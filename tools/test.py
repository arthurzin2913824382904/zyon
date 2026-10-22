"""Compile both entry points and test UI behavior plus the actual core adapters.

Usage: LUAU_BIN=/path/to/luau python3 tools/test.py
The matching luau-compile binary must be alongside luau or on PATH.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
luau = os.environ.get("LUAU_BIN") or shutil.which("luau")
if not luau:
    raise SystemExit("Set LUAU_BIN to the official Luau CLI executable.")
compiler = Path(luau).resolve().with_name("luau-compile")
if not compiler.is_file():
    compiler = shutil.which("luau-compile")
if not compiler:
    raise SystemExit("The official luau-compile executable is required.")

subprocess.run(["python3", "tools/build.py", "--check"], cwd=ROOT, check=True)
subprocess.run([str(compiler), "--null", "src/ZyonUI.luau", "zyon-hub.lua", "zyon-ui-preview.lua"], cwd=ROOT, check=True)
subprocess.run([luau, "tests/ui.spec.luau"], cwd=ROOT, check=True)

core = (ROOT / "src/zyon-core.luau").read_text()
start = core.index("local function toggleEnabled(value)")
end = core.index("--==============================================================\n-- SHUTDOWN", start)
integration = core[start:end]
test = (ROOT / "tests/core-adapters.spec.luau").read_text()
assert test.count("-- @INTEGRATION@") == 1
with tempfile.TemporaryDirectory(prefix="zyon-tests-") as temporary:
    script = Path(temporary) / "core-adapters.luau"
    script.write_text(test.replace("-- @INTEGRATION@", integration))
    subprocess.run([luau, str(script)], cwd=ROOT, check=True)
