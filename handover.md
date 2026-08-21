# Escape Kids — hardware boot black-screen — handover

## Status: ROOT CAUSE FOUND, FIX NOT YET IMPLEMENTED

Diagnostics only so far. No functional RTL touched. Do not "fix" by removing
the halt — see Root cause below for why that would be dishonest.

## Root cause

Main KCPU is **permanently halted by a latched bus error**:

```verilog
// jtsimson_main.v:413
if( buserror ) berr_l <= 1;   // sticky, never cleared except by rst
// jtsimson_main.v:568
.halt( berr_l )               // wired straight into jtkcpu
```

`buserror` is a **microcode-raised illegal-opcode trap** (jtkcpu ucode), not a
bus timeout. Confirmed by hardware capture (pass 3 overlay): CPU frozen at
`cpu_addr=0x8058`, only 0x1F bytes past its own reset vector (`0x8039` at
`17c.bin:0x1FFFE`), with `main_cs`/`main_ok` both healthy — the memory path is
fine, the CPU simply is not advancing. Every video chip select is still
"never touched", so palette is never programmed and the picture is black
despite perfect video timing (VBL/HBL/pxl_cen all running).

**Open fork, not yet resolved:**
- (a) hardware returns different ROM data than the file at the trap address
  (SDRAM/memory-path bug) → fix belongs in the memory path
- (b) CPU reaches a real illegal opcode in the actual ROM (jtkcpu ucode gap)
  → fix belongs in KCPU microcode

These need opposite fixes. Pass 4 overlay (built, not yet hardware-read as of
this handover) exists specifically to settle this: compare `main_data` (live
byte hardware reads at the trap) against `17c.bin` at `pcbad`. If they match,
it's (b); if they differ, it's (a).

## Files changed (diagnostic-only, both marked TEMPORARY, revert before release)

- `rtl/vendor/jtcores/cores/simson/hdl/jtsimson_main.v` — 5 additive output
  ports (`dbg_berr_l`, `dbg_dtack`, `dbg_eep_rdy`, `dbg_pcbad[15:0]`,
  `dbg_aupper[7:0]`), pure pass-through assigns of existing internal signals.
  No behaviour change. Single call site (`jtsimson_game.v`), verified no
  other instantiation of `jtsimson_main` exists.
- `rtl/vendor/jtcores/cores/simson/hdl/jtsimson_game.v` — paged diagnostic
  overlay repurposing `debug_view` (was `assign debug_view = debug_mux;`).
  **Restore that line before any release build.**
- `rtl/vendor/jtcores/modules/jtframe/target/mister/hdl/jtframe_emu.sv` —
  reverted to stock (was touched in an earlier abandoned approach; do not
  re-touch it for this diagnostic — everything now lives in jtsimson_game.v).

## How the overlay works

JTFRAME already has an unused `debug_view` overlay row (bottom of screen,
drawn inside the game video path off `LHBL/LVBL/pxl_cen`, so it renders even
though the game's own video is black). `jtsimson_game.v` drives it with a
free-running page counter: displayed byte = `{page[3:0], payload[3:0]}`, so
the on-screen hex readout is literally **`PX`** — P = page number, X = that
page's nibble. Pages auto-advance every ~0.70 s (2^25 clk48 cycles); a full
sweep of all 15 pages takes ~10.5 s. No keyboard needed — just power on and
record ~12-15 s of the screen.

Pages run **1..F, never 0**: the overlay hides the row on an all-zero byte,
and "page 0, payload 0" is exactly the "CPU completely dead" case that must
stay visible, so page numbering skips 0 entirely.

Reading a capture: crop+tile the overlay row across the sweep (ffmpeg
`crop`+`tile` into one contact sheet) rather than eyeballing scattered frames.

## Current page map (pass 4 — the build in flight as of this handover)

| page | payload bits (MSB→LSB) | meaning |
|---|---|---|
| 1 | `main_cs_act` `main_ok_act` `main_cs_stuck` `cpu_addr_changing` | CPU halt confirmation. `main_cs`=1,`main_ok`=0 → CPU wedged waiting on ROM. `stuck`=1 → cs held high a whole period, no data. `addr_changing`=0 → CPU not advancing at all (this is the established state). |
| 2 | `berr_l` `dtack`(live) `eep_rdy`(live) `1`(marker) | `berr_l`=1 confirms the halt mechanism directly. Marker bit validates readout orientation — if it reads 0, the decode is wrong. |
| 3 | `cpu_addr[15:12]` | |
| 4 | `cpu_addr[11:8]` | |
| 5 | `cpu_addr[7:4]` | |
| 6 | `cpu_addr[3:0]` | pages 3-6 together = full 16-bit CPU address bus, live/frozen. |
| 7 | `pcbad[15:12]` | |
| 8 | `pcbad[11:8]` | |
| 9 | `pcbad[7:4]` | |
| A | `pcbad[3:0]` | pages 7-A = PC **latched at the exact moment of the trap** (jtkcpu_ctrl.v:152). This is the authoritative "where it died" address — may differ slightly from the frozen `cpu_addr` on pages 3-6. |
| B | `main_data[7:4]` | |
| C | `main_data[3:0]` | pages B-C = the live ROM byte the frozen CPU is currently reading. **Compare this against `17c.bin` at the `pcbad` address** to resolve the (a)/(b) fork above. |
| D | `Aupper[7:4]` | |
| E | `Aupper[3:0]` | pages D-E = jtkcpu's own bank/page register (`addr[23:16]` from the CPU itself). Confirms the bank register isn't the reason the CPU landed in the wrong region. |
| F | `rgb_nz` `vbl_act` `hbl_act` `pxl_cen_act` | video output sanity — expect `0 1 1 1` (no non-black pixel, but timing alive). |

## Address decode reference (for reading pcbad / cpu_addr by hand)

Fixed program window: `A[15]` set → `rom_addr = {4'b0011, A[14:0]}`
(`jtsimson_main.v:356-357`). So CPU address `0x8000-0xFFFF` maps directly to
ROM file offset `0x18000-0x1FFFF` in `17c.bin` (mask off bit 15, OR in
`0x18000`... concretely: `rom_file_offset = (cpu_addr & 0x7FFF) | 0x18000`).

Banked window (`A[15:13]==3`, i.e. `0x6000-0x7FFF`): `rom_addr = {2'b00,
Aupper[3:0], A[12:0]}` — physical ROM offset depends on the `Aupper` bank
nibble, not a fixed formula; read `Aupper` off pages D-E to compute it.

Reset vector: `17c.bin` offset `0x1FFFE` = `0x8039` (word value, i.e. CPU
starts execution at logical `0x8039`). IRQ vector unknown-offset (0xFFF8) not
yet checked; FIRQ vector not yet checked — check `17c.bin` at `0x1FFF8` etc.
if needed later.

## Prior passes (superseded, kept for context — do not repeat these builds)

- **Pass 1**: sticky bits (PLL locked, download done, reset released, any/
  bank0 SDRAM ack). All green. Ruled out PLL/SDRAM/reset/download entirely.
- **Pass 2**: windowed activity + `esckids`/`any_profile` export. Found
  `esckids=1` (profile correct — killed the donor-rst8-reset-hold hypothesis)
  and the decisive `ba0_ack=0` while `ba_any_ack=1` — bank0 idle while other
  banks stream. **This build also touched `jtframe_emu.sv` and introduced a
  real timing failure** (-0.051 ns setup, Slow 1100mV -40C, single endpoint on
  `pll_hdmi|...|divclk`) from placement disturbance — never shipped, and
  `jtframe_emu.sv` was reverted to stock afterward. Don't repeat that mistake;
  keep all diagnostic logic inside `jtsimson_game.v`/`jtsimson_main.v` only.
- **Pass 3**: 16-page overlay (first version). Found the `berr_l`/halt
  mechanism and pinned `cpu_addr=0x8058`. Superseded by pass 4's page map
  above (pass 3's "ever" flags and rom_addr-detail pages were dropped as
  redundant once the halt mechanism was known).

Full detail with exact hex reads and reasoning for each pass is in
`.mister/iteration-log.jsonl` (search `hw-overlay-pass` / `hw-bringup`).

## Next steps

1. Build pass 4 (RTL done, build was starting when this handover was written
   — check `.codex-mister-build/EscapeKids/*/quartus.log` for the most recent
   compile result before rebuilding).
2. Get a ~12-15s hardware boot capture (video or screenshots covering a full
   page sweep).
3. Decode all 15 pages (crop+tile the overlay row across the capture).
4. Compute `pcbad` → ROM file offset, read that byte from `17c.bin`, compare
   against the captured `main_data`. Match → hypothesis (b), jtkcpu ucode gap;
   mismatch → hypothesis (a), memory-path/SDRAM bug.
5. Only then implement the actual fix, in the module the fork points to.
6. Before any release build: revert `jtsimson_game.v`'s
   `assign debug_view = ...` back to `assign debug_view = debug_mux;`, and
   remove the `dbg_*` port group from `jtsimson_main.v`.
7. Do not build/deploy an RBF without explicit user instruction — see
   `~/.claude/CLAUDE.md` RBF authorization rule.

## Git state

Two files modified locally, uncommitted as of this handover:
`jtsimson_game.v`, `jtsimson_main.v`. Not yet committed/pushed this pass.

**Remote divergence unresolved**: `origin/main` has one squashed commit
(`b7f62de`) not in local history; local has ~41 granular commits including
`.gitignore` cleanup the squashed commit doesn't have. RTL content is
byte-identical between the two at their respective tips (verified via `git
diff --stat` across trees) — no code conflict, but a push will be rejected
(non-fast-forward) until the user picks: force-push local (replaces the
remote commit, content-equivalent), rebase onto origin (drops local gitignore
work, re-admits artifacts it excluded), or merge (keeps both, re-admits
excluded artifacts). Do not resolve this without asking the user again if it
comes up in the next session — it was left open pending their choice.
