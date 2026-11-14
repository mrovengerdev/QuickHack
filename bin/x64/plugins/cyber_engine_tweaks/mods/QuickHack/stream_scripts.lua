-- QuickHack stream script catalog. Loaded by stream.lua.
-- All generators live inside create() so this file stays under Lua's local limit.
local function create()
  local function mem()
    return string.format("0x%08X", math.random(0x10001000, 0x7FFFF000))
  end

  local function word()
    return string.format("%02X", math.random(0, 255))
  end

  local function banner(title)
    local name = string.upper(tostring(title or "QUICKHACK"))
    if #name > 28 then
      name = string.sub(name, 1, 28)
    end
    return name
  end

  local function ms()
    return tostring(math.random(400, 3600))
  end

  local function pad(s, width)
    s = tostring(s or "")
    if #s >= width then
      return string.sub(s, 1, width)
    end
    return s .. string.rep(" ", width - #s)
  end

  local function bar(filled, width)
    width = width or 16
    if filled < 0 then
      filled = 0
    end
    if filled > width then
      filled = width
    end
    return "[" .. string.rep("#", filled) .. string.rep(".", width - filled) .. "]"
  end

  local function meter(name, filled, suffix, width)
    return "    " .. pad(name, 5) .. " " .. bar(filled, width) .. "  " .. suffix
  end

  local function hexrow(base, zeros)
    local bytes = {}
    local i = 1
    while i <= 8 do
      if zeros then
        bytes[i] = "00"
      else
        bytes[i] = word()
      end
      i = i + 1
    end
    return "  " .. string.format("0x%06X", base) .. "  " .. table.concat(bytes, " ")
  end

  local function script(title, art, message, opts)
    opts = opts or {}
    local addr = opts.addr or mem()
    local exitcode = opts.exit or "0"
    local zeros = opts.zeros
    local custom = opts.hex
    local hexlines = opts.hexlines
    if hexlines == nil then
      if custom ~= nil then
        hexlines = #custom
      else
        hexlines = 2
      end
    end
    local base = opts.base or math.random(0x200000, 0xEFFFF0)
    local lines = {
      "  $ qh exec " .. banner(title) .. " --at " .. addr,
      "  running...",
    }
    local i = 1
    while i <= #art do
      lines[#lines + 1] = art[i]
      i = i + 1
    end
    lines[#lines + 1] = "  runtime      " .. ms() .. "ms"
    lines[#lines + 1] = "  exit         " .. exitcode
    lines[#lines + 1] = "  message      " .. message
    local h = 0
    while h < hexlines do
      if custom ~= nil and custom[h + 1] ~= nil then
        lines[#lines + 1] = "  " .. string.format("0x%06X", base + (h * 8)) .. "  " .. custom[h + 1]
      else
        lines[#lines + 1] = hexrow(base + (h * 8), zeros)
      end
      h = h + 1
    end
    lines[#lines + 1] = "  $"
    if #lines < 12 then
      table.remove(lines, #lines)
      while #lines < 11 do
        lines[#lines + 1] = hexrow(base + ((#lines) * 8), zeros)
      end
      lines[#lines + 1] = "  $"
    end
    if #lines > 16 then
      local cut = {}
      local keep = #lines - 16
      -- Drop extra art lines (starting at index 3) so the frame stays intact.
      local skip = keep
      local j = 1
      local k = 1
      while j <= #lines do
        if skip > 0 and j >= 3 and j < (#lines - (3 + hexlines)) then
          skip = skip - 1
        else
          cut[k] = lines[j]
          k = k + 1
        end
        j = j + 1
      end
      lines = cut
    end
    return lines
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

  local CATALOG = {}

  local function add(family, fn)
    local list = CATALOG[family]
    if list == nil then
      list = {}
      CATALOG[family] = list
    end
    list[#list + 1] = fn
  end

  add("memorywipe", function(title)
    return script(title, {
      meter("mem", 0, "0K"),
      meter("wipe", 16, "100%"),
    }, "TARGET MEMORY EMPTIED", { zeros = true, hexlines = 4 })
  end)

  add("memorywipe", function(title)
    return script(title, {
      "    page  0  " .. bar(0) .. "  EMPTY",
      "    page  1  " .. bar(0) .. "  EMPTY",
      "    page  2  " .. bar(0) .. "  EMPTY",
      "    page  3  " .. bar(0) .. "  EMPTY",
      meter("free", 16, "100%"),
    }, "ALL PAGES ZEROED", { zeros = true, hexlines = 4 })
  end)

  add("overheat", function(title)
    return script(title, {
      meter("fan", 0, "OFF"),
      meter("temp", 16, tostring(math.random(120, 148)) .. "C  WARNING"),
      meter("rail", 14, "TRIP"),
      meter("pwr", 15, "1.21V"),
      meter("loss", math.random(2, 5), tostring(math.random(12, 28)) .. "%"),
    }, "FAN HALTED - TEMP WARNING")
  end)

  add("overheat", function(title)
    local temp = tostring(math.random(124, 148))
    return script(title, {
      meter("fan", 0, "OFF"),
      "    tmp     40 |",
      "            80 |########",
      "           " .. temp .. " |################",
      "                  WARNING",
      "    rail  TRIP",
    }, "FAN OFF - THERMAL WARNING")
  end)

  add("shortcircuit", function(title)
    return script(title, {
      "    vbus  13.8V  ##############",
      "    vbus   0.1V  #",
      meter("amp", 16, "FAULT"),
      "    spark *  *    * *     *",
    }, "BUS FAULT LATCHED")
  end)

  add("shortcircuit", function(title)
    return script(title, {
      "    rail  VCC ---x--- GND",
      "              SHORT",
      meter("i", 16, "48A"),
      meter("prot", 0, "BLOWN"),
    }, "RAIL COLLAPSED TO GROUND")
  end)

  add("synapse", function(title)
    return script(title, {
      "    sig   /\\_/\\    /\\_/\\",
      "          \\   \\_/\\/    \\_",
      meter("thr", 16, "MAX"),
      meter("lock", 16, "SEIZE"),
    }, "SYNAPTIC LOCK SEIZED")
  end)

  add("synapse", function(title)
    return script(title, {
      "    spike |      *",
      "          |     * *",
      "          | *  *   *  *",
      "          |* *       *",
      meter("thr", 16, "MAX"),
    }, "NEURAL SPIKE SATURATED")
  end)

  add("rebootoptics", function(title)
    return script(title, {
      "    vis   +----------------+",
      "          |##########      |",
      "          |    ##########  |",
      "          |        ######  |",
      "          +----------------+",
      meter("sync", 0, "LOST"),
    }, "OPTICS REBOOT ISSUED")
  end)

  add("rebootoptics", function(title)
    return script(title, {
      meter("vis", 0, "BLACK"),
      "    scan  ====  ====  ====",
      "          ----  ----  ----",
      meter("link", 0, "DOWN"),
      meter("boot", 16, "RESTART"),
    }, "OPTIC BUS RESTARTED")
  end)

  add("weaponglitch", function(title)
    return script(title, {
      "    fire  [>               ]  JAM",
      "    ammo  [? ? ? ?         ]",
      "    bolt  [####----####----]  DESYNC",
    }, "FIRING CYCLE DESYNCED")
  end)

  add("weaponglitch", function(title)
    return script(title, {
      "    cyl   [##] [  ] [##] [  ]",
      meter("feed", 0, "STUCK"),
      meter("safe", 16, "ON"),
      "    fire  --------x--------",
    }, "FEED JAMMED - SAFE FORCED")
  end)

  add("cyberware", function(title)
    return script(title, {
      meter("fw", 0, "BRICK"),
      "    i2c   * --x-- * --x-- *",
      meter("nlink", 16, "SEIZE"),
    }, "CYBERWARE BUS SEIZED")
  end)

  add("cyberware", function(title)
    return script(title, {
      "    impl  CORE --x-- LIMB",
      meter("ctl", 16, "OVERRIDE"),
      meter("ack", 0, "NONE"),
      meter("loop", 16, "OPEN"),
    }, "IMPLANT CONTROL OVERRIDDEN")
  end)

  add("systemreset", function(title)
    return script(title, {
      meter("cpu0", 0, "HALT"),
      meter("cpu1", 0, "HALT"),
      meter("svc", 0, "DOWN"),
      "    boot  [            *   ]  WAIT",
    }, "SYSTEM RESET COMMITTED")
  end)

  add("systemreset", function(title)
    return script(title, {
      "    run   * * * * * * * *",
      "    halt  x x x x x x x x",
      meter("init", 0, "REAPED"),
      meter("fs", 0, "UNMOUNTED"),
    }, "ALL SERVICES HALTED")
  end)

  add("suicide", function(title)
    return script(title, {
      meter("proc", 16, "TERM"),
      meter("wd", 16, "FORCE"),
      "    init  reaped",
      meter("life", 0, "STOP"),
    }, "PROCESS FORCE-HALTED")
  end)

  add("suicide", function(title)
    return script(title, {
      "    pid   [##########------]  KILL",
      "    tree  init",
      "            +-- target  x",
      "            +-- child   x",
      meter("sig", 16, "TERM"),
    }, "WATCHDOG REAPED TARGET")
  end)

  add("detonate", function(title)
    return script(title, {
      "    t-3   " .. bar(4),
      "    t-2   " .. bar(8),
      "    t-1   " .. bar(12),
      "    t-0   " .. bar(16) .. "  FIRE",
    }, "FUSE COMPLETE - FIRE")
  end)

  add("detonate", function(title)
    return script(title, {
      meter("fuse", 16, "0.0s"),
      "    arm   *  *  *  *  *  *",
      meter("cap", 16, "MAX"),
    }, "CHARGE RELEASED")
  end)

  add("cripple", function(title)
    return script(title, {
      meter("Lhip", 0, "LOCK"),
      meter("Lkn", 0, "LOCK"),
      meter("Rhip", 0, "LOCK"),
      meter("Rkn", 0, "LOCK"),
      "    gait  -- x -- x -- x --",
    }, "MOTORS LOCKED")
  end)

  add("cripple", function(title)
    return script(title, {
      "    step  L --x-- R --x-- L",
      meter("drv", 0, "CUT"),
      meter("bal", 0, "LOST"),
      meter("hold", 16, "RIGID"),
    }, "MOVEMENT DRIVE CUT")
  end)

  add("ping", function(title)
    return script(title, {
      "    hop 1  " .. mem() .. "  [####]  " .. tostring(math.random(1, 3)) .. "ms",
      "    hop 2  " .. mem() .. "  [####]  " .. tostring(math.random(3, 6)) .. "ms",
      "    hop 3  " .. mem() .. "  [####]  " .. tostring(math.random(6, 9)) .. "ms",
      "    hop 4  " .. mem() .. "  [*]     ttl",
      meter("loss", 0, "0%"),
    }, "HOST REACHED - 4 HOPS")
  end)

  add("ping", function(title)
    return script(title, {
      "      * -- * -- * -- *",
      "                |",
      "              (you)",
      "    rtt   2ms  5ms  8ms  11ms",
      meter("loss", 0, "0%"),
    }, "ECHO PATH MAPPED")
  end)

  add("whistle", function(title)
    return script(title, {
      "    call  ~    ~    ~    ~",
      "         ~  ~    ~    ~",
      meter("rng", 14, "WIDE"),
      "    ack   " .. tostring(math.random(4, 9)) .. "  NODES",
    }, "BEACON BROADCAST")
  end)

  add("whistle", function(title)
    return script(title, {
      "    tone  /\\    /\\    /\\",
      "          \\/    \\/    \\/",
      meter("tx", 16, "MAX"),
      meter("hear", 16, "LOCK"),
    }, "ATTRACT SIGNAL LOCKED")
  end)

  add("contagion", function(title)
    return script(title, {
      "        A *----* B",
      "          |      |",
      "        C *----* D",
      meter("spread", 16, "100%"),
      "    hosts  4 / 4  INFECTED",
    }, "PAYLOAD PROPAGATED")
  end)

  add("contagion", function(title)
    return script(title, {
      "    seed  * -- * -- * -- *",
      "                |",
      "                * -- *",
      meter("spread", 16, "100%"),
      "    hosts  6 / 6  INFECTED",
    }, "ALL NODES INFECTED")
  end)

  add("contagion", function(title)
    return script(title, {
      "        A-T    T-A    G-C    C-G",
      "         \\      /      \\      /",
      "          T-A  A-T    C-G  G-C",
      "        ========================",
      "        COPY   COPY   COPY  COPY",
      meter("spread", 16, "100%"),
    }, "STRAND REPLICATED HOST-WIDE", {
      hex = { "C0 17 A1 90 FF FF 00 04", "41 54 47 43 41 54 47 43" },
    })
  end)

  add("sonic", function(title)
    return script(title, {
      "     2k  ##",
      "     4k  ######",
      "     8k  ##############",
      "    16k  ################",
      meter("hz", 16, "PEAK"),
    }, "SONIC PEAK COMMITTED")
  end)

  add("sonic", function(title)
    return script(title, {
      "    wav   /\\/\\/\\/\\/\\/\\/\\/\\",
      "          \\/\\/\\/\\/\\/\\/\\/\\/",
      meter("spl", 16, "MAX"),
      meter("ear", 16, "OVER"),
    }, "AUDIO PATH OVERDRIVEN")
  end)

  add("backup", function(title)
    return script(title, {
      "    node  * <-- * <-- *",
      "              ^",
      "              *",
      meter("link", 16, "UP"),
      "    units 3 / 3  ARRIVED",
    }, "BACKUP UNITS LINKED")
  end)

  add("backup", function(title)
    return script(title, {
      meter("call", 16, "SENT"),
      "    u1    [################]  HERE",
      "    u2    [################]  HERE",
      "    u3    [################]  HERE",
    }, "REINFORCEMENT ARRIVED")
  end)

  add("camera", function(title)
    return script(title, {
      "    feed  +----------------+",
      "          |  NO SIGNAL     |",
      "          |  ############  |",
      "          +----------------+",
      meter("link", 0, "DOWN"),
    }, "CAMERA FEED DROPPED")
  end)

  add("camera", function(title)
    return script(title, {
      "    cam0  [XXXXXXXXXXXXXXXX]  DEAD",
      "    cam1  [XXXXXXXXXXXXXXXX]  DEAD",
      "    cam2  [XXXXXXXXXXXXXXXX]  DEAD",
      meter("link", 0, "DOWN"),
    }, "ALL CAMERAS BLANKED")
  end)

  add("turret", function(title)
    return script(title, {
      "          \\       /",
      "            \\   /",
      "          --- + ---",
      "            /   \\",
      "          /       \\",
      meter("aim", 16, "LOCK"),
    }, "TURRET AIM OVERRIDDEN")
  end)

  add("turret", function(title)
    return script(title, {
      "    yaw   <---------*----->",
      meter("arc", 16, "SWEEP"),
      meter("fire", 16, "AUTO"),
      meter("iff", 0, "OFF"),
    }, "IFF DISABLED - AUTO FIRE")
  end)

  add("distract", function(title)
    return script(title, {
      "    decoy *     *     *",
      "       *     *     *",
      meter("noise", 16, "MAX"),
    }, "DECOY BURST SENT")
  end)

  add("distract", function(title)
    return script(title, {
      "    blip  .  *  .  *  .  *",
      "          *  .  *  .  *  .",
      meter("att", 16, "PULLED"),
      meter("src", 0, "HIDDEN"),
    }, "ATTENTION PULLED AWAY")
  end)

  add("explode", function(title)
    return script(title, {
      meter("pres", 16, "RUPTURE"),
      "     (  *  *  *  *  *  )",
      "      ( * * * * * * * )",
      meter("cap", 16, "DUMP"),
    }, "PRESSURE VESSEL RUPTURED")
  end)

  add("explode", function(title)
    return script(title, {
      "    cell  [####] [####] [####]",
      "          boom   boom   boom",
      meter("arm", 16, "HOT"),
      meter("out", 16, "OPEN"),
    }, "CELLS DUMPED")
  end)

  add("vehicle", function(title)
    return script(title, {
      meter("spd", 12, "87"),
      meter("brake", 0, "CUT"),
      meter("thr", 16, "MAX"),
      meter("steer", 4, "LOCK"),
    }, "BRAKES CUT - STEER LOCKED")
  end)

  add("vehicle", function(title)
    return script(title, {
      "    can   ECU --x-- BRK",
      "            '--x-- STR",
      meter("ctl", 16, "TAKE"),
      meter("hand", 0, "LOST"),
    }, "VEHICLE BUS HIJACKED")
  end)

  add("unlock", function(title)
    return script(title, {
      meter("auth", 16, "OK"),
      "    latch [..........>>>>>>]  OPEN",
      "    door  [ ]====  ]",
    }, "LATCH RELEASED")
  end)

  add("unlock", function(title)
    return script(title, {
      "    pin   * * * *  ACCEPTED",
      meter("bolt", 0, "CLEAR"),
      meter("mag", 0, "OFF"),
      meter("door", 16, "OPEN"),
    }, "LOCK CLEARED - DOOR OPEN")
  end)

  add("overload", function(title)
    return script(title, {
      meter("railA", 16, "WARNING"),
      meter("railB", 16, "WARNING"),
      meter("draw", 16, "240%"),
      meter("prot", 0, "BYPASS"),
    }, "POWER RAILS OVERLOADED")
  end)

  add("overload", function(title)
    return script(title, {
      "    grid  *====*====*",
      "          ||   ||   ||",
      "          *====*====*",
      meter("load", 16, "MAX"),
      meter("brk", 0, "OPEN"),
    }, "GRID LOAD AT MAXIMUM")
  end)

  add("control", function(title)
    return script(title, {
      "    user  [local] --x--> [remote]",
      meter("sess", 16, "TAKEN"),
      meter("ctl", 16, "OWN"),
    }, "SESSION TAKEN")
  end)

  add("control", function(title)
    return script(title, {
      "    pipe  src ==== dst",
      "                attached",
      meter("own", 16, "REMOTE"),
      meter("loc", 0, "CUT"),
    }, "REMOTE PIPE ATTACHED")
  end)

  add("control", function(title)
    return script(title, {
      "    ICE   ################",
      "          ######  ##  ####",
      "          ####        ####",
      "          ##   ****     ##",
      "          ****************",
      meter("hole", 16, "OPEN"),
    }, "ICE WALL BREACHED", {
      hex = { "49 43 45 00 00 00 00 00", "00 00 DE AD 00 00 00 00" },
    })
  end)

  add("generic", function(title)
    return script(title, {
      meter("job", 16, "DONE"),
      meter("buf", 12, "76%"),
      meter("loss", math.random(0, 3), tostring(math.random(0, 8)) .. "%"),
    }, "EXECUTION COMPLETE")
  end)

  add("generic", function(title)
    return script(title, {
      "    path  * -- * -- * -- *",
      meter("ok", 16, "PASS"),
      meter("ret", 16, "0x00"),
    }, "TARGET ROUTINE RETURNED")
  end)

  -- RAM-fail output: nothing is sent. The allocation stops at the first X
  -- in the RAM bar and the line after it calls out the missing memory.
  local FAIL_TARGET = {
    memorywipe = "wipe.pages",
    overheat = "heat.cycle",
    shortcircuit = "vbus.arm",
    synapse = "synapse.lock",
    rebootoptics = "optics.boot",
    weaponglitch = "weapon.jam",
    cyberware = "cyberware.bus",
    systemreset = "cpu.reset",
    suicide = "proc.term",
    detonate = "fuse.arm",
    cripple = "motor.lock",
    ping = "net.probe",
    whistle = "beacon.tx",
    contagion = "payload.seed",
    sonic = "sonic.burst",
    backup = "backup.call",
    camera = "feed.cut",
    turret = "turret.iff",
    distract = "decoy.emit",
    explode = "charge.arm",
    vehicle = "can.bus",
    unlock = "latch.open",
    overload = "rail.surge",
    control = "ice.breach",
    generic = "job.alloc",
  }

  local function whole(n)
    if type(n) ~= "number" then
      return 0
    end
    n = math.floor(n + 0.001)
    if n < 0 then
      return 0
    end
    return n
  end

  local FAIL_CALLER = {
    contagion = "contagion.spread",
    memorywipe = "memorywipe.run",
    overheat = "overheat.burn",
    shortcircuit = "shortcircuit.zap",
    synapse = "synapse.burn",
    ping = "ping.sweep",
  }

  local function writeFail(title, available, cost)
    local family = familyOf(title)
    local target = FAIL_TARGET[family] or FAIL_TARGET.generic
    local caller = FAIL_CALLER[family] or (family .. ".run")
    local a = whole(available)
    local c = whole(cost)
    local short = c - a
    local maxv = c
    if a > maxv then
      maxv = a
    end
    if maxv < 1 then
      maxv = 1
    end
    local filled = math.floor(16 * a / maxv + 0.5)
    if filled > 15 then
      filled = 15
    end
    local base = math.random(0x10001000, 0x7FFF0000)
    base = base - (base % 16)
    local fault = base + a
    local hex = function(n) return string.format("0x%08X", n) end

    -- One cell per RAM unit of cost. Long costs show a 12-cell window that
    -- always contains the first unallocated cell.
    local first = 0
    if c > 12 and a > 8 then
      first = a - 8
    end
    local last = c - 1
    if last > first + 11 then
      last = first + 11
    end
    local prefix = "  map      " .. hex(base + first) .. "  "
    if first > 0 then
      prefix = prefix .. ".."
    end
    local cells = {}
    local caretCol = #prefix + 1
    local i = first
    while i <= last do
      if i == a then
        caretCol = #prefix + #table.concat(cells) + 3
      end
      if i < a then
        cells[#cells + 1] = "[###]"
      else
        cells[#cells + 1] = "[ ? ]"
      end
      i = i + 1
    end
    local mapLine = prefix .. table.concat(cells)
    if last < c - 1 then
      mapLine = mapLine .. ".."
    end
    local caretLine = string.rep(" ", caretCol - 1) .. "^ " .. hex(fault) .. "  UNALLOCATED"

    return {
      "  $ qh exec " .. banner(title) .. " --at " .. hex(base),
      "  ram    [" .. string.rep("#", filled) .. "X",
      "  !!!!!!!! FATAL: UNALLOCATED RAM !!!!!!!!",
      "  SIGSEGV  heap fault at " .. hex(fault),
      "  alloc    " .. target .. "  req " .. tostring(c) .. "U  have " .. tostring(a) .. "U  short " .. tostring(short) .. "U",
      mapLine,
      caretLine,
      "  trace",
      "    #0  " .. hex(fault) .. "  " .. target .. string.format("+0x%02X", a) .. "   <-- NO RAM",
      "    #1  " .. hex(base - 0x28) .. "  " .. caller .. "+0x1C",
      "    #2  " .. hex(base - 0xA0) .. "  qh.exec+0x40",
      "    #3  " .. hex(base - 0xB0) .. "  daemon.main",
      "  !!!!!!!! RAM SHORTAGE  " .. tostring(short) .. "U MISSING !!!!!!!!",
      "  exit 12  SIGSEGV",
      "  $",
    }
  end

  -- The game refused the hack for a reason other than RAM: cooldown, already
  -- uploading, blocked, and so on. Says so plainly so it is never read as a
  -- RAM shortage.
  local function writeBlocked(title, reason)
    local family = familyOf(title)
    local target = FAIL_TARGET[family] or FAIL_TARGET.generic
    local base = math.random(0x10001000, 0x7FFF0000)
    base = base - (base % 16)
    local hex = function(n) return string.format("0x%08X", n) end
    local why = reason
    if type(why) ~= "string" or why == "" then
      why = "UNKNOWN"
    end
    return {
      "  $ qh exec " .. banner(title) .. " --at " .. hex(base),
      "  lock   [################]",
      "  !!!!!!!! FATAL: EXECUTION BLOCKED !!!!!!!!",
      "  EBUSY    lock held on " .. target .. " at " .. hex(base),
      "  reason   " .. string.upper(why),
    }
  end

  local function write(title)
    local family = familyOf(title)
    local variants = CATALOG[family]
    if variants == nil then
      variants = CATALOG.generic
    end
    return variants[math.random(1, #variants)](title)
  end

  return { write = write, writeFail = writeFail, writeBlocked = writeBlocked }
end

return create()
