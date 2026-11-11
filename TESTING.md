# QuickHack — install and in-game test

Mod for Cyberpunk 2077 2.5 and Cyber Engine Tweaks 1.38.1. Looking at a hackable target shows its quickhack icons at bottom center, using the game's own hack icons. The keys you bind in CET start that slot's upload on the press. Upload duration stays the vanilla time. The bar does not require scan mode. Holding scan does not slow time. This mod does not write scan duration.

## Requirements

Install with Vortex before this mod. Each native plugin must be a 2.5 build. Codeware is not required.

1. RED4ext. Loads CET. This mod ships no native plugin.
2. redscript. Compiles `QuickHack.reds` so Lua can call private `TranslateChoicesIntoQuickSlotCommands` through `QuickHack_FillCommands`.
3. Cyber Engine Tweaks 1.38.1. Lua host, ink bar, and the bindings menu.

Launch the game once so redscript finishes its first compile, then quit.

## Vortex

On the PC where the game is installed:

1. Zip `bin`, `r6`, and `archive` so all three are at the root of the zip, not nested in an extra folder. Command: `zip -r QuickHack.zip bin r6 archive`
2. Vortex, Mods, Install From File, select `QuickHack.zip`, Enable, Deploy Mods.
3. Confirm files landed at `<game>\bin\x64\plugins\cyber_engine_tweaks\mods\QuickHack\init.lua`, `<game>\r6\scripts\QuickHack\QuickHack.reds`, and `<game>\archive\pc\mod\quickhack.archive`. `<game>` is the folder that contains `bin` and `r6`. Steam example: `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077`.
4. If either file is missing, copy those two trees by hand into `<game>` and Deploy again.

## Manual install

Copy `bin`, `r6`, and `archive` from this repo onto `<game>`, merging folders. The three confirm paths above must exist.

## Bindings

This mod does not hard-bind 1-9. Bindings are CET Inputs, not Hotkeys. Inputs still fire while you hold W. Hotkeys do not.

1. Restart the game after installing this zip. Reload Mods is not enough for a new input list.
2. Open the CET overlay. Bindings. Open the Inputs group, not Hotkeys.
3. Assign `Quickhack 1` through `Quickhack 9`. They have no default key.
4. If a key is already used by the game, clear that conflict or pick a free key. Unbound slots do nothing.
5. The digit on the bar is the slot (`Quickhack 1`), not the keyboard key you chose.

## First launch

1. CET console must contain `QuickHack ready`.
2. It must not contain `nameplate hook failed` or `QuickHack_FillCommands failed`.
3. If redscript failed, open `<game>\r6\logs\` and read the newest `redscript_rCURRENT.log`. Fix the compile error before testing gameplay. Reload mods from the CET overlay after Lua edits. Restart the game after `.reds` edits.

## Gameplay checks

Load a save with a cyberdeck, on foot, not in a menu. Bind at least `Quickhack 1`.

1. Look at a hostile netrunner or a hackable device. Within one look, the game's quickhack icons (same art as the vanilla hack list, not colored squares) appear at bottom center. The scanner does not need to be held.
2. Look at the floor. The bar disappears as soon as the cursor is no longer over the object.
3. Look at a target with few hacks, then one with many. The 1 icon does not slide. Empty slots to the right stay empty and do not pull 1 toward center.
4. Press the key bound to `Quickhack 1` while holding W. The vanilla upload starts on that press. Upload progress appears immediately and lasts the normal time for that hack, not zero. No scan windup before the upload starts. Holding the key does not start a second upload.
5. A grey icon is locked (cooldown, ICE, no RAM). Its number still sits in that slot. Pressing its slot does nothing.
6. A camera or vehicle uses the same slot row. There is no separate vehicle key row.
7. Hold the normal scan key. Time stays full speed. The vanilla quickhack list still appears. Scan duration stays the game's per-target time. Our bar still follows the nameplate target.
8. Open the CET overlay and press the bound key. Nothing casts. Close the overlay and the key works again.
9. CET console stays quiet during 30 seconds of looking through a crowd. No repeating error line. `QuickHack fills/s=` stays `0` while the nameplate is empty.

## Uninstall

Disable or delete the Vortex mod, or delete the two paths in the confirm step. Restart the game.
