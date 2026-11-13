# Prat3.0-DibsTweaks: notes

One add-on with two Prat modules. Requires Prat-3.0 (`## Dependencies: Prat-3.0`); it does
not load without it, and edits no Prat files.

- Author: DibsCodes. License: GNU GPL version 3 or later (`LICENSE`, and a header in each
  Lua file). `ReverseChat.lua` credits the Prat 3.0 module template (Prat Development Team,
  GPL), which it started from.
- Release: CurseForge, WoW Forever game version, with Prat 3.0 as a required dependency.
  Source: public GitHub repo `DibsCodes/Prat3.0-DibsTweaks`, built by CurseForge's packager
  (`.pkgmeta`; `NOTES.md` and `README.md` are left out of the package). The TOC version is
  `@project-version@`, which the packager replaces with the git tag; a local copy shows the
  placeholder as is.
- Logo: `media/logo.png` (512 px, for the README and CurseForge; left out of the package)
  and `logo.tga` (64 px, uncompressed 32-bit with alpha) for `## IconTexture`. Forever's
  add-on list reads `IconTexture` and draws it at 20x20 before the title
  (Blizzard_AddOnList/AddonList.lua at the source pin).

| Module (name in Extras and Module Control) | File | Default |
|---|---|---|
| Dibs reverse chat: newest messages at the top of chosen windows | `ReverseChat.lua` | Off |
| Dibs animated chat: slide and fade-in animation, text kept at the top, scroll limit | `AnimatedChat.lua` | On |

- Target: Forever only (Interface 16001).
- Source pin: Gethe/wow-ui-source `forever` @ 9dc84f0d3bbae1768ac3405b3716000bd93eda06 (1.60.1.70862).
- Design: no mock-up step. The modules add no new UI, only standard Prat options groups.
- Testing route: UIForever simulator for each round, then the user's live client.

## Packaging (2026-11-12)

Replaces the separate add-ons `Prat-3.0_ReverseChat` and `Prat-3.0_AnimatedChat`. Those were
moved to `Interface\_OldAddOns\` (outside AddOns, so they do not load). Both copies must not
load at once: they would register the same chat hooks twice.

- Prat shows a module's internal name in Module Control, so the internal names are the
  requested names, spaces included: `Dibs reverse chat`, `Dibs animated chat`. Prat and
  AceConfig accept spaces in these keys (AceConfigRegistry rejects only control characters).
- Settings namespaces: `Prat_Dibs reverse chat`, `Prat_Dibs animated chat`.
- `Settings.lua` (`ns.MoveModuleSettings`) moves saved settings from the old names
  (`Prat_ReverseChat`, `Prat_AnimatedChat`, and the Module Control on/off entries) once,
  before each module is created. It never overwrites settings that already exist under the
  new name.

## Dibs reverse chat

Uses ScrollingMessageFrame's native top insert mode. Per-window option "Reverse Windows".
The combat log (ChatFrame2) is never reversed. An extension hooks Prat's `Scroll:MouseWheel`
and flips the wheel in top insert mode.

Known behaviour: Page Up/Down keys are not flipped; the jump button stays in its corner with
its arrow rotated; Copy Chat stays oldest-first.

Update risks: Prat renaming `AddModuleToLoad`, `AddModuleExtension`, `PRAT_L`, `Prat.Addon`,
`HookedFrames` or `Scroll:MouseWheel`; Prat adding its own top-mode wheel flip.

## Dibs animated chat

| ID | Behaviour | Where |
|---|---|---|
| R2 | Older messages slide to make room for a new one | Offsets `visibleLines[1]`; the other lines are chained to it |
| R3 | The new message fades in | Sets the new lines' alpha from 0 to 1 |
| R4 | Short animation | Default 0.15 s, ease-out. Option range 0.05 to 0.5 s |
| R5 | Text hangs from the top of the window; when the oldest message has faded out, the others move up (user's wording, 2026-11-09) | `GetLift` raises `visibleLines[1]` by the empty room above the showing text |
| R6 | Scrolling back cannot push messages out of the window (2026-11-09) | `LimitScroll`, `OnScrollOffsetSet` |

- Works in both insert modes, so it works with Dibs reverse chat. "Keep Text At The Top"
  and the scroll limit are off in top insert mode, where the text already starts at the top.
- No animation while scrolled back, for the combat log, or for messages that arrived while
  a tab was hidden.
- A burst of messages adds to the running slide, capped at the window height.
- A restricted (secret) text height shows that message without animation.
- Options: Animation Time, Slide Old Messages, Fade In New Messages, Keep Text At The Top.

Hooks: `AddOnDisplayRefreshedCallback`, `hooksecurefunc` on the chat frame's `OnPostUpdate`
(with a child frame `OnUpdate` as fallback) and `SetScrollOffset`. Reads
`CanEffectivelyFade`, `CalculateLineAlphaValueFromTimestamp`, `overrideFadeTimestamp` and
`oldestFadingLineTimestamp`; if one is missing, the top features are off.

## Results

### Static checks (2026-11-12)
- Lua 5.1 syntax parse (luaparse) of all three files: passed.
- TOC lists `Settings.lua`, `ReverseChat.lua`, `AnimatedChat.lua`; all exist. Interface 16001.
- After the license headers and the TOC dependency change, the code with comments removed
  is byte-identical to the version tested in the simulator (same length and checksum).

### Simulator, package (UIForever Forever flavor 1.60.1.70450, 2026-11-12)
Fresh session, Prat 3.0 from the simulator catalog plus this package. Checked from the Lua
console.

Passed:
- Both modules load; they appear as "Dibs reverse chat" and "Dibs animated chat" under
  Extras and in Module Control. No modules exist under the old names.
- Settings move, case 1: old Reverse Chat on with ChatFrame1 off, old Animated Chat with
  duration 0.3 and Keep Text At The Top off. After `/reload` the new modules had exactly
  those settings, and the old namespaces were gone.
- Settings move, case 2: old Reverse Chat turned off in Module Control. After `/reload` the
  new module was off, and the old Module Control entries were gone.
- Both modules on: ChatFrame1 in top insert mode, the newest message on top, sliding in
  from above (anchor TOPLEFT, offset 12) and fading in from 0. Reverse chat turned off:
  the window goes back to bottom insert mode.
- No Lua errors.

Found and fixed: the old Module Control entries were not moved, because Prat gives every
module name a default value; the check now uses `rawget`.

### Earlier simulator results (separate add-ons, 2026-11-07 to 2026-11-09)
- Reverse chat: newest on top, wheel direction, Ctrl/Shift wheel, scroll bar, jump button,
  temporary whisper windows, per-window option, disable/enable, `/reload` persistence.
- Animated chat: slide and fade timing (about 0.15 s), wrapped messages, bursts, scrolled
  back, combat log, disable/enable, duration setting; text at the top (stacking, moving up
  when the oldest is gone, full window, option off); scroll limit (stops at the oldest
  message, page up, tall messages, few messages).

### In-game
- Separate add-ons: user reported reverse chat and the slide and fade-in "working great" /
  "works perfectly" in the live client. No itemised checklist was recorded.
- This package: not run yet.

Open items:
- [ ] Package loads with no Lua errors (a new add-on needs a full client restart), and the
      saved Reverse Chat settings (on; ChatFrame1 and ChatFrame4 not reversed) carry over.
- [ ] Animated chat: a new message arriving while scrolled to the very top. In the simulator
      the scroll position went from 17 back to 16 without the lines being redrawn. Not
      diagnosed.
- [ ] Animated chat: text at the top and the scroll limit in game, by eye.
- [ ] Messages that arrived in a hidden tab do not animate when the tab is shown.
- [ ] Links in chat stay clickable. Text fading after inactivity still works.
- [ ] No taint or restricted-value errors during real chat and combat.
