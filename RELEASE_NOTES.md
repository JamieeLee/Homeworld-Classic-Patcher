# v0.1.0 — Initial portable patcher (pre-release)

A transparent, offline alternative to running the original HW1 Classic fix installer.

**For Homeworld 1 Classic build 2.303 only** (included in the Homeworld Remastered Collection), not Remastered or Homeworld 2/3.

### Included
- Readable `.cmd` and PowerShell patcher with no bundled game executable.
- JSON manifest containing 74 exact byte modifications for docking and related behavior plus widescreen/resolution compatibility.
- Stock SHA-256 check before patching, automatic backup, patched output SHA-256 verification, and refusal on unsupported/modified builds.

### Testing status
- All 74 patches verified against the stock 2.303 executable; independently reproduced patched SHA-256.
- User confirmed the patched game launches at 2560×1440.
- The intermittent docking bug has **not** yet been confirmed fixed by repeated in-game testing; release should be marked **Pre-release**.

### Attribution
Original fix work: **Lou the Lou** — https://www.nexusmods.com/homeworldremastered/mods/10. This is a separate, inspectable patching tool to apply those changes to a user's own legitimate game installation. No original game binaries included.

### Install
Download `Homeworld1Classic_Reusable_Offline_Patcher_2.303.zip`, extract, then run `RUN_PATCHER.cmd` and select `Homeworld1Classic\exe\Homeworld.exe`.
