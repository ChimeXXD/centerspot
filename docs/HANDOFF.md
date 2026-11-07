# Handoff: read this first when you pick the project back up

## Latest: Day 5 built (export: 9:16/1:1/16:9 video, PNG, lineup card, spotlight; 26 formations), Sat 7 Nov 2026. Next: Chime checks WhatsApp/Discord playback, then Day 6 (share and harden, onboarding D-58).

### Where it stands
- **App: Agmen** (D-42), private repo `ChimeXXD/agmen`. Folder on disk is still `Tactics Board`.
- **Design:** Floodlight Chalk (D-44), mockup in `mockup/` is the baseline (D-50), `Agmen/Design/Tokens.swift` is the source of truth. Lime/coral defaults (D-53).
- **Library (D-56):** Agmen's own home screen replaced the system document browser: cards drawn by `BoardRenderer`, lime New tactic, press-and-hold Rename · Duplicate · Share · Delete (Delete asks first), the example on first launch. Files are `.tactic` in Documents (Files › On My iPhone › Agmen); outside files are checked and copied in. Board title is Agmen's own menu (D-57).
- **Built:** the board editor (renderer, drag, select, context row, steps strip D-54, toolbar D-55, undo toast, player sheet, formation picker D-48, launch scene). Every edit undoes and redoes through the document's `UndoManager`. VoiceOver labels from `Placement`, adjustable nudge.
- **Checks:** gate green; `BoardScreenshotUITests` walks the screens and writes `fidelity/shots/day3/*.png` (git-ignored). Run it alone: `xcodebuild -scheme AgmenUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' test`.
- **On the phone:** Day 3 Debug build installed 7 Nov. The signing profile was reused: it expires **13 Nov 2026, 21:30 Lagos**; reinstall before then.

### Known issues
- Not checked on the phone yet: importing a `.tactic` from AirDrop/WhatsApp/Files, and the Files folder showing up.
- Never run a UI test while the gate (or another xcodebuild) uses the same simulator: they kill each other's runs.
- Applying a smaller shape to 11 players leaves extras in place; the confirmation doesn't warn.
- Not built: pitch picker check, Sides & colours sheet, Debug screen, launch animation, AX5 screenshots.

### How Chime wants to work (keep doing this)
- Click-through questions (three options, recommendation first) for every decision.
- Chime picks references; never pre-select. Show a small sample (10–20) before any bulk run.
- Names: propose only names verified unused. Never name the design reference library in the repo (D-52 gate).
- One simulator job at a time. Push to GitHub after every commit.

### Do next
- Day 5 on the phone: export a clip, send it in WhatsApp and Discord; measured export on the iPhone 14 Pro: hero 1.9 s, 1.1 MB.
0. Day 4 on devices: playback smoothness and finger drawing on the iPhone; Pencil on the brother's iPad (D4-4), including whether a Pencil stroke from a token also drags it.
1. Chime approves the Day 3 screenshots and tries the board on the phone (drag, reorder, timed 5-step move). Approved shots go to `fidelity/refs/`.
2. Ask: does a stroke starting on a player always become a run (passes also start on players)?
3. Day 4: playback (`TimelineView(.animation)` → `Timeline`), scrubber, Reduce Motion step-through, drawn runs (finger on iPhone, Pencil on the brother's iPad).

### On hold
- Custom icons and illustrations (D-51), until Chime says go.
