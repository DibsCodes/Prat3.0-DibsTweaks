# Prat3.0-DibsTweaks: notes

One add-on with two Prat modules. Requires Prat-3.0 (`## Dependencies: Prat-3.0`); it does
not load without it, and edits no Prat files.

- Author: DibsCodes. License: GNU GPL version 3 or later (`LICENSE`, and a header in each
  Lua file). `ReverseChat.lua` credits the Prat 3.0 module template (Prat Development Team,
  GPL), which it started from.
- Release: CurseForge, WoW Forever game version, with Prat 3.0 as a required dependency.
  Source: public GitHub repo `DibsCodes/Prat3.0-DibsTweaks`, built by CurseForge's packager
  (`.pkgmeta`; `NOTES.md`, `README.md` and `media/` are left out of the package). The TOC
  version is `@project-version@`, which the packager replaces with the git tag; a local copy
  shows the placeholder as is.
- Logo: `media/logo.png` (512 px, for the README and CurseForge) and `logo.tga` (64 px,
  uncompressed 32-bit with alpha) for `## IconTexture`. Forever's add-on list reads
  `IconTexture` and draws it at 20x20 before the title (Blizzard_AddOnList/AddonList.lua).
- Target: Forever only (Interface 16001).
- Source pin: Gethe/wow-ui-source `forever` @ 9dc84f0d3bbae1768ac3405b3716000bd93eda06 (1.60.1.70862).
- Design: no mock-up step. The modules add no new UI, only standard Prat options groups.
- Testing route: UIForever simulator for each round, then the user's live client.

## Modules

| Module (name in Extras and Module Control) | Feature | Default | Options |
|---|---|---|---|
| Dibs reverse chat | Keep text at the top of the chosen windows | Off | "Keep Text At The Top" (per window, all on by default) |
| Dibs animated chat | Slide and fade-in when a message arrives | On | Animation Time, Slide Old Messages, Fade In New Messages |

| ID | Behaviour | Where |
|---|---|---|
| R2 | Older messages slide to make room for a new one | Engine: offsets `visibleLines[1]`; the other lines are chained to it |
| R3 | The new message fades in | Engine: new lines' alpha from 0 to 1 |
| R4 | Short animation | Default 0.15 s, ease-out. Option range 0.05 to 0.5 s |
| R5 | Text hangs from the top of the window; when the oldest message has faded out, the others move up (user's wording, 2026-11-09) | Engine `GetLift` |
| R6 | Scrolling back cannot push messages out of the window (2026-11-09) | Engine `LimitScroll`, `OnScrollOffsetSet` |
| R7 | "Dibs reverse chat" is only the keep-at-top feature, chosen per chat window (2026-11-12, replaces the earlier newest-on-top reversal) | `ReverseChat.lua` option `windows` |

## Structure

Both features move the same chat lines, so `Engine.lua` works out where they go and both
modules only switch features on. Each module calls `ns.Refresh()` when it is switched on or
off, its options change, or Prat's chat windows change.

- `ns.animated` ("Dibs animated chat") enables slide and fade. Without it, keep-at-top moves
  the text straight to its new place.
- `ns.top` ("Dibs reverse chat") enables keep-at-top and the scroll limit for windows where
  `windows[name]` is true.
- The combat log (ChatFrame2) is never attached. No animation while scrolled back, or for
  messages that arrived while a tab was hidden. A burst of messages adds to the running
  slide, capped at the window height. A restricted (secret) text height shows that message
  without animation.
- Keep-at-top and the scroll limit are off in top insert mode, where the text already starts
  at the top.
- Hooks: `AddOnDisplayRefreshedCallback`, `hooksecurefunc` on the chat frame's `OnPostUpdate`
  (child frame `OnUpdate` as fallback) and `SetScrollOffset`. Reads `CanEffectivelyFade`,
  `CalculateLineAlphaValueFromTimestamp`, `overrideFadeTimestamp` and
  `oldestFadingLineTimestamp`; if one is missing, keep-at-top is off.

Update risks: Blizzard changing `visibleLines`, `messageInfo`, the line anchoring or
`OnPostUpdate`; Prat renaming `AddModuleToLoad`, `PRAT_L`, `HookedFrames`, `HookedFrameList`
or `db.sv`.

## Settings history

- The modules first shipped as separate add-ons with module names `ReverseChat` and
  `AnimatedChat`. `Settings.lua` (`ns.MoveModuleSettings`) moves their saved settings to the
  new names once, never overwriting existing ones. The old add-on folders were moved to
  `Interface\_OldAddOns\` on the developer's machine.
- 2026-11-12: the newest-on-top reversal was removed. Its per-window choices (`frames`) are
  not reused; keep-at-top uses a new `windows` option. The old `top` option of Dibs animated
  chat is no longer read.
- Defaults (user, 2026-11-12): Dibs animated chat on, Dibs reverse chat off. Settings saved
  for the old reversal (including "on") made reverse chat start on, so `ReverseChat.lua`
  calls `ns.ResetModuleSettings(MODULE, 2)`: once, it clears the module's saved settings in
  every profile and stores `dibsSettingsVersion = 2` in its namespace. Later choices are
  kept. Raise the version only when the module's meaning changes again.

## Results

### Static checks (2026-11-12)
- Lua 5.1 syntax parse (luaparse) of all four Lua files: passed.
- TOC lists `Settings.lua`, `Engine.lua`, `ReverseChat.lua`, `AnimatedChat.lua`.

### Simulator, module split (UIForever Forever flavor 1.60.1.70450, 2026-11-12)
Fresh session, Prat 3.0 from the simulator catalog. Window height 170, 12 px lines. Values
are the newest line's anchor offset, read from the Lua console.

Passed:
- Defaults: Dibs reverse chat off, Dibs animated chat on.
- Animated chat only: text at the bottom; a new message starts 12 px below and slides in.
- Reverse chat turned on: text glides up to the top (4 lines: offset 122).
- Animated chat off: a new message goes straight under the text (offset 110, alpha 1); the
  oldest fading out moves the rest up at once (122).
- ChatFrame1 unticked: text goes back to the bottom. Ticked again: back to the top.
- Both on, new message: appears under the text at the top; older text does not move.
- Reverse chat off with animation on: text glides back to the bottom. Both off: plain chat.
- Fade-in completes in real time (alpha 1 after 0.5 s).
- No Lua errors.

### Simulator, defaults and one-time reset (same flavor, 2026-11-12)
Real `Settings.lua` and `ReverseChat.lua`, a stand-in `Engine.lua` (`ns.Refresh` does
nothing) and a minimal animated module, with Prat 3.0 from the catalog.

Passed:
- Fresh install: reverse chat off, animated chat on, `dibsSettingsVersion` 2 recorded.
- Old settings planted (reverse chat on, no version), then `/reload`: reverse chat off,
  saved "on" and old `frames` cleared, Module Control shows it disabled, animated chat on.
- Reverse chat then turned on and ChatFrame3 unticked, then `/reload`: both choices kept
  (no second reset).
- No Lua errors.

### Earlier simulator results (before the split, 2026-11-07 to 2026-11-12)
- Slide and fade timing (about 0.15 s), wrapped messages, bursts, scrolled back, combat log,
  disable/enable, duration setting.
- Keep-at-top: stacking, moving up when the oldest is gone, full window, real-time run.
- Scroll limit: stops at the oldest message, page up, tall messages, few messages.
- Packaging: module names in Extras and Module Control, settings moved from the old names.

### In-game
- Separate add-ons: slide and fade-in reported "works perfectly" in the live client.
- Package: the user tested it in game on 2026-11-12, which led to the module split (R7).
- Module split: not run in game yet.

Open items:
- [ ] Module split loads with no Lua errors; keep-at-top works per window with and without
      Dibs animated chat.
- [ ] A new message arriving while scrolled to the very top. In the simulator the scroll
      position went from 17 back to 16 without the lines being redrawn. Not diagnosed.
- [ ] Messages that arrived in a hidden tab do not animate when the tab is shown.
- [ ] Links in chat stay clickable. Text fading after inactivity still works.
- [ ] No taint or restricted-value errors during real chat and combat.
