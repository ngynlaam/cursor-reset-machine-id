<#
.SYNOPSIS
    Reset Cursor Machine ID
#>

param([switch]$Elevated)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Log {
    param([string]$Message)
    Write-Host $Message
}

function Get-CursorPaths {
    $appData = $env:APPDATA
    return @{
        StorageJson = Join-Path $appData "Cursor\User\globalStorage\storage.json"
        MachineId   = Join-Path $appData "Cursor\machineId"
    }
}

function New-MachineIds {
    return @{
        "telemetry.devDeviceId"    = [guid]::NewGuid().ToString()
        "telemetry.machineId"      = -join ((1..64) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
        "telemetry.macMachineId"   = -join ((1..128) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
        "telemetry.sqmId"          = "{" + [guid]::NewGuid().ToString().ToUpper() + "}"
        "storage.serviceMachineId" = [guid]::NewGuid().ToString()
    }
}

function Update-StorageJson {
    param([string]$Path, [hashtable]$NewIds)
    
    if (-not (Test-Path $Path)) {
        Write-Log "Warning: storage.json not found"
        return $false
    }
    
    try {
        Copy-Item -Path $Path -Destination "$Path.backup" -Force
        $content = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        
        foreach ($key in $NewIds.Keys) {
            $content | Add-Member -NotePropertyName $key -NotePropertyValue $NewIds[$key] -Force
        }
        
        $json = $content | ConvertTo-Json -Depth 10 -Compress:$false
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
        
        return $true
    }
    catch {
        Write-Log "Error updating storage.json: $_"
        return $false
    }
}

function Update-MachineIdFile {
    param([string]$Path, [string]$MachineId)
    
    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        if (Test-Path $Path) {
            Copy-Item -Path $Path -Destination "$Path.backup" -Force
        }
        
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $MachineId, $utf8NoBom)
        
        return $true
    }
    catch {
        Write-Log "Error updating machineId file: $_"
        return $false
    }
}

function Update-WindowsRegistry {
    param([hashtable]$NewIds)
    
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -Value ([guid]::NewGuid().ToString()) -Force
        
        $sqmPath = "HKLM:\SOFTWARE\Microsoft\SQMClient"
        if (-not (Test-Path $sqmPath)) {
            New-Item -Path $sqmPath -Force | Out-Null
        }
        Set-ItemProperty -Path $sqmPath -Name "MachineId" -Value $NewIds["telemetry.sqmId"] -Force
        
        return $true
    }
    catch {
        Write-Log "Error updating registry: $_"
        return $false
    }
}

function Main {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    
    if (-not $isAdmin) {
        try {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
            Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
            exit 0
        }
        catch {
            Write-Log "Failed to request admin privileges"
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    
    Write-Log "Cursor Machine ID Reset Tool"
    Write-Log ""
    
    $paths = Get-CursorPaths
    
    Write-Log "Generating new machine IDs..."
    $newIds = New-MachineIds
    
    Write-Log "Updating storage.json..."
    Update-StorageJson -Path $paths.StorageJson -NewIds $newIds | Out-Null
    
    Write-Log "Updating machineId file..."
    Update-MachineIdFile -Path $paths.MachineId -MachineId $newIds["telemetry.devDeviceId"] | Out-Null
    
    Write-Log "Updating Windows registry..."
    Update-WindowsRegistry -NewIds $newIds | Out-Null
    
    Write-Log ""
    Write-Log "Machine ID reset completed"
    Write-Log "Please restart Cursor to apply changes"
    Write-Log ""
    
    Read-Host "Press Enter to exit"
}

try {
    Main
}
catch {
    Write-Log "Error: $_"
    Read-Host "Press Enter to exit"
    exit 1
}
