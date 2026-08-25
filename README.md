# Escape Kids — MiSTer FPGA Core

An FPGA recreation of Konami's 1991 *Escape Kids* arcade hardware for the MiSTer DE10-Nano platform. The core targets a standard MiSTer setup with an SDRAM expansion and a 15 kHz-class horizontal arcade display.

## Compatibility

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

## Hardware model

| Hardware | Core implementation |
| --- | --- |
| Konami GX975 main board | JTCORES Konami CPU and Escape Kids address/map wrapper |
| K052109 / K051962 | Three-layer tilemap and tile-fetch video path |
| K053246-style sprite path | GX975 sprite DMA, object buffering, zoom, priority and shadow handling |
| K053251 / K053252 | Palette priority, raster timing, blanking and native 384 × 264 timing |
| Z80, YM2151 and K053260 | JTCORES sound devices with the Escape Kids PCM prefetch path |
| ER5911 | Serial EEPROM model with MiSTer NVRAM persistence |
| MiSTer platform | Standard `sys/` framework, HPS loader, SDRAM/DDR staging, video, audio and OSD glue |

## PCB accuracy

The implementation follows the original program-ROM map and register programming, established JTCORES device implementations, and the Konami/Vendetta MAME driver as a behavioral reference. The following areas have an explicit source or device basis:

| Area | Evidence basis |
| --- | --- |
| CPU and device address map | Original Escape Kids program-ROM behavior and the pinned Konami/Vendetta MAME map |
| K053252 raster | Original boot register writes and the independent K053252 timing implementation |
| ER5911 serial storage | ER5911 device behavior, the MAME EEPROM model and the MiSTer 128-byte NVRAM contract |
| GX975 video path | JTCORES' related Konami video devices and Escape Kids-specific register, banking and sprite integration |

Claims about analog output, SDRAM margin and physical PCB timing require validation on the target hardware and are not inferred from a compiled bitstream alone.

## ROMs and MRAs

Arcade ROM images are not included. Supply legally obtained MAME ROM archives matching the set names above. The MRAs describe the ROM interleaving, profile header and persistent NVRAM image used by the core.

For a manual installation, copy:

- `releases/Arcade-EscapeKids_20260824.rbf` to `/media/fat/_Arcade/cores/`
- both `.mra` files from `releases/` to `/media/fat/_Arcade/`

The repository contains source, framework files, release metadata and the single latest RBF only. Quartus databases, simulation output, captures, ROM archives and other local build products are excluded.

## Building from source

The project follows the standard MiSTer core layout from [MiSTer-devel/Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer). The pinned build target is Quartus Prime 17.0.2 Build 602 for the DE10-Nano Cyclone V `5CSEBA6U23`.

The main project is `EscapeKids.qpf`; `EscapeKids.qsf`, `EscapeKids.sdc`, `EscapeKids.sv`, `files.qip`, `rtl/` and `sys/` contain the project and source closure. `cfgstr.hex` and `font0.hex` are runtime assets required by the MiSTer framework and are intentionally tracked. Generated Quartus output belongs in the ignored build directories.

## Releases

The current public release is:

```text
releases/Arcade-EscapeKids_20260824.rbf
SHA-256: 0DAF231D05FCB300A53D4F8E8A1B9DD6D35E0E5801AE4C25E5768ADCA6BF541A
```

The RBF is compressed for MiSTer HPS configuration. Keep only the newest dated RBF in the root of `releases/`; the MRAs remain alongside it.

## Credits and license

- [JTCORES](https://github.com/jotego/jtcores) and its contributors for the reusable arcade RTL and MiSTer framework components.
- [MiSTer-devel/Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer) for the standard project layout and platform framework.
- The MAME project and its Konami/Vendetta driver for reference behavior and ROM mappings.
- The Escape Kids ROMs remain the property of their respective owners and are not distributed here.

Project-specific source is released under GPL-3.0-or-later. Vendored JTCORES and framework components retain their upstream copyright and license notices; see [LICENSE](LICENSE) and [JTCORES-LICENSE](rtl/vendor/jtcores/JTCORES-LICENSE).

## MiSTer Downloader

Add this section to `/media/fat/downloader.ini`, then run **Update All**:

```ini
[meathax/meatcores]
db_url = https://raw.githubusercontent.com/meathax/meatcores/db/db.json.zip
```
