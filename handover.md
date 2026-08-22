# Escape Kids — ROM-ready black-screen repair handover

## 22 August hardware screenshot correction

The complete 32-page hardware-debug capture supersedes the earlier
four-byte-word conclusion below. The frozen transaction is logical `0x8058`
(`main_rom_addr=0x18058`) returning `0x07`; the correct byte is `0xC2`, while
`0x07` belongs to `0x805a`. Both addresses occupy the same 32-bit cache word.

The first ready helper compared only `main_rom_addr[18:2]`, so it explicitly
treated this dangerous same-word, different-byte re-entry as already valid.
The production helper now retains and compares the full 19-bit byte address.
Its directed regression reproduces `0x1805a -> 0x18058` with stale-high raw
ready and requires ready to fall before the `0x18058` response is accepted.

Post-correction evidence:

- strict focused Verilator: `ESCAPE KIDS ROM READY PASS`;
- full top elaboration: exit 0, zero errors, no diagnostic in the helper;
- cold Asia and Japan CPU/sound smokes: pass with no bus-error fingerprint;
- no shared cache, clock, reset, CDC, SDC, video, audio or MRA change.

The prior wording about a *different* cache word is retained below as historical
context only and must not be used as the current request-identity contract.

## Status: RTL IMPLEMENTED AND SIMULATION-ACCEPTED; HARDWARE PROOF PENDING

The real RTL repair is implemented. The comprehensive diagnostic overlay and
`dbg_*` ports remain enabled for Escape Kids hardware validation; donor
profiles retain the normal `debug_mux` path.

No Quartus build or RBF was produced in this iteration because the user did
not request one. A real MiSTer load is still required before claiming that the
hardware black screen is closed.

## Causal finding

Real-hardware pass 3 froze the KCPU at logical address `0x8058` with latched
`berr_l`, while `main_cs` and `main_ok` were both asserted. ROM inspection and
the canonical MAME trace show `0x8058 = 0xC2`, a valid KCPU `CLRD` opcode. The
failure occurs exactly when execution re-enters program ROM on a different
four-byte SDRAM/cache word after a ROM→RAM→ROM sequence.

The selected explanation is a stale level-sensitive `main_ok` being consumed
as completion of that new ROM request. A speculative read at `0x7c00` proved
that raw chip-select history cannot identify the last completed ROM word; only
a forwarded, completed transfer can update that identity.

## Implemented RTL

- `rtl/esckids/escape_kids_rom_ready.sv` implements an Escape Kids-only fresh
  ready handshake. On re-entry to a different completed four-byte ROM word,
  an already-high raw `rom_ok` is rejected until the interface is observed
  not-ready, after which the next high is forwarded to the CPU.
- `rtl/vendor/jtcores/cores/simson/hdl/jtsimson_game.v` inserts the helper only
  between `main_ok` and the main KCPU's `rom_ok` input when `esckids` is active.
  All donor profiles receive raw `main_ok` unchanged.
- `files.qip` and `.mister/generate_sources.ps1` include the production module.
- `rtl/esckids/verify/tb_escape_kids_rom_ready.sv` covers first request,
  same-word re-entry, incomplete speculative reads, multi-cycle stale-high,
  fresh low→high completion, reset/profile clearing, and donor bypass.
- `.mister/mame/trace_esckids.lua` classifies the direction-sensitive
  `0x7c00-0x7fff` write as K052109 metadata. This repairs trace semantics only;
  it does not mutate MAME or mask comparator fields.

## Accepted evidence

- Directed strict Verilator test: `ESCAPE KIDS ROM READY PASS`.
- Full headless Verilator, 3,000,000 cycles to frame barrier:
  - Asia receipt: `.mister/verilator-hdl-traces/esckids-verilator-20260821T163111353Z-46d73831-receipt.json`
  - Japan receipt: `.mister/verilator-hdl-traces/esckidsj-verilator-20260821T163157125Z-0138050b-receipt.json`
  - both `full_smoke_pass`, 641 events, no bus-error fingerprint.
- Independent replay of each compiled model produced the identical raw trace
  SHA-256 `B39306796527B7C403B18235C8DCA29B51B28795EB46C0578D399A493B385DF9`.
- Paired MAME captures are independently deterministic: raw trace SHA-256
  `9318B81258E795A91F1DC137A2CE7F9EA9BD4306E54C21A049E393F8F13A7742`.
- Comparator receipts under `.mister/normalized/rom-ready-fresh-accepted/`
  are admissible `MATCH`, with no masks and a full 640-event matching prefix
  for both `esckids` and `esckidsj`.
- Both lanes read event 36 at `0x8058` as `0xC2`.
- Final top lint: exit 0, errors 0; no warning names the new helper. Existing
  dirty-tree lint warnings remain outside this repair.

## Next step

When explicitly requested, build a fresh compressed RBF through the mandated
`mister-rbf-build` flow, verify timing and artifact receipts, retain the prior
known-good RBF, then load the new core on a real MiSTer. The decisive physical
check is that KCPU activity advances beyond `0x8058`, `berr_l` does not latch,
and boot/video initialization proceeds. Do not restore the debug overlay or
remove/bypass the CPU halt as a workaround.

## Repository state

Changes are uncommitted. The pre-existing dirty worktree and unrelated user
edits were preserved. The existing remote-history divergence remains
unresolved; do not rebase, merge, force-push, or otherwise resolve it without
the user's explicit direction.
