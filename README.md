# Escape Kids — MiSTer FPGA Core

An FPGA recreation of Konami's 1991 *Escape Kids* arcade hardware for the MiSTer DE10-Nano platform. The core targets a standard MiSTer setup with an SDRAM expansion and a 15 kHz-class horizontal arcade display.

## Supported games

| MAME set | Game | Region | Players | MRA |
| --- | --- | --- | --- | --- |
| `esckids` | Escape Kids | Asia | 4 | `Escape Kids (Asia, 4 Players).mra` |
| `esckidsj` | Escape Kids | Japan | 2 | `Escape Kids (Japan, 2 Players).mra` |

Both MRAs use the same `Arcade-EscapeKids` core and select the cabinet/profile data through the ROM-loader header.

## Features in the OSD

- Run, Super Jump and Auto Run action buttons
- Start, Coin, Service and Test controls
- Native horizontal arcade video and MiSTer video options
- Stereo audio
- Optional "Mute One-Two Voice" toggle that silences the character "one, two" voice calls (sound-test entries 60 and 62)
- Persistent 128-byte ER5911-compatible NVRAM for game high scores

## **Hardware emulated**

| PCB device / glue | Active RTL path | Evidence / status |
| --- | --- | --- |
| CUS1 / 053248 main CPU | `jtsimson_main.v` and `modules/jtkcpu` | Pinned `vendetta.cpp` main-CPU declaration/map plus JTCORES donor; INFERRED board integration. |
| CUS8 / K052109 tile generator + CUS7 / K051962 timing | `jtsimson_scroll.v` through `jt052109.v` and `jt051962.v` | MAME K052109 map/device setup and JTCORES implementation; INFERRED board wiring. |
| CUS4 / K053246 + CUS5 / K053247 GX975 sprite path | `jtriders_obj.v`, `jt053244.sv` and `jt053246_dma.v` | MAME GX975 sprite configuration/callback and JTCORES object path; INFERRED board wiring. |
| CUS6 / K053251 priority and palette control | `jtsimson_colmix.v` and `jtcolmix_053251.v` | MAME priority-register/palette configuration and JTCORES implementation; INFERRED board wiring. |
| CUS2 / K053252 CCU | `jtsimson_video.v` with `jtk053252.v` and `jtk053252_mmr.sv` | Furrtek die reverse engineering establishes the counter/register fields; MAME supplies the 24 MHz device integration; field model KNOWN, board integration INFERRED. |
| CUS3 / K053260, YM2151 and Z80 sound system | `jtsimson_sound.v`, `jt053260`, `jt51` and `jtframe_z80.v` | Pinned MAME sound map/device setup plus JTCORES implementations; INFERRED board wiring. |
| ER5911 serial EEPROM | `jtsimson_main.v` through `jt5911.sv` | MAME 128-byte EEPROM declaration and the JTCORES serial-device model; INFERRED board integration. |
| Decoder/PAL glue | Escape branch of `jtsimson_main.v` | Pinned MAME `esckids_map` and the captured boot bus contract; INFERRED, with no standalone custom-PAL RTL identified. |
| External ROM/SDRAM interface | `jtsimson_game_sdram.v` and `jtframe_sdram64.v` | MiSTer board storage/download path; platform glue, not an original custom Konami IC. |
| MiSTer platform glue | `EscapeKids.sv` and vendored `sys/` | Template_MiSTer framework and HPS/OSD/video/audio integration; platform support, not PCB emulation. |

## PCB Accuracy

The table below lists only areas with a direct device or board-evidence basis. JTCORES and MAME are used elsewhere as implementation/reference sources, not as independent PCB proof.

| Area | Evidence basis |
| --- | --- |
| K053252 CCU/raster registers | [Furrtek's published 053252 die reverse engineering](https://github.com/furrtek/SiliconRE/blob/master/Konami/053252/README.md) documents the counter widths, reset fields, reload values and sync inputs used by the project timing model. |

Claims about analog output, SDRAM margin and physical PCB timing require validation on the target hardware and are not inferred from a compiled bitstream alone.

## ROMs and MRAs

Arcade ROM images are not included. Supply legally obtained MAME ROM archives matching the set names above. The MRAs describe the ROM interleaving, profile header and persistent NVRAM image used by the core.

The parent `esckids` MRA uses `esckids.zip`. The Japan clone MRA searches
`esckids.zip|esckidsj.zip` by CRC for each external part, so it accepts the
usual MAME layouts:

- merged: one archive containing all parent and clone members;
- split: `esckids.zip` plus the clone-only `esckidsj.zip`; or
- non-merged: a complete `esckidsj.zip` archive.

For the split layout, keep both archives in the MAME ROM directory. The
release XML can be checked with `python scripts/validate_mras.py`.

For a manual installation, place the RBF and both MRA files in the same `_Arcade` folder (or the equivalent release folders):

- `releases/Arcade-EscapeKids_20260831.rbf` to `/media/fat/_Arcade/`
- both `.mra` files from `releases/` to `/media/fat/_Arcade/`

The repository contains source, framework files, release metadata and the single latest RBF only. Quartus databases, simulation output, captures, ROM archives and other local build products are excluded.

## Building from source

The project follows the standard MiSTer core layout from [MiSTer-devel/Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer). The pinned build target is Quartus Prime 17.0.2 Build 602 for the DE10-Nano Cyclone V `5CSEBA6U23`.

The main project is `EscapeKids.qpf`; `EscapeKids.qsf`, `EscapeKids.sdc`, `EscapeKids.sv`, `files.qip`, `rtl/` and `sys/` contain the project and source closure. `cfgstr.hex` and `font0.hex` are runtime assets required by the MiSTer framework and are intentionally tracked. Generated Quartus output belongs in the ignored build directories.

## Releases

The current public release is:

```text
releases/Arcade-EscapeKids_20260903.rbf
SHA-256: 7E5D8A20F4A809988CC4DCB0B4CFC498E5D0A65DB8503A85683695E7C7230A32
```

The RBF is compressed for MiSTer HPS configuration. Keep only the newest dated RBF in the root of `releases/`; the MRAs remain alongside it.

## Credits

- [JTCORES](https://github.com/jotego/jtcores) and its contributors for the reusable arcade RTL and MiSTer framework components.
- [MiSTer-devel/Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer) for the standard project layout and platform framework.
- The MAME project and its Konami/Vendetta driver for reference behavior and ROM mappings.
- [Furrtek's SiliconREsearch](https://github.com/furrtek/SiliconRE) for the published Konami 053252 die reverse-engineering notes used to bound the CCU model.
- The Escape Kids ROMs remain the property of their respective owners and are not distributed here.

## License

Project-specific source is released under GPL-3.0-or-later. Vendored JTCORES and framework components retain their upstream copyright and license notices; see [LICENSE](LICENSE) and [JTCORES-LICENSE](rtl/vendor/jtcores/JTCORES-LICENSE).

## MiSTer Downloader

Add this section to `/media/fat/downloader.ini`, then run **Update All**:

```ini
[meathax/meatcores]
db_url = https://raw.githubusercontent.com/meathax/meatcores/db/downloader_meathax_meatcores.zip
```
