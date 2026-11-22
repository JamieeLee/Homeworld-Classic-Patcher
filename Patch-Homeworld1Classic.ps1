# HOMEWORLD 1 CLASSIC 2.303 PORTABLE PATCHER
# Readable PowerShell; no networking, downloads, registry edits, admin rights, or extra executables.
# Verifies the exact stock Homeworld.exe before modification, creates a backup, and checks result.
param([string]$GameExePath, [switch]$ListDetected, [switch]$RestoreOriginal)
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
            $property = $reg.PSObject.Properties[$propertyName]
            if ($null -eq $property) { continue }
            $value = [string]$property.Value
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
# Only read existing GOG configuration; never change game or registry settings.
# A candidate is accepted for patching only if its EXE matches the exact 2.303 hash.
function Get-GogExeFromLocation([string]$Location) {
    if ([string]::IsNullOrWhiteSpace($Location)) { return $null }
    try {
        $folder = [Environment]::ExpandEnvironmentVariables($Location.Trim().Trim('"'))
        if ($folder -match '(?i)\.exe$') { $folder = Split-Path -Path $folder -Parent }
        foreach ($relative in @(
            'Homeworld1Classic\exe\Homeworld.exe',
            'exe\Homeworld.exe',
            'Homeworld.exe'
        )) {
            $exe = Join-Path $folder $relative
            if (Test-Path -LiteralPath $exe -PathType Leaf) {
                return [System.IO.Path]::GetFullPath($exe)
            }
        }
    } catch { return $null }
    return $null
}
function Find-GogHomeworldExe {
    $locations = New-Object 'System.Collections.Generic.List[string]'

    # GOG Galaxy and offline installers may register different roots/values.
    foreach ($registryRoot in @(
        'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games',
        'HKLM:\SOFTWARE\GOG.com\Games',
        'HKCU:\SOFTWARE\GOG.com\Games',
        'HKCU:\SOFTWARE\WOW6432Node\GOG.com\Games'
    )) {
        try { $gameKeys = @(Get-ChildItem -LiteralPath $registryRoot -ErrorAction Stop) }
        catch { continue }
        foreach ($key in $gameKeys) {
            try { $game = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop }
            catch { continue }
            foreach ($field in @('path', 'workingDir', 'exe')) {
                $property = $game.PSObject.Properties[$field]
                if ($null -ne $property -and $property.Value -is [string] -and
                    -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                    $locations.Add([string]$property.Value)
                }
            }
        }
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    foreach ($programFilesRoot in @($programFilesX86, $env:ProgramFiles)) {
        if ([string]::IsNullOrWhiteSpace($programFilesRoot)) { continue }
        foreach ($folder in @(
            'GOG Galaxy\Games\Homeworld Remastered Collection',
            'GOG Galaxy\Games\Homeworld Remastered'
        )) { $locations.Add((Join-Path $programFilesRoot $folder)) }
    }

    # Conventional GOG standalone/Galaxy folders on fixed drives.
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        try {
            if ($drive.DriveType -ne [System.IO.DriveType]::Fixed -or -not $drive.IsReady) { continue }
            $driveRoot = $drive.RootDirectory.FullName
            foreach ($folder in @(
                'GOG Games\Homeworld Remastered Collection',
                'GOG Games\Homeworld Remastered',
                'Games\GOG\Homeworld Remastered Collection',
                'Games\Homeworld Remastered Collection'
            )) { $locations.Add((Join-Path $driveRoot $folder)) }
        } catch { continue }
    }

    $found = @()
    foreach ($location in @($locations | Select-Object -Unique)) {
        $exe = Get-GogExeFromLocation $location
        if ($null -ne $exe) { $found += $exe }
    }
    return @($found | Select-Object -Unique)
}
function Find-GameInstallations {
    $candidates = @()
    foreach ($exe in @(Find-SteamHomeworldExe)) {
        $candidates += [pscustomobject]@{ Store = 'Steam'; Path = [string]$exe }
    }
    foreach ($exe in @(Find-GogHomeworldExe)) {
        $candidates += [pscustomobject]@{ Store = 'GOG'; Path = [string]$exe }
    }
    $unique = @()
    $seen = @{}
    foreach ($item in $candidates) {
        if ([string]::IsNullOrWhiteSpace($item.Path) -or $seen.ContainsKey($item.Path)) { continue }
        $seen[$item.Path] = $true
        $unique += $item
    }
    return $unique
}
function Resolve-GameExePath {
    $candidates = @(Find-GameInstallations)
    if ($candidates.Count -eq 0) {
        Write-Host 'No Steam or GOG Homeworld 1 Classic executable automatically found.' -ForegroundColor Yellow
    }
    foreach ($candidate in $candidates) {
        Write-Host ''
        Write-Host "$($candidate.Store) installation detected:" -ForegroundColor Cyan
        Write-Host "  $($candidate.Path)"
        $choice = (Read-Host 'Use this executable? Type Y to confirm, or N to try the next/browse').Trim()
        if ($choice -match '^(?i:y|yes)$') { return $candidate.Path }
    }
    Write-Host 'Choose Homeworld.exe manually. Only the exact supported SHA-256 will be patched.'
    return Select-GameExe
}
# Restore by copying the verified stock backup over the patched executable.
# The original .bak stays untouched so the user can recover again if necessary.
function Restore-OriginalHomeworldExe([string]$ExePath, $PatchData) {
    $expectedOriginal = ([string]$PatchData.source_sha256).ToLowerInvariant()
    $expectedPatched = ([string]$PatchData.patched_sha256).ToLowerInvariant()
    $presentHash = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($presentHash -eq $expectedOriginal) {
        Write-Host 'Homeworld.exe is already the verified original. Nothing to restore.' -ForegroundColor Green
        return
    }
    if ($presentHash -ne $expectedPatched) {
        throw "Restore refused. The current Homeworld.exe is neither the supported patched EXE nor the original. Actual SHA-256: $presentHash. No files changed."
    }
    if (Get-Process -Name 'Homeworld' -ErrorAction SilentlyContinue) {
        throw 'Homeworld is running. Close the game before restoring the original.'
    }

    $folder = [System.IO.Path]::GetDirectoryName($ExePath)
    $backups = @(Get-ChildItem -LiteralPath $folder -Filter 'Homeworld.exe.original-2.303-*.bak' -File |
        Sort-Object LastWriteTime -Descending)
    $verifiedBackup = $null
    foreach ($candidate in $backups) {
        try {
            $candidateHash = (Get-FileHash -LiteralPath $candidate.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($candidateHash -eq $expectedOriginal) {
                $verifiedBackup = $candidate
                break
            }
        } catch {
            continue
        }
    }
    if ($null -eq $verifiedBackup) {
        throw 'Restore refused: no backup matches the exact stock 2.303 SHA-256. Nothing changed. Keep your files and use game-file verification if needed.'
    }

    Write-Host ''
    Write-Host 'Verified original backup:' -ForegroundColor Cyan
    Write-Host "  $($verifiedBackup.FullName)"
    Write-Host 'The existing patched Homeworld.exe will be replaced with this verified original.'
    Write-Host 'The .bak copy will be preserved.'
    $confirmation = (Read-Host 'Type RESTORE to continue, or anything else to cancel').Trim()
    if ($confirmation -cne 'RESTORE') {
        Write-Host 'Canceled. No files changed.'
        return
    }

    # Copy backup to a temporary file; atomically replace the EXE.
    # Never consume or delete the original backup.
    $temp = Join-Path $folder ('.homeworld-restore-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $rollback = Join-Path $folder ('.homeworld-patched-rollback-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::Copy($verifiedBackup.FullName, $temp)
        $tempHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($tempHash -ne $expectedOriginal) {
            throw 'Restore temporary copy failed hash verification. Game unchanged.'
        }
        $stillPatched = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($stillPatched -ne $expectedPatched) {
            throw 'Game executable changed during restore preparation. Nothing replaced.'
        }
        # .NET Framework requires an actual rollback path for File.Replace.
        # This temporarily saves the patched EXE until the restored hash is checked.
        [System.IO.File]::Replace($temp, $ExePath, $rollback)
    } finally {
        if ([System.IO.File]::Exists($temp)) { [System.IO.File]::Delete($temp) }
    }

    $restoredHash = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($restoredHash -ne $expectedOriginal) {
        throw "Restore verification failed. Original backup: $($verifiedBackup.FullName); temporary patched rollback: $rollback"
    }
    if ([System.IO.File]::Exists($rollback)) {
        try { [System.IO.File]::Delete($rollback) }
        catch { Write-Warning "Restore succeeded, but the temporary patched rollback could not be removed: $rollback" }
    }
    Write-Host ''
    Write-Host 'SUCCESS! Original Homeworld.exe restored.' -ForegroundColor Green
    Write-Host "Original backup preserved: $($verifiedBackup.FullName)"
    Write-Host "Restored SHA-256: $restoredHash"
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
    if ($ListDetected) {
        foreach ($installation in @(Find-GameInstallations)) {
            Write-Output "$($installation.Store)|$($installation.Path)"
        }
        exit 0
    }
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
    if ($RestoreOriginal) {
        Restore-OriginalHomeworldExe -ExePath $GameExePath -PatchData $data
        exit 0
    }
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
    Write-Host 'To undo: run this launcher again and select Restore Original.'
} catch {
    Write-Host ''
    Write-Host "OPERATION NOT COMPLETED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'No replacement occurs unless the required hashes and files have been verified.'
    exit 2
}
