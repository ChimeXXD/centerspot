# Handoff: read this first when you pick the project back up

## Latest: Chime's iPad feedback all built and shipped (Sun 8 Nov 2026, ~03:30 Lagos). Next: Chime's answers from trying it on the iPad, then broadcast part 2 (tilted camera), onboarding (D-58), Day 7.

### Where it stands
- **App: Agmen** (D-42), private repo `ChimeXXD/agmen`. Folder on disk is still `Tactics Board`. Last commit `360ddd9` (CI run 42437973848 was in progress at handoff; check it first: `gh run list --limit 3`).
- **Design:** broadcast look (D-65), circles everywhere (D-66), dark disc outline and numbers on top (D-67). Approved mockups: `design-v2` tag plus `mockup/screens-nov8.js` (D-72..D-74 frames, approved 8 Nov). `Agmen/Design/Tokens.swift` is the source of truth (broadcast tokens added by hand).
- **Built today (8 Nov):**
  - Broadcast part 1 (`96b989b`): per-step marks (zones, shape lines, glows) in the format, timeline and renderer; Zone / Line / Glow draw tools; Spotlight removed; one scrolling row of tools at AX sizes (D-70); 2/255 frame-test tolerance (D-71).
  - iPad big-screen board (`07a2d87`, D-73/D-75): landscape = full-height pitch left, column right (nav row, every step listed with its note, selected player/mark, draw tools); portrait = pitch as big as the height allows.
  - Straight / Curved arrows (D-72): engine `ShapedPath` (`07a2d87`) and the switch + draggable middle bend dot (`360ddd9`). Straight is the default.
  - Small library cards (`360ddd9`, D-74): sideways pitch via `BoardRenderer` `Options.card`; 3 a row on iPhone, 6 on the 13-inch iPad landscape, 5 on the 11-inch.
- **Devices:** iPhone 14 Pro and the borrowed iPad Pro 13-inch (M4, "Uche's iPad", iPadOS 26.6.1, UDID 00008132-001E11443ED9801C) both have `360ddd9`'s build. The iPad installs over Wi-Fi now (paired, Developer Mode on). The iPad goes back on Mon 9 Nov. iPhone signing expires **13 Nov 2026, 21:30 Lagos**; iPad's about a day later. Reinstall before then.
- **Checks at `360ddd9`:** gate 3/3 (413 unit tests); iPhone UI 11 passed on iPhone 18 Pro (iPad-only tests skip); iPad UI 6/6 on the iPad Pro 13-inch (M5) iOS 27 simulator (`id=C41FBB98-5C55-4B3C-A608-C58B62977CFA`).
- **Verified by Chime on devices:** AirDrop `.tactic` iPhone → iPad opens. Not yet: curves with finger/Pencil, dragging the dot, card scroll smoothness, rotation mid-edit.

### Waiting on Chime (ask when they're back)
1. How the iPad layout, Straight / Curved and the dot feel on the real iPad (Pencil).
2. The bend dot draws on top of the players (mockup has it under). OK?
3. Remove takes off only the arrow; the player stays where the run took them. Should Remove also move them back?
4. On iPad only the Pencil draws in Draw mode (zones included). Should a finger draw zones?
5. ⌘Z on an iPad keyboard should undo exactly one edit (G2 fix): try it if a keyboard is around.
6. Older asks: AX5 screenshots (`fidelity/shots/broadcast/ax5-*`), Day 3/4 screenshot approval, a timed 5-step move.

### Known issues (logged, not fixed)
- The selected arrow is kept as an index, so undo/redo can move the selection to a different arrow (review, `BoardScreen+Bend.swift`).
- On iPad the library's first frame lays out the phone grid, then reflows; the board can flash the compact layout on open (review).
- Card discs are 1.5×, which widens the carry radius on cards: a nearby loose ball can draw at a player's feet on the card only.
- Pencil touch-down while a finger drags the dot can drop the drag until lift.
- `-seedLibrary N` adds up without `-resetLibrary` (debug only).
- The heat glow's tap area is a circle a little bigger than the drawn ellipse.
- Applying a smaller shape to 11 players leaves extras in place; the confirmation doesn't warn.

### Working rules learned this session
- **Never run a UI test while the gate or another xcodebuild uses the same simulator.** Parallel lanes each get their own simulator: gate = iPhone 18 Pro; lanes used iPhone 17 Pro (`6B42CA64…`), iPhone 17 Pro Max (`7885F596…`), iPad Pro 13-inch (M5) (`C41FBB98…`), iPad Pro 11-inch (M5) (`3707B3BB…`). The gate runs at every turn end and fails on lanes' half-done edits; that's expected while lanes work, never "fix" a lane's file yourself.
- **Memory:** the Mac has 24 GB. Two lanes plus the gate hit the 85% ceiling; Chime closed apps to help. Docker/OrbStack (4.4 GB) and Brave (3.7 GB) are the big ones to ask about.
- `TEST_RUNNER_SHOTS_DIR=<abs path>` must go before `xcodebuild` (env var) for screenshots.
- Mutation tests only on a scratch copy (`mktemp -d`), never the live tree.
- CI is Xcode 26.6 / Swift 6.3.3: Binding setters as closure literals, split and type long expressions. Check every push.

### How Chime wants to work (keep doing this)
- Restate their feedback point by point in plain words and confirm the open choices (click-through, three options, recommendation first) **before** building. Messages are dictated; read loosely ("we are weird now" = "where are we now").
- Chime picks references; ask which elements of a reference to adopt before designing from it.
- Mockup frames first, Chime approves from PNGs (open them with `open`, give full absolute paths), then build.
- Ship each feature to GitHub when it's built; install on the devices; check CI.
- Names: propose only names verified unused. Never name the design reference library in the repo (D-52 gate).

### Do next
1. Check CI for `360ddd9`; fix first if red.
2. Chime's answers to "Waiting on Chime" 1–5; fix what they find while the iPad is still here (Mon 9 Nov).
3. Broadcast part 2 (BR-2): tilted camera in `BoardRenderer` following the ball, playback and export, iPhone and iPad; editing stays flat; re-measure export on the phone.
4. Onboarding (D-58) mockup in the broadcast look (Skip → library; × closes that tip and the next can come), Chime approves, then TipKit.
5. Day 7: README, demo video made in the app, case study, repo public, `pull_request` in CI.

### On hold
- Custom icons and illustrations (D-51), until Chime says go.
