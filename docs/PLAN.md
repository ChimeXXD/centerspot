# CenterSpot: the one-week build

Written 6 Nov 2026. Decisions are in `DECISIONS.md` (D-01 to D-27). The PRD is `PRD.md`; this plan replaces its phases for the week.

## What "done" means

A **portfolio project**, not an App Store launch (D-01). We build it with Claude Code in one week, stop at a **private beta** on Chime's iPhone, and ship an **open-source GitHub repo** that Chime features on chimexd.work next to Meridian.

The finished project is:
1. A working app on Chime's iPhone: pick a formation, drag players through steps, play the move, export a 9:16 MP4 that plays in WhatsApp and TikTok, and save or share a `.tactic` file.
2. A public repo that reads like senior work: README with a clip made in the app, an architecture diagram (one renderer, pure timeline), the format spec, tests, a CI badge, a clean history.
3. A case study and a 30-second 9:16 video for the portfolio site, made in the app itself.

The selling point: **draw the move, not just the shape** (D-02).

## The week at a glance

Dates are a suggestion; start Day 0 whenever Chime does, and shift the rest.

| Phase | Day | Focus | Gate (must pass before the next day) |
| --- | --- | --- | --- |
| Setup | 0 | Setup | Empty app builds and runs **on Chime's iPhone** (and the iPad simulator); private repo pushed; proof gate runs |
| Design and core | 1 | **Design direction** + core lane (D-23) | References collected; 3 directions on the direction board; **Chime picks one**; UI brief §1–3 filled; tokens in code. Core lane: as many Day 2 tests green as the day allows |
| Design and core | 2 | Finish the core (tests first), start the renderer | Format round trip, clamping, import limits and timeline tests green; presets load; then `BoardRenderer` begins (Day 3 list) |
| Build the app | 3 | Board editor | Chime approves the board screen; a 5-step move built by hand in under 60 s on the phone |
| Build the app | 4 | Playback and drawn runs | Playback is smooth on the phone; a drawn run is followed by its token (finger on the iPhone; Pencil on the borrowed iPad, D-26); render test (screen vs export frame, D-24 tolerance) green |
| Build the app | 5 | Export | A 5-step move exports to 1080×1920 MP4 in under 10 s on the phone and plays in WhatsApp; PNG export works |
| Harden | 6 | Share and harden | `.tactic` save, open and AirDrop work; importer fuzz tests; CI green; beta build on the phone (links and QR after Day 7, D-36) |
| Ship | 7 | Portfolio and open source | Repo public; README, demo video (made in the app) and case study done |

## Scope for the week

| Must (the demo breaks without it) | Should (if the day has room) | Cut (not this week) |
| --- | --- | --- |
| Model, `.tactic` format v1, timeline engine, with tests | | App Store anything; Pro unlock; pricing |
| Presets: 8 eleven-a-side shapes, 5- and 7-a-side (D-14) | Pencil-drawn runs on iPad, finger draw mode on iPhone (D-08) | Voiceover recording, captions |
| Board editor: drag, select, numbers and names, two sides, ball | iPad layout: library · board · inspector (O-3) | Animated GIF; web viewer; link + QR share (after Day 7, D-36) |
| Steps strip: add, duplicate, delete, reorder; per-step duration | Arrows (run, pass, dribble, press) per step | Mac app; iCloud sync; team folders |
| Playback with scrubber; Reduce Motion step-through | 16:9 and 1:1 export | Five-a-side rota and balanced teams (D-19) |
| MP4 9:16 export with size shown; PNG of a step | Lineup card image; spotlight a player in an export (D-40) | FC code card; template gallery |
| `DocumentGroup` save, open, AirDrop | Two-state tactics UI (D-20; the format has it from v1) | Kit Lab (D-18); Squad Snap (D-30) |
| VoiceOver labels for tokens and controls | Custom icons and illustrations (D-51): **on hold until Chime says go** | Shortcuts, widgets |
| On the phone; CI green | Ghost trails behind moving tokens | |

## Day by day

### Day 0: Setup
- [x] Rename to CenterSpot before the first commit (D-42). Done 6 Nov: display name, target and scheme, bundle ID `dev.chime.centerspot`, `centerspot://`, UTType, CLAUDE.md, proof.json, docs; camera usage string dropped (D-36)
- [x] `git init`, private repo `ChimeXXD/centerspot` (O-2), first commit of these docs. 6 Nov: `bdacf0a`, visibility PRIVATE
- [x] `project.yml` builds an empty universal app; `CenterSpotTests` runs one test. 6 Nov: 3 Swift Testing tests pass on iPhone 18 Pro (iOS 27.0); iPad Pro 13-inch (M5) iOS 26.5 builds; mutation run went red
- [x] Signing with the free Personal Team; app launches on Chime's iPhone. 6 Nov: installed and launched with devicectl; Chime saw the document browser (Create Document, Recents)
- [x] CI (`.github/workflows/ci.yml`) runs on push to `main` only while private. 6 Nov: run 42289439771 succeeded
- [x] Proof gate (`.claude/proof.json`) runs test and build-ios26 (D-32, D-43)

### Day 1: Design direction (D-12)
- [x] Collect 30–50 references by surface (board, step strip, playback controls, export sheet, document browser launch) in `docs/design/REFERENCES.md`; images stay local. 6–7 Nov: 333 general + 2,433 tactics-app screenshots on the pick board; Chime used none and chose the mockup (D-50)
- [x] Write the pattern summary: what the picks share, what to avoid
- [x] Build `docs/design/direction-board/index.html`: three directions, each showing the board on iPhone, a playing move and the export sheet
- [x] **Chime picks a direction** (log it as a decision): Floodlight colours with Chalk type (D-44); mockup is the baseline (D-50)
- [x] Fill UI brief §1–3 (direction, tokens, type, motion); add `Design/Tokens.swift`. 7 Nov: tokens generated from the mockup, Nunito + Kalam bundled, `TokenContrastTests` 7/7
- [ ] Draft app icon (on hold with icons and illustrations, D-51)
- [x] Core lane (D-23): model, format validation and timeline done on Day 1 (84 tests)

### Day 2: Model, format and timeline (tests first; starts on Day 1 as the core lane, D-23)
- [x] `Model/` types per `SPEC.md` §2 except the `Formation` and `Role` presets (D2-4); `Codable` matches `FORMAT.md` (6 Nov, core lane: 84 tests pass)
- [x] Round trip: `examples/*.tactic` decode → encode → decode is equal (6 Nov, core lane: 84 tests pass)
- [x] Import validation: size cap, `schemaVersion`, clamping, count limits, unknown keys ignored (6 Nov, core lane: 84 tests pass)
- [x] `Timeline.state(at:in:)`: holds, easing, straight moves, path following, end of tactic (6 Nov, core lane: 84 tests pass)
- [x] Presets: load `formations.json` and `roles.json`; applying a formation keeps names and numbers (7 Nov: `PresetTests` 6/6; roles follow the slot)
- [x] `Placement`: zone words for VoiceOver ("edge of the box", "left half-space") (7 Nov: `PlacementTests` 5/5; the on-screen labels are checked on Day 3)

### Day 3: Board editor
- [x] `BoardRenderer`: pitch per type, tokens per side (D-15), ball, selection ring (white chalk, UI-BRIEF §1) (7 Nov: `BoardRendererTests` sample pixels for fill, ring, selection and dashed pass)
- [ ] Render check: 7- and 5-a-side markings match `Placement`'s zone boundaries; Nunito weights (heavy title vs body) visibly differ in a simulator screenshot
- [x] Canvas board with drag (snap off by default), tap to select, inspector sheet (name, number, role, side) (7 Nov: `TacticEditsTests`, `BoardScreenshotUITests`; drag still to feel on the phone)
- [ ] Formation picker; pitch picker (7 Nov: formation picker done and walked in the UI test; the pitch picker sits in the title menu and hasn't been exercised yet)
- [x] Steps strip: add (duplicates current), delete, reorder, duration (7 Nov: `TacticEditsTests`, `DocumentEditorUndoTests` undo and redo for every edit; press-hold reorder still to try on the phone)
- [ ] Chime approves the screen; baseline saved to `fidelity/refs/`

### Day 4: Playback and drawn runs
- [x] Play, pause, scrub, loop; `TimelineView(.animation)` drives `Timeline` (7 Nov: `PlaybackClockTests`, `PlaybackTrackTests`, UI walk; smoothness still to feel on the phone)
- [x] Reduce Motion: step-through with crossfades (7 Nov: `PlaybackTrackTests`, 651 sampled `t`s never between steps; on-device look still to check)
- [x] Draw mode: Pencil on iPad, toggle on iPhone; stroke → simplified path → token run for that step (7 Nov: `StrokeEditsTests`, `PathSimplifierTests`, UI walk draws a finger run; D-59/D-62; finger feel on the phone and Pencil on the iPad still to check)
- [ ] Borrow session on the brother's iPad (D-26): install, Pencil draws a run, finger moves tokens
- [x] Arrows per step (Should) (7 Nov: every stroke leaves its arrow, D-62)
- [x] Render test: on-screen frame vs offscreen frame at the same `t` (7 Nov: `RendererParityTests` under D-60/D-61; 2 px shift and one recoloured token fail it)

### Day 5: Export
- [x] `VideoExporter`: frames from `BoardRenderer` → `AVAssetWriter`, 1080×1920, 30 fps, H.264, cancellable with progress (7 Nov: `VideoExportTests` read the files back; three sizes)
- [x] Export sheet: preview, preset, size estimate, then the share sheet (7 Nov: `ExportFlowUITests`; "Up to" estimate, D-64)
- [x] PNG of the current step; 16:9 and 1:1 (Should); lineup card (Should) (7 Nov: `ImageExportTests`, lineup tests; spotlight D-40 too; 26 formations, D-63)
- [x] Measure on the phone: time and size for 5 and 10 steps; log real numbers in PROGRESS.md (spike baseline 7 Nov: 15 s clip in 2.5 s, 5.5 MB at 4 Mbps) (7 Nov, iPhone 14 Pro Debug: hero 1.9 s 1.1 MB; 10 steps 2.6 s 2.2 MB)

### Day 6: Share and harden
- [ ] `TacticDocument` with the exported UTType; open from Files and AirDrop (7 Nov: the document now reads and writes through `TacticFormat`; `TacticDocumentTests` 6/6. 8 Nov: Chime AirDropped a `.tactic` from the iPhone to the iPad and it opened; Files still to check)
- [x] Fuzz the importer with malformed, huge and hostile files (7 Nov: `FuzzImportTests`, 6,437 seeded cases; 4 bugs fixed, D-68)
- [x] VoiceOver pass; Dynamic Type in sheets (7 Nov: `ControlLabelUITests` with Apple's accessibility audit; `DynamicTypeUITests` AX5, 5 screens fixed; on-device VoiceOver still to try)
- [ ] CI green; beta build on Chime's iPhone
- [ ] Borrow session on the brother's iPad (D-26): install the beta, open a `.tactic` from Files, VoiceOver pass
- [ ] Should: onboarding (D-58), after the broadcast restyle (D-65): mockup of the welcome pages and tip sequence (first draft 7 Nov, to redo in the new look), Chime approves, then build (welcome on first launch, TipKit tips on the example move: drag, step, Play, draw a run, export)

### Broadcast restyle and 3D camera (D-65, added 7 Nov; before Day 7)
- [x] Chime's iPad feedback (8 Nov): Straight / Curved arrows (D-72), big-screen iPad board (D-73), small wide library cards (D-74); mockup frames, Chime approves, then build (8 Nov: frames approved, `mockup/screens-nov8.js`; steps listed in the iPad column, D-75; iPad first while the borrowed iPad is here)
- [x] Mockup: broadcast pitch, glow rings, zones, shape lines, heat glow, the tilted camera; Chime approves (7 Nov: approved, tag `design-v2`; circles everywhere, no figures, D-66; numbers on top and a dark outline, D-67)
- [x] Format: zones, shape lines and glows as additive v1 fields (FORMAT.md, import rules, fuzz cases, round trips) (7 Nov: per-step `marks`; `MarksFormatTests`, `FuzzImportTests+Marks`)
- [x] Renderer: broadcast pitch, discs with a dark outline and numbers on top (D-66/D-67), glow rings, zones, shape lines, heat glow; parity stays green (7 Nov: `BoardRendererTests+Broadcast`, `RendererParityTests` with step 4's marks)
- [x] Draw tools for zones, shape lines and glow; undoable; VoiceOver words for each (7 Nov: `MarkEditsTests`, `BroadcastUITests`; Spotlight removed; one scrolling row of tools at AX sizes, D-70)
- [ ] Tilted camera in `BoardRenderer` (perspective projection, far-to-near figures) for playback and exports on iPhone and iPad; editing stays flat; export timing re-measured on the phone (8 Nov: built and tested, D-76, commits 09f73aa..1ed0238; waiting on the timed export and Chime on the phone)
- [ ] Then the onboarding (D-58) in the new look

### Day 7: Portfolio and open source
- [ ] README: clip, what it does, architecture diagram, format link, how to build, honest numbers
- [ ] Demo video made **in the app** (9:16), plus screen recordings of building it
- [ ] Case study draft in `docs/CASE-STUDY.md` for chimexd.work
- [ ] Make the repo public; CI on every push
- [ ] Borrow session on the brother's iPad (D-26): film the Pencil part of the demo
