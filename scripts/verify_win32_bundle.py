"""Verify a deployed Qt5/MinGW bundle contains *only* x86 PE binaries.

Optional cross-platform check; requires only Python 3 on the build computer.
The tablet itself does not need Python.

    python scripts/verify_win32_bundle.py out/package-win32/DomowyPlan
"""
from __future__ import annotations

import argparse
from pathlib import Path

REQUIRED = (
    "DomowyPlan.exe", "Qt5Core.dll", "Qt5Gui.dll", "Qt5Qml.dll",
    "Qt5Quick.dll", "Qt5Sql.dll", "platforms/qwindows.dll",
    "sqldrivers/qsqlite.dll", "libgcc_s_dw2-1.dll", "libstdc++-6.dll",
    "libwinpthread-1.dll", "URUCHOM.bat", "ZAINSTALUJ.bat",
)


def pe_machine(path: Path) -> int:
    """Read IMAGE_FILE_HEADER.Machine from a Windows PE image."""
    with path.open("rb") as handle:
        if handle.read(2) != b"MZ":
            raise ValueError(f"Missing MZ header: {path}")
        handle.seek(0x3C)
        offset_data = handle.read(4)
        if len(offset_data) != 4:
            raise ValueError(f"Truncated DOS header: {path}")
        offset = int.from_bytes(offset_data, "little")
        if offset < 64 or offset > path.stat().st_size - 6:
            raise ValueError(f"Invalid PE offset: {path}")
        handle.seek(offset)
        if handle.read(4) != b"PE\0\0":
            raise ValueError(f"Invalid PE signature: {path}")
        machine = handle.read(2)
        if len(machine) != 2:
            raise ValueError(f"Truncated COFF header: {path}")
        return int.from_bytes(machine, "little")


def verify_bundle(folder: Path) -> list[str]:
    issues: list[str] = []
    if not folder.is_dir():
        return [f"Directory does not exist: {folder}"]
    for file in REQUIRED:
        if not (folder / file).is_file():
            issues.append(f"Missing: {file}")
    qml_found = any(
        p.parent.name == "Controls.2" and p.parent.parent.name == "QtQuick"
        for p in folder.rglob("qmldir")
    )
    if not qml_found:
        issues.append("Missing QtQuick/Controls.2/qmldir")
    binaries = [p for p in folder.rglob("*")
                if p.is_file() and p.suffix.lower() in {".dll", ".exe"}]
    if not binaries:
        issues.append("No PE binaries found")
    for binary in binaries:
        try:
            machine = pe_machine(binary)
            if machine != 0x14C:
                issues.append(f"Not x86 (PE machine 0x{machine:04x}): {binary}")
        except (OSError, ValueError) as exc:
            issues.append(str(exc))
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path, help="Directory containing DomowyPlan.exe")
    args = parser.parse_args()
    issues = verify_bundle(args.folder)
    if issues:
        for issue in issues:
            print("ERROR:", issue)
        return 1
    count = sum(p.suffix.lower() in {".exe", ".dll"}
                for p in args.folder.rglob("*") if p.is_file())
    print(f"OK: {count} PE binaries verified as 32-bit x86")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
