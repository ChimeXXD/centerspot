# How we build: the Meridian process

This is the exact process we used to build **Meridian** (29 Oct – 6 Nov 2026, 153 commits, from an empty folder to a
public repo, a private beta on Chime's iPhone and a live case study). Use it as the yardstick for Tactics Board:
when a session is unsure what to do next, or how to know something is done, the answer is here.

It is written from Meridian's own records: `docs/PLAN.md`, `docs/DECISIONS.md`, `PROGRESS.md`, `docs/HANDOFF.md`,
`docs/SKILL-PROMPTS.md`, `.claude/proof.json` and the session history. Where something went wrong, the rule that came
out of it is in [Lessons](#9-lessons-what-went-wrong-and-the-rule-it-left).

---

## 1. The shape of the project

| Phase | What happens | Ends when |
| --- | --- | --- |
| **Paperwork** (before Day 0) | PRD → research → decisions → one-week plan with gates → spec with a check per requirement → `features.json` → CLAUDE.md → kickoff prompts | Every decision has a D-number and every requirement says how it will be verified |
| **Day 0: Setup** | Repo, XcodeGen project, placeholder app on the **real iPhone** with free signing, proof gate, private GitHub repo | The empty app runs on the phone and the repo is pushed |
| **Day 1: The core, tests first** | The part that must be right, with no UI (Meridian: the time engine) | The test matrix is green |
| **Day 2: Design direction** | References → three directions → Chime picks → UI brief → tokens in code | Every screen has a brief section and a style is picked |
| **Days 3–5: Build** | Screens, then the system surfaces (Meridian: widgets, then the Live Activity) | Each screen passes its fidelity check and Chime approves it |
| **Day 6: Harden** | Refresh and failure states, CI, an accuracy audit, skill reviews, private beta | CI green, audit passes, beta on the phone |
| **Day 7: Ship** | README, demo video, case study, open-source checklist, repo public | Repo public, case study live. **Never cut Day 7.** |
| **After** | Chime's feedback from real use, one request at a time | Each request logged, built, proven, installed |

The **gate** at the end of each day is a hard stop: don't start the next day until it passes. If a day overruns,
cut that day's **Should** items, never a Must and never Day 7.

---

## 2. Paperwork first (already done for Tactics Board)

Meridian started as a PRD and became a set of documents that every session reads before touching code. Tactics Board
already has these; keep them alive the same way.

| File | What it holds | Rule |
| --- | --- | --- |
| `CLAUDE.md` | What we're building, the frame (portfolio, $0, private beta, public on Day 7), fixed stack, layout, commands, **numbered correctness rules** | Read first, every session. A new hard-won rule goes here. |
| `docs/DECISIONS.md` | One row per decision: **D-xx**, the decision, *why* (with Chime's words and the evidence) | Never reopen a decision unless it blocks you; then write it under **Open** and ask Chime. A new decision that replaces an old one says "Supersedes D-xx". |
| `docs/PLAN.md` | The week at a glance (day, focus, gate), the Must / Should / Cut table, zero-cost rules, then each day's checklist split into **"Claude does"** and **"Chime does"**, a ready prompt and the gate | Tick boxes as work completes, with a one-line note of what was actually done |
| `docs/SPEC.md` | User flows and **acceptance criteria**, each ending in `verify:` (the test, script or screenshot that proves it) | A requirement with no `verify:` isn't finished being written |
| `docs/features.json` | One item per unit of work: `id`, `day`, `priority`, `criteria`, `verify`, `passes`, `evidence` | `passes: true` only with evidence: test names and counts, the command run, the date |
| `PROGRESS.md` | Build log, newest first. Each entry: **Changed**, **Checked** (real numbers), **Not verified**, **Next** | One entry per session or batch. Say what *wasn't* checked. |
| `docs/HANDOFF.md` | The latest session summary: where it stands, what Chime asked for in order, choices made, files, what's not done and why, next steps, open questions | Rewritten at the end of every session so the next one starts cold without losing anything |
| `docs/RESEARCH.md` | Sources and findings behind decisions | Primary sources over summaries |
| `.claude/proof.json` | The checks that gate every commit (build, test, spec) | Changing a check needs Chime's OK |

---

## 3. The daily loop

Every working session on Meridian ran this loop. One **unit** is one feature, screen, bug or decision.

1. **Start cold, read first.** CLAUDE.md → HANDOFF.md → the day in PLAN.md → the last PROGRESS.md entry → the
   decisions that touch today's work.
2. **Restate the ask.** When Chime asks "do you understand?", say back what will be built, ask only the questions
   that change the work, then start. **Write any new instruction into DECISIONS.md the same turn**, quoting Chime
   (see Lessons: instructions that weren't written down were lost).
3. **Split big asks into units** and work them one at a time. Long work: keep a task list current.
4. **Take specifics from their source.** Copy from the spec, the brief, the API docs or a real response. Never type
   copy, numbers or requirements from memory.
5. **Tests first for the core** (Meridian: everything in `Shared/Time/`). Record real API responses as fixtures in
   `Tests/Fixtures/` and test against those. Red first, then green.
6. **Iterate with the narrowest check:** one test file or one test name, never the whole suite while fixing.
7. **Prove the test can fail.** For a new rule, break the code on purpose (a mutation run: a window of 365 days made
   366, a filter made to always return true) and confirm the test goes red, then restore.
8. **UI: build, screenshot, fidelity check** (section 4). "It's live" means two screenshots seconds apart differ,
   never one render.
9. **Review:** `/code-review medium --fix` on the diff (`high` for risky work: data, concurrency, deleting things).
   Read what it fixed; product calls it skips go to Chime.
10. **Verify against the ask:** a fresh-context verifier (`proof:verifier`) checks the change against Chime's exact
    words and the features.json item, and reports gaps only. Fix the real ones.
11. **Run the full gate** (build, test, spec) on its own, with no other simulator job running.
12. **Update the records:** tick PLAN.md, set the features.json item with evidence, add the PROGRESS.md entry.
13. **Commit in its own command, then push.** Conventional message (`feat:`, `fix:`, `test:`, `chore:`, `docs:`).
    Push after every commit; Chime wants every change on GitHub.
14. **Install on Chime's iPhone over Wi-Fi** after every app change (build for the device, `devicectl` install).
    Install only: launching the app or taking a phone screenshot needs a fresh go-ahead. Note the signing expiry
    (free signing lasts 7 days).
15. **Report plainly:** what changed in Chime's terms, what was checked with numbers, what wasn't, what Chime needs
    to decide. End the session by rewriting HANDOFF.md.

---

## 4. The design process

Meridian's look was decided before its screens were built, and once built **the app became the source of truth**.

1. **References by surface.** One search per surface (each screen, the widget, the Live Activity). Meridian's board
   had 154 references; Chime liked 47. Note the pattern taken from each pick. Keep reference images out of git and
   **never name the reference library in public** (repo, commits, case study): say "I designed".
2. **A board, then picks.** Show the references as an HTML board grouped by surface; Chime picks.
3. **Three directions, side by side** (`docs/design/direction-board/`), each showing the real content in the real
   frames. Chime picks one (Meridian: Night Sky; Glass and Poster Colour rejected) and says what they don't like
   (no brown background). Log the pick as a decision.
4. **Studies for the one detail that carries the product** (Meridian: three numeral styles for the countdown).
5. **Chime designs the first version by hand in Figma.** It's a design-engineer portfolio piece, so the case study
   must show the design work.
6. **`docs/design/UI-BRIEF.md`:** one section per screen and surface: its job, the references it borrows from, every
   element **with its test ID**, its copy taken from the spec, and every state (empty, loading, error, long text).
7. **Tokens and components in code** (`Design/Tokens.swift`, each component with a `#Preview`).
8. **Build the screen in SwiftUI from the brief.**
9. **Fidelity check:** `fidelity/inventory/<screen>.json` lists the IDs and exact copy from the brief;
   `fidelity/verify-screen.sh <screen>` runs a UI test that launches the screen and checks every item, then prints
   **ALL PASS** and saves a screenshot.
10. **Chime approves from the screenshot**, with one round of notes per screen. Approved shots become the
    `fidelity/refs/` baselines.
11. **Check it on the phone**, not only in renders. System surfaces (widgets, Live Activities) lay out differently on
    the device than in `ImageRenderer` renders.
12. **Design system site** (`design-system/`) mirrors the app: a design change goes into SwiftUI first and the site in
    the same commit. Rendered pictures reach the site through a sync script only after Chime approves them.
13. **Plain words, no legends.** If something needs a colour code or a dot explained, say it in words instead
    (Meridian replaced status dots with "Out", "Expected", "time not announced").

---

## 5. The checks that decide "done"

Done means a check you can run says so, not that the work looks right.

| Check | Runs | Proves |
| --- | --- | --- |
| Unit tests (Swift Testing) over recorded fixtures | Every change, narrow while fixing | The logic, including edges (time zones, clock changes, window boundaries) |
| Mutation run | Once per new rule | The test can actually fail |
| `fidelity/verify-screen.sh <screen>` | After UI work | Every element and its exact copy is on screen |
| Proof gate (`.claude/proof.json`): build, test, spec | Before every commit, alone | Nothing else broke; every spec requirement has a `verify:` |
| `/code-review --fix` | After each code change | Bugs a second reader catches |
| `proof:verifier` | Once per unit, before commit | The change meets Chime's exact ask |
| CI (GitHub Actions) | By hand while private; every push and PR once public | It builds on a clean machine |
| On the phone | After install; with Chime's go-ahead for screenshots | Real device layout, real timers, real data |
| Chime's approval | Each screen | It's what Chime wanted |

Never weaken a check to pass it. If a check is wrong (for example it depends on live data that can't be
guaranteed), say why, ask Chime, and only then change it.

---

## 6. Day by day: what Meridian actually did

| Day | Meridian's focus | What made it work |
| --- | --- | --- |
| 0 | Setup | The gate asked for the **free-signing route on the real phone** (widget reading App Group data) before building on it; the widgets were approved on the phone on 1 Nov |
| 1 | Time engine, tests first | Recorded real TVmaze episodes as fixtures; a test matrix of every rule × 6 zones × summer and winter × clock-change dates |
| 2 | Design direction, data clients, Search | References → board → three directions → pick → brief → tokens, while the data clients were built in parallel |
| 3 | App screens | Fidelity inventories per screen; Chime's notes per screen; a 5-person glance test on the main screen |
| 4 | Widgets | One JSON snapshot shared with the widget; timers that stop at zero; checked on the phone |
| 5 | Live Activity and Debug menu | A Debug menu that fakes a release in minutes, so the hardest feature could be shown on demand and filmed |
| 6 | Harden | Refresh and delay detection, offline states, CI, a 20-drop accuracy audit, ten skill reviews |
| 7 | Ship | README for a 60-second reader, demo video, case study, open-source checklist, `v0.1.0` tag, repo public |
| After | Chime's feedback | Each request: logged as a decision, built, tested, reviewed, committed, pushed, installed |

For Tactics Board, map the same skeleton onto its own core (the model, engine and file format first, tests first),
then the design phase, then the screens, then the export pipeline.

---

## 7. Working with agents

- **Parallel agents only when the work splits into lanes that touch different files.** Tell each agent: don't
  commit, push, install or edit the shared docs. Afterwards, check their screenshots yourself, run the review, write
  the docs, then commit and push.
- **One simulator job at a time.** Two test runs at once crash (`Mach -308`) or fail unrelated tests. Shut the
  simulator down when done; the Mac is tight on memory, so stop dev servers and recordings and never close Chime's apps.
- **Don't pass `-quiet` to a narrow test run:** it hides which test failed. Grep for `✘` and `Test run with` instead.
- **Speed over ceremony for small things:** copy and config edits are done directly with a narrow test; batch small
  fixes into one review, one screenshot round and one install.
- **Skill reviews:** one skill per fresh session, a shared preamble pasted first ("decisions win over the skill's
  advice; findings first, edits after Chime's picks"), then two passes: findings ranked by impact, Chime picks,
  then apply only the picks (Meridian's prompts are in its `docs/SKILL-PROMPTS.md`).

---

## 8. How Chime wants to work

- **Show, don't describe.** Chime judges from screenshots and the phone. Explain in plain words, not code.
- **Confirm understanding** when asked: restate, ask the real questions, then start.
- **Install on the iPhone after every app change.** Never launch it or screenshot the phone without a fresh go-ahead.
- **Push to GitHub after every commit.**
- **Write every instruction down the same turn** (DECISIONS.md, or Open if it's deferred), quoting Chime's words. If
  a request is deferred, say so plainly and put it in PLAN.md with its day.
- **Check definitions need Chime's OK:** `.claude/proof.json`, anything in `fidelity/`, `.claude/settings.json`.
- **Fewer approval prompts:** plain commands, no `cd … &&` prefixes. Chime often walks away mid-task.
- **$0, no new dependencies** without Chime's OK.
- Chime is they/them.

---

## 9. Lessons: what went wrong and the rule it left

| What happened on Meridian | The rule now |
| --- | --- |
| Status dots needed explaining ("I had to ask you to understand it. Obviously, users won't") | Say it in words; no legends or colour codes |
| TVmaze's airstamp for a show without a time was a fake noon in the channel's country | Read the raw data before trusting a field; detect placeholders by the documented signal, never by guessing |
| An island layout looked right in renders but was blank on the phone | Confirm every system-surface layout change on the device |
| Two simulator test runs at once crashed, and a parallel agent's run failed an unrelated widget test | One simulator job at a time; run the gate alone |
| `-quiet` hid which test failed | No `-quiet` on narrow runs |
| A 3× sped-up countdown in the demo video "looks broken" in an app about trustworthy time | Film the real thing at real speed |
| The phone's screen recording took over the Dynamic Island | Record with QuickTime on the Mac over a cable |
| The design reference library was named in commits and had to be scrubbed from history | Never name it in anything public; say "I designed" |
| TVmaze's popularity score couldn't rank the top shows (several at 100), and Netflix's Top 10 is off-limits by its terms | Check that a data source really measures what you need before building on it; prefer public, keyless, permitted sources |
| Several instructions Chime gave were lost when a long session was summarised, and a request deferred to "after Day 7" felt forgotten | Write every instruction into DECISIONS.md the same turn; a deferral is said out loud and planned |
| A worker agent and the main session edited the same files at once | One writer per file; pause and coordinate before continuing |
| A free CI plan covers few macOS minutes on a private repo (we push after every commit) | CI run by hand (`workflow_dispatch`) while private; every push and PR once public |
| Free signing expires after 7 days | Note the expiry on every install; reinstall before it lapses |

---

## 10. Per-session checklist (copy into the session)

```
[ ] Read CLAUDE.md, docs/HANDOFF.md, today's day in docs/PLAN.md, the last PROGRESS.md entry
[ ] Restate the ask; write new instructions into docs/DECISIONS.md now
[ ] Split into units; for each unit:
    [ ] take specifics from the source (spec, brief, API docs, recorded fixture)
    [ ] tests first for the core; red, then green; narrowest run while fixing
    [ ] mutation run for a new rule
    [ ] UI: build, screenshot, fidelity/verify-screen.sh <screen> → ALL PASS
    [ ] /code-review medium --fix (high if risky)
    [ ] proof:verifier against Chime's exact words
    [ ] full gate alone (build, test, spec)
    [ ] tick PLAN.md, features.json (with evidence), PROGRESS.md entry
    [ ] commit (own command) → push → install on the iPhone (no launch, no screenshot)
[ ] Tell Chime: changed / checked (numbers) / not checked / needs a decision
[ ] Rewrite docs/HANDOFF.md; shut the simulator down
```
