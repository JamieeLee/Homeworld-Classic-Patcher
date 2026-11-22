# v0.1.1 — Steam auto-detection (pre-release)

Improves setup of the offline Homeworld 1 Classic build 2.303 patcher.

- Automatically searches Steam installation locations and alternate library folders for **Homeworld Remastered Collection** (AppID `244160`).
- Displays the detected `Homeworld1Classic\exe\Homeworld.exe` path for explicit **Y** confirmation.
- Falls back to a file picker if Steam is not found or its detected path is declined.
- Retains exact stock SHA-256 verification, an original backup, post-patch verification, and all 74 byte modifications.
- Does **not** support distinct CD-ROM builds or other versions; mismatched EXEs are refused.
- Contains no copyrighted game EXE and no third-party installer.

**Testing:** The earlier version's patched game launched at 2560×1440. Steam auto-detection and the intermittent docking issue have not yet been comprehensively tested on user systems.

**Credit:** Original docking and widescreen modifications by **Lou the Lou**. This project republishes those fixes as an inspectable script-based patcher with permission reported by the maintainer.

Original mod: https://www.nexusmods.com/homeworldremastered/mods/10
