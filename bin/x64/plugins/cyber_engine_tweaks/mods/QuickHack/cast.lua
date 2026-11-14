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

local function notify(slotIndex, ok)
  pcall(function()
    local Hud = require("hud")
    if type(Hud) == "table" and type(Hud.feedback) == "function" then
      Hud.feedback(slotIndex, ok)
    end
  end)
end

local function ramDenied(command)
  local Hud = require("hud")
  if type(Hud) ~= "table" or type(Hud.canAfford) ~= "function" then
    return false, nil, nil
  end
  local affordable, available, cost = Hud.canAfford(command)
  return affordable == false, available, cost
end

local function bail(slotIndex, reason)
  local key = tostring(slotIndex) .. ":" .. reason
  if bailPrinted[key] then
    return
  end
  bailPrinted[key] = true
  print("QuickHack: tryCast slot " .. tostring(slotIndex) .. " skipped: " .. reason)
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
    notify(slotIndex, false)
    -- Locked for a RAM shortage gets the RAM-fail output; anything else
    -- (cooldown, already uploading, blocked) gets the blocked output.
    local denied, available, cost = false, nil, nil
    pcall(function()
      denied, available, cost = ramDenied(command)
    end)
    pcall(function()
      local streamMod = require("stream")
      if type(streamMod) ~= "table" then
        return
      end
      if denied and type(streamMod.pushFail) == "function" then
        streamMod.pushFail(command, available, cost)
      elseif type(streamMod.pushBlocked) == "function" then
        streamMod.pushBlocked(command)
      end
    end)
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
    notify(slotIndex, false)
    return
  end
  if not started then
    bail(slotIndex, "execute returned false")
    notify(slotIndex, false)
    local denied, available, cost = false, nil, nil
    pcall(function()
      denied, available, cost = ramDenied(command)
    end)
    if denied then
      pcall(function()
        local streamMod = require("stream")
        if type(streamMod) == "table" and type(streamMod.pushFail) == "function" then
          streamMod.pushFail(command, available, cost)
        end
      end)
    end
    return
  end
  notify(slotIndex, true)
  local okStream, streamMod = pcall(require, "stream")
  if okStream and type(streamMod) == "table" and type(streamMod.push) == "function" then
    streamMod.push(command)
  end
end

return Cast
