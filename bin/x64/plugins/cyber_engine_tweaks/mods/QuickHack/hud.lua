local Target = require("target")

local Hud = {}

local SLOT_COUNT = 9
local ICON = 56
local ICON_Y = 18
local NUMBER_Y = 76
local TITLE_Y = 96
local RAM_Y = 0
local SLOT_W = 76
local STRIDE = 84
local BAR_W = 748
local BAR_H = 114
local FILL_OPACITY = 0.15
local MAIN_COLORS = "base\\gameplay\\gui\\common\\main_colors.inkstyle"
local NUMBER_TINT = nil
local RED = nil

local canvas = nil
local parent = nil
local slots = {}
local overflow = nil
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

local function bindingFontSize(label)
  return 18
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
    slot.number:SetFontSize(18)
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
    return QuickHackIcons.LibraryReason(inkController or inkSpawner, canvas, command, slot.index, slot.x + 10, ICON_Y, ICON)
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

local function rawPool(player, pool)
  if player == nil then
    return nil
  end
  local ok, value = pcall(function()
    return Game.GetStatPoolsSystem():GetStatPoolValue(player:GetEntityID(), pool, false)
  end)
  if ok and type(value) == "number" then
    return value
  end
  return nil
end

local function hasOverclock(player)
  if player == nil then
    return false
  end
  local ok, active = pcall(function()
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
  local health = rawPool(player, gamedataStatPoolType.Health)
  if not okRate or type(rate) ~= "number" or health == nil then
    return false
  end
  return health - rate * shortfall > 0
end

local function canAfford(command)
  local cost = readCost(command)
  if cost == nil then
    return false
  end
  if cost <= 0 then
    return true
  end
  local available = availableRam()
  local memory = available
  if memory == nil then
    memory = rawPool(Game.GetPlayer(), gamedataStatPoolType.Memory)
  end
  if memory == nil then
    return true
  end
  if memory >= cost then
    return true
  end
  return canPayWithHealth(Game.GetPlayer(), cost, memory)
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
  local okAff, can = pcall(canAfford, command)
  if okAff and can == true then
    unaffordable = false
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
  if slot.icon == nil and canvas ~= nil and slot.index ~= nil then
    pcall(function()
      slot.icon = canvas:GetWidget(CName.new("qhicon" .. tostring(slot.index)))
    end)
  end
  if slot.icon ~= nil then
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

local function showSlot(slot, command)
  local opacity = command.m_isLocked and 0.4 or 1.0
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
      return QuickHackIcons.MakeBar(inkController, BAR_W, BAR_H, 128.0)
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
    canvas:SetSize(Vector2.new({ X = BAR_W, Y = BAR_H }))
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
    }
    applyBinding(slots[i])
    i = i + 1
  end

  overflow = makeText(756, NUMBER_Y, SLOT_W, 18, 18, NUMBER_TINT, "")
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
  if count == 0 then
    local i = 1
    while i <= SLOT_COUNT do
      hideSlot(slots[i])
      i = i + 1
    end
    overflow:SetVisible(false)
    canvas:SetVisible(false)
    lastGen = gen
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

    if count > 9 then
      pcall(function()
        overflow:SetText("+" .. tostring(count - 9))
        overflow:SetVisible(true)
      end)
    else
      pcall(function()
        overflow:SetVisible(false)
      end)
    end
  end

  canvas:SetVisible(true)
end

function Hud.destroy()
  teardown()
end

return Hud
