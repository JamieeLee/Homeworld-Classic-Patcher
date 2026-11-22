# Changelog

All notable changes to the **Homeworld 1 Classic Portable Patcher** are recorded here, in **one ongoing file**. New entries are added to the top; existing release history stays in place. The patcher supports only the exact verified Homeworld 1 Classic **2.303** executable.

## Unreleased

## [v0.1.3](https://github.com/JamieeLee/Homeworld-Classic-Patcher/releases/tag/v0.1.3) — Restore Original from Backup (pre-release)

### Added
- **Restore Original EXE** in the existing `RUN_PATCHER.cmd` launcher, alongside Install Patch and Exit.
- Verification that the current `Homeworld.exe` has the expected patched SHA-256 and that a local timestamped `.bak` matches the exact stock 2.303 SHA-256. When several backups exist, the newest verified original is selected.
- Clear `RESTORE` confirmation before atomically replacing the patched executable with a copy of the verified original backup. The original backup is preserved.
- Restoration uses the backup file directly; it does not attempt to reverse individual executable byte changes or alter Windows registry settings.
- Safe refusal if the game is running, the EXE is not the expected patched version, or no valid backup is available; restoring an already-original EXE is a no-op.
- Synthetic Windows tests for missing/invalid backups, cancellation, successful restoration, and repeat operation.

### Documentation
- Explained why the executable requires each patch group: docking and collision avoidance, flight/camera calculations, resolution detection, widescreen movement orders, and Windows settings.
- Clarified what the patcher itself reads or writes versus what the patched game does with its settings.
- Linked the full 74-site technical reference from the README.
- Expanded the technical reference with an explanation of **each of the 74 byte modifications**, including the assembly instruction's role and game behavior it affects.
- Documented the restore workflow and direct GitHub release asset downloads.

### Compatibility
- No changes to the 74 patch definitions, source hash, or patched output hash.
- Steam and GOG discovery remain available. Exact **Homeworld 1 Classic 2.303** builds only.
- Windows PowerShell execution policy is respected by default; temporary override still requires explicit user consent.

## [v0.1.2](https://github.com/JamieeLee/Homeworld-Classic-Patcher/releases/tag/v0.1.2) — Steam & GOG Auto-Detection (pre-release)

### Added
- **GOG detection**, reading existing GOG installation information and checking common standalone/GOG Galaxy directories on fixed drives.
- Store labels and explicit **Y** confirmation for each detected Steam or GOG executable, with manual browsing as a fallback.
- User choice when a PowerShell execution-policy restriction prevents normal launch. A temporary process-only bypass is offered **only after explicit Y approval**, never by default.
- `PATCH_REFERENCE.md` with the purpose, file offset, and exact before/after bytes for all **74** changes.
- `THIRD_PARTY_NOTICES.md` preserving upstream MIT attribution and license requirements.
- Windows test fixtures for Steam alternate libraries, GOG detection, and refusal to modify unknown executables.

### Retained
- Exact 2.303 source hash verification, all 74 expected-byte checks, original EXE backup, result hash verification, offline operation, and rejection of unsupported builds.

### Verification
- Windows syntax and synthetic installation tests passed; patch manifest and 74 technical entries passed automated consistency checks.
- **Real GOG installations and the intermittent docking behavior still need extended testing.**

## [v0.1.1](https://github.com/JamieeLee/Homeworld-Classic-Patcher/releases/tag/v0.1.1) — Steam Auto-Detection (pre-release)

### Added
- Automatic discovery of *Homeworld Remastered Collection* through Steam's installation paths, library folders, and AppID `244160` manifest.
- Full detected executable path with **Y/N** approval and manual selection if needed.

### Retained
- Exact file compatibility verification, backups, and full result verification before reporting success.

## [v0.1.0](https://github.com/JamieeLee/Homeworld-Classic-Patcher/releases/tag/v0.1.0) — Initial Portable Patcher (pre-release)

### Added
- Offline `.cmd` launcher, readable PowerShell patcher, and `patches.json` containing all 74 verified byte changes.
- SHA-256 stock EXE verification, expected-byte validation, timestamped backup, patched output SHA-256 verification, and refusal to modify unknown or already-modified game builds.
- Support for the docking, widescreen/resolution, related calculation, and settings compatibility corrections in the verified build.

### Verification
- Verified all 74 patch sites and the resulting patched EXE SHA-256.
- Confirmed the patched game launches at **2560×1440**.
- **The intermittent docking fix was not conclusively proven through repeated gameplay at release.**

---

For **why** individual game bytes change, see [PATCH_REFERENCE.md](PATCH_REFERENCE.md). For install/use instructions, see [README.md](README.md). Copyright and upstream licensing are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
