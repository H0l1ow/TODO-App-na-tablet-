#Requires -Version 5.1
# Does not remove the SQLite database, JSON backups or diagnostic log.
$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'Programs\DomowyPlan'
$desktopLink = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Domowy Plan.lnk'
$programsLink = Join-Path ([Environment]::GetFolderPath('Programs')) 'Domowy Plan.lnk'
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Domowy Plan.lnk'
Write-Host 'Domowy Plan - uninstall'
Write-Host ('Program folder: ' + $destination)
Write-Host 'SQLite database and backups will be KEPT.'
$answer = Read-Host 'Type USUN to uninstall'
if ($answer -cne 'USUN') { Write-Host 'Cancelled.'; exit 0 }
if (Get-Process -Name 'DomowyPlan' -ErrorAction SilentlyContinue) {
    throw 'Close DomowyPlan before uninstalling it.'
}
foreach ($link in @($desktopLink, $programsLink, $startupLink)) {
    if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
}
if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Recurse -Force
}
Write-Host 'Program removed. User data retained.' -ForegroundColor Green
