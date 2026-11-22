# Homeworld 1 Classic — Portable Patcher

An **unofficial, portable patcher for Homeworld 1 Classic build 2.303** included with *Homeworld Remastered Collection* on Steam.

## What it does

This patcher updates **your installed copy** of `Homeworld.exe` with 74 targeted byte changes to:

- Address unreliable **fighter and corvette docking** behavior.
- Improve **widescreen aspect-ratio handling**.
- Enable **higher display resolutions**, including 2560×1440, by changing resolution detection and limits.
- Apply related movement-calculation and Windows settings-compatibility changes.

It works **offline**, does not include a copy of the game, and does not require installing a separate application. Docking behavior can be intermittent, so the docking correction is still undergoing extended gameplay testing.

> **Supported game:** Homeworld **1 Classic build 2.303** only. Not Homeworld 1 Remastered, Homeworld 2, Homeworld 3, or other Classic builds.

## How it works

1. **Finds the game:** Locates Steam installations, including additional Steam library folders, and shows the detected executable path for your approval. A manual file picker is available if needed.
2. **Checks compatibility:** Verifies the original `Homeworld.exe` SHA-256 and all 74 expected byte sequences before modifying anything.
3. **Makes a backup:** Preserves your original executable beside the game file.
4. **Applies the patch:** Writes the byte changes to your own `Homeworld.exe`.
5. **Verifies the result:** Checks the patched executable's SHA-256 against the expected result.

If the executable does not match the supported version, the patcher refuses to modify it. All patch offsets and replacement bytes are documented in `patches.json`, and the patching logic is available in the PowerShell source.

## Installation

1. Install *Homeworld Remastered Collection*, including **Homeworld 1 Classic**.
2. Download the release ZIP and extract the entire archive into one folder.
3. Double-click `RUN_PATCHER.cmd` on Windows.
4. The patcher searches Steam installation paths and additional library folders for *Homeworld Remastered Collection* (AppID `244160`), shows the full detected `Homeworld.exe` path, and asks for `Y` confirmation. If it can't find the game, or you decline the proposed path, it opens a file picker for `Homeworld1Classic\exe\Homeworld.exe`.
5. Confirm only after its stock SHA-256 verifies. Type `YES` to patch.
6. The patcher creates a timestamped backup beside the original file.

Steam detection only reads existing Steam registry installation paths, `libraryfolders.vdf`, and `appmanifest_244160.acf`. It doesn't modify Steam settings. **Original CD-ROM versions aren't supported unless their EXE happens to match the exact verified 2.303 SHA-256.** Otherwise, they are safely refused.

Requires the built-in Windows PowerShell, not Python. The patcher runs offline using the files included in the release ZIP. PowerShell's execution-policy override is limited to the spawned process; it is not a permanent change to your system settings.

## Supported hashes

| File state | SHA-256 |
| --- | --- |
| Stock HW1 Classic 2.303 `Homeworld.exe` | `421c114e832c56bd1994fe97c342969ef69881bb74399e67bef979c6923df381` |
| Patched HW1 Classic 2.303 `Homeworld.exe` | `166c3a23a0eeb5789823602b2571be98ae926a9447376c4b843ac0d1179884fb` |

This kit refuses unknown builds or modified files rather than guessing offsets.

## Restore the original

Close the game, remove or rename the modified `Homeworld.exe`, then rename the `.bak` file that the patcher created back to `Homeworld.exe`. Steam's Verify Integrity of Game Files can also restore stock files, potentially undoing any patches.

## Testing status — v0.1.1

- Original stock EXE and all 74 patch sites matched the expected bytes.
- Independent recomputation of the resulting file matched the expected patched SHA-256, byte for byte.
- User reported that the patcher launched and the patched game started at **2560×1440**.
- **Intermittent docking bug is not yet conclusively validated over repeated gameplay runs.**
- Steam auto-detection was added in v0.1.1 and hasn't yet been checked across multiple real Steam library configurations. Manual browsing remains available.
- The script has not been fully regression-tested across Windows installations or Steam updates.

## Files

- `RUN_PATCHER.cmd` — double-click launcher
- `Patch-Homeworld1Classic.ps1` — readable patching script
- `patches.json` — 74 explicit offset/byte modifications and checksums
- `README.md` — source documentation

## Credits

Original docking, widescreen, and resolution fixes: **Lou the Lou** — [HW1 Classic Docking Fix + Widescreen Support](https://www.nexusmods.com/homeworldremastered/mods/10).

## Project information

This unofficial community tool packages the fixes as verified byte patches that users apply to **their own** Homeworld 1 Classic executable. It is not affiliated with Gearbox, Blackbird Interactive, Valve, or Nexus Mods. Homeworld and related names are trademarks of their respective owners.

Permission to distribute the patch data was confirmed by the repository maintainer. No game executable is included, and no repository-wide software license has been selected.
