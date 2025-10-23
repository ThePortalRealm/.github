<#
.SYNOPSIS
  Sync .github templates and community files to all enabled repos
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$SourceDir = Join-Path $RootDir ".github"
$ReposFile = Join-Path $ScriptDir "repos.json"

# --- Check dependencies
foreach ($cmd in @("gh","git")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "Missing dependency: $cmd"
        exit 1
    }
}

# --- Verify source folders
if (-not (Test-Path "$SourceDir\ISSUE_TEMPLATE")) {
    Write-Host "Missing .github/ISSUE_TEMPLATE folder"
    exit 1
}

Write-Host "Syncing .github templates and policies..."
Write-Host ""

# --- Load repos.json
$repos = (Get-Content $ReposFile -Raw | ConvertFrom-Json).repos | Where-Object { $_.enabled -eq $true }

foreach ($repo in $repos) {
    $Org  = $repo.org
    $Name = $repo.name
    $Full = "$Org/$Name"

    Write-Host "Syncing $Full"

    $Tmp = New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid())
    gh repo clone $Full $Tmp.FullName -- -q --depth=1 | Out-Null
    Set-Location $Tmp.FullName

    New-Item -ItemType Directory -Force -Path ".github" | Out-Null

    $Files = @(
        "$SourceDir\ISSUE_TEMPLATE",
        "$SourceDir\PULL_REQUEST_TEMPLATE",
        "$SourceDir\CONTRIBUTING.md",
        "$SourceDir\SECURITY.md",
        "$SourceDir\CODE_OF_CONDUCT.md"
    )

    foreach ($f in $Files) {
        if (Test-Path $f) {
            Copy-Item $f ".github\" -Recurse -Force
        }
    }

    $changed = git status --porcelain
    if ($changed) {
        git add .github | Out-Null
        git commit -m "Sync .github templates and community files" | Out-Null
        git push origin HEAD | Out-Null
        Write-Host "Updated $Full"
    }
    else {
        Write-Host "No changes in $Full"
    }

    Set-Location $RootDir
    Remove-Item $Tmp.FullName -Recurse -Force
    Write-Host ""
}

Write-Host "All enabled repositories synced successfully!"
