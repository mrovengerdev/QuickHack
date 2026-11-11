local Target = require("target")
local Cast = require("cast")
local Hud = require("hud")

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

local inputPrinted = {}
local slot = 1
while slot <= 9 do
  local index = slot
  local ok, err = pcall(registerInput, "QuickHackSlot" .. index, "Quickhack " .. index, function(keypress)
    if not keypress then
      return
    end
    if not inputPrinted[index] then
      inputPrinted[index] = true
      print("QuickHack: bound slot " .. index .. " pressed")
    end
    Cast.tryCast(index)
  end)
  if not ok then
    print("QuickHack: registerInput failed: " .. tostring(err))
    break
  end
  slot = slot + 1
end

registerForEvent("onInit", function()
  Cast.install()
  Target.install()
  Hud.install()
  print("QuickHack ready build 51")
end)

registerForEvent("onOverlayOpen", function()
  Cast.setOverlay(true)
end)

registerForEvent("onOverlayClose", function()
  Cast.setOverlay(false)
end)

local updateErrorPrinted = false

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
  run("hud ensure", function()
    Hud.ensure()
  end)
  run("target", function()
    Target.tick(dt)
  end)
  run("dilation", function()
    Cast.tickDilation()
  end)
  run("hud refresh", function()
    Hud.refresh()
  end)
  run("stream", function()
    Stream.tick(dt)
  end)
end)

registerForEvent("onDraw", function()
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
