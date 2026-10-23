local createAutoSprint = require("../src/AutoSprint")
local function fixture()
    local f = { moving = true, physical = false, alive = true, denied = false, releaseDenied = false,
        binding = { KeyCodes = { "LeftShift" } }, calls = {}, connected = false }
    local input = {}
    function input:SendKeyEvent(down, key)
        if f.denied or (not down and f.releaseDenied) then error("permission denied") end
        f.calls[#f.calls + 1] = { down = down, key = key }
    end
    local heartbeat = {}
    function heartbeat:Connect(callback)
        f.tick, f.connected = callback, true
        return { Disconnect = function() f.connected = false end }
    end
    f.controller = createAutoSprint({
        heartbeat = heartbeat, target = {}, alive = function() return f.alive end,
        getBinding = function() return f.binding end,
        isKeyboardKey = function(key) return key == "LeftShift" end,
        getVirtualInput = function() return input end,
        shouldSprint = function() return f.moving end,
        isKeyDown = function() return f.physical end,
    })
    return f
end
local count = 0
local function test(name, fn)
    fn(); count += 1; print("PASS " .. name)
end
test("Auto Sprint uses the configured key and does not spam key-down", function()
    local f = fixture()
    assert(not f.controller.Get())
    assert(f.controller.Set(true))
    f.tick(); f.tick()
    assert(#f.calls == 1 and f.calls[1].down and f.calls[1].key == "LeftShift")
    assert(f.controller.Set(false))
    assert(#f.calls == 2 and not f.calls[2].down)
    f.controller.Cleanup()
end)
test("pausing movement, focus or chat releases the held key", function()
    local f = fixture()
    f.controller.Set(true); f.tick()
    f.moving = false; f.tick()
    assert(#f.calls == 2 and not f.calls[2].down)
    f.moving = true; f.tick()
    assert(#f.calls == 3 and f.calls[3].down)
    f.controller.Cleanup()
    assert(#f.calls == 4 and not f.calls[4].down and not f.connected)
end)
test("a physically held Sprint key is left to the player", function()
    local f = fixture()
    f.physical = true
    f.controller.Set(true); f.tick(); f.controller.Set(false)
    assert(#f.calls == 0)
    f.controller.Cleanup()
end)
test("missing key binding rejects activation with an explanation", function()
    local f = fixture()
    f.binding = nil
    local ok, reason = f.controller.Set(true)
    assert(not ok and reason and not f.controller.Get())
    f.controller.Cleanup()
end)
test("executor input denial disables Sprint and records the failure", function()
    local f = fixture()
    f.denied = true
    f.controller.Set(true); f.tick()
    assert(not f.controller.Get() and #f.calls == 0)
    assert(f.controller.Error():find("recusou"))
    f.controller.Cleanup()
end)
test("failed key release remains retryable during cleanup", function()
    local f = fixture()
    f.controller.Set(true); f.tick()
    f.releaseDenied = true
    assert(not f.controller.Cleanup() and f.connected)
    f.releaseDenied = false
    assert(f.controller.Cleanup() and not f.connected)
    assert(not f.calls[#f.calls].down)
    assert(not f.controller.Set(true))
end)
test("a stopped core releases Sprint on its next heartbeat", function()
    local f = fixture()
    f.controller.Set(true); f.tick()
    f.alive = false; f.tick()
    assert(#f.calls == 2 and not f.calls[2].down)
    assert(not f.controller.Get())
    f.controller.Cleanup()
end)
print("Completed " .. count .. " Auto Sprint tests")
