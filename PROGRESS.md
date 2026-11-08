# Progress

Build log for the one-week plan (`docs/PLAN.md`). Newest entry first. Each entry: **Changed**, **Checked** (with real numbers), **Not verified**, **Next**.

## Broadcast part 2: the tilted camera (Sun 8 Nov 2026, afternoon)

**Changed**
- Chime's choices (D-76): Broadcast by default, one remembered choice for Play and Export; Reduce Motion keeps the tilt with one still view fitted to the whole move; no ball follows the middle of the players moving. D-77: CI paused (GitHub Actions minutes used up for November; jobs refused, nothing charged) until the repo is public.
- `CameraTrack` (Engine): where the camera looks, a pure function of the tactic, Gaussian-smoothed over 0.4 s, sampled at 30 fps, plus the span the subject covers.
- `BroadcastCamera` (Render): the approved mockup's CSS camera as maths (tilt 54°, perspective, focus row, centre column; 58° wide lens for 16:9), never panning past a touchline; `framing:` zooms out until a span fits.
- `BoardRenderer` `Options.broadcast`: pitch, marks and arrows drawn on the camera's plane and projected point by point (stroke outlines, so lines thin with distance); discs projected flat, far to near; numbers upright. Without a camera every call is the flat board's own.
- Playback: the Flat | Broadcast switch where Back was (iPhone nav bar, iPad column nav), full-width board, VoiceOver elements where the camera draws each disc (none for players off screen).
- Export: Camera row (videos only; images stay flat), broadcast frames edge to edge (16:9 all board, text over it), `VideoExportSettings.camera`.
- Verifier: 1 gap fixed (the Reduce Motion view only centred on the move; a wing-to-wing switch left the ball off screen). Code review (medium): 7 found, 3 fixed by the review (movers once per step, an overload that could recurse, duplicate disc code), the off-screen VoiceOver elements fixed here; left: the per-frame track fallback, CGContext+Camera's repeated branches, the preview rebuilding the track on a Title/Notes toggle.

**Checked**
- Red: `CameraTrackTests` 10 and `BroadcastCameraTests` 9 against stubs; `BoardRendererTests+Camera` 4 of 6 against the unused option. Mutations (scratch copy): discs in board order killed by `nearerDiscsAreDrawnOverFartherOnes`; numbers painted on the grass killed by `numbersStayUpright` (after rewriting it on a white away number: the first version was blind, dark ink matched the dark pitch).
- Parity: screen vs export through the camera first failed D-61's 64/255 cap at ring edges (84/255, 22 px): strokes under a squashing transform rasterise differently in SwiftUI. Discs are now projected filled polygons; passes at 0.9, 3.9, 5.5 s.
- Gate 3/3 at 1ed0238. AgmenUITests 17 on iPhone 18 Pro (5 iPad-only skipped); IPadLayoutUITests + CameraUITests on the iPad Pro 13-inch (M5) simulator. Simulator timing: 10.6 ms per broadcast frame at 1080 × 1544 vs 6.4 ms flat.
- `VideoExportTests.theSettingsHaveNoReduceMotionInput` lists the new `camera` field (its comment asks for that; camera is not a Reduce Motion input).
- Two gate runs failed in FuzzImportTests while other test runs shared the simulator; alone and in a quiet full run they pass.

**Not verified**
- Timed export on the iPhone 14 Pro (c968c1f installed, Debug; 1ed0238 not yet: the phone dropped off). Chime's feel of the camera on the device. Xcode 26.6 (CI paused, D-77).

**Next**
- Chime's phone timing and feedback; then onboarding (D-58) in the broadcast look.

## Straight / Curved switch and small library cards (Sun 8 Nov 2026)

**Changed**
- D-72 UI: "Shape | Straight | Curved" in the Draw panel (iPhone) and the iPad column, Straight by default, hidden for Zone/Line/Glow. A curved arrow shows a middle dot; dragging it bends the line (one undo step, D-69 cap, counted for Cancel); dropping it on the straight line straightens it. iPad row "3's run · drag the dot to bend" with Remove (new `StrokeEdits.removeArrow`). `middle(of:)` now finds the furthest point from the chord for old freehand paths. Verifier fixes G1–G3 (step list in Draw mode; ⌘Z once in iPad landscape; no step-actions hint while drawing).
- D-74 library cards: `Options.card` in the one `BoardRenderer` turns the pitch a quarter clockwise with upright numbers (only at 7 pt or more), discs 1.5×, minimum line widths. `LibraryGrid` picks columns from the width: 3 on every iPhone, 6 on the 13-inch iPad in landscape, 5 on the 11-inch (keeps numbers), 4/3 in portrait, a third as many at AX sizes. Debug `-seedLibrary N`.
- Code review (high): 10 found, 4 fixed (a tap on the dot saved an empty bend; marks and arrow ends on cards missed a carried ball's disc; per-frame tactic copies while dragging; indentation). Left: the selected arrow is an index, so undo can move the selection to another arrow; the library's first frame on iPad lays out the phone grid; cards' larger discs widen the carry radius; Pencil + finger together can drop a dot drag; debug seeding adds up without `-resetLibrary`.

**Checked**
- Red runs recorded by both lanes (scratch copies with stubs); mutations 7/7 and 7/7 killed.
- Gate 3/3 (413 unit tests). iPhone UI 11 passed (iPad-only tests skip) on iPhone 18 Pro; iPad UI 6/6 on the iPad Pro 13-inch simulator (6 cards a row, shape row in the column, board layout).
- Installed on the iPhone 14 Pro and the borrowed iPad.

**Not verified**
- Chime on the devices: drawing curves with finger and Pencil, dragging the dot, card scroll smoothness. Xcode 26.6 until CI.

**Next**
- Chime's iPad feedback; then broadcast part 2 (tilted camera), onboarding (D-58), Day 7.

## iPad big-screen board and arrow shapes (engine) (Sun 8 Nov 2026)

**Changed**
- Chime's iPad feedback (D-72..D-75), mockup frames approved (`mockup/screens-nov8.js`).
- iPad layout (D-73/D-75): landscape puts the upright pitch full height on the left and a column on the right (nav row, every step as a list with its note, the selected player or mark, draw tools in Draw mode); portrait centres the pitch as big as the height allows with chips and actions in one row. Chosen from the window size, not the device. iPhone unchanged (17 of 18 screenshots pixel-identical; the 18th is the export preview, which plays on a clock).
- Arrow shapes, engine only (D-72): `ShapedPath` makes Straight (the stroke's two ends) or Curved (one quadratic bend through the stroke's deepest point, 25 points; under 8% of the length comes out straight); `StrokeEdits.bend` moves the middle dot. Renderer: the dribble wave is spaced along the whole line and arrow ends trim along the whole line. Until the switch is built, every drawn arrow is straight (Chime's default).
- Code review (high): 10 found, 3 fixed (Cancel in iPad Draw mode undid the wrong edits after a step was added from the list; bending one arrow could bend another player's run; blank lines). Left for the switch step: the bend dot's 25-point guess for old freehand paths. To check on the iPad: a one-frame layout flash on open, ⌘Z possibly registered twice.

**Checked**
- Red: `IPadLayoutUITests.testLandscape` "718.0 is less than 800.0" before the layout; D-72 tests failed on stubs; a curved dribble waved on one side only before the renderer fix. 19/19 mutations killed (scratch copy).
- Gate 3/3 (390 unit tests). iPhone UI tests 8/8 on iPhone 18 Pro; `IPadLayoutUITests` 2/2 on the iPad Pro 13-inch simulator. Installed on Chime's borrowed iPad.

**Not verified**
- On the real iPad: rotation mid-edit, Pencil in the column layout, Split View. Xcode 26.6 until CI. No separate verifier pass yet (run after the commit to save Chime's iPad time).

**Next**
- Straight / Curved switch and the bend dot (D-72 UI), then small library cards (D-74).

## Broadcast restyle part 1: marks, dark pitch, Zone / Line / Glow (Sat 7 – Sun 8 Nov 2026)

**Changed**
- Format: optional per-step `marks` (zones, shape lines, glows: rings on players or a heat spot). Old files open unchanged; `schemaVersion` stays 1. Refuse and repair rules, an example and timing notes in `docs/FORMAT.md`. The example move's step 4 now has the mockup's marks.
- Timeline: marks fade like arrows (D-46); a mark with the same id on the next step eases to its new shape instead; lines and rings follow their players.
- Renderer (D-65/D-66/D-67): dark broadcast pitch; draw order pitch, marks, arrows, discs with a thin dark outline, then every number on top. Old green pitch tokens removed.
- Draw tools Zone, Line and Glow: one undoable edit per mark, under D-69's size cap; VoiceOver labels ("Zone 1, left wing, step 4"); Remove row; zone move and corner handles.
- Spotlight (D-40) removed: code, export setting, menu, tests.
- At the accessibility text sizes the seven tools sit in one sideways-scrolling row (D-70; the pitch had shrunk to ~150 pt). The board-vs-export frame test allows 2/255 (D-71).
- Code review (high): 6 found, 4 fixed: a side change wiped a whole shape line; VoiceOver couldn't build lines or rings; the zone preview showed boxes too small to keep; repeated per-token work each frame. Left: the heat tap area is slightly bigger than the glow; on iPad only the Pencil draws zones (for Chime to try).
- Verifier: the AX5 pitch check measured the board area, not the pitch (fixed); one untyped expression risky for Xcode 26.6 (split and typed).

**Checked**
- Red on a scratch copy with stubs: 100 tests, 177 issues, every new behaviour failing; 12 of 12 mutations killed (scratch copy only).
- Gate 3/3 (unit tests, iPad iOS 26.5 build, library-name check). UI scheme 7/7 (`BroadcastUITests` new; `DynamicTypeUITests` checks the pitch stays over 220 pt and a swipe reaches Glow).
- Screenshots in `fidelity/shots/broadcast/` match the approved mockup's layout and copy.

**Not verified**
- Xcode 26.6 (CI) until the push. Finger drawing of zones and lines on the iPhone; Pencil on the iPad. VoiceOver custom actions (XCUITest can't trigger them).

**Next**
- Install on the iPhone and the borrowed iPad; push; CI. Then part 2: the tilted camera following the ball.

## Day 5 fix: Save to Photos crashed (Sat 7 Nov 2026)

**Changed**
- Chime: the app quit on Save to Photos. Crash reports from the phone (19:44, 19:45): `dispatch_assert_queue` in `closure #1 in ExportModel.saveToPhotos()` called from `PHPhotoLibrary _performCancellableChanges`. The change block inherited the `@MainActor` model's isolation; Photos runs it on its own queue and Swift 6's runtime check stopped the app. The block is now built in a `@concurrent nonisolated` helper.
- Code review (high): fixed a double tap saving twice and pinned the helper with `@concurrent` (a `nonisolated async` function would run on the caller's actor under SE-0461). The UI test resets the Photos permission each run so the prompt is always exercised.
- Searched the app for other framework callbacks with inherited main-actor isolation: none.

**Checked**
- Red: `ExportFlowUITests.testExportFlow` with the new Save to Photos step: "dev.chime.agmen crashed", simulator crash report with the same stack as the phone's. Green after the fix: "Saved to Photos", app still running.
- All 4 UI tests pass; gate all 3 pass. Installed on the iPhone 14 Pro.
- WhatsApp and Discord play the exported clip (Chime).

**Not verified**
- Save to Photos on the phone after the fix (Chime).

## Day 5: export (Sat 7 Nov 2026)

**Changed**
- `VideoExporter` (+ `VideoExportSettings`, `ExportClock`, `ExportFrame`, `ExportLayout`, `ExportText`): frames from `Timeline` drawn by `BoardRenderer` → AVAssetWriter, H.264, 30 fps, BT.709, 0.5 s lead-in and 1 s end still, off the main actor, progress, cancel deletes the file; no Reduce Motion input. 9:16, 1:1, 16:9 (pitch upright, title left, note right, D-63). "Agmen" corner mark on every frame (D-38).
- `ImageExporter`: PNG of the current step (2 × the pitch's on-screen width) and a lineup card (1080×1350).
- Export sheet to the mockup: preview with safe zones, Vertical 9:16 / Square / Wide / Image, "Up to … MB" before export (D-64), "Rendering n of N frames", Cancel, real size, share sheet, Save to Photos, error state. Spotlight a player (D-40): ring, fading trail, others dimmed, export only.
- 26 formations (D-63). The picker's Use button is pinned under the tiles. `ExportSpike` replaced by `-exportBench`.
- Code review (high): 10 found, 6 fixed (Cancel race leaving "Rendering" stuck, discard deleting a caller's folder, PNG width from the board area instead of the pitch, layout keyed on width, Release log lines, a colour space per frame); then fixed the lineup help text, "Rendering 0 of 1" on images, and closing the sheet mid-Photos-save.
- Verifier: the estimate overstated ~4× → "Up to" (D-64); the spotlight trail had no pixel test (added); stale formation counts in SPEC/features; leftover exports are now cleared at launch.

**Checked**
- On Chime's iPhone 14 Pro (Debug, `-exportBench`): hero 9:16 1.92 s, 1.11 MB (budget 4.27); 1:1 0.84 s, 0.60 MB; 16:9 1.34 s, 0.74 MB; 10 steps 9:16 2.62 s, 2.22 MB (budget 8.37); 1:1 1.62 s, 1.18 MB; 16:9 2.60 s, 1.46 MB. Release will be faster.
- Gate: all 3 pass; "Test run with 281 tests in 27 suites passed". UI tests: 4 pass (library and board, playback and draw, export flow, export error); screenshots in `fidelity/shots/day5/`.
- Red runs: the frame plan, long notes on 5-a-side, the corner mark inside the square board, a goal-line player in the text band, long lineup names, the formation count, the leftover cleanup; each failed first.
- Mutations, each restored: end still, lead-in, end still at t=0, bitrate ×4, cancel without delete, time jitter, three formation breaks, the spotlight trail removed.

**Not verified**
- Playback in WhatsApp and Discord (Chime). Save to Photos on the phone (permission prompt). iPad layout of the sheet; AX5 Dynamic Type.

**Next**
- Chime sends a clip to WhatsApp and Discord; then Day 6 (share and harden, onboarding D-58).

## Day 4 fix: the ball moves smoothly (Sat 7 Nov 2026)

**Changed**
- Chime's phone recording showed the ball jerking. Measured cause: the "at their feet" offset switched on and off at one distance, a 17.8 pt change in one frame as a pass left a player. Now the timeline eases a carry weight across each move with the same curve as the move (`BoardState.carry`), the editor uses the same rule at rest (`Possession.carryWeight`), and a drag works it out live.
- A ball its carrier keeps from one step to the next rides along the carrier's run instead of cutting its own straight line.
- One possession rule (`Possession`): the nearest player within 1.2 disc radii has the ball, for the timeline, drawing, and D-62's pass/dribble rule (a pass from the farther of two players in reach is only the arrow).
- Code review (medium): 8 found, 5 fixed (resting state vs playback carry, all-or-nothing playback offset vs eased editor offset, stale carry during a drag, 1-point ball runs, the rule written twice); the nearer-player rule then fixed too.

**Checked**
- `theBallNeverJumpsBetweenFrames` (hero at 60 fps): worst per-frame change in the ball's motion 17.8 pt before, 0.35 pt after; turns red (12.6 pt) without the eased carry. `aCarriedBallFollowsItsCarriersRun` red before, and red again with the carry-along removed. `onlyTheNearerOfTwoPlayersInReachPassesTheBall` red before the fix.
- Gate: all 3 checks pass; both UI tests pass (98 s). Installed on the iPhone 14 Pro.

**Not verified**
- How it looks on the phone (Chime to replay the move).

## Day 4: playback and drawn runs (Sat 7 Nov 2026)

**Changed**
- Playback: `PlaybackClock` (pure: play, pause, scrub, loop, ½×/1×, time passed in), `PlaybackTrack` (step starts, segments, scrubber, prev/next, Reduce Motion step-through with 0.3 s crossfades), `TimelineView(.animation)` drives the board; the playback bar follows the mockup (segments, Kalam note, time with tenths, Loop on by default). Editing is off while playing; the toast is cleared on Play.
- Draw mode: `PathSimplifier` (thin, bound at 1 000, Douglas–Peucker, cap 200), `StrokeEdits` (D-59/D-62: Run moves the player, Pass moves the ball only from its carrier, Dribble moves the player and the ball they carry, Press moves the player, grass is an arrow; D-28 next step; D-27 anchoring; every stroke leaves its arrow and is one undo), `StrokeCapture` (touch-down recognizer: finger in iPhone draw mode, Pencil always on iPad). Draw panel to the mockup; Cancel undoes the session's edits.
- Render parity (D4-3): screen board via `ImageRenderer` vs `BoardRenderer.image` at the same `t`. Chime set D-60 (99.5% within 16/255; SwiftUI anti-aliases line edges differently) and D-61 (no pixel over 64/255, because a share rule can't see one token 2 px off).
- Code review (high): 8 found, 5 fixed (Cancel undoing non-draw edits, inspector in iPad draw mode, Pencil blocked by other touches, stroke across a mode change, edge-to-centre stroke adding a step, stale scrub). Chime decided: a pass from a non-carrier is only the arrow; Cancel + Redo is fine.
- Verifier: fixed the UI test that drew a pass from a non-carrier, the dribble ball jump, a loose ball near a player not starting its own stroke, the toast's Undo during playback, and kept D-61's two mutations as tests.

**Checked**
- Gate: build-ios26, test, no-library-name all pass; "Test run with 247 tests in 23 suites passed".
- UI tests: `testLibraryAndBoard` and `testPlaybackAndDraw` pass ("Executed 2 tests, with 0 failures", 97 s); screenshots in `fidelity/shots/day4/`.
- Red runs: 38 of 52 failed against stubs (the first red run crashed the host on raw indexing and was redone with guarded indexes); the carrier, dribble and loose-ball tests failed before their code.
- Mutations, each restored: 13 in the build (loop wrap, restart, Reduce Motion, scrubber mapping, simplifier cap/aspect/bound, pass mover, step add, re-anchoring, tap length, ball-before-player); carrier rule, dribble rule, the 64 cap (both D-61 tests go red).
- Parity: pitch 99.96% within 16/255 (max 28); hero 99.92–99.93% (max 30–40).
- Simplifier: the first version took 64 s on a 10k zigzag (quadratic, re-run 40 times); now 8.5 ms Debug, 0.6 ms for a realistic finger stroke (Mac timings).
- Installed on the iPhone 14 Pro (signing still expires 13 Nov 2026, 21:30 Lagos).

**Not verified**
- Playback smoothness and drawing feel on the iPhone; Reduce Motion on a device.
- iPad: Pencil draws while the finger moves tokens; whether a Pencil stroke from a token also triggers a drag (verifier's risk); Cancel mid-Pencil-stroke.
- Mac notes: the proof hook's automatic test runs collided with the build agent's simulator runs (14:33–15:10, not evidence); one UI run was stopped at the 85% memory ceiling and re-run.

**Next**
- Chime tries playback and drawing on the phone; iPad borrow session for the Pencil (D4-4); then Day 5 (export).

## Day 3 follow-up: Agmen's own library (Sat 7 Nov 2026)

**Changed**
- Chime saw the system document browser on the phone (raw-JSON thumbnail, "Untitled.tactic", "632 bytes", grey button) and asked for an app, not a file manager. D-56 replaces `DocumentGroup` with Agmen's library: lime New tactic, cards drawn by `BoardRenderer` (step 1, title, "11-a-side · 5 steps"), press-and-hold Rename · Duplicate · Share · Delete, Delete asks first, the example "Overlap down the left" on first launch only.
- `TacticLibrary` (+Import): `.tactic` files in Documents (visible in Files › On My iPhone › Agmen), safe names, dedupe, rename-on-save, duplicate, delete, import through `TacticFormat` with a size cap before reading. `LibraryStore`, `TacticCard`, `LibraryScreen`, `TacticEditorHost` (own `UndoManager`, autosave 0.5 s after a change, on close and on background; no write when untouched).
- D-57: the board title is Agmen's own menu (Rename, pitch), so Undo, Redo and Share stay visible with long titles.
- Code review (high): 9 found, 4 fixed (long emoji titles past the 255-byte name limit, ⌘Z/⇧⌘Z on the board, autosave re-reading the whole folder, unchanged rename reordering). Then fixed: an untouched New tactic is discarded on close; the launch pitch fades before the centre circle (stray arc beside the cards).
- Verifier: 2 data-safety gaps fixed. (a) Re-opening an open tactic from Files read the file before the board's last edits were saved; the store now flushes the open board first. (b) Names differing only in case: the simulator refuses "press.tactic" next to "Press.tactic" yet reports it missing, and a case-sensitive disk would keep both and fail later renames; names are now compared without case, so such pairs are never made. The library re-reads the folder when the app returns.

**Checked**
- Gate: build-ios26, test, no-library-name all pass. Library suites 37/37 (`TacticLibraryTests`, `TacticLibraryImportTests`, `LibraryStoreTests`).
- Red runs: library stub "27 tests in 2 suites failed … 33 issues"; `LibraryStoreTests` and the safety tests failed to compile before the code existed.
- Mutations, each restored: 20 library rules (M1–M20 in the agent's run, M14 and M21 explained); discard guards (2); case-insensitive names, flush before import, unregister by board (3). Each went red in its own test.
- `BoardScreenshotUITests.testLibraryAndBoard` passed (63 s): example card, New tactic → formation picker → empty board, rename from the board title and from the menu, Delete asks first, plus every Day 3 board check. Two earlier failures were clashes with the gate's run on the same simulator; the same tests passed alone (library suite 3/3).
- Installed on the iPhone 14 Pro (signing still expires 13 Nov 2026, 21:30 Lagos).

**Not verified**
- On the phone: a `.tactic` from AirDrop/WhatsApp/Files reaching the app; the folder in Files › On My iPhone › Agmen; whether the phone's disk is case-sensitive (handled either way).
- Hardware-keyboard ⌘Z on iPad; VoiceOver card actions (especially Share); AX5 sizes; iPad layout; the title width cap on a 375 pt screen.
- No test covers `TacticEditorHost`'s autosave timing directly (store-level tests cover close and flush).
- Skipped from review: the save-failure alert can't show over an open sheet; import decodes the whole folder to collect ids.

**Next**
- Chime tries the library and board on the phone and approves the screenshots in `fidelity/shots/day3/`; then Day 4.

## Day 3: board editor (Sat 7 Nov 2026)

**Changed**
- `TacticEdits` (pure edits: move clamped, steps add/delete/reorder/duration/note, tokens add per D-55 / delete / name / number / role / side, pitch), `Timeline.restingState`, `FormationMatch` (tag follows the step on screen), `Nudge` (VoiceOver moves, 2%, clamped).
- `Render/`: `BoardGeometry` (the only points conversion, also used by the formation diagrams), `PitchDrawing`, `TokenDrawing`, `ArrowDrawing` (run solid, pass dashed, dribble zigzag, press double chevron), `BoardRenderer` (screen through `withCGContext`, offscreen `image(...)`).
- Board screen to the mockup: canvas, context row, steps strip (D-54), toolbar (D-55), Share in the nav bar, undo toast, empty state, `DocumentEditor` (every edit through the document's `UndoManager`). Player sheet, formation picker (D-48) with the replace confirmation, launch scene (Nunito title, Kalam tagline, chalk pitch). Placeholder view removed. Play/Draw/Export/Share show "Coming on Day N".
- `AgmenUITests` target (own scheme, so `test` stays unit-only) walks the screens and saves the screenshots.
- Code review (medium): 8 found, 6 fixed (delete from the last step skipped one back, reorder lost the current step, cancelled drag left a stale preview, toast Undo could undo a later edit, duplicated resting-position rule, arrows shortened against raw instead of drawn centres); then the toast Undo returns the board to the restored step. Skipped: formation tag cost per frame.
- Verifier: 3 gaps fixed (undo/redo tests, nudge test, diagram points outside `Render/`); flagged the formation tag reading step 1 while the picker edits the current step; fixed.

**Checked**
- Gate: build-ios26, test, no-library-name all pass. New suites `DocumentEditorUndoTests`, `BoardAccessibilityTests` and the step-aware tag test: 13/13 on iPhone 18 Pro iOS 27.0.
- Red runs: TacticEdits 12+ failures against stubs; geometry/renderer/helpers "39 tests in 5 suites failed … 31 issues"; new suites failed to compile without `Nudge`.
- Mutation runs, each restored: clamp in moveToken, hit radius 22→30, selection ring 55% chalk, formation tolerance 1.0 (8 issues across 4 tests); undo registration removed, nudge clamp removed, tag pinned to step 1 (24 issues across 4 tests).
- `BoardScreenshotUITests` passed in full (60 s): VoiceOver label on h9, "4-3-3", "Step 2 of 4 · 1.4 s" after delete, Undo brings step 3 back and returns to it. An earlier run failed because the simulator host terminated the app mid-test (log: "Termination requested by simulator host"), not an app crash.
- Built and installed on the iPhone 14 Pro. The profile was reused, so signing still expires 13 Nov 2026, 21:30 Lagos.

**Not verified**
- Drag, double-tap, press-hold reorder and undo feel on the phone; the timed 5-step move (< 60 s) and New tactic → share (< 2 min).
- "New tactic" sometimes creates two documents in the simulator ("Unable to Import Document"); 2 of 4 earlier UI runs. Needs a look on the phone.
- New tactic is the system's grey button: a custom style on `NewDocumentButton` broke creation, so the lime capsule isn't possible there.
- Pitch picker (title menu), 7- and 5-a-side render check, AX5 Dynamic Type, Sides & colours sheet, Debug screen, launch animation.
- Applying a 7/5-a-side shape to 11 players leaves the extras where they were; the confirmation doesn't say so.
- Chime's approval of the screenshots (`fidelity/shots/day3/`), then baselines to `fidelity/refs/`.

**Next**
- Chime reviews the screenshots and tries the board on the phone; then Day 4 (playback and drawn runs).

## Day 1 finished, Day 2 core (Sat 7 Nov 2026)

**Changed**
- Design into code: `Agmen/Design/Tokens.swift` generated from the mockup CSS (`mockup/tokens_to_swift.py`), `RGBA` and WCAG `Contrast`, Nunito (variable) and Kalam bundled under OFL; UI-BRIEF §1–3 written. Lime and coral joined the palette as the defaults (D-53). Selection ring is white chalk so it shows on lime discs.
- `Formation`, `Role`, `Presets` (bundled JSON); `Formation.apply` keeps names and numbers, roles follow the slot, extra slots get new players, the away side and ball stay.
- `Placement`: zone words and VoiceOver labels ("Number 9, striker, edge of the box, step 4 of 5"; away players "Their number …" or "Ade, their player …").
- Reference rounds closed: Chime chose the mockup as the baseline (D-50); custom icons and illustrations on hold (D-51); library name scrubbed from history and guarded (D-52).
- Code review (medium) on the tokens: 8 fixes (single source for side colours, both pitch stripes in contrast tests, fonts checked by exact name, opaque-only contrast, rounding, FORMAT example).

**Checked**
- `TokenContrastTests` 7/7, `PresetTests` 6/6, `PlacementTests` 5/5 on iPhone 18 Pro iOS 27.0; review agent ran 103/103.
- Mutation runs, each restored: black outline removed → 3 red; formation number matching removed → 2 red; edge-of-box removed → 3 red; named away player → red before the fix.
- Verifier: 15/16, the gap fixed (named away players say their side). Design check still PASS after the white selection ring.
- A gate run collided with the review's test run ("signal kill before establishing connection"); re-run alone it passed.

**Not verified**
- Nunito weights rendering on device (Day 3 screenshot); zones vs drawn 7/5-a-side markings (Day 3 render check).

- Save and open now go through the safe reader: `TacticDocument` holds a validated `Tactic`, refuses oversized files before reading when the size is known, and writes clean JSON. `TacticDocumentTests` 6/6; mutation (bypass the reader) → 3 red, restored. Old `NewDocumentTests` now read the saved form instead of raw bytes (same checks).

- Export spike on Chime's iPhone 14 Pro (Debug, `-exportSpike`, simple frames with 23 numbered discs): 8 s clip rendered in 2.25 s, 2.50 MB; 15 s clip in 2.50 s, 5.51 MB at 4 Mbps; 4.62 MB at 3 Mbps. Targets (under 10 s, under 8 MB) met with about 4× headroom on time; the real renderer adds arrows and text.

**Next**
- Day 3: the board (renderer, drag, steps strip, formation picker) built to the mockup, checked on the phone.

## Day 1: design references, direction pick, and the core (Fri 6 Nov 2026)

**Changed**
- Design lane: 36 references by surface with a pattern summary (`docs/design/REFERENCES.md`), then 297 more across all 14 surfaces (`docs/design/REFERENCES-ROUND-2.md`, saved to an "Agmen references" collection; links in the git-ignored `reference-board/images/links.md`). Direction board with Floodlight, Chalk and Matchday Print; Chime picked **Floodlight colours with Chalk type** (D-44), added to the board as "Floodlight Chalk".
- Core lane (agent in its own worktree, merged by hand): `Agmen/Model/` (Tactic, Pitch, Side, Token, Phase, Step, Point, Path, Arrow), `Agmen/Services/TacticFormat*` (decode with every FORMAT rule, encode), `Agmen/Engine/` (Timeline, BoardState, Easing, PathSampler), fixtures in `AgmenTests/Fixtures/` (hero, five-a-side, new full 11-v-11) with a test that keeps them equal to `examples/`.
- Code review (high, untrusted input): fixed a missing token snapping to the centre, edited runs making tokens jump (runs now re-anchored every frame), fixture drift, a malformed `app` block refusing the file, five copies of the clamp, and two copies of the 256 KB cap.
- D-45 (format and timeline details the core lane settled), D-46 (a step's arrows show the move about to happen; hero move rewritten: dribble on step 2, pass to 3 and 9's run on step 3, the cross on step 4). Two tests that assert the hero's contents were updated to the new content; the omitted-keys check now uses a blank tactic so it keeps its coverage.

**Checked**
- iPhone 18 Pro, iOS 27.0: core lane full run `Test run with 80 tests in 4 suites passed`; after the review 84 pass; after D-46 and the new refuse test, `FormatRoundTripTests` 7/7 and `ImportValidationTests` 60/60 pass. The full gate runs at commit.
- Mutation runs, each restored: anchoring removed → 2 red; coordinate clamp removed → `outOfRangeCoordinatesAreClamped` red with 3 issues; linear easing → 5 red.
- Verifier: 14 of 16 pass; the 2 gaps fixed (non-integer shirt number now tested; PLAN no longer claims the preset types).
- Direction board rendered with WebKit and checked by eye: fixed balls hiding numbers and arrowheads hidden under discs.

**Not verified**
- The look on a real phone (nothing on the device yet beyond Day 0). Presets (D2-4) and Placement (D2-5) not built.

**Next**
- Chime reviews the round-2 references; refine Floodlight Chalk; write UI brief §1–3 and `Design/Tokens.swift`. Then presets and Placement, and the board renderer (Day 2–3).

## Day 0: Agmen scaffold (Fri 6 Nov 2026)

**Changed**
- Renamed to Agmen (D-42): target `Agmen`, tests `AgmenTests`, bundle `dev.chime.agmen`, `agmen://`, UTType `dev.chime.agmen.tactic`, display name, CLAUDE.md, proof.json, settings.json (Chime approved the check-file changes), docs. Camera usage string removed (D-36).
- `Agmen/App/AgmenApp.swift` (`DocumentGroup`), `Agmen/App/TacticDocument.swift` (placeholder holding raw bytes; blank v1 tactic for new documents; 256 KB cap on open), `Agmen/Features/Board/BoardPlaceholderView.swift`.
- `AgmenTests/NewDocumentTests.swift`: new document is valid v1 JSON; new documents get distinct IDs; the hero fixture is bundled (5 steps, 17 tokens).
- Code review (`/code-review --fix`): fixed the iPhone portrait lock (the `INFOPLIST_KEY_` setting was ignored) and added the 256 KB cap. Deferred: CI Xcode version (Day 6), `AgmenTests/Fixtures/` folder (Day 2), iPad multi-window scene manifest (after Day 7 with the split view), duplicate build/test check (needs Chime), pinning XcodeGen in CI.

**Checked**
- Red: mutation `schemaVersion` 1 → 2 made `newDocumentIsVersionOneTactic()` fail ("Expectation failed: object["schemaVersion"] as? Int == 1"); restored.
- Green: iPhone 18 Pro, iOS 27.0: `Test run with 3 tests in 1 suite passed`. iPad Pro 13-inch (M5), iOS 26.5: `** BUILD SUCCEEDED **`.
- Device: signed with the free Personal Team, installed on Chime's iPhone 14 Pro (iOS 27.0.1) with `devicectl`. **Signing expires 13 Nov 2026, 21:30 Lagos time**; reinstall before then.
- Verifier: PASS on everything checkable before the first commit; one docs mismatch fixed (Day 0 link check moved to after Day 7).

**Not verified**
- Launched on the phone with Chime's go-ahead; Chime saw the document browser. Rotation lock and the 256 KB refusal not seen on a device.

**Next**
- Done: commits `bdacf0a`, `8d40fd6` on private `ChimeXXD/agmen`; proof gate's duplicate `build` check removed (D-43). Then Day 1: design direction + core lane (D-23).

## All open questions resolved (Fri 6 Nov 2026, later)

**Changed**
- D-32 `build-ios26` proof check (iPad simulator, iOS 26.5; full before each commit). D-33 opponents in the hero move (5 away players; 17 tokens). D-34 name Halfspace, repo `ChimeXXD/halfspace`. D-35 iPad: Pencil now, split view after Day 7. D-36 video and image are the headline share; `.tactic` file is the editable extra; links and QR after Day 7.

**Checked**
- `.claude/proof.json` and the hero fixture parse; spec checker: PASS (23 criteria, 29 features). 4 link criteria moved to the spec's "After Day 7" list.

**Not verified**
- No name or trademark search for Halfspace. The `build-ios26` check hasn't run yet (no sources until Day 0).

**Next**
- Day 0, starting with the rename.

## Open questions answered (Fri 6 Nov 2026)

**Changed**
- D-28 (a drawn run sets the next-step position), D-29 (hero move = `overlap-left`, now 5 steps), D-30 (Squad Snap cut, supersedes D-17), D-31 (test devices). O-4, O-5, O-7, O-8 marked resolved. PLAN moves Squad Snap to Cut.
- `examples/overlap-left.tactic`: step 5 added ("9 attacks the near post and finishes").

**Checked**
- iPhone 14 Pro runs iOS 27.0.1 (`devicectl device info details`). Fixture parses; spec checker passes (23 criteria, 29 features).

**Not verified**
- Apple Intelligence support on the iPhone 14 Pro (from memory: none).

**Next**
- Day 0.

## PRD refined, process adopted (Fri 6 Nov 2026)

**Changed**
- DECISIONS: D-21 (PROCESS.md is the foundation), D-22 (design straight in SwiftUI), D-23 (Day 1 runs design and core lanes), D-24 (render parity tolerance), D-25 (links are raw DEFLATE), D-26 (brother's iPad for Pencil), D-27 (import refuse/repair rules, run anchoring, streaming inflate). Open O-4 to O-8 added.
- SPEC: Goal, Users, Non-goals, Core flows, Risks, Open questions added; 23 acceptance criteria, each with `verify:`. FORMAT: rules table with refuse/repair per field; link decoding order and bomb guard. PLAN, features.json (22 → 29 items), HANDOFF, KICKOFF updated to match.
- Removed the design reference library's name from KICKOFF-PROMPT.md and REFERENCES.md (Meridian lesson).

**Checked**
- Spec checker: `PASS spec: 23 acceptance criteria, all with verify:; 29 features (0 passing)` (was 11 failures).
- Apple's `NSData.compressed(using: .zlib)` output starts `ab 56`; Python `zlib.decompress` rejects it, `wbits=-15` decodes 900 bytes. So the link format is raw DEFLATE (D-25).
- Toolchain: Xcode 27.2, XcodeGen 2.46.0, gh; iPhone 18 Pro and iPad Pro 13-inch (M5) simulators on iOS 27.0; Chime's iPhone 14 Pro paired. `examples/overlap-left.tactic` has 4 steps, `five-a-side-long-ball` 2.
- Fresh-context verifier on the spec: 12 gaps reported; all fixed in the docs except those needing Chime (O-5, O-7, O-8).

**Not verified**
- Squad Snap hardware support on the iPhone 14 Pro (O-8); custom-scheme links in WhatsApp (O-6); free-account device limit (from memory).

**Next**
- Chime answers O-4 to O-8 when convenient; Day 0 setup.

## Project created (Fri 6 Nov 2026)

**Changed**
- Folder created with the plan and starter data: CLAUDE.md, PRD (from Project Ideas), PLAN, SPEC, FORMAT, DECISIONS (D-01 to D-20, L-1 to L-5, O-1 to O-3), RESEARCH, HANDOFF, KICKOFF-PROMPT, UI brief draft, references plan, features.json, presets (12 formations, 22 roles), two example `.tactic` files, project.yml, Config, CI workflow and proof gate.

**Checked**
- `presets/*.json` and `examples/*.tactic` parse as JSON; formation slot counts are 11, 7 and 5.

**Not verified**
- `project.yml` hasn't been run through XcodeGen yet (no sources exist). Day 0 does that.

**Next**
- Day 0 (see `docs/KICKOFF-PROMPT.md`).
