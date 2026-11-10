local Target = require("target")

local Hud = {}

local SLOT_COUNT = 9
local ICON = 56
local ICON_Y = 18
local NUMBER_Y = 76
local TITLE_Y = 96
local RAM_Y = 0
local RAM_ICON = 14
local SLOT_W = 76
local STRIDE = 84
local BAR_W = 748
local BAR_H = 114
local NUMBER_TINT = nil
local WHITE = nil
local RED = nil

local canvas = nil
local parent = nil
local slots = {}
local overflow = nil
local built = false
local lastGen = -1
local printedFew = false
local printedMany = false
local imageErrorPrinted = false
local partEmptyPrinted = false
local partPrinted = false

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

local function optionText(command)
  local title = command.m_title
  if title == nil or tostring(title) == "" then
    title = command.m_titleAlternative
  end
  local text = title == nil and "" or tostring(title)
  if string.sub(text, 1, 7) == "LocKey#" then
    local ok, localized = pcall(function()
      return GetLocalizedText(text)
    end)
    if ok and localized ~= nil and tostring(localized) ~= "" then
      return tostring(localized)
    end
  end
  return text
end

local function iconStrings(command)
  local path, part = "", ""
  local okPath, redsPath = pcall(function()
    return QuickHackIcons.AtlasPathOf(command)
  end)
  local okPart, redsPart = pcall(function()
    return QuickHackIcons.PartNameOf(command)
  end)
  if okPath and redsPath ~= nil then
    path = tostring(redsPath)
  end
  if okPart and redsPart ~= nil then
    part = tostring(redsPart)
  end
  return path, part
end

local function applyAtlas(icon, path, part, size)
  if path == nil or path == "" or part == nil or part == "" or part == "None" then
    return false
  end
  local ok = pcall(function()
    icon:SetAtlasResource(path)
    icon:SetTexturePart(part)
    icon:SetAtlasResource(ResRef.FromString(path))
    icon:SetTexturePart(CName.new(part))
    icon:SetFitToContent(true)
    icon:SetSize(Vector2.new({ X = size, Y = size }))
    icon:SetTileHAlign(inkEHorizontalAlign.Center)
    icon:SetTileVAlign(inkEVerticalAlign.Center)
    icon:SetTintColor(WHITE)
    icon:SetOpacity(1.0)
  end)
  return ok
end

local function applyIcon(slot, command)
  local icon = slot.placeholder
  if command == nil or icon == nil or command.m_icon == nil then
    return
  end
  local key = tostring(command.m_icon)
  if key == slot.iconKey then
    return
  end
  local path, part = iconStrings(command)
  if not applyAtlas(icon, path, part, ICON) then
    if not imageErrorPrinted then
      imageErrorPrinted = true
      print("QuickHack: icon atlas failed " .. path .. " " .. part)
    end
    return
  end
  slot.icon = icon
  slot.iconKey = key
end

local function availableRam()
  local player = Game.GetPlayer()
  if player == nil then
    return nil
  end
  local ok, value = pcall(function()
    return Game.GetStatPoolsSystem():GetStatPoolValue(player:GetEntityID(), gamedataStatPoolType.Memory, false)
  end)
  if ok and type(value) == "number" then
    return math.floor(value + 0.001)
  end
  local maxOk, maxRam = pcall(function()
    return Game.GetStatsSystem():GetStatValue(player:GetEntityID(), gamedataStatType.Memory)
  end)
  local pctOk, pct = pcall(function()
    local defs = Game.GetAllBlackboardDefs().UI_PlayerBioMonitor
    return Game.GetBlackboardSystem():Get(defs):GetFloat(defs.MemoryPercent)
  end)
  if maxOk and pctOk and type(maxRam) == "number" and type(pct) == "number" then
    return math.floor(maxRam * pct * 0.01 + 0.001)
  end
  return nil
end

local costTypePrinted = false

local function readCost(command)
  local ok, cost = pcall(function()
    return QuickHackIcons.CostOf(command)
  end)
  if not ok or cost == nil then
    if not costTypePrinted then
      costTypePrinted = true
      print("QuickHack: cost type " .. type(cost) .. " " .. tostring(cost))
    end
    return nil
  end
  local value = cost
  if type(cost) ~= "number" then
    value = tonumber(tostring(cost))
  end
  if type(value) ~= "number" then
    if not costTypePrinted then
      costTypePrinted = true
      print("QuickHack: cost type " .. type(cost) .. " " .. tostring(cost))
    end
    return nil
  end
  if value < 0 then
    return nil
  end
  if value == 0 and not costTypePrinted then
    costTypePrinted = true
    print("QuickHack: cost type " .. type(cost) .. " value 0")
  end
  return math.floor(value + 0.001)
end

local function paintRam(slot, command)
  if slot.ramText == nil then
    return
  end
  local cost = readCost(command)
  if cost == nil then
    slot.ramText:SetText("")
    slot.ramText:SetVisible(false)
    return
  end
  slot.ramText:SetText(tostring(cost))
  local available = availableRam()
  local unaffordable = available ~= nil and cost > available
  slot.ramText:SetTintColor(unaffordable and RED or NUMBER_TINT)
  slot.ramText:SetVisible(true)
end

local function hideSlot(slot)
  if slot.placeholder ~= nil then
    slot.placeholder:SetVisible(false)
  end
  if slot.icon ~= nil then
    slot.icon:SetVisible(false)
  end
  if slot.number ~= nil then
    slot.number:SetVisible(false)
  end
  if slot.title ~= nil then
    slot.title:SetVisible(false)
  end
  if slot.ramText ~= nil then
    slot.ramText:SetVisible(false)
  end
  if slot.ramIcon ~= nil then
    slot.ramIcon:SetVisible(false)
  end
end

local function showSlot(slot, command)
  local opacity = command.m_isLocked and 0.4 or 1.0
  slot.number:SetOpacity(1.0)
  slot.title:SetOpacity(opacity)
  slot.number:SetVisible(true)
  slot.title:SetVisible(true)
  slot.title:SetText(optionText(command))
  applyIcon(slot, command)
  slot.placeholder:SetOpacity(opacity)
  slot.placeholder:SetVisible(true)
  paintRam(slot, command)
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
  RED = HDRColor.new({ Red = 1.0, Green = 0.15, Blue = 0.15, Alpha = 1.0 })

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
    place(icon, x + 10, ICON_Y, ICON, ICON)
    icon:SetVisible(false)
    icon:Reparent(canvas, -1)

    local ramText = makeText(x, RAM_Y, SLOT_W, 16, 14, NUMBER_TINT, "")
    local number = makeText(x, NUMBER_Y, SLOT_W, 18, 18, NUMBER_TINT, tostring(i))
    local title = makeText(x, TITLE_Y, SLOT_W, 14, 13, WHITE, "")
    slots[i] = {
      placeholder = icon,
      icon = icon,
      number = number,
      title = title,
      ramText = ramText,
      iconKey = nil,
      x = x,
    }
    i = i + 1
  end

  overflow = makeText(756, NUMBER_Y, SLOT_W, 18, 18, NUMBER_TINT, "")
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
  local list = Target.getCommands()
  local count = #list
  if count == 0 then
    local i = 1
    while i <= SLOT_COUNT do
      hideSlot(slots[i])
      i = i + 1
    end
    overflow:SetVisible(false)
    canvas:SetVisible(false)
    lastGen = Target.getGeneration()
    return
  end
  local gen = Target.getGeneration()
  local ramIndex = 1
  while ramIndex <= SLOT_COUNT do
    local command = list[ramIndex]
    if command ~= nil and slots[ramIndex] ~= nil then
      paintRam(slots[ramIndex], command)
    end
    ramIndex = ramIndex + 1
  end
  if gen == lastGen then
    if not printedFew or not printedMany then
      noteSlot1(count)
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
