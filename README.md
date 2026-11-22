# Homeworld 1 Classic — Portable Patcher

An **unofficial, portable patcher for Homeworld 1 Classic build 2.303** included with *Homeworld Remastered Collection* on **Steam or GOG**.

**Releases and project history:** [CHANGELOG.md](CHANGELOG.md) — one running log for every version.

**Downloads:** [GitHub Releases](https://github.com/JamieeLee/Homeworld-Classic-Patcher/releases). Open the version you want and expand **Assets** for the patcher ZIP and checksum; pre-releases don't appear as the latest stable release.

## What it does

This patcher updates **your installed copy** of `Homeworld.exe` with 74 targeted byte changes to:

- Address unreliable **fighter and corvette docking** behavior.
- Improve **widescreen aspect-ratio handling**.
- Enable **higher display resolutions**, including 2560×1440, by changing resolution detection and limits.
- Apply related movement-calculation and Windows settings-compatibility changes.

It works **offline**, does not include a copy of the game, and does not require installing a separate application. Docking behavior can be intermittent, so the docking correction is still undergoing extended gameplay testing.

> **Supported game:** Homeworld **1 Classic build 2.303** only. Not Homeworld 1 Remastered, Homeworld 2, Homeworld 3, or other Classic builds.

## Why we patch these parts of the game

These are **specific problems in the Classic executable**, not cosmetic changes or unrelated tweaks:

| Area | What goes wrong without the patch | What our patch changes |
| --- | --- | --- |
| **Docking and collision avoidance** | Some floating-point absolute-value calculations were compiled using integer conversions. Small values can get truncated, preventing the AI from recognizing an obstructed approach. Fighters and corvettes may circle the Kushan Mothership instead of docking. | Restores floating-point absolute-value behavior in avoidance calculations. |
| **Flight and camera calculations** | The same float-to-integer conversion issue occurs in other flight, movement, and camera calculations. | Corrects the affected absolute-value operations at their known locations. |
| **Available resolutions** | The Classic video menu uses a small legacy resolution whitelist and a 1600-pixel width limit. | Removes those restrictions so the game can list resolutions reported by the display driver, including widescreen modes. |
| **Widescreen movement orders** | The cursor-to-world calculation assumes a 4:3 display, so a ship's move destination can appear somewhere other than where you point. | Adjusts the calculation for the actual aspect ratio and updates the projection when you change resolution in-game. |
| **Windows settings and first launch** | The game tries to store settings under the machine-wide Windows registry location, where normal users often lack write access; older defaults can also force 640×480 and 16-bit color. | Changes the **game's own** settings location to the current user's registry area, uses desktop-sized initial settings, and defaults to 32-bit color. |

**What the patcher itself touches:** It reads existing Steam/GOG installation information to find the game, verifies the exact EXE, then modifies **only your selected `Homeworld.exe`** after making a backup. It does **not** write to the Windows registry. The **patched game**, however, will use `HKEY_CURRENT_USER\SOFTWARE\Sierra On-Line\Homeworld` for its settings. Old settings in the machine-wide registry location are **not automatically copied**, so you may need to choose your preferred video settings again.

**See every individual change:** [`PATCH_REFERENCE.md`](PATCH_REFERENCE.md) explains all **74 file offsets**, their exact before-and-after bytes, and their technical purpose. [`patches.json`](patches.json) is the patcher's authoritative machine-readable manifest. This makes it possible to check what we're changing without trusting a vague description.

## How it works

1. **Finds the game:** Searches Steam libraries and GOG installation locations, then shows the store and exact executable path for your approval. A manual file picker is available if needed.
2. **Checks compatibility:** Verifies the original `Homeworld.exe` SHA-256 and all 74 expected byte sequences before modifying anything.
3. **Makes a backup:** Preserves your original executable beside the game file.
4. **Applies the patch:** Writes the byte changes to your own `Homeworld.exe`.
5. **Verifies the result:** Checks the patched executable's SHA-256 against the expected result.

If the executable does not match the supported version, the patcher refuses to modify it. All patch offsets and replacement bytes are documented in `patches.json`, and the patching logic is available in the PowerShell source.

## Installation

1. Install *Homeworld Remastered Collection*, including **Homeworld 1 Classic**.
2. Download the release ZIP and extract the entire archive into one folder.
3. Double-click `RUN_PATCHER.cmd` on Windows and choose **1. Install Patch**.
4. The patcher searches Steam libraries and GOG installation folders, labels each detected candidate **Steam** or **GOG**, shows the full `Homeworld.exe` path, and asks for `Y` confirmation. If no match is found, or you decline every path, it opens a file picker for `Homeworld1Classic\exe\Homeworld.exe`.
5. Confirm only after its stock SHA-256 verifies. Type `YES` to patch.
6. The patcher keeps **one verified original backup** beside the game as `Homeworld.exe.original-2.303.bak`. Reinstalling after a restore reuses this backup instead of making another copy. When a backup is first created, its **Date modified** reflects the time it was saved, not the older date on the stock game file.

Steam discovery reads the existing Steam registry locations, `libraryfolders.vdf`, and `appmanifest_244160.acf` (AppID `244160`). GOG discovery reads existing GOG installation registry paths and checks standard GOG/Galaxy folders on fixed drives. Detection does not change Steam or GOG settings. **Other game builds, including different CD-ROM and GOG EXEs, are refused unless they match the exact verified 2.303 SHA-256.**

Requires the built-in Windows PowerShell, not Python. The patcher runs offline using the files included in the release ZIP. **It uses your normal PowerShell execution policy by default.** If Windows blocks script execution, the launcher explains the situation and **asks** whether to retry with a temporary `-ExecutionPolicy Bypass` for that one run. **No bypass happens without a Y answer.** Choosing **N** leaves the policy untouched so you can address it manually. This does not change the system's persistent execution-policy settings. Organization-managed policies may prohibit an override.

## Supported hashes

| File state | SHA-256 |
| --- | --- |
| Stock HW1 Classic 2.303 `Homeworld.exe` | `421c114e832c56bd1994fe97c342969ef69881bb74399e67bef979c6923df381` |
| Patched HW1 Classic 2.303 `Homeworld.exe` | `166c3a23a0eeb5789823602b2571be98ae926a9447376c4b843ac0d1179884fb` |

This kit refuses unknown builds or modified files rather than guessing offsets.

## Restore the original

Close Homeworld, then run **`RUN_PATCHER.cmd`** and choose **2. Restore Original EXE**. The patcher locates your Steam or GOG installation (or lets you browse), then:

1. Confirms that `Homeworld.exe` matches the exact supported **patched** SHA-256.
2. Locates the verified `Homeworld.exe.original-2.303.bak`, or a compatible older timestamped backup if no reusable backup exists.
3. Shows the selected backup and requires you to type **`RESTORE`**.
4. Copies the original bytes back into `Homeworld.exe`, atomically replaces the patched file, and verifies the result. The verified original backup is **preserved**.

No reverse-patching of individual bytes is performed. Unknown or modified EXEs and invalid/missing backups are refused.

## Clean up older backups

If you patched and restored with earlier versions, your game folder may contain several files named `Homeworld.exe.original-2.303-<date>-<id>.bak`. Those files can have an older **Date modified** because they inherited the date of the stock EXE even though their names show when the backup was made.

Run **`RUN_PATCHER.cmd`**, choose **3. Clean Up Backups**, and confirm by typing **`CLEAN`**. The patcher verifies the stock-file SHA-256 of each recognized backup, saves one reusable `Homeworld.exe.original-2.303.bak` with the current backup timestamp, and removes only verified duplicate files. **Unknown, altered, or unverified files remain untouched.** Declining the prompt does not change anything.

Future install/restore cycles reuse the same backup and **do not keep resetting its timestamp**. Only a newly created backup gets a new **Date modified**. This housekeeping does not change game settings or patch bytes.

Steam's **Verify integrity of game files** can also restore stock binaries, but it may undo other changes.

## Testing status — v0.1.2

- Original stock EXE and all 74 patch sites matched the expected bytes.
- Independent recomputation of the resulting file matched the expected patched SHA-256, byte for byte.
- User reported that the patcher launched and the patched game started at **2560×1440**.
- **Intermittent docking bug is not yet conclusively validated over repeated gameplay runs.**
- Steam detection (v0.1.1) and GOG detection (v0.1.2) are checked using synthetic Windows installation fixtures; **real GOG/Steam configurations still need additional user testing**. Manual browsing remains available.
- The script has not been fully regression-tested across Windows installations or Steam updates.

## Files

- `RUN_PATCHER.cmd` — double-click launcher
- `Patch-Homeworld1Classic.ps1` — readable install and verified-backup restore script
- `patches.json` — 74 explicit offset/byte modifications and checksums
- `CHANGELOG.md` — one ongoing release and development history
- `PATCH_REFERENCE.md` — purpose, offsets, and exact bytes for all 74 patches
- `THIRD_PARTY_NOTICES.md` — original source copyright and license notices
- `LICENSE` — MIT license for this project
- `tests/Windows-SmokeTests.ps1` — Windows fixture tests (in repository, not needed to run the patcher)
- `README.md` — source documentation

## Credits

Original docking, widescreen, and resolution fixes: **Lou the Lou** — [HW1 Classic Docking Fix + Widescreen Support](https://www.nexusmods.com/homeworldremastered/mods/10).

## Project information

This unofficial community tool packages the fixes as verified byte patches that users apply to **their own** Homeworld 1 Classic executable. It is not affiliated with Gearbox, Blackbird Interactive, Valve, or Nexus Mods. Homeworld and related names are trademarks of their respective owners.

The project is licensed under **MIT** (see [`LICENSE`](LICENSE)). The patch data incorporates MIT-licensed research and definitions; its original copyright and license notice are preserved in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). No game executable is included. For a complete technical breakdown, see [`PATCH_REFERENCE.md`](PATCH_REFERENCE.md).
