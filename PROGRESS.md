# Progress

Build log for the one-week plan (`docs/PLAN.md`). Newest entry first. Each entry: **Changed**, **Checked** (with real numbers), **Not verified**, **Next**.

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
- The app hasn't been launched on the phone (needs Chime's go-ahead). Rotation lock and the 256 KB refusal not seen on a device.

**Next**
- First commit, private repo `ChimeXXD/agmen`, push. Then Day 1: design direction + core lane (D-23).

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
