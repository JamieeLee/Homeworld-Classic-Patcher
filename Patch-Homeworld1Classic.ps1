# HOMEWORLD 1 CLASSIC 2.303 PORTABLE PATCHER
# Readable PowerShell; no networking, downloads, registry edits, admin rights, or extra executables.
# Verifies the exact stock Homeworld.exe before modification, creates a backup, and checks result.
param([string]$GameExePath, [switch]$ListDetected, [switch]$RestoreOriginal, [switch]$CleanBackups)
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
# Use one stable, verified backup rather than accumulating timestamped files.
# Legacy timestamped backups are recognized, but never deleted without explicit consent.
function Get-StockBackupInventory([string]$Folder, [string]$ExpectedHash) {
    $items = @()
    foreach ($candidate in @(Get-ChildItem -LiteralPath $Folder -Filter 'Homeworld.exe.original-2.303*.bak' -File)) {
        $isCanonical = $candidate.Name -ieq 'Homeworld.exe.original-2.303.bak'
        if (-not $isCanonical -and
            $candidate.Name -notmatch '(?i)^Homeworld\.exe\.original-2\.303-\d{8}-\d{6}-[0-9a-f]{8}\.bak$') {
            continue
        }
        # Reparse points could lead outside the selected game's directory; never use/delete them.
        if (($candidate.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $valid = $false
        try {
            $valid = (Get-FileHash -LiteralPath $candidate.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ExpectedHash
        } catch { $valid = $false }
        $items += [pscustomobject]@{
            File = $candidate
            Canonical = $isCanonical
            Valid = $valid
        }
    }
    return $items
}
function Ensure-StockBackup([string]$ExePath, [string]$ExpectedHash) {
    $folder = [System.IO.Path]::GetDirectoryName($ExePath)
    $canonical = Join-Path $folder 'Homeworld.exe.original-2.303.bak'
    $backups = @(Get-StockBackupInventory -Folder $folder -ExpectedHash $ExpectedHash)
    if (Test-Path -LiteralPath $canonical) {
        $existing = @($backups | Where-Object { $_.Canonical -and $_.Valid })
        if ($existing.Count -ne 1) {
            throw "A backup already exists but is invalid or inaccessible: $canonical. Nothing was overwritten."
        }
        return $canonical
    }
    $legacy = @($backups | Where-Object { $_.Valid -and -not $_.Canonical } |
        Sort-Object { $_.File.LastWriteTimeUtc } -Descending)
    $backupSource = $ExePath
    if ($legacy.Count -gt 0) { $backupSource = $legacy[0].File.FullName }
    if ((Get-FileHash -LiteralPath $backupSource -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) {
        throw 'No verified original EXE is available to preserve. Nothing changed.'
    }
    # No overwrite: if another process created this path, File.Copy must fail safely.
    [System.IO.File]::Copy($backupSource, $canonical, $false)
    if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) {
        throw "New backup did not verify. Stop here and inspect: $canonical"
    }
    return $canonical
}
function Clean-StockBackupDuplicates([string]$ExePath, $PatchData) {
    $expected = ([string]$PatchData.source_sha256).ToLowerInvariant()
    $current = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($current -ne $expected -and $current -ne ([string]$PatchData.patched_sha256).ToLowerInvariant()) {
        throw "Cleanup refused: selected Homeworld.exe is not a supported original or patched build. No files changed."
    }
    $folder = [System.IO.Path]::GetDirectoryName($ExePath)
    $canonical = Join-Path $folder 'Homeworld.exe.original-2.303.bak'
    $backups = @(Get-StockBackupInventory -Folder $folder -ExpectedHash $expected)
    if ((Test-Path -LiteralPath $canonical) -and
        @($backups | Where-Object { $_.Canonical -and $_.Valid }).Count -ne 1) {
        throw "Backup cleanup refused because the canonical backup is invalid or inaccessible: $canonical"
    }
    $legacyValid = @($backups | Where-Object { $_.Valid -and -not $_.Canonical } |
        Sort-Object { $_.File.LastWriteTimeUtc } -Descending)
    $skipped = @($backups | Where-Object { -not $_.Valid }).Count
    if ($legacyValid.Count -eq 0) {
        Write-Host 'No duplicate verified original backups to clean.' -ForegroundColor Green
        if ($skipped -gt 0) { Write-Warning "$skipped unverified backup(s) were left untouched." }
        return
    }
    Write-Host ''
    Write-Host "Found $($legacyValid.Count) older backup(s) matching the exact stock SHA-256:" -ForegroundColor Cyan
    foreach ($item in $legacyValid) { Write-Host "  $($item.File.Name)" }
    Write-Host "Keep one backup as: $canonical"
    if ($skipped -gt 0) { Write-Warning "$skipped unverified backup(s) will NOT be touched." }
    $answer = (Read-Host 'Type CLEAN to consolidate these verified copies, or anything else to cancel').Trim()
    if ($answer -cne 'CLEAN') {
        Write-Host 'Canceled. No backups changed.'
        return
    }
    # Preserve a verified canonical copy BEFORE deleting any legacy file.
    if (-not (Test-Path -LiteralPath $canonical)) {
        [System.IO.File]::Copy($legacyValid[0].File.FullName, $canonical, $false)
    }
    if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
        throw 'Canonical backup failed verification. No older backups were deleted.'
    }
    $removed = 0
    foreach ($item in $legacyValid) {
        try {
            # Recheck hashes and file attributes immediately before each deletion.
            $fresh = Get-Item -LiteralPath $item.File.FullName -ErrorAction Stop
            if (($fresh.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            if ((Get-FileHash -LiteralPath $fresh.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { continue }
            if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
                throw 'Canonical backup changed; stopping cleanup.'
            }
            [System.IO.File]::Delete($fresh.FullName)
            $removed++
        } catch {
            Write-Warning "Could not remove $($item.File.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "Cleanup complete: $removed verified duplicate(s) removed. Original backup kept: $canonical" -ForegroundColor Green
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
    $inventory = @(Get-StockBackupInventory -Folder $folder -ExpectedHash $expectedOriginal)
    $verifiedBackups = @($inventory | Where-Object { $_.Valid } |
        Sort-Object -Property @{ Expression = 'Canonical'; Descending = $true },
        @{ Expression = { $_.File.LastWriteTimeUtc }; Descending = $true })
    $verifiedBackup = $null
    if ($verifiedBackups.Count -gt 0) { $verifiedBackup = $verifiedBackups[0].File }
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
    if ($CleanBackups) {
        Clean-StockBackupDuplicates -ExePath $GameExePath -PatchData $data
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

    # Keep one stable original backup. Repeated install/restore cycles reuse it.
    $folder = [System.IO.Path]::GetDirectoryName($GameExePath)
    if (Get-Process -Name 'Homeworld' -ErrorAction SilentlyContinue) {
        throw 'Homeworld is running. Close the game before installing the patch.'
    }
    $backup = Ensure-StockBackup -ExePath $GameExePath -ExpectedHash ([string]$data.source_sha256)
    $temp = Join-Path $folder ('.homeworld-patch-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $rollback = Join-Path $folder ('.homeworld-stock-rollback-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllBytes($temp, $edited)
        $tempHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($tempHash -ne [string]$data.patched_sha256) {
            throw 'Temporary patched EXE failed verification; original was not replaced.'
        }
        $currentHash = (Get-FileHash -LiteralPath $GameExePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currentHash -ne [string]$data.source_sha256) {
            throw 'Game executable changed during patch preparation. Nothing replaced.'
        }
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$data.source_sha256) {
            throw 'Original backup changed during patch preparation. Nothing replaced.'
        }
        # Windows requires a real rollback path for File.Replace.
        [System.IO.File]::Replace($temp, $GameExePath, $rollback)
    } finally {
        if ([System.IO.File]::Exists($temp)) { [System.IO.File]::Delete($temp) }
    }
    $finalHash = (Get-FileHash -LiteralPath $GameExePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $backupHash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($finalHash -ne [string]$data.patched_sha256 -or $backupHash -ne [string]$data.source_sha256) {
        throw "Post-install verification failed. Original backup: $backup; temporary rollback: $rollback"
    }
    if ([System.IO.File]::Exists($rollback)) {
        try { [System.IO.File]::Delete($rollback) }
        catch { Write-Warning "Patching succeeded, but temporary rollback could not be removed: $rollback" }
    }
    Write-Host ''
    Write-Host 'SUCCESS! Homeworld 1 Classic is patched.' -ForegroundColor Green
    Write-Host "Backup: $backup"
    Write-Host "Patched SHA-256: $finalHash"
    Write-Host 'To undo: run this launcher again and select Restore Original.'
    Write-Host 'To remove older duplicate backups: select Clean Up Backups from the launcher.'
} catch {
    Write-Host ''
    Write-Host "OPERATION NOT COMPLETED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'No replacement occurs unless the required hashes and files have been verified.'
    exit 2
}
