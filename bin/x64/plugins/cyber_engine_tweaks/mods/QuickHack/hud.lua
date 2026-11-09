local Target = require("target")

local Hud = {}

local SLOT_COUNT = 9
local ICON = 56
local SLOT_W = 76
local STRIDE = 84
local BAR_W = 748
local BAR_H = 96
local NUMBER_TINT = nil
local WHITE = nil

local canvas = nil
local parent = nil
local slots = {}
local overflow = nil
local built = false
local lastGen = -1
local printedFew = false
local printedMany = false
local imageErrorPrinted = false
local buildErrorPrinted = false

local function screenX(widget)
  local ok, pos = pcall(function()
    return widget:GetScreenPosition()
  end)
  if ok and pos ~= nil then
    if pos.X ~= nil then
      return pos.X
    end
    if pos.x ~= nil then
      return pos.x
    end
  end
  local okMargin, margin = pcall(function()
    return widget:GetMargin()
  end)
  if okMargin and margin ~= nil then
    if margin.left ~= nil then
      return margin.left
    end
    if margin.Left ~= nil then
      return margin.Left
    end
  end
  return nil
end

local function tryPrintSlot1(count)
  if slots[1] == nil or slots[1].icon == nil then
    return false
  end
  local x = screenX(slots[1].icon)
  if x == nil then
    return false
  end
  print(string.format("QuickHack slot1 x=%.4f count=%d", x, count))
  return true
end

local function noteSlot1(count)
  if count >= 1 and count <= 3 and not printedFew then
    if tryPrintSlot1(count) then
      printedFew = true
    end
  end
  if count >= 8 and not printedMany then
    if tryPrintSlot1(count) then
      printedMany = true
    end
  end
end

local function place(widget, x, y, w, h)
  widget:SetAnchor(inkEAnchor.TopLeft)
  widget:SetAnchorPoint(Vector2.new({ X = 0.0, Y = 0.0 }))
  widget:SetMargin(inkMargin.new({ left = x, top = y, right = 0.0, bottom = 0.0 }))
  widget:SetSize(Vector2.new({ X = w, Y = h }))
end

local function makeText(x, y, w, h, size, tint, text)
  local label = inkText.new()
  place(label, x, y, w, h)
  label:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
  label:SetFontStyle("Regular")
  label:SetFontSize(size)
  label:SetTintColor(tint)
  label:SetHorizontalAlignment(textHorizontalAlignment.Center)
  label:SetText(text)
  label:SetVisible(false)
  label:Reparent(canvas, -1)
  return label
end

local function applyIcon(slot, command)
  local iconId = command.m_icon
  if iconId == nil then
    return
  end
  local key = tostring(iconId)
  if key == slot.iconKey then
    return
  end
  local ok, err = pcall(function()
    local record = TweakDBInterface.GetUIIconRecord(iconId)
    slot.icon:SetAtlasResource(record:AtlasResourcePath())
    slot.icon:SetTexturePart(record:AtlasPartName())
  end)
  if not ok then
    if not imageErrorPrinted then
      imageErrorPrinted = true
      print("QuickHack: icon atlas failed: " .. tostring(err))
    end
    return
  end
  slot.iconKey = key
end

local function hideSlot(slot)
  slot.icon:SetVisible(false)
  slot.number:SetVisible(false)
  slot.title:SetVisible(false)
end

local function showSlot(slot, command)
  local opacity = command.m_isLocked and 0.4 or 1.0
  slot.icon:SetOpacity(opacity)
  slot.title:SetOpacity(opacity)
  slot.number:SetOpacity(1.0)
  slot.icon:SetVisible(true)
  slot.number:SetVisible(true)
  slot.title:SetVisible(true)
  local title = command.m_title
  slot.title:SetText(title == nil and "" or tostring(title))
  applyIcon(slot, command)
end

local function build()
  local layer = Game.GetInkSystem():GetLayer(CName.new("inkHUDLayer"))
  if layer == nil then
    return false
  end
  local window = layer:GetVirtualWindow()
  if window == nil then
    return false
  end

  NUMBER_TINT = HDRColor.new({ Red = 0.3686, Green = 0.9647, Blue = 1.1888, Alpha = 1.0 })
  WHITE = HDRColor.new({ Red = 1.0, Green = 1.0, Blue = 1.0, Alpha = 1.0 })

  canvas = inkCanvas.new()
  canvas:SetName(CName.new("quickhack_bar"))
  canvas:SetAnchor(inkEAnchor.BottomCenter)
  canvas:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 1.0 }))
  canvas:SetMargin(inkMargin.new({ left = 0.0, top = 0.0, right = 0.0, bottom = 128.0 }))
  canvas:SetSize(Vector2.new({ X = BAR_W, Y = BAR_H }))
  canvas:SetVisible(false)
  canvas:Reparent(window, -1)
  parent = window

  slots = {}
  local i = 1
  while i <= SLOT_COUNT do
    local x = (i - 1) * STRIDE
    local icon = inkImage.new()
    icon:SetAnchor(inkEAnchor.TopLeft)
    place(icon, x, 0, ICON, ICON)
    icon:SetVisible(false)
    icon:Reparent(canvas, -1)

    local number = makeText(x, 58, SLOT_W, 18, 18, NUMBER_TINT, tostring(i))
    local title = makeText(x, 76, SLOT_W, 14, 13, WHITE, "")
    slots[i] = {
      icon = icon,
      number = number,
      title = title,
      iconKey = nil,
    }
    i = i + 1
  end

  overflow = makeText(756, 58, SLOT_W, 18, 18, NUMBER_TINT, "")
  built = true
  return true
end

function Hud.install()
end

function Hud.ensure()
  if built then
    return
  end
  local ok, err = pcall(build)
  if ok and built then
    return
  end
  if canvas ~= nil and parent ~= nil then
    pcall(function()
      parent:RemoveChild(canvas)
    end)
  end
  canvas = nil
  parent = nil
  slots = {}
  overflow = nil
  built = false
  if not ok and not buildErrorPrinted then
    buildErrorPrinted = true
    print("QuickHack: bar build failed: " .. tostring(err))
  end
end

function Hud.refresh()
  if not built then
    return
  end
  local gen = Target.getGeneration()
  if gen == lastGen then
    if not printedFew or not printedMany then
      noteSlot1(#Target.getCommands())
    end
    return
  end
  lastGen = gen

  local list = Target.getCommands()
  local count = #list
  local i = 1
  while i <= SLOT_COUNT do
    local command = list[i]
    if command == nil then
      hideSlot(slots[i])
    else
      showSlot(slots[i], command)
    end
    i = i + 1
  end

  if count > 9 then
    overflow:SetText("+" .. tostring(count - 9))
    overflow:SetVisible(true)
  else
    overflow:SetVisible(false)
  end

  canvas:SetVisible(count > 0)
  noteSlot1(count)
end

function Hud.destroy()
  if canvas ~= nil and parent ~= nil then
    pcall(function()
      parent:RemoveChild(canvas)
    end)
  end
  canvas = nil
  parent = nil
  slots = {}
  overflow = nil
  built = false
  lastGen = -1
end

return Hud
