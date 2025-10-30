# Cursor Machine ID Reset - Quick Install Script

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "Administrator privileges required"
    Write-Host "Please run PowerShell as Administrator and execute:"
    Write-Host "irm https://raw.githubusercontent.com/ngynlaam/cursor-reset-machine-id/main/install.ps1 | iex"
    Write-Host ""
    Start-Sleep -Seconds 3
    exit 1
}

Write-Host ""
Write-Host "Cursor Machine ID Reset"
Write-Host ""

$tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Write-Host "Downloading reset script..."
    $scriptUrl = "https://raw.githubusercontent.com/ngynlaam/cursor-reset-machine-id/main/Reset-CursorMachineID.ps1"
    $scriptPath = Join-Path $tempDir "Reset-CursorMachineID.ps1"
    
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "Download completed"
        Write-Host ""
    }
    catch {
        Write-Host "Download failed: $_"
        Start-Sleep -Seconds 3
        exit 1
    }
    
    & $scriptPath
    
}
catch {
    Write-Host "Error: $_"
    Start-Sleep -Seconds 3
    exit 1
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
