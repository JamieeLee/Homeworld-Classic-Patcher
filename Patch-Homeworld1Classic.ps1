# HOMEWORLD 1 CLASSIC 2.303 PORTABLE PATCHER
# Readable PowerShell; no networking, downloads, registry edits, admin rights, or extra executables.
# Verifies the exact stock Homeworld.exe before modification, creates a backup, and checks result.
param([string]$GameExePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-HashOfBytes([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Hex-ToBytes([string]$Hex) {
    if (($Hex.Length % 2) -ne 0 -or $Hex -notmatch '^[0-9A-Fa-f]*$') { throw 'Invalid patch hexadecimal data.' }
    [byte[]]$out = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $out.Length; $i++) { $out[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return ,$out
}
# Read existing Steam configuration; never write to the registry.
# Steam AppID 244160 is Homeworld Remastered Collection.
function Find-SteamHomeworldExe {
    $steamRoots = @()
    foreach ($regPath in @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )) {
        try { $reg = Get-ItemProperty -LiteralPath $regPath -ErrorAction Stop }
        catch { continue }
        foreach ($propertyName in @('SteamPath', 'InstallPath', 'SteamExe')) {
            $value = [string]$reg.$propertyName
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            if ($propertyName -eq 'SteamExe') { $value = Split-Path -Path $value -Parent }
            if (Test-Path -LiteralPath (Join-Path $value 'steamapps') -PathType Container) {
                $steamRoots += $value
            }
        }
    }
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) { $steamRoots += (Join-Path $programFilesX86 'Steam') }
    if ($env:ProgramFiles) { $steamRoots += (Join-Path $env:ProgramFiles 'Steam') }

    $libraries = @($steamRoots | Select-Object -Unique)
    foreach ($root in @($steamRoots | Select-Object -Unique)) {
        $libraryList = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $libraryList -PathType Leaf)) { continue }
        try { $contents = [System.IO.File]::ReadAllText($libraryList) }
        catch { continue }
        foreach ($match in [regex]::Matches($contents, '(?im)^\s*"path"\s*"([^"]+)"')) {
            $library = $match.Groups[1].Value.Replace('\\', '\')
            if (Test-Path -LiteralPath (Join-Path $library 'steamapps') -PathType Container) {
                $libraries += $library
            }
        }
    }
    $found = @()
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $appManifest = Join-Path $library 'steamapps\appmanifest_244160.acf'
        if (-not (Test-Path -LiteralPath $appManifest -PathType Leaf)) { continue }
        try { $appInfo = [System.IO.File]::ReadAllText($appManifest) }
        catch { continue }
        $installed = [regex]::Match($appInfo, '(?im)^\s*"installdir"\s*"([^"]+)"')
        if (-not $installed.Success) { continue }
        $gameFolder = Join-Path (Join-Path $library 'steamapps\common') $installed.Groups[1].Value
        $exe = Join-Path $gameFolder 'Homeworld1Classic\exe\Homeworld.exe'
        if (Test-Path -LiteralPath $exe -PathType Leaf) { $found += $exe }
    }
    return @($found | Select-Object -Unique)
}
function Resolve-GameExePath {
    $candidates = @(Find-SteamHomeworldExe)
    if ($candidates.Count -eq 0) {
        Write-Host 'No Steam Homeworld 1 Classic executable automatically found.' -ForegroundColor Yellow
    }
    foreach ($candidate in $candidates) {
        Write-Host ''
        Write-Host 'Steam installation detected:' -ForegroundColor Cyan
        Write-Host "  $candidate"
        $choice = (Read-Host 'Use this executable? Type Y to confirm, or N to browse/try next').Trim()
        if ($choice -match '^(?i:y|yes)$') { return $candidate }
    }
    Write-Host 'Choose Homeworld.exe manually. Only the exact supported SHA-256 will be patched.'
    return Select-GameExe
}
function Select-GameExe {
    Add-Type -AssemblyName System.Windows.Forms
    $chooser = New-Object System.Windows.Forms.OpenFileDialog
    $chooser.Title = 'Find Homeworld 1 Classic Homeworld.exe (Homeworld1Classic\exe)'
    $chooser.Filter = 'Homeworld.exe|Homeworld.exe|Executable files (*.exe)|*.exe'
    $chooser.CheckFileExists = $true
    $chooser.Multiselect = $false
    if ($chooser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'Canceled. No files changed.' }
    return $chooser.FileName
}
try {
    Write-Host '================================================='
    Write-Host '  Homeworld 1 CLASSIC 2.303 - Portable Patch Kit'
    Write-Host '================================================='
    Write-Host 'Works ONLY with Homeworld 1 Classic build 2.303.'
    Write-Host 'Not for Homeworld 1 Remastered, HW2, or HW3.'
    Write-Host ''
    $patchDataPath = Join-Path $PSScriptRoot 'patches.json'
    if (-not (Test-Path -LiteralPath $patchDataPath -PathType Leaf)) { throw 'Missing patches.json. Keep the kit files together.' }
    $data = Get-Content -LiteralPath $patchDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $data.patches -or [int]$data.patch_count -ne 74 -or $data.patches.Count -ne 74) {
        throw 'Unexpected patch manifest. Refusing to modify anything.'
    }
    if ([string]::IsNullOrWhiteSpace($GameExePath)) { $GameExePath = Resolve-GameExePath }
    $GameExePath = [System.IO.Path]::GetFullPath($GameExePath.Trim('"'))
    if (-not (Test-Path -LiteralPath $GameExePath -PathType Leaf)) { throw "Game file not found: $GameExePath" }
    if ([System.IO.Path]::GetFileName($GameExePath) -ine 'Homeworld.exe') { throw 'Select the game file named Homeworld.exe.' }
    Write-Host "Target: $GameExePath"
    $beforeHash = (Get-FileHash -LiteralPath $GameExePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($beforeHash -eq [string]$data.patched_sha256) {
        Write-Host 'This executable is already patched. Nothing to do.' -ForegroundColor Green
        exit 0
    }
    if ($beforeHash -ne [string]$data.source_sha256) {
        throw "This is not the expected stock 2.303 executable. Actual SHA-256: $beforeHash`nExpected SHA-256: $($data.source_sha256)`nNothing was modified. It may be another version or already modded."
    }
    Write-Host 'Exact original version verified.' -ForegroundColor Green
    [byte[]]$orig = [System.IO.File]::ReadAllBytes($GameExePath)
    if ($orig.Length -ne [int]$data.source_size) { throw 'File size mismatch. Nothing changed.' }
    [byte[]]$edited = New-Object byte[] $orig.Length
    [System.Array]::Copy($orig, $edited, $orig.Length)
    $ranges = New-Object 'System.Collections.Generic.List[object]'
    foreach ($p in $data.patches) {
        $offset = [int]$p.offset
        [byte[]]$old = Hex-ToBytes ([string]$p.old)
        [byte[]]$new = Hex-ToBytes ([string]$p.new)
        if ($old.Length -ne $new.Length -or $old.Length -eq 0 -or $offset -lt 0 -or $offset -gt ($orig.Length - $old.Length)) {
            throw 'Patch offset/length invalid. Nothing changed.'
        }
        for ($i = 0; $i -lt $old.Length; $i++) {
            if ($orig[$offset+$i] -ne $old[$i]) { throw "Patch data mismatch at byte $($offset+$i). Nothing changed." }
            $edited[$offset+$i] = $new[$i]
        }
        $ranges.Add([pscustomobject]@{ Start = $offset; End = $offset + $old.Length })
    }
    $sorted = @($ranges | Sort-Object Start)
    for ($i=1; $i -lt $sorted.Length; $i++) {
        if ($sorted[$i].Start -lt $sorted[$i-1].End) { throw 'Overlapping patch offsets. Nothing changed.' }
    }
    $resultHash = Get-HashOfBytes $edited
    if ($resultHash -ne [string]$data.patched_sha256) { throw "Patched result failed SHA-256 verification ($resultHash). Nothing changed." }
    Write-Host "All $($data.patch_count) changes verified in memory." -ForegroundColor Green
    $response = (Read-Host 'Apply patch and save an original backup? Type YES to continue').Trim()
    if ($response -cne 'YES') { Write-Host 'Canceled. No files changed.'; exit 0 }

    # Atomic replace on NTFS. File.Replace creates the stock EXE backup in the same operation.
    # Refuse to overwrite an existing backup or to modify the game on any verification failure.
    $folder = [System.IO.Path]::GetDirectoryName($GameExePath)
    $stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')
    $backup = Join-Path $folder ("Homeworld.exe.original-2.303-$stamp-" + [Guid]::NewGuid().ToString('N').Substring(0,8) + '.bak')
    $temp = Join-Path $folder ('.homeworld-patch-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllBytes($temp, $edited)
        $tempHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($tempHash -ne [string]$data.patched_sha256) { throw 'Temporary file failed verification; original was not replaced.' }
        $currentHash = (Get-FileHash -LiteralPath $GameExePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currentHash -ne [string]$data.source_sha256) { throw 'Game executable changed during patch preparation. Nothing replaced.' }
        [System.IO.File]::Replace($temp, $GameExePath, $backup)
    } finally {
        if ([System.IO.File]::Exists($temp)) { [System.IO.File]::Delete($temp) }
    }
    $finalHash = (Get-FileHash -LiteralPath $GameExePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $backupHash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($finalHash -ne [string]$data.patched_sha256 -or $backupHash -ne [string]$data.source_sha256) {
        throw "Post-install verification failed. Stop here; restore the original using the backup: $backup"
    }
    Write-Host ''
    Write-Host 'SUCCESS! Homeworld 1 Classic is patched.' -ForegroundColor Green
    Write-Host "Backup: $backup"
    Write-Host "Patched SHA-256: $finalHash"
    Write-Host 'To undo: exit the game, delete patched Homeworld.exe, and rename your .bak file to Homeworld.exe.'
} catch {
    Write-Host ''
    Write-Host "PATCH NOT COMPLETED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Nothing should be replaced unless both game and patch were validated.'
    exit 1
}
