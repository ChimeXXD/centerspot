# Mockup gaps to cover in the redo

From the fresh-context check of the draft mockup (commit 80870b3) against SPEC, UI-BRIEF and the decisions, 6 Nov 2026. The draft is superseded by D-47: the redo is built from Chime's picks, and must also cover everything below.

## Must
1. Add tokens: a control to add a player (either side), the ball and a cone (scope: "two sides, ball").
2. Ball and cones are selectable and draggable, with a nudge-only selection state (UI-BRIEF §4.3).
3. Pitch picker sheet: full, 7-a-side, 5-a-side; stripes or plain (SPEC §9).
4. Sides & colours sheet. **Needs Chime:** how the file's palette keys (`blue`, `orange`, …) map to the Floodlight colours (lime home, coral away).
5. Step editing states: duration picker (0.3–5 s), note editor (140 characters), drag-to-reorder.
6. Step chip gestures. **Needs Chime:** UI-BRIEF says long-press shows the actions and drag reorders; the draft used tap for actions and long-press to reorder.
7. Formation replace confirmation: "Move players to 4-2-3-1? Names and numbers stay." Move / Cancel.
8. VoiceOver label: number, role name from roles.json, zone, ", step n of m"; tokens adjustable (nudge).
9. Export preview shows dashed safe zones (preview only).
10. Image export: selected state ("Export image", pixel size = 2 × board points) and done state.
11. Newer-version import alert: "Made with a newer version of Agmen."
12. Press arrows drawn as a short double chevron, never a plain line (D-15).
13. Copy: the preset is "Vertical 9:16" (UI-BRIEF §4.6), not "Story 9:16".
14. Test IDs: `inspector.role` and `inspector.side` as in UI-BRIEF §4.3.
15. Tap the title to rename (or note that DocumentGroup's rename covers it).
16. Launch title art: the name over a pitch fragment with one animated run.
17. Playback time shows the timeline (about 0:06.5), not the export length (8 s with stills).
18. AX5 Dynamic Type check for sheets and the strip (in the simulator).
19. Debug screen (Debug builds): load an example, export timing log, reset.
20. "Save to Photos" needs the Photos add-only permission string; confirm it stays (it's in project.yml).

## Should
- Spotlight a player in the export (D-40).
- Lineup card, separate from the step PNG.
- Square and Wide previews (Wide rotates the pitch, D-16); all 8 eleven-a-side shapes plus 7- and 5-a-side tiles.
- Draw mode: iPad Pencil hover state; the D-28 result (next step moved or added). **Needs Chime:** SPEC §6 says a stroke starting on a player always becomes a run, but passes also start on players.
