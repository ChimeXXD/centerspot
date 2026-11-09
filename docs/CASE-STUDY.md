<!-- clip: demo video goes here -->

# CenterSpot: draw the move, not just the shape

CenterSpot is a native SwiftUI app for iPhone and iPad. You build a football move as steps on a phone, play it, and export it as a 9:16 video, an image or an open `.tactic` file.

**Role.** Chime Ekpendu (they/them) directed the product and the design. They set the audience, picked the visual direction, approved each mockup before it was built and made the product calls; the [decisions log](DECISIONS.md) has 98 entries. The code was written by Claude Code under a proof-gated workflow: nothing commits until an iOS 26 iPad build, the full unit test suite and a repo check all pass.

**Timeframe.** Built from 6 to 9 Nov 2026, and still going, as a portfolio piece. It is a private beta on Chime's iPhone and a borrowed iPad, with no App Store release ([D-01](DECISIONS.md)).

## The problem and who it's for

People who explain football tactics can show a shape, but not a move. They share screenshots, text codes and Canva templates. The [PRD](PRD.md) found the demand:

- FM Scout's FM26 tactics index lists about 147 shared tactics; the top one has 141,968 downloads ([FM Scout](https://www.fmscout.com/f-fm26-tactics-index.html)).
- r/footballmanagergames has about 545,000 members, up 8.4% in a year ([GummySearch](https://gummysearch.com/r/footballmanagergames/)).
- Canva lists 15,275 football templates, so people dress up lineups by hand ([Canva](https://www.canva.com/templates/s/football/)).

The existing apps aim at paid club staff or stop at static images:

| App | Price | Gap |
| --- | --- | --- |
| [TacticalPad](https://apps.apple.com/app/id946927077) | $39.99 a year | No 9:16 export preset |
| [Tactics Manager](https://www.soccertutor.com/tacticsmanager/) | £79.99 Pro | MP4 export capped at 1 animation free, 5 on Pro |
| [Tacticsboard](https://www.softwareadvice.com/product/546220-Tacticsboard/) | From €14.99 a month | Web only; animation behind club plans |
| [easy2coach](https://www.easy2coach.net/en/tactics/) | Free to start | Images and PDF only, no video |

No app in the research did keyframe steps, a one-tap 9:16 MP4, Pencil-drawn runs and an open file format together ([D-02](DECISIONS.md)).

**Who it's for.** Gamers and creators first, with EA FC Clubs squads as the core case: a captain shows the human teammates the move, and each of them plays one position ([D-37](DECISIONS.md)). Grassroots coaches come second. Chime is in Lagos, where small files on mobile data matter, so the target is under 8 MB for 15 seconds ([D-11](DECISIONS.md)).

## What it does

1. **Pick a shape** from 26 formations across 11-, 7- and 5-a-side ([D-63](DECISIONS.md)).
2. **Build steps.** Drag players, add a step, drag again. The app eases between steps.
3. **Draw what happens.** A run moves the player, a pass moves the ball, a dribble moves both ([D-59](DECISIONS.md)). Lines are Straight or Curved ([D-72](DECISIONS.md)). On iPad, the Apple Pencil draws.
4. **Play it**, flat or through the tilted **Broadcast** camera that follows the ball ([D-76](DECISIONS.md)).
5. **Export** an MP4 at 9:16, 1:1 or 16:9, a PNG of a step, or a lineup card. The file size shows before you share.

Also built:

- **Scenarios:** 24 ready-made moves on 11-a-side, 18 on 7-a-side and 13 on 5-a-side, on any shape. Attacking moves end in a goal; defending moves end with the ball won ([D-96](DECISIONS.md), [D-97](DECISIONS.md)).
- **The `.tactic` format:** versioned JSON with a public [spec](FORMAT.md). Bad files are refused or repaired by written rules.
- **A library** that loops your last move above your cards ([D-89](DECISIONS.md)), and **onboarding** with tips that wait for you to act ([D-78](DECISIONS.md)).
- **Accessibility:** each player reads as "Number 9, striker, edge of the box, step 4 of 5" in VoiceOver. Reduce Motion swaps tweening for crossfades. Screens were checked at the largest text size. Sides differ by shape, not only colour ([D-15](DECISIONS.md)).

## Key decisions and trade-offs

**One renderer for the screen and every export ([D-07](DECISIONS.md)).** The PRD planned SwiftUI `Canvas` on screen and a separate path for video, which invites "it looks different in the video" bugs. Instead, one `BoardRenderer` draws with Core Graphics for both. A parity test holds them together: 99.5% of pixels within 16/255, and no pixel more than 64/255 off ([D-60](DECISIONS.md), [D-61](DECISIONS.md)). The second rule was added because the first missed a player drawn 2 px off.

**A library instead of DocumentGroup ([D-56](DECISIONS.md)).** The system document browser gave Files integration for free ([D-09](DECISIONS.md)). On the phone it showed a raw JSON thumbnail and "632 bytes", and Chime asked for an app, not a file manager. CenterSpot now draws its own library. Tactics stay `.tactic` files in the app's Documents folder. The cost is automatic iCloud Drive sync, which a one-phone beta doesn't need.

**The Broadcast camera is maths, not a 3D engine ([D-65](DECISIONS.md), [D-76](DECISIONS.md), [D-95](DECISIONS.md)).** SceneKit or RealityKit would have meant a second renderer and broken parity. The camera is a perspective projection inside `BoardRenderer`, ported from the approved mockup's CSS. Its path is a pure function of the tactic, so playback, scrubbing and export frame the same view at the same moment.

**The Pencil draws only in Draw mode ([D-90](DECISIONS.md)).** The first rule was that the Pencil always draws on iPad. On Chime's iPad it drew a line on every touch and couldn't move a player. Now it acts like a finger until you pick Draw.

**Clean stacking, with covered numbers clipped ([D-93](DECISIONS.md)).** The old rule drew every number above every disc ([D-67](DECISIONS.md)). On the device that looked glitched: one player's number sat on another's disc. Now each player is drawn whole, back to front, like one coin on another, and the number underneath shows where it isn't covered.

**Scenarios with the JavaScript mockup as the spec ([D-94](DECISIONS.md), [D-96](DECISIONS.md)).** Moves come from rules, not hand-placed boards. The side on the ball follows a short role-based script; the other side reacts by rule, and a beaten defender stays beaten. The rules were written first in [`scenario-motion.js`](../mockup/scenario-motion.js), playable in a browser. Fixtures are generated from it, and the Swift port must match 158 fixture moves. A fresh-context check compared all 1,112 shape, scenario and side combinations with the spec: 0 differences.

**Links and QR deferred ([D-36](DECISIONS.md)).** The format already defines links ([D-25](DECISIONS.md)). But Chime wanted to share tactics visually, so video and image became the headline and the `.tactic` file the editable extra. That freed time for export and hardening.

## How it was built

**The mockup is the spec.** Chime approved HTML mockups from screenshots before a screen was built. The Swift design tokens are generated from the mockup's CSS. For scenarios, the mockup's JavaScript generates the fixtures the Swift tests check.

**The proof gate.** A commit that touches the app has to pass three checks ([D-32](DECISIONS.md), [D-52](DECISIONS.md)):

- `build-ios26`: the app builds for an iPad simulator on iOS 26.5, the version on the borrowed iPad.
- `test`: the full unit test suite.
- `no-library-name`: no tracked file names the design reference library.

**Around the gate.** Most units were written tests first, red against stubs, then green. Many were mutation-tested: break a rule on a scratch copy and check a test fails. A code review ran on most changes, with fixes applied; styling-only passes skipped it. A fresh-context verifier checked each unit against its acceptance criteria. UI tests run on iPhone and iPad simulators, and Chime's rule is that every change is checked on both devices.

**Size on 9 Nov:** 67 commits; about 13,300 lines of Swift in the app and about 9,400 in tests; 482 `@Test` unit tests and 21 UI tests.

## Honest numbers

Export on Chime's iPhone 14 Pro, from the `-exportBench` run on 8 Nov ([PROGRESS.md](../PROGRESS.md)). It is a Debug build; Release wasn't measured. The budget is the encoder's ceiling: 8 MB per 15 seconds at 1080×1920, scaled by pixel count.

| Move | Format | Flat | Broadcast | Budget |
| --- | --- | --- | --- | --- |
| Hero, 8 s | 9:16 | 1.68 s, 1.33 MB | 2.37 s, 2.56 MB | 4.27 MB |
| Hero, 8 s | 1:1 | 0.85 s, 0.69 MB | 1.52 s, 1.59 MB | 2.40 MB |
| Hero, 8 s | 16:9 | 1.35 s, 0.83 MB | 2.23 s, 2.52 MB | 4.27 MB |
| Ten steps, 15.7 s | 9:16 | 2.98 s, 2.75 MB | 4.67 s, 5.83 MB | 8.37 MB |
| Ten steps, 15.7 s | 1:1 | 1.64 s, 1.40 MB | 2.96 s, 3.55 MB | 4.71 MB |
| Ten steps, 15.7 s | 16:9 | 2.60 s, 1.70 MB | 4.36 s, 5.85 MB | 8.37 MB |

Broadcast takes about 1.5 times as long and makes files about twice the size, because a moving camera compresses less. Every clip is inside its budget. The PRD set its time target on an iPhone 13; only the 14 Pro has been measured.

## What went wrong and what changed

- **Claude chose references that Chime should have chosen ([D-47](DECISIONS.md)).** It ranked a "top five" and designed 15 screens without a pick round. Chime reset it: every reference goes on a pick board and Chime picks. In the end Chime kept the mockup ([D-50](DECISIONS.md)).
- **The system document browser was replaced ([D-56](DECISIONS.md)),** after Chime saw it on the phone.
- **Covered numbers were hidden, then clipped ([D-93](DECISIONS.md)).** The first stacking fix hid any number a disc cut into. Chime: "Don't make the number disappear."
- **The Broadcast lens changed three times ([D-91](DECISIONS.md), [D-95](DECISIONS.md)).** The first left a quarter of the view empty. A steady wide shot fixed that, but Chime wanted a closer view bent toward the player on the ball. The current lens was picked from renders on both devices.
- **Defending scenarios first ended in a goal ([D-97](DECISIONS.md)).** Chime: "the defending scenarios should lead to a successful defense… the defender gets the ball… not the keeper saves it." Now our nearest outfield player wins the ball; the keeper does it only at a penalty and in a 1v1.
- **Two crashes only the devices showed.** Save to Photos quit the app because of Swift 6's runtime isolation check. On the iPad, opening a tactic crashed because iPadOS built list rows off the main thread; the simulators never reproduced it. Both are fixed.
- **Parallel agents collided on one simulator ([L-4](DECISIONS.md)).** It was a lesson from an earlier project, and it happened again: gate runs failed while another test run shared the simulator, then passed alone. The rule now is one test run per simulator.
- **CI was paused ([D-77](DECISIONS.md)).** The private repo used all 2,000 free GitHub Actions minutes for November in about 37 runs, because macOS minutes count ten times. CI comes back when the repo goes public.
- **The size estimate was about 4× too high ([D-64](DECISIONS.md)).** It said "About 4 MB" for a 1.1 MB clip. It now says "Up to …".

## What's next

- **Links and QR codes** ([D-36](DECISIONS.md)), from the criteria already in [SPEC.md](SPEC.md) and [FORMAT.md](FORMAT.md).
- **The iPad three-column split view** (library, board, inspector), moved to after Day 7 ([D-35](DECISIONS.md)).
- **Day 7** ([PLAN.md](PLAN.md)): make the repo public, turn CI back on and fix what it finds, write the README, make a 9:16 demo in the app, and film the Pencil on the iPad.

## Status

The app runs on Chime's iPhone 14 Pro and a borrowed iPad Pro. The logs show these confirmed on the devices: the exported clip plays in WhatsApp and Discord; a `.tactic` AirDropped from the iPhone opens on the iPad; after the crash fix the iPad opened a board and stayed up; and the export timings above.

On 9 Nov Chime ran a 16-item checklist on both devices and every item passed: playback and Reduce Motion, editing players and steps, drawing runs with Straight and Curved arrows, Broadcast and its export, zones, lines and glows, saving and opening `.tactic` files through Files and AirDrop, the library, the tips, VoiceOver on the iPhone, the iPad layout, the Pencil only drawing in Draw mode, scenarios, and the player tag ([D-98](DECISIONS.md)). 29 of the 35 features in [`features.json`](features.json) pass; the rest are links and QR (after Day 7), CI (when the repo is public), VoiceOver on the iPad, and the Day 7 items.
