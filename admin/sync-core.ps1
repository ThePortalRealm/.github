param(
    [switch]$Issues,
    [switch]$Files,
    [switch]$Labels
)

Write-Host "=== The Portal Realm GitHub Sync ==="

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ReposFile = Join-Path $ScriptDir "repos.json"
$Repos = (Get-Content $ReposFile | ConvertFrom-Json).repos | Where-Object { $_.enabled -eq $true }

foreach ($repo in $Repos) {
    $FullRepo = "$($repo.org)/$($repo.name)"
    Write-Host "→ Processing $FullRepo"

    if ($Files) {
        & "$ScriptDir/sync-files.ps1" -Repo $FullRepo
    }
    if ($Issues) {
        & "$ScriptDir/sync-issue-types.ps1" -Repo $FullRepo
    }
    if ($Labels) {
        & "$ScriptDir/sync-labels.ps1" -Repo $FullRepo
    }

    Write-Host ""
}

Write-Host "All enabled repositories synced successfully."
