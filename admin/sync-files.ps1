<#
.SYNOPSIS
  The Portal Realm --- Template & Policy Sync
.DESCRIPTION
  Copies .github templates and community files to all enabled repos.
  Assumes this script runs from .github/admin inside the .github repo.
  Restores working directory when finished.
#>

param(
    [string]$Repo
)

$StartDir = Get-Location
try {
    # We are inside .github/admin -> one level up is the .github repo root
    $SourceDir = Split-Path -Parent $PSScriptRoot

    if (-not (Test-Path $SourceDir)) {
        Write-Host "Missing .github source directory: $SourceDir"
        exit 1
    }

    $TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

    Write-Host "Cloning $Repo..."
    gh repo clone $Repo $TmpDir -- -q --depth=1
    Set-Location $TmpDir

    if (-not (Test-Path ".github")) {
        New-Item -ItemType Directory -Path ".github" | Out-Null
    }

    Write-Host "Copying template and policy files..."
    Copy-Item -Recurse -Force "$SourceDir\.github\ISSUE_TEMPLATE" ".github\" -ErrorAction SilentlyContinue
    Copy-Item -Recurse -Force "$SourceDir\.github\PULL_REQUEST_TEMPLATE" ".github\" -ErrorAction SilentlyContinue
    Copy-Item -Force "$SourceDir\CONTRIBUTING.md","$SourceDir\SECURITY.md","$SourceDir\CODE_OF_CONDUCT.md","$SourceDir\config.yml" ".github\" -ErrorAction SilentlyContinue

    git add .github | Out-Null
    if (-not (git diff --cached --quiet)) {
        git commit -m "Sync .github templates and community files [skip ci]" | Out-Null
        git push origin HEAD | Out-Null
        Write-Host "Updated $Repo"
    }
    else {
        Write-Host "No changes in $Repo"
    }

    # Always return to safe directory first
    Set-Location $env:TEMP
    Start-Sleep -Milliseconds 500

    # Kill any lingering git/gh processes
    Get-Process git, gh -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    $attempts = 0
    $waitTime = 2
    while ((Test-Path $TmpDir) -and ($attempts -lt 5)) {
        try {
            Remove-Item -Recurse -Force -ErrorAction Stop $TmpDir
            Write-Host "Cleaned up temp folder: $TmpDir"
            break
        }
        catch {
            $attempts++
            Write-Host "Cleanup attempt $attempts failed:"
            Write-Host "  Exception: $($_.Exception.Message)"
            Write-Host "  Retrying in $waitTime seconds..."
            Start-Sleep -Seconds $waitTime
            $waitTime *= 2
        }
    }

    if (Test-Path $TmpDir) {
        Write-Host "Scheduling deferred cleanup for $TmpDir"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout 5 & rmdir /s /q `"$TmpDir`"" -WindowStyle Hidden
    }
}
finally {
    Set-Location $StartDir
}
