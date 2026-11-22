# Homeworld 1 Classic — Portable Patcher

An **unofficial, offline, inspectable** byte-patch utility for **Homeworld 1 Classic build 2.303** as supplied with *Homeworld Remastered Collection*.

It applies the 74 byte modifications described by the original **HW1 Classic Docking Fix + Widescreen Support** mod. **Credit for discovering the gameplay and video fixes belongs to the original mod author, Lou the Lou.** This repository is an alternative *distribution mechanism* for the fixes, not a claim of authorship of the original reverse-engineering work.

Original mod: https://www.nexusmods.com/homeworldremastered/mods/10

> **Scope:** Homeworld **1 Classic only**. **Not** Homeworld 1 Remastered, Homeworld 2, or Homeworld 3.

## Why a readable patcher?

This package contains no game executable, no bundled third-party installer, and no downloaded payload. Its patch logic is a readable Windows PowerShell script, with all offsets and original/replacement bytes in `patches.json`. It verifies the exact stock executable before modification, writes a backup, and verifies the expected output SHA-256. The script is designed to exit without modifying incompatible builds.

**A readable script and checksums make auditing easier; they do not guarantee safety.** Review the contents before running, and back up important files.

## Installation

1. Install *Homeworld Remastered Collection*, including **Homeworld 1 Classic**.
2. Download the release ZIP and extract the entire archive into one folder.
3. Double-click `RUN_PATCHER.cmd` on Windows.
4. The patcher searches Steam installation paths and additional library folders for *Homeworld Remastered Collection* (AppID `244160`), shows the full detected `Homeworld.exe` path, and asks for `Y` confirmation. If it can't find the game, or you decline the proposed path, it opens a file picker for `Homeworld1Classic\exe\Homeworld.exe`.
5. Confirm only after its stock SHA-256 verifies. Type `YES` to patch.
6. The patcher creates a timestamped backup beside the original file.

Steam detection only reads existing Steam registry installation paths, `libraryfolders.vdf`, and `appmanifest_244160.acf`. It doesn't modify Steam settings. **Original CD-ROM versions aren't supported unless their EXE happens to match the exact verified 2.303 SHA-256.** Otherwise, they are safely refused.

Requires the built-in Windows PowerShell, not Python. It does not need internet access or to execute the original author's installer. PowerShell's execution-policy override is limited to the spawned process; it is not a permanent change to your system settings.

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

## Attribution and independence

This is an unofficial community packaging of patches originating from the **HW1 Classic Docking Fix + Widescreen Support** project by **Lou the Lou**. No affiliation with Gearbox, Blackbird Interactive, Valve, or Nexus Mods. Homeworld and related names are trademarks of their respective owners. The game executable is **not** redistributed here.

## License

The original mod author has given permission for this alternative patch packaging, as confirmed by the repository maintainer. This does **not** grant a general license to redistribute the original mod or claim authorship of its fixes. No repository-wide software license has been selected yet.
