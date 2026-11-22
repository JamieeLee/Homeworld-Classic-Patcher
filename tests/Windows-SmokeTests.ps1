# Windows smoke tests for store detection and strict hash refusal.
# Creates temporary fake installations and registry fixtures; no game files used.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$patcher = Join-Path $repo 'Patch-Homeworld1Classic.ps1'
$fixtureRoot = Join-Path $env:TEMP ('hw1-patcher-fixtures-' + [guid]::NewGuid().ToString('N'))
$gogKey = 'HKCU:\SOFTWARE\GOG.com\Games\HW1PatcherFixture'
$steamKey = 'HKCU:\Software\Valve\Steam'
$steamKeyPreviouslyExisted = Test-Path -LiteralPath $steamKey
$priorSteamPathExists = $false
$priorSteamPath = $null
if ($steamKeyPreviouslyExisted) {
    $steamProperties = Get-ItemProperty -LiteralPath $steamKey
    $priorSteamPathExists = $null -ne $steamProperties.PSObject.Properties['SteamPath']
    if ($priorSteamPathExists) { $priorSteamPath = [string]$steamProperties.SteamPath }
}
try {
    $gogRoot = Join-Path $fixtureRoot 'GOG Custom\Homeworld Remastered Collection'
    $gogExe = Join-Path $gogRoot 'Homeworld1Classic\exe\Homeworld.exe'
    New-Item -ItemType Directory -Path (Split-Path $gogExe -Parent) -Force | Out-Null
    [IO.File]::WriteAllBytes($gogExe, [byte[]](1, 2, 3, 4, 5))
    New-Item -Path $gogKey -Force | Out-Null
    New-ItemProperty -Path $gogKey -Name path -PropertyType String -Value $gogRoot -Force | Out-Null

    $steamRoot = Join-Path $fixtureRoot 'Steam Root'
    $steamLibrary = Join-Path $fixtureRoot 'Another Steam Library'
    $steamExe = Join-Path $steamLibrary 'steamapps\common\Homeworld\Homeworld1Classic\exe\Homeworld.exe'
    New-Item -ItemType Directory -Path (Join-Path $steamRoot 'steamapps') -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $steamExe -Parent) -Force | Out-Null
    [IO.File]::WriteAllBytes($steamExe, [byte[]](8, 9, 10))
    $vdfPath = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
    $escapedLibrary = $steamLibrary.Replace('\', '\\')
    $vdfText = '"libraryfolders"' + [Environment]::NewLine +
        '{' + [Environment]::NewLine +
        '    "1"' + [Environment]::NewLine +
        '    {' + [Environment]::NewLine +
        '        "path" "' + $escapedLibrary + '"' + [Environment]::NewLine +
        '    }' + [Environment]::NewLine +
        '}'
    [IO.File]::WriteAllText($vdfPath, $vdfText)
    $manifest = '"AppState"' + [Environment]::NewLine + '{' + [Environment]::NewLine +
        '    "appid" "244160"' + [Environment]::NewLine +
        '    "installdir" "Homeworld"' + [Environment]::NewLine + '}'
    [IO.File]::WriteAllText((Join-Path $steamLibrary 'steamapps\appmanifest_244160.acf'), $manifest)

    New-Item -Path $steamKey -Force | Out-Null
    New-ItemProperty -Path $steamKey -Name SteamPath -Value $steamRoot -PropertyType String -Force | Out-Null

    # Discover via real Windows PowerShell without overriding the local execution policy.
    $found = @(& powershell.exe -NoProfile -File $patcher -ListDetected)
    if ($LASTEXITCODE -ne 0) { throw 'Detection command failed.' }
    # Windows may normalize an 8.3 path (RUNNER~1) to its long form;
    # compare the stable installation suffix and validate the actual target file.
    $gogMatches = @($found | Where-Object {
        $_.StartsWith('GOG|', [System.StringComparison]::OrdinalIgnoreCase) -and
        $_.EndsWith('\GOG Custom\Homeworld Remastered Collection\Homeworld1Classic\exe\Homeworld.exe', [System.StringComparison]::OrdinalIgnoreCase)
    })
    $steamMatches = @($found | Where-Object {
        $_.StartsWith('Steam|', [System.StringComparison]::OrdinalIgnoreCase) -and
        $_.EndsWith('\Another Steam Library\steamapps\common\Homeworld\Homeworld1Classic\exe\Homeworld.exe', [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($gogMatches.Count -ne 1 -or -not (Test-Path -LiteralPath $gogMatches[0].Substring(4) -PathType Leaf)) {
        throw ("GOG fixture was not found. Detected: " + ($found -join '; '))
    }
    if ($steamMatches.Count -ne 1 -or -not (Test-Path -LiteralPath $steamMatches[0].Substring(6) -PathType Leaf)) {
        throw ("Steam fixture was not found. Detected: " + ($found -join '; '))
    }
    Write-Host 'PASS: GOG registry path and Steam alternate-library path detected.'

    # Fake EXE must never be modified, even when passed directly.
    $before = (Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash
    $savedPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & powershell.exe -NoProfile -File $patcher -GameExePath $gogExe *> $null
        $refusalCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPref }
    if ($refusalCode -ne 2) { throw "Unsupported fake EXE was not refused with exit 2 (got $refusalCode)." }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash -ne $before) {
        throw 'Unsupported fake EXE changed!'
    }
    $backs = @(Get-ChildItem -LiteralPath (Split-Path $gogExe -Parent) -Filter '*.bak')
    if ($backs.Count -ne 0) { throw 'Unsupported fake EXE generated an unexpected backup.' }
    Write-Host 'PASS: Unrecognized Homeworld.exe refused with no mutation or backup.'
    # Restore tests use synthetic game bytes and a synthetic local manifest.
    # The published patches.json and the real game's executable are never modified.
    $restoreKit = Join-Path $fixtureRoot 'restore-test-kit'
    New-Item -ItemType Directory -Path $restoreKit -Force | Out-Null
    $restoreScript = Join-Path $restoreKit 'Patch-Homeworld1Classic.ps1'
    Copy-Item -LiteralPath $patcher -Destination $restoreScript
    [byte[]]$fakeOriginal = @(1, 2, 3, 4, 5)
    [byte[]]$fakePatched = @(8, 9, 10, 11, 12)
    $sourceHash = Get-FileHash -LiteralPath $gogExe -Algorithm SHA256
    $sourceHash = $sourceHash.Hash.ToLowerInvariant()
    [IO.File]::WriteAllBytes($gogExe, $fakePatched)
    $patchedHash = (Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant()

    $fixtureManifest = [pscustomobject]@{
        version = '2.303'
        patch_count = 74
        source_sha256 = $sourceHash
        patched_sha256 = $patchedHash
        source_size = 5
        patches = @(1..74 | ForEach-Object {
            [pscustomobject]@{ offset=0; old='01'; new='08'; group='dock' }
        })
    }
    $fixtureManifest | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $restoreKit 'patches.json') -Encoding UTF8

    $restoreBackup = Join-Path (Split-Path $gogExe -Parent) 'Homeworld.exe.original-2.303-20261122-000000-12345678.bak'

    # No usable backup: fail safely without modifying the patched EXE.
    $savedPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        'RESTORE' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -RestoreOriginal *> $null
        $missingBackupCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPref }
    if ($missingBackupCode -ne 2) { throw "Missing-backup restore did not fail (code: $missingBackupCode)." }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $patchedHash) {
        throw 'Restore modified the game despite missing backup.'
    }

    # A corrupt backup must never be used.
    [IO.File]::WriteAllBytes($restoreBackup, [byte[]](99, 98, 97))
    $savedPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        'RESTORE' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -RestoreOriginal *> $null
        $invalidBackupCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPref }
    if ($invalidBackupCode -ne 2) { throw "Invalid-backup restore did not fail (code: $invalidBackupCode)." }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $patchedHash) {
        throw 'Restore used an invalid backup.'
    }
    Write-Host 'PASS: Missing and corrupt backups were rejected safely.'

    [IO.File]::WriteAllBytes($restoreBackup, $fakeOriginal)
    # User cancellation leaves both EXE and backup intact.
    'NO' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -RestoreOriginal *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Cancel operation failed.' }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $patchedHash) {
        throw 'Restore ignored a cancellation.'
    }

    # Explicit consent restores original content, preserving the source backup.
    'RESTORE' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -RestoreOriginal
    if ($LASTEXITCODE -ne 0) { throw "Restore operation failed with exit code $LASTEXITCODE." }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHash) {
        throw 'Restored EXE does not match the original.'
    }
    if ((Get-FileHash -LiteralPath $restoreBackup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHash) {
        throw 'Restore removed or modified the original backup.'
    }
    Write-Host 'PASS: Cancel and verified original EXE restore; original backup preserved.'

    # Repeating restore with an already-original EXE does not overwrite anything.
    & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -RestoreOriginal *> $null
    if ($LASTEXITCODE -ne 0 -or
        (Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHash) {
        throw 'Restore was not idempotent.'
    }
    Write-Host 'PASS: Already-original EXE is an unchanged no-op.'

    # The following fixture exercises the *install* path with 74 non-overlapping changes,
    # without needing or modifying the real game executable.
    [byte[]]$stockBytes = New-Object byte[] 96
    [byte[]]$patchBytes = New-Object byte[] 96
    for ($i = 0; $i -lt 96; $i++) {
        $stockBytes[$i] = 0x11
        $patchBytes[$i] = 0x11
    }
    for ($i = 0; $i -lt 74; $i++) { $patchBytes[$i] = 0x22 }
    [IO.File]::WriteAllBytes($gogExe, $stockBytes)
    $testStockHash = (Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllBytes($gogExe, $patchBytes)
    $testPatchedHash = (Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllBytes($gogExe, $stockBytes)
    $installFixture = [pscustomobject]@{
        version = '2.303'
        patch_count = 74
        source_sha256 = $testStockHash
        patched_sha256 = $testPatchedHash
        source_size = 96
        patches = @(0..73 | ForEach-Object {
            [pscustomobject]@{ offset=$_; old='11'; new='22'; group='dock' }
        })
    }
    $installFixture | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $restoreKit 'patches.json') -Encoding UTF8

    # Remove the earlier 5-byte fixture backup and install from a clean directory.
    if (Test-Path -LiteralPath $restoreBackup) { Remove-Item -LiteralPath $restoreBackup -Force }
    $canonical = Join-Path (Split-Path $gogExe -Parent) 'Homeworld.exe.original-2.303.bak'
    if (Test-Path -LiteralPath $canonical) { throw 'Unexpected backup before first install.' }
    # Reproduce the reported scenario: a stock game file last modified days ago.
    $oldGameWriteTime = [DateTime]::SpecifyKind([DateTime]::Parse('2026-11-19T18:18:00'), [DateTimeKind]::Utc)
    [IO.File]::SetLastWriteTimeUtc($gogExe, $oldGameWriteTime)
    'YES' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe *> $null
    if ($LASTEXITCODE -ne 0) { throw "Initial install failed: $LASTEXITCODE" }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $testPatchedHash) {
        throw 'Initial install did not produce expected patched bytes.'
    }
    if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant() -ne $testStockHash) {
        throw 'Canonical backup missing or invalid after install.'
    }
    $backupWriteUtc = [IO.File]::GetLastWriteTimeUtc($canonical)
    if (([Math]::Abs(([DateTime]::UtcNow - $backupWriteUtc).TotalSeconds)) -gt 120) {
        throw "Backup still has an inherited old file timestamp: $backupWriteUtc"
    }
    Write-Host 'PASS: First install created one verified backup timestamped at backup creation.'

    # Restore then patch again: the same verified backup must be reused, no new legacy files.
    'RESTORE' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -RestoreOriginal *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic restore before reinstall failed.' }
    'YES' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Reinstall failed.' }
    if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant() -ne $testStockHash) {
        throw 'Canonical backup was overwritten or modified.'
    }
    if ([IO.File]::GetLastWriteTimeUtc($canonical) -ne $backupWriteUtc) {
        throw 'Reinstall unexpectedly reset the existing original backup timestamp.'
    }
    $timestampBackups = @(Get-ChildItem -LiteralPath (Split-Path $gogExe -Parent) -Filter 'Homeworld.exe.original-2.303-*.bak' -File)
    if ($timestampBackups.Count -ne 0) { throw 'Repeated installation created redundant timestamped backups.' }
    Write-Host 'PASS: Repeated restore/install cycles reuse one original backup.'

    # Simulate two old timestamped backups and one invalid backup in a pre-upgrade folder.
    $legacyFolder = Split-Path $gogExe -Parent
    $legacyA = Join-Path $legacyFolder 'Homeworld.exe.original-2.303-20261122-040437-76400f46.bak'
    $legacyB = Join-Path $legacyFolder 'Homeworld.exe.original-2.303-20261122-052759-5be55a04.bak'
    $legacyCorrupt = Join-Path $legacyFolder 'Homeworld.exe.original-2.303-20261122-060000-badbad12.bak'
    [IO.File]::WriteAllBytes($legacyA, $stockBytes)
    [IO.File]::WriteAllBytes($legacyB, $stockBytes)
    [IO.File]::WriteAllBytes($legacyCorrupt, [byte[]](1, 2, 3))
    [IO.File]::SetLastWriteTimeUtc($legacyA, $oldGameWriteTime)
    [IO.File]::SetLastWriteTimeUtc($legacyB, $oldGameWriteTime)
    Remove-Item -LiteralPath $canonical -Force

    # Cancellation does not create a canonical file or delete any old files.
    'NO' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -CleanBackups *> $null
    if ($LASTEXITCODE -ne 0 -or
        (Test-Path -LiteralPath $canonical) -or
        -not (Test-Path -LiteralPath $legacyA) -or
        -not (Test-Path -LiteralPath $legacyB)) {
        throw 'Cleanup cancellation modified backup files.'
    }
    Write-Host 'PASS: Declining cleanup preserves all backups.'

    # Explicit consent consolidates both verified legacy copies, preserving invalid data.
    'CLEAN' | & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -CleanBackups *> $null
    if ($LASTEXITCODE -ne 0) { throw "Backup cleanup failed: $LASTEXITCODE" }
    if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant() -ne $testStockHash) {
        throw 'Cleanup did not retain a verified canonical original.'
    }
    $cleanedBackupTime = [IO.File]::GetLastWriteTimeUtc($canonical)
    if (([Math]::Abs(([DateTime]::UtcNow - $cleanedBackupTime).TotalSeconds)) -gt 120) {
        throw "Consolidated backup has stale modification time: $cleanedBackupTime"
    }
    if ((Test-Path -LiteralPath $legacyA) -or (Test-Path -LiteralPath $legacyB)) {
        throw 'Cleanup failed to remove verified legacy duplicates.'
    }
    if (-not (Test-Path -LiteralPath $legacyCorrupt)) {
        throw 'Cleanup deleted an unverified legacy file.'
    }
    if ((Get-FileHash -LiteralPath $gogExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $testPatchedHash) {
        throw 'Cleanup modified the current game executable.'
    }
    Write-Host 'PASS: Old verified duplicates consolidated; invalid backup and game EXE left untouched.'

    # A second cleanup is an idempotent no-op; no new copies should appear.
    & powershell.exe -NoProfile -File $restoreScript -GameExePath $gogExe -CleanBackups *> $null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $canonical)) {
        throw 'Repeated cleanup failed.'
    }
    Write-Host 'PASS: Repeated cleanup is a no-op.'

    # The last native process intentionally exited 2; do not leak that into the CI shell.
    $global:LASTEXITCODE = 0
} finally {
    if ($priorSteamPathExists) {
        New-ItemProperty -Path $steamKey -Name SteamPath -PropertyType String -Value $priorSteamPath -Force | Out-Null
    } elseif (Test-Path -LiteralPath $steamKey) {
        Remove-ItemProperty -LiteralPath $steamKey -Name SteamPath -ErrorAction SilentlyContinue
    }
    if (-not $steamKeyPreviouslyExisted -and (Test-Path -LiteralPath $steamKey)) {
        Remove-Item -LiteralPath $steamKey -Recurse -Force
    }
    if (Test-Path -LiteralPath $gogKey) { Remove-Item -LiteralPath $gogKey -Recurse -Force }
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
