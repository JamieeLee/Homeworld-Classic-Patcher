# v0.1.1 — Steam Auto-Detection (pre-release)

This update makes the Homeworld 1 Classic 2.303 patcher easier to use by locating your Steam installation automatically.

### Changes
- Searches Steam's installed libraries, including additional library folders, for **Homeworld Remastered Collection** (AppID `244160`).
- Shows the detected `Homeworld1Classic\exe\Homeworld.exe` path and asks you to confirm it.
- Opens a manual file picker if the executable can't be found automatically or if you decline the detected path.
- Keeps the exact SHA-256 compatibility check, original-file backup, all 74 byte patches, and verification of the finished EXE.

### Compatibility
- Supports **Homeworld 1 Classic build 2.303**.
- Other builds, including different CD-ROM executables, are not patched unless they exactly match the supported file.
- Works offline and includes no game executable.

### Testing
The patcher has been used to launch Homeworld 1 Classic at **2560×1440**. Steam auto-detection still needs testing across different Steam installations, and the intermittent docking issue has not yet been conclusively verified through repeated gameplay.
