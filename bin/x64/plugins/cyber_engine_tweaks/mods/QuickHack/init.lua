local Target = require("target")
local Cast = require("cast")
local Hud = require("hud")

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
  print("QuickHack ready build 29")
end)

registerForEvent("onOverlayOpen", function()
  Cast.setOverlay(true)
end)

registerForEvent("onOverlayClose", function()
  Cast.setOverlay(false)
end)

registerForEvent("onUpdate", function(dt)
  local player = Game.GetPlayer()
  if player == nil or not IsDefined(player) then
    Hud.invalidate()
    return
  end
  Hud.ensure()
  Cast.tickDilation()
  Hud.refresh()
end)

registerForEvent("onShutdown", function()
  Hud.destroy()
end)
