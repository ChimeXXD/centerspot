# Handoff: read this first when you pick the project back up

## Latest: broadcast restyle part 1 built (marks, dark pitch, Zone / Line / Glow, Spotlight removed), Sun 8 Nov 2026. Next: install on the iPhone and the borrowed iPad, then part 2 (tilted camera following the ball), then onboarding (D-58), then Day 7.

### Where it stands
- **App: Agmen** (D-42), private repo `ChimeXXD/agmen`. Folder on disk is still `Tactics Board`.
- **Design:** broadcast look (D-65), approved mockup tagged `design-v2` in `mockup/`; circles everywhere, no figures (D-66); dark outline on every disc and every number on top (D-67). `Agmen/Design/Tokens.swift` is the source of truth (broadcast tokens added by hand; the generator would overwrite them).
- **Library (D-56):** Agmen's own home screen; `.tactic` files in Documents; outside files checked and copied in through file coordination (D-69).
- **Built:** board editor, playback, drawn runs/passes/dribbles/presses (D-59/D-62), export (9:16, 1:1, 16:9 video, PNG, lineup card), 26 formations, hardening (fuzzed importer D-68, 256 KB cap on edits D-69), marks per step (zones, shape lines, glows) with draw tools. Spotlight removed.
- **Checks:** gate (unit tests, iPad iOS 26.5 build, library-name check). UI scheme `AgmenUITests` (7 tests); pass `TEST_RUNNER_SHOTS_DIR=$PWD/fidelity/shots/<dir>` to save screenshots.
- **CI** builds with Xcode 26.6 / Swift 6.3.3: Binding setters as closure literals, split long expressions and give them types. Check every push (`gh run list --limit 1`).
- **On the phone:** Day 5 + Photos-fix build. Signing expires **13 Nov 2026, 21:30 Lagos**; reinstall before then.

### Known issues
- Never run a UI test while the gate (or another xcodebuild) uses the same simulator: they kill each other's runs (the gate runs automatically at the end of each turn).
- On iPad only the Pencil draws in Draw mode, zones included; Chime to decide if a finger should draw zones.
- The heat glow's tap area is a circle a little bigger than the drawn ellipse.
- Applying a smaller shape to 11 players leaves extras in place; the confirmation doesn't warn.

### How Chime wants to work (keep doing this)
- Click-through questions (three options, recommendation first) for every decision.
- Chime picks references; ask which elements of a reference to adopt before designing from it.
- Names: propose only names verified unused. Never name the design reference library in the repo (D-52 gate).
- One simulator job at a time. Ship each feature to GitHub when it's built; check CI after every push.
- Give complete absolute paths, or `open` images, when showing Chime anything.

### Do next
1. Install on the iPhone and the borrowed iPad (D4-4, D6-4: Pencil drawing, open a `.tactic` from Files, VoiceOver pass).
2. Part 2 (BR-2): tilted camera in `BoardRenderer` following the ball, playback and export, iPhone and iPad; editing stays flat; re-measure export on the phone.
3. Onboarding (D-58) mockup in the broadcast look; Skip goes to the library; × closes that tip and the next can come. Chime approves, then TipKit.
4. From Chime: AX5 screenshots (`fidelity/shots/broadcast/ax5-*`), Day 3/4 screenshot approval, a timed 5-step move, AirDrop a `.tactic`.
5. Day 7: README, demo video made in the app, case study, repo public, `pull_request` in CI.

### On hold
- Custom icons and illustrations (D-51), until Chime says go.
