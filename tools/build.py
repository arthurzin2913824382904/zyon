"""Embed the dependency-free UI into the single-file Roblox entry points."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MARKER = "-- @ZYON_UI_FACTORY@"
ui = (ROOT / "src/ZyonUI.luau").read_text()
factory = "local createZyonUI = (function()\n" + ui + "\nend)()"
core = (ROOT / "src/zyon-core.luau").read_text()
assert core.count(MARKER) == 1, "Core must have exactly one UI insertion point"
main = core.replace(MARKER, factory)
preview = '''-- Zyon Hub UI preview: run as a LocalScript in StarterPlayerScripts.
-- No Illegal Soccer modules or gameplay automation are loaded by this preview.
'''+factory+'''
local player = game:GetService("Players").LocalPlayer
local parent = player:WaitForChild("PlayerGui")
local previous = parent:FindFirstChild("ZyonHubPreview")
if previous then previous:Destroy() end
createZyonUI({
    parent = parent,
    guiName = "ZyonHubPreview",
    playerName = player.DisplayName,
    viewport = function()
        local camera = workspace.CurrentCamera
        return camera and camera.ViewportSize or Vector2.new(1280, 720)
    end,
})
'''
outputs = {"zyon-hub.lua": main, "zyon-ui-preview.lua": preview}
for name, contents in outputs.items():
    destination = ROOT / name
    if "--check" in sys.argv:
        assert destination.is_file() and destination.read_text() == contents, f"Rebuild {name}: python3 tools/build.py"
    else:
        destination.write_text(contents)
print("Verified generated entry points" if "--check" in sys.argv else "Generated zyon-hub.lua and zyon-ui-preview.lua")
