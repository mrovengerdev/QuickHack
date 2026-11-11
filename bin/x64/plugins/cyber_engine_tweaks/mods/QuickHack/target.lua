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


local HOVER_DEG = 2.0

local function lookAtObject()
  local player = Game.GetPlayer()
  if not isDefined(player) then
    return nil
  end
  local function fromLook(entity)
    if isDefined(entity) then
      return resolveHackable(entity)
    end
    return nil
  end
  local okSys, targeting = pcall(function()
    return Game.GetTargetingSystem()
  end)
  if okSys and targeting ~= nil then
    local okVis, visible = pcall(function()
      return targeting:GetLookAtObject(player, true, true)
    end)
    local found = fromLook(okVis and visible or nil)
    if found ~= nil then
      return found
    end
    local okAny, any = pcall(function()
      return targeting:GetLookAtObject(player, true, false)
    end)
    found = fromLook(okAny and any or nil)
    if found ~= nil then
      return found
    end
  end
  local okWrap, wrapped = pcall(function()
    return QuickHackAim.LookAt(player)
  end)
  return fromLook(okWrap and wrapped or nil)
end

local function closestObject()
  local player = Game.GetPlayer()
  if not isDefined(player) then
    return nil, 999
  end
  local okEntity, entity = pcall(function()
    return QuickHackCrosshair.Closest(player)
  end)
  local okAngle, angle = pcall(function()
    return QuickHackCrosshair.ClosestAngle(player)
  end)
  if not okAngle or type(angle) ~= "number" then
    angle = 999
  end
  if not okEntity or not isDefined(entity) then
    return nil, angle
  end
  return resolveHackable(entity), angle
end

local function hoveredNow()
  local looked = lookAtObject()
  if isDefined(looked) then
    return looked
  end
  local cross, angle = closestObject()
  if isDefined(cross) and type(angle) == "number" and angle <= HOVER_DEG then
    return cross
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

local function acquire(entity)
  if not isDefined(entity) or sameEntity(entity, Game.GetPlayer()) or not accept(entity) then
    if hoveredKey ~= nil or #commands > 0 then
      clearAll()
    end
    return false
  end
  local key = entityIdKey(entity)
  if key == hoveredKey and isDefined(hoveredEntity) and #commands > 0 then
    return true
  end
  if showEntity(entity, key) then
    return true
  end
  clearAll()
  return false
end

function Target.onHoverId(value)
  acquire(hoveredNow())
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

  if hidden() then
    nextFillAt = 0
    clearDisplay()
    return
  end

  local ok, armed = pcall(function()
    return acquire(hoveredNow())
  end)
  if not ok then
    local msg = tostring(armed)
    if not seenFillErrors[msg] then
      seenFillErrors[msg] = true
      print("QuickHack: acquire failed: " .. msg)
    end
    return
  end
  if not armed then
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
