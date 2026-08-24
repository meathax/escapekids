# Escape Kids MiSTer Core

MiSTer FPGA implementation of Konami's *Escape Kids* arcade hardware for the DE10-nano / MiSTer FPGA platform. The core uses the MiSTer framework and requires the standard SDRAM-equipped setup.

## Features in the OSD

- Asia, 4-player and Japan, 2-player game sets
- Standard MiSTer video, audio, reset and ROM loading controls
- **Mute One-Two Voice**: Off by default; switch it On to mute the repeating gameplay voice effect
- Player controls named **Run**, **Super Jump**, and **Auto Run**
- **Auto Run** repeatedly taps Run while held, reducing repeated button presses
- Start, Coin, Service and Test controls
- Game-written high scores persist through the 128-byte ER5911 NVRAM image
- ROM downloads use JTFRAME's DDR3 burst staging path before reset release

## PCB Accuracy

| Area | Evidence basis |
| --- | --- |
| Konami CPU/device address map | Pinned Escape/Vendetta MAME driver and original program-ROM decode |
| K053252 raster totals | Original boot register writes and independent K053252 RTL/MAME totals: 384 × 264 |
| ER5911 serial EEPROM command framing and persistence | ER5911 device documentation, the pinned MAME `EEPROM_ER5911_8BIT` model, and the 128-byte MiSTer NVRAM contract |

Areas without qualifying board measurements are not claimed here. Native hardware display, audio, and control validation remains a separate release gate.

## Supported games

- Escape Kids (Asia, 4 Players)
- Escape Kids (Japan, 2 Players)

## Hardware emulated

| Hardware | Implementation / reference |
| --- | --- |
| Konami main CPU | JTCORES Konami CPU donor, Escape program map |
| K052109/K051962 tile/video logic | JTCORES video implementation |
| K053251/K053252 timing and priority | JTCORES devices, Escape register programming |
| Z80, YM2151 and K053260 audio | JTCORES sound devices with Escape PCM prefetch wrapper |
| ER5911 serial EEPROM | `jt5911` donor plus generated 128×8 NVRAM path; MRA index 2 is persistent storage for game high scores |
| MiSTer HPS, DDR3/SDRAM, video and OSD | MiSTer template framework; `JTFRAME_MR_DDRLOAD` stages ROM downloads in 1 KiB DDR3 bursts |

## Credits

- [JTCORES](https://github.com/jotego/jtcores) and Jotego contributors for the reusable arcade RTL, under its retained GPL-3.0-or-later notices.
- [MiSTer-devel Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer) for the platform framework.
- The MAME project and its Konami/Vendetta driver for reference behavior and ROM mappings.
- Escape Kids original ROM data is not included; users must provide legally obtained ROMs.

## License

Project-specific source is released under GPL-3.0-or-later. Vendored JTCORES and MiSTer framework files retain their upstream copyright and license notices. See [LICENSE](LICENSE).

## How to install

Copy the RBF and both MRA files from `releases/` to `/media/fat/_Arcade/` on the MiSTer SD card (or the equivalent MiSTer release folder). Place the legally obtained Escape Kids ROM ZIPs in the location expected by the MRA files.

For automatic installation, add this entry to `downloader.ini`:

```ini
[meathax/meatcores]
db_url = https://raw.githubusercontent.com/meathax/meatcores/db/downloader_meathax_meatcores.zip
```

Then run **Update All** on MiSTer.

## Development

Production RTL is under `rtl/`; the MiSTer framework is under `sys/`; release MRAs and accepted RBF artifacts are under `releases/`. Build and verification metadata is intentionally kept out of the public source package.

README structure follows the [meathax/s32](https://github.com/meathax/s32) core documentation pattern.
