# Escape Kids — blue-background strips & ROM 17C BAD: investigation state

Updated 2026-08-27. Continues from sessions of 2026-08-25..27. All claims
below are hardware-measured unless marked otherwise.

## THE HEADLINE

Two separate defects, both now precisely bounded:

**Defect 1 - `ROM 17C BAD` on the boot RAM/ROM check, DETERMINISTIC**
(every boot, every build, both download paths):
- SDRAM content is byte-perfect at the download boundary: on-screen Fletcher
  checksums (diag build) match offline goldens on the same boots that show
  BAD - stream-into-loader A = `143F:97DF`, loader-to-controller write
  transactions B = `8BFF:76DF`, byte count exact (0x6E0000).
- The game's checksum machinery works: `ROM 5F OK 46E5H` matches MAME.
- `DF80` is simply the 16-bit sum of every byte of `17c.bin` (verified
  offline). MAME 0.289 shows the check sweeping mainbank entries 0..11
  (frames 144..186, one entry every 2-3 frames) plus the fixed
  0x8000-0xFFFF window - i.e. the whole 128 KiB exactly once.
- NOT a bank-mapping defect (2026-08-27, supersedes the earlier conclusion):
  a `+SMOKE_BANKSUM_STOP` probe accumulating the bytes the CPU accepts per
  bank matches every bank's golden sum in BOTH the functional-SDRAM and
  `-RealSdramTiming` Verilator lanes. No byte differs. Bank decode in
  `jtsimson_main.v` is exonerated; further RTL bank work is wasted effort.
- Remaining cause is therefore hardware-only: real SDRAM readback, or a
  synthesis/timing difference invisible to every simulation lane.

**Defect 2 — sparse 8x1 uniform-colour strips on the blue background,
RANDOM PER BOOT, stable within a boot (scroll-locked to the tilemap):**
Eliminated by direct measurement: download FIFO drops (hardware ovfl
counter = 0 on strip-bearing boots), runtime fetch timing (late-fetch
counters 0/0/0, lyrb worst latency 12-25 clk48 vs 64 budget on
strip-bearing boots), refresh interleave (Icarus chip-model sweeps clean),
DRAM decay (uniform words != bit decay), write-path address race (chip
model replay clean; earlier "confirmation" was two bench wiring bugs —
see lessons), the board itself (upstream jtsimson Vendetta on the SAME
MiSTer+module: clean, no BAD, no strips).
Remaining space: controller->chip write execution on real silicon, or a
per-boot-stable read-path defect — and Defect 1 proves this core HAS a
systematic read-path defect class. Strips may be the same family on the
video side. FIX DEFECT 1 FIRST; re-evaluate strips after.

## 2026-08-27 UPDATE — Defect 1's assumed root cause is REFUTED

The "systematic banked-read defect in the GX975 bank-window mapping"
hypothesis is falsified in simulation. Both project-owned Verilator lanes
read every banked byte correctly, so the core as simulated computes the
correct `DF80H` and would print `ROM 17C OK`.

Method (differential, MAME 0.289 `esckids` vs Verilator full-smoke):

- MAME side: a read tap on CPU 0x6000-0x7FFF keyed by `:mainbank`'s live
  entry shows the boot check sweeping bank entries 0..11 with exactly 8192
  reads each, from the loop at PC 0x8555 (`ADDB ,X+` / `ADCA #0` / `LEAX` /
  `BNE`), plus the fixed 0x8000-0xFFFF window. Per-entry sums match the ROM
  image exactly (entry n == `17c.bin[n*0x2000 .. +0x2000)`).
- Golden arithmetic: `DF80` is the plain 16-bit byte sum of the whole
  128 KiB `17c.bin`; banks 0..11 sum to `99DD`, fixed 0x18000-0x1FFFF sums
  to `45A3`, and `99DD + 45A3 = DF80`.
- RTL side: `+SMOKE_BANKSUM_STOP=<frame>` probe added to
  `.mister/tb/tb_escape_kids_full_smoke.sv`, accumulating every byte the CPU
  accepts from the banked window keyed by `Aupper[3:0]` (plus the fixed
  region). Two lanes, authenticated MRA media, stop at frame 210:
  functional SDRAM, and `-RealSdramTiming`.
- Result: banks 2,3,6,7,8,9,10 (and 11 in the real-timing lane) show exactly
  four accepted samples per byte (a `cpu_cen`/`dtack` sampling artifact) and
  sums of exactly 4x the golden bank sum, e.g. bank 2 `3C38` = 4 x `8F0E`,
  bank 9 `CBC0` = 4 x `F2F0`. Banks 0,1,4,5,11 carry extra counts because the
  game also executes from them. No byte differs from the ROM image.

Consequence: the deterministic hardware `ROM 17C BAD` is NOT a bank-mapping
error and is not reproduced by the project's Verilator lanes at all. The
remaining space is hardware-only: SDRAM readback on the real chip, or a
synthesis/timing-level difference. Note the banks the game never executes
(2,3,6,7,8,9,10) are exactly the ones only the boot check touches, which is
consistent with a hardware readback fault in regions the game does not run
from, and would explain "checks BAD but plays fine".

Recommended next evidence (needs an RBF build, so it needs explicit
authorization): extend the on-screen diag overlay with a CPU-independent
readback checksum of SDRAM bank 0, offsets 0x00000-0x1FFFF, taken after
download completes, and show it next to the golden `DF80`. That splits
"SDRAM readback is wrong on hardware" from "the CPU read path is wrong on
hardware" in a single screenshot.

## NEXT STEPS (in order)

1. IN FLIGHT (2026-08-27): on-hardware SDRAM readback diagnostic.
   `rtl/esckids/escape_kids_rom_readback.sv` borrows the main-ROM SDRAM slot
   once after the download completes (the CPU stalls on dtack for the
   duration; the KCPU has no bus timeout, its `buserror` is a microcode trap)
   and runs three phases over 0x00000-0x1FFFF:
     phase 0  ascending byte sum            -> overlay rows 15-16, expect DF80
     phase 1  the same scan again           -> rows 17-18, must equal phase 0
     phase 2  per address read/evict/reread -> row 19 unstable count,
              rows 20-22 first unstable address, row 23 scanner flags
   Reading of the result:
     sums != DF80              -> SDRAM content or readback is wrong;
     sums == DF80, unstable>0  -> the slot returns different bytes for the
                                  same address, first_bad names where;
     everything clean          -> the defect is on the CPU-side request path
                                  (romrq/cache/handshake), not the memory.
2. After the Defect-1 fix on hardware: re-run the strip statistics
   (multi-boot screenshot sweep) to see if strips moved or died.
3. If strips persist: remaining leads are a per-boot-stable read-path defect
   (romrq/cache addressing under BA2_LEN=64) and physical write execution.

## TOOLING BUILT (all committed / on device)

- `ESCKIDS_STRIP_DIAG` overlay (commits 954ad85, 79a7022/88dc729, 73f3dd3):
  15 binary rows top-left, 4px blocks, MSB left, bright=1:
  rows 0-4 = ovfl / lyrb-late / lyra-late / lyrf-late / lyrb-maxlat;
  rows 5-8 = checksum A (white), 9-12 = checksum B (yellow),
  13-14 = byte count (green). Freezes after download. Presentation crop
  eats 12 px on the left: on SCREEN the blocks are at x0..31 (block n bit b
  sample x = b*4+1), rows y = 5,13,21,...,117.
  CRITICAL past bug (fixed in 73f3dd3): never clock these from game rst —
  game reset is held for the whole download and wipes the sums.
- Goldens: A via `.mister/compute_stream_checksum.py` over index0.bin
  (emit_mra_stream.py); B via `scratchpad/dwnld_sim/tb_bgolden.sv` Icarus
  replay. Asia set: A=143F:97DF, B=8BFF:76DF, count 0x6E0000.
- BAD/OK classifier + row decoder: `.mister/decode_strip_overlay.py` decodes
  all overlay rows from a native MiSTer screenshot. Geometry is 1:1 with the
  288x240 screenshot: bit b of row n is sampled at x = b*4+1, y = 5+8n,
  bright (>160 on any channel) = 1. Calibrated 2026-08-27 against the known
  download-checksum goldens. Check screen appears ~17 s after MRA load; BAD
  is red>8 px in x150-260/y30-230 on that screen.
- Icarus chip-model benches (scratchpad/dwnld_sim): tb_progwrite2 (write
  integrity + refresh sweep), tb_dwnld_addr (address-integrity, row-cross),
  tb_bgolden. Verilator+mt48 model is 2-state-unreliable: use ICARUS for
  the chip model. Validate every bench with a known-good control first.

## DEVICE / TREE STATE

- Repo HEAD `73f3dd3` (branch main): diag overlay + checksums, macro
  `ESCKIDS_STRIP_DIAG` ON in jtframe_macros.vh + EscapeKids.qsf.
  REMOVE BOTH before any release build.
- MiSTer cores dir: `Arcade-EscapeKids_ZCHK.rbf` = current diag build
  (sha256 7f0a54e3...) and is the MRA-selected core. TRAP: MiSTer's MRA
  resolution picks the LEXICOGRAPHICALLY LAST `Arcade-EscapeKids_*.rbf` —
  suffix letters beat dates ( _ZCHK > _FIX > _DIAG > _CTRL > dates ).
  Stashed test builds in `/media/fat/tmp_esc/`.
- MRA on device + repo: classic download (DDR address attr removed in
  f1c4b4e; DDR path corrupted even the program ROM).
- `releases/Arcade-EscapeKids_20260826.rbf` is currently a DIAG-macro
  build (20ffe18e...) mislabeled as release — rebuild clean before shipping.
- `rfsh` change in flight: jtframe_sdram64.v has `noreq_g` hblank-gating of
  idle refresh (commit? uncommitted? -> it was committed in the FIX build
  lineage; verify `git log rtl/vendor/.../jtframe_sdram64.v`). Harmless per
  measurements but NOT the strip fix.

## KEY NUMBERS / EVIDENCE INDEX

- 17C BAD rate: 14/14 (FIX build), 7/7 (ZCHK build), 3/3 (pre-noreq_g
  build) — deterministic. Vendetta upstream: 0 BAD.
- Strip-bearing boots measured with ALL counters clean (ovfl 0, late 0/0/0,
  maxlat 12-25). One outlier boot showed maxlat 159/208 + late counts —
  unexplained variance, low priority.
- Strip structure (prior session): every strip exactly 8px, 8-aligned, ONE
  uniform colour, 128px period both axes = per-tile-code; tile ROM contains
  3133 all-FF / 114898 all-00 words (wrong-address fetches mostly invisible).
- Evidence docs: `.mister/tile-strip-hardware-rootcause-20260825.md`
  (elimination matrix + 2026-08-27 audit appendix), project memory
  `esckids-strip-rootcause.md`, shared lessons (bench-control rule).

## 2026-08-28 BANK-2 REPAIR HANDOFF REGRESSION

- KNOWN RTL defect: `rtl/esckids/escape_kids_tile_repair.sv` released bank-2
  ownership at `ba2_dst`, the first response beat, while
  `JTFRAME_BA2_LEN=64` requires ownership through final `ba2_rdy`.
- Before fix: `.mister/verilator-hdl-traces/esckids-repair-probe.jsonl`
  (SHA256
  7c1a68c733e5f5e9a4658c51a4ddb59296746cb2ef1009cef3a4a27f6a9e75b6)
  showed 4/4 owner drops before burst tail. After fix:
  `.mister/verilator-hdl-traces/esckids-repair-probe-regression-clean.jsonl`
  (SHA256
  2fc22357f47a163448ab1d9f7b04130bab303bb23fa0c8ce2806e5760892157a)
  showed 5 burst starts, 5 tails, 4 post-tail drops, and 0 early drops;
  the probe assertion completed without firing.
- Focused verification: strict headless model build exit 0; CPU/sound
  self-test pass; Escape Kids and Japan raster regressions pass at the
  established 20,000,000-cycle / two-boundary contract.
- This closes a proven interconnect defect only. It does not prove that the
  extra repair engine corresponds to a PCB chip or that it causes the
  physical blue-background strips; those remain open pending native good/bad
  frame evidence and, ideally, board/ROM/logic-analyzer data.
