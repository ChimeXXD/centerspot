# Kickoff prompts for Claude CLI

Open Terminal in this folder (`Projects/Personal Projects/Tactics Board`) and run `claude`. Paste one prompt per session.

## Session 1: Day 0 (setup)

```
Read CLAUDE.md, docs/HANDOFF.md, docs/PLAN.md and docs/DECISIONS.md. We're starting Day 0 of Agmen.
Set up the project: git init, a private GitHub repo ChimeXXD/agmen, xcodegen generate, and an empty
DocumentGroup app (TacticDocument placeholder) that builds and launches on the iPhone 18 Pro simulator and on my
iPhone with my free Personal Team. Add one Swift Testing test. Check the agmen:// URL scheme opens the app.
Commit and push after each green step, tick the Day 0 boxes in docs/PLAN.md and docs/features.json, and log the
session in PROGRESS.md. Ask me before anything that costs money or adds a dependency.
```

## Session 2: Day 1 (design direction)

```
Read CLAUDE.md, docs/HANDOFF.md and docs/design/UI-BRIEF.md. Today is Day 1: design direction (D-12).
1. Collect 30–50 references by surface (docs/design/REFERENCES.md lists surfaces and searches). Use the reference
   library connector if it's connected (never name it in the repo); keep images in docs/design/reference-board/images/ (git-ignored). Note each pick.
2. Write the pattern summary.
3. Build docs/design/direction-board/index.html with three distinct directions. Each shows: the board on iPhone
   with a 4-3-3, a move mid-playback with a run and a pass arrow, the steps strip, and the 9:16 export frame.
   Use only our own artwork (no club badges or real kits, D-13).
4. While I look at the board, run the core lane (D-23): Model/, the .tactic format and Timeline, tests first.
5. Stop and ask me to pick. Then fill UI-BRIEF §1–3, add Agmen/Design/Tokens.swift, and log the pick as a
   new decision.
```

## Session 3+: build days

```
Read CLAUDE.md, docs/HANDOFF.md, the latest PROGRESS.md entry and docs/PLAN.md. Continue with Day <N>.
Tests first for Model/, Engine/ and LinkCodec. Pass the day's gate before moving on, check UI on my phone,
commit and push after each green step, and update PLAN.md, features.json, PROGRESS.md and HANDOFF.md.
```
