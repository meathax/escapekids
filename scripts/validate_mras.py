#!/usr/bin/env python3
"""Validate the checked-in Escape Kids MRA ROM contracts.

This is intentionally a metadata and archive-resolution test only.  It never
needs or creates copyrighted ROM data; the layout test uses synthetic bytes.
"""

from __future__ import annotations

import argparse
import binascii
import io
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MRAS = (
    ROOT / "releases" / "Escape Kids (Asia, 4 Players).mra",
    ROOT
    / "releases"
    / "_alternatives"
    / "EscapeKids"
    / "Escape Kids (Japan, 2 Players).mra",
)
JAPAN_ZIPS = "esckids.zip|esckidsj.zip"


def fail(message: str) -> None:
    raise AssertionError(message)


def validate_mra(path: Path) -> None:
    tree = ElementTree.parse(path)
    root = tree.getroot()
    if root.tag != "misterromdescription":
        fail(f"{path}: root is {root.tag!r}, expected misterromdescription")

    rbf = root.findtext("rbf", "").strip()
    if not rbf or "/" in rbf or "\\" in rbf or "." in rbf:
        fail(f"{path}: rbf must be an undated basename without extension: {rbf!r}")

    if root.findtext("resolution", "").strip() != "15kHz":
        fail(f"{path}: resolution must be 15kHz")
    for tag in ("homebrew", "bootleg"):
        value = root.findtext(tag, "").strip()
        if value not in {"yes", "no"}:
            fail(f"{path}: {tag} must be yes/no, got {value!r}")

    roms = root.findall("rom")
    if not roms:
        fail(f"{path}: no rom blocks")
    indices = []
    for rom in roms:
        index_text = rom.get("index")
        if index_text is None:
            fail(f"{path}: rom block has no index")
        try:
            index = int(index_text, 10)
        except ValueError:
            fail(f"{path}: invalid rom index {index_text!r}")
        indices.append(index)
        if "type" in rom.attrib:
            fail(f"{path}: rom index {index} contains obsolete type attribute")

        external_parts = [
            part
            for part in rom.findall("part")
            if part.get("name") is not None or part.get("crc") is not None
        ]
        if not external_parts:
            continue

        zip_text = rom.get("zip", "")
        zip_names = zip_text.split("|") if zip_text else []
        if not zip_names or any(not name for name in zip_names):
            fail(f"{path}: rom index {index} has external parts but no zip list")
        if len({name.lower() for name in zip_names}) != len(zip_names):
            fail(f"{path}: rom index {index} repeats a zip archive")
        if any("/" in name or "\\" in name or not name.lower().endswith(".zip") for name in zip_names):
            fail(f"{path}: rom index {index} has a non-basename zip list: {zip_text!r}")

        for part in external_parts:
            crc = part.get("crc")
            if crc is None or len(crc) != 8:
                fail(f"{path}: rom index {index} has invalid CRC {crc!r}")
            try:
                int(crc, 16)
            except ValueError:
                fail(f"{path}: rom index {index} has invalid CRC {crc!r}")

    if len(indices) != len(set(indices)):
        fail(f"{path}: duplicate rom indices: {indices}")
    if 0 not in indices:
        fail(f"{path}: missing main rom index 0")

    if path.name == "Escape Kids (Japan, 2 Players).mra":
        for index in (0, 2):
            rom = next((candidate for candidate in roms if candidate.get("index") == str(index)), None)
            if rom is None or rom.get("zip") != JAPAN_ZIPS:
                actual = None if rom is None else rom.get("zip")
                fail(f"{path}: Japan rom index {index} must use {JAPAN_ZIPS!r}, got {actual!r}")


def zip_bytes(entries: dict[str, bytes]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, payload in entries.items():
            archive.writestr(name, payload)
    return output.getvalue()


def archive_crcs(blob: bytes) -> set[int]:
    with zipfile.ZipFile(io.BytesIO(blob)) as archive:
        return {info.CRC for info in archive.infolist()}


def resolve_by_crc(archives: dict[str, bytes], zip_list: str, crcs: list[int]) -> list[str]:
    resolved = []
    for crc in crcs:
        match = next(
            (
                archive_name
                for archive_name in zip_list.split("|")
                if archive_name in archives and crc in archive_crcs(archives[archive_name])
            ),
            None,
        )
        if match is None:
            fail(f"synthetic layout: CRC {crc:08x} was not found in {zip_list!r}")
        resolved.append(match)
    return resolved


def validate_synthetic_layouts() -> None:
    parent_payload = b"synthetic parent program"
    clone_payload = b"synthetic nested Japan clone program"
    nvram_payload = b"synthetic Japan nvram"
    crcs = [
        binascii.crc32(parent_payload) & 0xFFFFFFFF,
        binascii.crc32(clone_payload) & 0xFFFFFFFF,
        binascii.crc32(nvram_payload) & 0xFFFFFFFF,
    ]

    merged = {
        "esckids.zip": zip_bytes(
            {
                "975f02": parent_payload,
                "esckidsj/975r01": clone_payload,
                "esckidsj/esckidsj.nv": nvram_payload,
            }
        )
    }
    if resolve_by_crc(merged, JAPAN_ZIPS, crcs) != ["esckids.zip"] * 3:
        fail("synthetic merged layout did not resolve every part from the parent archive")

    split = {
        "esckids.zip": zip_bytes({"975f02": parent_payload}),
        "esckidsj.zip": zip_bytes(
            {"975r01": clone_payload, "esckidsj.nv": nvram_payload}
        ),
    }
    if resolve_by_crc(split, JAPAN_ZIPS, crcs) != [
        "esckids.zip",
        "esckidsj.zip",
        "esckidsj.zip",
    ]:
        fail("synthetic split layout did not fall back per part")

    nonmerged = {
        "esckidsj.zip": zip_bytes(
            {"975f02": parent_payload, "975r01": clone_payload, "esckidsj.nv": nvram_payload}
        )
    }
    if resolve_by_crc(nonmerged, JAPAN_ZIPS, crcs) != ["esckidsj.zip"] * 3:
        fail("synthetic non-merged clone layout did not resolve from the clone archive")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mras", nargs="*", type=Path, help="MRA files to validate")
    args = parser.parse_args()
    paths = args.mras or list(DEFAULT_MRAS)
    try:
        for path in paths:
            validate_mra(path)
        validate_synthetic_layouts()
    except (AssertionError, ElementTree.ParseError, OSError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: validated {len(paths)} MRA file(s) and synthetic merged/split/non-merged layouts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
