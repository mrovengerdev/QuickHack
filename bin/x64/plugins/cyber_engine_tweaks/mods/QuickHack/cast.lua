local Target = require("target")

local overlay = false
local lastCast = {}

local Cast = {}

function Cast.setOverlay(isOpen)
  overlay = isOpen and true or false
end

function Cast.isOverlay()
  return overlay
end

local function unsetFocusDilation()
  Game.GetTimeSystem():UnsetTimeDilation(TimeDilationHelper.GetFocusModeKey())
  Game.GetTimeSystem():UnsetTimeDilation(TimeDilationHelper.GetFocusedStateKey())
end

function Cast.install()
  Override("PlayerVisionModeController", "ActivateVisionMode", function(self, wrapped, ...)
    wrapped(...)
    unsetFocusDilation()
  end)
end

function Cast.tickDilation()
  local player = Game.GetPlayer()
  local ok, vision = pcall(function()
    local defs = Game.GetAllBlackboardDefs().PlayerStateMachine
    return Game.GetBlackboardSystem():GetLocalInstanced(player:GetEntityID(), defs):GetInt(defs.Vision)
  end)
  if ok and vision == 1 then
    unsetFocusDilation()
  end
end

local bailPrinted = {}

local function bail(slotIndex, reason)
  local key = tostring(slotIndex) .. ":" .. reason
  if bailPrinted[key] then
    return
  end
  bailPrinted[key] = true
  print("QuickHack: tryCast slot " .. tostring(slotIndex) .. " skipped: " .. reason)
end

local function actionDefined(action)
  if action == nil then
    return false
  end
  local ok, defined = pcall(function()
    return IsDefined(action)
  end)
  return ok and defined == true
end

function Cast.tryCast(slotIndex)
  if Cast.isOverlay() then
    bail(slotIndex, "overlay open")
    return
  end

  local menuOk, inMenu = pcall(function()
    return Game.GetBlackboardSystem():Get(Game.GetAllBlackboardDefs().UI_System):GetBool(Game.GetAllBlackboardDefs().UI_System.IsInMenu)
  end)
  if menuOk and inMenu then
    bail(slotIndex, "menu open")
    return
  end

  local player = Game.GetPlayer()
  if player == nil then
    bail(slotIndex, "no player")
    return
  end
  if QuickhackModule.IsQuickhackBlockedByScene(player) then
    bail(slotIndex, "scene blocked")
    return
  end

  local command = Target.getCommands()[slotIndex]
  if command == nil then
    bail(slotIndex, "empty slot")
    return
  end
  if command.m_noQuickhackData then
    bail(slotIndex, "no quickhack data")
    return
  end
  if command.m_isLocked then
    bail(slotIndex, "locked")
    return
  end

  local previous = lastCast[slotIndex]
  if previous ~= nil and os.clock() - previous < 0.20 then
    bail(slotIndex, "repeat guard")
    return
  end
  lastCast[slotIndex] = os.clock()

  local ok, started = pcall(function()
    return QuickHackCast.Execute(player, command)
  end)
  if not ok then
    bail(slotIndex, "execute error " .. tostring(started))
    return
  end
  if not started then
    bail(slotIndex, "execute returned false")
    return
  end
  local okStream, streamMod = pcall(require, "stream")
  if okStream and type(streamMod) == "table" and type(streamMod.push) == "function" then
    streamMod.push(command)
  end
end

return Cast
