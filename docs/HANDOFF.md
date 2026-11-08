# Handoff: read this first when you pick the project back up

## Latest: broadcast camera, onboarding and the unslop pass built and shipped (Sun 8 Nov 2026, evening Lagos). Next: Chime on the phone, then "fix everything", then the iPad check, then Day 7.

### Where it stands
- **App: Agmen** (D-42), private repo `ChimeXXD/agmen`. Folder on disk is still `Tactics Board`. Last code commit `61e71d1`.
- **CI is paused until the repo is public (D-77):** November's free Actions minutes are used up; GitHub refuses jobs and charges nothing. Don't treat a billing-blocked run as red. On Day 7, once public, check the first run (Xcode 26.6) and fix what it finds.
- **Chime's order (8 Nov):** broadcast camera → onboarding → **fix everything** → iPad check (Chime's brother lends the iPad again) → Day 7.
- **Built today (8 Nov, afternoon and evening):**
  - Broadcast camera (BR-2, D-76): `CameraTrack` (Engine), `BroadcastCamera` (Render, the mockup's CSS camera as maths), `Options.broadcast` in `BoardRenderer`; the Flat | Broadcast switch in playback (remembered, Broadcast by default), Reduce Motion's still view fitted to the whole move; the Camera row in Export (videos only, images flat). Timed on the iPhone 14 Pro: hero 9:16 2.37 s / 2.56 MB, ten steps 9:16 4.67 s / 5.83 MB of 8.37 MB (PROGRESS has every format).
  - Onboarding (D-58, D-78): three welcome pages (Broadcast on 2 and 3), five TipKit tips on the board, Show tips again in the library's More menu. Mockup tag `design-v3`.
  - Unslop, polish mode (D-80): one lime lead per screen; heavy type only for the wordmark and shirt numbers; welcome titles without periods.
- **Checks at `61e71d1`:** gate 3/3. AgmenUITests: every test passed across today's runs (17 + Onboarding on iPhone 18 Pro; iPad layout + camera on the iPad Pro 13-inch simulator). Verifier and code review ran on the camera and on the onboarding; their fixes are in.
- **Device:** iPhone 14 Pro has `61e71d1`'s build (installed over Wi-Fi). Signing expires **13 Nov 2026, 21:30 Lagos**: reinstall before then. Bench: launch with `xcrun devicectl device process launch --console --terminate-existing --device 00008120-001044862EC0201E dev.chime.agmen -- -exportBench` (keep the phone awake; it reports both cameras).

### Waiting on Chime
1. How the Broadcast camera feels in Play on the phone (drift on passes?). BR-2 stays `passes: false` until then (rule 9).
2. The onboarding on the phone: delete the app or use More › Show tips again.
3. The unslop: D-80 (lime, weights, periods; applied while Chime was away) and D-81 (screen-by-screen: 4 pt spacing, one icon rule, token corners, dimmed empty board, centred welcome; Chime picked these). Chime to look on the phone; the empty board's halfway line still runs between the prompt's words and button at 40%.
4. Older: the iPad questions from 8 Nov morning (Straight/Curved and the bend dot feel, dot above or below players, Remove moving the player back, finger drawing zones on iPad, ⌘Z), AX5 screenshots, Day 3/4 approvals.

### Fix everything (next, before Day 7)
- From the camera review: the per-frame `CameraTrack` fallback in `broadcastTarget`; `CGContext+Camera` repeated branches; the export preview rebuilds the track on a Title/Notes toggle.
- From the onboarding review: tips show on any board, not only the example (as specified; Chime may want example-only); the tip modifier swaps a control's identity when a tip comes or goes; on a board with no players the drag tip holds the others back.
- From 8 Nov morning: the selected arrow is an index (undo can move it); the iPad library's first frame lays out the phone grid; card discs widen the carry radius; Pencil + finger can drop a dot drag; `-seedLibrary` adds up; the heat glow's tap area; a smaller shape on 11 players leaves extras.
- The board's title truncates to "Overlap dow…" on the phone (the Undo/Redo/Share group is wide), seen in the D-81 audit.
- The Draw panel's "Shape" label is a one-off 13 pt size; the library grid's 10 pt gap is off the 4 pt grid but pinned by `LibraryGridTests` to the D-74 mockup (change both together if Chime wants it).

### Working rules learned this session
- **Never let two test runs share a simulator.** The gate runs at every turn end; a background UI suite on the same simulator made it fail (signal kill, fuzz timeouts). Wait for UI runs to finish (Monitor/until-loop) before ending a turn, and tell review agents not to run xcodebuild.
- **The commit gate refuses a command that edits files and commits in one go.** Edit in one step, `git add … && git commit …` in the next.
- **TipKit's popover modifier breaks `ImageRenderer`** (parity test) and steals taps: attach it only when a tip is due (`agmenTip`).
- Popover content's accessibility identifiers don't reach XCUITest; find the tip's close by its label "Close tip".
- `devicectl … launch` needs `--` before the app's own arguments.
- The design check needs Playwright: it's installed in the session scratchpad (`pw/`, version 1.64 matches the cached Chromium 1248); run with `NODE_PATH=<scratch>/pw/node_modules`.

### How Chime wants to work (keep doing this)
- Restate their feedback point by point and confirm open choices (click-through, three options, recommendation first) before building. Messages are dictated; read loosely.
- Mockup frames first, Chime approves from PNGs (open them with `open`, full absolute paths), then build.
- Ship each feature to GitHub when it's built; install on the devices.
- Short status lines while working; Chime asked "what's taking so long" when updates went quiet.
- Names: propose only names verified unused. Never name the design reference library in the repo (D-52 gate).

### On hold
- Custom icons and illustrations (D-51), until Chime says go.
