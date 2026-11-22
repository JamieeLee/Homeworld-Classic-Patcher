# v0.1.2 — Steam & GOG Auto-Detection (pre-release)

The portable Homeworld 1 Classic 2.303 patcher now searches **both Steam and GOG** installations, while continuing to patch only the **exact verified game executable**.

### What's changed
- **GOG support:** Reads existing GOG installation registry entries and checks common standalone and GOG Galaxy folders. Steam detection, including additional Steam libraries, is retained.
- **Your choice:** Labels each candidate **Steam** or **GOG**, displays the full `Homeworld.exe` path, and asks for **Y** confirmation. If none is accepted, offers manual file selection.
- **No automatic execution-policy bypass:** Starts under the user's existing Windows PowerShell policy. If a script launch is blocked, the launcher offers an explicit **Y/N** choice for a temporary process-only retry. Choosing **N** leaves the user to address their policy manually.
- **Full technical transparency:** New `PATCH_REFERENCE.md` documents the purpose, exact old/new bytes, and file offset of every one of the **74 patch sites**.
- **Clear licensing:** Includes a dedicated MIT third-party notice. The project remains MIT licensed.

### Safeguards
- Supports only the exact **Homeworld 1 Classic 2.303** executable, regardless of storefront. Different Steam/GOG/CD-ROM builds are refused.
- Verifies stock SHA-256 and all original byte sequences, creates an original backup, and verifies the resulting patched SHA-256.
- Operates offline, does not write Steam/GOG registry settings, and does not distribute a game EXE.

### Testing
Windows fixture tests cover Steam alternate-library detection, GOG registry detection, and refusal to modify an unsupported executable. **Real-world GOG installation detection has not yet been verified**, and the intermittent docking fix still needs longer gameplay testing. This remains a **pre-release**.
