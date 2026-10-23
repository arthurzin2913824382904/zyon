-- Zyon Hub UI preview: run as a LocalScript in StarterPlayerScripts.
-- No Illegal Soccer modules or gameplay automation are loaded by this preview.
local createZyonUI = (function()
-- Matte client UI. Every row responds to input; missing gameplay callbacks explain why they cannot run.
local function createZyonUI(options)
    options = options or {}
    local rt = options.runtime or {}
    local Instance = rt.Instance or Instance
    local Color3 = rt.Color3 or Color3
    local UDim2 = rt.UDim2 or UDim2
    local UDim = rt.UDim or UDim
    local Vector2 = rt.Vector2 or Vector2
    local Enum = rt.Enum or Enum
    local TweenInfo = rt.TweenInfo or TweenInfo
    local services = options.services or {
        Input = game:GetService("UserInputService"),
        Run = game:GetService("RunService"),
        Tween = game:GetService("TweenService"),
    }
    local parent = assert(options.parent, "Zyon Hub requires a PlayerGui parent")
    local palette = {
        black = Color3.fromRGB(12, 12, 15),
        sidebar = Color3.fromRGB(8, 8, 10),
        surface = Color3.fromRGB(18, 18, 22),
        hover = Color3.fromRGB(25, 24, 30),
        line = Color3.fromRGB(37, 36, 43),
        purple = Color3.fromRGB(166, 128, 255),
        purpleDark = Color3.fromRGB(39, 30, 57),
        white = Color3.fromRGB(246, 245, 249),
        secondary = Color3.fromRGB(146, 143, 157),
        off = Color3.fromRGB(49, 48, 57),
    }
    local state = {
        autoShooting = false, autoPassing = false, infiniteStamina = false,
        fullSpeedCharge = false, ballMagnetic = false, autoSprint = false,
        magneticRange = 12,
        autoGK = false, closeRangeRush = false, highBallJumps = false,
        jumpThenDive = false, backwardRecovery = false, positionAssist = false,
        preShotCoverage = false, respectManualMovement = false,
        diveDirection = "SMART", positionMode = "THREATS",
    }
    local adapters = options.features or {}
    local choiceAdapters = options.choices or {}
    local connections, tweens, controls, pages, tabs = {}, {}, {}, {}, {}
    local choices = {}
    local api = {}
    local destroyed, minimized, hidden = false, false, false
    local activeTab, busyCount = "offense", 0
    local dragInput, dragStart, dragOrigin, rangeInput
    local width, height, headerHeight = 800, 590, 54
    local lastViewport, lastBusy

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        connections[#connections + 1] = connection
        return connection
    end
    local function create(class, props, owner)
        local object = Instance.new(class)
        for key, value in pairs(props) do object[key] = value end
        object.Parent = owner
        return object
    end
    local function frame(owner, name, position, size, color)
        return create("Frame", {
            Name = name, Position = position, Size = size,
            BackgroundColor3 = color or palette.surface, BorderSizePixel = 0,
        }, owner)
    end
    local function round(object, radius)
        create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
        return object
    end
    local function outline(object, color)
        return create("UIStroke", {
            Color = color or palette.line, Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, object)
    end
    local function text(owner, name, value, position, size, fontSize, color)
        return create("TextLabel", {
            Name = name, Text = value, Position = position, Size = size,
            Font = Enum.Font.Gotham, TextSize = fontSize or 14,
            TextColor3 = color or palette.white, BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0,
        }, owner)
    end
    local function button(owner, name, position, size)
        return create("TextButton", {
            Name = name, Text = "", Position = position, Size = size,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutoButtonColor = false, Selectable = true,
        }, owner)
    end
    local function animate(object, props)
        if tweens[object] then tweens[object]:Cancel() end
        local tween = services.Tween:Create(object,
            TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
        tweens[object] = tween
        tween:Play()
    end
    local gui = create("ScreenGui", {
        Name = options.guiName or "ZyonHub", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)
    local host = frame(gui, "WindowHost", UDim2.fromOffset(24, 60), UDim2.fromOffset(0, 0))
    host.BackgroundTransparency = 1
    -- Flat, neutral surfaces with a soft silhouette; no image textures or asset downloads.
    local window = round(frame(host, "Window", UDim2.fromOffset(0, 0),
        UDim2.fromOffset(width, height), palette.black), 9)
    window.Active, window.ClipsDescendants = true, true
    outline(window, palette.line)
    local scale = create("UIScale", { Scale = 1 }, window)

    local header = button(window, "DragHandle", UDim2.fromOffset(0, 0), UDim2.new(1, -98, 0, headerHeight))
    header.Selectable, header.Active = false, true
    local logo = frame(header, "Logo", UDim2.fromOffset(20, 17), UDim2.fromOffset(22, 20))
    logo.BackgroundTransparency = 1
    round(frame(logo, "Top", UDim2.fromOffset(2, 1), UDim2.fromOffset(18, 3), palette.white), 1)
    local slash = round(frame(logo, "Slash", UDim2.fromOffset(1, 9), UDim2.fromOffset(20, 3), palette.purple), 1)
    slash.Rotation = -44
    round(frame(logo, "Bottom", UDim2.fromOffset(2, 17), UDim2.fromOffset(18, 3), palette.white), 1)
    local brand = text(header, "Brand", "ZYON <font color=\"#A680FF\">HUB</font>",
        UDim2.fromOffset(53, 15), UDim2.fromOffset(165, 24), 16)
    brand.RichText, brand.Font = true, Enum.Font.GothamBold
    text(header, "GameName", "Illegal Soccer", UDim2.fromOffset(210, 17),
        UDim2.fromOffset(180, 20), 11, palette.secondary)
    frame(window, "HeaderLine", UDim2.fromOffset(0, headerHeight - 1), UDim2.new(1, 0, 0, 1), palette.line)
    local minimize = round(button(window, "Minimize", UDim2.new(1, -84, 0, 13), UDim2.fromOffset(28, 28)), 5)
    local close = round(button(window, "Close", UDim2.new(1, -46, 0, 13), UDim2.fromOffset(28, 28)), 5)
    for _, control in ipairs({ minimize, close }) do
        control.BackgroundColor3 = palette.hover
        connect(control.MouseEnter, function() animate(control, { BackgroundTransparency = 0 }) end)
        connect(control.MouseLeave, function() animate(control, { BackgroundTransparency = 1 }) end)
    end
    local minimizeLabel = text(minimize, "Glyph", "−", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 22)
    minimizeLabel.TextXAlignment = Enum.TextXAlignment.Center
    local closeLabel = text(close, "Glyph", "×", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 22)
    closeLabel.TextXAlignment = Enum.TextXAlignment.Center

    local body = frame(window, "Body", UDim2.fromOffset(0, headerHeight), UDim2.new(1, 0, 1, -headerHeight), palette.black)
    local sidebar = frame(body, "Sidebar", UDim2.fromOffset(0, 0), UDim2.new(0, 184, 1, 0), palette.sidebar)
    frame(sidebar, "Divider", UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), palette.line)
    text(sidebar, "MenuHeading", "WORKSPACE", UDim2.fromOffset(22, 23), UDim2.fromOffset(140, 16), 9, palette.secondary)
    local nav = frame(sidebar, "Navigation", UDim2.fromOffset(10, 53), UDim2.new(1, -20, 0, 156), palette.sidebar)
    create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
    text(sidebar, "Shortcut", "RSHIFT  /  mostrar ou ocultar", UDim2.new(0, 22, 1, -96), UDim2.new(1, -36, 0, 18), 9, palette.secondary)
    frame(sidebar, "UserDivider", UDim2.new(0, 16, 1, -72), UDim2.new(1, -32, 0, 1), palette.line)
    local userCard = frame(sidebar, "User", UDim2.new(0, 12, 1, -65), UDim2.new(1, -24, 0, 52), palette.sidebar)
    local userMark = round(frame(userCard, "Avatar", UDim2.fromOffset(10, 11), UDim2.fromOffset(30, 30), palette.purpleDark), 8)
    local userInitial = text(userMark, "Initial", string.upper(string.sub(options.playerName or "P", 1, 1)), UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 14)
    userInitial.TextXAlignment = Enum.TextXAlignment.Center
    text(userCard, "Player", options.playerName or "Player", UDim2.fromOffset(50, 8), UDim2.new(1, -57, 0, 20), 12)
    text(userCard, "Edition", "Sessão local", UDim2.fromOffset(50, 29), UDim2.new(1, -57, 0, 15), 10, palette.secondary)

    local main = frame(body, "Main", UDim2.fromOffset(184, 0), UDim2.new(1, -184, 1, 0), palette.black)
    local pageTitle = text(main, "PageTitle", "Offense", UDim2.fromOffset(26, 20), UDim2.new(1, -52, 0, 29), 22)
    pageTitle.Font = Enum.Font.GothamMedium
    local pageSubtitle = text(main, "PageSubtitle", "Controle as opções de ataque.",
        UDim2.fromOffset(26, 52), UDim2.new(1, -52, 0, 18), 11, palette.secondary)
    local noticeBar = frame(main, "NoticeBar", UDim2.new(0, 20, 1, -37), UDim2.new(1, -40, 0, 28), palette.black)
    round(noticeBar, 5)
    local message = text(noticeBar, "Status", "Selecione uma opção para configurar.",
        UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), 10, palette.secondary)
    local function notice(value, isError)
        if destroyed then return end
        message.Text, message.TextColor3 = value, isError and palette.purple or palette.secondary
        noticeBar.BackgroundColor3 = isError and palette.purpleDark or palette.black
        if options.onNotice then options.onNotice(value, isError == true) end
    end
    local function busy()
        local value = dragInput ~= nil or rangeInput ~= nil or busyCount > 0
        if lastBusy ~= value then
            lastBusy = value
            if options.onBusy then options.onBusy(value) end
        end
    end
    local function clearGestures()
        dragInput, rangeInput = nil, nil
        for _, page in pairs(pages) do page.ScrollingEnabled = true end
        busy()
    end
    local function viewport()
        return options.viewport and options.viewport() or Vector2.new(1280, 720)
    end
    local function fit(x, y)
        local view = viewport()
        local actualHeight = minimized and headerHeight or height
        local factor = math.max(0.05, math.min(1, (view.X - 24) / width, (view.Y - 48) / actualHeight))
        scale.Scale, lastViewport = factor, view
        window.Size = UDim2.fromOffset(width, actualHeight)
        host.Position = UDim2.fromOffset(
            math.clamp(x or host.Position.X.Offset, 12, math.max(12, view.X - width * factor - 12)),
            math.clamp(y or host.Position.Y.Offset, 24, math.max(24, view.Y - actualHeight * factor - 12)))
    end

    -- Small vector icons work in executors without an HTTP image dependency.
    local function knife(owner)
        local shape = frame(owner, "Knife", UDim2.fromOffset(15, 12), UDim2.fromOffset(20, 24))
        shape.BackgroundTransparency, shape.Rotation = 1, -42
        round(frame(shape, "Blade", UDim2.fromOffset(8, 0), UDim2.fromOffset(7, 14), palette.white), 2)
        frame(shape, "Edge", UDim2.fromOffset(8, 0), UDim2.fromOffset(2, 12), palette.purple)
        round(frame(shape, "Guard", UDim2.fromOffset(4, 13), UDim2.fromOffset(14, 3), palette.white), 1)
        round(frame(shape, "Grip", UDim2.fromOffset(9, 16), UDim2.fromOffset(5, 9), palette.white), 2)
    end
    local function gear(owner)
        local shape = frame(owner, "Gear", UDim2.fromOffset(15, 13), UDim2.fromOffset(24, 24))
        shape.BackgroundTransparency = 1
        for index = 0, 7 do
            local angle = math.rad(index * 45)
            local tooth = frame(shape, "Tooth" .. index,
                UDim2.fromOffset(12 + math.sin(angle) * 9, 12 - math.cos(angle) * 9),
                UDim2.fromOffset(5, 7), palette.white)
            tooth.AnchorPoint, tooth.Rotation = Vector2.new(0.5, 0.5), index * 45
        end
        local ring = round(frame(shape, "Ring", UDim2.fromOffset(4, 4), UDim2.fromOffset(16, 16), palette.white), 8)
        round(frame(ring, "Hole", UDim2.fromOffset(5, 5), UDim2.fromOffset(6, 6), palette.sidebar), 3)
    end
    local function shield(owner)
        local shape = frame(owner, "Shield", UDim2.fromOffset(16, 12), UDim2.fromOffset(22, 25))
        shape.BackgroundTransparency = 1
        local top = round(frame(shape, "Top", UDim2.fromOffset(1, 0), UDim2.fromOffset(20, 16), palette.white), 3)
        local point = frame(shape, "Point", UDim2.fromOffset(4, 9), UDim2.fromOffset(14, 14), palette.white)
        point.Rotation = 45
        top.ZIndex = 2
        local inset = round(frame(top, "Inset", UDim2.fromOffset(3, 3), UDim2.fromOffset(14, 12), palette.sidebar), 2)
        inset.ZIndex = 3
        local mark = frame(inset, "Mark", UDim2.fromOffset(6, 2), UDim2.fromOffset(2, 9), palette.purple)
        mark.ZIndex = 4
    end
    local function addTab(id, title, subtitle, drawIcon, order)
        local control = round(button(nav, id, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 44)), 6)
        control.LayoutOrder, control.BackgroundColor3, control.BackgroundTransparency = order, palette.sidebar, 0
        local tint = round(frame(control, "SelectedTint", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), palette.purpleDark), 6)
        tint.BackgroundTransparency = 0.6
        local marker = round(frame(control, "ActiveMarker", UDim2.fromOffset(0, 12), UDim2.fromOffset(2, 20), palette.purple), 1)
        drawIcon(control)
        local label = text(control, "Label", title, UDim2.fromOffset(50, 0), UDim2.new(1, -58, 1, 0), 13)
        label.Font = Enum.Font.GothamMedium
        local page = create("ScrollingFrame", {
            Name = id, Position = UDim2.fromOffset(26, 88), Size = UDim2.new(1, -52, 1, -133),
            CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
            ScrollBarImageColor3 = palette.purple, BorderSizePixel = 0,
            BackgroundTransparency = 1, Visible = false, ClipsDescendants = true,
        }, main)
        create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, page)
        create("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6) }, page)
        pages[id], tabs[id] = page, { button = control, marker = marker, tint = tint, title = title, subtitle = subtitle }
        connect(control.Activated, function() api.SelectTab(id) end)
        connect(control.MouseEnter, function()
            if not destroyed then animate(control, { BackgroundColor3 = palette.hover }) end
        end)
        connect(control.MouseLeave, function()
            if not destroyed then animate(control, { BackgroundColor3 = palette.sidebar }) end
        end)
        return page
    end
    local offense = addTab("offense", "Offense", "Controle as opções de ataque.", knife, 1)
    local defense = addTab("defense", "Defense", "Auto GK • defesas, saltos e posicionamento.", shield, 2)
    local misc = addTab("misc", "Misc", "Ajustes de movimento e controle da bola.", gear, 3)
    function api.SelectTab(id)
        if destroyed or not pages[id] then return false end
        clearGestures()
        activeTab = id
        for name, page in pairs(pages) do
            page.Visible, tabs[name].marker.Visible = name == id, name == id
            tabs[name].tint.Visible = name == id
        end
        pageTitle.Text, pageSubtitle.Text = tabs[id].title, tabs[id].subtitle
        return true
    end
    local function card(page, name, heading, order, cardHeight)
        local panel = round(frame(page, name, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, cardHeight)), 7)
        panel.LayoutOrder = order
        outline(panel)
        text(panel, "Heading", heading, UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 16), 10, palette.secondary)
        return panel
    end
    local function available(key)
        return adapters[key] ~= nil and type(adapters[key].Set) == "function"
    end
    local function renderToggle(key)
        if destroyed then return end
        local item, adapter = controls[key], adapters[key]
        local ready, readError = available(key), false
        if ready and adapter.Get then
            local ok, value = pcall(adapter.Get)
            if ok and type(value) == "boolean" then state[key] = value else readError = true end
        end
        local on = ready and not readError and state[key]
        local failure
        if ready and type(adapter.Error) == "function" then
            local ok, reason = pcall(adapter.Error)
            if ok and type(reason) == "string" then failure = reason end
        end
        item.description.Text = failure or (ready and adapter.Description) or item.defaultDescription
        item.status.Text = readError and "Erro" or (item.busy and "Aplicando…" or (ready and "" or "Sem integração"))
        item.status.TextColor3 = on and palette.purple or palette.secondary
        -- Unimplemented actions still accept clicks and explain the missing integration.
        item.switch.Active, item.switch.Selectable = not item.busy, true
        item.hit.Active, item.hit.Selectable = not item.busy, true
        local position = UDim2.fromOffset(on and 23 or 3, 3)
        local color = on and palette.purple or palette.off
        if item.lastOn ~= on then
            animate(item.switch, { BackgroundColor3 = color })
            animate(item.knob, { Position = position })
            item.lastOn = on
        end
    end
    function api.SetFeature(key, value)
        local item = controls[key]
        if destroyed or not item or item.busy or type(value) ~= "boolean" then return false end
        if not available(key) then
            notice(item.title .. " ainda não possui implementação nesta source.", true)
            return false
        end
        local adapter = adapters[key]
        local previous = state[key]
        item.busy, busyCount = true, busyCount + 1
        busy()
        renderToggle(key)
        local ok, accepted, detail = pcall(adapter.Set, value)
        local success = ok and accepted ~= false
        if success and adapter.Get then
            local readOK, actual = pcall(adapter.Get)
            success = readOK and actual == value
            if not success then detail = "O jogo não confirmou a alteração." end
        end
        if destroyed then
            if success and value then pcall(adapter.Set, false) end
            return false
        end
        if success then state[key] = value else state[key] = previous end
        item.busy, busyCount = false, busyCount - 1
        busy()
        renderToggle(key)
        notice(success and (item.title .. (value and " ativado" or " desativado"))
            or (item.title .. ": " .. tostring(ok and (detail or "alteração recusada") or accepted)), not success)
        return success
    end
    local function toggle(panel, key, title, description, y, withDivider)
        local row = frame(panel, key, UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 56))
        row.BackgroundTransparency = 1
        text(row, "Title", title, UDim2.fromOffset(0, 5), UDim2.new(1, -78, 0, 21), 13)
        local detail = text(row, "Description", description, UDim2.fromOffset(0, 29), UDim2.new(1, -132, 0, 17), 10, palette.secondary)
        local status = text(row, "State", "", UDim2.new(1, -126, 0, 29), UDim2.fromOffset(126, 17), 9, palette.secondary)
        status.TextXAlignment = Enum.TextXAlignment.Right
        local hit = button(row, "HitTarget", UDim2.fromOffset(-6, 0), UDim2.new(1, -54, 1, 0))
        local switch = round(button(row, "Switch", UDim2.new(1, -44, 0, 7), UDim2.fromOffset(44, 24)), 12)
        switch.BackgroundTransparency, switch.BackgroundColor3 = 0, palette.off
        local knob = round(frame(switch, "Knob", UDim2.fromOffset(3, 3), UDim2.fromOffset(18, 18), palette.white), 9)
        controls[key] = { switch = switch, hit = hit, knob = knob, description = detail, status = status,
            title = title, defaultDescription = description, busy = false }
        if withDivider then frame(row, "Divider", UDim2.fromOffset(0, 55), UDim2.new(1, 0, 0, 1), palette.line) end
        local function activate()
            if destroyed or hidden or minimized or not switch.Active then return end
            api.SetFeature(key, not state[key])
        end
        connect(switch.Activated, activate)
        connect(hit.Activated, activate)
        connect(hit.MouseEnter, function()
            if not destroyed then animate(row, { BackgroundColor3 = palette.hover, BackgroundTransparency = 0 }) end
        end)
        connect(hit.MouseLeave, function()
            if not destroyed then animate(row, { BackgroundTransparency = 1 }) end
        end)
        renderToggle(key)
    end
    local offenseCard = card(offense, "Automation", "Shooting & passing", 1, 160)
    toggle(offenseCard, "autoShooting", "Auto Shooting", "Assistência e liberação de chute.", 38, true)
    toggle(offenseCard, "autoPassing", "Auto Passing", "Passe automático.", 96, false)

    local function renderChoice(key)
        if destroyed then return end
        local entry, adapter = choices[key], choiceAdapters[key]
        local ready = adapter ~= nil and type(adapter.Set) == "function"
        if ready and adapter.Get then
            local ok, value = pcall(adapter.Get)
            if ok and entry.values[value] then state[key] = value else ready = false end
        end
        entry.status.Text = ready and "" or "PENDENTE"
        for value, item in pairs(entry.buttons) do
            item.button.Active, item.button.Selectable = ready and not entry.busy, ready
            item.outline.Color = ready and state[key] == value and palette.purple or palette.line
            item.button.BackgroundColor3 = ready and state[key] == value and palette.purpleDark or palette.black
        end
    end
    function api.SetChoice(key, value)
        local entry, adapter = choices[key], choiceAdapters[key]
        if destroyed or not entry or entry.busy or not entry.values[value]
            or not adapter or type(adapter.Set) ~= "function" then return false end
        local previous = state[key]
        entry.busy, busyCount = true, busyCount + 1
        busy()
        renderChoice(key)
        local ok, accepted, detail = pcall(adapter.Set, value)
        local success = ok and accepted ~= false
        if success and adapter.Get then
            local readOK, actual = pcall(adapter.Get)
            success = readOK and actual == value
        end
        if destroyed then return false end
        state[key] = success and value or previous
        entry.busy, busyCount = false, busyCount - 1
        busy()
        renderChoice(key)
        notice(success and (entry.title .. " atualizado") or (entry.title .. ": " .. tostring(ok and (detail or "alteração recusada") or accepted)), not success)
        return success
    end
    local function choice(panel, key, title, items, y)
        local row = frame(panel, key, UDim2.fromOffset(18, y), UDim2.new(1, -36, 0, 72))
        row.BackgroundTransparency = 1
        text(row, "Title", title, UDim2.fromOffset(0, 0), UDim2.new(1, -100, 0, 22), 14)
        local status = text(row, "Availability", "", UDim2.new(1, -90, 0, 0), UDim2.fromOffset(90, 22), 9, palette.secondary)
        status.TextXAlignment = Enum.TextXAlignment.Right
        choices[key] = { title = title, values = {}, buttons = {}, status = status, busy = false }
        local total = #items
        for index, item in ipairs(items) do
            local control = round(button(row, item.value,
                UDim2.new((index - 1) / total, 0, 0, 30), UDim2.new(1 / total, -6, 0, 32)), 6)
            control.BackgroundTransparency, control.BackgroundColor3 = 0, palette.black
            local border = outline(control)
            local label = text(control, "Label", item.label, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 11)
            label.TextXAlignment = Enum.TextXAlignment.Center
            choices[key].values[item.value] = true
            choices[key].buttons[item.value] = { button = control, outline = border }
            connect(control.Activated, function()
                if not destroyed and not hidden and not minimized and control.Active then api.SetChoice(key, item.value) end
            end)
        end
        renderChoice(key)
    end
    local gkLive = card(defense, "GoalkeeperLive", "Live status", 1, 124)
    local gkStatus = text(gkLive, "GKStatus", "Aguardando integração", UDim2.fromOffset(16, 33), UDim2.new(1, -32, 0, 23), 14)
    gkStatus.Font = Enum.Font.GothamMedium
    local gkDetail = text(gkLive, "GKDetail", "", UDim2.fromOffset(16, 59), UDim2.new(1, -32, 0, 28), 10, palette.secondary)
    gkDetail.TextWrapped, gkDetail.TextTruncate = true, Enum.TextTruncate.None
    local gkStats = text(gkLive, "GKStats", "", UDim2.fromOffset(16, 96), UDim2.new(1, -32, 0, 16), 10, palette.purple)
    local gkAutomation = card(defense, "GoalkeeperAutomation", "Auto GK", 2, 410)
    toggle(gkAutomation, "autoGK", "Auto GK", "Ativa as defesas automáticas do goleiro.", 38, true)
    toggle(gkAutomation, "closeRangeRush", "Close-range Rush", "Avançar para defender em curta distância.", 96, true)
    toggle(gkAutomation, "highBallJumps", "High-ball Jumps", "Saltar para alcançar bolas altas.", 154, true)
    toggle(gkAutomation, "jumpThenDive", "Jump Then Dive", "Combinar salto e mergulho nas defesas.", 212, true)
    choice(gkAutomation, "diveDirection", "Dive Direction", {
        { value = "SMART", label = "Smart" }, { value = "FORWARD", label = "Forward" },
        { value = "LEFT", label = "Left" }, { value = "RIGHT", label = "Right" },
        { value = "SIDES", label = "Sides" },
    }, 276)
    toggle(gkAutomation, "backwardRecovery", "Lob / Back Recovery", "Recuperação para bolas por cobertura.", 348, false)
    local positioning = card(defense, "GoalkeeperPositioning", "Positioning", 3, 292)
    toggle(positioning, "positionAssist", "Position Assist", "Ajustar o posicionamento do goleiro.", 38, true)
    toggle(positioning, "preShotCoverage", "Pre-shot Coverage", "Cobrir o ângulo antes do chute adversário.", 96, true)
    choice(positioning, "positionMode", "Position Mode", {
        { value = "THREATS", label = "Threats only" },
        { value = "HOME_AND_THREATS", label = "Home + threats" },
    }, 158)
    toggle(positioning, "respectManualMovement", "Manual Movement First", "Dar prioridade aos seus movimentos manuais.", 230, false)
    local diagnostics = card(defense, "GoalkeeperDiagnostics", "Diagnostics", 4, 96)
    local debugButton = round(button(diagnostics, "GKDebug", UDim2.fromOffset(18, 42), UDim2.new(1, -36, 0, 34)), 6)
    debugButton.BackgroundTransparency, debugButton.BackgroundColor3 = 0, palette.black
    outline(debugButton)
    local debugLabel = text(debugButton, "Label", "Imprimir diagnóstico do Auto GK", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12)
    debugLabel.TextXAlignment = Enum.TextXAlignment.Center
    debugButton.Active, debugButton.Selectable = type(options.onGKDebug) == "function", type(options.onGKDebug) == "function"
    connect(debugButton.Activated, function()
        if destroyed or hidden or minimized or not debugButton.Active then return end
        local ok, result = pcall(options.onGKDebug)
        notice(ok and result ~= false and "Diagnóstico enviado ao console." or "Não foi possível gerar o diagnóstico.", not ok or result == false)
    end)
    local function refreshGK()
        if not options.goalkeeperStatus then return end
        local ok, result = pcall(options.goalkeeperStatus)
        if not ok or type(result) ~= "table" then
            gkStatus.Text, gkDetail.Text = "Erro de status", "Não foi possível consultar o Auto GK."
            return
        end
        gkStatus.Text = tostring(result.name or "OFF")
        gkDetail.Text = tostring(result.detail or "")
        gkStats.Text = string.format("Solicitações: %d   •   Saltos: %d   •   Mergulhos: %d   •   Rush: %d",
            result.requests or 0, result.jumps or 0, result.dives or 0, result.rushes or 0)
    end
    refreshGK()

    local miscCard = card(misc, "Movement", "Movement & ball", 1, 376)
    toggle(miscCard, "infiniteStamina", "Infinite Stamina", "Controle de stamina.", 38, true)
    toggle(miscCard, "fullSpeedCharge", "Full Speed Charge", "Movimento durante o carregamento.", 96, true)
    toggle(miscCard, "ballMagnetic", "Ball Magnetic", "Controle de alcance da bola.", 154, true)

    local range = frame(miscCard, "magneticRange", UDim2.fromOffset(16, 220), UDim2.new(1, -32, 0, 72))
    range.BackgroundTransparency = 1
    text(range, "Title", "Ball Magnetic Range", UDim2.fromOffset(0, 0), UDim2.new(1, -100, 0, 24), 13)
    local rangeValue = round(create("TextBox", {
        Name = "Value", Text = "12", Position = UDim2.new(1, -58, 0, 0), Size = UDim2.fromOffset(58, 25),
        Font = Enum.Font.Code, TextSize = 12, TextColor3 = palette.white, BackgroundColor3 = palette.black,
        BorderSizePixel = 0, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Center,
    }, range), 4)
    outline(rangeValue)
    local rangeHit = button(range, "Slider", UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 30))
    local track = round(frame(rangeHit, "Track", UDim2.fromOffset(8, 13), UDim2.new(1, -16, 0, 4), palette.off), 2)
    local fill = round(frame(track, "Fill", UDim2.fromOffset(0, 0), UDim2.new(11 / 49, 0, 1, 0), palette.purple), 2)
    local thumb = round(frame(track, "Thumb", UDim2.new(11 / 49, 0, 0.5, 0), UDim2.fromOffset(14, 14), palette.white), 7)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    text(range, "Minimum", "1 stud", UDim2.fromOffset(0, 56), UDim2.fromOffset(80, 14), 9, palette.secondary)
    local maximum = text(range, "Maximum", "50 studs", UDim2.new(1, -80, 0, 56), UDim2.fromOffset(80, 14), 9, palette.secondary)
    maximum.TextXAlignment = Enum.TextXAlignment.Right
    frame(miscCard, "RangeDivider", UDim2.fromOffset(16, 304), UDim2.new(1, -32, 0, 1), palette.line)
    toggle(miscCard, "autoSprint", "Auto Sprint", "Correr sem manter uma tecla pressionada.", 312, false)

    function api.SetRange(value)
        if destroyed or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
        local rounded = math.clamp(math.floor(value + 0.5), 1, 50)
        if rounded == state.magneticRange then return true end
        if options.onRangeChanged then
            local ok, result = pcall(options.onRangeChanged, rounded)
            if not ok or result == false then notice("Não foi possível alterar o alcance.", true); return false end
        end
        state.magneticRange = rounded
        rangeValue.Text = tostring(rounded)
        fill.Size, thumb.Position = UDim2.new((rounded - 1) / 49, 0, 1, 0), UDim2.new((rounded - 1) / 49, 0, 0.5, 0)
        notice("Alcance: " .. rounded .. " studs" .. (available("ballMagnetic") and "" or " • Ball Magnetic pendente"))
        return true
    end
    connect(rangeValue.FocusLost, function()
        if destroyed then return end
        local value = tonumber(rangeValue.Text)
        if not value or not api.SetRange(value) then notice("Digite um alcance entre 1 e 50 studs.", true) end
        rangeValue.Text = tostring(state.magneticRange)
    end)
    local function fromPoint(point)
        if track.AbsoluteSize.X <= 0 then return end
        api.SetRange(1 + math.clamp((point.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * 49)
    end
    local function pointer(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
    end
    local function follows(input, original)
        return input == original or (original and original.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement)
    end
    local function ends(input, original)
        return input == original or (original and original.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)
    end
    connect(rangeHit.InputBegan, function(input)
        if destroyed or hidden or minimized or activeTab ~= "misc" then return end
        if pointer(input) then
            clearGestures()
            rangeInput, misc.ScrollingEnabled = input, false
            busy()
            fromPoint(input.Position)
        elseif input.KeyCode == Enum.KeyCode.Left then api.SetRange(state.magneticRange - 1)
        elseif input.KeyCode == Enum.KeyCode.Right then api.SetRange(state.magneticRange + 1) end
    end)
    connect(header.InputBegan, function(input)
        if destroyed or hidden or not pointer(input) then return end
        clearGestures()
        dragInput, dragStart, dragOrigin = input, input.Position, host.Position
        busy()
    end)
    connect(services.Input.InputChanged, function(input)
        if destroyed or hidden then return end
        if rangeInput and follows(input, rangeInput) then fromPoint(input.Position)
        elseif dragInput and follows(input, dragInput) then
            fit(dragOrigin.X.Offset + input.Position.X - dragStart.X, dragOrigin.Y.Offset + input.Position.Y - dragStart.Y)
        end
    end)
    connect(services.Input.InputEnded, function(input)
        if (rangeInput and ends(input, rangeInput)) or (dragInput and ends(input, dragInput)) then clearGestures() end
    end)
    connect(services.Input.WindowFocusReleased, clearGestures)
    function api.SetVisible(value)
        if destroyed then return false end
        clearGestures()
        hidden, gui.Enabled = value ~= true, value == true
        return true
    end
    connect(services.Input.InputBegan, function(input, processed)
        if not processed and not destroyed and input.KeyCode == Enum.KeyCode.RightShift
            and not services.Input:GetFocusedTextBox() then api.SetVisible(hidden) end
    end)
    connect(minimize.Activated, function()
        if destroyed then return end
        clearGestures()
        minimized, body.Visible = not minimized, minimized
        minimizeLabel.Text = minimized and "+" or "−"
        fit()
    end)
    function api.Destroy()
        if destroyed then return true end
        destroyed = true
        dragInput, rangeInput, busyCount = nil, nil, 0
        busy()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, tween in pairs(tweens) do tween:Cancel() end
        table.clear(connections)
        table.clear(tweens)
        gui:Destroy()
        return true
    end
    connect(close.Activated, function()
        if destroyed then return end
        if options.onClose then
            local ok, accepted = pcall(options.onClose)
            if not ok or accepted == false then notice("Não foi possível descarregar. Tente novamente.", true); return end
        end
        api.Destroy()
    end)
    function api.IsInput(input)
        if destroyed or hidden or not pointer(input) then return false end
        local point, origin, size = input.Position, window.AbsolutePosition, window.AbsoluteSize
        return point.X >= origin.X and point.X <= origin.X + size.X
            and point.Y >= origin.Y and point.Y <= origin.Y + size.Y
    end
    function api.GetState()
        local result = table.clone(state)
        result.tab, result.visible, result.minimized = activeTab, not hidden and not destroyed, minimized
        return result
    end
    function api.BindFeature(key, adapter)
        if destroyed or not controls[key] or controls[key].busy then return false end
        adapters[key] = adapter
        renderToggle(key)
        return true
    end
    function api.Refresh()
        if destroyed then return end
        for key in pairs(controls) do renderToggle(key) end
        for key in pairs(choices) do renderChoice(key) end
        refreshGK()
        local view = viewport()
        if not lastViewport or view.X ~= lastViewport.X or view.Y ~= lastViewport.Y then fit() end
    end
    local elapsed = 0
    connect(services.Run.Heartbeat, function(delta)
        if destroyed then return end
        elapsed += delta
        if elapsed >= 0.2 then elapsed = 0; api.Refresh() end
    end)
    -- An externally removed ScreenGui must release input listeners as well.
    connect(gui.Destroying, function() api.Destroy() end)
    api.Gui = gui
    api.SelectTab("offense")
    fit()
    busy()
    return api
end

return createZyonUI

end)()
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
