# Escape Kids for MiSTer

An FPGA recreation of Konami's 1991 *Escape Kids* arcade hardware for the MiSTer DE10-Nano. The core supports the horizontal Asia four-player and Japan two-player releases, with the original cabinet profile selected by the MRA at ROM-load time.

| | |
| --- | --- |
| **Target** | MiSTer DE10-Nano with an SDRAM expansion |
| **Original hardware** | Konami GX975-class arcade board |
| **Video** | Horizontal 15 kHz-class arcade timing, with MiSTer video options |
| **Audio** | Stereo YM2151 and K053260-based sound path |
| **Core file** | `Arcade-EscapeKids` |

## Supported games

| MAME set | Title | Region | Cabinet | MRA |
| --- | --- | --- | --- | --- |
| `esckids` | Escape Kids | Asia | 4 players | `Escape Kids (Asia, 4 Players).mra` |
| `esckidsj` | Escape Kids | Japan | 2 players | `Escape Kids (Japan, 2 Players).mra` |

Both sets use the same `Arcade-EscapeKids` RBF. The MRA header selects the correct game/cabinet profile; it is not an OSD setting.

## Features in the OSD

| Control or option | Default | Purpose |
| --- | --- | --- |
| Run | `A` | Player run action |
| Super Jump | `B` | Player super-jump action |
| Auto Run | `X` | Enable the game-specific auto-run control |
| Start / Coin | `Start` / `Select` | Cabinet start and coin inputs |
| Service / Test | `L` / `R` | Cabinet service and test inputs |
| Mute One-Two Voice | Off | Suppress only the character “one, two” voice calls; FM, PCM mixing, and other sound commands remain unchanged |
| NVRAM | Persistent | Retains the 128-byte ER5911-compatible game EEPROM, including high scores |

MiSTer's standard video controls remain available. The core is intended for horizontal output and declares the arcade `15kHz` resolution class in its MRAs.

## PCB Accuracy

This section deliberately lists only behaviour supported by direct device or board evidence. MAME and JTCORES are valuable functional and implementation references, but are not treated as PCB proof.

| Verified area | Evidence | What the core uses it for |
| --- | --- | --- |
| Konami K053252 CCU raster-register model | [Furrtek's K053252 die-reverse-engineering notes](https://github.com/furrtek/SiliconRE/blob/master/Konami/053252/README.md) document the counter widths, reset fields, reload values, and sync inputs. | The project-owned CCU register model and raster timing path. |

The board integration of the other devices below is currently **inferred** from the program behaviour, the pinned MAME driver, and established JTCORES implementations. No claim is made here for analog output characteristics, exact PCB propagation delay, or SDRAM margin; those need board-specific measurement or hardware capture.

## **Hardware emulated**

| Original device or function | Active FPGA path | Evidence status |
| --- | --- | --- |
| CUS1 / 053248 main CPU | `jtsimson_main.v` plus `modules/jtkcpu` | **INFERRED** — Escape Kids device map in the pinned MAME Konami/Vendetta driver and the JTCORES CPU integration. |
| CUS8 K052109 tile generator and CUS7 K051962 timing | `jtsimson_scroll.v`, `jt052109.v`, and `jt051962.v` | **INFERRED** — MAME device/map declarations and the JTCORES implementation. |
| CUS4 K053246 and CUS5 K053247 sprite system | `jtriders_obj.v`, `jt053244.sv`, and `jt053246_dma.v` | **INFERRED** — GX975 sprite configuration/callback behaviour and the JTCORES object pipeline. |
| CUS6 K053251 priority and palette control | `jtsimson_colmix.v` and `jtcolmix_053251.v` | **INFERRED** — MAME priority/palette configuration and the JTCORES mixer. |
| CUS2 K053252 CCU | `jtsimson_video.v`, `jtk053252.v`, and `jtk053252_mmr.sv` | **KNOWN** for the documented counter/register fields; **INFERRED** for this board's integration. |
| CUS3 K053260, YM2151, and Z80 sound board | `jtsimson_sound.v`, `jt053260`, `jt51`, and `jtframe_z80.v` | **INFERRED** — MAME sound map/device configuration and the JTCORES sound devices. |
| ER5911 serial EEPROM | `jtsimson_main.v` through `jt5911.sv` | **INFERRED** — MAME's 128-byte EEPROM declaration and the JTCORES serial-device model. |
| Address decoder and PAL glue | Escape Kids branch in `jtsimson_main.v` | **INFERRED** — Escape Kids address-map behaviour and captured boot-bus contracts; no standalone custom-PAL model has been identified. |

MiSTer ROM storage, SDRAM, HPS I/O, OSD, and video-output code are platform integration, not original Konami PCB devices.

## ROMs and MRAs

ROM images are not included. Use legally obtained archives matching the set names above. The MRAs supply the required ROM ordering, interleaving, cabinet-profile header, and default EEPROM image.

The Asia MRA reads `esckids.zip`. The Japan-clone MRA searches `esckids.zip|esckidsj.zip` by CRC and supports the usual MAME layouts:

- merged: one archive containing parent and clone members;
- split: `esckids.zip` plus clone-only `esckidsj.zip`; or
- non-merged: one complete `esckidsj.zip` archive.

For a split layout, keep both archives in the MAME ROM directory. Validate the release XML after an MRA change with:

```text
python scripts/validate_mras.py
```

## How to install

For a manual installation, copy the current RBF and the MRA you want to use to the same MiSTer Arcade directory:

```text
/media/fat/_Arcade/
```

The published files are:

| File | Repository location |
| --- | --- |
| Core RBF | `releases/Arcade-EscapeKids_20260903.rbf` |
| Asia / four-player MRA | `releases/Escape Kids (Asia, 4 Players).mra` |
| Japan / two-player MRA | `releases/_alternatives/EscapeKids/Escape Kids (Japan, 2 Players).mra` |

To install through the MiSTer downloader, add the following to `downloader.ini`:

```ini
[meathax/meatcores]
db_url = https://raw.githubusercontent.com/meathax/meatcores/db/downloader_meathax_meatcores.zip
```

Then run **Update All** from MiSTer. The updater places the core and MRA files in the appropriate Arcade location.

## Building from source

The main Quartus project is `EscapeKids.qpf`. Its source and constraint manifests are `EscapeKids.qsf`, `EscapeKids.sdc`, and `files.qip`. The supported production toolchain is Quartus Prime 17.0.2 Build 602 for the DE10-Nano Cyclone V `5CSEBA6U23`.

Use `clean.bat` to remove generated Quartus output before a clean local build. Generated databases, simulation output, captures, and ROM images are intentionally not tracked.

## Release

The current committed release is `Arcade-EscapeKids_20260903.rbf`.

```text
SHA-256: 7E5D8A20F4A809988CC4DCB0B4CFC498E5D0A65DB8503A85683695E7C7230A32
```

The RBF is compressed for MiSTer's HPS configuration. Only the newest accepted dated RBF belongs in the root of `releases/`; the MRA files remain alongside it or in their documented alternatives directory.

## Credits

- [JTCORES](https://github.com/jotego/jtcores) and its contributors, for the reusable arcade RTL and MiSTer framework components.
- [MiSTer-devel/Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer), for the standard MiSTer project layout and platform framework.
- [MAME](https://www.mamedev.org/), for reference behaviour, driver research, ROM naming, and ROM mappings.
- [Furrtek's SiliconREsearch](https://github.com/furrtek/SiliconRE), for the K053252 die-reverse-engineering notes that bound the CCU model.
- Konami and the original rights holders. Game ROMs are not distributed with this project.

## License

The repository's project-specific source is distributed under the [GNU General Public License, version 2](LICENSE). Vendored JTCORES and MiSTer framework components retain their upstream copyright and licence notices, including [JTCORES-LICENSE](rtl/vendor/jtcores/JTCORES-LICENSE).
