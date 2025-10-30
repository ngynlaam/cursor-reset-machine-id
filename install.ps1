# Cursor Machine ID Reset - Quick Install Script

$ErrorActionPreference = "Stop"

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "ERROR: Administrator privileges required" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator and execute:" -ForegroundColor Yellow
    Write-Host "  irm https://raw.githubusercontent.com/YOUR_USERNAME/cursor-reset-machine-id/main/install.ps1 | iex" -ForegroundColor Cyan
    Write-Host ""
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host ""
Write-Host "Cursor Machine ID Reset - Quick Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Create temp directory
$tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Download
    Write-Host "[INFO] Downloading reset script..." -ForegroundColor White
    $scriptUrl = "https://raw.githubusercontent.com/ngynlaam/cursor-reset-machine-id/main/Reset-CursorMachineID.ps1"
    $scriptPath = Join-Path $tempDir "Reset-CursorMachineID.ps1"
    
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "[OK] Download completed" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to download script: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check your internet connection and try again" -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 5
        exit 1
    }
    
    Write-Host ""
    Write-Host "[INFO] Starting reset process..." -ForegroundColor White
    Write-Host ""
    
    # Execute
    & $scriptPath
    
}
catch {
    Write-Host ""
    Write-Host "[ERROR] An error occurred: $_" -ForegroundColor Red
    Write-Host ""
    Start-Sleep -Seconds 5
    exit 1
}
finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
