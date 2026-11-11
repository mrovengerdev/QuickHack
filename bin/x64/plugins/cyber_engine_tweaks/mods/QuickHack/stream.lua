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

local function pid()
  return tostring(200 + math.random(0, 32700))
end

local function mem()
  return string.format("0x%08X", math.random(0x10001000, 0x7FFFF000))
end

local function word()
  return string.format("%02X", math.random(0, 255))
end

local function pair()
  return mem() .. " x " .. mem()
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
    local last = lines[#lines] or ""
    local first = string.sub(last, 1, 1)
    if first == "+" or first == "=" or string.find(last, "COMMIT", 1, true) or string.find(last, "panic", 1, true) then
      at = #lines
    end
    if first == "|" then
      table.insert(lines, at, box("  " .. pair()))
    else
      table.insert(lines, at, "  " .. pair() .. "  pid " .. pid())
    end
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

local function hexrow(base)
  local bytes = {}
  local i = 1
  while i <= 8 do
    bytes[i] = word()
    i = i + 1
  end
  return "  " .. string.format("%08X", base) .. "  " .. table.concat(bytes, " ")
end

local function familyOf(title)
  local t = string.lower(tostring(title or ""))
  if string.find(t, "wipe", 1, true) then
    return "memorywipe"
  end
  if string.find(t, "overheat", 1, true) then
    return "overheat"
  end
  if string.find(t, "short", 1, true) and string.find(t, "circuit", 1, true) then
    return "shortcircuit"
  end
  if string.find(t, "synapse", 1, true) or string.find(t, "burnout", 1, true) then
    return "synapse"
  end
  if string.find(t, "optic", 1, true) or string.find(t, "blind", 1, true) then
    return "rebootoptics"
  end
  if string.find(t, "weapon", 1, true) then
    return "weaponglitch"
  end
  if string.find(t, "cyberware", 1, true) or string.find(t, "malfunction", 1, true) then
    return "cyberware"
  end
  if string.find(t, "suicide", 1, true) then
    return "suicide"
  end
  if string.find(t, "grenade", 1, true) or string.find(t, "detonate", 1, true) then
    return "detonate"
  end
  if string.find(t, "cripple", 1, true) or string.find(t, "movement", 1, true) then
    return "cripple"
  end
  if string.find(t, "ping", 1, true) then
    return "ping"
  end
  if string.find(t, "whistle", 1, true) then
    return "whistle"
  end
  if string.find(t, "contagion", 1, true) then
    return "contagion"
  end
  if string.find(t, "sonic", 1, true) then
    return "sonic"
  end
  if string.find(t, "backup", 1, true) then
    return "backup"
  end
  if string.find(t, "camera", 1, true) then
    return "camera"
  end
  if string.find(t, "turret", 1, true) then
    return "turret"
  end
  if string.find(t, "distract", 1, true) then
    return "distract"
  end
  if string.find(t, "system", 1, true) and string.find(t, "reset", 1, true) then
    return "systemreset"
  end
  if string.find(t, "explode", 1, true) then
    return "explode"
  end
  if string.find(t, "vehicle", 1, true) or string.find(t, "hijack", 1, true) or string.find(t, "brake", 1, true) then
    return "vehicle"
  end
  if string.find(t, "unlock", 1, true) or string.find(t, "door", 1, true) then
    return "unlock"
  end
  if string.find(t, "overload", 1, true) then
    return "overload"
  end
  if string.find(t, "take control", 1, true) or string.find(t, "remote", 1, true) then
    return "control"
  end
  if string.find(t, "reset", 1, true) then
    return "systemreset"
  end
  return "generic"
end

local function dumpWipe(title)
  local base = math.random(0x20000000, 0x6F000000)
  return fit({
    string.rep("=", COL),
    "  >> MEMORY DUMP  " .. banner(title),
    "  pid " .. pid() .. "  comm=wiped  sess " .. mem(),
    string.rep("-", COL),
    hexrow(base),
    hexrow(base + 16),
    hexrow(base + 32),
    hexrow(base + 48),
    hexrow(base + 64),
    hexrow(base + 80),
    "  munmap " .. string.format("%08X", base) .. ".." .. string.format("%08X", base + 0x1000),
    "  pages zeroed  16  ok",
    string.rep("=", COL),
  })
end

local function panicWipe(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  vm_fault  page not present  at " .. mem(),
    "  cr2=" .. mem() .. "  cr3=" .. mem(),
    "  stack:",
    "    [0] wipe_pages+0x4C     " .. mem(),
    "    [1] do_munmap+0x18      " .. mem(),
    "    [2] sys_memctl+0xA0     " .. mem(),
    "    [3] irq_exit+0x0C       " .. mem(),
    "  core dumped  " .. pair(),
    "  ram image flushed  ok",
    "  * * *  END PANIC  * * *",
  })
end

local function mapsWipe(title)
  local a = math.random(0x00400000, 0x00A00000)
  return fit({
    "  /proc/" .. pid() .. "/maps    " .. banner(title),
    "  " .. string.format("%08X-%08X", a, a + 0x8C000) .. " r-x  [text]",
    "  " .. string.format("%08X-%08X", a + 0x8C000, a + 0x9C000) .. " r--  [rodata]",
    "  " .. string.format("%08X-%08X", a + 0x9C000, a + 0x120000) .. " rw-  [data]",
    "  " .. mem() .. "-" .. mem() .. " rw-  [heap]",
    "  " .. mem() .. "-" .. mem() .. " ---  [guard]",
    "  " .. mem() .. "-" .. mem() .. " rw-  [stack]",
    "  --- wipe ---",
    "  munmap heap   ok  " .. mem(),
    "  munmap stack  ok  " .. mem(),
    "  pid " .. pid() .. "  address space empty",
    "  COMMIT  memory wiped",
  })
end

local function thermPanic(title)
  local temp = 96 + math.random(0, 28)
  return fit({
    edge("="),
    box("  THERMD  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  Tctl=" .. tostring(temp) .. "C  trip  critical"),
    box("  fan pwm=255  still rising"),
    box("  KERNEL PANIC @ " .. mem()),
    box("    thermal_isr+0x22"),
    box("    acctrip_halt+0x08"),
    box("  " .. pair()),
    box("  cpu0 offline  cpu1 offline"),
    box("  STATUS  thermal shutdown"),
    edge("="),
  })
end

local function thermMsr(title)
  return fit({
    "  [msr]  " .. banner(title) .. "  pid " .. pid(),
    "  rdmsr  0x1A2  IA32_THERM  = " .. mem(),
    "  rdmsr  0x19C  THERM_STATUS = " .. mem(),
    "  package trip  PROCHOT  asserted",
    "  p-state  P0 -> Pmin  " .. mem(),
    "  clk  4.20GHz -> 0.40GHz",
    "  drop  irq " .. tostring(math.random(20, 80)) .. "%  packet loss " .. tostring(math.random(5, 40)) .. "%",
    "  " .. pair(),
    "  " .. pair(),
    "  wait  cooldown  3s",
    "  COMMIT  rail hot  hold",
    "  [msr]  end",
  })
end

local function thermAcpi(title)
  return fit({
    "  ACPI  \_TZ.CPU0  " .. banner(title),
    "  pid " .. pid() .. "  ev  0x80  thermal",
    "  sensor  0  " .. tostring(100 + math.random(0, 20)) .. "C  crit",
    "  sensor  1  " .. tostring(90 + math.random(0, 20)) .. "C  warn",
    "  _CRT exceeded  at " .. mem(),
    "  +------------------------------+",
    "  |   ##    ##    HEAT   ##    ## |",
    "  |     ##      ##    ##      ##  |",
    "  +------------------------------+",
    "  KERNEL PANIC  ACPI halt",
    "  " .. pair(),
    "  COMMIT  trip logged",
  })
end

local function busError(title)
  return fit({
    "  ***  BUS ERROR  SIGBUS  ***",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  addr " .. mem() .. "  align fault",
    "  data  " .. word() .. " " .. word() .. " " .. word() .. " " .. word() .. "  bus 0",
    "  irq storm  190k/s  cpu0",
    "  " .. pair(),
    "  " .. pair(),
    "  ecc  uncorrectable  3",
    "  KERNEL PANIC  machine check",
    "  mca bank0  " .. mem(),
    "  rail  VCORE  collapse",
    "  ***  END BUS ERROR  ***",
  })
end

local function irqStorm(title)
  return fit({
    edge("+"),
    box("  IRQ  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  irq  16  214882  storm"),
    box("  irq  19  180221  storm"),
    box("  apic  " .. mem() .. "  latched"),
    box("  packet loss  " .. tostring(math.random(12, 67)) .. "%  nic0"),
    box("  " .. pair()),
    box("  short on bus  DAT[7:0]"),
    box("  STATUS  circuit open"),
    box("  COMMIT  line isolated"),
    edge("+"),
  })
end

local function railDrop(title)
  return fit({
    "  pmicd  " .. banner(title) .. "  pid " .. pid(),
    "  VCORE   1.05 -> 0.11  fault",
    "  VSOC   0.90 -> 0.00  fault",
    "  i2c-0  nack  at " .. mem(),
    "  KERNEL PANIC  undervolt",
    "  " .. pair(),
    "  gpio  PWR_OK  deassert",
    "  watchdog  0  bark",
    "  dump  " .. mem() .. "  4K",
    "  Isolate rail  ok",
    "  pid " .. pid() .. "  halted",
    "  COMMIT  short cleared",
  })
end

local function synPanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  SYNAPSE  " .. banner(title) .. "  pid " .. pid(),
    "  nmi  double fault  at " .. mem(),
    "  ss  " .. mem() .. "  rsp " .. mem(),
    "    [0] neur_fire+0x9E",
    "    [1] chain_burn+0x14",
    "    [2] irq_nmi+0x02",
    "  packet loss  100%  link down",
    "  " .. pair(),
    "  core 2  fused  offline",
    "  * * *  END PANIC  * * *",
    "  COMMIT  synapse dead",
  })
end

local function synFlood(title)
  return fit({
    edge("="),
    box("  NEURAL  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  spike rate  40kHz -> 1.2MHz"),
    box("  refractory  0ms  OVERFLOW"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  kernel: synapse_q full"),
    box("  drop  " .. tostring(math.random(200, 900)) .. "  frames"),
    box("  STATUS  burnout"),
    box("  COMMIT  pathway seared"),
    edge("="),
  })
end

local function synWatch(title)
  return fit({
    "  watchdog  " .. banner(title),
    "  pid " .. pid() .. "  tick missed  8",
    "  last  " .. mem() .. "  now " .. mem(),
    "  feed  failed  timeout",
    "  KERNEL PANIC  hard lock",
    "  " .. pair(),
    "  " .. pair(),
    "  reset vector  " .. mem(),
    "  core dump  queued",
    "  link  packet loss  92%",
    "  halt  ok",
    "  COMMIT  watchdog bite",
  })
end

local function opticReset(title)
  return fit({
    "  fb0  " .. banner(title) .. "  pid " .. pid(),
    "  ioctl  FBIOPUT_VSCREEN  " .. mem(),
    "  modeset  fail  hang",
    "  gpu  fence  timeout  3s",
    "  KERNEL PANIC  ring stalled",
    "  " .. pair(),
    "  blank  ok  edid lost",
    "  retry  1  no link",
    "  retry  2  no link",
    "  packet loss  100%  dsi",
    "  STATUS  optics offline",
    "  COMMIT  framebuffer reset",
  })
end

local function opticCrc(title)
  return fit({
    edge("+"),
    box("  VISION  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  crc  fail  " .. mem()),
    box("  frame  0  drop"),
    box("  frame  1  drop"),
    box("  frame  2  drop"),
    box("  " .. pair()),
    box("  i2c  cam0  nack"),
    box("  STATUS  pipeline halt"),
    box("  COMMIT  reboot optics"),
    edge("+"),
  })
end

local function opticDma(title)
  return fit({
    "  dma  " .. banner(title) .. "  pid " .. pid(),
    "  chan0  " .. mem() .. " -> " .. mem(),
    "  desc  corrupt  " .. word() .. word(),
    "  KERNEL PANIC  iommu fault",
    "  iova  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  unmap  fb  ok",
    "  blackout  1",
    "  pid " .. pid() .. "  stopped",
    "  COMMIT  stream cut",
    "  [dma]  end",
  })
end

local function weaponDma(title)
  return fit({
    "  ***  DMA FAULT  ***",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  iommu  " .. mem() .. "  write violate",
    "  dev  wpn0  bar0  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  packet loss  " .. tostring(math.random(20, 80)) .. "%  fire-ctl",
    "  KERNEL PANIC  uncorrectable",
    "  isolate  device  ok",
    "  trigger  inhibit  1",
    "  ***  END DMA FAULT  ***",
    "  COMMIT  glitch held",
  })
end

local function weaponBus(title)
  return fit({
    edge("="),
    box("  WPNCTL  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  can0  err  stuffbit"),
    box("  can0  packet loss  " .. tostring(math.random(10, 60)) .. "%"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  firmware  crc  mismatch"),
    box("  safe  state  forced"),
    box("  STATUS  actuator mute"),
    box("  COMMIT  bus quiet"),
    edge("="),
  })
end

local function weaponIrq(title)
  return fit({
    "  irq  wpn  " .. banner(title) .. "  pid " .. pid(),
    "  spurious  40012",
    "  ack  fail  at " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  mask  irq  21  ok",
    "  timeout  fire-loop",
    "  KERNEL PANIC  skipped  recover",
    "  pid " .. pid() .. "  yield",
    "  lock  trigger  ok",
    "  COMMIT  glitch sticky",
    "  [irq]  end",
  })
end

local function wareFw(title)
  return fit({
    "  fwupd  " .. banner(title) .. "  pid " .. pid(),
    "  image  " .. mem() .. "  crc  BAD",
    "  slot  A  dirty  slot  B  stale",
    "  i2c-3  timeout  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  rollback  fail",
    "  KERNEL PANIC  bad capsule",
    "  hold  reset  line",
    "  packet loss  44%  mbus",
    "  STATUS  cyberware fault",
    "  COMMIT  module isolate",
  })
end

local function wareI2c(title)
  return fit({
    edge("+"),
    box("  MBUS  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  i2c  0x68  nack"),
    box("  i2c  0x69  nack"),
    box("  scl  stuck  low  " .. mem()),
    box("  " .. pair()),
    box("  recover  bus  fail"),
    box("  STATUS  peripheral dead"),
    box("  COMMIT  net offline"),
    box("  packet loss  100%"),
    edge("+"),
  })
end

local function warePanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops: implant watchdog",
    "  at " .. mem(),
    "    [0] cw_tick+0x70",
    "    [1] bio_isr+0x1C",
    "  " .. pair(),
    "  " .. pair(),
    "  submodule  offline  6",
    "  * * *  END PANIC  * * *",
    "  COMMIT  malfunction latched",
    "  [oops]  end",
  })
end

local function resetPanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid() .. "  init",
    "  sysrq  b  immediate reboot",
    "  sync  filesystems  skip",
    "  " .. pair(),
    "  " .. pair(),
    "  watchdog  bite  0",
    "  reset  vector  " .. mem(),
    "  pid 1  killed",
    "  packet loss  100%",
    "  * * *  REBOOTING  * * *",
    "  COMMIT  system reset",
  })
end

local function resetWatch(title)
  return fit({
    edge("="),
    box("  INIT  " .. banner(title) .. "  pid 1"),
    edge("-"),
    box("  runlevel  0  going down"),
    box("  sigterm  pid " .. pid()),
    box("  sigterm  pid " .. pid()),
    box("  " .. pair()),
    box("  unmount  /  busy"),
    box("  force  umount  ok"),
    box("  STATUS  restart"),
    box("  COMMIT  reboot armed"),
    edge("="),
  })
end

local function resetDump(title)
  return fit({
    "  kexec  " .. banner(title) .. "  pid " .. pid(),
    "  load  " .. mem() .. "  len  0x2000",
    "  shutdown  hooks  4",
    "  " .. pair(),
    "  " .. pair(),
    "  nmi  shootdown  cpus",
    "  KERNEL PANIC  expected",
    "  jump  " .. mem(),
    "  boot  cpu0  spinning",
    "  packet loss  link reset",
    "  COMMIT  kexec go",
    "  [kexec]  end",
  })
end

local function killSig(title)
  return fit({
    "  ***  FATAL  SIGKILL  ***",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  sender  pid " .. pid() .. "  uid 0",
    "  at " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  threads  12  reaped",
    "  fds  closed  27",
    "  KERNEL  process gone",
    "  wait  zombie  0",
    "  ***  END  ***",
    "  COMMIT  target halted",
  })
end

local function killInit(title)
  return fit({
    edge("+"),
    box("  INIT  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  SIGTERM  ignored"),
    box("  SIGKILL  delivered  " .. mem()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  ns  teardown  ok"),
    box("  STATUS  no process"),
    box("  COMMIT  init released"),
    box("  packet loss  100%"),
    edge("+"),
  })
end

local function killOops(title)
  return fit({
    "  oops:  " .. banner(title),
    "  pid " .. pid() .. "  comm=target",
    "  KERNEL PANIC  fatal exception",
    "  rip  " .. mem() .. "  cs  0x10",
    "    [0] do_exit+0x00",
    "    [1] do_group_exit+0x24",
    "  " .. pair(),
    "  " .. pair(),
    "  core  not dumped",
    "  parent  reaped  ok",
    "  COMMIT  exit(137)",
    "  [oops]  end",
  })
end

local function fuseTimer(title)
  return fit({
    "  fused  " .. banner(title) .. "  pid " .. pid(),
    "  gpio  ARM  assert  " .. mem(),
    "  timer  3.00s  armed",
    "  " .. pair(),
    "  tick  2.00  ok",
    "  tick  1.00  ok",
    "  tick  0.00  fire",
    "  irq  40  delivered",
    "  packet  burst  ok",
    "  " .. pair(),
    "  STATUS  fuse spent",
    "  COMMIT  detonate",
  })
end

local function fuseCan(title)
  return fit({
    edge("="),
    box("  CAN0  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  id  0x0C0  ARM"),
    box("  id  0x0C1  FIRE  " .. mem()),
    box("  " .. pair()),
    box("  packet loss  0%  local"),
    box("  ack  1  from " .. mem()),
    box("  STATUS  payload out"),
    box("  COMMIT  bus fired"),
    box("  gpio  spent"),
    edge("="),
  })
end

local function fusePanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops:  gpio fire  " .. mem(),
    "    [0] fuse_isr+0x10",
    "    [1] handle_irq+0x44",
    "  " .. pair(),
    "  " .. pair(),
    "  expected  panic  hold",
    "  * * *  END PANIC  * * *",
    "  packet  sent  1",
    "  COMMIT  charge gone",
    "  [gpio]  end",
  })
end

local function motorPid(title)
  return fit({
    "  pidctl  " .. banner(title) .. "  pid " .. pid(),
    "  loop  P=" .. tostring(math.random(8, 40)) .. "  I=0  D=0",
    "  setpoint  0  meas  " .. tostring(math.random(20, 90)),
    "  pwm  clamp  0  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  stall  detect  1",
    "  encoder  lost  packet loss " .. tostring(math.random(15, 70)) .. "%",
    "  safe  torque  off",
    "  STATUS  gait freeze",
    "  COMMIT  movement crippled",
    "  [pidctl]  end",
  })
end

local function motorBus(title)
  return fit({
    edge("+"),
    box("  SERVO  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  can1  timeout  " .. mem()),
    box("  packet loss  " .. tostring(math.random(20, 90)) .. "%"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  brake  lock  on"),
    box("  STATUS  actuators hold"),
    box("  COMMIT  walk inhibit"),
    box("  irq  27  masked"),
    edge("+"),
  })
end

local function motorPanic(title)
  return fit({
    "  KERNEL PANIC  motor isr",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  at " .. mem(),
    "    [0] gait_tick+0x5A",
    "    [1] pwm_isr+0x0E",
    "  " .. pair(),
    "  " .. pair(),
    "  joints  8  offline",
    "  recover  skip",
    "  STATUS  frozen",
    "  COMMIT  limp mode",
    "  [panic]  end",
  })
end

local function pingIcmp(title)
  local lost = math.random(2, 6)
  local sent = 12
  return fit({
    "  PING  " .. banner(title) .. "  pid " .. pid(),
    "  icmp  id=" .. string.format("0x%04X", math.random(0, 65535)) .. "  " .. mem(),
    "  64 bytes  ttl=54  time=2 ms",
    "  64 bytes  ttl=54  time=3 ms",
    "  64 bytes  ttl=1   time=*  loss",
    "  64 bytes  ttl=54  time=2 ms",
    "  64 bytes  ttl=0   time=*  loss",
    "  " .. pair(),
    "  " .. pair(),
    "  ---  stats  ---",
    "  " .. tostring(sent) .. " sent  " .. tostring(lost) .. " lost  " .. tostring(math.floor(lost * 100 / sent)) .. "% packet loss",
    "  COMMIT  echo done",
  })
end

local function pingTrace(title)
  return fit({
    "  traceroute  " .. banner(title) .. "  pid " .. pid(),
    "   1  " .. mem() .. "  1 ms",
    "   2  " .. mem() .. "  4 ms",
    "   3  *  *  *  packet loss",
    "   4  " .. mem() .. "  9 ms",
    "   5  *  *  *  packet loss",
    "   6  " .. mem() .. "  12 ms",
    "  " .. pair(),
    "  hop  3,5  dropped",
    "  rtt  avg  8ms  loss  28%",
    "  STATUS  path mapped",
    "  COMMIT  trace end",
  })
end

local function pingSock(title)
  return fit({
    edge("="),
    box("  NETSTAT  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  udp  " .. mem() .. "  ESTAB"),
    box("  udp  " .. mem() .. "  DROP"),
    box("  " .. pair()),
    box("  rx  errors  " .. tostring(math.random(10, 200))),
    box("  packet loss  " .. tostring(math.random(5, 35)) .. "%"),
    box("  STATUS  host reachable"),
    box("  COMMIT  ping cached"),
    box("  ttl  54"),
    edge("="),
  })
end

local function whistleUdp(title)
  return fit({
    "  beacon  " .. banner(title) .. "  pid " .. pid(),
    "  udp  dst " .. mem() .. "  port 9",
    "  payload  " .. word() .. word() .. word() .. word(),
    "  " .. pair(),
    "  " .. pair(),
    "  send  8  datagrams",
    "  packet loss  " .. tostring(math.random(0, 15)) .. "%",
    "  ack  none  expected",
    "  hop  flood  ok",
    "  STATUS  whistle out",
    "  COMMIT  broadcast",
    "  [udp]  end",
  })
end

local function whistleMesh(title)
  return fit({
    edge("+"),
    box("  MESH  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  neigh  " .. mem() .. "  heard"),
    box("  neigh  " .. mem() .. "  heard"),
    box("  " .. pair()),
    box("  ttl  4  hop"),
    box("  packet loss  6%"),
    box("  STATUS  lure armed"),
    box("  COMMIT  beacon hold"),
    box("  rssi  -41 dBm"),
    edge("+"),
  })
end

local function whistleRaw(title)
  return fit({
    "  raw  " .. banner(title) .. "  pid " .. pid(),
    "  sock  AF_PACKET  " .. mem(),
    "  frame  0  out  " .. mem(),
    "  frame  1  out  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  retry  0",
    "  packet loss  2%",
    "  STATUS  tone sent",
    "  COMMIT  whistle done",
    "  [raw]  end",
    "  pid " .. pid() .. "  idle",
  })
end

local function contagionSyn(title)
  return fit({
    "  * worm  " .. banner(title) .. "  pid " .. pid(),
    "  syn  flood  " .. mem(),
    "  syn  flood  " .. mem(),
    "  syn  flood  " .. mem(),
    "  " .. pair(),
    "  sockets  4096  open",
    "  packet loss  peer  " .. tostring(math.random(10, 50)) .. "%",
    "  hop  2  infected",
    "  hop  3  infected",
    "  STATUS  spread ok",
    "  COMMIT  contagion live",
    "  [worm]  end",
  })
end

local function contagionRoute(title)
  return fit({
    edge("="),
    box("  ROUTE  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  add  " .. mem() .. "  via infect"),
    box("  add  " .. mem() .. "  via infect"),
    box("  " .. pair()),
    box("  ttl  8  propagate"),
    box("  packet loss  11%"),
    box("  STATUS  mesh owned"),
    box("  COMMIT  routes dirty"),
    box("  pid " .. pid() .. "  spawn"),
    edge("="),
  })
end

local function contagionPanic(title)
  return fit({
    "  KERNEL PANIC  netfilter",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  hook  PRE  overrun  " .. mem(),
    "    [0] nf_infect+0x66",
    "    [1] ip_rcv+0x30",
    "  " .. pair(),
    "  " .. pair(),
    "  expected  skip  continue",
    "  hosts  6  tagged",
    "  packet loss  19%",
    "  COMMIT  worm resident",
    "  [nf]  end",
  })
end

local function sonicIrq(title)
  return fit({
    "  audio  " .. banner(title) .. "  pid " .. pid(),
    "  irq  22  underrun  " .. mem(),
    "  buf  " .. mem() .. "  empty",
    "  " .. pair(),
    "  " .. pair(),
    "  sample  48k  force  192k",
    "  clip  1  amp  max",
    "  packet loss  0%  local",
    "  STATUS  shock out",
    "  COMMIT  codec held",
    "  [pcm]  end",
    "  pid " .. pid() .. "  drain",
  })
end

local function sonicDma(title)
  return fit({
    edge("+"),
    box("  PCM  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  dma  " .. mem() .. "  burst"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  fifo  overflow  12"),
    box("  KERNEL  warn  spike"),
    box("  STATUS  tone locked"),
    box("  COMMIT  sonic done"),
    box("  irq  22  ack"),
    edge("+"),
  })
end

local function sonicPanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops:  codec  lockup  " .. mem(),
    "    [0] snd_isr+0x2A",
    "    [1] handle_irq+0x44",
    "  " .. pair(),
    "  " .. pair(),
    "  recover  replay  ok",
    "  * * *  END PANIC  * * *",
    "  packet loss  3%",
    "  COMMIT  burst sent",
    "  [snd]  end",
  })
end

local function backupMesh(title)
  return fit({
    "  meshctl  " .. banner(title) .. "  pid " .. pid(),
    "  req  BACKUP  to " .. mem(),
    "  req  BACKUP  to " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  ack  1  rtt  8ms",
    "  ack  2  rtt  11ms",
    "  packet loss  " .. tostring(math.random(0, 20)) .. "%",
    "  units  inbound  2",
    "  STATUS  request out",
    "  COMMIT  backup called",
    "  [mesh]  end",
  })
end

local function backupFlood(title)
  return fit({
    edge("="),
    box("  FLOOD  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  udp  4096  burst  " .. mem()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  hop  3  fanout"),
    box("  packet loss  7%"),
    box("  STATUS  alert sent"),
    box("  COMMIT  net flooded"),
    box("  ttl  6"),
    edge("="),
  })
end

local function backupRoute(title)
  return fit({
    "  route  " .. banner(title) .. "  pid " .. pid(),
    "  add  default  via " .. mem(),
    "  metric  1  prefsrc " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  neigh  solicited  4",
    "  packet loss  4%",
    "  STATUS  path open",
    "  COMMIT  backup routed",
    "  [rt]  end",
    "  pid " .. pid() .. "  wait",
    "  rtt  9ms",
  })
end

local function cameraIoctl(title)
  return fit({
    "  v4l  " .. banner(title) .. "  pid " .. pid(),
    "  ioctl  VIDIOC_STREAM  " .. mem(),
    "  grab  on  fd  3",
    "  " .. pair(),
    "  " .. pair(),
    "  frame  0  " .. mem(),
    "  frame  1  " .. mem(),
    "  packet loss  1%  csi",
    "  STATUS  feed owned",
    "  COMMIT  camera hijack",
    "  [v4l]  end",
    "  pid " .. pid() .. "  stream",
  })
end

local function cameraLink(title)
  return fit({
    edge("+"),
    box("  CSI  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  link  up  " .. mem()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  edid  ok  hijack"),
    box("  packet loss  0%"),
    box("  STATUS  lens owned"),
    box("  COMMIT  control taken"),
    box("  irq  18  hooked"),
    edge("+"),
  })
end

local function cameraPanic(title)
  return fit({
    "  KERNEL PANIC  skipped",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops:  soft  " .. mem(),
    "    [0] cam_isr+0x16",
    "  " .. pair(),
    "  " .. pair(),
    "  recover  hook  ok",
    "  stream  held",
    "  packet loss  2%",
    "  STATUS  still up",
    "  COMMIT  camera live",
    "  [cam]  end",
  })
end

local function turretCtl(title)
  return fit({
    "  turretd  " .. banner(title) .. "  pid " .. pid(),
    "  auth  token  " .. mem(),
    "  take  axis  pan  tilt",
    "  " .. pair(),
    "  " .. pair(),
    "  fire-ctl  armed  0",
    "  packet loss  3%  can0",
    "  setpoint  hold",
    "  STATUS  mount owned",
    "  COMMIT  turret seized",
    "  [turret]  end",
    "  pid " .. pid() .. "  idle",
  })
end

local function turretBus(title)
  return fit({
    edge("="),
    box("  CAN0  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  id  0x200  CLAIM"),
    box("  id  0x201  ACK  " .. mem()),
    box("  " .. pair()),
    box("  packet loss  5%"),
    box("  STATUS  bus master"),
    box("  COMMIT  mount locked"),
    box("  irq  33  ours"),
    box("  safeties  held"),
    edge("="),
  })
end

local function turretIrq(title)
  return fit({
    "  irq  " .. banner(title) .. "  pid " .. pid(),
    "  hook  33  at " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  steal  ok",
    "  old  isr  " .. mem(),
    "  packet loss  1%",
    "  STATUS  isr ours",
    "  COMMIT  turret hook",
    "  [irq]  end",
    "  pid " .. pid() .. "  run",
    "  ticks  40",
  })
end

local function distractUdp(title)
  return fit({
    "  noise  " .. banner(title) .. "  pid " .. pid(),
    "  udp  flood  " .. mem(),
    "  udp  flood  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  hops  2  bounce",
    "  packet loss  " .. tostring(math.random(5, 25)) .. "%",
    "  decoy  4  up",
    "  STATUS  attention pulled",
    "  COMMIT  distract live",
    "  [noise]  end",
    "  pid " .. pid() .. "  hold",
  })
end

local function distractArp(title)
  return fit({
    edge("+"),
    box("  ARP  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  who-has  " .. mem()),
    box("  is-at    " .. mem()),
    box("  " .. pair()),
    box("  cache  poison  3"),
    box("  packet loss  8%"),
    box("  STATUS  lure set"),
    box("  COMMIT  distract ok"),
    box("  ttl  2"),
    edge("+"),
  })
end

local function distractBeacon(title)
  return fit({
    "  beacon  " .. banner(title) .. "  pid " .. pid(),
    "  ssid  spoof  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  interval  50ms",
    "  packet loss  4%",
    "  clients  2  pulled",
    "  STATUS  decoy up",
    "  COMMIT  distract hold",
    "  [bcn]  end",
    "  pid " .. pid() .. "  tick",
    "  rssi  -50",
  })
end

local function explodeBus(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops:  ecu  overcurrent  " .. mem(),
    "    [0] cell_isr+0x08",
    "  " .. pair(),
    "  " .. pair(),
    "  pack  isolate  fail",
    "  * * *  END PANIC  * * *",
    "  packet loss  100%",
    "  STATUS  energy release",
    "  COMMIT  explode",
    "  [ecu]  end",
  })
end

local function explodeGpio(title)
  return fit({
    edge("="),
    box("  GPIO  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  line  CHARGE  " .. mem()),
    box("  line  FIRE    assert"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  irq  40  fire"),
    box("  STATUS  packed spent"),
    box("  COMMIT  explode ok"),
    box("  bus  dead"),
    edge("="),
  })
end

local function explodeCan(title)
  return fit({
    "  can0  " .. banner(title) .. "  pid " .. pid(),
    "  id  0x7FF  KILL  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  ack  none  bus-off",
    "  packet loss  100%",
    "  KERNEL PANIC  ecu gone",
    "  " .. mem() .. "  silent",
    "  STATUS  wreck",
    "  COMMIT  explode sent",
    "  [can]  end",
    "  pid " .. pid() .. "  exit",
  })
end

local function vehicleCan(title)
  return fit({
    "  ecu  " .. banner(title) .. "  pid " .. pid(),
    "  can0  take  " .. mem(),
    "  id  0x100  THROT  0",
    "  id  0x101  BRAKE  1",
    "  " .. pair(),
    "  " .. pair(),
    "  packet loss  " .. tostring(math.random(0, 18)) .. "%",
    "  STATUS  vehicle owned",
    "  COMMIT  bus master",
    "  [ecu]  end",
    "  pid " .. pid() .. "  hold",
    "  spd  0",
  })
end

local function vehicleBrake(title)
  return fit({
    edge("+"),
    box("  ABS  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  loop  lock  " .. mem()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  pwm  100%  hold"),
    box("  packet loss  2%"),
    box("  STATUS  wheels locked"),
    box("  COMMIT  brake forced"),
    box("  can0  ok"),
    edge("+"),
  })
end

local function vehiclePanic(title)
  return fit({
    "  KERNEL PANIC  skipped",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  ecu  soft  reset  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  recover  our  isr",
    "  packet loss  9%",
    "  throttle  clamp  0",
    "  STATUS  drive cut",
    "  COMMIT  hijack hold",
    "  [ecu]  end",
    "  pid " .. pid() .. "  run",
  })
end

local function unlockAuth(title)
  return fit({
    "  authd  " .. banner(title) .. "  pid " .. pid(),
    "  keyring  " .. mem() .. "  add",
    "  pam  bypass  1",
    "  " .. pair(),
    "  " .. pair(),
    "  lock  state  1 -> 0",
    "  gpio  BOLT  retract",
    "  packet loss  0%",
    "  STATUS  door open",
    "  COMMIT  unlock ok",
    "  [auth]  end",
    "  pid " .. pid() .. "  done",
  })
end

local function unlockNfc(title)
  return fit({
    edge("="),
    box("  NFC  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  uid  " .. mem() .. "  clone"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  crypto  skip"),
    box("  packet loss  0%"),
    box("  STATUS  latch free"),
    box("  COMMIT  unlock"),
    box("  field  on"),
    edge("="),
  })
end

local function unlockGpio(title)
  return fit({
    "  gpio  " .. banner(title) .. "  pid " .. pid(),
    "  line  LOCK  deassert  " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  irq  14  edge",
    "  debounce  ok",
    "  packet loss  0%",
    "  STATUS  open",
    "  COMMIT  bolt pulled",
    "  [gpio]  end",
    "  pid " .. pid() .. "  idle",
    "  state  0",
  })
end

local function overloadRail(title)
  return fit({
    "  pmicd  " .. banner(title) .. "  pid " .. pid(),
    "  VBUS  12.0 -> 18.4  over",
    "  IBUS  " .. tostring(math.random(20, 80)) .. "A  trip",
    "  " .. pair(),
    "  " .. pair(),
    "  KERNEL PANIC  overcurrent",
    "  at " .. mem(),
    "  isol  fail",
    "  packet loss  71%",
    "  STATUS  rail blown",
    "  COMMIT  overload",
    "  [pmic]  end",
  })
end

local function overloadIrq(title)
  return fit({
    edge("+"),
    box("  PSU  " .. banner(title) .. "  pid " .. pid()),
    edge("+"),
    box("  irq  OC  " .. mem()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  clamp  fail"),
    box("  packet loss  54%"),
    box("  STATUS  surge"),
    box("  COMMIT  overload ok"),
    box("  warn  thermal"),
    edge("+"),
  })
end

local function overloadPanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops:  psu  " .. mem(),
    "    [0] oc_isr+0x04",
    "  " .. pair(),
    "  " .. pair(),
    "  * * *  END PANIC  * * *",
    "  packet loss  88%",
    "  STATUS  brownout",
    "  COMMIT  overload latched",
    "  [oops]  end",
    "  pid " .. pid() .. "  dead",
  })
end

local function controlTake(title)
  return fit({
    "  ctl  " .. banner(title) .. "  pid " .. pid(),
    "  session  " .. mem() .. "  stolen",
    "  old  pid " .. pid() .. "  kicked",
    "  " .. pair(),
    "  " .. pair(),
    "  tty  hijack  ok",
    "  packet loss  1%",
    "  STATUS  remote owned",
    "  COMMIT  take control",
    "  [ctl]  end",
    "  pid " .. pid() .. "  master",
    "  fd  0 1 2  ours",
  })
end

local function controlNet(title)
  return fit({
    edge("="),
    box("  RSH  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  bind  " .. mem() .. "  22"),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  auth  none"),
    box("  packet loss  2%"),
    box("  STATUS  shell open"),
    box("  COMMIT  control held"),
    box("  tty  raw"),
    edge("="),
  })
end

local function controlIrq(title)
  return fit({
    "  irq  hook  " .. banner(title),
    "  pid " .. pid() .. "  vec " .. mem(),
    "  " .. pair(),
    "  " .. pair(),
    "  steal  isr  ok",
    "  packet loss  0%",
    "  STATUS  input ours",
    "  COMMIT  remote bind",
    "  [irq]  end",
    "  pid " .. pid() .. "  run",
    "  ticks  12",
    "  ack  1",
  })
end

local function genericPanic(title)
  return fit({
    "  * * *  KERNEL PANIC  * * *",
    "  " .. banner(title) .. "  pid " .. pid(),
    "  oops:  at " .. mem(),
    "    [0] sys_enter+0x3C",
    "    [1] irq_exit+0x0C",
    "  " .. pair(),
    "  " .. pair(),
    "  cr2=" .. mem(),
    "  packet loss  " .. tostring(math.random(10, 90)) .. "%",
    "  * * *  END PANIC  * * *",
    "  COMMIT  exec ok",
    "  [oops]  end",
  })
end

local function genericNet(title)
  return fit({
    "  netd  " .. banner(title) .. "  pid " .. pid(),
    "  sock  " .. mem() .. "  connect",
    "  " .. pair(),
    "  " .. pair(),
    "  rx  " .. tostring(math.random(100, 900)) .. "  tx  " .. tostring(math.random(100, 900)),
    "  packet loss  " .. tostring(math.random(2, 40)) .. "%",
    "  rtt  " .. tostring(math.random(1, 20)) .. "ms",
    "  drop  " .. tostring(math.random(0, 30)),
    "  STATUS  link dirty",
    "  COMMIT  run done",
    "  [net]  end",
    "  pid " .. pid() .. "  idle",
  })
end

local function genericHex(title)
  return fit({
    edge("="),
    box("  EXEC  " .. banner(title) .. "  pid " .. pid()),
    edge("-"),
    box("  ip  " .. mem()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  " .. pair()),
    box("  packet loss  " .. tostring(math.random(0, 25)) .. "%"),
    box("  STATUS  committed"),
    box("  COMMIT  ok"),
    box("  sess  " .. mem()),
    edge("="),
  })
end

local function genericIrq(title)
  return fit({
    "  irq  " .. banner(title) .. "  pid " .. pid(),
    "  vec  " .. mem() .. "  fire",
    "  " .. pair(),
    "  " .. pair(),
    "  ack  1  " .. mem(),
    "  packet loss  " .. tostring(math.random(0, 20)) .. "%",
    "  tick  4  ok",
    "  STATUS  handled",
    "  COMMIT  irq done",
    "  [irq]  end",
    "  pid " .. pid() .. "  yield",
    "  ip  " .. mem(),
  })
end

local CATALOG = {
  memorywipe = { dumpWipe, panicWipe, mapsWipe },
  overheat = { thermPanic, thermMsr, thermAcpi },
  shortcircuit = { busError, irqStorm, railDrop },
  synapse = { synPanic, synFlood, synWatch },
  rebootoptics = { opticReset, opticCrc, opticDma },
  weaponglitch = { weaponDma, weaponBus, weaponIrq },
  cyberware = { wareFw, wareI2c, warePanic },
  systemreset = { resetPanic, resetWatch, resetDump },
  suicide = { killSig, killInit, killOops },
  detonate = { fuseTimer, fuseCan, fusePanic },
  cripple = { motorPid, motorBus, motorPanic },
  ping = { pingIcmp, pingTrace, pingSock },
  whistle = { whistleUdp, whistleMesh, whistleRaw },
  contagion = { contagionSyn, contagionRoute, contagionPanic },
  sonic = { sonicIrq, sonicDma, sonicPanic },
  backup = { backupMesh, backupFlood, backupRoute },
  camera = { cameraIoctl, cameraLink, cameraPanic },
  turret = { turretCtl, turretBus, turretIrq },
  distract = { distractUdp, distractArp, distractBeacon },
  explode = { explodeBus, explodeGpio, explodeCan },
  vehicle = { vehicleCan, vehicleBrake, vehiclePanic },
  unlock = { unlockAuth, unlockNfc, unlockGpio },
  overload = { overloadRail, overloadIrq, overloadPanic },
  control = { controlTake, controlNet, controlIrq },
  generic = { genericPanic, genericNet, genericHex, genericIrq },
}

local function scriptFor(command)
  local title = titleOf(command)
  local family = familyOf(title)
  local variants = CATALOG[family]
  if variants == nil then
    variants = CATALOG.generic
  end
  return pick(variants)(title)
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

function Stream.push(command)
  if command == nil then
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
