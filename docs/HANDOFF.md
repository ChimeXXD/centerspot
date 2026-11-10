# Handoff: read this first when you pick the project back up

## Latest: Day 7 done: public repo, README, case study live, CenterSpot on chimexd.work (Tue 10 Nov 2026, Lagos)

### Where it stands
- **Repo public** (D-100): https://github.com/ChimeXXD/centerspot, CI green (Xcode 26.6, iPhone 17 Pro simulator), README after Meridian's and Clepso's with screens and GIFs (`docs/readme/`). 31 of 35 features pass; open: links and QR (D0-4, D6-2, after the week), VoiceOver on the iPad (D6-4), and D6-3 waits on Chime's look at the AX5 shots.
- **Case study live:** https://chimexd.work/work/centerspot (portfolio repo `content/work/centerspot.mdx`, its own "Life of a move" map; copy still drafted, Chime to put Role and "How it was checked" in their own words). CenterSpot is third on the home page after Meridian and Clepso; Perpetual Trading moved to /work. Cover, icon and previews from the CenterSpot page in the Figma file "Portfolio Elements" (option A, the design system's first colourway).
- **Design system:** https://centerspot-design-system.vercel.app redeploys on every push (Root Directory `design-system`). It now shows D-99's Include the move switch.
- **App since the last handoff:** D-98 player tag (name, else CDM/LB/ST…), D-99 scenarios set up the starting position unless Include the move is on. Installed on both devices on 9 Nov; signing runs out about **16 Nov**: reinstall before then.
- **Media:** Chime's recordings live in `videos/` (git-ignored; originals show private chats). Edited copies "01 … 05" sit beside them; the case study uses 720-wide encodes.
- **Portfolio housekeeping:** the GitHub/X/PSN data refresh is in `git stash` on the portfolio repo (`stash@{0}`); builds rewrite those files and `docs/HANDOFF.md` there says to commit them separately or leave them out.

### Next
1. Chime: the case study's copy in their own words; VoiceOver on the iPad; the AX5 screenshots; reinstall before 16 Nov.
2. **The v0.1.0 release is not published.** Claude Code's permission check blocked `gh release create` (a public surface). Notes and the four 9:16 exports were staged in the session scratchpad (gone after the session); to redo: export the clips again (the hero flat and Broadcast, Counter-attack attacking, Build-up v press defending, titled "Win it back high", through `VideoExporter`), then Chime runs `gh release create v0.1.0 --target main --prerelease …` or allows it.
3. After the week (if it continues): link and QR sharing (D-36), the iPad's three-column view.

### This session, in order (9–10 Nov 2026)
The conversation behind the section above, so the next session doesn't have to re-derive it.

1. **Device checklist.** Claude sent a 16-item checklist (iPhone and iPad: playback and Reduce Motion, players, steps, runs and Straight/Curved, Broadcast and its export, marks, Files and AirDrop, library, tips, VoiceOver, iPad layout, Pencil, scenarios, then the player tag). Chime: "the system is working fine", then confirmed all 16 passed. 12 features were ticked with that evidence (1742a6e).
2. **Player tag (D-98).** Chime: tap a player and show its name, else its position ("number six… CDM… don't remove the role"). Picked: the tapped player only, standard positions (holding mid and deep playmaker → CDM, full-backs LB/RB from where they stand, shadow striker and false nine → CF…), screen only. Code review fixed the tag's placement for large text and the touchlines (abacb5a).
3. **"I can't see the changes."** A commit doesn't reach the devices. Claude now builds for `generic/platform=iOS` and installs with `xcrun devicectl device install app` on both (iPhone 14 Pro `00008120-001044862EC0201E`, iPad `00008132-001E11443ED9801C`) after every app change.
4. **README and repo case study drafts** (922bc57), then the portfolio case study. Claude read Meridian's page (`content/work/meridian.mdx`) as the model. Picked: films = app exports plus device clips; decisions = Broadcast, scenarios, Pencil and iPad, one renderer and the file; Claude drafts, Chime edits.
5. **"Don't copy Meridian's map."** Chime: "My workflow shouldn't be identical for every project." Picked "Life of a move": The gap, Draw it, Play it, Start from a scenario, Post it, Send it, How it was checked; key numbers as one line under the intro (a new optional `meta.facts`). Later Chime dropped the Next section and asked for the GitHub link beside the design system's.
6. **Scenarios start empty (D-99).** Chime: a scenario forced its ready-made steps on you; "the default state should be empty", with a toggle for the motion. Built: Include the move above Use, off and remembered; off sets up the starting position, and the tile shows it still (f946aaa). Code review: the move was built twice (fixed), a comment was wrong (fixed); Claude reverted the reviewer's "no move on unpicked tiles", which would have made tiles jump.
7. **Chime's recordings.** Five files in `videos/` (two iPhone, two iPad, one camera film of the Pencil). Chime wanted them shorter without losing anything: idle stretches over 1.4 s were cut to about 1 s, then 1.5x, sound off. The WhatsApp one had the share sheet (contacts' faces), the WhatsApp "Send to" list and the Face ID unlock cut out (14.55–27.0 s). The first idle detection cut real taps on the iPad (a small tag change looked still), so it was rerun more sensitively and every frame checked. Edited copies are named "01 iPhone - draw runs, then play in Broadcast" … "05 iPad camera - drawing with the Apple Pencil". `videos/` is git-ignored. Chime approved all five, and they're on the case study.
8. **Published.** Chime approved; the portfolio branch `centerspot-case-study` was fast-forwarded onto `main`, which deploys to Cloudflare Pages (bd5df8c).
9. **Figma cover.** On the file "Portfolio Elements" (`mageMpQwkjfpW2jBY66fNl`), page CenterSpot: Meridian's card, hover and list frames copied with CenterSpot's screens, plus three cover options. Chime chose the design system's first colourway (#F2F5F7 lockup on #0B0F14, lime spot) and asked that nothing be Meridian's near-black; every slot, tile and border was recoloured to ink, surface and hairline.
10. **Repo public (D-100).** A scan found no secrets; the only personal mention is "Chime's brother's iPad" (unnamed, left as is). Pushed, made public, given a description, topics and the case study as homepage. CI's fixed simulator didn't exist on the runner, so it now picks or makes one, and runs on pull requests: green.
11. **README.** Chime: "look at Clepso and Meridian… I can't see any of the CenterSpot logo… the screens." Rewritten after Meridian's (mark, badges, link row, hero GIF of the app's export, a section per feature with screens, mermaid diagram, numbers, design system shot, get started, quality gates, map, docs, privacy, status) with Clepso's Known limitations.
12. **Design system 404, fixed.** The Vercel project is linked to the repo; pushes deployed the repo root. Root Directory is now `design-system` (set through the Vercel API with the CLI's login), so pushes redeploy it correctly.
13. **Home page.** Chime: Meridian, Clepso, CenterSpot, then See more; full order Meridian, Clepso, CenterSpot, Perps Trading, Bulan, 101 before one, GlamByPrime, Gui Inu, Aptos Monkeys. Added a `centerspot` tone, the Figma logo and icon (text outlined), hover and list previews; the site's tests now expect that order. Previewed locally, then pushed on Chime's yes (bd9a5a5).
14. **Wrap-up.** Features, plan, decisions, build log, and this file; the design system shows the switch (f5f500b).

### Chime's preferences learned this session
- Install every app change on both devices; say it's installed and to relaunch.
- Show a local preview (`PORT=4319 node scripts/serve-out.mjs` in the portfolio, after `npx next build`) and wait for a yes before pushing anything live.
- Each project's case study gets its own structure; don't reuse another's map.
- Use the design system's colours (first colourway: chalk on ink), never a near-black from another project.
- Shorten recordings without losing taps; cut private screens (contacts, chats, unlocks) rather than show them.
- Commits run the proof gate's full tests: don't run simulator tests in the background at the same time (they collide), and keep memory free (Chime closes Brave, Figma, Dia when asked).
- In the portfolio, `npx next build` (or `npm run build`) rewrites `content/*.json` and a PSN image: restore them before committing.

## Before: four device fixes and scenarios on the Formation sheet (Mon 9 Nov 2026, afternoon Lagos). Next: Chime tries scenarios and the fixes on the devices.

### Where it stands
- **Fixes (D-90 to D-93), commit `08af64b`, installed on both devices:** the Pencil only draws in draw mode; Broadcast shows touchline to touchline (mostly a steady wide shot now; no dark above the far goal); iPad landscape Play lists the steps; players stack cleanly (a number shows whole or not at all, selected and dragged players on top).
- **Scenarios (D-94):** the Formation sheet's Scenarios tab, 24 / 18 / 13 situations by size, Attacking / Defending. The rules live in `mockup/scenarios.js`; the Swift port (`ScenarioBuilder`) must match `CenterSpotTests/Fixtures/scenarios.json` (regenerate with `node mockup/gen_scenario_fixtures.js` after changing a rule, and say so).
- **Design check:** Playwright 1.64.1 matches the cached Chromium (1248). Install it in a scratch folder and run `check-design.mjs` from there; the iPad frame is its own page (`scenarios-ipad.html`, `--viewport 1376x1032`).
- **Open for Chime:** the example's 9 is hidden behind 5 at step 4 now that covered numbers hide (offer to nudge 9 in `examples/overlap-left.tactic`); the board's chip shows "6 players", not the scenario's name; the Pencil on the real iPad.
- **Chime's rules this session:** check every change on both the iPhone and the iPad; when Chime has explained a feature, don't push a reference board, design from the explanation plus football knowledge.

## Before: renamed to CenterSpot, app icon, design system (Mon 9 Nov 2026, early Lagos). Next: Chime on the devices, the iPad check, then Day 7.

### Where it stands
- **App: CenterSpot** (D-85): bundle ID `dev.chime.centerspot`, UTType `dev.chime.centerspot.tactic`, links `centerspot://`, repo `ChimeXXD/centerspot` (private), folder `CenterSpot`. Every old-name mention was replaced, history included (Chime's choice). Last commit `c2d2f69`.
- **Devices:** iPhone 14 Pro and Chime's iPad have CenterSpot with its icon (D-86); the old app is uninstalled and its tactics were copied across. Signing for the new ID was made 9 Nov, so it expires about **16 Nov**; reinstall before then.
- **Design system** (D-87): `design-system/index.html`, rebuilt by `python3 design-system/src/build.py`. Unslopped; never coloured side-stripe cards (Chime's global rule). Not hosted yet: Chime's others are on Vercel, so ask before deploying.
- **Open for Chime:** wordmark weight in the app (800) vs the logo (900); keep or drop the heavier small mark for 16–20 px; swap the app's SF Symbols for the custom icons (on hold); how they run the app on the Mac; the App Store name check (Apple's search was rate-limited on 9 Nov).
- **Lesson:** a background agent stuck on a rate-limited API burned an hour while nothing else moved. Give agents a time box, check them within 10 minutes, and keep building in parallel.

## Before: broadcast camera, onboarding and the unslop pass (Sun 8 Nov 2026, evening Lagos)

### Where it stands
- **App: CenterSpot** (D-42), private repo `ChimeXXD/centerspot`. Last code commit `61e71d1`.
- **CI is paused until the repo is public (D-77):** November's free Actions minutes are used up; GitHub refuses jobs and charges nothing. Don't treat a billing-blocked run as red. On Day 7, once public, check the first run (Xcode 26.6) and fix what it finds.
- **Chime's order (8 Nov):** broadcast camera → onboarding → **fix everything** → iPad check (Chime's brother lends the iPad again) → Day 7.
- **Built today (8 Nov, afternoon and evening):**
  - Broadcast camera (BR-2, D-76): `CameraTrack` (Engine), `BroadcastCamera` (Render, the mockup's CSS camera as maths), `Options.broadcast` in `BoardRenderer`; the Flat | Broadcast switch in playback (remembered, Broadcast by default), Reduce Motion's still view fitted to the whole move; the Camera row in Export (videos only, images flat). Timed on the iPhone 14 Pro: hero 9:16 2.37 s / 2.56 MB, ten steps 9:16 4.67 s / 5.83 MB of 8.37 MB (PROGRESS has every format).
  - Onboarding (D-58, D-78): three welcome pages (Broadcast on 2 and 3), five TipKit tips on the board, Show tips again in the library's More menu. Mockup tag `design-v3`.
  - Unslop, polish mode (D-80): one lime lead per screen; heavy type only for the wordmark and shirt numbers; welcome titles without periods.
- **Checks at `61e71d1`:** gate 3/3. CenterSpotUITests: every test passed across today's runs (17 + Onboarding on iPhone 18 Pro; iPad layout + camera on the iPad Pro 13-inch simulator). Verifier and code review ran on the camera and on the onboarding; their fixes are in.
- **Device:** iPhone 14 Pro has `61e71d1`'s build (installed over Wi-Fi). Signing expires **13 Nov 2026, 21:30 Lagos**: reinstall before then. Bench: launch with `xcrun devicectl device process launch --console --terminate-existing --device 00008120-001044862EC0201E dev.chime.centerspot -- -exportBench` (keep the phone awake; it reports both cameras).

### Waiting on Chime
1. How the Broadcast camera feels in Play on the phone (drift on passes?). BR-2 stays `passes: false` until then (rule 9).
2. The onboarding on the phone: delete the app or use More › Show tips again.
3. The unslop: D-80 (lime, weights, periods; applied while Chime was away) and D-81 (screen-by-screen: 4 pt spacing, one icon rule, token corners, dimmed empty board, centred welcome; Chime picked these). Chime to look on the phone; the empty board's halfway line still runs between the prompt's words and button at 40%.
4. Older: the iPad questions from 8 Nov morning (Straight/Curved and the bend dot feel, dot above or below players, Remove moving the player back, finger drawing zones on iPad, ⌘Z), AX5 screenshots, Day 3/4 approvals.

### Fix everything (done 8 Nov night, D-83; see PROGRESS)
- Left for the iPad check: Pencil + finger together on the bend dot (needs the real Pencil); sharing from the board to AirDrop/WhatsApp on the devices.
- Draw panel "Shape" label is a one-off 13 pt size.

### Working rules learned this session
- **iPadOS 26 hardware builds lazy view content off the main thread** (`com.apple.SwiftUI.AsyncRenderer`, under `ViewThatFits`/`ScrollView` measuring). A `ForEach` closure that touches main-actor state there crashes the app (runtime isolation check). Make such closures `@Sendable` and build views with `nonisolated` inits from plain values. The simulators (26.5, 27) don't reproduce it; test on the device, and run UI tests with tips on too.
- **Never let two test runs share a simulator.** The gate runs at every turn end; a background UI suite on the same simulator made it fail (signal kill, fuzz timeouts). Wait for UI runs to finish (Monitor/until-loop) before ending a turn, and tell review agents not to run xcodebuild.
- **The commit gate refuses a command that edits files and commits in one go.** Edit in one step, `git add … && git commit …` in the next.
- **TipKit's popover modifier breaks `ImageRenderer`** (parity test) and steals taps: attach it only when a tip is due (`centerSpotTip`).
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
- Swapping the app's SF Symbols for the custom icon set (drawn in `design-system/`, D-87), until Chime says go.
