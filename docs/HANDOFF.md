# Handoff: read this first when you pick the project back up

## Latest: Day 3 built, Sat 7 Nov 2026. Waiting on Chime's review; then Day 4 (playback and drawn runs).

### Where it stands
- **App: Agmen** (D-42), private repo `ChimeXXD/agmen`. Folder on disk is still `Tactics Board`.
- **Design:** Floodlight Chalk (D-44), mockup in `mockup/` is the baseline (D-50), `Agmen/Design/Tokens.swift` is the source of truth. Lime/coral defaults (D-53).
- **Built:** the board editor (renderer, drag, select, context row, steps strip D-54, toolbar D-55, undo toast, player sheet, formation picker D-48, launch scene). Every edit undoes and redoes through the document's `UndoManager`. VoiceOver labels from `Placement`, adjustable nudge.
- **Checks:** gate green; `BoardScreenshotUITests` walks the screens and writes `fidelity/shots/day3/*.png` (git-ignored). Run it alone: `xcodebuild -scheme AgmenUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' test`.
- **On the phone:** Day 3 Debug build installed 7 Nov. The signing profile was reused: it expires **13 Nov 2026, 21:30 Lagos**; reinstall before then.

### Known issues
- "New tactic" sometimes makes two documents in the simulator ("Unable to Import Document"). Suspect: the launch scene's hidden toolbar copy of the button. Check on the phone.
- New tactic can't be lime: a custom `ButtonStyle` on `NewDocumentButton` breaks creation.
- Applying a smaller shape to 11 players leaves extras in place; the confirmation doesn't warn.
- Not built: pitch picker check, Sides & colours sheet, Debug screen, launch animation, AX5 screenshots.

### How Chime wants to work (keep doing this)
- Click-through questions (three options, recommendation first) for every decision.
- Chime picks references; never pre-select. Show a small sample (10–20) before any bulk run.
- Names: propose only names verified unused. Never name the design reference library in the repo (D-52 gate).
- One simulator job at a time. Push to GitHub after every commit.

### Do next
1. Chime approves the Day 3 screenshots and tries the board on the phone (drag, reorder, timed 5-step move). Approved shots go to `fidelity/refs/`.
2. Ask: does a stroke starting on a player always become a run (passes also start on players)?
3. Day 4: playback (`TimelineView(.animation)` → `Timeline`), scrubber, Reduce Motion step-through, drawn runs (finger on iPhone, Pencil on the brother's iPad).

### On hold
- Custom icons and illustrations (D-51), until Chime says go.
