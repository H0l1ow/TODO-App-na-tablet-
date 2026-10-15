#Requires -Version 5.1
<#
Build + self-contained x86 distribution for the EDGE 1086 (Windows 10 32-bit).
Run on a Windows development computer with Qt 5.15.2 mingw81_32, matching
MinGW 8.1.0 32-bit and CMake installed. Never execute on the tablet.

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Win32.ps1 `
  -QtRoot C:\Qt\5.15.2\mingw81_32 -MingwRoot C:\Qt\Tools\mingw810_32
#>
[CmdletBinding()]
param(
    [string]$QtRoot = 'C:\Qt\5.15.2\mingw81_32',
    [string]$MingwRoot = 'C:\Qt\Tools\mingw810_32'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    Write-Host ('> ' + $Program + ' ' + ($Arguments -join ' '))
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ('Command failed with exit code ' + $LASTEXITCODE + ': ' + $Program)
    }
}

function Assert-X86([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw ('Missing binary: ' + $Path) }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw ('Not an MZ executable: ' + $Path) }
        $stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $offset = $reader.ReadInt32()
        if ($offset -lt 64 -or $offset -gt ($stream.Length - 6)) {
            throw ('Invalid PE header: ' + $Path)
        }
        $stream.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        if ($reader.ReadUInt32() -ne 0x00004550) { throw ('Invalid PE signature: ' + $Path) }
        $machine = $reader.ReadUInt16()
        if ($machine -ne 0x014C) {
            throw ('Not 32-bit x86 PE (machine ' + $machine + '): ' + $Path)
        }
    }
    finally { $stream.Dispose() }
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$QtRoot = [System.IO.Path]::GetFullPath($QtRoot)
$MingwRoot = [System.IO.Path]::GetFullPath($MingwRoot)
$qtBin = Join-Path $QtRoot 'bin'
$gccBin = Join-Path $MingwRoot 'bin'
$qmake = Join-Path $qtBin 'qmake.exe'
$windeploy = Join-Path $qtBin 'windeployqt.exe'
$gcc = Join-Path $gccBin 'g++.exe'
$make = Join-Path $gccBin 'mingw32-make.exe'
foreach ($file in @($qmake, $windeploy, $gcc, $make)) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw ('Tool not found: ' + $file) }
}
$version = ((& $qmake -query QT_VERSION) | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne '5.15.2') {
    throw ('Expected Qt 5.15.2, found: ' + $version)
}
$gccTarget = ((& $gcc -dumpmachine) | Select-Object -First 1).Trim()
$gccVersion = ((& $gcc -dumpfullversion) | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or !$gccTarget.StartsWith('i686-') -or !$gccVersion.StartsWith('8.1.')) {
    throw ('Expected MinGW-w64 i686 GCC 8.1.x, found: ' + $gccTarget + ' ' + $gccVersion)
}
Assert-X86 (Join-Path $qtBin 'Qt5Core.dll')
$cmake = (Get-Command cmake.exe -ErrorAction Stop).Source
$build = Join-Path $repo 'out\build-win32-release'
$stage = Join-Path $repo 'out\package-win32\DomowyPlan'
$zip = Join-Path $repo 'out\DomowyPlan-Win32-x86-v0.3.zip'
$oldPath = $env:PATH
$env:PATH = $qtBin + ';' + $gccBin + ';' + $oldPath
try {
    Write-Host '== 1/4 Build Win32 x86 ==' -ForegroundColor Cyan
    Invoke-Checked $cmake @(
        '-S', $repo, '-B', $build, '-G', 'MinGW Makefiles',
        '-DCMAKE_BUILD_TYPE=Release',
        '-DBUILD_TESTING=OFF',
        '-DDOMOWYPLAN_REQUIRE_X86=ON',
        ('-DCMAKE_PREFIX_PATH=' + $QtRoot),
        ('-DCMAKE_MAKE_PROGRAM=' + $make),
        ('-DCMAKE_CXX_COMPILER=' + $gcc)
    )
    Invoke-Checked $cmake @('--build', $build, '--parallel', '2')
    $exe = Join-Path $build 'DomowyPlan.exe'
    Assert-X86 $exe

    Write-Host '== 2/4 Deploy Qt runtime and QML ==' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Copy-Item -LiteralPath $exe -Destination (Join-Path $stage 'DomowyPlan.exe')
    Invoke-Checked $windeploy @(
        '--release', '--compiler-runtime', '--no-translations',
        '--qmldir', (Join-Path $repo 'qml'),
        (Join-Path $stage 'DomowyPlan.exe')
    )

    # QSQLITE is loaded dynamically: make its presence explicit, even when
    # windeployqt does not discover the SQLite driver automatically.
    $sqlDriver = Join-Path $stage 'sqldrivers\qsqlite.dll'
    if (!(Test-Path -LiteralPath $sqlDriver)) {
        $qtSqlDriver = Join-Path $QtRoot 'plugins\sqldrivers\qsqlite.dll'
        if (!(Test-Path -LiteralPath $qtSqlDriver)) { throw 'Qt SQLite plugin qsqlite.dll missing in Qt installation' }
        New-Item -ItemType Directory -Path (Split-Path -Parent $sqlDriver) -Force | Out-Null
        Copy-Item -LiteralPath $qtSqlDriver -Destination $sqlDriver
    }

    foreach ($runtime in @('libgcc_s_dw2-1.dll', 'libstdc++-6.dll', 'libwinpthread-1.dll')) {
        $destination = Join-Path $stage $runtime
        if (!(Test-Path -LiteralPath $destination)) {
            $source = Join-Path $gccBin $runtime
            if (!(Test-Path -LiteralPath $source)) { throw ('Missing MinGW runtime: ' + $runtime) }
            Copy-Item -LiteralPath $source -Destination $destination
        }
    }

    # A relative qt.conf prevents Qt from looking for developer-PC modules.
    [System.IO.File]::WriteAllText(
        (Join-Path $stage 'qt.conf'),
        "[Paths]`r`nPlugins=.`r`nQml2Imports=qml`r`n",
        [System.Text.Encoding]::ASCII
    )

    Get-ChildItem -LiteralPath (Join-Path $repo 'packaging') -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force
    }

    Write-Host '== 3/4 Validate 32-bit release files ==' -ForegroundColor Cyan
    foreach ($required in @('DomowyPlan.exe', 'Qt5Core.dll', 'Qt5Gui.dll', 'Qt5Qml.dll',
                             'Qt5Quick.dll', 'Qt5Sql.dll', 'platforms\qwindows.dll',
                             'sqldrivers\qsqlite.dll', 'URUCHOM.bat', 'ZAINSTALUJ.bat')) {
        if (!(Test-Path -LiteralPath (Join-Path $stage $required))) {
            throw ('Required deployment file missing: ' + $required)
        }
    }
    $qmlControl = @(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter qmldir |
        Where-Object { $_.FullName -match '[\\/]QtQuick[\\/]Controls\.2[\\/]qmldir$' })
    if ($qmlControl.Count -eq 0) {
        throw 'QtQuick.Controls 2 QML module missing. Check --qmldir and the selected Qt package.'
    }
    $binaries = @(Get-ChildItem -LiteralPath $stage -File -Recurse |
                  Where-Object { $_.Extension -in @('.dll', '.exe') })
    foreach ($binary in $binaries) { Assert-X86 $binary.FullName }
    Write-Host ('Validated ' + $binaries.Count + ' x86 PE binaries.')

    Write-Host '== 4/4 Create transport ZIP ==' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    Write-Host ('Ready: ' + $zip) -ForegroundColor Green
    Write-Host ('SHA256: ' + $hash)
    Write-Host 'Copy ZIP to the tablet, extract it, and run DomowyPlan\ZAINSTALUJ.bat.'
}
finally {
    $env:PATH = $oldPath
}
