#Requires -Version 5.1
# This script runs on the 32-bit Windows 10 tablet. No administrator required.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PayloadDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$source = [System.IO.Path]::GetFullPath($PayloadDir)
$destination = Join-Path $env:LOCALAPPDATA 'Programs\DomowyPlan'
if (!(Test-Path -LiteralPath (Join-Path $source 'DomowyPlan.exe') -PathType Leaf)) {
    throw 'Package is missing DomowyPlan.exe. Transfer the BUILT Win32 ZIP, not the source ZIP.'
}
if ($source.TrimEnd('\') -ieq $destination.TrimEnd('\')) {
    throw 'Application is already in its installation directory. Run URUCHOM.bat instead.'
}
if (Get-Process -Name 'DomowyPlan' -ErrorAction SilentlyContinue) {
    throw 'Close DomowyPlan before installing/updating it.'
}
$pe = [System.IO.File]::OpenRead((Join-Path $source 'DomowyPlan.exe'))
try {
    $br = New-Object System.IO.BinaryReader($pe)
    $pe.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
    $offset = $br.ReadInt32()
    if ($offset -lt 64 -or $offset -gt $pe.Length - 6) { throw 'Invalid Windows executable.' }
    $pe.Seek(($offset + 4), [System.IO.SeekOrigin]::Begin) | Out-Null
    if ($br.ReadUInt16() -ne 0x014c) { throw 'This package is not 32-bit x86.' }
}
finally { $pe.Dispose() }

Write-Host ''
Write-Host 'Domowy Plan - offline install (Windows 10 x86)' -ForegroundColor Cyan
Write-Host ('Source: ' + $source)
Write-Host ('Target: ' + $destination)
Write-Host 'User data in AppData WILL NOT be overwritten.'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
# The source folder may include Qt DLLs and nested plugins. Copy them together.
Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
}

$desktop = [Environment]::GetFolderPath('DesktopDirectory')
$programs = [Environment]::GetFolderPath('Programs')
$startup = [Environment]::GetFolderPath('Startup')
foreach ($dir in @($desktop, $programs, $startup)) {
    if (!(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}
$shell = New-Object -ComObject WScript.Shell
function New-AppShortcut([string]$LinkFile) {
    $link = $shell.CreateShortcut($LinkFile)
    $link.TargetPath = Join-Path $destination 'URUCHOM.bat'
    $link.WorkingDirectory = $destination
    $link.Description = 'Domowy Plan - offline TODO'
    $link.IconLocation = (Join-Path $destination 'DomowyPlan.exe') + ',0'
    $link.Save()
}
$startLink = Join-Path $programs 'Domowy Plan.lnk'
$desktopLink = Join-Path $desktop 'Domowy Plan.lnk'
$startupLink = Join-Path $startup 'Domowy Plan.lnk'
New-AppShortcut $desktopLink
New-AppShortcut $startLink

$choice = Read-Host 'Start automatically when Windows user logs in? [T/n]'
if ($choice -match '^[nN]') {
    if (Test-Path -LiteralPath $startupLink) { Remove-Item -LiteralPath $startupLink -Force }
    Write-Host 'Autostart disabled.'
} else {
    New-AppShortcut $startupLink
    Write-Host 'Autostart enabled.'
}
Write-Host ''
Write-Host 'Installation successful.' -ForegroundColor Green
Write-Host ('Launch: ' + (Join-Path $destination 'URUCHOM.bat'))
Write-Host ('Uninstall: ' + (Join-Path $destination 'ODINSTALUJ.bat'))
Write-Host 'Database and backups are stored outside the program directory.'
$launch = Read-Host 'Launch Domowy Plan now? [T/n]'
if ($launch -notmatch '^[nN]') {
    Start-Process -FilePath (Join-Path $destination 'URUCHOM.bat') -WorkingDirectory $destination
}
