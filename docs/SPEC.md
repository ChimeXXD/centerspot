# Spec

Written 6 Nov 2026. What the app does this week, precisely enough to build and test. Decisions are cited as D-xx. Screen look and copy live in `design/UI-BRIEF.md`; the file format lives in `FORMAT.md`.

## Goal

People who explain football tactics (FM and EA FC players, grassroots coaches, football creators) can show a *move*, not just a shape: build it as steps on a phone, play it, and post it as a 9:16 video or send it as an open `.tactic` file. Today they use screenshots, text codes, Canva templates or screen recordings of board apps (`PRD.md`). This week it is a portfolio project (D-01): it works end to end on Chime's iPhone 14 Pro, Pencil runs are proven on a borrowed iPad (D-26), and the repo goes public on Day 7.

## Users

- **Primary:** Chime, in Lagos, on an iPhone 14 Pro: builds moves, exports clips, shares in WhatsApp.
- **Secondary (portfolio audience):** FM and EA FC players explaining a tactic; Sunday-league and five-a-side coaches planning on a phone before kick-off; creators who need a 9:16 clip.
- **Occasional device:** Chime's brother's iPad with Apple Pencil, for drawn runs (D-26).

## Non-goals (this week)

- App Store release, listing, pricing, paywall, TestFlight (D-01).
- Accounts, servers, analytics, iCloud sync, universal links (D-01, D-10).
- Club badges, league names, real kits, player photos or databases, game logos (D-13).
- Voiceover, captions, GIF, web viewer, Mac app, Five-a-side rota, Kit Lab, FC code card (PLAN Cut column, D-18, D-19).
- A Figma design pass (D-22).

## 1. Jobs and core flows

1. **Show a move:** New tactic → pick a formation → drag players in step 1 → **+** adds step 2 (a copy) → drag again, up to 3–8 steps → Play → Export → Vertical 9:16 → size shown → share sheet. Target: under 2 minutes for a first move.
2. **Share a tactic:** Share → `.tactic` file (AirDrop, Files, WhatsApp document), → the other person opens it in the app and sees the exact board. Links and QR come after Day 7 (D-36).
3. **Post a lineup:** pick a step → Export → Image → PNG of that step (lineup card is a Should).
4. **Draw a run:** Draw (iPhone toggle; Pencil on iPad) → stroke starting on a player → that player follows the stroke when the move plays.
5. **Open a bad file:** open an oversized, newer-version or broken `.tactic` → a plain error message, no crash.

## 2. Model (`Agmen/Model/`)

| Type | Holds | Notes |
| --- | --- | --- |
| `Tactic` | `id`, `title`, `pitch`, `sides[2]`, `tokens`, `phases` | A phase is a named step list. v1 UI shows one phase, "Main"; D-20 adds "In possession" / "Out of possession" |
| `Pitch` | `kind`: `full`, `sevenASide`, `fiveASide`; `style`: `stripes`, `plain` | Aspect (length × width, metres): full 105 × 68, seven 60 × 40, five 40 × 25 |
| `Side` | `id` (`home`/`away`), `name`, `colour` (palette key), `rendering` (`filled`/`ring`) | Two sides max. Rendering is fixed by side (D-15) |
| `Token` | `id`, `kind` (`player`, `ball`, `cone`, `marker`), `side?`, `number?`, `name?`, `roleID?` | Up to 30 tokens |
| `Step` | `id`, `duration` (s, 0.3…5, default 1.2), `positions` [tokenID: `Point`], `runs` [tokenID: `Path`], `arrows`, `note?` | Up to 40 steps per phase |
| `Point` | `x`, `y` in 0…1 (D-05) | Clamped on decode and on drag |
| `Path` | `points` (2…200 `Point`s) | Simplified from a stroke (D-08); a run ends at the token's position in the *next* step |
| `Arrow` | `kind` (`run`, `pass`, `dribble`, `press`), `points` (2…200) | Drawn on its step only, faded in during the step's hold |
| `Formation` (preset) | `id`, `name`, `pitch`, `slots[]` (`number`, `roleID`, `x`, `y`) | From `presets/formations.json` (D-14) |
| `Role` (preset) | `id`, `short`, `name`, `line` (`gk`, `def`, `mid`, `att`) | From `presets/roles.json` |

## 3. Timeline (`Engine/`) (D-06)

- `Timeline.duration(of phase) = Σ (hold + step.duration)` over all steps except the last, plus a final hold. `hold = 0.3 s`.
- `Timeline.state(at t, in tactic) -> BoardState`: positions for every token, the arrows visible at `t` and their opacity, and the active step index.
- Between step *i* and *i+1*, progress `p = ease((t − start) / duration)` with `ease` = ease-in-out cubic. A token **with a run** in step *i* moves along the run's arc length at `p`; otherwise it moves straight from its position in step *i* to step *i+1*. A token missing from step *i+1* stays where it was.
- Arrows of step *i* fade in over the first 0.2 s of its hold and fade out as the move to *i+1* ends.
- `t` is clamped to `0…duration`. The function has no clock, no state and no randomness: the same input gives the same output (tested).

## 4. Rendering (`Render/`) (D-07, D-15, D-16)

- `BoardRenderer.draw(state:tactic:in:size:theme:options:)` draws into a `CGContext`. Options: `selection`, `showSafeZones`, `ghostTrails` (Should), `scale`.
- Pitch fits the rect with its aspect, vertical, attacking upward; markings from the pitch kind (box, six-yard box, centre circle, spot, arcs; scaled for 7- and 5-a-side).
- Token sizes scale with the pitch width (a full-pitch player disc ≈ 4.2% of pitch width). Numbers in a rounded, tabular face; names below in small caps (look decided on Day 1).
- Home = filled disc in the side colour with a contrasting number. Away = ring in the side colour, number inside. Ball = white disc with dark outline. Selection = an outer ring + slight lift shadow (screen only).
- Arrow styles: run solid with a head, pass dashed with a head, dribble wavy, press a short double chevron. Line widths scale with the pitch.

## 5. Screens

Details, copy and test IDs are in `design/UI-BRIEF.md`.

| Screen | iPhone | iPad (Should, O-3) |
| --- | --- | --- |
| Launch / library | Agmen's own home screen (D-56, supersedes the system document browser): title art, lime "New tactic", then a grid of tactic cards, newest first, each drawing step 1; press and hold for Rename, Duplicate, Share, Delete | Same |
| Board | Full-screen vertical pitch; toolbar (formation, pitch, draw, play, export, share); steps strip at the bottom | Centre column of a split view; inspector on the right |
| Inspector | Sheet: name, number, role, side, delete | Trailing column |
| Formation picker | Sheet grid of mini pitches | Popover |
| Playback | Play/pause, scrubber, step ticks, loop; replaces the steps strip while playing | Same |
| Export | Sheet: preview at preset ratio with safe zones, preset (9:16 default), estimated size, Export → progress → share sheet | Same |
| Share | Share sheet with `.tactic`, link and QR (Should) | Same |
| Debug (Debug builds) | Load any example; export timing log; reset | Same |

## 6. Interactions

- **Drag** a token to move it in the current step. One finger; long-press then drag to multi-select (Should). Clamped to the pitch; no snap by default.
- **Tap** a token to select; tap the pitch to deselect; double-tap a token to open the inspector.
- **New step** duplicates the current step and selects it. Steps can be reordered by drag, deleted (with undo) and given a duration.
- **Draw mode**: on iPad the Pencil always draws and the finger always moves tokens; on iPhone a toolbar toggle switches the finger to drawing. The picked line type decides what a stroke from a player does (D-59): Run moves the player, Pass moves the ball, Dribble moves both, Press moves the player; a stroke from empty grass is an arrow of the picked type and moves nothing.
- **Undo/redo** through the document's `UndoManager` for every edit.

## 7. Export (D-11)

| Preset | Size | Notes |
| --- | --- | --- |
| Vertical | 1080 × 1920 | Default. Pitch fills the width; title and step note in the top band; safe zones shown only in the preview |
| Square | 1080 × 1080 | Should |
| Wide | 1920 × 1080 | Should; pitch upright in the middle, title left, step note right (D-63) |
| Image | PNG of the current step; pixel width = 2 × the board's on-screen width in points | |

- 30 fps, H.264, `AVAssetWriter` with a pixel buffer adaptor, frames from `BoardRenderer`; a 0.5 s lead-in still and a 1 s end still.
- Export runs off the main actor, reports progress, can be cancelled, and writes to a temporary file handed to the share sheet.
- Before sharing, show the file size. Budget: under 8 MB for 15 s at 1080 × 1920.

## 8. Accessibility

- Every token: "Number 9, striker, edge of the box" (+ ", step 3 of 6" while editing). Zones come from `Placement`: thirds (defensive, middle, final), channels (left wing, left half-space, centre, right half-space, right wing) and named areas (six-yard box, penalty area, edge of the box, centre circle).
- VoiceOver can move a selected token with the adjustable action (nudge up/down/left/right by 2% of the pitch).
- Dynamic Type in every sheet and the steps strip; the board itself scales with the screen.
- Reduce Motion: playback steps through with 0.3 s crossfades. Exports are unchanged.
- Colour is never the only difference between sides or arrow kinds (D-15).

## 9. Acceptance criteria (each mirrored in `features.json`)

Fixtures: **the hero fixture** is `examples/overlap-left.tactic`, 5 steps (D-29); **a full fixture** is an 11-v-11, 6-step tactic with a ball, added in the core lane.

**Core (tests first)**
- [ ] Every file in `examples/` and the fixtures decodes, re-encodes and decodes again to an equal `Tactic`; an empty board (0 tokens) round-trips. verify: `FormatRoundTripTests`
- [ ] Every row of the FORMAT rules table has a case: each "refuse" row gives the generic or newer-version error and no crash; each "repair" row opens with the value clamped, truncated or dropped as written; runs are anchored to neighbouring positions and a run on the last step is dropped. verify: `ImportValidationTests` (one case per row), then `FuzzImportTests` on Day 6
- [ ] `Timeline.state(at:in:)` at `t = 0` equals step 1, at the end equals the last step, mid-move matches hand-computed ease-in-out cubic within 0.001, a token with a run follows it by arc length, and two calls with the same input are equal. verify: `TimelineTests`, plus one mutation run (break the easing, confirm red, restore)
- [ ] 26 formations load (18 eleven-a-side, 4 seven-a-side, 4 five-a-side; D-63) and 22 roles; applying a formation keeps every player's name and number. verify: `PresetTests`

**Look and accessibility**
- [ ] Every kit palette number ink passes WCAG AA (4.5:1) on its fill. verify: `TokenContrastTests`
- [ ] Every player token has a VoiceOver label from number, role and zone ("Number 9, striker, edge of the box"), with ", step 3 of 6" while editing; the adjustable action nudges a selected token by 2% of the pitch. verify: `PlacementTests` for zone words; UI test `BoardAccessibilityUITests` reads the 4-3-3 labels and performs one increment
- [ ] Every toolbar and strip control has a VoiceOver label, and every sheet lays out at AX5 Dynamic Type without clipped text. verify: `ControlLabelUITests` (every hittable control has a non-empty label); AX5 simulator screenshots of each sheet reviewed by Chime
- [ ] The board on screen and an exported frame at the same `t` and size agree on at least 99.5% of pixels within 16/255 per channel (D-60, supersedes D-24), and no pixel is more than 64/255 off (D-61). The screen side is captured from the real board view (`Canvas` + `withCGContext`) with `ImageRenderer`, not from a second offscreen call. verify: `RendererParityTests`

**Editing**
- [ ] Drag moves a token in the current step and clamps it to the pitch; tap selects; the inspector changes name, number, role and side; formation and pitch pickers apply. verify: `BoardEditorTests` on the editing model; Chime approves the board screenshot (baseline in `fidelity/refs/`)
- [ ] Steps: add (duplicates the current step), delete, reorder and per-step duration; every edit, including delete, can be undone and redone. verify: `StepEditingTests` using the document's `UndoManager`
- [ ] A 5-step move is built by hand in under 60 s, and a first move from New tactic to the share sheet takes under 2 minutes. verify: manual, timed on the iPhone 14 Pro, numbers in PROGRESS.md
- [ ] A finger stroke (iPhone draw mode) and a Pencil stroke (borrowed iPad) that start on a player become that player's run, simplified to at most 200 points. verify: `PathSimplifierTests`; manual on both devices (D-26)

**Playback and export**
- [ ] Playback has no visible stutter, and Reduce Motion switches in-app playback to step-through crossfades. verify: manual on the iPhone 14 Pro (play the hero fixture 3 times with Reduce Motion off and on)
- [ ] The exporter takes no Reduce Motion input, so the setting cannot change a video. verify: `VideoExportTests` asserts the exporter's configuration type has no such field (compile-level) and two exports of the hero fixture decode to identical frames
- [ ] The exported video of the hero fixture is H.264, 1080 × 1920, 30 fps, has `30 × (0.5 + timeline duration + 1.0)` frames (±1), and its size is at most `8 MB × length ÷ 15 s`. verify: `VideoExportTests` reads the file back with AVFoundation
- [ ] The export sheet shows the estimated size and length before export, shows progress ("Rendering n of N frames"), Cancel stops it and deletes the temporary file, and the actual file size is shown before the share sheet. verify: `ExportFlowUITests`; `VideoExporterTests` for cancel
- [ ] The hero fixture exports in under 10 s on the iPhone 14 Pro and plays in WhatsApp. verify: manual: 1. install a Release build; 2. open the hero fixture; 3. time Export to the share sheet; 4. send it to yourself in WhatsApp and play it; 5. log time and size in PROGRESS.md
- [ ] Image export is a PNG of the current step whose pixel width is twice the board's on-screen width in points (for example, a 402 pt board gives 804 px). verify: `ImageExportTests`

**Files and links**
- [ ] A `.tactic` file opens in the app from Files and from AirDrop, and saves back. verify: manual on the iPhone 14 Pro: 1. AirDrop a fixture from the Mac; 2. it opens in the app; 3. edit, close, reopen from Files

**After Day 7 (D-36), kept so the link work starts from a spec:**
- A hostile link (wrong prefix, bad base64, corrupt stream, a payload that inflates past 256 KB) is refused with the generic error, and the bomb case stops inflating at 256 KB. verify: `LinkCodecTests`
- A link round-trips every fixture; its payload decodes with the Python line in FORMAT (padding restored, `wbits=-15`); each fixture's link length is recorded; a link over 2,000 characters offers the file instead. verify: `LinkCodecTests`; the Python line run on one fixture link
- Opening a valid link or QR creates a new untitled document holding exactly that tactic, saved like any new document; an invalid one shows the generic error. verify: `LinkOpenUITests` opens a fixture link with the app running; manual once from the Camera app
- `agmen://` opens the app from Messages and from a QR code in the Camera app; whether WhatsApp makes it tappable is recorded. verify: manual after Day 7 (Messages, WhatsApp, QR), results in PROGRESS.md

## 10. Risks and assumptions

- **Export is too slow or too big on the iPhone 14 Pro** — cheapest test: on Day 2, a throwaway exporter writes 450 frames of the pitch at 1080 × 1920 and logs time and size; set the H.264 bitrate explicitly (about 4 Mbps fits 8 MB per 15 s).
- **`Canvas` with `withCGContext` and an offscreen context differ more than the D-24 tolerance** — cheapest test: write `RendererParityTests` with the pitch alone before drawing tokens.
- **The borrowed iPad isn't available or runs below iPadOS 26** — cheapest test: ask for the model and version now (O-4); if it fails, Pencil drops to Should-after-Day-7 and the finger path carries the demo.
- **Free signing:** builds expire after 7 days and free accounts allow only a few devices (from memory: about 3 per device type; enough for one iPhone and one iPad). Note the expiry on every install.
- **The Mac's memory is shared with Split It** — one simulator at a time; shut it down after each run.
- **iOS 26 coverage:** simulators run iOS 27 and the iPhone runs 27.0.1; only the borrowed iPad runs 26.6.1 (D-31) — covered by the `build-ios26` proof check before every commit (D-32).
- **Verified 6 Nov:** Apple's `.zlib` compression writes raw DEFLATE without a header (D-25).

## 11. Open questions

None open. O-1 to O-8 are resolved in `DECISIONS.md` (D-28 to D-36). New questions go under Open there.
