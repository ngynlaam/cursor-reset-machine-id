<#
.SYNOPSIS
    Reset Cursor Machine ID

.DESCRIPTION
    Resets Cursor IDE machine ID by generating new IDs and updating storage files and registry.
#>

param(
    [switch]$Elevated
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# Functions
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $prefix = switch ($Level) {
        "Info"    { "[INFO]" }
        "Success" { "[OK]" }
        "Warning" { "[WARN]" }
        "Error"   { "[ERROR]" }
    }
    
    $color = switch ($Level) {
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Get-CursorPaths {
    $appData = $env:APPDATA
    
    return @{
        StorageJson = Join-Path $appData "Cursor\User\globalStorage\storage.json"
        StateDb     = Join-Path $appData "Cursor\User\globalStorage\state.vscdb"
        MachineId   = Join-Path $appData "Cursor\machineId"
    }
}

function New-MachineIds {
    $devDeviceId = [guid]::NewGuid().ToString()
    $machineId = -join ((1..64) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
    $macMachineId = -join ((1..128) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
    $sqmId = "{" + [guid]::NewGuid().ToString().ToUpper() + "}"
    
    return @{
        "telemetry.devDeviceId"    = $devDeviceId
        "telemetry.machineId"      = $machineId
        "telemetry.macMachineId"   = $macMachineId
        "telemetry.sqmId"          = $sqmId
        "storage.serviceMachineId" = $devDeviceId
    }
}

function Update-StorageJson {
    param(
        [string]$Path,
        [hashtable]$NewIds
    )
    
    Write-Log "Updating storage.json..."
    
    if (-not (Test-Path $Path)) {
        Write-Log "storage.json not found: $Path" -Level Warning
        return $false
    }
    
    try {
        $backupPath = "$Path.backup"
        Copy-Item -Path $Path -Destination $backupPath -Force
        
        # Read with UTF-8
        $content = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        
        foreach ($key in $NewIds.Keys) {
            $content | Add-Member -NotePropertyName $key -NotePropertyValue $NewIds[$key] -Force
        }
        
        # Save with UTF-8 without BOM
        $json = $content | ConvertTo-Json -Depth 10 -Compress:$false
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
        
        Write-Log "storage.json updated" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to update storage.json: $_" -Level Error
        return $false
    }
}

function Update-MachineIdFile {
    param(
        [string]$Path,
        [string]$MachineId
    )
    
    Write-Log "Updating machineId file..."
    
    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        if (Test-Path $Path) {
            $backupPath = "$Path.backup"
            Copy-Item -Path $Path -Destination $backupPath -Force
        }
        
        # Write with UTF-8 without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $MachineId, $utf8NoBom)
        
        Write-Log "machineId file updated" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to update machineId file: $_" -Level Error
        return $false
    }
}

function Update-WindowsRegistry {
    param(
        [hashtable]$NewIds
    )
    
    Write-Log "Updating Windows registry..."
    
    try {
        $cryptographyPath = "HKLM:\SOFTWARE\Microsoft\Cryptography"
        $newGuid = [guid]::NewGuid().ToString()
        Set-ItemProperty -Path $cryptographyPath -Name "MachineGuid" -Value $newGuid -Force
        
        $sqmPath = "HKLM:\SOFTWARE\Microsoft\SQMClient"
        if (-not (Test-Path $sqmPath)) {
            New-Item -Path $sqmPath -Force | Out-Null
        }
        Set-ItemProperty -Path $sqmPath -Name "MachineId" -Value $NewIds["telemetry.sqmId"] -Force
        
        Write-Log "Registry updated" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to update registry: $_" -Level Error
        return $false
    }
}

# ============================================================================
# Main
# ============================================================================

function Main {
    Write-Host ""
    Write-Host "Cursor Machine ID Reset Tool" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    
    if (-not $isAdmin) {
        Write-Log "Administrator privileges required" -Level Warning
        Write-Log "Requesting elevation..." -Level Info
        
        try {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
            Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
            exit 0
        }
        catch {
            Write-Log "Failed to request administrator privileges" -Level Error
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    
    Write-Log "Running with administrator privileges" -Level Success
    
    # Get paths
    $paths = Get-CursorPaths
    
    # Step 1: Generate new IDs
    Write-Host ""
    Write-Host "[1/3] Generating new machine IDs..." -ForegroundColor Cyan
    $newIds = New-MachineIds
    Write-Log "New IDs generated" -Level Success
    
    # Step 2: Update files
    Write-Host ""
    Write-Host "[2/3] Updating storage files..." -ForegroundColor Cyan
    $success = $true
    $success = (Update-StorageJson -Path $paths.StorageJson -NewIds $newIds) -and $success
    $success = (Update-MachineIdFile -Path $paths.MachineId -MachineId $newIds["telemetry.devDeviceId"]) -and $success
    
    # Step 3: Update registry
    Write-Host ""
    Write-Host "[3/3] Updating Windows registry..." -ForegroundColor Cyan
    $success = (Update-WindowsRegistry -NewIds $newIds) -and $success
    
    # Summary
    Write-Host ""
    if ($success) {
        Write-Host "================================" -ForegroundColor Green
        Write-Log "Machine ID reset completed successfully" -Level Success
        Write-Host "================================" -ForegroundColor Green
        Write-Host ""
        Write-Log "You can now restart Cursor to apply changes" -Level Info
    }
    else {
        Write-Host "================================" -ForegroundColor Yellow
        Write-Log "Reset completed with some warnings" -Level Warning
        Write-Host "================================" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor White
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# Run
try {
    Main
}
catch {
    Write-Log "An unexpected error occurred: $_" -Level Error
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor White
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}
