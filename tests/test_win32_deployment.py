import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "verify_win32_bundle", ROOT / "scripts" / "verify_win32_bundle.py"
)
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)


def fake_pe(machine):
    content = bytearray(96)
    content[:2] = b"MZ"
    content[0x3C:0x40] = (0x40).to_bytes(4, "little")
    content[0x40:0x44] = b"PE\0\0"
    content[0x44:0x46] = machine.to_bytes(2, "little")
    return bytes(content)


class Win32VerifierTests(unittest.TestCase):
    def test_pe_header_identifies_x86_vs_x64(self):
        with tempfile.TemporaryDirectory() as temp:
            binary = Path(temp) / "test.dll"
            binary.write_bytes(fake_pe(0x14C))
            self.assertEqual(VERIFY.pe_machine(binary), 0x14C)
            binary.write_bytes(fake_pe(0x8664))
            self.assertEqual(VERIFY.pe_machine(binary), 0x8664)

    def test_pe_header_rejects_invalid_files(self):
        with tempfile.TemporaryDirectory() as temp:
            binary = Path(temp) / "test.exe"
            binary.write_bytes(b"not a PE")
            with self.assertRaises(ValueError):
                VERIFY.pe_machine(binary)
            binary.write_bytes(b"MZ")
            with self.assertRaises(ValueError):
                VERIFY.pe_machine(binary)

    def test_bundle_requires_qt_plugins_and_x86_runtime(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            for filename in VERIFY.REQUIRED:
                file = folder / filename
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(fake_pe(0x14C) if file.suffix in {".exe", ".dll"} else b"batch")
            module = folder / "qml" / "QtQuick" / "Controls.2" / "qmldir"
            module.parent.mkdir(parents=True, exist_ok=True)
            module.write_text("plugin qtquickcontrols2plugin", encoding="utf-8")
            self.assertEqual(VERIFY.verify_bundle(folder), [])
            (folder / "Qt5Core.dll").write_bytes(fake_pe(0x8664))
            self.assertTrue(any("Not x86" in message for message in VERIFY.verify_bundle(folder)))
            (folder / "sqldrivers" / "qsqlite.dll").unlink()
            self.assertTrue(any("qsqlite.dll" in message for message in VERIFY.verify_bundle(folder)))

    def test_build_files_target_the_expected_toolchain(self):
        cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
        builder = (ROOT / "scripts" / "Build-Win32.ps1").read_text(encoding="utf-8")
        self.assertIn("DOMOWYPLAN_REQUIRE_X86", cmake)
        self.assertIn("Qt5 5.15.2 EXACT", cmake)
        self.assertIn("mingw81_32", builder)
        self.assertIn("mingw810_32", builder)
        self.assertIn("windeployqt.exe", builder)
        self.assertIn("Assert-X86", builder)
        self.assertIn("qsqlite.dll", builder)
        self.assertIn("QT_QUICK_BACKEND=software", (ROOT / "packaging" / "URUCHOM.bat").read_text())

    def test_installer_keeps_database_outside_program_files(self):
        source = (ROOT / "packaging" / "install" / "Install-Win32.ps1").read_text()
        uninstall = (ROOT / "packaging" / "install" / "Uninstall-Win32.ps1").read_text()
        self.assertIn("LOCALAPPDATA", source)
        self.assertIn("Startup", source)
        self.assertIn("LOCALAPPDATA", uninstall)
        self.assertNotIn("Remove-Item -LiteralPath $env:APPDATA", uninstall)


if __name__ == "__main__":
    unittest.main()
