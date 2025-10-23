<#
.SYNOPSIS
  The Portal Realm --- Label Sync Utility (PowerShell version)
.DESCRIPTION
  Syncs labels across multiple repositories defined in repos.json.
  Supports JSON comments, multi-org structure, and an optional --Clean flag
  to remove labels not listed in labels.json.
  Requires: gh CLI authenticated with repo/org scope.
#>

param(
    [switch]$Clean,
    [string]$LabelsFile = "$PSScriptRoot/labels.json",
    [string]$ReposFile = "$PSScriptRoot/repos.json"
)

# ============================================================
#  Dependency Check
# ============================================================
$dependencies = @("gh", "git")
foreach ($tool in $dependencies) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "Missing dependency: $tool"
        exit 1
    }
}

# ============================================================
#  strip-comments helper
# ============================================================
function Strip-Comments {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Missing file: $Path"
    }

    $content = Get-Content $Path -Raw
    $content = [regex]::Replace($content, '/\*.*?\*/', '', 'Singleline')
    $content = [regex]::Replace($content, '//.*', '')
    $content = [regex]::Replace($content, ',\s*([\}\]])', '$1')
    return $content
}

# ============================================================
#  Load and Clean JSON
# ============================================================
try {
    $CleanLabels = Strip-Comments $LabelsFile | ConvertFrom-Json
    $CleanRepos  = Strip-Comments $ReposFile | ConvertFrom-Json
}
catch {
    Write-Host "Error parsing JSON: $($_.Exception.Message)"
    exit 1
}

# ============================================================
#  Summary
# ============================================================
$EnabledRepos = $CleanRepos.repos | Where-Object { $_.enabled -eq $true }
$LabelCount = $CleanLabels.Count
$RepoCount  = $EnabledRepos.Count

Write-Host "Syncing $LabelCount labels across $RepoCount repositories"
Write-Host ""

# ============================================================
#  Main Loop
# ============================================================
foreach ($Repo in $EnabledRepos) {
    $FullRepo = "$($Repo.org)/$($Repo.name)"
    Write-Host "Syncing labels for $FullRepo"

    # Check access
    if (-not (gh repo view $FullRepo --json name -q '.name' 2>$null)) {
        Write-Host "Skipping: cannot access $FullRepo"
        Write-Host ""
        continue
    }

    # Iterate each label from JSON
    foreach ($Label in $CleanLabels) {
        $Name  = $Label.name
        $Color = $Label.color
        $Desc  = $Label.description

        $exists = gh label view $Name --repo $FullRepo --json name -q '.name' 2>$null

        if ($exists) {
            Write-Host "Updating: $Name"
            gh label edit $Name --repo $FullRepo --color $Color --description "$Desc" --force | Out-Null
        }
        else {
            Write-Host "Creating: $Name"
            gh label create $Name --repo $FullRepo --color $Color --description "$Desc" --force | Out-Null
        }
    }

    Write-Host "Finished syncing $FullRepo"

    # ========================================================
    #  Optional Cleanup
    # ========================================================
    if ($Clean) {
        Write-Host "Cleaning labels not in labels.json for $FullRepo..."

        $Existing = gh label list --repo $FullRepo --json name -q '.[].name' | ConvertFrom-Json
        $Defined  = $CleanLabels.name

        foreach ($LabelName in $Existing) {
            if ($Defined -notcontains $LabelName) {
                Write-Host "  Removing: $LabelName"
                try {
                    gh label delete $LabelName --repo $FullRepo --yes | Out-Null
                }
                catch {
                    Write-Host "  Failed to delete $LabelName --- $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Host ""
}

Write-Host "All enabled repositories synced successfully!"
