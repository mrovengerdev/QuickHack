local Target = {}

local commands = {}
local targetId = nil
local hoveredKey = nil
local hoveredEntity = nil
local generation = 0
local nextFillAt = 0
local fillCount = 0
local fillWindowStart = 0
local seeded = false
local hookPrinted = false
local seenFillErrors = {}

local function entityIdKey(entity)
  if entity == nil then
    return nil
  end
  local ok, key = pcall(function()
    local eid = entity:GetEntityID()
    if eid == nil then
      return nil
    end
    if eid.hash ~= nil and eid.hash ~= 0 then
      return tostring(eid.hash)
    end
    return tostring(eid)
  end)
  if not ok then
    return nil
  end
  return key
end

local function clearDisplay()
  local dirty = targetId ~= nil or #commands > 0
  commands = {}
  targetId = nil
  if dirty then
    generation = generation + 1
  end
end

local function clearAll()
  hoveredKey = nil
  hoveredEntity = nil
  clearDisplay()
end

local function isDefined(obj)
  if obj == nil then
    return false
  end
  local ok, defined = pcall(function()
    return IsDefined(obj)
  end)
  if ok then
    return defined
  end
  return true
end

local function sameEntity(a, b)
  if a == nil or b == nil then
    return false
  end
  if a == b then
    return true
  end
  local left = entityIdKey(a)
  local right = entityIdKey(b)
  return left ~= nil and left == right
end

local function overlayOpen()
  local ok, Cast = pcall(require, "cast")
  if not ok or Cast == nil or Cast.isOverlay == nil then
    return false
  end
  return Cast.isOverlay() == true
end

local function menuOpen()
  local ok, value = pcall(function()
    return Game.GetBlackboardSystem():Get(Game.GetAllBlackboardDefs().UI_System):GetBool(Game.GetAllBlackboardDefs().UI_System.IsInMenu)
  end)
  if not ok then
    return false
  end
  return value == true
end

local function hasCyberdeck(player)
  local stats = Game.GetStatsSystem()
  local ok, value = pcall(function()
    return stats:GetStatValue(player:GetEntityID(), gamedataStatType.HasCyberdeck)
  end)
  if not ok then
    ok, value = pcall(function()
      return stats:GetStatValue(player:GetEntityID(), "HasCyberdeck")
    end)
  end
  if not ok or value == nil or value <= 0 then
    return false
  end
  return true
end

local function hidden()
  local player = Game.GetPlayer()
  if not isDefined(player) then
    return true
  end
  local sceneOk, blocked = pcall(function()
    return QuickhackModule.IsQuickhackBlockedByScene(player)
  end)
  if overlayOpen() or menuOpen() or (sceneOk and blocked) or not hasCyberdeck(player) then
    return true
  end
  return false
end

local function copyCommands(src)
  local list = {}
  if src == nil then
    return list
  end
  local function push(entry)
    if entry and not entry.m_noQuickhackData then
      list[#list + 1] = entry
    end
  end
  local okLen, n = pcall(function()
    return #src
  end)
  if not okLen or type(n) ~= "number" then
    n = 0
  end
  if n == 0 then
    local okZero, head = pcall(function()
      return src[0]
    end)
    if okZero and head ~= nil then
      local i = 0
      while i < 64 do
        local okItem, entry = pcall(function()
          return src[i]
        end)
        if not okItem or entry == nil then
          break
        end
        push(entry)
        i = i + 1
      end
      return list
    end
    local okOne, first = pcall(function()
      return src[1]
    end)
    if okOne and first ~= nil then
      local i = 1
      while i <= 64 do
        local okItem, entry = pcall(function()
          return src[i]
        end)
        if not okItem or entry == nil then
          break
        end
        push(entry)
        i = i + 1
      end
    end
    return list
  end
  local i = 1
  while i <= n do
    local okItem, entry = pcall(function()
      return src[i]
    end)
    if okItem then
      push(entry)
    end
    i = i + 1
  end
  return list
end

local function methodMissing(err)
  local text = tostring(err)
  return string.find(text, "QuickHack_FillCommands", 1, true) ~= nil
    or string.find(text, "attempt to call", 1, true) ~= nil
end

local function ownerOf(entity)
  local ok, owner = pcall(function()
    return entity:GetVehicle()
  end)
  if ok and isDefined(owner) then
    return owner
  end
  ok, owner = pcall(function()
    return entity:GetOwner()
  end)
  if ok and isDefined(owner) then
    return owner
  end
  return nil
end

local function kindOf(entity)
  if not isDefined(entity) or sameEntity(entity, Game.GetPlayer()) then
    return nil
  end
  local okDev, isDev = pcall(function()
    return entity:IsDevice()
  end)
  if okDev and isDev == true then
    return "device"
  end
  local okVeh, isVeh = pcall(function()
    return entity:IsVehicle()
  end)
  if okVeh and isVeh == true then
    return "vehicle"
  end
  local okPup, isPup = pcall(function()
    return entity:IsPuppet()
  end)
  if okPup and isPup == true then
    return "puppet"
  end
  return "other"
end

local function resolveHackable(entity)
  local kind = kindOf(entity)
  if kind == "device" or kind == "vehicle" or kind == "puppet" then
    return entity
  end
  local owner = ownerOf(entity)
  if kindOf(owner) == "device" or kindOf(owner) == "vehicle" then
    return owner
  end
  return entity
end
local function fillList(entity)
  local ok, filled = pcall(function()
    return entity:QuickHack_FillCommands()
  end)
  fillCount = fillCount + 1
  if not ok then
    local msg = tostring(filled)
    if not seenFillErrors[msg] then
      seenFillErrors[msg] = true
      print("QuickHack: QuickHack_FillCommands failed: " .. msg)
    end
    return nil, msg
  end
  local list = copyCommands(filled)
  if #list == 0 then
    return nil, "empty"
  end
  return list, nil
end

local function fillNow(entity)
  local list = fillList(entity)
  nextFillAt = os.clock() + 0.25
  if list == nil then
    commands = {}
    generation = generation + 1
    return
  end
  commands = list
  targetId = entityIdKey(entity)
  generation = generation + 1
end

local function accept(entity)
  local player = Game.GetPlayer()
  if not isDefined(entity) or sameEntity(entity, player) then
    return false
  end
  local ok, can = pcall(function()
    return entity:CanRevealRemoteActionsWheel()
  end)
  if ok and can == true then
    return true
  end
  local okDev, isDev = pcall(function()
    return entity:IsDevice()
  end)
  if okDev and isDev == true then
    return true
  end
  local okVeh, isVeh = pcall(function()
    return entity:IsVehicle()
  end)
  return okVeh and isVeh == true
end

local function findEntity(eid)
  if eid == nil then
    return nil
  end
  local ok, entity = pcall(function()
    return Game.FindEntityByID(eid)
  end)
  if ok and isDefined(entity) then
    return entity
  end
  return nil
end

local function asEntityID(value)
  if value == nil then
    return nil
  end
  if value.hash ~= nil then
    return value
  end
  if value.playerTarget ~= nil and value.playerTarget.hash ~= nil then
    return value.playerTarget
  end
  local ok, unwrapped = pcall(function()
    return FromVariant(value)
  end)
  if ok and unwrapped ~= nil and unwrapped.hash ~= nil then
    return unwrapped
  end
  return nil
end


local function showEntity(entity, fallbackKey)
  local list = fillList(entity)
  if list == nil then
    return false
  end
  hoveredKey = entityIdKey(entity) or fallbackKey
  hoveredEntity = entity
  targetId = hoveredKey
  commands = list
  generation = generation + 1
  nextFillAt = os.clock() + 0.25
  return true
end

function Target.onHoverId(value)
  if value == nil then
    clearAll()
    return
  end
  local eid = asEntityID(value)
  if eid == nil then
    return
  end
  if eid.hash == nil or eid.hash == 0 then
    clearAll()
    return
  end
  local key = tostring(eid.hash)
  if key == hoveredKey and isDefined(hoveredEntity) and #commands > 0 then
    return
  end
  local entity = resolveHackable(findEntity(eid))
  if not isDefined(entity) or not accept(entity) then
    clearAll()
    return
  end
  if not showEntity(entity, key) then
    clearAll()
  end
end

function Target.install()
  local hooked = false
  local okObserve, errObserve = pcall(function()
    Observe("HUDManager", "OnNemaplateChangedRequest", function(self, evt)
      Target.onHoverId(evt)
    end)
    hooked = true
  end)
  local okListen = pcall(function()
    local defs = Game.GetAllBlackboardDefs().UI_NameplateData
    local board = Game.GetBlackboardSystem():Get(defs)
    board:RegisterListenerVariant(defs.EntityID, function(value)
      Target.onHoverId(value)
    end)
    hooked = true
  end)
  if not hooked and not hookPrinted then
    hookPrinted = true
    local err = okObserve and "RegisterListenerVariant failed" or tostring(errObserve)
    if not okListen and not okObserve then
      err = tostring(errObserve)
    end
    print("QuickHack: nameplate hook failed: " .. err)
  end
end
local shownPrinted = false
local awayPrinted = false
local rayMissing = false

local function isObject(entity)
  local kind = kindOf(entity)
  return kind == "device" or kind == "vehicle"
end

local function facingDot(entity)
  local player = Game.GetPlayer()
  local ok, dot = pcall(function()
    return QuickHackAim.Facing(player, entity)
  end)
  if not ok or type(dot) ~= "number" or dot <= -1.5 then
    if not rayMissing then
      rayMissing = true
      print("QuickHack: crosshair ray missing")
    end
    return nil
  end
  return dot
end

local function showObject(entity)
  entity = resolveHackable(entity)
  if not isObject(entity) or not accept(entity) then
    return false
  end
  local key = entityIdKey(entity)
  if key == hoveredKey and isDefined(hoveredEntity) and #commands > 0 then
    return true
  end
  return showEntity(entity, key)
end

local function queryLookAt()
  local player = Game.GetPlayer()
  if not isDefined(player) then
    return nil
  end
  local ok, entity = pcall(function()
    return QuickHackAim.LookAt(player)
  end)
  if not ok then
    return nil
  end
  return resolveHackable(entity)
end

local function queryCrosshair()
  local player = Game.GetPlayer()
  if not isDefined(player) then
    return nil
  end
  local ok, entity = pcall(function()
    return QuickHackAim.Crosshair(player)
  end)
  if not ok then
    return nil
  end
  return resolveHackable(entity)
end

local function pickObject()
  local looked = queryLookAt()
  local cross = queryCrosshair()
  local lookDot = isObject(looked) and facingDot(looked) or nil
  local crossDot = isObject(cross) and facingDot(cross) or nil
  if isObject(looked) and (lookDot == nil or lookDot >= 0) then
    return looked, "look-at", lookDot
  end
  if isObject(cross) and (crossDot == nil or crossDot >= 0) then
    return cross, "crosshair", crossDot
  end
  if lookDot ~= nil and lookDot < 0 then
    return nil, "away", lookDot
  end
  if crossDot ~= nil and crossDot < 0 then
    return nil, "away", crossDot
  end
  return nil, nil, nil
end

function Target.tick(dt)
  local now = os.clock()
  if fillWindowStart == 0 then
    fillWindowStart = now
  end
  if now - fillWindowStart >= 1.0 then
    print(string.format("QuickHack fills/s=%d", fillCount))
    fillCount = 0
    fillWindowStart = now
  end

  local hoverOk, hoverValue = pcall(function()
    local function definedId(eid)
      return eid ~= nil and eid.hash ~= nil and eid.hash ~= 0
    end
    local function readId(board, id)
      local ok, eid = pcall(function()
        return board:GetEntityID(id)
      end)
      if ok and definedId(eid) then
        return eid
      end
      local variantOk, variant = pcall(function()
        return board:GetVariant(id)
      end)
      if variantOk then
        local unwrapped = asEntityID(variant)
        if definedId(unwrapped) then
          return unwrapped
        end
      end
      return nil
    end

    local nameDefs = Game.GetAllBlackboardDefs().UI_NameplateData
    local named = readId(Game.GetBlackboardSystem():Get(nameDefs), nameDefs.EntityID)
    if definedId(named) then
      local namedEntity = resolveHackable(findEntity(named))
      if accept(namedEntity) then
        return named
      end
    end
    local lookDefs = Game.GetAllBlackboardDefs().UI_TargetingInfo
    local looked = readId(Game.GetBlackboardSystem():Get(lookDefs), lookDefs.CurrentVisibleTarget)
    if definedId(looked) then
      local lookedEntity = resolveHackable(findEntity(looked))
      if accept(lookedEntity) then
        return looked
      end
    end
    return nil
  end)
  local lookEntity = nil
  if hoverOk then
    lookEntity = resolveHackable(findEntity(asEntityID(hoverValue)))
  end
  if kindOf(lookEntity) == "puppet" and accept(lookEntity) then
    Target.onHoverId(hoverValue)
  else
    local object, source, dot = pickObject()
    if object ~= nil and showObject(object) then
      if not shownPrinted then
        shownPrinted = true
        print(string.format("QuickHack: object via %s dot=%s", source, dot == nil and "none" or string.format("%.2f", dot)))
      end
    elseif isObject(hoveredEntity) then
      if source == "away" and not awayPrinted then
        awayPrinted = true
        print(string.format("QuickHack: look-away dot=%.2f", dot))
      end
      clearAll()
    elseif hoverOk then
      Target.onHoverId(nil)
    end
  end

  if hidden() then
    nextFillAt = 0
    clearDisplay()
    return
  end

  if not isDefined(hoveredEntity) then
    return
  end
  if now >= nextFillAt then
    fillNow(hoveredEntity)
  end
end

function Target.onCommands(value)
  if value == nil or value.lookAtObject == nil then
    return
  end
  if not accept(value.lookAtObject) then
    return
  end
  local key = entityIdKey(value.lookAtObject)
  if key == nil then
    return
  end
  if hoveredKey == nil or key ~= hoveredKey then
    return
  end
  targetId = key
  if value.shouldReveal == false then
    commands = {}
    generation = generation + 1
    return
  end
  commands = copyCommands(value.commands)
  generation = generation + 1
  nextFillAt = os.clock() + 0.25
end

function Target.getCommands()
  return commands
end

function Target.getTargetId()
  return targetId
end

function Target.getGeneration()
  return generation
end

return Target
