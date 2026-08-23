#!/usr/bin/env python3
"""Validate the tracked Escape Kids JTFRAME configuration contract."""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
import xml.etree.ElementTree as ET
from pathlib import Path


EXPECTED_MACROS = {
    "CORENAME": "EscapeKids",
    "GAMETOP": "jtsimson_game_sdram",
    "JTFRAME_HEADER": "4",
    "JTFRAME_COLORW": "8",
    "JTFRAME_PXLCLK": "6",
    "JTFRAME_WIDTH": "320",
    "JTFRAME_HEIGHT": "240",
    "JTFRAME_BUTTONS": "3",
    "JTFRAME_RATE": "59.19",
    "JTFRAME_BA1_START": "0x080000",
    "JTFRAME_BA0_LEN": "32",
    "PCM_START": "0x0A0000",
    "JTFRAME_BA2_START": "0x1E0000",
    "JTFRAME_BA3_START": "0x2E0000",
    "JTFRAME_PROM_START": "0x6E0000",
    "JTFRAME_IOCTL_RD": "128",
    "GAME_ROM_LEN": "0x6E0000",
    "JTFRAME_ARX": "5",
    "JTFRAME_ARY": "4",
    "JTFRAME_180SHIFT": "0",
    "JTFRAME_SHIFT": "1",
    "JTFRAME_LF_HW": "9",
    "JTFRAME_LF_VW": "8",
    "JTFRAME_MCLK": "48000000",
    "JTFRAME_TIMESTAMP": "0",
    "JTFRAME_MR_FASTIO": "0",
    "JTFRAME_DIALEMU_LEFT": "5",
    "JTFRAME_DEBUG_VPOS": "0",
}

REQUIRED_FLAGS = {
    "JTFRAME_MEMGEN",
    "JTFRAME_CLK48",
    "JTFRAME_MR_DDRLOAD",
    "JTFRAME_STEREO",
    "JTFRAME_JOY_DURL",
    "JTFRAME_JOY1_POS",
    "JTFRAME_OSD_TEST",
    "JTFRAME_NOMRA_DIP",
    "JTFRAME_RELEASE",
    "JTKCPU_DEBUG",
}


def fail(message: str) -> None:
    raise RuntimeError(message)


def normalize_value(value: str) -> str:
    value = value.strip().split("#", 1)[0].strip()
    value = re.sub(r"\d+'h([0-9a-fA-F]+)", r"0x\1", value)
    return value.lower()


def parse_macros(path: Path) -> tuple[dict[str, str], set[str]]:
    assignments: dict[str, str] = {}
    flags: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or line.startswith("["):
            continue
        if line.startswith("-"):
            continue
        if "=" in line:
            name, value = line.split("=", 1)
            assignments[name.strip()] = value.strip()
        elif re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", line):
            flags.add(line)
    return assignments, flags


def parse_verilog_macros(path: Path) -> tuple[dict[str, str], set[str]]:
    assignments: dict[str, str] = {}
    flags: set[str] = set()
    pattern = re.compile(r"^\s*`define\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+(.*?))?\s*$")
    for raw in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(raw)
        if not match:
            continue
        name, value = match.groups()
        if value is None:
            flags.add(name)
        else:
            assignments[name] = value.strip()
    return assignments, flags


def check_macros(root: Path) -> None:
    cfg_assignments, cfg_flags = parse_macros(root / "cfg" / "macros.def")
    vh_assignments, vh_flags = parse_verilog_macros(root / "rtl" / "esckids" / "jtframe_macros.vh")

    for name, expected in EXPECTED_MACROS.items():
        actual = cfg_assignments.get(name)
        if actual is None or normalize_value(actual) != normalize_value(expected):
            fail(f"cfg/macros.def: {name}={actual!r}, expected {expected!r}")
        vh_actual = vh_assignments.get(name)
        if vh_actual is None or normalize_value(vh_actual) != normalize_value(expected):
            fail(f"jtframe_macros.vh: {name}={vh_actual!r}, expected {expected!r}")

    missing_cfg_flags = sorted(REQUIRED_FLAGS - cfg_flags)
    missing_vh_flags = sorted(REQUIRED_FLAGS - vh_flags)
    if missing_cfg_flags:
        fail(f"cfg/macros.def missing flags: {', '.join(missing_cfg_flags)}")
    if missing_vh_flags:
        fail(f"jtframe_macros.vh missing flags: {', '.join(missing_vh_flags)}")


def check_mem_yaml(root: Path) -> None:
    text = (root / "cfg" / "mem.yaml").read_text(encoding="utf-8")
    required_fragments = (
        "params:",
        "clocks:",
        "audio:",
        "sdram:",
        "bram:",
        "module: jt053260",
        "- name: main",
        "addr_width: 19",
        "- name: snd",
        "addr_width: 17",
        "- name: pcma",
        "- name: pcmb",
        "- name: pcmc",
        "- name: pcmd",
        "- name: lyrf",
        "- name: lyra",
        "- name: lyrb",
        "- name: lyro",
        "addr_width: 22",
        "- name: nvram",
        "addr_width: 7",
        "ioctl: { save: true, restore: true, order: 0 }",
    )
    for fragment in required_fragments:
        if fragment not in text:
            fail(f"cfg/mem.yaml missing required topology fragment: {fragment}")


def check_mame2mra(root: Path) -> None:
    path = root / "cfg" / "mame2mra.toml"
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    parse = data.get("parse", {})
    if "vendetta.cpp" not in parse.get("sourcefile", []):
        fail("cfg/mame2mra.toml must parse vendetta.cpp")
    if set(parse.get("main_setnames", [])) != {"esckids", "esckidsj"}:
        fail("cfg/mame2mra.toml main_setnames must be esckids and esckidsj")

    header = data.get("header", {})
    header_data = {item["machine"]: item["data"] for item in header.get("data", [])}
    if header_data != {"esckids": "03 00 00 00", "esckidsj": "03 01 00 00"}:
        fail(f"unexpected header data: {header_data!r}")

    buttons = data.get("buttons", {}).get("names", [])
    if {item["machine"] for item in buttons} != {"esckids", "esckidsj"}:
        fail("button names must cover both Escape Kids sets")
    if any(item.get("names") != "Run,Super Jump,Auto Run" for item in buttons):
        fail("unexpected Escape Kids game-button names")

    regions = data.get("ROM", {}).get("regions", [])
    by_name = {item["name"]: item for item in regions}
    required = {
        "maincpu": {},
        "audiocpu": {"start": "JTFRAME_BA1_START"},
        "k053260": {"start": "PCM_START", "rename": "pcm"},
        "k052109": {"start": "JTFRAME_BA2_START", "width": 32, "rename": "tiles"},
        "k053246": {"start": "JTFRAME_BA3_START", "width": 64, "rename": "obj"},
    }
    for name, expected in required.items():
        if name not in by_name:
            fail(f"cfg/mame2mra.toml missing ROM region {name}")
        for key, value in expected.items():
            if by_name[name].get(key) != value:
                fail(f"ROM region {name} has {key}={by_name[name].get(key)!r}, expected {value!r}")
    if data["ROM"].get("order") != ["maincpu", "audiocpu", "pcm", "tiles", "obj"]:
        fail("unexpected MRA ROM order")


def check_mras(root: Path) -> None:
    expected_headers = {"esckids": "03 00 00 00", "esckidsj": "03 01 00 00"}
    mras = sorted((root / "releases").rglob("*.mra"))
    if len(mras) != 2:
        fail(f"expected exactly two Escape Kids MRAs, found {len(mras)}")
    for path in mras:
        tree = ET.parse(path)
        root_node = tree.getroot()
        setname = root_node.findtext("setname")
        if setname not in expected_headers:
            fail(f"unexpected MRA setname in {path}: {setname!r}")
        if root_node.findtext("resolution") != "15kHz":
            fail(f"{path}: resolution must be 15kHz")
        if root_node.findtext("homebrew") != "no" or root_node.findtext("bootleg") != "no":
            fail(f"{path}: homebrew/bootleg must be no")
        if root_node.findtext("rbf") != "Arcade-EscapeKids":
            fail(f"{path}: unexpected RBF basename")
        rom0 = root_node.find("rom[@index='0']")
        if rom0 is None or "type" in rom0.attrib:
            fail(f"{path}: rom index 0 must omit the deprecated type placeholder")
        if rom0.findtext("part") != expected_headers[setname]:
            fail(f"{path}: header bytes do not match cfg/mame2mra.toml")
        nvram = root_node.find("nvram[@index='2']")
        if nvram is None or nvram.get("size") != "128":
            fail(f"{path}: expected 128-byte persistent NVRAM at index 2")
        buttons = root_node.find("buttons")
        if buttons is None or not {"Run", "Super Jump", "Auto Run"}.issubset(
            set(buttons.get("names", "").split(","))
        ):
            fail(f"{path}: required game buttons are missing")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        check_macros(root)
        check_mem_yaml(root)
        check_mame2mra(root)
        check_mras(root)
    except (OSError, ET.ParseError, KeyError, TypeError, ValueError, RuntimeError) as exc:
        print(f"JTFRAME CONFIG FAIL: {exc}", file=sys.stderr)
        return 1
    print("JTFRAME CONFIG PASS")
    print("  target: EscapeKids / jtsimson_game_sdram")
    print("  sets: esckids, esckidsj")
    print("  stream: header + main + BA1 + PCM + BA2 tiles + BA3 objects")
    print("  MRA: 15kHz, Arcade-EscapeKids, NVRAM index 2 size 128")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
