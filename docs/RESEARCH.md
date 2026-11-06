# Research

The full market research, competitors and sources are in `PRD.md` (25 Oct 2026). This file adds what came after and the technical notes that shape the build. Add new findings here with a date and a link to a page you actually opened.

## Added 5 Nov 2026 (shortlist check)

- **Squad sharing already exists for FC.** FUT.GG's app and FUT Squad Builder build and share Ultimate Team squads ([FUT.GG app](https://www.fut.gg/app/)). So Squad Snap is a way to get your own squad onto the board fast, not a product (D-17).
- **FC 26 Clubs kits can't take artwork.** The in-game kit editor is template-based: pick a pattern and colours; no image import or export. PC texture mods work offline only ([onReplay](https://onreplay.ai/blog/ea-fc-kit-creator/)).
- **FM26 takes community 2D kit packs** ([Passion4FM](https://www.passion4fm.com/fm26-fmg-kits-by-fm-graphics/)). Kit Lab stays a separate idea (D-18).

## Positioning recap (from the PRD)

- TacticalPad ($39.99/yr) exports 4:3, 16:9 and 16:10, no 9:16.
- Tactics Manager (SoccerTutor) exports MP4 but caps animations: 1 free, 5 on the £79.99 Pro plan.
- Lineup apps (Lineup11, Soccer Line Up Builder 11) are static and sell club-look packs.
- FM26 split tactics into in-possession and out-of-possession, which our two-phase format supports (D-20).
- EA FC players trade tactic codes; FUT.GG reports 4-2-1-3 in 26% of tracked squads, so it's in the presets.

## Technical notes

- **One renderer.** `GraphicsContext.withCGContext` lets `Canvas` hand Core Graphics drawing to the same code export uses (D-07). `ImageRenderer` can't render UIKit-backed views such as PencilKit, one more reason not to rely on it for export (PRD sources).
- **Video from frames:** `AVAssetWriter` + `AVAssetWriterInput` (H.264) + `AVAssetWriterInputPixelBufferAdaptor`, appending `CVPixelBuffer`s with explicit presentation times (PRD source: IMG.LY). Use a `CVPixelBufferPool` from the adaptor; draw each frame into the buffer's memory with a `CGContext`.
- **PencilKit:** `PKCanvasView` with `drawingPolicy = .pencilOnly` on iPad (finger free to move tokens); read `PKStroke.path` points, simplify, convert to normalised coordinates (D-08).
- **Free provisioning** supports App Groups and local features but not Associated Domains, so no universal links (D-10). Verify on Day 0 that a custom URL scheme opens the app from Messages.
- **Documents:** `DocumentGroup(newDocument:)` + `FileDocument`; declare the UTType in `project.yml` (exported type, `public.json` conformance) so Files and AirDrop route `.tactic` files to the app.

## Lessons from Meridian (5 Nov 2026)

See `DECISIONS.md` L-1 to L-5: device checks over renders, tests first, a decisions log, one simulator at a time, honest numbers in the case study.
