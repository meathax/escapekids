# Escape Kids presentation-crop iteration

Date: 2026-08-24

## Decision record

Observation:

- Escape Kids' authentic native raster is 384 horizontal clocks by 264 vertical
  lines, with a 321x240 game-visible window. The unwanted presentation edge is
  the source active-column range outside columns 12..299 inclusive.
- The prior framework-facing `VGA_DE` exposed the complete 321x240 window, and
  the project advertised a 5:4 aspect ratio even though the requested picture
  is 288x240 (4:3).

Evidence:

- Pinned MAME `vendetta.cpp` uses
  `set_raw(24_MHz_XTAL / 4, 384, 0, 321, 264, 0+8, 240+8)`: 6 MHz pixel,
  HTOTAL 384, VTOTAL 264, horizontal visible interval 0..320, and vertical
  visible interval 8..247.
- The pre-change strict native-raster receipt and the post-change Asia and
  Japan receipts all report `total_h=384`, `total_v=264`, and
  `pixel_ticks=101376`. The register-write fingerprint is unchanged:
  `writes=12`, vector `017F0012000D00010107080773`, commit PC `0x80b7`, raw PC
  `0x80bb`, opcode `0x3a`, address `0x3fcc`, data `0x73`.
- The native horizontal counter is the Escape bridge's 9-bit
  `jtsimson_scroll.esc_hdump`, which advances once per `pxl_cen` through the
  measured 384-pixel domain `0x020..0x19f`. The captured native-frame receipt
  reports `hdump_min=32` and `hdump_max=415`. Therefore the content mapping is
  **INFERRED from the pinned 321-pixel active interval and this counter trace**:
  source column 0 = `hdump 0x020`, column 12 = `0x02c`, last kept column 299 =
  `0x14b`, first cropped column 300 = `0x14c`, strip column 316 = `0x15c`, and
  last native active column 320 = `0x160`; native HBlank follows at
  `0x161..0x19f`. The 9-bit counter is reset/reloaded by the existing CCU
  `hld` path; it is not changed by this iteration.
- The K053252 outputs `ccu_lhbl/ccu_lvbl/ccu_hs/ccu_vs` and registered `hld/vld`
  into `jtsimson_scroll`. JTFRAME then derives its `arcade_video` blanking and
  `video_freak` output DE from that path. The new crop is downstream of the
  imported child `VGA_DE`, at the project `emu` boundary, so the CCU blanking
  and all game/video-chip timing remain authoritative.
- The accepted MAME raw frame
  `.mister/mame-gameplay-pixels/snap-20260822T152356163Z-17525c4c/frame_00425.png`
  is 321x240. In that captured scene columns 300..320 contain non-black
  pixels; the captured edge is not universally a black border and columns
  316..320 do not equal columns 12..16. Therefore the crop is recorded as an
  explicit presentation convention. **INFERRED classification:** the MAME
  edge is scene-dependent CCU/border behaviour hidden by the crop, not a reason
  to rewrite internal timing. The MAME frame SHA256 is
  `E519874DA726BE44618B7D713596D111EC70F8A3FE41610CBA57BBDD23BA6DEA`.
- The existing native RTL frame
  `.mister/frame-cap-esckids-centering-fix-425/frame_00425.ppm` is also 321x240.
- Existing evidence in `.mister/evidence/video-edge-rowscroll-20260823.md`
  describes separate background-strip behaviour. This iteration does not
  alter the internal raster or claim that issue closed.

Hypotheses:

1. The K053252/driver raster geometry is wrong. This is falsified by the
   unchanged strict raster fingerprint and the exact MAME geometry.
2. The final presentation active-enable exposes unwanted edge columns. This
   is the selected explanation and is consistent with a boundary-only crop.
3. The internal counters, sync, IRQ, CCU, tile, sprite, or palette timing
   needs changing. This is rejected because the requested correction is
   presentation-only and the native timing receipt is unchanged.

Selected explanation:

The correction belongs at the project-owned final presentation boundary. The
source game raster remains intact; only the `VGA_DE` active-enable presented to
the MiSTer framework is narrowed to the desired 288 columns.

Smallest change:

- `rtl/esckids/escape_kids_emu.sv` now receives the imported JTFRAME active
  enable as `jtframe_vga_de` and drives the project `VGA_DE` through
  `escape_kids_presentation_crop`.
- `rtl/esckids/escape_kids_presentation_crop.sv` counts source active pixels
  on `CLK_VIDEO`/`CE_PIXEL`. It uses `LEFT=12`, `RIGHT=300` (exclusive), a
  9-bit source-column counter, synchronous `RESET`, reset-on-blanking, and
  right-edge saturation. The output is active exactly for source columns
  `[12,300)`, giving 288 pixels per active line.
- RGB, HSYNC, VSYNC, `JTFRAME_WIDTH=320`, `JTFRAME_HEIGHT=240`, all internal
  H/V counters, sync/blanking generation, K053252/052109/053246/053251 logic,
  game-visible timing, and ROM/download behaviour are unchanged.
- `JTFRAME_ARX/JTFRAME_ARY` was changed from `5/4` to `4/3` in the project
  macro/configuration surfaces and the checked validator. The crop is
  equivalent to a presentation active-area change; it does not change the
  native raster totals or game timing.

## Verification

The dedicated headless crop contract passes:

- `.mister/run_presentation_crop.ps1`
- `.mister/presentation-crop-receipt.json`
- Synthetic 384x264 input with a 321x240 source active window produced exactly
  288 active pixels on each of 240 lines, no active pixels in vertical blanking,
  and the expected left/right boundaries.
- Strict Verilator settings were used with `--threads 1`, assertions enabled,
  no SDL/display backend, and a unique volatile `R:/Verilator` workspace.

Integration checks:

- Full top/emu strict lint passed with zero errors. The 1424 warning records
  are the existing donor/framework warning population; no crop-specific
  warning was introduced.
- Strict native-raster replay passed for both `esckids` and `esckidsj`; both
  retained the exact 384x264/101376-pixel timing fingerprint above.
- The existing project full-smoke frame barriers also passed for both sets in
  the current source tree (`full_smoke_pass`, diagnostic-only lane): Asia
  receipt `.mister/verilator-hdl-traces/esckids-verilator-20260823T153741643Z-f51a2658-receipt.json`
  and Japan receipt
  `.mister/verilator-hdl-traces/esckidsj-verilator-20260823T154142637Z-16b70f80-receipt.json`.
  Both used the strict headless build contract (`--threads 1`, assertions,
  no display backend) and include the new crop source in their effective
  source closure.
- `python tools/validate_jtframe_config.py` passed for both sets.
- `git diff --check` passed.
- Quartus Prime 17.0.2 Build 602 Analysis & Synthesis (`map`) passed with
  zero errors. The current map receipt/log is
  `.codex-mister-build/EscapeKids/20260824-021415-893-map/`; it reports
  42,086 logic cells, 1,480 RAM segments, 67 DSP elements, 3 PLLs, and 174
  warnings. No warning line names `escape_kids_presentation_crop`; the
  warning population is donor/framework/IP/constraint related. The prior
  full-compile log reported 173 warnings, so this is not claimed as a
  warning-count reduction or a full no-new-warning proof. The prior known-good
  3,061,120-byte RBF was preserved at
  `.codex-mister-build/preserved/20260824-021400-476/001-EscapeKids.rbf` with
  SHA256 `12A9256353F1C7FEA6DD4FF47C72C0320BA2DCA0F720B0493D338463467733BC`.

The framework-facing geometry is therefore:

| Boundary | Before | After |
|---|---:|---:|
| Native total | 384x264 | 384x264 |
| Native active source window | 321x240 | 321x240 |
| Final `VGA_DE` active window | 321x240 | 288x240 |
| Horizontal source columns | 0..320 | 12..299 |
| Vertical source lines | 240 lines | 240 lines |
| Aspect metadata | 5:4 | 4:3 |

The dedicated crop regression proves the active-enable geometry at the
framework boundary; it is not a replacement for a post-build RGB frame dump.
The available pre-change/native RGB capture remains 321x240, so the final
shell-integrated RGB edge pixels still require a fresh RBF/hardware capture.

The existing coin-to-gameplay background-strip runner was started with its
authenticated media, exact input timing, and frame-2090 stop contract. It was
stopped cleanly at native frame 657 after producing gameplay frame 630. That
321x240 capture (`.mister/frame-cap-esckids-coin2gameplay/frame_00630.ppm`,
SHA256 `e669ee5c28f40bcbe0eda09e386954c69b5fb4f3ebbc545fded7155befe2ab7d`)
has non-black pixels in every row at columns 316..320, while columns 12..16
are black in this scene; columns 316..320 are not pixel-identical to 12..16.
This confirms the right-edge strip in RTL and records it as a presentation
boundary divergence intentionally hidden by the crop. The full frame-2090
runner did not complete and is not claimed as a regression pass; the prior
frame-3390 closure remains open in
`.mister/evidence/video-edge-rowscroll-20260823.md`.

## Regression scope and remaining verification

The affected path is the final framework-facing DE path used by HDMI and
analog output, plus the aspect metadata. Asia and Japan set profiles were
covered. The shared K053252/CCU and game logic were deliberately not changed.

MAME/Verilator-specific MCP operations were not callable in this session. The
historical capability inventory is retained in `.mister/mcp_capabilities.json`;
the local pinned headless runners were used instead, with their build/run
receipts and hashes preserved.

Quartus Analysis & Synthesis passed in the synthesis-only `map` stage, but no
full fit/STA/assembler flow, final RBF, or physical MiSTer recapture was run
in this iteration. A fresh compressed RBF and hardware check remain required
before release: keep the known-good RBF for rollback, verify 4:3
centering on HDMI and analog, inspect the first/last visible columns and
scandoubled output, and confirm reset, OSD, inputs, audio, sync, and native
refresh. Do not treat the crop regression or Verilator raster result as
hardware evidence.

The prior background-strip observation remains open. If a future capture shows
those strips at the new presentation boundary, trace their first causal
producer in the internal renderer before considering any additional crop or
mask.

## 2026-08-24 tile-strip differential investigation — diagnostic gate

Observation:

- The current authenticated Verilator frame capture completed deterministically
  through barrier frame 1001. The blue player-intro window is present before
  the scripted coin edge; the requested causal tile/GFX divergence is not yet
  bound to a named pixel.

Evidence:

- KNOWN: pinned MAME binary, driver, and ROM archive identities remain the
  hashes recorded in `.mister/mame_reference.json` and
  `.mister/rom_regions.json`.
- KNOWN: baseline receipt is
  `.mister/frame-cap-task-blue-baseline-a/run-receipt.json`; it reports
  authenticated media, strict Verilator 5.050, `--threads 1`, headless mode,
  `run_exit=0`, and `frame_capture_done` at frame 1001.
- KNOWN: baseline frame 400 is
  `.mister/frame-cap-task-blue-baseline-a/frame_00400.ppm`; its native frame
  is 321x240 and its receipt hash is recorded in `frames.jsonl`.
- INFERRED: the pre-coin frame family is semantically equivalent to the clean
  MAME player-intro capture, but raw frame ordinals still require scroll-phase
  alignment.

Hypotheses:

1. Authenticated graphics download/interleave or bank lane corruption.
2. Wrong K052109 tile code/attribute, bank, fine-y, flip, or sorted ROM
   address.
3. Tilemap RAM readback or CPU/render collision.
4. SDRAM response timing/cache collision, lower ranked because the symptom is
   stable in layer space.

Selected explanation:

- None yet. The next run adds only `VERILATOR`-gated read-only observation in
  the existing full-top bench; no RTL behavior is changed.

Smallest change:

- Add a bounded video trace plusarg and an optional MAME tilemap dump. Keep
  all production timing, memory, address, and bus paths unchanged.

Verification:

- Rebuild the fresh Verilator model, capture the named tile/pixel and its
  computed/returned graphics word, compare against the authenticated stream
  and MAME tilemap bytes, then rerun the clean frame scenario.

Regression scope:

- Asia 4P first; then shared K052109/K051962 tilemap/GFX path, Japan 2P
  sibling smoke, existing raster/loader/tile/priority/sprite/audio checks.

Known unknowns:

- Exact affected coordinate, MAME/RTL scroll-phase mapping, and whether the
  far-right band is the same internal producer remain unresolved. No RBF or
  hardware claim is made.
