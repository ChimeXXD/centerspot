# Progress

Build log for the one-week plan (`docs/PLAN.md`). Newest entry first. Each entry: **Changed**, **Checked** (with real numbers), **Not verified**, **Next**.

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
