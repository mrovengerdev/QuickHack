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
local MIN_SCROLL = 4
local MAX_SCROLL = 80
local BAR_SCALE = 1.0
local MIN_SCALE = 0.70
local MAX_SCALE = 1.50
local CFG = "bin/x64/plugins/cyber_engine_tweaks/mods/QuickHack/stream.cfg"
local CFG_VER = 3
local FONT = "base\\gameplay\\gui\\fonts\\industry\\industry.inkfontfamily"

local color = { r = 1.5, g = 0.0, b = 0.0 }
local streamOn = true
local barOn = true
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
  file:write(string.format("v%d %.4f %.4f %.4f %.4f %.1f scroll=%.1f scale=%.3f stream=%d bar=%d\n", CFG_VER, color.r, color.g, color.b, opacity, CHARS_PER_SEC, SCROLL_PX_PER_SEC, BAR_SCALE, streamOn and 1 or 0, barOn and 1 or 0))
  file:close()
end

local function loadCfg()
  local file = io.open(CFG, "r")
  if file == nil then
    return
  end
  local text = file:read("*a")
  file:close()
  if string.match(text or "", "stream=0") then
    streamOn = false
  end
  if string.match(text or "", "bar=0") then
    barOn = false
  end
  local ver, r, g, b, a, s = string.match(text or "", "v(%d+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s*([%d%.]*)")
  if ver == nil then
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
  local scroll = string.match(text or "", "scroll=([%d%.]+)")
  if scroll ~= nil then
    SCROLL_PX_PER_SEC = clamp(tonumber(scroll) or SCROLL_PX_PER_SEC, MIN_SCROLL, MAX_SCROLL)
  end
  local scale = string.match(text or "", "scale=([%d%.]+)")
  if scale ~= nil then
    BAR_SCALE = clamp(tonumber(scale) or BAR_SCALE, MIN_SCALE, MAX_SCALE)
  end
  if tonumber(ver) < CFG_VER or scroll == nil or scale == nil then
    saveCfg()
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

local titlePrinted = false

local function asText(value)
  if value == nil then
    return ""
  end
  if type(value) == "string" then
    return value
  end
  local ok, text = pcall(function()
    return tostring(value)
  end)
  if not ok or type(text) ~= "string" or text == "" or string.sub(text, 1, 8) == "userdata" then
    return ""
  end
  return text
end

local function localize(text)
  if text == nil or text == "" then
    return ""
  end
  local ok, localized = pcall(function()
    return GetLocalizedText(text)
  end)
  if ok then
    local s = asText(localized)
    if s ~= "" then
      return s
    end
  end
  if string.sub(text, 1, 7) == "LocKey#" then
    local okKey, byKey = pcall(function()
      return GetLocalizedTextByKey(CName.new(string.sub(text, 8)))
    end)
    if okKey then
      local s = asText(byKey)
      if s ~= "" then
        return s
      end
    end
    return ""
  end
  return text
end

local function titleOf(command)
  if command == nil then
    return "quickhack"
  end
  local okReds, reds = pcall(function()
    return QuickHackIcons.TitleOf(command)
  end)
  if okReds then
    local s = localize(asText(reds))
    if s ~= "" then
      return s
    end
  end
  local fields = {
    command.m_title,
    command.title,
    command.m_titleAlternative,
    command.titleAlternative,
  }
  local i = 1
  while i <= #fields do
    local s = localize(asText(fields[i]))
    if s ~= "" then
      return s
    end
    i = i + 1
  end
  local okCat, cat = pcall(function()
    local value = command.m_iconCategory
    if value == nil then
      value = command.iconCategory
    end
    if value == nil then
      return ""
    end
    return NameToString(value)
  end)
  if okCat then
    local s = asText(cat)
    if s ~= "" and s ~= "None" then
      return s
    end
  end
  local okPart, part = pcall(function()
    return QuickHackIcons.PartNameOf(command)
  end)
  if okPart then
    local s = asText(part)
    if s ~= "" and s ~= "None" then
      return s
    end
  end
  if not titlePrinted then
    titlePrinted = true
    print("QuickHack: stream title missing")
  end
  return "quickhack"
end

local writeScript
local writeFailScript
do
  local function asWriter(ok, result)
    if not ok then
      return nil
    end
    if type(result) == "function" then
      return result
    end
    if type(result) == "table" and type(result.write) == "function" then
      if type(result.writeFail) == "function" then
        writeFailScript = result.writeFail
      end
      return result.write
    end
    return nil
  end

  local errors = {}
  local ok, result = pcall(require, "stream_scripts")
  writeScript = asWriter(ok, result)
  if writeScript == nil then
    errors[#errors + 1] = "require: " .. tostring(ok) .. " " .. type(result) .. " " .. tostring(result)
    local paths = {
      "stream_scripts.lua",
      "bin/x64/plugins/cyber_engine_tweaks/mods/QuickHack/stream_scripts.lua",
    }
    local i = 1
    while i <= #paths and writeScript == nil do
      local path = paths[i]
      local loader, loadErr = loadfile(path)
      if loader ~= nil then
        local ran, value = pcall(loader)
        writeScript = asWriter(ran, value)
        if writeScript == nil then
          errors[#errors + 1] = path .. ": " .. tostring(ran) .. " " .. type(value) .. " " .. tostring(value)
        end
      else
        errors[#errors + 1] = path .. " missing: " .. tostring(loadErr)
      end
      i = i + 1
    end
  end

  if writeScript == nil then
    local detail = table.concat(errors, " | ")
    print("QuickHack: stream scripts failed: " .. detail)
    writeScript = function(title)
      return {
        "  :: QUICKHACK / STREAM",
        "  catalog failed: " .. detail,
        "  " .. tostring(title or ""),
      }
    end
  end
end

local function scriptFor(command)
  return writeScript(titleOf(command))
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

local scriptErrorPrinted = false

function Stream.pushFail(command, available, cost)
  if not streamOn or command == nil or writeFailScript == nil then
    return
  end
  local ok, lines = pcall(function()
    return writeFailScript(titleOf(command), available, cost)
  end)
  if not ok or type(lines) ~= "table" or #lines < 1 then
    return
  end
  if active == nil then
    active = { lines = lines, index = 1 }
    return
  end
  queue[#queue + 1] = lines
end

function Stream.push(command)
  if not streamOn or command == nil then
    return
  end
  local ok, lines = pcall(scriptFor, command)
  if not ok or type(lines) ~= "table" or #lines < 1 then
    if not scriptErrorPrinted then
      scriptErrorPrinted = true
      print("QuickHack: stream script failed: " .. tostring(lines))
    end
    return
  end
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
  if not streamOn or not ensure() then
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
    if type(line) ~= "string" then
      active = nil
    else
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
  local function slider(label, value, low, high, fmt)
    local nextValue, used = ImGui.SliderFloat(label, value, low, high, fmt or "%.3f")
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
    local streamNext, streamHit = ImGui.Checkbox("Netrunner console output", streamOn)
    if type(streamNext) == "boolean" and (streamHit == true or streamNext ~= streamOn) and streamNext ~= streamOn then
      Stream.setStreamOn(streamNext)
    end
    local barNext, barHit = ImGui.Checkbox("Netrunner quickhack bar", barOn)
    if type(barNext) == "boolean" and (barHit == true or barNext ~= barOn) and barNext ~= barOn then
      Stream.setBarOn(barNext)
    end
    ImGui.Separator()
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
    local nscroll, scrollOk = slider("Scroll speed##rate", SCROLL_PX_PER_SEC, MIN_SCROLL, MAX_SCROLL, "%.0f")
    if scrollOk then
      SCROLL_PX_PER_SEC = clamp(nscroll, MIN_SCROLL, MAX_SCROLL)
      changed = true
    end
    ImGui.Text(string.format("Pixels / sec: %.0f", SCROLL_PX_PER_SEC))
    ImGui.Separator()
    ImGui.Text("Quickhack bar size")
    local nscale, scaleOk = slider("Bar size##scale", BAR_SCALE, MIN_SCALE, MAX_SCALE, "%.2f")
    if scaleOk then
      BAR_SCALE = clamp(nscale, MIN_SCALE, MAX_SCALE)
      changed = true
      pcall(function()
        local Hud = require("hud")
        if type(Hud) == "table" and type(Hud.setScale) == "function" then
          Hud.setScale(BAR_SCALE)
        end
      end)
    end
    ImGui.Text(string.format("Size: %.0f%%", BAR_SCALE * 100))
    if ImGui.Button("RED") then
      color.r, color.g, color.b = 1.5, 0.0, 0.0
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("TEAL") then
      color.r, color.g, color.b = 0.0, 1.5, 1.15
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("GREEN") then
      color.r, color.g, color.b = 0.0, 1.5, 0.0
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("YELLOW") then
      color.r, color.g, color.b = 1.5, 1.5, 0.0
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
  queue = {}
  active = nil
end

function Stream.isStreamOn()
  return streamOn
end

function Stream.isBarOn()
  return barOn
end

function Stream.barScale()
  return BAR_SCALE
end

function Stream.setStreamOn(on)
  streamOn = on == true
  if not streamOn then
    Stream.destroy()
  end
  saveCfg()
end

function Stream.setBarOn(on)
  barOn = on == true
  saveCfg()
end

pcall(loadCfg)

return Stream
