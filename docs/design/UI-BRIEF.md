# UI brief

How each Agmen screen looks and behaves. **Draft, 6 Nov 2026.** §4–6 (screens, copy, states, test IDs) are ready to build from. §1–3 (direction, tokens, motion) are filled in on Day 1, after Chime picks a direction from `direction-board/` (D-12). Copy marked *new* can change at screen review.

## 1. Direction (Day 1)

To be written from Chime's pick. Constraints any direction must meet:

1. **The pitch is the picture.** Chrome stays out of the way: one toolbar, one strip. The board fills the screen on iPhone.
2. **Reads in a 9:16 video at a glance**: high contrast between pitch, tokens and arrows, big numbers, no thin hairlines that vanish after compression.
3. **No club looks** (D-13): neutral kit palette, generic pitch.
4. **Sides differ by shape** (D-15). Arrow kinds differ by line style.
5. Works in light and dark, but the exported video has one fixed look (decide on Day 1: likely dark pitch, like a broadcast graphic).

Questions for the direction board: grass stripes vs flat chalkboard vs dark broadcast; token style (flat disc, shirt glyph, ringed disc); type for numbers (rounded vs condensed sport); how the steps strip looks (numbered dots, mini thumbnails, film strip).

## 2. Tokens (`Design/Tokens.swift`, Day 1)

To fill from the chosen direction:

- **Kit palette** (palette keys used by `.tactic` files): `blue`, `red`, `orange`, `yellow`, `green`, `purple`, `black`, `white`, `sky`, `maroon`. Each has a fill and a contrasting number ink that passes WCAG AA, and a ring variant for away sides.
- **Pitch themes:** at least one for the app and one for export (may be the same).
- **Arrow inks** per kind, plus the line-style rule (D-15).
- **Spacing** 4 · 8 · 12 · 16 · 24 · 32. **Radius** sheet 20, strip item 12, chip capsule.
- **Type:** text styles for Dynamic Type; one face for token numbers (tabular).
- **Motion:** system motion first; custom moves each get one job (press, step change, play/pause, export progress).

## 3. Motion (Day 1)

- Playback motion is the timeline (SPEC §3), not SwiftUI animations.
- UI motion: selecting a token (lift + ring, 0.15 s), adding a step (the strip slides and the new step pulses once), play/pause morph, export progress. Reduce Motion: crossfades only.

## 4. Screens

### 4.1 Launch / library (`DocumentGroupLaunchScene`)
- Title art (the app name over a pitch fragment with one animated run), **New tactic** (primary), the system browser below.
- New tactic opens the formation picker first.
- Test IDs: `launch.new`.

### 4.2 Board (iPhone)
- **Top bar:** back to library (system), title (tap to rename), **Undo**, **Redo**, overflow (Pitch, Sides & colours, Duplicate, Debug).
- **Pitch:** fills the width, vertical, safe-area aware. Tokens per SPEC §4.
- **Bottom toolbar:** Formation · Draw (toggle, iPhone) · **Play** · Export · Share.
- **Steps strip** above the toolbar: numbered step chips (1, 2, 3 …), the current one highlighted, **+** at the end. Long-press a chip: Duplicate, Duration, Note, Delete. Drag to reorder.
- **Empty state** (no tokens, e.g. a blank 5-a-side): "Pick a formation to start" *(new)* with a button.
- Test IDs: `board.pitch`, `board.token.<id>`, `toolbar.formation`, `toolbar.draw`, `toolbar.play`, `toolbar.export`, `toolbar.share`, `steps.add`, `steps.chip.<n>`.

### 4.3 Inspector (sheet on iPhone, trailing column on iPad)
- Fields: Name, Number (0–99), Role (picker from `roles.json`, grouped by line), Side, Delete player.
- Ball and cones: position nudge only.
- Test IDs: `inspector.name`, `inspector.number`, `inspector.role`, `inspector.side`, `inspector.delete`.

### 4.4 Formation picker (sheet)
- Segmented: 11-a-side · 7-a-side · 5-a-side. Grid of mini pitches with the shape name ("4-3-3").
- Applying to a board with players asks once: "Move players to 4-2-3-1? Names and numbers stay." *(new)* with Move / Cancel.
- Test IDs: `formation.<id>`.

### 4.5 Playback
- Replaces the steps strip: Play/Pause, a scrubber with ticks at each step, the current step note, Loop toggle, speed (0.5×, 1×) *(Should)*.
- Tap the pitch while playing to pause.
- Test IDs: `playback.toggle`, `playback.scrubber`, `playback.loop`.

### 4.6 Export (sheet)
- Live preview playing at the chosen ratio; safe zones as dashed overlays (preview only).
- Preset: **Vertical 9:16** (default) · Square · Wide *(Should)* · Image.
- Title band toggle; step notes toggle.
- Estimated size and length: "About 6 MB · 14 s" *(new)*.
- **Export** → progress ("Rendering 212 of 420 frames") with Cancel → share sheet.
- Errors: "Couldn't make the video. Try again, or export an image." *(new)*
- Test IDs: `export.preset.<id>`, `export.start`, `export.cancel`, `export.size`.

### 4.7 Share
- Share sheet with: the `.tactic` file, **Copy link**, **Show QR** *(Should)*.
- Link too long: "This tactic is too big for a link. Send the file instead." *(new)*

### 4.8 Import errors (plain words)
- Newer version: "Made with a newer version of Agmen."
- Invalid or too big: "This file isn't a tactic we can open." *(new)*

## 5. iPad (Should, O-3)
- `NavigationSplitView`: library is the document browser; board in the centre; inspector trailing.
- Pencil draws, finger moves (SPEC §6). Hover with Pencil shows where a run will start.

## 6. Accessibility checklist
- VoiceOver labels per SPEC §8; adjustable action to nudge a token.
- Every toolbar button has a label and a large-content-viewer title.
- Dynamic Type up to AX5 in sheets and the strip (the strip scrolls).
- Hit targets ≥ 44 pt; tokens get an invisible 44 pt hit area even when drawn smaller.
