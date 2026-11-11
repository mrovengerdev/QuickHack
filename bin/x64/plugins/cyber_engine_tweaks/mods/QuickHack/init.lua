local Target = require("target")
local Cast = require("cast")
local Hud = require("hud")
local Stream = require("stream")

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
  print("QuickHack ready build 46")
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
  Stream.drawSettings()
end)

registerForEvent("onShutdown", function()
  Stream.destroy()
  Hud.destroy()
end)
