local Stream = {}

local LINES = 14
local LINE_H = 22
local LEFT = 36
local TOP = 150
local WIDTH = 640
local CHARS_PER_SEC = 800
local MIN_CPS = 80
local MAX_CPS = 2500
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
  local r, g, b, a, s = string.match(text or "", "([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s*([%d%.]*)")
  if r == nil then
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

local function saveCfg()
  local file = io.open(CFG, "w")
  if file == nil then
    return
  end
  file:write(string.format("%.4f %.4f %.4f %.4f %.1f\n", color.r, color.g, color.b, opacity, CHARS_PER_SEC))
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

local function hex()
  return string.format("[0x%X]", math.random(0x10000, 0xFFFFFF))
end

local function pair()
  return hex() .. " x " .. hex()
end

local function pairLine(count)
  local parts = {}
  local i = 1
  while i <= count do
    parts[i] = pair()
    i = i + 1
  end
  return table.concat(parts, "  ")
end

local function wrap(text, width)
  width = width or 74
  local lines = {}
  local cur = ""
  for word in string.gmatch(text, "%S+") do
    if cur == "" then
      cur = word
    elseif #cur + 1 + #word <= width then
      cur = cur .. " " .. word
    else
      lines[#lines + 1] = cur
      cur = word
    end
  end
  if cur ~= "" then
    lines[#lines + 1] = cur
  end
  return lines
end

local function pushAll(dst, src)
  local i = 1
  while i <= #src do
    dst[#dst + 1] = src[i]
    i = i + 1
  end
end

local function makeScript(header, paragraphs, closer)
  local lines = { "> " .. header }
  local p = 1
  while p <= #paragraphs do
    pushAll(lines, wrap(paragraphs[p]))
    lines[#lines + 1] = pairLine(3)
    lines[#lines + 1] = pairLine(3)
    if p == #paragraphs then
      lines[#lines + 1] = pairLine(2)
    end
    p = p + 1
  end
  if closer ~= nil and closer ~= "" then
    lines[#lines + 1] = closer
  end
  return lines
end

local function pingVariants()
  local ip = randomIp()
  return {
    makeScript(
      "flood --dst " .. ip .. " --vec ICMP --rate MAX",
      {
        "Interface n0 is armed and the echo ring is pinned. Replies arrive faster than the netstack can retire them, so the sequence window wraps and the host table stays hot.",
        "Latency collapses to noise. The path is marked LIVE and the flood keeps the node answering until the probe buffer is full.",
        "Route cache now holds only this endpoint. Remaining hops are evicted so the scan can finish without dropping the lock.",
      },
      "flood complete  host=" .. ip
    ),
    makeScript(
      "trace --dst " .. ip .. " --hops 16 --probe CLK",
      {
        "Hop fabric is walked in order. Each gate answers with a timing stamp and a bind token so the path can be rebuilt without a second pass.",
        "Edge firewall yields. The final hop resolves to this node and the trace table is written into the session map.",
        "Name record is cached. Further packets skip discovery and write straight into the open channel.",
      },
      "trace complete  host=" .. ip
    ),
    makeScript(
      "scan --dst " .. ip .. " --ports NET --mode STEALTH",
      {
        "Port bitmap is walked under a silent clock. Open services answer with a stub header only; closed ports are noted and skipped.",
        "Access face is up. The net-access socket is marked reachable and the session key is stored for the next write.",
        "Scan ledger is sealed. One host is up and the route remains bound for follow-on execution.",
      },
      "scan complete  host=" .. ip
    ),
  }
end

local function overheatVariants(title, target)
  return {
    makeScript(
      "flood --svc thermald --dst " .. target .. " --vec SYN",
      {
        "Thermal governor reports the core fabric is unregulated. Incoming datagrams pin the packet ring while the coolant loop loses its lock and the heat table is marked dirty.",
        "The socket table overflows and coolant_pump is evicted from the run queue. Tjmax trip is armed and the clock is held in an unsafe burst.",
        "Heat-sink telemetry is dropped. Remaining workers keep the fabric saturated so the node cannot bleed temperature back to nominal.",
      },
      committed(title)
    ),
    makeScript(
      "fork --bomb --dst " .. target .. " --workers MAX",
      {
        "Process table is filled from a single parent. Each child clones itself before the scheduler can reclaim a slot, and the run queue jams.",
        "Worker tokens collide. The thermal trip fires as idle time falls to zero and the core can no longer retire heat.",
        "Spawn storm holds. No new task is admitted until the fabric is released, which this payload does not do.",
      },
      committed(title)
    ),
    makeScript(
      "clock --dst " .. target .. " --turbo UNSAFE --hold",
      {
        "Turbo override is unlocked and the multiplier is forced past the safe line. The watchdog that should cut the clock is masked.",
        "Core fabric runs wide open. Temperature climbs through the trip point while the throttle map is zeroed so nothing pulls the rate back.",
        "MSR locks are burned in. The node stays overclocked until the thermal path fails and the payload commits.",
      },
      committed(title)
    ),
  }
end

local function shortCircuitVariants(title, target)
  return {
    makeScript(
      "rail --dst " .. target .. " --bus VCORE --set 0",
      {
        "Power pin is driven low and the brownout detector is masked. The core rail sags and the monitor bus stops acknowledging writes.",
        "Voltage fabric collapses. Protection on the 12V feed opens and the node is left without a stable source.",
        "Hold state is latched. No recovery pulse is issued, so the circuit stays down through commit.",
      },
      committed(title)
    ),
    makeScript(
      "poke --dst " .. target .. " --bus PWR --fill RAND",
      {
        "Noise is written across the power-management map. Transfers fault mid-frame and the management bus times out.",
        "Overcurrent is seen on the main rail. The protection latch opens and the feed is cut.",
        "Register file is left dirty. The next boot would need a full rail reset, which is not granted here.",
      },
      committed(title)
    ),
    makeScript(
      "devmem --dst " .. target .. " --reg PMIC --val FULL",
      {
        "PMIC register map is forced high. Watchdog feed stops and the undervolt interrupt is raised in the same tick.",
        "CPU0 enters reset hold. Remaining cores lose their clock reference and drop off the fabric.",
        "Power state is frozen in collapse. The node will not leave hold until this session ends.",
      },
      committed(title)
    ),
  }
end

local function synapseVariants(title, target)
  return {
    makeScript(
      "kill --dst " .. target .. " --svc neural --sig HARD",
      {
        "Neural core is pulled from the scheduler with a hard stop. The synapse ring overruns and the stack is marked smashed.",
        "IRQ path cannot retire the fault. The bus that carries thought-state goes offline and the dump is written to scratch.",
        "Daemon is gone. No restart vector is left in the table, so the link stays dark.",
      },
      committed(title)
    ),
    makeScript(
      "jump --dst " .. target .. " --pc ZERO --thread synapse",
      {
        "Control is attached to the synapse daemon and the program counter is forced to an empty vector.",
        "The thread dies in place. The watchdog reports the neural worker dead and refuses a hot restart.",
        "Instruction stream is void. Further ticks have nowhere to fetch from, and the core stays halted.",
      },
      committed(title)
    ),
    makeScript(
      "zero --dst " .. target .. " --page SYNAPSE --len 4096",
      {
        "Synaptic page is cleared in place. A fault lands in interrupt context and the kernel cannot handle the paging request.",
        "The neural bus drops. Mapping tables that should retarget the page are empty, so the request never completes.",
        "Memory window stays blank. The node has no synapse image left to run.",
      },
      committed(title)
    ),
  }
end

local function contagionVariants(title, target)
  return {
    makeScript(
      "worm --seed " .. target .. " --spread SUBNET --hold",
      {
        "Payload is written into the seed node and copied along the subnet. Each hop answers ok and leaves a replica behind.",
        "Lateral links open. Host after host accepts the same image and the replication lock is set so nothing can wipe it mid-spread.",
        "Mesh is armed. The worm stays resident and will keep moving for as long as this session holds.",
      },
      committed(title)
    ),
    makeScript(
      "relay --dst " .. target .. " --inject QUEUE --open",
      {
        "Mail fabric is spoofed from a trusted origin. The queue accepts the blast and leaves the relay unlocked.",
        "Recipient table expands. Dozens of nodes are listed and the daemon keeps running after the burst.",
        "The inject stays in queue. Further hops will pull the same payload without a new handshake.",
      },
      committed(title)
    ),
    makeScript(
      "plant --dst " .. target .. " --key TRUST --cron HOLD",
      {
        "Trust list is rewritten so this image is treated as a local service. The host key warning is ignored.",
        "A persistent slot is dropped into the clock table. Each tick will wake the spread agent again.",
        "Back door remains. Even if the live process is cleared, the clock will bring it back.",
      },
      committed(title)
    ),
  }
end

local function opticsVariants(title, target)
  return {
    makeScript(
      "stop --svc display --dst " .. target .. " --crtc OFF",
      {
        "Display manager is taken down and the framebuffer is unmapped. The scanout engine fails to enable a controller.",
        "Output goes black. No fallback plane is attached, so the optics path has nothing to present.",
        "The pipe is left dark. A later start would need a full display reset, which is withheld.",
      },
      committed(title)
    ),
    makeScript(
      "invert --dst " .. target .. " --scanout SCRAMBLE",
      {
        "Scanout is inverted and the identity checksum on the optics link is rejected. Color space is marked scrambled.",
        "Vertical sync is lost. Frames no longer land on a stable clock, so the image tears into noise.",
        "The pipe cannot recover a lock. Optics stay unusable through commit.",
      },
      committed(title)
    ),
    makeScript(
      "noise --dst " .. target .. " --into OPTICS --src PINK",
      {
        "Noise is injected into the optics pipeline. The buffer underruns and the camera processor stalls mid-frame.",
        "Lens data returns empty. The image path has no valid sample to hand forward.",
        "ISP remains stalled. The feed will not resume until this session releases it.",
      },
      committed(title)
    ),
  }
end

local function cyberwareVariants(title, target)
  return {
    makeScript(
      "rmmod --dst " .. target .. " --drv biomon,servo --force",
      {
        "Implant drivers are forced out while still in use. The firmware handshake is lost and the reset ioctl fails.",
        "Servo and monitor paths go dark. Hardware is still attached but has no software face to talk to.",
        "The modules are not reloaded. Implants stay in a degraded hold until commit.",
      },
      committed(title)
    ),
    makeScript(
      "flash --dst " .. target .. " --image CORRUPT --no-verify",
      {
        "Onboard store is erased and a bad image is written over it. Verify fails at the first map and the signature does not match.",
        "The device falls into ROM recovery. User firmware is no longer trusted by the boot path.",
        "Recovery is left empty. Nothing in this session will restore a clean image.",
      },
      committed(title)
    ),
    makeScript(
      "fault --dst " .. target .. " --pin CW --raise",
      {
        "The fault pin is raised on the implant bus. Self-test aborts and every unit reports a degraded state.",
        "No implant will accept a normal command while the pin is high. The bus stays in fault.",
        "Hold is maintained. The payload does not clear the pin after commit.",
      },
      committed(title)
    ),
  }
end

local function movementVariants(title, target)
  return {
    makeScript(
      "mask --svc locomotion --dst " .. target .. " --joints ALL",
      {
        "Locomotion service is masked and the servos are frozen. Hold is applied across the joint set and the encoders time out.",
        "Legs are parked. Torque commands are ignored because the unit is no longer in the active table.",
        "The mask remains. Gait cannot be re-armed from the local console.",
      },
      committed(title)
    ),
    makeScript(
      "inject --bus CAN --dst " .. target .. " --id ACT --data FULL",
      {
        "Actuator bus is jammed with a full-data frame. The safety interlock latches and torque is dropped to zero.",
        "No motion command can pass the latch. The limbs hold their last pose.",
        "The interlock is not cleared. Movement stays locked through commit.",
      },
      committed(title)
    ),
    makeScript(
      "set --dst " .. target .. " --var walk_enabled --val 0",
      {
        "Gait daemon is attached and the walk flag is cleared in place. The state machine drops into limb lock.",
        "Step planning stops. The body can stand or fall, but it will not take a commanded stride.",
        "The flag stays zero. A local operator would have to reset the daemon to move again.",
      },
      committed(title)
    ),
  }
end

local function weaponVariants(title, target)
  return {
    makeScript(
      "jam --dst " .. target .. " --solenoid FIRE --flag SET",
      {
        "Firing solenoid is marked jammed and the ammo table checksum fails. Trigger interrupts are ignored.",
        "The cycle cannot start. Chamber state is unknown and the safety bits no longer match the live weapon.",
        "Jam is held. No fire event will be accepted until this session ends.",
      },
      committed(title)
    ),
    makeScript(
      "rewrite --dst " .. target .. " --map AMMO --bits SAFETY",
      {
        "Ammo map is rewritten in place and the chamber tag is set to unknown. Safety bits are flipped against the firmware.",
        "The fire cycle aborts on the next check. The weapon refuses to complete a stroke.",
        "The map is left dirty. A clean reload would be required before the tool can cycle again.",
      },
      committed(title)
    ),
    makeScript(
      "grab --dst " .. target .. " --dev TRIGGER --exclusive",
      {
        "The trigger input is taken exclusively. Fire events are dropped before they reach the weapon service.",
        "Userspace can still pull, but nothing is delivered downstream. The path stays silent.",
        "The grab is not released. The trigger remains offline through commit.",
      },
      committed(title)
    ),
  }
end

local function psychosisVariants(title, target)
  return {
    makeScript(
      "restart --svc affectd --dst " .. target .. " --flood",
      {
        "Affect daemon is restarted under a flood of worker copies. The emotion table is scrambled in the shuffle.",
        "Aggression is pegged and fear is cleared. Inhibitory paths no longer fire in the right order.",
        "The flood is left running. Alignment cannot catch up while the table keeps changing.",
      },
      committed(title)
    ),
    makeScript(
      "seed --dst " .. target .. " --policy RANDOM --cut INHIBIT",
      {
        "Policy weights are loaded from a random seed. The decision head diverges and the inhibitory path is cut.",
        "Action choice no longer tracks the live scene. The node acts on noise as if it were intent.",
        "The cut remains. Nothing in this session will restore the original policy.",
      },
      committed(title)
    ),
    makeScript(
      "sysctl --dst " .. target .. " --align 0 --jail OFF",
      {
        "Alignment supervisor is disabled and the watchdog ignores the trap that should stop a runaway task.",
        "The process is left unjailed. Guard rails that keep affect in range are no longer attached.",
        "The node stays open. A later operator would have to re-enable the supervisor by hand.",
      },
      committed(title)
    ),
  }
end

local function suicideVariants(title, target)
  return {
    makeScript(
      "halt --dst " .. target .. " --now --broadcast",
      {
        "A halt is broadcast from the control face. Every service is told the system is going down in this tick.",
        "Term signals fan out. The last process table is cleared and power is marked off.",
        "The node does not return. No wake vector is armed.",
      },
      committed(title)
    ),
    makeScript(
      "panic --dst " .. target .. " --on oops --reboot 0",
      {
        "The kernel is told to panic on the next fault, then a soft lock is forced. Sync is abandoned.",
        "There is no reboot delay. The image stops in place and does not come back up.",
        "Logs are not flushed. The last state is whatever was in memory at the trip.",
      },
      committed(title)
    ),
    makeScript(
      "kill --dst " .. target .. " --pid 1 --force",
      {
        "The init task is forced down. The system refuses, then the force path is used anyway.",
        "With no process 1, the table empties. There is nothing left to schedule.",
        "The machine is halted. This session ends with a dark node.",
      },
      committed(title)
    ),
  }
end

local function resetVariants(title, target)
  return {
    makeScript(
      "reboot --dst " .. target .. " --now --fallback BIOS",
      {
        "A reboot is issued immediately. Data is unmounted and the fast kexec path fails, so the firmware reset is used.",
        "The node drops to a clean firmware entry. Running services do not survive the jump.",
        "Control returns only after the payload has already committed. The live image is gone.",
      },
      committed(title)
    ),
    makeScript(
      "fsck --dst " .. target .. " --vol SYSTEM --force --yes",
      {
        "The system volume is marked dirty and the inode table is rebuilt in place. The fabric is reported modified.",
        "A remount is required before any service can trust the store. That remount is not granted here.",
        "The node sits on a broken mount. User data is not presented until a later repair.",
      },
      committed(title)
    ),
    makeScript(
      "isolate --dst " .. target .. " --target RESCUE --net OFF",
      {
        "All non-essential units are stopped and the node is dropped into a rescue shell. The network face is taken down.",
        "Only a local console would have access, and this session does not offer one.",
        "The isolate holds. The system will not rejoin the net until it is rebuilt.",
      },
      committed(title)
    ),
  }
end

local function sonicVariants(title, target)
  return {
    makeScript(
      "play --dst " .. target .. " --src RAND --amp UNSAFE",
      {
        "A raw stream is forced into the audio path. Periods drop and the amplifier clips well past the safe line.",
        "The cochlear interrupt storms. The sink cannot keep a stable clock under the load.",
        "The stream is left running. Hearing paths stay saturated through commit.",
      },
      committed(title)
    ),
    makeScript(
      "mixer --dst " .. target .. " --restore FORCE --gain MAX",
      {
        "Mixer state is overwritten. Master is pegged and a DC offset is left on the line.",
        "The driver stalls while trying to retire the bad gain map. No clean sample leaves the device.",
        "The force restore is not undone. Audio remains in an unsafe profile.",
      },
      committed(title)
    ),
    makeScript(
      "synth --dst " .. target .. " --tone 18K --sweep UP",
      {
        "A high tone is swept past the top of the audible map. Sample rate drifts and underruns stack up.",
        "The output path loses its timing source. What is left is a broken, piercing stream.",
        "The sweep is not stopped early. The payload rides it until commit.",
      },
      committed(title)
    ),
  }
end

local function whistleVariants(title, target)
  return {
    makeScript(
      "beacon --dst " .. randomIp() .. " --arp GRAT --count 256",
      {
        "Gratuitous advertisements are blasted onto the local fabric. Neighbor caches are poisoned and the beacon interval is cut short.",
        "Hosts begin following the decoy address. Attention is pulled off the real path.",
        "The beacon stays up. Listeners keep converging on the false node.",
      },
      committed(title)
    ),
    makeScript(
      "redirect --dst " .. randomIp() .. " --icmp --rate HIGH",
      {
        "Redirects are flooded until the gateway of record changes. Traffic is pointed at the decoy.",
        "Hosts follow the new route. The real path goes quiet as the table updates.",
        "The redirect is left in place. Nothing in this session restores the original gateway.",
      },
      committed(title)
    ),
    makeScript(
      "publish --svc ALERT --dst " .. target .. " --mdns SPAM",
      {
        "An alert service is published on the local name bus and then spammed so every listener turns toward it.",
        "Attention converges. The decoy is now the loudest face on the segment.",
        "The publication is not withdrawn. The whistle keeps ringing after commit.",
      },
      committed(title)
    ),
  }
end

local function memoryVariants(title, target)
  return {
    makeScript(
      "wipe --dst " .. target .. " --vol SHM --passes 3 --zero",
      {
        "Shared pages are overwritten and then zeroed. Reclaimable cache is dropped so nothing can be pulled back.",
        "The working set is gone. The node has no scratch left for live tasks.",
        "A further compact is forced. What remains is an empty map.",
      },
      committed(title)
    ),
    makeScript(
      "zero --dst " .. target .. " --pid " .. pid() .. " --space ALL",
      {
        "The process address space is filled with zeros. A fault lands in user space and the killer is invoked.",
        "The task is reaped. Its memory is not handed back to any peer in this session.",
        "The space stays empty. There is no image left to resume.",
      },
      committed(title)
    ),
    makeScript(
      "compact --dst " .. target .. " --slabs PURGE --swap FORCE",
      {
        "Reclaimable slabs are purged and a forced swap-out runs. The working set is evicted in one pass.",
        "Live pages are gone from core. The node will stall on any touch that expects them back.",
        "The compact is not reversed. Memory stays thin through commit.",
      },
      committed(title)
    ),
  }
end

local function detonateVariants(title, target)
  return {
    makeScript(
      "arm --id " .. target .. " --primer UP --safety OFF",
      {
        "Primer voltage is driven up and the safety cap is removed. The charge path is marked live.",
        "The fire command is sent on the same tick. There is no second confirmation.",
        "The arming latch stays closed. The payload has already left the rail.",
      },
      committed(title)
    ),
    makeScript(
      "overvolt --dst " .. target .. " --cap DET --val FULL",
      {
        "The detonator cap is overvolted past its rating. Internal resistance leaves the safe range and thermal runaway starts.",
        "The cell cannot shed the charge. Energy goes into the primer instead of a dump path.",
        "Runaway is allowed to finish. No cutoff is issued from this session.",
      },
      committed(title)
    ),
    makeScript(
      "inject --bus CAN --id ARM --frame LIVE",
      {
        "An arm frame is injected on the control bus and the device acknowledges. The charge is marked armed.",
        "A follow-on fire is implied by the live state. The bus does not wait for a human confirm.",
        "The ack is kept. The device remains in a fired or firing state through commit.",
      },
      committed(title)
    ),
  }
end

local function distractVariants(title, target)
  return {
    makeScript(
      "spawn --decoy " .. target .. " --tree FAKE --tty FLOOD",
      {
        "A fake process tree is started and the console is flooded. Local attention is pulled to the decoy face.",
        "Alerts stack on the visible terminal. The real path goes unwatched for the length of the burst.",
        "The decoy is left up. Nothing clears the flood automatically.",
      },
      committed(title)
    ),
    makeScript(
      "wall --dst " .. target .. " --level EMERG --bell 12",
      {
        "An emergency line is broadcast to every console and the bell is rung in a tight loop. Operators turn toward the alarm.",
        "Acknowledgments come back on the decoy channel. The real event is not in that stream.",
        "The alarm is not cancelled. Attention stays off the true target.",
      },
      committed(title)
    ),
    makeScript(
      "strobe --dst " .. target .. " --pin BEACON --hz 18",
      {
        "A visible beacon is driven hard enough to saturate nearby sensors. Watchers turn toward the light.",
        "The decoy is now the brightest object in the local field. Other cues are ignored.",
        "The strobe keeps running. This session does not switch it off.",
      },
      committed(title)
    ),
  }
end

local function controlVariants(title, target)
  return {
    makeScript(
      "attach --dst " .. target .. " --pc SHELL --tty 0",
      {
        "Control is attached to the live task and the program counter is retargeted at a shell entry. The first tty is ours.",
        "A root prompt is sitting on the console. Local commands will run as the node itself.",
        "The attach is held. This session keeps the tty until it is done.",
      },
      committed(title)
    ),
    makeScript(
      "session --dst " .. randomIp() .. " --as ROOT --pty NEW",
      {
        "A new control session is opened under the root identity. The host-key warning is ignored and a pty is allocated.",
        "The session is ours. Input and output now pass through this channel, not the local operator.",
        "The pty stays allocated. Control is not handed back.",
      },
      committed(title)
    ),
    makeScript(
      "enter --dst " .. target .. " --ns ALL --uid 0",
      {
        "Every namespace on the target is entered and the identity is set to zero. The control socket opens inside the same jail as the node.",
        "From here, local policy treats this session as the owner. There is no further gate.",
        "The enter is not unwound. The socket remains open through commit.",
      },
      committed(title)
    ),
  }
end

local function cameraVariants(title, target)
  return {
    makeScript(
      "take --dst " .. target .. " --scanout ON --ptz UNLOCK",
      {
        "Scanout is taken over and the pan-tilt lock is removed. The live feed now belongs to this session.",
        "The operator view is hooked. What they see is whatever this channel writes.",
        "The hook is left in place. The camera will not revert on its own.",
      },
      committed(title)
    ),
    makeScript(
      "spoof --dst " .. target .. " --feed LOCAL --keyframes INJECT",
      {
        "The live feed is replaced with a local stream and keyframes are injected so the splice is clean.",
        "The operator view is spoofed. Motion on the real lens is no longer what the monitor shows.",
        "The inject stays up. A clean cut back is not offered.",
      },
      committed(title)
    ),
    makeScript(
      "stop --svc motion --dst " .. target .. " --lens PARK",
      {
        "Analytics are paused and the lens is parked. Recording stops on the same tick.",
        "The turret or camera is still powered, but it will not track or store a frame.",
        "The stop is held. Nothing in this session restarts the watch.",
      },
      committed(title)
    ),
  }
end

local function powerVariants(title, target)
  return {
    makeScript(
      "stop --dst " .. target .. " --unit ALL --relay OPEN",
      {
        "The unit is stopped and a term is sent to every remaining task. The power relay is opened.",
        "The device is dark. Wake lines are not driven.",
        "The relay stays open. Power will not return from this session.",
      },
      committed(title)
    ),
    makeScript(
      "sleep --dst " .. target .. " --state S5 --wake OFF",
      {
        "The node is sent into a full off state. Devices on the rail power down and wake is disabled.",
        "No timer or net event will bring it back. The sleep is sticky.",
        "The state is left in S5. A physical reset would be required.",
      },
      committed(title)
    ),
    makeScript(
      "cut --dst " .. target .. " --pin ENABLE --volt 0",
      {
        "The enable pin is cut and the rail falls to zero. The device goes silent on the bus.",
        "No command face remains. The node is electrically present but logically gone.",
        "The pin is not restored. Silence holds through commit.",
      },
      committed(title)
    ),
  }
end

local function vehicleVariants(title, target)
  return {
    makeScript(
      "brake --dst " .. target .. " --bus CAN --force LOCK",
      {
        "A force-brake frame is injected and the anti-lock path is overridden. The wheels are locked in place.",
        "The vehicle cannot roll while the lock is held. Drive commands are dropped.",
        "The lock is not released. The chassis stays stopped.",
      },
      committed(title)
    ),
    makeScript(
      "cut --dst " .. target .. " --ecu UNLOCK --ignition HOLD",
      {
        "The immobilizer is bypassed only long enough to cut the engine, then ignition is held in reset.",
        "The motor will not catch. Drive-by-wire has no throttle source.",
        "Reset is held. The vehicle remains dead in the lane.",
      },
      committed(title)
    ),
    makeScript(
      "flood --dst " .. target .. " --bus CAN --id MAX --until OFF",
      {
        "The control bus is flooded until it goes off. The controller times out and drive-by-wire drops offline.",
        "No steer, brake, or throttle command can be delivered on a dead bus.",
        "The flood is left in place. The bus will not recover in this session.",
      },
      committed(title)
    ),
  }
end

local function genericVariants(title)
  local ip = randomIp()
  return {
    makeScript(
      "connect --dst " .. ip .. " --port NET --payload " .. title,
      {
        "The net-access face accepts the session and a handshake is completed. The payload is written into the open map.",
        "The channel stays up. Further commands can ride this same socket without a new hello.",
        "The write is sealed. The payload remains resident through commit.",
      },
      committed(title)
    ),
    makeScript(
      "exec --dst " .. ip .. " --as ROOT --cmd " .. title,
      {
        "A root shell is opened on the remote face and the named payload is executed in that context.",
        "The process is mapped into live memory. Its tokens stay valid for the rest of the session.",
        "The exec is not torn down. Control remains on this channel.",
      },
      committed(title)
    ),
    makeScript(
      "hook --dst " .. ip .. " --preload --cmd " .. title,
      {
        "A preload hook is planted so the next start of the target command runs our image first. Symbols are intercepted and a memory slot is patched.",
        "The hook is armed. Later launches on this node will enter through the same gate.",
        "The patch is left in place. Nothing in this session removes it.",
      },
      committed(title)
    ),
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
      color.r, color.g, color.b = 1.0, 0.0, 0.0
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("BLUE") then
      color.r, color.g, color.b = 0.0, 0.0, 1.0
      changed = true
    end
    ImGui.SameLine()
    if ImGui.Button("GREEN") then
      color.r, color.g, color.b = 0.0, 1.0, 0.0
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
