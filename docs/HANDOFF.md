# Handoff: read this first when you pick the project back up

## Latest: Day 1 and Day 2 done, Sat 7 Nov 2026. Next is Day 3 (the board).

### Where it stands
- **App: Agmen** (D-42), private repo `ChimeXXD/agmen`. Folder on disk is still `Tactics Board`.
- **Design:** Floodlight Chalk (D-44): Floodlight's colours, Chalk's type (Nunito, handwritten Kalam for notes). The 15-screen mockup in `mockup/` is the baseline (D-50); `docs/design/MOCKUP-GAPS.md` lists what it still has to cover. `Agmen/Design/Tokens.swift` is now the source of truth for the look. Lime and coral are the default team colours (D-53). Selection ring is white chalk.
- **Core:** model, `.tactic` validation (every FORMAT rule), timeline, presets (12 formations, 22 roles), `Placement` (VoiceOver zone words), document open/save through the safe reader. About 110 tests pass; mutation runs done for each rule.
- **Export spike on the iPhone 14 Pro:** a 15 s 1080×1920 clip renders in 2.5 s, 5.5 MB at 4 Mbps (targets: under 10 s, under 8 MB).
- **On the phone:** installed Debug build (with the spike). Free signing expires **13 Nov 2026, 21:30 Lagos**; reinstall before then.
- **Not built yet:** the board UI. The app still opens to a placeholder.

### How Chime wants to work (keep doing this)
- Click-through questions (three options, recommendation first) for every decision.
- Chime picks references; never pre-select. **Show a small sample (10–20) before any bulk run** (reference rounds wasted tokens: Chime rejected 333 general-app and 2,433 tactics-app screenshots and chose the mockup instead).
- Names: propose only names verified unused.
- Never name the design reference library in the repo; the commit gate refuses it (D-52).
- One simulator job at a time; never run tests while a review agent is running them.

### Do next (Day 3)
1. Ask the three open design questions from `MOCKUP-GAPS.md` as click-through: step chip gestures (tap vs long-press), whether a stroke starting on a player is always a run, how to add the ball/cones/opponents.
2. `Render/BoardRenderer` (pitch per kind, tokens per side, arrows by line style, ball at the carrier's feet, white selection ring), drawn the same on screen and in export (D-07).
3. Board screen to the mockup: drag (clamped), select, context row, steps strip, toolbar, formation picker (D-48). Render check for 7/5-a-side markings vs `Placement`; Nunito weights in a screenshot.
4. Chime approves from simulator screenshots and on the phone; baselines to `fidelity/refs/`.

### On hold
- Custom icons and illustrations (D-51), until Chime says go.
