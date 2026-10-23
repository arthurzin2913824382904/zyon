-- Run with the official Luau CLI. These exercise real UI callbacks against a small Roblox mock.
local createUI = require("../src/ZyonUI")

local function signal()
    local listeners = {}
    local object = {}
    function object:Connect(fn)
        local connection = { Connected = true, fn = fn }
        function connection:Disconnect() self.Connected = false end
        listeners[#listeners + 1] = connection
        return connection
    end
    function object:Fire(...)
        for _, listener in ipairs(table.clone(listeners)) do
            if listener.Connected then listener.fn(...) end
        end
    end
    function object:Count()
        local count = 0
        for _, listener in ipairs(listeners) do if listener.Connected then count += 1 end end
        return count
    end
    return object
end
local function fixture(features, onClose, rangeCallback, extra)
    extra = extra or {}
    local screen = { X = 1280, Y = 720 }
    local enum = setmetatable({}, { __index = function(self, group)
        local items = setmetatable({}, { __index = function(list, key)
            local value = group .. "." .. key
            rawset(list, key, value)
            return value
        end })
        rawset(self, group, items)
        return items
    end })
    local function dim(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end
    local function dim2(sx, ox, sy, oy) return { X = dim(sx, ox), Y = dim(sy, oy) } end
    local function vector(x, y) return { X = x, Y = y } end
    local instances = {}
    local methods = {}
    local function totalScale(node)
        local factor = node.Parent and totalScale(node.Parent) or 1
        for _, child in ipairs(node._children) do
            if child.ClassName == "UIScale" then factor *= child.Scale end
        end
        return factor
    end
    local mt = {}
    function mt.__index(node, key)
        if methods[key] then return methods[key] end
        if key == "AbsoluteSize" then
            if node.ClassName == "PlayerGui" or node.ClassName == "ScreenGui" then return vector(screen.X, screen.Y) end
            local owner = node.Parent and node.Parent.AbsoluteSize or vector(0, 0)
            local factor = totalScale(node)
            return vector(owner.X * node.Size.X.Scale + node.Size.X.Offset * factor,
                owner.Y * node.Size.Y.Scale + node.Size.Y.Offset * factor)
        elseif key == "AbsolutePosition" then
            local origin = node.Parent and node.Parent.AbsolutePosition or vector(0, 0)
            local size = node.Parent and node.Parent.AbsoluteSize or vector(0, 0)
            local factor = node.Parent and totalScale(node.Parent) or 1
            local own = node.AbsoluteSize
            return vector(origin.X + size.X * node.Position.X.Scale + node.Position.X.Offset * factor - own.X * node.AnchorPoint.X,
                origin.Y + size.Y * node.Position.Y.Scale + node.Position.Y.Offset * factor - own.Y * node.AnchorPoint.Y)
        end
        return node._props[key]
    end
    function mt.__newindex(node, key, value)
        if key == "Parent" then
            local previous = node._props.Parent
            if previous then
                local index = table.find(previous._children, node)
                if index then table.remove(previous._children, index) end
            end
            if value then value._children[#value._children + 1] = node end
        end
        node._props[key] = value
    end
    function methods:GetChildren() return table.clone(self._children) end
    function methods:FindFirstChild(name, recursive)
        for _, child in ipairs(self._children) do
            if child.Name == name then return child end
            if recursive then
                local found = child:FindFirstChild(name, true)
                if found then return found end
            end
        end
        return nil
    end
    function methods:Destroy()
        if self._props.destroyed then return end
        self._props.destroyed = true
        self.Destroying:Fire()
        for _, child in ipairs(self:GetChildren()) do child:Destroy() end
        self.Parent = nil
    end
    local function new(class)
        local object = setmetatable({ _children = {}, _props = {
            ClassName = class, Name = class, Enabled = true, Visible = true, Active = true,
            Position = dim2(0, 0, 0, 0), Size = dim2(0, 0, 0, 0), AnchorPoint = vector(0, 0),
            Scale = 1, ScrollingEnabled = true,
        } }, mt)
        for _, event in ipairs({ "Activated", "MouseEnter", "MouseLeave", "InputBegan", "FocusLost", "Destroying" }) do
            object[event] = signal()
        end
        instances[#instances + 1] = object
        return object
    end
    local input = {
        InputBegan = signal(), InputChanged = signal(), InputEnded = signal(),
        WindowFocusReleased = signal(), focused = nil,
    }
    function input:GetFocusedTextBox() return self.focused end
    local services = { Input = input, Run = { Heartbeat = signal() }, Tween = {} }
    function services.Tween:Create(object, _, properties)
        return { Play = function() for key, value in pairs(properties) do object[key] = value end end,
            Cancel = function() end }
    end
    local busy = false
    local parent = new("PlayerGui")
    local ui = createUI({
        parent = parent, playerName = "Test Player", services = services, features = features,
        viewport = function() return vector(screen.X, screen.Y) end,
        onBusy = function(value) busy = value end,
        onClose = onClose, onRangeChanged = rangeCallback,
        choices = extra.choices, goalkeeperStatus = extra.goalkeeperStatus, onGKDebug = extra.onGKDebug,
        runtime = {
            Instance = { new = new }, Color3 = { fromRGB = function(r, g, b) return r .. ":" .. g .. ":" .. b end },
            UDim = { new = dim }, UDim2 = { new = dim2, fromOffset = function(x, y) return dim2(0, x, 0, y) end,
                fromScale = function(x, y) return dim2(x, 0, y, 0) end },
            Vector2 = { new = vector }, Enum = enum, TweenInfo = { new = function() return {} end },
        },
    })
    local function find(name) return assert(ui.Gui:FindFirstChild(name, true), "Missing UI object: " .. name) end
    local function pointer(kind, x, y)
        return { UserInputType = enum.UserInputType[kind], Position = vector(x or 0, y or 0), KeyCode = "None" }
    end
    return { ui = ui, input = input, services = services, find = find, enum = enum, screen = screen,
        pointer = pointer, parent = parent, busy = function() return busy end, instances = instances }
end
local count = 0
local function test(name, fn)
    fn()
    count += 1
    print("PASS " .. name)
end
local function eq(actual, expected)
    assert(actual == expected, "Expected " .. tostring(expected) .. ", received " .. tostring(actual))
end

test("branding, black sidebar and requested tabs", function()
    local f = fixture()
    eq(f.ui.Gui.Name, "ZyonHub")
    assert(f.find("Brand").Text:find("ZYON"))
    eq(f.find("Sidebar").BackgroundColor3, "8:8:10")
    eq(f.ui.GetState().tab, "offense")
    assert(f.find("Knife")); assert(f.find("Gear"))
    assert(f.find("Shield"))
    eq(f.find("PageTitle").Text, "Offense")
    f.find("Navigation"):FindFirstChild("misc").Activated:Fire()
    eq(f.ui.GetState().tab, "misc")
    eq(f.find("PageTitle").Text, "Misc")
    eq(f.ui.SelectTab("unknown"), false)
    f.ui.Destroy()
end)
test("Defense contains every original goalkeeper control", function()
    local f = fixture()
    f.find("Navigation"):FindFirstChild("defense").Activated:Fire()
    eq(f.ui.GetState().tab, "defense")
    eq(f.find("PageTitle").Text, "Defense")
    eq(f.find("Main"):FindFirstChild("defense").Visible, true)
    eq(f.find("Main"):FindFirstChild("offense").Visible, false)
    for _, key in ipairs({ "autoGK", "closeRangeRush", "highBallJumps", "jumpThenDive", "backwardRecovery",
        "positionAssist", "preShotCoverage", "respectManualMovement", "diveDirection", "positionMode", "GKStatus", "GKStats", "GKDebug" }) do
        assert(f.find(key))
    end
    f.ui.Destroy()
end)
test("all Defense toggles apply native state and switch independently", function()
    local features, native = {}, {}
    local keys = { "autoGK", "closeRangeRush", "highBallJumps", "jumpThenDive", "backwardRecovery",
        "positionAssist", "preShotCoverage", "respectManualMovement" }
    for _, key in ipairs(keys) do
        native[key] = false
        features[key] = { Get = function() return native[key] end,
            Set = function(value) native[key] = value; return true end }
    end
    local f = fixture(features)
    f.ui.SelectTab("defense")
    for _, key in ipairs(keys) do
        f.find(key):FindFirstChild("Switch").Activated:Fire()
        eq(native[key], true)
        eq(f.ui.GetState()[key], true)
    end
    f.find("autoGK"):FindFirstChild("Switch").Activated:Fire()
    eq(native.autoGK, false)
    eq(native.highBallJumps, true)
    f.ui.Destroy()
end)
test("goalkeeper direction and position selectors accept only real choices", function()
    local dive, position = "SMART", "THREATS"
    local f = fixture(nil, nil, nil, { choices = {
        diveDirection = { Get = function() return dive end, Set = function(value) dive = value; return true end },
        positionMode = { Get = function() return position end, Set = function(value) position = value; return true end },
    } })
    f.ui.SelectTab("defense")
    for _, direction in ipairs({ "FORWARD", "LEFT", "RIGHT", "SIDES", "SMART" }) do
        f.find("diveDirection"):FindFirstChild(direction).Activated:Fire()
        eq(dive, direction); eq(f.ui.GetState().diveDirection, direction)
    end
    f.find("positionMode"):FindFirstChild("HOME_AND_THREATS").Activated:Fire()
    eq(position, "HOME_AND_THREATS")
    eq(f.ui.SetChoice("diveDirection", "invalid"), false)
    eq(f.ui.GetState().diveDirection, "SMART")
    f.ui.Destroy()
end)
test("unavailable or rejected goalkeeper selectors preserve current selection", function()
    local f = fixture(nil, nil, nil, { choices = {
        diveDirection = { Get = function() return "SMART" end, Set = function() return false end },
    } })
    eq(f.ui.SetChoice("positionMode", "HOME_AND_THREATS"), false)
    eq(f.find("positionMode"):FindFirstChild("THREATS").Active, false)
    eq(f.ui.SetChoice("diveDirection", "LEFT"), false)
    eq(f.ui.GetState().diveDirection, "SMART")
    f.ui.Destroy()
end)
test("Defense status, action counters and diagnostics are live", function()
    local name, count = "OFF", 0
    local f = fixture(nil, nil, nil, {
        goalkeeperStatus = function() return { name = name, detail = "native status", requests = 3, jumps = 2, dives = 1, rushes = 0 } end,
        onGKDebug = function() count += 1; return true end,
    })
    f.ui.SelectTab("defense")
    eq(f.find("GKStatus").Text, "OFF")
    assert(f.find("GKStats").Text:find("Solicitações: 3"))
    name = "WAITING FOR GK"
    f.services.Run.Heartbeat:Fire(0.25)
    eq(f.find("GKStatus").Text, name)
    eq(f.find("GKDetail").Text, "native status")
    f.find("GKDebug").Activated:Fire()
    eq(count, 1)
    assert(f.find("Status").Text:find("console"))
    f.ui.Destroy()
end)
test("missing gameplay implementations never turn on", function()
    local f = fixture()
    for _, key in ipairs({ "autoShooting", "autoPassing", "infiniteStamina", "fullSpeedCharge", "ballMagnetic", "autoSprint" }) do
        local row = f.find(key)
        eq(row:FindFirstChild("Switch").Active, true)
        eq(row:FindFirstChild("State").Text, "Sem integração")
        row:FindFirstChild("HitTarget").Activated:Fire()
        assert(f.find("Status").Text:find("ainda não possui implementação"))
        eq(f.ui.SetFeature(key, true), false)
        eq(f.ui.GetState()[key], false)
    end
    f.ui.Destroy()
end)
test("Misc row targets and switches both accept input", function()
    local sprint = false
    local f = fixture({ autoSprint = { Get = function() return sprint end,
        Set = function(value) sprint = value; return true end } })
    f.ui.SelectTab("misc")
    f.find("autoSprint"):FindFirstChild("HitTarget").Activated:Fire()
    eq(sprint, true)
    f.find("autoSprint"):FindFirstChild("Switch").Activated:Fire()
    eq(sprint, false)
    f.find("ballMagnetic"):FindFirstChild("Switch").Activated:Fire()
    assert(f.find("Status").Text:find("Ball Magnetic"))
    eq(f.ui.GetState().ballMagnetic, false)
    f.ui.Destroy()
end)
test("all Misc rows fit inside the desktop scroll area", function()
    local f = fixture()
    f.ui.SelectTab("misc")
    local page = f.find("Main"):FindFirstChild("misc")
    local last = f.find("autoSprint")
    assert(last.AbsolutePosition.Y + last.AbsoluteSize.Y <= page.AbsolutePosition.Y + page.AbsoluteSize.Y)
    f.ui.Destroy()
end)
test("range accepts numeric entry and rejects invalid text", function()
    local f = fixture()
    local value = f.find("magneticRange"):FindFirstChild("Value")
    value.Text = "34"
    value.FocusLost:Fire()
    eq(f.ui.GetState().magneticRange, 34)
    value.Text = "bad input"
    value.FocusLost:Fire()
    eq(f.ui.GetState().magneticRange, 34)
    eq(value.Text, "34")
    value.Text = "100"
    value.FocusLost:Fire()
    eq(f.ui.GetState().magneticRange, 50)
    f.ui.Destroy()
end)
test("runtime feature errors appear inline without breaking refresh", function()
    local f = fixture({ autoSprint = { Get = function() return false end, Set = function() return false end,
        Error = function() return "Executor denied input" end } })
    f.services.Run.Heartbeat:Fire(0.25)
    eq(f.find("autoSprint"):FindFirstChild("Description").Text, "Executor denied input")
    f.ui.Destroy()
end)
test("toggle invokes gameplay callback and confirms state", function()
    local enabled, calls = false, 0
    local f = fixture({ autoShooting = { Get = function() return enabled end, Set = function(value)
        calls += 1; enabled = value; return true
    end } })
    local switch = f.find("autoShooting"):FindFirstChild("Switch")
    switch.Activated:Fire()
    eq(enabled, true); eq(calls, 1); eq(f.ui.GetState().autoShooting, true)
    eq(switch:FindFirstChild("Knob").Position.X.Offset, 23)
    switch.Activated:Fire()
    eq(enabled, false); eq(calls, 2); eq(f.busy(), false)
    f.ui.Destroy()
end)
test("setter-only adapters can turn a feature off again", function()
    local enabled = false
    local f = fixture({ autoPassing = { Set = function(value) enabled = value; return true end } })
    eq(f.ui.SetFeature("autoPassing", true), true)
    eq(enabled, true); eq(f.ui.GetState().autoPassing, true)
    eq(f.ui.SetFeature("autoPassing", false), true)
    eq(enabled, false); eq(f.ui.GetState().autoPassing, false)
    f.ui.Destroy()
end)
test("failed or unconfirmed setters stay off and report errors", function()
    local f = fixture({ autoPassing = { Set = function() return false, "not ready" end } })
    eq(f.ui.SetFeature("autoPassing", true), false)
    eq(f.ui.GetState().autoPassing, false)
    assert(f.find("Status").Text:find("not ready"))
    f.ui.BindFeature("autoPassing", { Set = function() error("native failure") end })
    eq(f.ui.SetFeature("autoPassing", true), false)
    eq(f.busy(), false)
    f.ui.BindFeature("autoPassing", { Set = function() return true end, Get = function() return false end })
    eq(f.ui.SetFeature("autoPassing", true), false)
    eq(f.ui.GetState().autoPassing, false)
    f.ui.Destroy()
end)
test("heartbeat reflects native changes without reapplying setters", function()
    local enabled = false
    local f = fixture({ autoSprint = { Get = function() return enabled end, Set = function() error("must not be called") end } })
    enabled = true
    f.services.Run.Heartbeat:Fire(0.25)
    eq(f.ui.GetState().autoSprint, true)
    f.ui.Destroy()
end)
test("slider clamps, rounds and rejects invalid values", function()
    local f = fixture()
    eq(f.ui.GetState().magneticRange, 12)
    eq(f.ui.SetRange(19.6), true); eq(f.ui.GetState().magneticRange, 20)
    f.ui.SetRange(-100); eq(f.ui.GetState().magneticRange, 1)
    f.ui.SetRange(100); eq(f.ui.GetState().magneticRange, 50)
    eq(f.ui.SetRange(0 / 0), false); eq(f.ui.SetRange(math.huge), false)
    eq(f.ui.SetRange("bad"), false)
    f.ui.Destroy()
end)
test("slider keeps previous value when game callback rejects update", function()
    local f = fixture(nil, nil, function() return false end)
    eq(f.ui.SetRange(25), false)
    eq(f.ui.GetState().magneticRange, 12)
    f.ui.Destroy()
end)
test("mouse slider drag reaches both ends and releases scrolling", function()
    local f = fixture()
    f.ui.SelectTab("misc")
    local slider = f.find("Slider")
    local track = slider:FindFirstChild("Track")
    local left = track.AbsolutePosition.X
    local down = f.pointer("MouseButton1", left, 400)
    slider.InputBegan:Fire(down)
    eq(f.ui.GetState().magneticRange, 1); eq(f.busy(), true)
    f.input.InputChanged:Fire(f.pointer("MouseMovement", left + track.AbsoluteSize.X, 400))
    eq(f.ui.GetState().magneticRange, 50)
    f.input.InputEnded:Fire(f.pointer("MouseButton1"))
    eq(f.busy(), false)
    eq(f.find("Main"):FindFirstChild("misc").ScrollingEnabled, true)
    f.ui.Destroy()
end)
test("touch slider ignores other fingers and clears on tab switch", function()
    local f = fixture()
    f.ui.SelectTab("misc")
    local slider = f.find("Slider")
    local down = f.pointer("Touch", 0, 400)
    slider.InputBegan:Fire(down)
    eq(f.busy(), true)
    f.input.InputChanged:Fire(f.pointer("Touch", 10000, 400))
    eq(f.ui.GetState().magneticRange, 1)
    down.Position.X = 10000
    f.input.InputChanged:Fire(down)
    eq(f.ui.GetState().magneticRange, 50)
    f.ui.SelectTab("offense")
    eq(f.busy(), false)
    eq(f.find("Main"):FindFirstChild("misc").ScrollingEnabled, true)
    f.ui.Destroy()
end)
test("RightShift, chat focus and minimizing preserve option state", function()
    local f = fixture()
    local key = { KeyCode = f.enum.KeyCode.RightShift }
    f.ui.SetRange(28)
    f.input.InputBegan:Fire(key, false)
    eq(f.ui.GetState().visible, false)
    f.input.focused = {}
    f.input.InputBegan:Fire(key, false)
    eq(f.ui.GetState().visible, false)
    f.input.focused = nil
    f.input.InputBegan:Fire(key, false)
    eq(f.ui.GetState().visible, true)
    f.find("Minimize").Activated:Fire()
    eq(f.ui.GetState().minimized, true); eq(f.find("Body").Visible, false)
    eq(f.find("Window").Size.Y.Offset, 54)
    f.find("Minimize").Activated:Fire()
    eq(f.ui.GetState().minimized, false); eq(f.find("Body").Visible, true)
    eq(f.ui.GetState().magneticRange, 28)
    f.ui.Destroy()
end)
test("window dragging stays in viewport and resize fits small screens", function()
    local f = fixture()
    f.find("DragHandle").InputBegan:Fire(f.pointer("MouseButton1", 100, 100))
    f.input.InputChanged:Fire(f.pointer("MouseMovement", -1000, -1000))
    eq(f.find("WindowHost").Position.X.Offset, 12)
    eq(f.find("WindowHost").Position.Y.Offset, 24)
    f.input.WindowFocusReleased:Fire()
    eq(f.busy(), false)
    f.screen.X, f.screen.Y = 390, 500
    f.services.Run.Heartbeat:Fire(0.25)
    local window = f.find("Window")
    assert(window.AbsolutePosition.X + window.AbsoluteSize.X <= f.screen.X)
    assert(window.AbsolutePosition.Y + window.AbsoluteSize.Y <= f.screen.Y)
    f.ui.Destroy()
end)
test("close respects cleanup failure, then disconnects listeners on success", function()
    local accepted, calls = false, 0
    local f = fixture(nil, function() calls += 1; return accepted end)
    local close = f.find("Close")
    close.Activated:Fire()
    eq(calls, 1); eq(f.ui.GetState().visible, true)
    accepted = true
    close.Activated:Fire()
    eq(calls, 2); eq(f.ui.GetState().visible, false)
    eq(f.input.InputChanged:Count(), 0)
    eq(f.services.Run.Heartbeat:Count(), 0)
    eq(f.ui.Destroy(), true)
    eq(f.ui.SetRange(20), false)
end)
test("external GUI removal cleans up all input handlers", function()
    local f = fixture()
    f.ui.Gui:Destroy()
    eq(f.input.InputBegan:Count(), 0)
    eq(f.input.InputEnded:Count(), 0)
    eq(f.ui.GetState().visible, false)
end)
print("Completed " .. count .. " UI tests")
