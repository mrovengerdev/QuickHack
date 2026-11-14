local Target = require("target")

local Hud = {}

local SLOT_COUNT = 18
local ROW_SIZE = 9
local ROW_GAP = 100
local ROW_H = 126
local ICON = 56
local ICON_Y = 18
local NUMBER_Y = 76
local TITLE_Y = 96
local RAM_Y = 0
local SLOT_W = 76
local STRIDE = 84
local BAR_W = 748
local BAR_H = 114
local MIN_SCALE = 0.70
local MAX_SCALE = 1.50
local barScale = 1.0
local FILL_OPACITY = 0.15
local MAIN_COLORS = "base\\gameplay\\gui\\common\\main_colors.inkstyle"
local NUMBER_TINT = nil
local RED = nil

local canvas = nil
local parent = nil
local slots = {}
local overflow = nil
local twoRows = false
local arranging = false
local layoutKey = nil
local heldRow = nil
local built = false
local lastGen = -1
local inkController = nil
local inkHost = nil
local inkSpawner = nil
local hosted = false
local hostRetry = false
local windowPrinted = false
local wrapPrinted = false
local spawnFailPrinted = false
local tintPrinted = false
local iconTintPrinted = false
local costPrinted = false
local buildErrorPrinted = false


local UNBOUND_LABEL = "[UNBINDED]"
local bindErrorPrinted = false

local function bindingLabel(index)
  local ok, name = pcall(function()
    if type(GetBind) ~= "function" then
      return nil
    end
    return GetBind("QuickHackSlot" .. tostring(index))
  end)
  if not ok or name == nil then
    return UNBOUND_LABEL
  end
  name = tostring(name)
  if name == "" or name == "Unbound" or name == "unbound" then
    return UNBOUND_LABEL
  end
  return name
end

local function clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

local function sc(n)
  return n * barScale
end

local function scInt(n)
  local v = math.floor(n * barScale + 0.5)
  if v < 1 then
    return 1
  end
  return v
end

local function bindingFontSize(label)
  return scInt(18)
end

local function applyBinding(slot)
  if slot == nil or slot.number == nil then
    return
  end
  local ok, err = pcall(function()
    local label = bindingLabel(slot.index)
    if label == slot.bindLabel then
      return
    end
    slot.number:SetText(label)
    slot.number:SetFontSize(bindingFontSize(label))
    slot.bindLabel = label
  end)
  if ok then
    return
  end
  if not bindErrorPrinted then
    bindErrorPrinted = true
    print("QuickHack: binding label failed: " .. tostring(err))
  end
  pcall(function()
    local fallback = tostring(slot.index)
    slot.number:SetText(fallback)
    slot.number:SetFontSize(scInt(18))
    slot.bindLabel = fallback
  end)
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

-- Lua cannot read QuickhackData fields, so the title comes from redscript.
local function optionText(command)
  if command == nil then
    return ""
  end
  local ok, reds = pcall(function()
    return QuickHackIcons.TitleOf(command)
  end)
  if not ok or reds == nil then
    return ""
  end
  local text = tostring(reds)
  if string.sub(text, 1, 8) == "userdata" then
    return ""
  end
  if string.sub(text, 1, 7) == "LocKey#" then
    local okLoc, localized = pcall(function()
      return GetLocalizedText(text)
    end)
    if okLoc and localized ~= nil and tostring(localized) ~= "" then
      return tostring(localized)
    end
  end
  return text
end

-- Spawns the Slot item from quickhack.archive and loads the game's own
-- quickhack sprite into it. The spawned widget is named qhicon<index>.
local function applyIcon(slot, command)
  if command == nil or canvas == nil then
    return
  end
  local okKey, key = pcall(function()
    return QuickHackIcons.DebugOf(command)
  end)
  if not okKey or key == nil then
    return
  end
  key = tostring(key)
  if key == "no-command" or key == "icon-id-invalid" or key == "no-uiicon-record" then
    slot.iconKey = nil
    return
  end
  if key == slot.iconKey and slot.icon ~= nil then
    return
  end
  slot.icon = nil
  slot.iconKey = nil
  local okLib, reason = pcall(function()
    return QuickHackIcons.LibraryReason(inkController or inkSpawner, canvas, command, slot.index, slot.x + sc(10), (slot.y or 0) + sc(ICON_Y), scInt(ICON))
  end)
  if not okLib then
    reason = "error " .. tostring(reason)
  end
  if reason ~= "ok" then
    if not spawnFailPrinted then
      spawnFailPrinted = true
      print("QuickHack: slot library spawn " .. tostring(reason))
    end
    return
  end
  pcall(function()
    local widget = canvas:GetWidget(CName.new("qhicon" .. tostring(slot.index)))
    if widget ~= nil then
      slot.icon = widget
      widget:SetOpacity(1.0)
      widget:SetVisible(true)
    end
  end)
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

local OVERCLOCK_BUFF = "BaseStatusEffect.Intelligence_Central_Milestone_3_Overclock_Buff"

local function hasOverclock(player)
  if player == nil then
    return false
  end
  local ok, active = pcall(function()
    return QuickHackableHelper.IsOverclockedStateActive(player)
  end)
  if ok then
    return active == true
  end
  ok, active = pcall(function()
    return Game.GetStatusEffectSystem():HasStatusEffect(player:GetEntityID(), TweakDBID.new(OVERCLOCK_BUFF))
  end)
  return ok and active == true
end

local function canPayWithHealth(player, cost, memory)
  if player == nil or type(cost) ~= "number" or type(memory) ~= "number" then
    return false
  end
  if not hasOverclock(player) then
    return false
  end
  local shortfall = cost - memory
  if shortfall <= 0 then
    return true
  end
  local okRate, rate = pcall(function()
    return Game.GetStatsSystem():GetStatValue(player:GetEntityID(), gamedataStatType.OverclockedStateHealthCost)
  end)
  local okHealth, health = pcall(function()
    return Game.GetStatPoolsSystem():GetStatPoolValue(player:GetEntityID(), gamedataStatPoolType.Health, false)
  end)
  if not okRate or not okHealth or type(rate) ~= "number" or type(health) ~= "number" then
    return false
  end
  return health - rate * shortfall > 0
end

local function readCost(command)
  local ok, cost = pcall(function()
    return QuickHackIcons.CostOf(command)
  end)
  local value = nil
  if ok and cost ~= nil then
    value = cost
    if type(cost) ~= "number" then
      value = tonumber(tostring(cost))
    end
  end
  if type(value) ~= "number" then
    if not costPrinted then
      costPrinted = true
      print("QuickHack: cost read failed " .. type(cost) .. " " .. tostring(cost))
    end
    return nil
  end
  if value < 0 then
    return nil
  end
  return math.floor(value + 0.001)
end

local function gameTint(widget, unaffordable)
  if widget == nil then
    return
  end
  local ok = pcall(function()
    widget:SetStyle(ResRef.FromString(MAIN_COLORS))
    widget:BindProperty(CName.new("tintColor"), CName.new(unaffordable and "MainColors.Red" or "MainColors.Blue"))
  end)
  if not ok then
    if not tintPrinted then
      tintPrinted = true
      print("QuickHack: game color binding failed, using fallback tint")
    end
    pcall(function()
      widget:SetTintColor(unaffordable and RED or NUMBER_TINT)
    end)
  end
end

local function eachEdge(slot, fn)
  if slot.edges == nil then
    return
  end
  local edge = 1
  while slot.edges[edge] ~= nil do
    fn(slot.edges[edge])
    edge = edge + 1
  end
end

local function currentScale()
  local scale = 1.0
  pcall(function()
    local Stream = require("stream")
    if type(Stream) == "table" and type(Stream.barScale) == "function" then
      scale = Stream.barScale()
    end
  end)
  if type(scale) ~= "number" then
    scale = 1.0
  end
  return clamp(scale, MIN_SCALE, MAX_SCALE)
end

local function streamMod()
  local ok, mod = pcall(require, "stream")
  if ok and type(mod) == "table" then
    return mod
  end
  return nil
end

local function rowOf(index)
  if index > ROW_SIZE then
    return 2
  end
  return 1
end

-- Row origin in HUD units, offset from the bar's usual spot. Always the
-- same X/Y the overlay sliders show, so the preview is where the row lands.
local function rowOrigin(row)
  local mod = streamMod()
  if mod ~= nil and type(mod.rowXY) == "function" then
    local x, y = mod.rowXY(row)
    if type(x) == "number" and type(y) == "number" then
      return x, y
    end
  end
  if row == 2 then
    return 0, sc(ROW_GAP)
  end
  return 0, 0
end

local function layoutSlot(slot, ox)
  if slot == nil then
    return
  end
  ox = ox or 0
  local rx, ry = rowOrigin(rowOf(slot.index))
  local col = (slot.index - 1) % ROW_SIZE
  local x = rx + sc(col * STRIDE)
  local y = ry
  slot.x = x
  slot.y = y
  local frameX = x + sc(8) + ox
  local frameY = y + sc(ICON_Y - 2)
  local frameW = sc(ICON + 4)
  local frameH = sc(ICON + 4)
  local thickness = scInt(2)
  if slot.fill ~= nil then
    place(slot.fill, frameX, frameY, frameW, frameH)
  end
  if slot.edges ~= nil then
    if slot.edges[1] ~= nil then
      place(slot.edges[1], frameX, frameY, frameW, thickness)
    end
    if slot.edges[2] ~= nil then
      place(slot.edges[2], frameX, frameY + frameH - thickness, frameW, thickness)
    end
    if slot.edges[3] ~= nil then
      place(slot.edges[3], frameX, frameY, thickness, frameH)
    end
    if slot.edges[4] ~= nil then
      place(slot.edges[4], frameX + frameW - thickness, frameY, thickness, frameH)
    end
  end
  local textX = x + ox
  if slot.ramText ~= nil then
    place(slot.ramText, textX, y + sc(RAM_Y), sc(SLOT_W), sc(16))
    slot.ramText:SetFontSize(scInt(14))
  end
  if slot.number ~= nil then
    place(slot.number, textX, y + sc(NUMBER_Y), sc(SLOT_W), sc(18))
    slot.number:SetFontSize(scInt(18))
  end
  if slot.title ~= nil then
    place(slot.title, textX, y + sc(TITLE_Y), sc(SLOT_W), sc(30))
    slot.title:SetFontSize(scInt(13))
    pcall(function()
      slot.title:SetWrapping(true, sc(SLOT_W))
    end)
  end
  if slot.icon ~= nil then
    pcall(function()
      place(slot.icon, x + sc(10) + ox, y + sc(ICON_Y), sc(ICON), sc(ICON))
    end)
  end
end

local function layoutOverflow()
  if overflow == nil then
    return
  end
  local rx, ry = rowOrigin(twoRows and 2 or 1)
  place(overflow, rx + sc(756), ry + sc(NUMBER_Y), sc(SLOT_W), sc(18))
  overflow:SetFontSize(scInt(18))
end

local function layoutBar()
  if canvas ~= nil then
    pcall(function()
      canvas:SetSize(Vector2.new({ X = sc(BAR_W), Y = sc(BAR_H) }))
    end)
  end
  local i = 1
  while i <= SLOT_COUNT do
    if slots[i] ~= nil then
      slots[i].fx = nil
      layoutSlot(slots[i], 0)
      slots[i].iconKey = nil
    end
    i = i + 1
  end
  layoutOverflow()
end

local function relayoutRows()
  local i = 1
  while i <= SLOT_COUNT do
    if slots[i] ~= nil then
      layoutSlot(slots[i], 0)
    end
    i = i + 1
  end
  layoutOverflow()
end

local function updateLayoutMode(count)
  local overlayOpen = false
  pcall(function()
    overlayOpen = require("cast").isOverlay() == true
  end)
  twoRows = count > ROW_SIZE
  arranging = overlayOpen
  local mod = streamMod()
  local key = tostring(twoRows) .. tostring(arranging)
  if mod ~= nil and type(mod.rowPos) == "function" then
    local a = mod.rowPos(1)
    local b = mod.rowPos(2)
    if a ~= nil then
      key = key .. string.format("|%.1f,%.1f", a.x, a.y)
    end
    if b ~= nil then
      key = key .. string.format("|%.1f,%.1f", b.x, b.y)
    end
  end
  if key ~= layoutKey then
    layoutKey = key
    relayoutRows()
  end
end

local function applyFx(slot)
  local fx = slot.fx
  if fx == nil then
    return
  end
  local t = fx.t
  local dur = fx.dur
  if fx.kind == "fail" then
    local decay = 1 - (t / dur)
    local ox = math.sin(t * 42) * sc(7) * decay
    layoutSlot(slot, ox)
    return
  end
  layoutSlot(slot, 0)
  local w = 0.5 * (1 - math.cos(t / dur * 4 * math.pi))
  if slot.fill ~= nil then
    slot.fill:SetOpacity(FILL_OPACITY + 0.45 * w)
  end
  eachEdge(slot, function(edge)
    edge:SetOpacity(0.75 + 0.25 * w)
  end)
  if slot.icon ~= nil then
    pcall(function()
      slot.icon:SetOpacity(1.0 - 0.55 * w)
    end)
  end
end

local function ramState(cost)
  local available = availableRam()
  local unaffordable = available ~= nil and cost > available
  if unaffordable then
    local okPay, canPay = pcall(canPayWithHealth, Game.GetPlayer(), cost, available)
    if okPay and canPay == true then
      unaffordable = false
    end
  end
  return available, unaffordable
end

local seenLockReasons = {}

-- The game's own quickhack list (the same data the scanner wheel uses) marks a
-- hack unusable with m_isLocked and says why in m_inactiveReason: cooldown,
-- already uploading, not enough RAM, and so on. Red whenever it does.
local function gameLocked(command)
  local ok, locked = pcall(function()
    return command.m_isLocked == true
  end)
  if not ok or not locked then
    return false
  end
  pcall(function()
    local reason = tostring(command.m_inactiveReason)
    local title = tostring(optionText(command))
    local key = title .. "|" .. reason
    if not seenLockReasons[key] then
      seenLockReasons[key] = true
      print("QuickHack: locked " .. title .. " reason " .. reason)
    end
  end)
  return true
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
  local available, unaffordable = ramState(cost)
  if gameLocked(command) then
    unaffordable = true
  end
  gameTint(slot.ramText, unaffordable)
  gameTint(slot.number, unaffordable)
  gameTint(slot.title, unaffordable)
  if slot.fill ~= nil then
    gameTint(slot.fill, unaffordable)
    slot.fill:SetOpacity(FILL_OPACITY)
    slot.fill:SetVisible(true)
  end
  slot.ramText:SetVisible(true)
  if slot.icon ~= nil and slot.iconKey ~= nil then
    local okTint, tinted = pcall(function()
      return QuickHackIcons.TintIcon(slot.icon, unaffordable)
    end)
    if not okTint or tinted ~= true then
      if not iconTintPrinted then
        iconTintPrinted = true
        print("QuickHack: icon tint failed " .. tostring(tinted))
      end
      gameTint(slot.icon, unaffordable)
    end
  end
  eachEdge(slot, function(edge)
    gameTint(edge, unaffordable)
    edge:SetOpacity(0.75)
    edge:SetVisible(true)
  end)
end

local function hideSlot(slot)
  if slot.fill ~= nil then
    slot.fill:SetVisible(false)
  end
  eachEdge(slot, function(edge)
    edge:SetVisible(false)
  end)
  if slot.icon ~= nil then
    pcall(function()
      slot.icon:SetVisible(false)
    end)
  end
  if canvas ~= nil and slot.index ~= nil then
    pcall(function()
      local names = { "qhspawn", "qhicon" }
      local n = 1
      while names[n] ~= nil do
        local old = canvas:GetWidget(CName.new(names[n] .. tostring(slot.index)))
        if old ~= nil then
          canvas:RemoveChild(old)
        end
        n = n + 1
      end
    end)
  end
  slot.icon = nil
  slot.iconKey = nil
  slot.ghost = false
  if slot.number ~= nil then
    slot.number:SetVisible(false)
  end
  if slot.title ~= nil then
    slot.title:SetVisible(false)
  end
  if slot.ramText ~= nil then
    slot.ramText:SetVisible(false)
  end
end

local function ghostSlot(slot)
  if slot.fill ~= nil then
    gameTint(slot.fill, false)
    slot.fill:SetOpacity(FILL_OPACITY)
    slot.fill:SetVisible(true)
  end
  eachEdge(slot, function(edge)
    gameTint(edge, false)
    edge:SetOpacity(0.45)
    edge:SetVisible(true)
  end)
  slot.ghost = true
end

-- While the overlay is open every empty slot shows as a frame so the full
-- 2x9 layout is visible; closing the overlay hides them again.
local function updateGhosts(list)
  local i = 1
  while i <= SLOT_COUNT do
    local slot = slots[i]
    if slot ~= nil and list[i] == nil then
      if arranging and not slot.ghost then
        pcall(ghostSlot, slot)
      elseif not arranging and slot.ghost then
        pcall(hideSlot, slot)
      end
      if arranging and slot.ghost then
        local glow = heldRow ~= nil and rowOf(i) == heldRow
        eachEdge(slot, function(edge)
          edge:SetOpacity(glow and 1.0 or 0.45)
        end)
      end
    end
    i = i + 1
  end
end

local function showSlot(slot, command)
  slot.ghost = false
  local opacity = 1.0
  slot.number:SetOpacity(1.0)
  slot.title:SetOpacity(opacity)
  applyBinding(slot)
  slot.number:SetVisible(true)
  slot.title:SetVisible(true)
  slot.title:SetText(optionText(command))
  eachEdge(slot, function(edge)
    edge:SetOpacity(0.75)
    edge:SetVisible(true)
  end)
  applyIcon(slot, command)
  if slot.icon ~= nil then
    pcall(function()
      if slot.iconKey == nil then
        slot.icon:SetVisible(false)
      else
        slot.icon:SetOpacity(opacity)
        slot.icon:SetVisible(true)
      end
    end)
  end
  paintRam(slot, command)
end

local function build()
  barScale = currentScale()
  local layer = Game.GetInkSystem():GetLayer(CName.new("inkHUDLayer"))
  if layer == nil then
    return false
  end
  local window = layer:GetVirtualWindow()
  if window == nil then
    return false
  end

  NUMBER_TINT = HDRColor.new({ Red = 0.3686, Green = 0.9647, Blue = 1.1888, Alpha = 1.0 })
  RED = HDRColor.new({ Red = 1.0, Green = 0.15, Blue = 0.15, Alpha = 1.0 })

  canvas = nil
  parent = nil
  hosted = false
  if inkController ~= nil then
    local okBar, bar = pcall(function()
      return QuickHackIcons.MakeBar(inkController, sc(BAR_W), sc(BAR_H), 128.0)
    end)
    if okBar and bar ~= nil then
      canvas = bar
      if inkHost == nil then
        pcall(function()
          inkHost = inkController:GetRootCompoundWidget()
        end)
      end
      parent = inkHost
      hosted = true
    end
  end
  if canvas == nil then
    canvas = inkCanvas.new()
    canvas:SetName(CName.new("quickhack_bar"))
    canvas:SetAnchor(inkEAnchor.BottomCenter)
    canvas:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 1.0 }))
    canvas:SetMargin(inkMargin.new({ left = 0.0, top = 0.0, right = 0.0, bottom = 128.0 }))
    canvas:SetSize(Vector2.new({ X = sc(BAR_W), Y = sc(BAR_H) }))
    canvas:SetVisible(false)
    local host = window
    if inkHost ~= nil then
      host = inkHost
      hosted = true
    end
    canvas:Reparent(host, -1)
    parent = host
  end

  if not hosted and not windowPrinted then
    windowPrinted = true
    print("QuickHack: bar on virtual window")
  end

  slots = {}
  local i = 1
  while i <= SLOT_COUNT do
    local x = (i - 1) * STRIDE
    local edges = {}
    local thickness = 2
    local frameX = x + 8
    local frameY = ICON_Y - 2
    local frameW = ICON + 4
    local frameH = ICON + 4
    local fill = inkRectangle.new()
    fill:SetAnchor(inkEAnchor.TopLeft)
    place(fill, frameX, frameY, frameW, frameH)
    fill:SetTintColor(NUMBER_TINT)
    fill:SetOpacity(FILL_OPACITY)
    fill:SetVisible(false)
    fill:Reparent(canvas, -1)
    local edge = 1
    while edge <= 4 do
      local bar = inkRectangle.new()
      bar:SetAnchor(inkEAnchor.TopLeft)
      if edge == 1 then
        place(bar, frameX, frameY, frameW, thickness)
      elseif edge == 2 then
        place(bar, frameX, frameY + frameH - thickness, frameW, thickness)
      elseif edge == 3 then
        place(bar, frameX, frameY, thickness, frameH)
      else
        place(bar, frameX + frameW - thickness, frameY, thickness, frameH)
      end
      bar:SetTintColor(NUMBER_TINT)
      bar:SetOpacity(0.75)
      bar:SetVisible(false)
      bar:Reparent(canvas, -1)
      edges[edge] = bar
      edge = edge + 1
    end

    local ramText = makeText(x, RAM_Y, SLOT_W, 16, 14, NUMBER_TINT, "")
    local number = makeText(x, NUMBER_Y, SLOT_W, 18, 18, NUMBER_TINT, tostring(i))
    local title = makeText(x, TITLE_Y, SLOT_W, 30, 13, NUMBER_TINT, "")
    pcall(function()
      title:SetFitToContent(false)
      title:SetVerticalAlignment(textVerticalAlignment.Top)
    end)
    local okWrap, wrapErr = pcall(function()
      title:SetWrapping(true, SLOT_W)
    end)
    if not okWrap and not wrapPrinted then
      wrapPrinted = true
      print("QuickHack: title wrap failed " .. tostring(wrapErr))
    end
    slots[i] = {
      icon = nil,
      edges = edges,
      fill = fill,
      number = number,
      title = title,
      ramText = ramText,
      iconKey = nil,
      bindLabel = nil,
      index = i,
      x = x,
      fx = nil,
    }
    layoutSlot(slots[i], 0)
    applyBinding(slots[i])
    i = i + 1
  end

  overflow = makeText(756, NUMBER_Y, SLOT_W, 18, 18, NUMBER_TINT, "")
  layoutOverflow()
  built = true
  return true
end

local function bindHud()
  pcall(function()
    local layer = Game.GetInkSystem():GetLayer(CName.new("inkHUDLayer"))
    if layer == nil then
      return
    end
    local ctrl = nil
    pcall(function()
      ctrl = layer:GetGameController()
    end)
    if ctrl == nil then
      return
    end
    inkController = ctrl
    pcall(function()
      inkHost = ctrl:GetRootCompoundWidget()
    end)
  end)
end

-- Do not walk up to the HUD layer root or reparent onto the healthbar or
-- minimap: that disabled the game HUD in build 55. inkSpawner is only a
-- fallback SpawnFromExternal controller; the bar stays on our canvas.
local function hookSpawner(className, method)
  local ok, err = pcall(function()
    ObserveAfter(className, method, function(this)
      if this ~= nil then
        inkSpawner = this
      end
    end)
  end)
  if not ok then
    print("QuickHack: could not hook " .. className .. "." .. method .. ": " .. tostring(err))
  end
end

function Hud.install()
  -- Do not Observe OnInitialize on HUD subclasses: CET errors with
  -- "Function OnInitialize in class ... does not exist" because the
  -- method is defined on a parent.
  hookSpawner("healthbarWidgetGameController", "OnPlayerAttach")
  hookSpawner("gameuiHudHealthbarGameController", "OnPlayerAttach")
  hookSpawner("MinimapContainerController", "OnPlayerAttach")
end

local function teardown()
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
  hosted = false
  layoutKey = nil
end

function Hud.invalidate()
  teardown()
end

function Hud.ensure()
  bindHud()
  if built and canvas ~= nil then
    local alive = pcall(function()
      canvas:GetName()
    end)
    if not alive then
      teardown()
    end
  end
  if built and not hosted and inkController ~= nil and not hostRetry then
    hostRetry = true
    teardown()
  end
  if built then
    return
  end
  local ok, err = pcall(build)
  if ok and built then
    return
  end
  teardown()
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
  local gen = Target.getGeneration()
  pcall(updateLayoutMode, count)
  if count == 0 then
    local i = 1
    while i <= SLOT_COUNT do
      if not (arranging and slots[i].ghost) then
        hideSlot(slots[i])
      end
      i = i + 1
    end
    overflow:SetVisible(false)
    lastGen = gen
    updateGhosts(list)
    canvas:SetVisible(arranging)
    return
  end
  local ramIndex = 1
  while ramIndex <= SLOT_COUNT do
    local command = list[ramIndex]
    if command ~= nil and slots[ramIndex] ~= nil then
      pcall(applyBinding, slots[ramIndex])
      pcall(paintRam, slots[ramIndex], command)
    end
    ramIndex = ramIndex + 1
  end
  if gen ~= lastGen then
    lastGen = gen
    local i = 1
    while i <= SLOT_COUNT do
      local command = list[i]
      if command == nil then
        pcall(hideSlot, slots[i])
      else
        pcall(showSlot, slots[i], command)
      end
      i = i + 1
    end

    if count > SLOT_COUNT then
      pcall(function()
        overflow:SetText("+" .. tostring(count - SLOT_COUNT))
        overflow:SetVisible(true)
      end)
    else
      pcall(function()
        overflow:SetVisible(false)
      end)
    end
  end

  updateGhosts(list)
  canvas:SetVisible(true)
end

function Hud.destroy()
  teardown()
end

function Hud.setScale(scale)
  if type(scale) ~= "number" then
    return
  end
  scale = clamp(scale, MIN_SCALE, MAX_SCALE)
  if built and math.abs(scale - barScale) < 0.0005 then
    return
  end
  barScale = scale
  if built then
    layoutBar()
    lastGen = -1
  end
end

function Hud.canAfford(command)
  local cost = readCost(command)
  if cost == nil then
    return true, nil, nil
  end
  local available, unaffordable = ramState(cost)
  return not unaffordable, available, cost
end

function Hud.feedback(index, ok)
  if not built or type(index) ~= "number" then
    return
  end
  local slot = slots[index]
  if slot == nil or slot.number == nil then
    return
  end
  local visible = false
  pcall(function()
    visible = slot.number:IsVisible()
  end)
  if not visible then
    return
  end
  slot.fx = {
    kind = ok and "ok" or "fail",
    t = 0,
    dur = ok and 0.45 or 0.40,
  }
end

function Hud.tick(dt)
  if not built or dt == nil then
    return
  end
  local i = 1
  while i <= SLOT_COUNT do
    local slot = slots[i]
    if slot ~= nil and slot.fx ~= nil then
      slot.fx.t = slot.fx.t + dt
      if slot.fx.t >= slot.fx.dur then
        layoutSlot(slot, 0)
        slot.fx = nil
      else
        applyFx(slot)
      end
    end
    i = i + 1
  end
end

-- Click-and-drag arranging. CET's overlay owns the mouse while it is open,
-- so an invisible full-screen ImGui window (kept behind the settings window)
-- catches the press, picks the row of frames nearest the cursor, and moves
-- that row's ink widgets by the mouse movement converted to HUD units.
local drag = { row = nil, lastX = 0, lastY = 0 }
local dragPrinted = false
local dragErrorPrinted = false

local function inkScale()
  local ok, w, h = pcall(function()
    return GetDisplayResolution()
  end)
  if not ok or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
    return nil
  end
  local s = h / 2160
  local bottom = h
  if w / h < 16 / 9 then
    s = w / 3840
    bottom = h - (h - 2160 * s) * 0.5
  end
  return s, w, h, bottom
end

-- Screen rectangle of a row's frames (not its titles), so the grab area is
-- exactly the empty frames shown while arranging.
local function rowRect(row, s, w, h)
  local rx, ry = rowOrigin(row)
  local left = w * 0.5 - sc(BAR_W) * s * 0.5 + (rx + sc(8)) * s
  -- Measured in game at 1920x1080: the visible frames sit about 140 HUD units
  -- above where the bottom-anchored layout math puts them.
  local top = (drag.bottom or h) - (128 + 140 + sc(BAR_H)) * s + (ry + sc(ICON_Y - 2)) * s
  local width = (sc((ROW_SIZE - 1) * STRIDE) + sc(ICON + 4)) * s
  return left, top, width, sc(ICON + 4) * s
end

local function pickRow(mx, my, s, w, h)
  -- Each row's grab area is its frame band grown by PICK_PAD HUD units above
  -- and below. When the areas of the two rows overlap, the row whose centre
  -- is nearest wins, so the split falls at the midpoint between them.
  local PICK_PAD = 40
  local best = nil
  local bestDist = nil
  local row = 1
  while row <= 2 do
    local left, top, width, height = rowRect(row, s, w, h)
    local pad = PICK_PAD * s
    if mx >= left - 8 * s and mx <= left + width + 8 * s
      and my >= top - pad and my <= top + height + pad then
      local dist = math.abs(my - (top + height * 0.5))
      if bestDist == nil or dist < bestDist then
        best = row
        bestDist = dist
      end
    end
    row = row + 1
  end
  return best
end

function Hud.drawDrag()
  if ImGui == nil or not built then
    return
  end
  local okCast, isOpen = pcall(function()
    return require("cast").isOverlay() == true
  end)
  if not okCast or not isOpen then
    drag.row = nil
    heldRow = nil
    return
  end
  local s, w, h, bottom = inkScale()
  if s == nil then
    return
  end
  drag.bottom = bottom
  local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
    + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoCollapse + ImGuiWindowFlags.NoSavedSettings
    + ImGuiWindowFlags.NoBackground + ImGuiWindowFlags.NoBringToFrontOnFocus + ImGuiWindowFlags.NoFocusOnAppearing
  ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)
  ImGui.SetNextWindowSize(w, h, ImGuiCond.Always)
  local pushed = pcall(function()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
  end)
  local visible = ImGui.Begin("##QuickHackDrag", flags)
  local okBody, bodyErr = pcall(function()
    if visible == false then
      return
    end
    ImGui.SetCursorPos(0, 0)
    ImGui.InvisibleButton("##QuickHackDragArea", w, h)
    local active = ImGui.IsItemActive() == true
    local mx, my = ImGui.GetMousePos()
    if type(mx) ~= "number" or type(my) ~= "number" then
      return
    end
    if active and drag.row == nil and drag.idle ~= true then
      drag.row = pickRow(mx, my, s, w, h)
      drag.idle = drag.row == nil
      drag.lastX = mx
      drag.lastY = my
      heldRow = drag.row
      if not dragPrinted then
        dragPrinted = true
        local l, t, rw, rh = rowRect(drag.row or 1, s, w, h)
        print(string.format("QuickHack: drag res %dx%d scale %.4f bottom %.0f mouse %.0f,%.0f row %s rect %.0f,%.0f %.0fx%.0f", w, h, s, bottom, mx, my, tostring(drag.row), l, t, rw, rh))
      end
    elseif active and drag.row ~= nil then
      local dx = mx - drag.lastX
      local dy = my - drag.lastY
      if dx ~= 0 or dy ~= 0 then
        drag.lastX = mx
        drag.lastY = my
        local mod = streamMod()
        if mod ~= nil and type(mod.rowXY) == "function" and type(mod.setRowPos) == "function" then
          local rx, ry = mod.rowXY(drag.row)
          mod.setRowPos(drag.row, rx + dx / s, ry + dy / s, false)
        end
      end
    elseif not active then
      if drag.row ~= nil then
        local mod = streamMod()
        if mod ~= nil and type(mod.saveRows) == "function" then
          mod.saveRows()
        end
      end
      drag.row = nil
      drag.idle = false
      heldRow = nil
    end
  end)
  ImGui.End()
  if pushed then
    pcall(function()
      ImGui.PopStyleVar(1)
    end)
  end
  if not okBody and not dragErrorPrinted then
    dragErrorPrinted = true
    print("QuickHack: row drag failed: " .. tostring(bodyErr))
  end
end

return Hud
