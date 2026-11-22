# Patch reference — Homeworld 1 Classic 2.303

This is the technical explanation of **every byte sequence our patcher changes**, in the user's own `Homeworld.exe`. It is an audit companion to [`patches.json`](patches.json), not an alternative set of patches. **The JSON manifest is the authoritative source used at runtime.**

## Why these changes exist

**Docking and avoidance (dock):** The 2023 executable uses integer conversions for floating-point absolute values in object-avoidance calculations. Truncating small floating-point values makes collision sizes appear near zero, so fighters and corvettes can orbit the Mothership instead of detecting an obstructed docking approach. The patches restore a bitwise floating-point absolute-value operation without increasing instruction length.

**Other flight and camera calculations (full):** Corrects the same float-to-integer absolute-value mistake in other movement, targeting, and camera calculations.

**Graphics and settings (video):** Removes the five-resolution whitelist and 1600-pixel cap, corrects cursor-to-world movement at widescreen aspect ratios, updates projection after an in-game resolution change, moves the game's own configuration storage from HKLM to HKCU for normal user access, defaults to 32-bit color, initializes at desktop resolution, and sorts detected modes. The PowerShell patcher itself **does not migrate existing registry values or write to the registry**; these bytes change how the *game* accesses its settings once launched.

## Verification and safety

- Target: `Homeworld1Classic\exe\Homeworld.exe`, exact build **2.303**, regardless of whether installed through Steam or GOG.
- Stock SHA-256: `421c114e832c56bd1994fe97c342969ef69881bb74399e67bef979c6923df381`
- Patched SHA-256: `166c3a23a0eeb5789823602b2571be98ae926a9447376c4b843ac0d1179884fb`
- All 74 original sequences must match before **any** patch is written. The replacement is generated and hash-checked in memory first, with a backup created during atomic replacement.
- Offsets below are **zero-based file offsets**, not virtual addresses. The old and new sequences are the actual hexadecimal byte sequences; length is in bytes.
- No other game data is changed, and unsupported EXEs are refused.

These per-site descriptions are traceable to the published patch table and reasoning notes accompanying the original fixes. They are **not** a claim that every assembly branch has been independently reverse-engineered anew. See [third-party notices](THIRD_PARTY_NOTICES.md) for attribution and license.

## Site-by-site changes

| # | Group | File offset | Bytes | Original bytes → replacement bytes | Purpose |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `dock` | `0x16E4D` | 4 | `F30F2CC2` → `660F7ED0` | O1 cvttss2si eax,xmm2 -> movd |
| 2 | `dock` | `0x16E51` | 3 | `0F57D2` → `0F1F00` | O1 xorps xmm2,xmm2 (zeroing for cvtsi2ss) -> nop |
| 3 | `dock` | `0x16E58` | 1 | `99` → `90` | O1 cdq -> nop |
| 4 | `dock` | `0x16E5D` | 2 | `33C2` → `D1E0` | O1 xor eax,edx -> shl eax,1 |
| 5 | `dock` | `0x16E65` | 2 | `2BC2` → `D1E8` | O1 sub eax,edx -> shr eax,1 |
| 6 | `dock` | `0x16E73` | 4 | `F30F2AD0` → `660F6ED0` | O1 cvtsi2ss xmm2,eax -> movd |
| 7 | `dock` | `0x16E87` | 4 | `F30F2CC1` → `660F7EC8` | O2 cvttss2si eax,xmm1 -> movd |
| 8 | `dock` | `0x16E8B` | 5 | `9933C22BC2` → `25FFFFFF7F` | O2 cdq/xor/sub -> and eax,0x7fffffff |
| 9 | `dock` | `0x16E90` | 4 | `F30F2AC0` → `660F6EC0` | O2 cvtsi2ss xmm0,eax -> movd |
| 10 | `dock` | `0x16E94` | 4 | `F30F2CC5` → `660F7EE8` | O3 cvttss2si eax,xmm5 -> movd |
| 11 | `dock` | `0x16E9D` | 5 | `9933C22BC2` → `25FFFFFF7F` | O3 cdq/xor/sub -> and eax,0x7fffffff |
| 12 | `dock` | `0x16EA9` | 4 | `F30F2AC0` → `660F6EC0` | O3 cvtsi2ss xmm0,eax -> movd |
| 13 | `dock` | `0x16A98` | 4 | `F30F2CC1` → `660F7EC8` | C1 cvttss2si -> movd |
| 14 | `dock` | `0x16AA5` | 5 | `9933C22BC2` → `25FFFFFF7F` | C1 abs |
| 15 | `dock` | `0x16ABB` | 3 | `0F5BDB` → `0F1F00` | C1 cvtdq2ps xmm3 -> nop |
| 16 | `dock` | `0x16AC7` | 4 | `F30F2CC1` → `660F7EC8` | C2 cvttss2si -> movd |
| 17 | `dock` | `0x16AD3` | 1 | `99` → `90` | C2 cdq -> nop |
| 18 | `dock` | `0x16AD4` | 2 | `33C2` → `D1E0` | C2 xor -> shl |
| 19 | `dock` | `0x16ADA` | 2 | `2BC2` → `D1E8` | C2 sub -> shr |
| 20 | `dock` | `0x16AE0` | 3 | `0F5BC0` → `0F1F00` | C2 cvtdq2ps xmm0 -> nop |
| 21 | `dock` | `0x16B0C` | 4 | `F30F2CC1` → `660F7EC8` | C3 cvttss2si -> movd |
| 22 | `dock` | `0x16B13` | 5 | `9933C22BC2` → `25FFFFFF7F` | C3 abs |
| 23 | `dock` | `0x16B1C` | 3 | `0F5BC0` → `0F1F00` | C3 cvtdq2ps xmm0 -> nop |
| 24 | `dock` | `0x16B5D` | 4 | `F30F2CC1` → `660F7EC8` | C4 cvttss2si -> movd |
| 25 | `dock` | `0x16B6C` | 5 | `9933C22BC2` → `25FFFFFF7F` | C4 abs |
| 26 | `dock` | `0x16B75` | 3 | `0F5BD2` → `0F1F00` | C4 cvtdq2ps xmm2 -> nop |
| 27 | `dock` | `0x16B90` | 4 | `F30F2CC1` → `660F7EC8` | C5 cvttss2si -> movd |
| 28 | `dock` | `0x16B9C` | 1 | `99` → `90` | C5 cdq -> nop |
| 29 | `dock` | `0x16B9D` | 2 | `33C2` → `D1E0` | C5 xor -> shl |
| 30 | `dock` | `0x16BA3` | 2 | `2BC2` → `D1E8` | C5 sub -> shr |
| 31 | `dock` | `0x16BA9` | 3 | `0F5BC0` → `0F1F00` | C5 cvtdq2ps xmm0 -> nop |
| 32 | `dock` | `0x16BD4` | 4 | `F30F2CC1` → `660F7EC8` | C6 cvttss2si -> movd |
| 33 | `dock` | `0x16BE0` | 5 | `9933C22BC2` → `25FFFFFF7F` | C6 abs |
| 34 | `dock` | `0x16BE9` | 3 | `0F5BC0` → `0F1F00` | C6 cvtdq2ps xmm0 -> nop |
| 35 | `full` | `0x15C71` | 4 | `F30F2CC0` → `660F7EC0` | A cvttss2si eax,xmm0 -> movd |
| 36 | `full` | `0x15C79` | 1 | `99` → `90` | A cdq -> nop |
| 37 | `full` | `0x15C7C` | 2 | `33F2` → `D1E6` | A xor esi,edx -> shl esi,1 |
| 38 | `full` | `0x15C7E` | 2 | `2BF2` → `D1EE` | A sub esi,edx -> shr esi,1 |
| 39 | `full` | `0x15C9C` | 3 | `0F5BD2` → `0F1F00` | A cvtdq2ps xmm2 -> nop |
| 40 | `full` | `0x162BC` | 4 | `F30F2CC1` → `660F7EC8` | B cvttss2si eax,xmm1 -> movd |
| 41 | `full` | `0x162C6` | 1 | `99` → `90` | B cdq -> nop |
| 42 | `full` | `0x162C9` | 2 | `33F2` → `D1E6` | B xor esi,edx -> shl esi,1 |
| 43 | `full` | `0x162CB` | 2 | `2BF2` → `D1EE` | B sub esi,edx -> shr esi,1 |
| 44 | `full` | `0x162D1` | 3 | `0F5BC9` → `0F1F00` | B cvtdq2ps xmm1 -> nop |
| 45 | `full` | `0x17191` | 4 | `F30F2CC0` → `660F7EC0` | C cvttss2si eax,xmm0 -> movd |
| 46 | `full` | `0x1719F` | 5 | `9933C22BC2` → `25FFFFFF7F` | C cdq/xor/sub -> and eax,0x7fffffff |
| 47 | `full` | `0x171A8` | 3 | `0F5BD2` → `0F1F00` | C cvtdq2ps xmm2 -> nop |
| 48 | `full` | `0x1AE97` | 4 | `F30F2CC5` → `660F7EE8` | D cvttss2si eax,xmm5 -> movd |
| 49 | `full` | `0x1AE9B` | 5 | `9933C22BC2` → `25FFFFFF7F` | D cdq/xor/sub -> and eax,0x7fffffff |
| 50 | `full` | `0x1AEA7` | 3 | `0F5BC0` → `0F1F00` | D cvtdq2ps xmm0 -> nop |
| 51 | `full` | `0x414C6` | 4 | `F30F2CC0` → `660F7EC0` | E cvttss2si eax,xmm0 -> movd |
| 52 | `full` | `0x414CA` | 5 | `9933C22BC2` → `25FFFFFF7F` | E cdq/xor/sub -> and eax,0x7fffffff |
| 53 | `full` | `0x414CF` | 4 | `F30F2AD0` → `660F6ED0` | E cvtsi2ss xmm2,eax -> movd |
| 54 | `full` | `0xBDE1F` | 4 | `F30F2CC1` → `660F7EC8` | F cvttss2si eax,xmm1 -> movd |
| 55 | `full` | `0xBDE23` | 5 | `9933C22BC2` → `25FFFFFF7F` | F cdq/xor/sub -> and eax,0x7fffffff |
| 56 | `full` | `0xBDE2C` | 3 | `0F5BDB` → `0F1F00` | F cvtdq2ps xmm3 -> nop |
| 57 | `video` | `0x29E79` | 131 | `660F6E150C1D6D00660F6E0DC02C7D000F5BC9A1549C73005683EC088BF10F5BD2660F6E1DC42C7D00F30F5ECA0F5BDBF30F5C0D64E66600F30F106838F30F10601C0F28C5F30F5C6010F30F114C2434660F6E0D081D6D000F5BC9F30F59ECF30F5ED9F30F5ECAF30F5C1D64E66600F30F105020F30F5C5014F30F1164241CF30F59D9` → `F30F2A150C1D6D00F30F2A0DC02C7D00A1549C73005683EC088BF1F30F2A1DC42C7D00F30F5ECAF30F5C0D64E66600F30F106838F30F10601C0F28C5F30F5C6010F30F114C2434F30F2A0D081D6D00F30F59ECF30F5ED9F30F5ECAF30F114C240CF30F5C1D64E66600F30F105020F30F5C5014F30F1164241CF30F59D9660F1F440000` | V1 raycast prologue: stash H/W |
| 58 | `video` | `0x29FEB` | 8 | `F30F100DFCE66600` → `F30F104C24046690` | V1 look 1/len starts from H/W instead of 1.0 |
| 59 | `video` | `0x26CE60` | 4 | `48E1FA3E` → `DA40273F` | V1 constant 0.49 -> 0.49/0.75 |
| 60 | `video` | `0x334F38` | 16 | `7D3A853A8D3A9E3AAD3ACD3AE43AEF3B` → `7D3A853A8A3A983AA43AC43ADE3A0000` | V1 .reloc entries follow the moved operands |
| 61 | `video` | `0x22619E` | 6 | `81FA40060000` → `81FAFFFFFF7F` | V2 drop the 1600-wide cap |
| 62 | `video` | `0x22600B` | 8 | `81FE000400007F3D` → `E96D0000000F1F00` | V2 accept every enumerated mode |
| 63 | `video` | `0x2338F1` | 5 | `6802000080` → `6801000080` | V3 utyVariablesLoad: HKLM -> HKCU |
| 64 | `video` | `0x233A3F` | 5 | `6802000080` → `6801000080` | V3 utyVariablesSave: HKLM -> HKCU |
| 65 | `video` | `0x233306` | 5 | `6802000080` → `6801000080` | V3 key open: HKLM -> HKCU |
| 66 | `video` | `0x233332` | 5 | `6802000080` → `6801000080` | V3 key create: HKLM -> HKCU |
| 67 | `video` | `0x20F744` | 5 | `6802000080` → `6801000080` | V3 CmdLine value: HKLM -> HKCU |
| 68 | `video` | `0x2CFD38` | 4 | `10000000` → `20000000` | V4 default colour depth 32-bit |
| 69 | `video` | `0x2CFD08` | 8 | `E001000080020000` → `0000000000000000` | V5 image defaults 640x480 -> 0 (unset) |
| 70 | `video` | `0x1C3379` | 55 | `CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC` → `E87203070053E8000000005B83BB88DD100000751C6A00FF93F8F20900898388DD10006A01FF93F8F20900898384DD10005BC3CCCCCCCC` | V5 cave: unset size -> desktop size |
| 71 | `video` | `0x2124AB` | 5 | `E840120200` → `E8C90EFBFF` | V5 WinMain calls the cave instead of utyVariablesLoad |
| 72 | `video` | `0x225ED0` | 74 | `558BEC5356576A108BF28BD9E87A1302008B4D0C8BF88B550883C404C7470C000000008937895704894F088B8B8C00000085C9750E89BB8C000000894F0C5F5E5B5DC38B410C85C0740F` → `558BEC5356576A108BF28BD9E87A1302008BF883C4048B4D0C8B55088937895704894F088D838C0000008B0885C974103951047C067F09393177058D410CEBEA894F0C89385F5E5B5DC3` | V6 rinAddMode: ordered insert by height, then width |
| 73 | `video` | `0xAF5C5` | 5 | `E8E6171600` → `E850691700` | V7 options Accept calls the aspect stub, which jumps to the renderer reload |
| 74 | `video` | `0x225F1A` | 30 | `660F1F4400008BC88B410C85C075F789790CC7470C000000005F5E5B5DC3` → `E80000000058DB80EDB10A00DAB0E9B10A00D99889C11A00E979AEFEFFCC` | V7 stub: rndAspectRatio = width / height, then the renderer reload |

## Notes on compatibility

A Steam installation and a GOG installation are **not automatically interchangeable** simply because they contain a file named `Homeworld.exe`. We only apply these bytes when the exact supported stock hash is present. A different GOG build, an updated release, or another modded executable will be refused without modifying it.

The original patched output hash can be rechecked with Windows PowerShell using:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath "C:\path\to\Homeworld1Classic\exe\Homeworld.exe"
```
