local Stream = {}

local LINES = 16
local LINE_H = 20
local LEFT = 36
local TOP = 150
local WIDTH = 720
local CHARS_PER_SEC = 1500
local MIN_CPS = 80
local MAX_CPS = 2500
local SCROLL_PX_PER_SEC = 18
local CFG = "bin/x64/plugins/cyber_engine_tweaks/mods/QuickHack/stream.cfg"
local CFG_VER = 2
local FONT = "base\\gameplay\\gui\\fonts\\industry\\industry.inkfontfamily"
local COL = 54

local color = { r = 1.5, g = 0.0, b = 0.0 }
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

local function saveCfg()
  local file = io.open(CFG, "w")
  if file == nil then
    return
  end
  file:write(string.format("v%d %.4f %.4f %.4f %.4f %.1f\n", CFG_VER, color.r, color.g, color.b, opacity, CHARS_PER_SEC))
  file:close()
end

local function loadCfg()
  local file = io.open(CFG, "r")
  if file == nil then
    return
  end
  local text = file:read("*a")
  file:close()
  local ver, r, g, b, a, s = string.match(text or "", "v(%d+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s*([%d%.]*)")
  if ver == nil then
    saveCfg()
    return
  end
  if tonumber(ver) < CFG_VER then
    saveCfg()
    return
  end
  color.r = clamp(tonumber(r) or color.r, 0, 1.5)
  color.g = clamp(tonumber(g) or color.g, 0, 1.5)
  color.b = clamp(tonumber(b) or color.b, 0, 1.5)
  opacity = clamp(tonumber(a) or opacity, 0.15, 1)
  if s ~= nil and s ~= "" then
    CHARS_PER_SEC = clamp(tonumber(s) or CHARS_PER_SEC, MIN_CPS, MAX_CPS)
  end
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

local function pick(variants)
  return variants[math.random(1, #variants)]
end

local function hex()
  return string.format("[0x%X]", math.random(0x10000, 0xFFFFFF))
end

local function pair()
  return hex() .. " x " .. hex()
end

local function pad(s, width)
  s = tostring(s or "")
  if #s > width then
    return string.sub(s, 1, width)
  end
  return s .. string.rep(" ", width - #s)
end

local function center(s, width)
  s = tostring(s or "")
  if #s >= width then
    return string.sub(s, 1, width)
  end
  local left = math.floor((width - #s) / 2)
  return string.rep(" ", left) .. s .. string.rep(" ", width - #s - left)
end

local function edge(ch)
  return "+" .. string.rep(ch, COL - 2) .. "+"
end

local function box(inner)
  return "|" .. pad(inner, COL - 2) .. "|"
end

local function fit(lines)
  while #lines < 12 do
    local at = #lines
    if string.sub(lines[#lines] or "", 1, 1) == "+" then
      at = #lines
    end
    table.insert(lines, at, box("  " .. pair()))
  end
  if #lines > 16 then
    local cut = {}
    local i = 1
    while i <= 16 do
      cut[i] = lines[i]
      i = i + 1
    end
    lines = cut
  end
  return lines
end

local function banner(title)
  local name = string.upper(tostring(title or "QUICKHACK"))
  if #name > 28 then
    name = string.sub(name, 1, 28)
  end
  return name
end

local function styleFrame(title)
  local lines = {
    edge("="),
    box("  QH // " .. banner(title)),
    box("  pid " .. tostring(200 + math.random(0, 7800)) .. "   sess " .. hex()),
    edge("-"),
    box("         .--."),
    box("        /    \\      CORE  LOCKED"),
    box("        \\    /      bus   HOT"),
    box("         `--'"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  STATUS  committed"),
    edge("="),
  }
  return fit(lines)
end

local function styleDump(title)
  local lines = {
    string.rep("=", COL),
    "  >> EXEC  " .. banner(title),
    string.rep("-", COL),
  }
  local row = 0
  while row < 8 do
    local addr = string.format("  %04X  ", 0x1000 + row * 16)
    local bytes = {}
    local i = 1
    while i <= 8 do
      bytes[i] = string.format("%02X", math.random(0, 255))
      i = i + 1
    end
    lines[#lines + 1] = addr .. table.concat(bytes, " ") .. "  " .. pair()
    row = row + 1
  end
  lines[#lines + 1] = string.rep("-", COL)
  lines[#lines + 1] = "  COMMIT  ok"
  lines[#lines + 1] = string.rep("=", COL)
  return fit(lines)
end

local function styleScan(title)
  local bars = { "[=>        ]", "[===>      ]", "[======>   ]", "[=========>]" }
  local lines = {
    "  /" .. string.rep("=", COL - 4) .. "\\",
    "  |" .. center(banner(title), COL - 4) .. "|",
    "  \\" .. string.rep("=", COL - 4) .. "/",
    "   > inject   " .. pair(),
    "   > map      " .. pair(),
  }
  local i = 1
  while i <= #bars do
    lines[#lines + 1] = "   > load " .. bars[i] .. "  " .. tostring(i * 25) .. "%"
    i = i + 1
  end
  lines[#lines + 1] = "   > " .. pair()
  lines[#lines + 1] = "   ** COMMIT **"
  return fit(lines)
end

local function styleWave(title)
  local lines = {
    edge("="),
    box("  " .. banner(title)),
    edge("-"),
    box("    /\\    /\\    /\\    /\\    /\\"),
    box("   /  \\  /  \\  /  \\  /  \\  /  \\"),
    box("  /    \\/    \\/    \\/    \\/    \\"),
    box("  SIGNAL  OPEN    RATE  MAX"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  done."),
    edge("="),
  }
  return fit(lines)
end

local function styleGrid(title)
  local lines = {
    edge("+"),
    box("  // " .. banner(title)),
    edge("+"),
  }
  local r = 1
  while r <= 8 do
    local cells = {}
    local c = 1
    while c <= 6 do
      if math.random() < 0.5 then
        cells[c] = "[##]"
      else
        cells[c] = "[  ]"
      end
      c = c + 1
    end
    lines[#lines + 1] = box("  " .. table.concat(cells, " ") .. "  " .. hex())
    r = r + 1
  end
  lines[#lines + 1] = box("  GRID  FLUSHED")
  lines[#lines + 1] = edge("+")
  return fit(lines)
end

local function asciiVariants(title)
  return {
    styleFrame(title),
    styleDump(title),
    styleScan(title),
    styleWave(title),
    styleGrid(title),
  }
end

local function scriptFor(command)
  return pick(asciiVariants(titleOf(command)))
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
    pcall(function()
      label:SetFontFamily(FONT, CName.new("Regular"))
    end)
    pcall(function()
      label:SetFontStyle(CName.new("Regular"))
      label:SetHorizontalAlignment(textHorizontalAlignment.Left)
    end)
    label:SetFontSize(15)
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

function Stream.push(command)
  if command == nil then
    return
  end
  local lines = scriptFor(command)
  if active == nil then
    active = { lines = lines, index = 1 }
    return
  end
  queue[#queue + 1] = lines
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
  local step = math.floor(CHARS_PER_SEC * dt)
  if step < 1 then
    step = 1
  end
  if active == nil and #queue > 0 then
    active = { lines = table.remove(queue, 1), index = 1 }
  end
  if active ~= nil then
    local line = active.lines[active.index]
    local current = jobs[#jobs]
    if current == nil or current.text ~= line then
      pushLine(line)
      current = jobs[#jobs]
    end
    current.shown = current.shown + step
    if current.shown >= #line then
      current.shown = #line
      active.index = active.index + 1
      if active.index > #active.lines then
        active = nil
      end
    end
  end
  local i = 1
  while i <= #jobs do
    if active == nil or jobs[i] ~= jobs[#jobs] or jobs[i].shown >= #jobs[i].text then
      jobs[i].y = jobs[i].y - SCROLL_PX_PER_SEC * dt
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
    local nextValue, used = ImGui.SliderFloat(label, value, low, high, "%.3f")
    if type(nextValue) ~= "number" and type(used) == "number" then
      nextValue, used = used, nextValue
    end
    if type(nextValue) ~= "number" then
      return value, false
    end
    if used == true or nextValue ~= value then
      return nextValue, true
    end
    return value, false
  end
  ImGui.SetNextWindowSize(360, 180, ImGuiCond.FirstUseEver)
  local visible = ImGui.Begin("QuickHack stream", ImGuiWindowFlags.AlwaysAutoResize)
  if visible ~= false then
    ImGui.Text("Left-side code color, opacity, and write speed")
    local changed = false
    local nr, rOk = slider("Red##chan", color.r, 0.0, 1.5)
    if rOk then
      color.r = nr
      changed = true
    end
    local ng, gOk = slider("Green##chan", color.g, 0.0, 1.5)
    if gOk then
      color.g = ng
      changed = true
    end
    local nb, bOk = slider("Blue##chan", color.b, 0.0, 1.5)
    if bOk then
      color.b = nb
      changed = true
    end
    local na, aOk = slider("Opacity##chan", opacity, 0.15, 1.0)
    if aOk then
      opacity = na
      changed = true
    end
    local ns, sOk = slider("Write speed##rate", CHARS_PER_SEC, MIN_CPS, MAX_CPS)
    if sOk then
      CHARS_PER_SEC = clamp(ns, MIN_CPS, MAX_CPS)
      changed = true
    end
    ImGui.Text(string.format("Chars / sec: %.0f", CHARS_PER_SEC))
    if ImGui.Button("RED") then
      color.r, color.g, color.b = 1.5, 0.0, 0.0
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("BLUE") then
      color.r, color.g, color.b = 0.0, 0.0, 1.5
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("GREEN") then
      color.r, color.g, color.b = 0.0, 1.5, 0.0
      changed = true
    end
    if changed then
      applyStyle()
      saveCfg()
    end
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
