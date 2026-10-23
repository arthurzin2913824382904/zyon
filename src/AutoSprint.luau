-- Hold the game's configured Sprint key while moving. Uses normal game sprint/stamina rules.
-- SendKeyEvent can be unavailable in some executors; failures leave the control off.
local function createAutoSprint(d)
    local enabled, closed, service, heldKey, sprintKey = false, false, nil, nil, nil
    local lastError, connection
    local A = {}
    local function errorText(message)
        lastError = tostring(message)
        if d.report then d.report(lastError) end
    end
    local function release()
        if not heldKey then return true end
        local ok, err = pcall(function() service:SendKeyEvent(false, heldKey, false, d.target) end)
        if not ok then errorText("Não foi possível soltar a tecla de sprint: " .. tostring(err)); return false end
        heldKey = nil
        return true
    end
    local function prepare()
        local ok, result = pcall(d.getBinding)
        if not ok or type(result) ~= "table" or type(result.KeyCodes) ~= "table" then
            return false, "O jogo não disponibilizou a tecla de Sprint."
        end
        local selected
        for _, key in ipairs(result.KeyCodes) do
            if d.isKeyboardKey(key) then selected = key; break end
        end
        if not selected then return false, "A configuração de Sprint precisa de uma tecla de teclado." end
        local got, input = pcall(d.getVirtualInput)
        if not got or not input then return false, "Este executor não disponibiliza entrada virtual para Auto Sprint." end
        local methodOK, method = pcall(function() return input.SendKeyEvent end)
        if not methodOK or type(method) ~= "function" then return false, "SendKeyEvent não está disponível neste executor." end
        service, sprintKey = input, selected
        return true
    end
    function A.Get() return enabled end
    function A.Error() return lastError end
    function A.Set(value)
        if closed or type(value) ~= "boolean" then return false, "Auto Sprint foi descarregado." end
        if value == enabled and (value or not heldKey) then return true end
        if not value then
            enabled = false
            return release()
        end
        local ok, reason = prepare()
        if not ok then lastError = reason; return false, reason end
        lastError, enabled = nil, true
        return true
    end
    local function pulse()
        if closed or not d.alive() then enabled = false; release(); return end
        if not enabled then release(); return end
        local ok, moving = pcall(d.shouldSprint)
        if not ok then
            enabled = false
            errorText("Falha ao consultar o movimento: " .. tostring(moving))
            release()
            return
        end
        if not moving then release(); return end
        if heldKey then return end
        -- A physically held key belongs to the player. Do not send its key-up.
        local reading, physical = pcall(d.isKeyDown, sprintKey)
        if not reading or physical then return end
        local sent, err = pcall(function() service:SendKeyEvent(true, sprintKey, false, d.target) end)
        if not sent then
            enabled = false
            errorText("O executor recusou Auto Sprint: " .. tostring(err))
            return
        end
        heldKey = sprintKey
    end
    function A.Cleanup()
        enabled = false
        if not release() then return false, lastError end
        closed = true
        if connection then connection:Disconnect(); connection = nil end
        return true
    end
    connection = d.heartbeat:Connect(pulse)
    return A
end

return createAutoSprint
