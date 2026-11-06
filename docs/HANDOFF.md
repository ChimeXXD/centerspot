# Handoff: read this first when you pick the project back up

## Latest: Day 0 done except the launch on the phone, Fri 6 Nov 2026

### Where it stands
- **The app is called Agmen** (D-42; folder on disk is still `Tactics Board`). Repo: private `ChimeXXD/agmen`.
- Empty `DocumentGroup` app with a placeholder `TacticDocument`; 3 Swift Testing tests pass on iPhone 18 Pro (iOS 27.0); builds on iPad Pro 13-inch (M5) iOS 26.5.
- **Installed on Chime's iPhone 14 Pro**, not launched yet. Signing expires **13 Nov 2026, 21:30 Lagos time**.
- Decisions D-21 to D-42 were made this session (process, SwiftUI-only design, two lanes on Day 1, render tolerance, raw DEFLATE, brother's iPad, import rules, run anchoring, hero move, Squad Snap cut, test devices, iOS 26 check, opponents, iPad scope, sharing, lead user, corner mark, WhatsApp + Discord, spotlight, name). Nothing is open.

### What Chime asked for, in order
1. Refine the PRD, explain the product and platform, use PROCESS.md as a foundation (D-21).
2. Use the brother's iPad Pro 13-inch (M4), iPadOS 26.6.1, Apple Pencil Pro (D-26, D-31).
3. Design straight in SwiftUI (D-22); core lane in parallel on Day 1 (D-23).
4. **Ask decisions as click-through questions with three options, as often as useful.**
5. **Only propose names verified unused.** Picked Agmen from Greek/Latin options.
6. Start Day 0 right away.

### Do next
1. Ask Chime (click-through) before launching Agmen on the phone; then tick D0-3.
2. Day 1 (D-23): design lane (references → three directions → Chime picks → UI brief §1–3 → tokens; lead user is gamers, creators and EA FC Clubs squads, D-37) and the core lane (Model/, format, timeline, tests first; fixtures in `AgmenTests/Fixtures/`).

### Deferred from the Day 0 review
- CI uses `iPhone 17 Pro, OS=latest` on the default Xcode of `macos-26`; local is Xcode 27.2 (fix by Day 6).
- iPad multi-window scene manifest (with the split view, after Day 7).
- proof.json `build` duplicates the build inside `test`; removing it needs Chime's OK.
