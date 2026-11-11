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
local inkController = nil
local inkHost = nil
local hosted = false
local hostPrinted = false
local hostRetry = false
local barHostPrinted = false
local spawnPrinted = false
local libPrinted = false
local spawnFailPrinted = false
local inkSpawner = nil
local spawnerPrinted = false

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
  if command == nil then
    return ""
  end
  local okReds, reds = pcall(function()
    return QuickHackIcons.TitleOf(command)
  end)
  if okReds and reds ~= nil then
    local text = tostring(reds)
    if text ~= "" and string.sub(text, 1, 8) ~= "userdata" then
      if string.sub(text, 1, 7) == "LocKey#" then
        local ok, localized = pcall(function()
          return GetLocalizedText(text)
        end)
        if ok and localized ~= nil and tostring(localized) ~= "" then
          return tostring(localized)
        end
      else
        return text
      end
    end
  end
  local title = command.m_title
  if title == nil or tostring(title) == "" then
    title = command.title
  end
  if title == nil or tostring(title) == "" then
    title = command.m_titleAlternative
  end
  if title == nil or tostring(title) == "" then
    title = command.titleAlternative
  end
  local text = title == nil and "" or tostring(title)
  if string.sub(text, 1, 8) == "userdata" then
    text = ""
  end
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
  if icon == nil or path == nil or path == "" or part == nil or part == "" or part == "None" then
    return false
  end
  local ok = pcall(function()
    pcall(function()
      icon:SetStyle(ResRef.FromString("base\\gameplay\\gui\\common\\main_colors.inkstyle"))
    end)
    icon:SetAtlasResource(ResRef.FromString(path))
    icon:SetTexturePart(CName.new(part))
    icon:SetFitToContent(false)
    icon:SetSize(Vector2.new({ X = size, Y = size }))
    icon:SetVisible(true)
    icon:SetTintColor(WHITE)
    icon:SetOpacity(1.0)
  end)
  if not ok then
    ok = pcall(function()
      icon:SetAtlasResource(path)
      icon:SetTexturePart(part)
      icon:SetFitToContent(false)
      icon:SetSize(Vector2.new({ X = size, Y = size }))
      icon:SetVisible(true)
    end)
  end
  return ok
end

local function applyIcon(slot, command)
  if command == nil or command.m_icon == nil or canvas == nil then
    return
  end
  local key = tostring(command.m_icon)
  if key == slot.iconKey and slot.icon ~= nil then
    return
  end
  local painted = false
  local libCtrl = inkController or inkSpawner
  local okLib, libReason = pcall(function()
    return QuickHackIcons.LibraryReason(libCtrl, canvas, command, slot.index, slot.x + 10, ICON_Y, ICON)
  end)
  if not okLib then
    libReason = "error " .. tostring(libReason)
  end
  if libReason == "ok" then
    painted = true
  end
  if not libPrinted then
    libPrinted = true
    print("QuickHack: slot library spawn " .. tostring(libReason))
  end
  if not painted then
    local okCW, redsCW = pcall(function()
      return QuickHackIcons.SpawnCodewareSlot(canvas, command, slot.index, slot.x + 10, ICON_Y, ICON, inkController or inkSpawner)
    end)
    if okCW and redsCW == true then
      painted = true
      if not spawnPrinted then
        spawnPrinted = true
        print("QuickHack: icon spawned with Codeware component")
      end
    elseif okCW ~= true and not spawnPrinted then
      spawnPrinted = true
      print("QuickHack: Codeware icon spawn error: " .. tostring(redsCW))
    end
  end
  local spawner = inkSpawner or inkController
  if not painted and spawner ~= nil then
    local okSpawn, redsSpawn = pcall(function()
      return QuickHackIcons.SpawnSlot(spawner, canvas, command, slot.index, slot.x + 10, ICON_Y, ICON)
    end)
    if okSpawn and redsSpawn == true then
      painted = true
      if not spawnPrinted then
        spawnPrinted = true
        print("QuickHack: icon spawned from HUD library")
      end
    elseif okSpawn ~= true and not spawnPrinted then
      spawnPrinted = true
      print("QuickHack: icon spawn error: " .. tostring(redsSpawn))
    elseif okSpawn == true and redsSpawn ~= true and not spawnFailPrinted then
      spawnFailPrinted = true
      if inkSpawner == nil then
        print("QuickHack: icon spawn returned false (no healthbar spawner yet)")
      else
        print("QuickHack: icon spawn returned false")
      end
    end
  end
  local okPaint, redsPaint
  if not painted then
    okPaint, redsPaint = pcall(function()
      return QuickHackIcons.PaintSlot(canvas, command, slot.index, slot.x + 10, ICON_Y, ICON, inkSpawner or inkController)
    end)
  end
  if (painted) or (okPaint and redsPaint == true) then
    painted = true
    pcall(function()
      local widget = canvas:GetWidget(CName.new("qhicon" .. tostring(slot.index)))
      if widget == nil then
        widget = canvas:GetWidget(CName.new("qhspawn" .. tostring(slot.index)))
      end
      if widget ~= nil then
        slot.icon = widget
        if WHITE ~= nil then
          slot.icon:SetTintColor(WHITE)
        end
        slot.icon:SetOpacity(1.0)
        slot.icon:SetVisible(true)
      end
    end)
  end
  if not painted and slot.placeholder ~= nil then
    local okOld, redsOld = pcall(function()
      return QuickHackIcons.PaintFor(slot.placeholder, command, inkSpawner or inkController or Game.GetPlayer())
    end)
    if okOld and redsOld == true then
      painted = true
    end
    local path, part = iconStrings(command)
    if (path == nil or path == "") and part ~= nil and part ~= "" and part ~= "None" then
      path = "base\\gameplay\\gui\\common\\icons\\quickhacks_icons.inkatlas"
    end
    if applyAtlas(slot.placeholder, path, part, ICON) then
      painted = true
    end
    if painted then
      slot.icon = slot.placeholder
    end
  end
  local path, part = iconStrings(command)
  local okDbg, dbg = pcall(function()
    return QuickHackIcons.DebugOf(command)
  end)
  if not okDbg then
    dbg = tostring(dbg)
  end
  if painted then
    slot.iconKey = key
    if not partPrinted then
      partPrinted = true
      local host = "no-host"
      if hosted then
        host = "hosted"
      end
      print("QuickHack: icon painted " .. tostring(path) .. " " .. tostring(part) .. " " .. tostring(dbg) .. " " .. host)
    end
    return
  end
  if not imageErrorPrinted then
    imageErrorPrinted = true
    print("QuickHack: icon paint failed " .. tostring(path) .. " " .. tostring(part) .. " " .. tostring(dbg))
  end
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
  local edgeColor = unaffordable and RED or NUMBER_TINT
  if slot.edges ~= nil then
    local edge = 1
    while slot.edges[edge] ~= nil do
      slot.edges[edge]:SetTintColor(edgeColor)
      slot.edges[edge]:SetOpacity(0.75)
      slot.edges[edge]:SetVisible(true)
      edge = edge + 1
    end
  end
end

local function hideSlot(slot)
  if slot.edges ~= nil then
    local edge = 1
    while slot.edges[edge] ~= nil do
      slot.edges[edge]:SetVisible(false)
      edge = edge + 1
    end
  end
  if slot.placeholder ~= nil then
    slot.placeholder:SetVisible(false)
  end
  if slot.icon ~= nil then
    slot.icon:SetVisible(false)
  end
  if slot.spawned ~= nil then
    pcall(function()
      slot.spawned:SetVisible(false)
    end)
    slot.spawned = nil
  end
  if slot.slotCanvas ~= nil then
    pcall(function()
      slot.slotCanvas:SetVisible(false)
    end)
    slot.slotCanvas = nil
  end
  if canvas ~= nil and slot.index ~= nil then
    pcall(function()
      local names = { "qhslot", "qhspawn", "qhicon" }
      local n = 1
      while names[n] ~= nil do
        local old = canvas:GetWidget(CName.new(names[n] .. tostring(slot.index)))
        if old ~= nil and old ~= slot.placeholder then
          canvas:RemoveChild(old)
        end
        n = n + 1
      end
    end)
  end
  slot.icon = slot.placeholder
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
  if slot.edges ~= nil then
    local edge = 1
    while slot.edges[edge] ~= nil do
      slot.edges[edge]:SetOpacity(0.75)
      slot.edges[edge]:SetVisible(true)
      edge = edge + 1
    end
  end
  applyIcon(slot, command)
  if slot.iconKey == nil then
    if slot.placeholder ~= nil then
      slot.placeholder:SetVisible(false)
    end
    if slot.icon ~= nil and slot.icon ~= slot.placeholder then
      pcall(function()
        slot.icon:SetVisible(false)
      end)
    end
  else
    if slot.icon ~= nil then
      pcall(function()
        slot.icon:SetOpacity(opacity)
        slot.icon:SetVisible(true)
      end)
    end
    if slot.placeholder ~= nil and slot.placeholder ~= slot.icon then
      slot.placeholder:SetVisible(false)
    end
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
  WHITE = HDRColor.new({ Red = 1.0, Green = 1.0, Blue = 1.0, Alpha = 1.0 })
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

  if not barHostPrinted then
    barHostPrinted = true
    if hosted then
      print("QuickHack: bar hosted on HUD")
    else
      print("QuickHack: bar on virtual window")
    end
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

    local icon = inkImage.new()
    icon:SetName(CName.new("qhicon" .. tostring(i)))
    icon:SetAnchor(inkEAnchor.TopLeft)
    place(icon, x + 10, ICON_Y, ICON, ICON)
    icon:SetFitToContent(false)
    icon:SetTintColor(WHITE)
    icon:SetVisible(false)
    pcall(function()
      icon:SetActiveTextureType(inkTextureType.StaticTexture)
    end)
    icon:Reparent(canvas, -1)

    local ramText = makeText(x, RAM_Y, SLOT_W, 16, 14, NUMBER_TINT, "")
    local number = makeText(x, NUMBER_Y, SLOT_W, 18, 18, NUMBER_TINT, tostring(i))
    local title = makeText(x, TITLE_Y, SLOT_W, 14, 13, WHITE, "")
    slots[i] = {
      placeholder = icon,
      icon = icon,
      edges = edges,
      number = number,
      title = title,
      ramText = ramText,
      iconKey = nil,
      index = i,
      x = x,
    }
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
    if not hostPrinted then
      hostPrinted = true
      local name = ""
      pcall(function()
        name = NameToString(ctrl:GetClassName())
      end)
      if name == "" then
        name = tostring(ctrl)
      end
      print("QuickHack: HUD host bound " .. name)
    end
  end)
end

-- Do not walk up to the HUD layer root or reparent onto the healthbar or
-- minimap: that disabled the game HUD in build 55. inkSpawner is only
-- the SpawnFromExternal controller; the bar stays on our canvas.
local function captureSpawner(this)
  if this == nil then
    return
  end
  inkSpawner = this
  if not spawnerPrinted then
    spawnerPrinted = true
    local name = ""
    pcall(function()
      name = NameToString(this:GetClassName())
    end)
    if name == "" then
      name = tostring(this)
    end
    print("QuickHack: icon spawner bound " .. name)
  end
end

local function hookSpawner(className, method)
  local ok, err = pcall(function()
    ObserveAfter(className, method, captureSpawner)
  end)
  if not ok then
    print("QuickHack: could not hook " .. className .. "." .. method .. ": " .. tostring(err))
  end
end

function Hud.install()
  -- Do not Observe OnInitialize on HUD subclasses: CET errors with
  -- "Function OnInitialize in class ... does not exist" because the
  -- method is defined on a parent. Hook OnPlayerAttach on controllers
  -- whose widget libraries can spawn vanilla icon items.
  hookSpawner("healthbarWidgetGameController", "OnPlayerAttach")
  hookSpawner("gameuiHudHealthbarGameController", "OnPlayerAttach")
  hookSpawner("MinimapContainerController", "OnPlayerAttach")
end

function Hud.invalidate()
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

function Hud.ensure()
  bindHud()
  if built and canvas ~= nil then
    local alive = pcall(function()
      canvas:GetName()
    end)
    if not alive then
      Hud.invalidate()
    end
  end
  if built and not hosted and inkController ~= nil and not hostRetry then
    hostRetry = true
    Hud.invalidate()
  end
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
