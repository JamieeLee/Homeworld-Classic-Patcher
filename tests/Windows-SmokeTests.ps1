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
