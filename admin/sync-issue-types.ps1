#
#.SYNOPSIS
#  The Portal Realm --- Org Issue Type Sync Utility (PowerShell version)
#.DESCRIPTION
#  Creates or updates organization-level issue types using the GitHub GraphQL API.
#  Requires: gh CLI authenticated with repo/org admin scope.
#  Reads: issue-types.json and repos.json (supports /* ... */ and // ... comments)
#

param(
    [string]$TypesFile = "$PSScriptRoot/issue-types.json",
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
    # Remove /* ... */ and // ... comments and trailing commas
    $content = [regex]::Replace($content, '/\*.*?\*/', '', 'Singleline')
    $content = [regex]::Replace($content, '//.*', '')
    $content = [regex]::Replace($content, ',\s*([\}\]])', '$1')
    return $content
}

# ============================================================
#  Prepare Clean JSON
# ============================================================
try {
    $CleanTypes = Strip-Comments $TypesFile | ConvertFrom-Json
    $CleanRepos = Strip-Comments $ReposFile | ConvertFrom-Json
}
catch {
    Write-Host "Error parsing JSON: $($_.Exception.Message)"
    exit 1
}

# ============================================================
#  Determine Organization
# ============================================================
$Org = ($CleanRepos.repos | Where-Object { $_.enabled -eq $true } | Select-Object -First 1).org
if (-not $Org) {
    Write-Host "Could not determine organization from repos.json"
    exit 1
}

# ============================================================
#  Retrieve Organization ID
# ============================================================
$OrgQuery = @"
{
  organization(login: "$Org") {
    id
  }
}
"@

$OrgID = gh api graphql -f query="$OrgQuery" --jq ".data.organization.id"
if (-not $OrgID) {
    Write-Host "Could not retrieve organization ID for $Org"
    exit 1
}

# ============================================================
#  Fetch existing issue types
# ============================================================
$ExistingQuery = @"
{
  organization(login: "$Org") {
    issueTypes(first: 100) {
      nodes { id name color description }
    }
  }
}
"@
$ExistingJSON = gh api graphql -f query="$ExistingQuery" --jq ".data.organization.issueTypes.nodes" | ConvertFrom-Json

# ============================================================
#  Color Conversion
# ============================================================
function Get-IssueTypeColor {
    param([string]$Hex)
    switch -regex ($Hex.ToUpper()) {
        "^(000000|1B1F23)$" { return "BLACK" }
        "^(0366D6|1F6FEB)$" { return "BLUE" }
        "^(2E8B57|22863A|0E8A16)$" { return "GREEN" }
        "^(D73A4A|CB2431)$" { return "RED" }
        "^(EAC54F|FBCA04)$" { return "YELLOW" }
        "^(9370DB|6F42C1)$" { return "PURPLE" }
        "^(708090|586069)$" { return "GRAY" }
        "^(FFA500|D18616)$" { return "ORANGE" }
        default { return "GRAY" }
    }
}

# ============================================================
#  Sync Loop
# ============================================================
Write-Host "Syncing $($CleanTypes.Count) issue types for organization: $Org"
Write-Host ""

foreach ($t in $CleanTypes) {
    $Name  = $t.name
    $Desc  = $t.description
    $Color = Get-IssueTypeColor $t.color
    $Existing = $ExistingJSON | Where-Object { $_.name -eq $Name }

    if ($Existing) {
        Write-Host "Updating: $Name ($Color)"
        $Mutation = @"
mutation {
  updateIssueType(input: {
    issueTypeId: "$($Existing.id)",
    color: $Color,
    description: "$Desc"
  }) {
    issueType { id name color description }
  }
}
"@
    }
    else {
        Write-Host "Creating: $Name ($Color)"
        $Mutation = @"
mutation {
  createIssueType(input: {
    ownerId: "$OrgID",
    name: "$Name",
    description: "$Desc",
    color: $Color,
    isEnabled: true
  }) {
    issueType { id name color description isEnabled }
  }
}
"@
    }

    try {
        gh api graphql -f query="$Mutation" | Out-Null
    }
    catch {
        Write-Host "Failed to sync $Name --- $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "All issue types synced successfully for $Org!"
