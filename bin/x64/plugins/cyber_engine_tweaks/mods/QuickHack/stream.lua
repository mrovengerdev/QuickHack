local Stream = {}

local LINES = 14
local LINE_H = 22
local LEFT = 36
local TOP = 150
local WIDTH = 640
local CHARS_PER_SEC = 92
local SCROLL_PX_PER_SEC = 18
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

local function pid()
  return tostring(200 + math.random(0, 7800))
end

local function pick(variants)
  return variants[math.random(1, #variants)]
end

local function committed(title)
  return "> " .. title .. " committed"
end

local function has(text, token)
  return string.find(text, token, 1, true) ~= nil
end

local function pingVariants()
  local ip = randomIp()
  return {
    {
      "> ping -f " .. ip,
      "PING " .. ip .. " (" .. ip .. "): 56 data bytes",
      string.format("64 bytes from %s: icmp_seq=1 ttl=54 time=9.2 ms", ip),
      string.format("64 bytes from %s: icmp_seq=2 ttl=54 time=8.7 ms", ip),
      "flooding ................ ok",
      "1000 packets/s",
      "icmp_seq overflow",
      string.format("--- %s ping statistics ---", ip),
      "4096 packets transmitted, 4096 received, 0% packet loss",
    },
    {
      "> traceroute " .. ip,
      "traceroute to subnet-node (" .. ip .. "), 16 hops max",
      " 1  gateway (" .. randomIp() .. ")  1.4 ms",
      " 2  edge-fw (" .. randomIp() .. ")  4.8 ms",
      " 3  subnet-node (" .. ip .. ")  9.1 ms",
      "> nslookup " .. ip,
      "Name:    subnet-node",
      "Address: " .. ip,
      "trace complete",
    },
    {
      "> nmap -sS " .. ip,
      "Starting Nmap 7.94",
      "Host is up (0.0091s latency).",
      "PORT     STATE SERVICE",
      "22/tcp   open  ssh",
      "443/tcp  open  https",
      "6148/tcp open  net-access",
      "MAC Address: " .. string.format("%02X:%02X:%02X:%02X:%02X:%02X", math.random(16, 255), octet(), octet(), octet(), octet(), octet()),
      "Nmap done: 1 IP address (1 host up)",
    },
  }
end

local function overheatVariants(title, target)
  return {
    {
      "> ddos --target " .. target .. " --vector heat",
      "opening 4096 sockets",
      "syn flood ................ ok",
      "connection table overflow",
      "thermal governor bypassed",
      "core temp 41C -> 118C",
      "coolant_loop killed",
      committed(title),
    },
    {
      "> fork --bomb --target " .. target,
      "pid " .. pid() .. " exec /bin/forkbomb",
      "[fork] spawning worker 0",
      "[fork] spawning worker 1",
      "[fork] spawning worker " .. tostring(math.random(200, 900)),
      "E: process table full",
      "sched: runqueue jammed",
      "thermal trip at 121C",
      committed(title),
    },
    {
      "> sysctl -w kernel.cpu.turbo=unsafe",
      "unlocking turbo_override on " .. target,
      "clock 3.20 GHz -> 6.80 GHz",
      "warning: Tjmax exceeded",
      "msr[" .. addr() .. "] = 0xDEAD",
      "throttle watchdog disabled",
      "core temp 44C -> 126C",
      committed(title),
    },
  }
end

local function shortCircuitVariants(title, target)
  return {
    {
      "> gpio write " .. target .. " rail=vcore value=0",
      "exporting pin 47",
      "direction=out",
      "brownout detector masked",
      "vcore 1.10V -> 0.31V",
      "I2C NACK on pmic",
      "rail collapsed",
      committed(title),
    },
    {
      "> dd if=/dev/urandom of=/dev/bus/" .. target .. " bs=4k",
      "writing noise into power-management bus",
      "xfer[" .. addr() .. "] fault",
      "smbus timeout",
      "overcurrent on 12V rail",
      "protection FET opened",
      committed(title),
    },
    {
      "> busybox devmem " .. addr() .. " 32 0xFFFFFFFF",
      "poking PMIC register map",
      "wdog feed stopped",
      "IRQn 12: undervolt",
      "cpu0 entered reset hold",
      committed(title),
    },
  }
end

local function synapseVariants(title, target)
  return {
    {
      "> kill -9 $(pgrep neural) --host " .. target,
      "neural-core pid=" .. pid(),
      "sending SIGKILL",
      "stack smash detected",
      "synapse ring buffer overrun",
      "core dumped to /tmp/neural.core",
      committed(title),
    },
    {
      "> gdb -p " .. pid() .. " -batch -ex 'jump *0x0'",
      "attaching to synapse daemon",
      "0x00000000 in ?? ()",
      "pc corrupted",
      "watchdog: neural thread dead",
      committed(title),
    },
    {
      "> python3 -c 'import ctypes; ctypes.memset(" .. addr() .. ", 0, 4096)'",
      "zeroing synaptic page",
      "page fault in irq context",
      "oops: unable to handle kernel paging request",
      "neural bus offline",
      committed(title),
    },
  }
end

local function contagionVariants(title, target)
  return {
    {
      "> worm --seed " .. target .. " --spread subnet",
      "payload written to /tmp/.c.bin",
      "copying to 10.0.0.0/24",
      "hop 1 ok  hop 2 ok  hop 3 ok",
      "lateral ssh: 14 hosts",
      "replication locked in",
      committed(title),
    },
    {
      "> sendmail -t --inject " .. target,
      "HELO subnet-node",
      "MAIL FROM:<root@local>",
      "250 2.0.0 Ok: queued",
      "relay open, 96 recipients",
      "daemon still running",
      committed(title),
    },
    {
      "> ssh-copy-id -i ~/.ssh/exploit root@" .. randomIp(),
      "scanning authorized_keys",
      "host key accepted (insecure)",
      "dropping payload in crontab",
      "* * * * * /tmp/.spread",
      committed(title),
    },
  }
end

local function opticsVariants(title, target)
  return {
    {
      "> systemctl stop display-manager@" .. target,
      "stopping Xorg",
      "framebuffer unmapped",
      "drm: failed to enable crtc",
      "output blacked out",
      committed(title),
    },
    {
      "> fbset --invert --device " .. target,
      "inverting scanout",
      "edid checksum invalid",
      "colorspace=scrambled",
      "vsync lost",
      committed(title),
    },
    {
      "> ffmpeg -f lavfi -i anoisesrc=c=pink -f fbdev /dev/fb0",
      "injecting noise into optics pipeline",
      "buffer underrun",
      "camera isp stalled",
      "lens data: NaN",
      committed(title),
    },
  }
end

local function cyberwareVariants(title, target)
  return {
    {
      "> rmmod -f biomon servo_ctl --host " .. target,
      "module servo_ctl is in use",
      "forcing remove",
      "firmware handshake lost",
      "ioctl(BIO_RESET) failed: EIO",
      committed(title),
    },
    {
      "> flashrom -p internal -w /tmp/corrupt.bin",
      "erasing chip",
      "verify failed at " .. addr(),
      "firmware signature invalid",
      "device left in ROM recovery",
      committed(title),
    },
    {
      "> ioctl /dev/cw0 CW_FAULT 1",
      "raising fault pin",
      "self-test aborted",
      "all implants reporting DEGRADED",
      committed(title),
    },
  }
end

local function movementVariants(title, target)
  return {
    {
      "> systemctl mask locomotion@" .. target,
      "freezing servos",
      "pid hold on joints 0-11",
      "encoder timeout",
      "legs parked",
      committed(title),
    },
    {
      "> canbus inject " .. target .. " id=0x1A0 data=FF",
      "actuator bus jammed",
      "safety interlock latched",
      "torque cmd dropped to 0",
      committed(title),
    },
    {
      "> gdb -p " .. pid() .. " -ex 'p walk_enabled=0'",
      "attached to gaitd",
      "walk_enabled = 0",
      "state=LIMB_LOCK",
      committed(title),
    },
  }
end

local function weaponVariants(title, target)
  return {
    {
      "> fwupd --device " .. target .. " --flag jam",
      "firing-pin solenoid jammed",
      "ammo table crc mismatch",
      "trigger irq ignored",
      committed(title),
    },
    {
      "> hexedit /dev/weapon0",
      "rewriting ammo map at " .. addr(),
      "chamber=UNKNOWN",
      "safety bits flipped",
      "cycle aborted",
      committed(title),
    },
    {
      "> evdev grab /dev/input/trigger",
      "exclusive grab ok",
      "dropping all fire events",
      "userspace trigger offline",
      committed(title),
    },
  }
end

local function psychosisVariants(title, target)
  return {
    {
      "> systemctl restart affectd@" .. target .. " --flood",
      "forking emotion daemon x64",
      "affect table scrambled",
      "aggression=MAX fear=0",
      committed(title),
    },
    {
      "> python3 /opt/net/emote.py --seed random",
      "loading weights",
      "NaN in softmax",
      "policy head diverged",
      "inhibitory path cut",
      committed(title),
    },
    {
      "> sysctl -w net.neural.align=0",
      "alignment supervisor disabled",
      "watchdog ignored SIGSYS",
      "process left unjailed",
      committed(title),
    },
  }
end

local function suicideVariants(title, target)
  return {
    {
      "> shutdown -h now " .. target,
      "Broadcast message from root",
      "The system is going down NOW!",
      "init: sending SIGTERM to all",
      "poweroff",
      committed(title),
    },
    {
      "> echo 1 > /proc/sys/kernel/panic_on_oops",
      "watchdog: BUG: soft lockup",
      "Kernel panic - not syncing",
      "rebooting in 0 seconds",
      committed(title),
    },
    {
      "> kill -9 1",
      "refusing to kill init; forcing",
      "pid 1 exited",
      "no more processes",
      "halted",
      committed(title),
    },
  }
end

local function resetVariants(title, target)
  return {
    {
      "> shutdown -r now " .. target,
      "Rebooting.",
      "unmounting /data",
      "kexec load failed, falling back",
      "BIOS reset",
      committed(title),
    },
    {
      "> fsck -f -y /dev/mapper/system",
      "superblock dirty",
      "inode table rebuilt",
      "FILE SYSTEM WAS MODIFIED",
      "remount required",
      committed(title),
    },
    {
      "> systemctl isolate rescue.target",
      "stopping all non-essential units",
      "dropped to rescue shell",
      "network offline",
      committed(title),
    },
  }
end

local function sonicVariants(title, target)
  return {
    {
      "> aplay -D " .. target .. " /dev/urandom",
      "Playing raw data 'urandom' : Signed 16 bit",
      "buffer underrun, period dropped",
      "amp clip @ +12dB",
      "cochlea irq storm",
      committed(title),
    },
    {
      "> alsactl restore --force",
      "overwriting mixer state",
      "master=127 gain=unsafe",
      "dc offset on line-out",
      "driver stalled",
      committed(title),
    },
    {
      "> sox -n -t alsa " .. target .. " synth 8 sine 18k",
      "frequency sweep 18k -> 22k",
      "sample rate drifted",
      "underrun x44",
      committed(title),
    },
  }
end

local function whistleVariants(title, target)
  return {
    {
      "> arping -c 256 -A " .. randomIp(),
      "broadcasting gratuitous ARP",
      "cache poisoned on 14 hosts",
      "beacon interval=10ms",
      committed(title),
    },
    {
      "> nping --icmp --rate 200 " .. randomIp(),
      "redirect flood",
      "gateway changed",
      "hosts following decoy",
      committed(title),
    },
    {
      "> avahi-publish -s " .. target .. " _alert._tcp 9",
      "service registered",
      "mdns spam",
      "listeners converging",
      committed(title),
    },
  }
end

local function memoryVariants(title, target)
  return {
    {
      "> shred -n 3 -z /dev/shm/*",
      "wiping shared pages on " .. target,
      "drop_caches = 3",
      "0kB available in kmem",
      committed(title),
    },
    {
      "> dd if=/dev/zero of=/proc/" .. pid() .. "/mem",
      "zeroing process address space",
      "segfault in userspace",
      "oom-killer invoked",
      committed(title),
    },
    {
      "> echo 1 > /proc/sys/vm/compact_memory",
      "purging reclaimable slabs",
      "swapout forced",
      "working set gone",
      committed(title),
    },
  }
end

local function detonateVariants(title, target)
  return {
    {
      "> squib arm --id " .. target,
      "primer voltage 0.0V -> 12.4V",
      "safety cap removed",
      "fire",
      committed(title),
    },
    {
      "> i2cset 0x40 0x01 0xFF",
      "overvolting detonator cap",
      "esr out of range",
      "thermal runaway",
      committed(title),
    },
    {
      "> cansend can0 1F0#DEADBEEF",
      "injecting arm command",
      "ack received",
      "charge armed",
      committed(title),
    },
  }
end

local function distractVariants(title, target)
  return {
    {
      "> systemd-run --on-active=0 decoy@" .. target,
      "spawned fake process tree",
      "tty flood on vt3",
      "attention diverted",
      committed(title),
    },
    {
      "> logger -p kern.emerg 'FIRE ALARM'",
      "broadcast to wall(1)",
      "console bell x12",
      "alerts acknowledged",
      committed(title),
    },
    {
      "> gpio strobe --pin 3 --hz 18",
      "beacon lit",
      "photodiode saturated",
      "watchers turning",
      committed(title),
    },
  }
end

local function controlVariants(title, target)
  return {
    {
      "> gdb -p " .. pid() .. " --eval-command='set $pc=&shell'",
      "attaching to " .. target,
      "tty hijack complete",
      "root prompt on pts/0",
      committed(title),
    },
    {
      "> ssh -t root@" .. randomIp() .. " 'exec script -c bash'",
      "host key warning ignored",
      "PTY allocated",
      "session is ours",
      committed(title),
    },
    {
      "> nsenter -t " .. pid() .. " -m -u -i -n /bin/sh",
      "entered container namespace",
      "uid=0 gid=0",
      "control socket open",
      committed(title),
    },
  }
end

local function cameraVariants(title, target)
  return {
    {
      "> v4l2-ctl -d " .. target .. " --overlay=1",
      "taking over scanout",
      "ptz unlocked",
      "feed hooked",
      committed(title),
    },
    {
      "> ffmpeg -i rtmp://local/cam -f fbdev /dev/fb0",
      "replacing live feed",
      "keyframes injected",
      "operator view spoofed",
      committed(title),
    },
    {
      "> systemctl stop motion@" .. target,
      "analytics paused",
      "lens parked",
      "recording stopped",
      committed(title),
    },
  }
end

local function powerVariants(title, target)
  return {
    {
      "> systemctl stop " .. target,
      "stopping unit",
      "sent SIGTERM",
      "power relay opened",
      committed(title),
    },
    {
      "> acpitool -s",
      "entering S5",
      "devices powered down",
      "wake disabled",
      committed(title),
    },
    {
      "> i2cset 0x20 0x00 0x00",
      "cutting enable pin",
      "rail at 0.00V",
      "device silent",
      committed(title),
    },
  }
end

local function vehicleVariants(title, target)
  return {
    {
      "> cansend can0 0C0#00000000",
      "injecting force-brake on " .. target,
      "ABS override",
      "wheels locked",
      committed(title),
    },
    {
      "> ecu-tool --unlock --flash-off",
      "immobilizer bypassed",
      "engine cut",
      "ignition held in reset",
      committed(title),
    },
    {
      "> python3 /opt/net/canflood.py --id 0x7FF",
      "bus off after 128 errors",
      "controller timeout",
      "drive-by-wire offline",
      committed(title),
    },
  }
end

local function genericVariants(title)
  local ip = randomIp()
  return {
    {
      "> nc -v " .. ip .. " 6148",
      "Connection to " .. ip .. " 6148 port [tcp] succeeded!",
      "banner: NET-ACCESS/2.0",
      "inject " .. title,
      "handshake ................ ok",
      "write payload " .. addr(),
      committed(title),
    },
    {
      "> python3 -c 'import pty; pty.spawn(\"/bin/sh\")'",
      "PTY allocated",
      "uid=0(root) gid=0(root)",
      "exec " .. title,
      "payload mapped at " .. addr(),
      committed(title),
    },
    {
      "> LD_PRELOAD=./hook.so " .. title,
      "constructor ran",
      "symbols intercepted: 6",
      "mem[" .. addr() .. "] patched",
      "hook armed",
      committed(title),
    },
  }
end

local function scriptFor(command)
  local title = titleOf(command)
  local action = actionName(command)
  local folded = string.lower(title .. " " .. action)
  local target = "node"
  if command.m_actionOwnerName ~= nil and tostring(command.m_actionOwnerName) ~= "" then
    target = tostring(command.m_actionOwnerName)
  end
  local variants
  if has(folded, "overheat") then
    variants = overheatVariants(title, target)
  elseif has(folded, "ping") then
    variants = pingVariants()
  elseif has(folded, "short circuit") or has(folded, "shortcircuit") or has(folded, "short_circuit") then
    variants = shortCircuitVariants(title, target)
  elseif has(folded, "synapse") or has(folded, "burnout") then
    variants = synapseVariants(title, target)
  elseif has(folded, "contagion") then
    variants = contagionVariants(title, target)
  elseif has(folded, "optics") then
    variants = opticsVariants(title, target)
  elseif has(folded, "cyberware") or has(folded, "malfunction") then
    variants = cyberwareVariants(title, target)
  elseif has(folded, "cripple") or has(folded, "locomotion") or has(folded, "movement") then
    variants = movementVariants(title, target)
  elseif has(folded, "weapon") then
    variants = weaponVariants(title, target)
  elseif has(folded, "psychosis") or has(folded, "cyberpsycho") then
    variants = psychosisVariants(title, target)
  elseif has(folded, "suicide") then
    variants = suicideVariants(title, target)
  elseif has(folded, "sonic") then
    variants = sonicVariants(title, target)
  elseif has(folded, "whistle") then
    variants = whistleVariants(title, target)
  elseif has(folded, "memory wipe") or has(folded, "memorywipe") or has(folded, "memwipe") then
    variants = memoryVariants(title, target)
  elseif has(folded, "system reset") or (has(folded, "reset") and not has(folded, "optics")) then
    variants = resetVariants(title, target)
  elseif has(folded, "detonate") or has(folded, "explode") or has(folded, "grenade") or has(folded, "overload") then
    variants = detonateVariants(title, target)
  elseif has(folded, "distract") or has(folded, "attract") then
    variants = distractVariants(title, target)
  elseif has(folded, "take control") or has(folded, "takecontrol") or has(folded, "possess") then
    variants = controlVariants(title, target)
  elseif has(folded, "camera") or has(folded, "turret") then
    variants = cameraVariants(title, target)
  elseif has(folded, "vehicle") or has(folded, "brake") or has(folded, "engine") then
    variants = vehicleVariants(title, target)
  elseif has(folded, "toggle") or has(folded, "turn off") or has(folded, "shutdown") or has(folded, "power") then
    variants = powerVariants(title, target)
  else
    variants = genericVariants(title)
  end
  return pick(variants)
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
    ImGui.Text("Left-side code color and opacity")
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
    if ImGui.Button("RED") then
      color.r, color.g, color.b = 1.0, 0.12, 0.10
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("BLUE") then
      color.r, color.g, color.b = 0.20, 0.40, 1.20
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("GREEN") then
      color.r, color.g, color.b = 0.20, 1.05, 0.28
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
