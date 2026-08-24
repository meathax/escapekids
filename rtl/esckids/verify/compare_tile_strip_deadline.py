#!/usr/bin/env python3
"""Compare the Escape Kids tile-row deadline regression against pinned evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

PIXEL_SCHEMA = "escape-kids-video-pixel-v1"
OLD_FINGERPRINT = {
    "layer": "B",
    "x": 144,
    "y": 100,
    "address": "0x3bbfc",
    "expected": "0x00ffffff",
    "actual": "0xffffffff",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        return json.load(stream)


def analyse_trace(path: Path, rom_path: Path) -> dict[str, Any]:
    rom = rom_path.read_bytes()
    stats: dict[str, dict[str, Any]] = {
        layer: {"loads": 0, "mismatches": 0, "first_mismatch": None}
        for layer in ("F", "A", "B")
    }
    mismatches: list[dict[str, Any]] = []
    pregrant_address_changes = 0

    with path.open("r", encoding="utf-8") as stream:
        for line in stream:
            event = json.loads(line)
            if event.get("schema") == "escape-kids-video-bank2-v1":
                if event.get("event") == "address_changed":
                    pregrant_address_changes += 1
                continue
            if event.get("schema") != PIXEL_SCHEMA:
                continue

            checks: list[tuple[str, str, str]] = []
            if event["hsub_a"] == "0":
                checks.append(("A", event["sorted_a"], event["rom_a_data"]))
            if event["hsub_b"] == "0":
                checks.append(("B", event["sorted_b"], event["rom_b_data"]))
            if int(event["hdump"], 16) & 7 == 0:
                checks.append(("F", event["sorted_f"], event["rom_f_data"]))

            for layer, address_text, actual_text in checks:
                address = int(address_text, 16)
                offset = 0x1E0004 + address * 4
                if offset + 4 > len(rom):
                    raise ValueError(f"{layer} address 0x{address:x} is outside {rom_path}")
                expected = struct.unpack_from("<I", rom, offset)[0]
                actual = int(actual_text, 16)
                layer_stats = stats[layer]
                layer_stats["loads"] += 1
                if actual != expected:
                    mismatch = {
                        "ordinal": layer_stats["loads"] - 1,
                        "layer": layer,
                        "x": event["x"],
                        "y": event["y"],
                        "address": f"0x{address:x}",
                        "expected": f"0x{expected:08x}",
                        "actual": f"0x{actual:08x}",
                        "tile_vaddr": f"0x{int(event['tile_vaddr'], 16):x}",
                        "tile_map_a": f"0x{int(event['tile_map_a'], 16):x}",
                        "tile_map_b": f"0x{int(event['tile_map_b'], 16):x}",
                    }
                    layer_stats["mismatches"] += 1
                    if layer_stats["first_mismatch"] is None:
                        layer_stats["first_mismatch"] = mismatch
                    if len(mismatches) < 64:
                        mismatches.append(mismatch)

    return {
        "path": str(path.resolve()).replace("\\", "/"),
        "sha256": sha256(path),
        "layers": stats,
        "mismatches": mismatches,
        "pregrant_address_changes": pregrant_address_changes,
    }


def find_old_fingerprint(result: dict[str, Any]) -> bool:
    return any(
        all(mismatch.get(key) == value for key, value in OLD_FINGERPRINT.items())
        for mismatch in result["mismatches"]
    )


def mame_frame(receipt: dict[str, Any]) -> dict[str, Any]:
    trace_path = Path(receipt["trace"])
    frame_event = None
    with trace_path.open("r", encoding="utf-8") as stream:
        for line in stream:
            event = json.loads(line)
            if event.get("schema") == "esckids-mame-native-frame-v1":
                frame_event = event
    if frame_event is None:
        raise ValueError(f"No native MAME frame in {trace_path}")
    return {
        "trace": str(trace_path.resolve()).replace("\\", "/"),
        "trace_sha256": sha256(trace_path),
        "frame": frame_event,
    }


def tile_entry(rtl_vram: Path, mame_tilemap: Path, index: int) -> dict[str, Any]:
    rtl = rtl_vram.read_bytes()
    mame = mame_tilemap.read_bytes()
    if len(rtl) < 0x4000 or len(mame) < 0x4000:
        raise ValueError("Tilemap dump is shorter than the K052109 code/attribute range")
    result = {
        "index": f"0x{index:x}",
        "rtl_code": f"0x{rtl[index]:02x}",
        "rtl_attribute": f"0x{rtl[0x2000 + index]:02x}",
        "mame_code": f"0x{mame[0x2000 + index]:02x}",
        "mame_attribute": f"0x{mame[index]:02x}",
    }
    result["match"] = (
        result["rtl_code"] == result["mame_code"]
        and result["rtl_attribute"] == result["mame_attribute"]
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--before-trace", type=Path, required=True)
    parser.add_argument("--after-trace", type=Path, required=True)
    parser.add_argument("--after-repeat-trace", type=Path, required=True)
    parser.add_argument("--rom-stream", type=Path, required=True)
    parser.add_argument("--before-verilator-receipt", type=Path, required=True)
    parser.add_argument("--after-verilator-receipt", type=Path, required=True)
    parser.add_argument("--after-repeat-verilator-receipt", type=Path, required=True)
    parser.add_argument("--before-frame", type=Path, required=True)
    parser.add_argument("--after-frame", type=Path, required=True)
    parser.add_argument("--after-repeat-frame", type=Path, required=True)
    parser.add_argument("--expected-after-frame-sha256")
    parser.add_argument("--mame-receipt", type=Path, required=True)
    parser.add_argument("--mame-repeat-receipt", type=Path, required=True)
    parser.add_argument("--mame-snapshot", type=Path, required=True)
    parser.add_argument("--rtl-vram", type=Path, required=True)
    parser.add_argument("--mame-tilemap", type=Path, required=True)
    parser.add_argument("--tile-index", type=lambda value: int(value, 0), default=0x15E0)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    before = analyse_trace(args.before_trace, args.rom_stream)
    after = analyse_trace(args.after_trace, args.rom_stream)
    after_repeat = analyse_trace(args.after_repeat_trace, args.rom_stream)
    before_receipt = load_json(args.before_verilator_receipt)
    after_receipt = load_json(args.after_verilator_receipt)
    after_repeat_receipt = load_json(args.after_repeat_verilator_receipt)
    mame_receipt = load_json(args.mame_receipt)
    mame_repeat = load_json(args.mame_repeat_receipt)
    after_frame_sha = sha256(args.after_frame)
    after_repeat_frame_sha = sha256(args.after_repeat_frame)

    checks = {
        "before_reproduces_old_fingerprint": find_old_fingerprint(before),
        "before_has_layer_b_failure": before["layers"]["B"]["mismatches"] > 0,
        "after_all_layers_match_rom": all(
            after["layers"][layer]["loads"] >= 9000
            and after["layers"][layer]["mismatches"] == 0
            for layer in ("F", "A", "B")
        ),
        "after_pregrant_addresses_stable": after["pregrant_address_changes"] == 0,
        "after_repeat_all_layers_match_rom": all(
            after_repeat["layers"][layer]["loads"] >= 9000
            and after_repeat["layers"][layer]["mismatches"] == 0
            for layer in ("F", "A", "B")
        ),
        "after_repeat_pregrant_addresses_stable": (
            after_repeat["pregrant_address_changes"] == 0
        ),
        "before_verilator_clean_exit": before_receipt.get("build_exit") == 0
        and before_receipt.get("run_exit") == 0,
        "after_verilator_clean_exit": after_receipt.get("build_exit") == 0
        and after_receipt.get("run_exit") == 0,
        "after_repeat_verilator_clean_exit": (
            after_repeat_receipt.get("build_exit") == 0
            and after_repeat_receipt.get("run_exit") == 0
        ),
        "after_verilator_contract": after_receipt.get("headless") is True
        and after_receipt.get("display_backend") == "none"
        and after_receipt.get("threads") == 1
        and after_receipt.get("bank2_wait") == 20,
        "after_verilator_trace_deterministic": after["sha256"]
        == after_repeat["sha256"],
        "after_verilator_frame_deterministic": after_frame_sha
        == after_repeat_frame_sha,
        "mame_runs_acceptance_eligible": mame_receipt.get("acceptance_eligible") is True
        and mame_repeat.get("acceptance_eligible") is True,
        "mame_normalized_trace_deterministic": mame_receipt.get("trace_sha256")
        == mame_repeat.get("trace_sha256"),
        "mame_tilemap_deterministic": mame_receipt.get("tilemap_dump_sha256")
        == mame_repeat.get("tilemap_dump_sha256"),
    }
    entry = tile_entry(args.rtl_vram, args.mame_tilemap, args.tile_index)
    checks["affected_tile_entry_matches_mame"] = entry["match"]
    if args.expected_after_frame_sha256:
        checks["after_frame_matches_regression_hash"] = (
            after_frame_sha == args.expected_after_frame_sha256.upper()
        )

    receipt = {
        "schema": "escape-kids-tile-strip-comparator-v1",
        "scenario": "esckids_rules_bank2_deadline_frame400",
        "input": {
            "journal": "cold reset; authenticated esckids media; no gameplay input",
            "stop": "native frame 401 after capturing frame 400",
            "bank2_response_wait_clocks": 20,
            "rom_stream": str(args.rom_stream.resolve()).replace("\\", "/"),
            "rom_stream_sha256": sha256(args.rom_stream),
        },
        "active_divergence_before": {
            "domain": "tile_rom_word",
            "fingerprint": OLD_FINGERPRINT,
            "matching_prefix_layer_b_words": before["layers"]["B"]["first_mismatch"]["ordinal"],
        },
        "before": before,
        "after": after,
        "after_repeat": after_repeat,
        "matching_prefix_after": "stop barrier",
        "affected_tile_entry": entry,
        "frames": {
            "before_path": str(args.before_frame.resolve()).replace("\\", "/"),
            "before_sha256": sha256(args.before_frame),
            "after_path": str(args.after_frame.resolve()).replace("\\", "/"),
            "after_sha256": after_frame_sha,
            "after_repeat_path": str(args.after_repeat_frame.resolve()).replace("\\", "/"),
            "after_repeat_sha256": after_repeat_frame_sha,
            "expected_after_sha256": args.expected_after_frame_sha256,
            "mame_snapshot": str(args.mame_snapshot.resolve()).replace("\\", "/"),
            "mame_snapshot_sha256": sha256(args.mame_snapshot),
            "mame": mame_frame(mame_receipt),
        },
        "receipts": {
            "before_verilator": str(args.before_verilator_receipt.resolve()).replace("\\", "/"),
            "after_verilator": str(args.after_verilator_receipt.resolve()).replace("\\", "/"),
            "after_repeat_verilator": str(
                args.after_repeat_verilator_receipt.resolve()
            ).replace("\\", "/"),
            "mame": str(args.mame_receipt.resolve()).replace("\\", "/"),
            "mame_repeat": str(args.mame_repeat_receipt.resolve()).replace("\\", "/"),
        },
        "checks": checks,
        "failure_explanation": (
            "A 32-bit bank-2 tile burst can miss the K051962 load deadline and "
            "reuse one stale 32-bit row, producing an 8x1 garbage strip."
        ),
    }
    receipt["verdict"] = "pass" if all(checks.values()) else "fail"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=2))
    return 0 if receipt["verdict"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
