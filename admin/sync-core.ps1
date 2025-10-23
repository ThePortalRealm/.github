<#
.SYNOPSIS
  The Portal Realm --- Unified GitHub Sync Controller
.DESCRIPTION
  Runs label, issue type, and .github file sync operations for all enabled repositories.
  Now guaranteed to restore the working directory when finished.
#>

param(
    [switch]$Files,
    [switch]$Issues,
    [switch]$Labels
)

$StartDir = Get-Location
try {
    Write-Host "=== The Portal Realm GitHub Sync ==="
    Write-Host ""

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $ReposFile = Join-Path $ScriptDir "repos.json"

    if (-not (Test-Path $ReposFile)) {
        Write-Host "Missing repos.json"
        exit 1
    }

    $ReposData = Get-Content $ReposFile | ConvertFrom-Json
    if ($ReposData.PSObject.Properties.Name -contains 'repos') {
        $RepoArray = $ReposData.repos
    } else {
        $RepoArray = $ReposData
    }
    $EnabledRepos = $RepoArray | Where-Object { $_.enabled -eq $true }

    # Always treat as array
    if ($EnabledRepos -isnot [System.Collections.IEnumerable] -or $EnabledRepos -is [string]) {
        $EnabledRepos = @($EnabledRepos)
    }

    foreach ($repo in $EnabledRepos) {
        $FullRepo = "$($repo.org)/$($repo.name)"
        Write-Host "-> Processing $FullRepo"
        Write-Host ""

        if ($Files) {
            Write-Host "[1/3] Syncing templates and policies..."
            & "$ScriptDir/sync-files.ps1" -Repo $FullRepo
            Write-Host ""
        }

        if ($Issues) {
            Write-Host "[2/3] Syncing issue types..."
            & "$ScriptDir/sync-issue-types.ps1"
            Write-Host ""
        }

        if ($Labels) {
            Write-Host "[3/3] Syncing labels..."
            & "$ScriptDir/sync-labels.ps1"
            Write-Host ""
        }

        Write-Host "Done: $FullRepo"
        Write-Host "--------------------------------------"
    }

    Write-Host ""
    Write-Host "All enabled repositories processed successfully."
}
finally {
    Set-Location $StartDir
}
