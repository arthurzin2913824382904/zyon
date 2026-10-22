-- tools/test.py inserts the actual UI integration block from src/zyon-core.luau below.
local captured
local Config = {
    CloseRangeRush = true, HighBallJumps = true, JumpThenDive = true, BackwardRecovery = true,
    PositionAssist = true, PreShotCoverage = true, RespectManualMovement = true,
    DiveFilter = "SMART", PositionMode = "THREATS",
}
local S = { alive = true, displayName = "OFF", displayDetail = "native detail" }
local ENV = { AUTO_GK_ENABLED = false }
local Stats = { Requests = 7, JumpRequests = 3, DiveRequests = 4, RushRequests = 2 }
local Rush = { candidate = {} }
local invalidations, releases, debugCalls = 0, 0, 0
local rejectInvalidation, rejectSmartRelease = false, false
local STR = { Enabled = false, SmartRelease = false }
function STR.SetEnabled(value) STR.Enabled = value; return true end
function STR.SetSmartRelease(value)
    if rejectSmartRelease then return false end
    STR.SmartRelease = value
    return true
end
local PlayerGui, UserInputService, RunService, TweenService = {}, {}, {}, {}
local LocalPlayer = { DisplayName = "Test" }
local function cleanup() return true end
local function flushStatusDisplay() end
local function invalidateFrame(value)
    assert(value == true)
    if rejectInvalidation then error("native invalidation failed") end
    invalidations += 1
end
local function releaseOwnedState(value) assert(value == true); releases += 1 end
local function status(name, detail) S.displayName, S.displayDetail = name, detail end
local function createZyonUI(options)
    captured = options
    return { IsInput = function() return false end }
end

-- @INTEGRATION@

assert(captured and ENV.ZyonHub == S.ui and S.isUIInput == S.ui.IsInput)
assert(ENV.AUTO_GK_ENABLED == false, "GK must start off")
assert(captured.features.autoGK.Set(true))
assert(ENV.AUTO_GK_ENABLED and captured.features.autoGK.Get())
assert(captured.features.autoGK.Set(false))
assert(not ENV.AUTO_GK_ENABLED and releases == 1)
print("PASS native Auto GK enable/disable releases owned movement")

for key, configKey in pairs({ closeRangeRush = "CloseRangeRush", highBallJumps = "HighBallJumps",
    jumpThenDive = "JumpThenDive", backwardRecovery = "BackwardRecovery", positionAssist = "PositionAssist",
    preShotCoverage = "PreShotCoverage", respectManualMovement = "RespectManualMovement" }) do
    local adapter = captured.features[key]
    assert(adapter.Get() == true)
    assert(adapter.Set(false))
    assert(Config[configKey] == false)
    assert(adapter.Set(true))
    assert(Config[configKey] == true)
end
assert(Rush.candidate == nil)
assert(invalidations == 3, "Position assist and coverage must invalidate the planner")
print("PASS all seven GK settings update the original configuration and reset the planner")

assert(captured.choices.diveDirection.Set("LEFT") and Config.DiveFilter == "LEFT")
Config.DiveFilter = "ALL"
assert(captured.choices.diveDirection.Get() == "SMART")
assert(not captured.choices.diveDirection.Set("INVALID"))
assert(captured.choices.positionMode.Set("HOME_AND_THREATS"))
assert(Config.PositionMode == "HOME_AND_THREATS" and invalidations == 4)
print("PASS native direction and position modes preserve original semantics")

rejectInvalidation = true
assert(not captured.features.positionAssist.Set(false))
assert(Config.PositionAssist == true, "Failed invalidation must restore configuration")
assert(not captured.choices.positionMode.Set("THREATS"))
assert(Config.PositionMode == "HOME_AND_THREATS")
rejectInvalidation = false
print("PASS failed planner updates roll back GK configuration")

assert(captured.features.autoShooting.Set(true))
assert(STR.Enabled and STR.SmartRelease and captured.features.autoShooting.Get())
assert(captured.features.autoShooting.Set(false))
assert(not STR.Enabled and not STR.SmartRelease)
rejectSmartRelease = true
assert(not captured.features.autoShooting.Set(true))
assert(not STR.Enabled and not STR.SmartRelease)
assert(captured.features.autoPassing == nil and captured.features.autoSprint == nil)
print("PASS shooting wraps the real assist and unavailable features stay unbound")

ENV.AutoGKDebug = function() debugCalls += 1 end
assert(captured.onGKDebug() and debugCalls == 1)
local report = captured.goalkeeperStatus()
assert(report.requests == 7 and report.jumps == 3 and report.dives == 4 and report.rushes == 2)
captured.onBusy(true); assert(S.uiBusy)
captured.onBusy(false); assert(not S.uiBusy)
S.alive = false
assert(not captured.features.autoGK.Set(true))
assert(not captured.features.highBallJumps.Set(false))
assert(not captured.choices.diveDirection.Set("LEFT"))
print("PASS status, diagnostics, busy state and lifecycle are connected")
print("Completed 6 core integration checks")
