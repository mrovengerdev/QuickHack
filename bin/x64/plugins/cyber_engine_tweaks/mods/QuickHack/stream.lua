local Stream = {}

local LINES = 14
local LINE_H = 22
local LEFT = 36
local TOP = 150
local WIDTH = 640
local HACK_FALLBACK = 0.50
local SCROLL_PX_PER_SEC = 46
local CFG = "bin/x64/plugins/cyber_engine_tweaks/mods/QuickHack/stream.cfg"

local color = { r = 0.3686, g = 0.9647, b = 1.1888 }
local opacity = 0.82

local canvas = nil
local parent = nil
local rows = {}
local jobs = {}
local active = nil

local function clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

local function tint()
  return HDRColor.new({
    Red = color.r,
    Green = color.g,
    Blue = color.b,
    Alpha = opacity,
  })
end

local function loadCfg()
  local file = io.open(CFG, "r")
  if file == nil then
    return
  end
  local text = file:read("*a")
  file:close()
  local r, g, b, a = string.match(text or "", "([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
  if r == nil then
    return
  end
  color.r = clamp(tonumber(r) or color.r, 0, 1.5)
  color.g = clamp(tonumber(g) or color.g, 0, 1.5)
  color.b = clamp(tonumber(b) or color.b, 0, 1.5)
  opacity = clamp(tonumber(a) or opacity, 0.15, 1)
end

local function saveCfg()
  local file = io.open(CFG, "w")
  if file == nil then
    return
  end
  file:write(string.format("%.4f %.4f %.4f %.4f\n", color.r, color.g, color.b, opacity))
  file:close()
end

local function applyStyle()
  local paint = tint()
  local i = 1
  while i <= LINES do
    local row = rows[i]
    if row ~= nil then
      row:SetTintColor(paint)
      row:SetOpacity(opacity)
    end
    i = i + 1
  end
end

local function titleOf(command)
  local title = command.m_title
  if title == nil or tostring(title) == "" then
    title = command.m_titleAlternative
  end
  local text = title == nil and "quickhack" or tostring(title)
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

local function actionName(command)
  if command.m_action == nil then
    return ""
  end
  local ok, name = pcall(function()
    return command.m_action:GetActionID()
  end)
  if ok and name ~= nil then
    return string.lower(tostring(name))
  end
  return ""
end

local function octet()
  return math.random(1, 254)
end

local function randomIp()
  return string.format("10.%d.%d.%d", octet(), octet(), octet())
end

local function addr()
  return string.format("0x%08X", math.random(0, 0x7FFFFFFF))
end

local function pingLines(count)
  local ip = randomIp()
  local lines = {
    "> ping " .. ip,
    "PING " .. ip .. " (" .. ip .. "): 56 data bytes",
  }
  local i = 1
  while i <= count do
    local time = 8 + math.random() * 18
    lines[#lines + 1] = string.format("64 bytes from %s: icmp_seq=%d ttl=%d time=%.1f ms", ip, i, 48 + (i % 9), time)
    i = i + 1
  end
  lines[#lines + 1] = "> nslookup " .. ip
  lines[#lines + 1] = "Name:    subnet-node"
  lines[#lines + 1] = "Address: " .. ip
  lines[#lines + 1] = string.format("--- %d packets transmitted, %d received, 0%% packet loss", count, count)
  return lines
end

local function overheatLines(title, target)
  return {
    "> ddos --target " .. target .. " --vector heat",
    "opening 4096 sockets",
    "syn flood ................ ok",
    "connection table overflow",
    "thermal governor bypassed",
    "core temp 41C -> 118C",
    "coolant_loop killed",
    "> " .. title .. " committed",
  }
end

local function handshakeLines(title)
  local lines = {
    "> exec " .. title,
    "open session",
    "inject " .. title,
  }
  local i = 1
  while i <= 6 do
    lines[#lines + 1] = addr() .. " x " .. addr()
    i = i + 1
  end
  lines[#lines + 1] = "handshake ................ ok"
  lines[#lines + 1] = "write payload"
  lines[#lines + 1] = "> " .. title .. " committed"
  return lines
end

local function scriptFor(command)
  local title = titleOf(command)
  local action = actionName(command)
  local folded = string.lower(title)
  local target = "node"
  if command.m_actionOwnerName ~= nil and tostring(command.m_actionOwnerName) ~= "" then
    target = tostring(command.m_actionOwnerName)
  end
  if string.find(action, "ping", 1, true) or string.find(folded, "ping", 1, true) then
    return pingLines(10)
  end
  if string.find(action, "overheat", 1, true) or string.find(folded, "overheat", 1, true) then
    return overheatLines(title, target)
  end
  return handshakeLines(title)
end

local function hackSeconds(command)
  if command ~= nil and command.m_action ~= nil then
    local ok, time = pcall(function()
      return command.m_action:GetActivationTime()
    end)
    if ok and type(time) == "number" and time >= 0.15 and time <= 8 then
      return time
    end
  end
  return HACK_FALLBACK
end

local function ensure()
  if canvas ~= nil then
    local alive = pcall(function()
      canvas:GetName()
    end)
    if alive then
      return true
    end
    canvas = nil
    rows = {}
  end
  local layer = Game.GetInkSystem():GetLayer(CName.new("inkHUDLayer"))
  if layer == nil then
    return false
  end
  local window = layer:GetVirtualWindow()
  if window == nil then
    return false
  end
  canvas = inkCanvas.new()
  canvas:SetName(CName.new("quickhack_stream"))
  canvas:SetAnchor(inkEAnchor.TopLeft)
  canvas:SetAnchorPoint(Vector2.new({ X = 0.0, Y = 0.0 }))
  canvas:SetMargin(inkMargin.new({ left = LEFT, top = TOP, right = 0.0, bottom = 0.0 }))
  canvas:SetSize(Vector2.new({ X = WIDTH, Y = LINES * LINE_H }))
  canvas:SetVisible(true)
  canvas:Reparent(window, -1)
  parent = window
  rows = {}
  local i = 1
  while i <= LINES do
    local label = inkText.new()
    label:SetAnchor(inkEAnchor.TopLeft)
    label:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
    label:SetFontStyle(CName.new("Regular"))
    label:SetFontSize(16)
    label:SetTintColor(tint())
    label:SetOpacity(opacity)
    label:SetVisible(false)
    label:SetText("")
    label:Reparent(canvas, -1)
    rows[i] = label
    i = i + 1
  end
  return true
end

local queue = {}

local function measure(lines)
  local total = 0
  local i = 1
  while i <= #lines do
    total = total + #lines[i]
    i = i + 1
  end
  if total < 1 then
    total = 1
  end
  return total
end

local function departJobs()
  local i = 1
  while i <= #jobs do
    jobs[i].depart = true
    i = i + 1
  end
end

function Stream.push(command)
  if command == nil then
    return
  end
  local lines = scriptFor(command)
  local seconds = hackSeconds(command)
  departJobs()
  queue = {}
  active = {
    lines = lines,
    index = 1,
    rate = measure(lines) / seconds,
    speed = ((#lines + LINES) * LINE_H) / seconds,
    deadline = os.clock() + seconds,
  }
end

local function placeRows()
  local i = 1
  while i <= LINES do
    local row = rows[i]
    local job = jobs[i]
    if row ~= nil then
      if job == nil then
        row:SetVisible(false)
      else
        local shown = string.sub(job.text, 1, job.shown)
        row:SetText(shown)
        row:SetMargin(inkMargin.new({ left = 0.0, top = job.y, right = 0.0, bottom = 0.0 }))
        row:SetSize(Vector2.new({ X = WIDTH, Y = LINE_H }))
        row:SetOpacity(opacity)
        row:SetVisible(job.y > -LINE_H and job.y < LINES * LINE_H)
      end
    end
    i = i + 1
  end
end

local function pushLine(text)
  local i = 1
  while i <= #jobs do
    jobs[i].y = jobs[i].y - LINE_H
    i = i + 1
  end
  jobs[#jobs + 1] = {
    text = text,
    shown = 0,
    y = (LINES - 1) * LINE_H,
  }
  while #jobs > LINES do
    table.remove(jobs, 1)
  end
end


function Stream.tick(dt)
  if not ensure() then
    return
  end
  if dt == nil or dt <= 0 then
    dt = 0.016
  end
  if dt > 0.05 then
    dt = 0.05
  end
  if active ~= nil and os.clock() >= active.deadline then
    departJobs()
    active = nil
  end
  if active == nil and #queue > 0 then
    local lines = table.remove(queue, 1)
    active = {
      lines = lines,
      index = 1,
      rate = measure(lines) / HACK_FALLBACK,
      speed = ((#lines + LINES) * LINE_H) / HACK_FALLBACK,
      deadline = os.clock() + HACK_FALLBACK,
    }
  end
  local step = 1
  if active ~= nil and active.rate ~= nil then
    step = math.floor(active.rate * dt)
    if step < 1 then
      step = 1
    end
  end
  if active ~= nil then
    local line = active.lines[active.index]
    local current = jobs[#jobs]
    if current == nil or current.text ~= line or current.depart == true then
      pushLine(line)
      current = jobs[#jobs]
    end
    current.shown = current.shown + step
    if current.shown >= #line then
      current.shown = #line
      active.index = active.index + 1
      if active.index > #active.lines then
        departJobs()
        active = nil
      end
    end
  end
  local i = 1
  while i <= #jobs do
    local job = jobs[i]
    if job.depart == true then
      job.y = job.y - ((LINES * LINE_H) / 0.08) * dt
    elseif active ~= nil and job ~= jobs[#jobs] then
      job.y = job.y - active.speed * dt
    end
    i = i + 1
  end
  while #jobs > 0 and jobs[1].y < -LINE_H do
    table.remove(jobs, 1)
  end
  placeRows()
end

function Stream.drawSettings()
  local Cast = require("cast")
  if ImGui == nil or Cast.isOverlay() ~= true then
    return
  end
  local function slider(label, value, low, high)
    local nextValue, used = ImGui.SliderFloat(label, value, low, high)
    if type(nextValue) ~= "number" then
      return value, false
    end
    if used == true or nextValue ~= value then
      return nextValue, true
    end
    return value, false
  end
  local flags = ImGuiWindowFlags.AlwaysAutoResize
  if ImGuiWindowFlags.NoMove ~= nil then
    flags = flags + ImGuiWindowFlags.NoMove
  end
  ImGui.Begin("QuickHack stream", flags)
  ImGui.Text("Left-side code color and opacity")
  local changed = false
  local function clicked(label)
    local pressed, extra = ImGui.Button(label, 88, 28)
    return pressed == true or extra == true
  end
  if clicked("Red") then
    color.r, color.g, color.b = 1, 0, 0
    changed = true
  end
  ImGui.SameLine()
  if clicked("Green") then
    color.r, color.g, color.b = 0, 1, 0
    changed = true
  end
  ImGui.SameLine()
  if clicked("Blue") then
    color.r, color.g, color.b = 0, 0, 1
    changed = true
  end
  local na, aOk = slider("Opacity", opacity, 0.15, 1.0)
  if aOk then
    opacity = na
    changed = true
  end
  if changed then
    applyStyle()
    saveCfg()
  end
  ImGui.End()
end

function Stream.invalidate()
  canvas = nil
  parent = nil
  rows = {}
end

function Stream.destroy()
  if canvas ~= nil and parent ~= nil then
    pcall(function()
      parent:RemoveChild(canvas)
    end)
  end
  Stream.invalidate()
  jobs = {}
  active = nil
end

loadCfg()

return Stream
