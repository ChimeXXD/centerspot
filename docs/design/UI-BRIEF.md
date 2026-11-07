# UI brief

How each Agmen screen looks and behaves. §1–3 written 7 Nov 2026 from the chosen direction (D-44) and the approved mockup (D-50); §4–6 hold screens, copy, states and test IDs, with `MOCKUP-GAPS.md` listing what the mockup still has to cover. Copy marked *new* can change at screen review.

## 1. Direction: Floodlight Chalk (D-44, D-50)

A night match on TV, explained at a chalkboard. Floodlight's palette (near-black chrome, a dark striped pitch, white chalk lines, one electric lime) with Chalk's type (rounded Nunito everywhere, handwritten Kalam for step notes). The mockup in `mockup/` is the baseline; `Agmen/Design/Tokens.swift` is the source of truth from here (D-12).

Rules every screen follows:
1. **The pitch is the picture.** One nav bar, one context row, one strip, one toolbar. Nothing floats over the pitch while editing; actions for a selected player or step live in the context row under the pitch.
2. **Reads in a 9:16 video at a glance:** dark pitch, chalk lines at 55% white, numbers in heavy Nunito, no hairlines under 1.4 pt at phone size.
3. **In the interface, lime marks what's live:** the current step, the playing state, the primary button. It is also the home kit and the pass arrow (D-53), so the selected player is marked with a white chalk ring instead, which shows on every kit.
4. **Sides differ by shape** (D-15): home filled discs, away rings with a dark centre. Arrow kinds differ by line: run solid, pass dashed, dribble wavy, press double chevron.
5. **Handwriting is for the coach's voice only:** step notes, the launch tagline, first-run hints. Everything else is Nunito.
6. **One fixed look for exports:** the same dark board, title band in Nunito, notes in Kalam, a small "Agmen" corner mark (D-38).
7. **No club looks** (D-13); custom icons and illustrations are on hold (D-51).

## 2. Tokens (`Agmen/Design/Tokens.swift`)

Generated once from the mockup's CSS by `mockup/tokens_to_swift.py`; edit the Swift file from now on.

- **Colour:** background `#0B0F14`, surfaces `#151B23` / `#1E2630` / `#27313D`, text `#F2F5F7`, muted `#93A0AD`, accent lime `#C6FF3D` with ink `#0B0F14`, danger `#FF6B6B`; pitch stripes `#0F241B` / `#112A1F`, chalk white at 55%; arrows run white, pass lime, dribble `#FFD84A`, press coral.
- **Kit palette** (palette keys used by `.tactic` files): `lime` (home default), `coral` (away default), `blue`, `red`, `orange`, `yellow`, `green`, `purple`, `black`, `white`, `sky`, `maroon` (D-53). Each has a fill and a number ink that pass WCAG AA (4.5:1); `black` and `maroon` get a light outline so they reach 3:1 on the pitch. Away rings draw the fill as the ring with a white number on a dark centre. Proven by `TokenContrastTests`.
- **Type:** Nunito (variable) and Kalam Regular, bundled under SIL OFL (`Agmen/Design/Fonts/`). Large title 34/heavy, title 22/heavy, headline 17/bold, body 15/semibold, caption 12/semibold, note Kalam 18; all scale with Dynamic Type. Token numbers use heavy Nunito sized to the board, not Dynamic Type.
- **Spacing** 4 · 8 · 12 · 16 · 24 · 32. **Radius** sheet 20, item 12, buttons and chips as capsules. **Touch targets** at least 44 pt (players get an invisible 44 pt hit area).

## 3. Motion

- Playback motion is the Timeline (SPEC §3), never SwiftUI animations.
- UI motion uses one curve, `timingCurve(0.2, 0, 0, 1)`: select a player 150 ms (white chalk ring, slight lift), step change 220 ms, sheets 320 ms, toast 200 ms. Adding a step pulses the new chip once.
- Reduce Motion: crossfades only, playback steps through with 0.3 s crossfades (rule 8); exports never change.

## 4. Screens

### 4.1 Launch / library (Agmen's own screen, D-56; supersedes `DocumentGroupLaunchScene`)
- Title art: "Agmen" in heavy Nunito and the Kalam tagline over a faint chalk pitch fragment. Then **New tactic** (the lime capsule), a "Recent" header and a two-column grid of tactic cards, newest first (one column at accessibility text sizes).
- A card draws its step 1 at rest with `BoardRenderer` (D-07), then the title and "11-a-side · 5 steps". Tap opens the board. Press and hold: Rename (alert with a text field), Duplicate ("… copy"), Share (the `.tactic` file), Delete, which asks first: "Delete “<title>”?" / "This can't be undone." VoiceOver reads "<title>, N steps" and offers the same four actions.
- First launch adds the example move "Overlap down the left". With no tactics: "Your tactics show up here."
- Footer (caption, muted): "Saved on this iPhone. Find them in Files › On My iPhone › Agmen." ("iPad" on iPad). If files in the folder can't be read, a count says so.
- New tactic opens the formation picker first. A `.tactic` opened from AirDrop, WhatsApp or Files is checked, copied into the library and opened; a bad one shows the §4.8 message.
- Test IDs: `launch.new`, `library.title`, `library.tagline`, `library.recent`, `library.card.<n>` (1 is the newest), `library.empty`, `library.recents-hint`, `library.rename.save`, `library.delete.confirm`.

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
- `NavigationSplitView`: Agmen's library screen (§4.1, D-56) in place of the system document browser; board in the centre; inspector trailing.
- Pencil draws, finger moves (SPEC §6). Hover with Pencil shows where a run will start.

## 6. Accessibility checklist
- VoiceOver labels per SPEC §8; adjustable action to nudge a token.
- Every toolbar button has a label and a large-content-viewer title.
- Dynamic Type up to AX5 in sheets and the strip (the strip scrolls).
- Hit targets ≥ 44 pt; tokens get an invisible 44 pt hit area even when drawn smaller.
