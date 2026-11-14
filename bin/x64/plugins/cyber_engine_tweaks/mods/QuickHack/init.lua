local Target = require("target")
local Cast = require("cast")

local function missingHud(err)
  print("QuickHack: hud load error: " .. tostring(err))
  local function noop()
  end
  return {
    install = noop,
    ensure = noop,
    refresh = noop,
    invalidate = noop,
    destroy = noop,
  }
end

local Hud
do
  local ok, result = pcall(require, "hud")
  if ok and type(result) == "table" and type(result.ensure) == "function" then
    Hud = result
  else
    Hud = missingHud(result)
  end
end

local function missingStream(err)
  print("QuickHack: stream load error: " .. tostring(err))
  return {
    tick = function()
    end,
    drawSettings = function()
    end,
    invalidate = function()
    end,
    destroy = function()
    end,
    push = function()
    end,
    isBarOn = function()
      return true
    end,
    isStreamOn = function()
      return true
    end,
    setBarOn = function()
    end,
    setStreamOn = function()
    end,
  }
end

local Stream
do
  local ok, result = pcall(require, "stream")
  if ok and type(result) == "table" and type(result.tick) == "function" then
    Stream = result
  else
    Stream = missingStream(result)
  end
end

-- Hotkeys (not inputs) so every slot can take a combo such as Ctrl+1.
local SLOT_KEYS = 18
local slot = 1
while slot <= SLOT_KEYS do
  local index = slot
  local ok, err = pcall(registerHotkey, "QuickHackSlot" .. index, "Quickhack " .. index, function()
    Cast.tryCast(index)
  end)
  if not ok then
    print("QuickHack: registerHotkey failed: " .. tostring(err))
    break
  end
  slot = slot + 1
end

pcall(registerHotkey, "QuickHackToggleBar", "Show / hide quickhack bar", function()
  Stream.setBarOn(not Stream.isBarOn())
end)

registerForEvent("onInit", function()
  Cast.install()
  Target.install()
  Hud.install()
  print("QuickHack ready build 88")
end)

registerForEvent("onOverlayOpen", function()
  Cast.setOverlay(true)
end)

registerForEvent("onOverlayClose", function()
  Cast.setOverlay(false)
end)

local updateErrorPrinted = false
local barShown = true

registerForEvent("onUpdate", function(dt)
  local player = Game.GetPlayer()
  if player == nil or not IsDefined(player) then
    Hud.invalidate()
    Stream.invalidate()
    return
  end
  local function run(name, fn)
    local ok, err = pcall(fn)
    if not ok and not updateErrorPrinted then
      updateErrorPrinted = true
      print("QuickHack: " .. name .. " failed: " .. tostring(err))
    end
  end
  local barOn = Stream.isBarOn()
  if not barOn and barShown then
    Hud.destroy()
  end
  barShown = barOn
  if barOn then
    run("hud ensure", function()
      Hud.ensure()
    end)
  end
  run("target", function()
    Target.tick(dt)
  end)
  run("dilation", function()
    Cast.tickDilation()
  end)
  if barOn then
    run("hud refresh", function()
      Hud.refresh()
    end)
    run("hud fx", function()
      Hud.tick(dt)
    end)
  end
  run("stream", function()
    Stream.tick(dt)
  end)
end)

registerForEvent("onDraw", function()
  if Stream.isBarOn() then
    pcall(function()
      Hud.drawDrag()
    end)
  end
  pcall(function()
    Stream.drawSettings()
  end)
end)

registerForEvent("onShutdown", function()
  pcall(function()
    Stream.destroy()
  end)
  pcall(function()
    Hud.destroy()
  end)
end)

-- Console: GetMod("QuickHack").stream(false) / .bar(false); pass true to re-enable.
local function toggle(setter, getter, label)
  return function(on)
    if on == nil then
      on = not getter()
    end
    setter(on == true)
    print("QuickHack: " .. label .. " " .. (getter() and "on" or "off"))
  end
end

return {
  stream = toggle(Stream.setStreamOn, Stream.isStreamOn, "console output"),
  bar = toggle(Stream.setBarOn, Stream.isBarOn, "quickhack bar"),
}
