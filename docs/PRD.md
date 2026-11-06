> Original PRD, written 25 Oct 2026 (timelines updated the same day). Decisions in `docs/DECISIONS.md` supersede anything here that disagrees: notably the portfolio frame (D-01), no App Store (D-01), iOS 26 minimum (D-03) and one renderer (D-07).

# Tactics Board

Tactics Board is a native iPhone and iPad app that turns a formation into a step-by-step animated move and exports it as a vertical video, an image or an importable link. It is worth building because no app we found does Pencil drawing, animation, 9:16 video and tactic sharing together for under $40 a year.

## Summary

Coaches, FM and EA FC players and football creators all share tactics, but they do it with screenshots, text codes and Canva templates. Existing board apps either target paid club staff (TacticalPad at $39.99 a year, Tactics Manager at £79.99) or stop at static lineups (Lineup11, Soccer Line Up Builder 11). Tactics Board aims at the gap: fast drawing, keyframe animation, one-tap 9:16 export, and a small open JSON format that travels as a link or QR code. It is local-first, built in SwiftUI with PencilKit, and ships open source on GitHub as Chime's portfolio piece. Money comes later from a one-time Pro unlock, not a subscription.

## Problem and audience

People who think about football tactics have no quick way to show a move, not just a shape. They share static screenshots, text codes or files that only one game can read.

- **Football Manager players.** FM26 launched with separate in-possession and out-of-possession formations and roles ([GamingBolt](https://gamingbolt.com/football-manager-26-gets-new-trailer-showcasing-new-possession-tactics-and-formations)). A two-state tactic is hard to explain in one screenshot. They share it on forums and Reddit, then argue in text about what the shape does.
- **EA Sports FC players.** Ultimate Team players swap tactic codes that hold formation, build-up style, line height and every player role ([FUT.GG](https://www.fut.gg/tactics/codes/)). A code imports the settings, but it does not show why the shape works.
- **Sunday-league and five-a-side coaches.** They plan in the hour before kick-off, on a phone, and post the lineup in a WhatsApp group. Most board apps are built for club staff on laptops.
- **Football creators on TikTok, Reels and X.** They need a 9:16 clip of a run or a press in under a minute. Today they screen-record a board app or edit in a video tool.

**When it hurts:** the night before a match, at half-time, after a game for a breakdown post, and during an FM save when a tactic finally clicks.

**Evidence of demand:** FM Scout's FM26 tactics index lists about 147 shared tactics, the top one downloaded 141,968 times ([FM Scout](https://www.fmscout.com/f-fm26-tactics-index.html)). r/footballmanagergames has about 545,000 members, up 42,000 in a year ([GummySearch](https://gummysearch.com/r/footballmanagergames/)). Canva lists 15,275 football templates, a sign that people dress up lineups by hand ([Canva](https://www.canva.com/templates/s/football/)).

## Research findings

- FM Scout's FM26 tactics index shows about 147 tactics; the top two have 141,968 and 65,590 downloads. The site showed 3,200 users online ([FM Scout](https://www.fmscout.com/f-fm26-tactics-index.html)).
- r/footballmanagergames has about 545k members and grew 8.4% in a year. "Tactic" is the third most common post topic ([GummySearch](https://gummysearch.com/r/footballmanagergames/), data as of 13 October 2026).
- FM26 split tactics into in-possession and out-of-possession screens. Moving a player in possession no longer changes his defensive job ([GamingBolt](https://gamingbolt.com/football-manager-26-gets-new-trailer-showcasing-new-possession-tactics-and-formations)). A board with two linked states fits this model directly.
- FUT.GG lists 46 distinct EA FC tactic codes, already for EA FC 27. The most used community formation, 4-2-1-3, appears in 26% of tracked squads ([FUT.GG](https://www.fut.gg/tactics/codes/)). Gamers already trade tactics as short codes.
- TacticalPad charges $39.99 a year and exports images and videos in 4:3, 16:9 and 16:10. It lists no 9:16 preset ([App Store](https://apps.apple.com/app/id946927077)).
- Tactics Manager by SoccerTutor exports MP4 animations but caps them: 1 on Free and 5 on the £79.99 Pro plan. Unlimited needs the Premier add-on ([SoccerTutor](https://www.soccertutor.com/tacticsmanager/)).
- Tacticsboard runs in the browser from €14.99 a month. Animation and GIF export sit behind paid club plans ([Software Advice](https://www.softwareadvice.com/product/546220-Tacticsboard/)).
- Lineup builders sell badge and kit packs. Lineup11 sells league packs for $0.99 to $3.99 and has 98 ratings ([App Store](https://apps.apple.com/app/id860716153)). Soccer Line Up Builder 11 sells a $34.99 lifetime plan and was updated on 7 October ([App Store](https://apps.apple.com/us/app/-/id6737229261)).
- 2025-2026 newcomers are small. Tactics Board - Soccer has 11 ratings and charges $19.99 a year ([App Store](https://apps.apple.com/app/id6743544146)). Strike Lite has too few ratings to show ([App Store](https://apps.apple.com/app/id6745530915)).
- PencilKit gives low-latency Pencil and finger capture and stores strokes as a `PKDrawing` that can be saved with app data ([Apple](https://developer.apple.com/documentation/pencilkit.md)).
- SwiftUI `Canvas` offers immediate-mode drawing, and `TimelineView` redraws it on a schedule, from iOS 15 ([Kodeco](https://www.kodeco.com/27594491-using-timelineview-and-canvas-in-swiftui?page=1)).
- Video export from frames needs `AVAssetWriter`, an input and a pixel buffer adaptor, with frame times set per frame ([IMG.LY](https://img.ly/blog/how-to-make-videos-from-still-images-with-avfoundation-and-swift)). `ImageRenderer` cannot render UIKit-backed views and shows a placeholder ([Create with Swift](https://createwithswift.com/exporting-swiftui-views-to-images-with-imagerender)).

## Competitors

### Hard competitors

| Product | What it does | Price | Strengths | Gaps |
| --- | --- | --- | --- | --- |
| [TacticalPad](https://apps.apple.com/app/id946927077) | Multi-sport coach whiteboard with 3D, digital ink, rosters, playbooks and animated plays | Free; $39.99/year subscription | Mature; image and video export; YouTube/Vimeo links | No 9:16 export preset; subscription; built for club coaches, not gamers or creators |
| [Tactics Manager (SoccerTutor)](https://www.soccertutor.com/tacticsmanager/) | Session and drill planner with frame-by-frame animation | Free; Pro £79.99 one-time; Premier £114.94/year | MP4 export; 310+ ready drills on Premier; runs on PC, Mac and iPad | 1 animation free, 5 on Pro; drill focus, not match tactics; heavy for phones |
| [Tacticsboard](https://www.softwareadvice.com/product/546220-Tacticsboard/) | Browser tool for club drill and session planning | Free tier; club plans €14.99 to €79.99/month | Shared club library; branding; GIF and PDF export | Web only; animation is paid; no video file; priced for clubs |
| [easy2coach Tactics](https://www.easy2coach.net/en/tactics/) | Step-by-step tactic animation on iOS, Android and web | Free to start | Multi-step animation; shares to WhatsApp, email and SMS | Exports PNG, PDF and JPEG only, no video; needs an account |
| [Lineup11](https://apps.apple.com/app/id860716153) | Lineup graphic builder with kits | Free; packs $0.99 to $3.99 | Quick social sharing; 98 ratings at 4.0 | iPhone only; static; sells kit packs that lean on club looks |
| [Soccer Line Up Builder 11](https://apps.apple.com/us/app/-/id6737229261) | Lineups, teams, stats and drawn movements | Free; Pro $2.99 to $24.99; lifetime $34.99 | iPhone, iPad, Mac and Vision Pro; high-res images; active updates | No animation or video; player database invites name and badge issues |
| [Tactics Board - Soccer](https://apps.apple.com/app/id6743544146) | 2025 newcomer with lineups and simple animations | Free; $2.99/month, $19.99/year, $39.99 lifetime | Cheap; 4.9 from 11 ratings | No video export listed; small audience |
| [Football Tactic Board: moves](https://apps.apple.com/us/app/-/id1458656274) | Drag-and-drop board for coaches | Free; $34.99 to $44.99/year | Field sizes and equipment | Last update v1.6 in 2020; 6 ratings at 3.0; no animation listed |
| [CoachNow Analyze](https://help.coachnow.io/en/articles/8534029-what-s-the-price-of-coachnow-analyze) | Video and image analysis with drawing tools | $9.99/month or $59.99/year | Strong telestration on real footage | Needs footage; no formation model or animation of players |

### Soft competitors

| Substitute | Why people use it | Where it fails |
| --- | --- | --- |
| Whiteboard or magnetic board | Instant, physical, no learning curve | Cannot be shared or replayed; gone after the session |
| PowerPoint or Keynote | Already installed; Magic Move can fake animation | Slow to build; no pitch or player model; awkward on a phone |
| [Canva](https://www.canva.com/templates/s/football/) templates | 15,275 football templates; good-looking matchday posts | Static; no formation logic; each lineup is a manual edit |
| Drawing on screenshots | Fast for FM and EA FC players | No motion; arrows lose meaning out of context |
| YouTube telestrators and video editors | Creators get pro-looking breakdowns | Needs footage and editing time; hard on a phone |
| [EA FC tactic codes](https://www.fut.gg/tactics/codes/) | One string imports a full tactic in game | Shows nothing visual; only works inside the game |

**The opening:** no product we found does Pencil drawing, keyframe animation, native 9:16 video and a portable tactic link in one app. Board apps aim at paid club staff and lineup apps stop at static images. A free, local-first app with a one-time Pro unlock can own the casual and creator end.

## Brainstorm

Name ideas: Tactics Board (working name), Chalkboard XI, Halfspace, Overlap.

- **Vertical-first export.** A 9:16 1080x1920 MP4 preset made for TikTok, Reels and Shorts, with safe zones for captions. TacticalPad stops at 16:10.
- **Keyframe steps, not timelines.** Each step is a snapshot of player positions; the app tweens between them. Drag a player, tap "Next step", repeat.
- **Pencil-native runs.** Draw a curved run with Apple Pencil and the player follows that path in the animation.
- **Two-state tactics.** One tactic holds an in-possession and an out-of-possession shape, matching FM26. Toggle or animate between them.
- **Tactic links and QR codes.** Encode the tactic JSON into a URL or QR. Anyone with the app opens the exact board; a web viewer shows it without the app.
- **Formation presets.** 4-3-3, 4-2-3-1, 3-5-2, 4-4-2, 4-1-4-1, 5-3-2, plus 5-a-side and 7-a-side shapes. One tap to switch, players keep their roles.
- **Role chips and instructions.** Short generic role labels (Inverted Full-Back, Target Forward) and notes per player, without copying any game's text.
- **EA FC code card.** Store a tactic code next to the drawn shape and export a card showing both. The visual explains what the code does.
- **Matchday lineup cards.** Generate a WhatsApp-ready image with date, kick-off, venue and subs, in the team's own colours.
- **Five-a-side rota.** Pick who plays from a group list, auto-balance two sides, and share both lineups as one image.
- **Creator voiceover.** Record narration while the move plays, muxed into the exported video.
- **Ghost trails and highlight.** Fading trails show where players came from; a spotlight ring marks the key runner.
- **Opposition layer.** Add a second side in a different colour to show a press or an overload.
- **Mac app for desk work.** A Mac Catalyst or native macOS build for FM players who already sit at a desk.
- **Template gallery.** Bundled classic patterns (third-man run, overlap, high press trigger) as editable starting points.
- **Shortcuts and widgets.** "Share today's lineup" from a Siri Shortcut; a lock-screen widget with next kick-off.

**Chosen direction:**

1. **Keyframe animation with 9:16 video export.** This is the clearest gap and the best portfolio demo. A 10-second clip shows the whole product.
2. **Apple Pencil drawing on iPad, finger on iPhone.** It shows native craft with PencilKit and plays to Chime's design skills.
3. **Open JSON tactic format with link and QR import.** It makes tactics spread between users and shows clean engineering in the repo.
4. **Formation presets and two-state tactics.** They give gamers and coaches a fast start and match how FM26 models a tactic.
5. **Matchday lineup card.** It is cheap to build and gives Sunday-league and five-a-side users a weekly reason to open the app.

## How we'd build it

**Architecture and stack**

- **App shell:** SwiftUI, iOS and iPadOS 18+, one universal target, with a Mac build through "Designed for iPad" first and native macOS later.
- **Board rendering:** SwiftUI `Canvas` inside a `TimelineView` for the pitch, players, arrows and tweened positions. It stays declarative, renders the same in-app and on export, and avoids a SpriteKit scene for 22 dots.
- **When to use SpriteKit:** only if profiling shows dropped frames with ghost trails or particles. Keep the renderer behind a `BoardRenderer` protocol so it can swap.
- **Drawing:** PencilKit `PKCanvasView` as an overlay for free ink. Convert a drawn stroke into a player path by sampling `PKStrokePath` points. Pencil-only drawing on iPad, finger on iPhone.
- **Animation model:** a tactic holds ordered steps; each step stores player positions and optional paths. Interpolate with ease-in-out per step and a per-step duration.
- **Video export:** render each frame offscreen with the same `Canvas` code into a `CGContext`, then append `CVPixelBuffer`s through `AVAssetWriterInputPixelBufferAdaptor`. H.264 or HEVC, 30 fps, presets for 1080x1920, 1920x1080 and 1080x1080. Do not rely on `ImageRenderer` for UIKit-backed views such as PencilKit; rasterise `PKDrawing` with `image(from:scale:)`.
- **Images and GIFs:** `ImageRenderer` for still cards; ImageIO for animated GIF.
- **Sharing:** `ShareLink` and `Transferable` for MP4, PNG and `.tactic` files; a custom UTType registered for import.
- **Tactic format:** versioned JSON (`schemaVersion`, pitch type, sides, players with role and number, steps, paths, notes). Compress with zlib and base64url into a link such as `tacticsboard.app/t#...`. Generate QR with Core Image `CIQRCodeGenerator`.
- **Web viewer:** a small static page on GitHub Pages that decodes the link fragment and plays the tactic. The data stays in the fragment and never hits a server.
- **Persistence:** SwiftData on device; optional iCloud sync through CloudKit later.
- **Layout:** iPad uses a three-column `NavigationSplitView` (library, board, inspector). iPhone uses a full-screen board with a bottom sheet for steps and roles.
- **Tooling:** Swift Testing for model and codec tests, snapshot tests for the board, GitHub Actions with Xcode Cloud or fastlane for TestFlight.

**Data and permissions**

- Local-first: every tactic lives on device; no account and no analytics SDK in v1.
- Permissions: Photos add-only access to save exports; microphone only when the user records a voiceover; camera only to scan a QR code.
- Links carry the full tactic in the URL fragment, so sharing needs no backend.
- Imported files are validated against the schema and size-capped at 256 KB before decoding.

### Product phases

#### Phase 0: Prototype (3–4 days)

**Goal:** prove that a drawn move can become a smooth 9:16 video on a real iPhone.

- One pitch, 11 v 0 players, 4-3-3 preset.
- Drag players, add up to 5 steps, play the tween.
- Export one MP4 at 1080x1920 through `AVAssetWriter`.

**Done when:** a 5-step move exports in under 10 seconds on an iPhone 13 and plays in Photos and WhatsApp.

#### Phase 1: MVP (2–3 weeks)

**Goal:** a free, App Store-ready app that coaches and gamers can use end to end.

- Presets: 4-3-3, 4-2-3-1, 3-5-2, 4-4-2, 5-3-2, plus 5-a-side and 7-a-side pitches.
- Two sides, numbers, names, generic role chips and per-player notes.
- PencilKit arrows and runs; player follows a drawn path.
- Export MP4 (9:16, 16:9, 1:1), PNG and lineup card.
- `.tactic` JSON file, link and QR import and export.
- iPad split view and iPhone compact layout; light and dark mode.

**Done when:** 20 TestFlight users each export a video and import a shared tactic without help, with crash-free sessions above 99.5%.

#### Phase 2: Creator and gamer features (1–2 weeks)

**Goal:** make Tactics Board the default tool for tactic clips and FM or EA FC breakdowns.

- In and out of possession states with an animated switch.
- Voiceover recording, captions and ghost trails.
- EA FC code card and FM role notes.
- Web viewer for links; template gallery of 15 classic patterns.
- Optional one-time Pro unlock (see monetisation).

**Done when:** 1,000 tactics have been shared by link and 25% of active users export at least one video a week.

#### Phase 3: Teams and Mac (about 2 weeks)

**Goal:** serve repeat team use and desk-based FM players.

- Native macOS app with keyboard shortcuts.
- iCloud sync and shared team folders through CloudKit sharing.
- Five-a-side rota and auto-balanced sides.
- Shortcuts actions and a next-match widget.

**Done when:** 30% of weekly users open the app on two devices, and the Mac build holds a 4.5+ rating.

## Feature and deliverable checklist

**Product**

- [ ] Write the one-page brief and the three core jobs: plan a lineup, animate a move, share a clip
- [ ] Define the tactic JSON schema v1 and publish it in the repo
- [ ] Pick the final name and check App Store and domain availability
- [ ] List the 8 formation presets and the 5-a-side and 7-a-side shapes
- [ ] Write the generic role list (about 20 roles) in our own words
- [ ] Define the free versus Pro line before Phase 2
- [ ] Recruit 20 TestFlight users: 5 coaches, 10 gamers, 5 creators

**Design**

- [ ] Design the pitch, player tokens and arrow styles in Figma
- [ ] Design the iPad three-column layout and the iPhone bottom-sheet layout
- [ ] Design the step strip: add, reorder, duplicate and delete steps
- [ ] Design the export sheet with 9:16, 16:9 and 1:1 previews and caption safe zones
- [ ] Design the matchday lineup card in 3 styles
- [ ] Pick a neutral kit colour system with no club look-alikes
- [ ] Design the app icon and App Store screenshots
- [ ] Write empty states, onboarding and error copy

**Engineering**

- [ ] Set up the Xcode project, SwiftData models and CI on GitHub Actions
- [ ] Build the `Canvas` board renderer behind a `BoardRenderer` protocol
- [ ] Build drag, snap-to-grid and multi-select for players
- [ ] Build the step model and tweening engine with per-step duration
- [ ] Add the PencilKit overlay and stroke-to-path conversion
- [ ] Build the `AVAssetWriter` exporter for MP4 at 30 fps
- [ ] Build PNG, GIF and lineup-card export
- [ ] Register the `.tactic` UTType and `Transferable` import and export
- [ ] Build the link codec (JSON, zlib, base64url) and QR generator
- [ ] Build QR scanning with `DataScannerViewController`
- [ ] Build the static web viewer on GitHub Pages
- [ ] Add voiceover recording and audio muxing (Phase 2)

**Quality**

- [ ] Unit tests for the schema, codec round trip and tweening maths
- [ ] Snapshot tests for the board at iPhone SE, iPhone Pro Max and iPad sizes
- [ ] Profile export on an iPhone 13; target under 10 seconds for 10 seconds of video
- [ ] VoiceOver labels for every player, step and control
- [ ] Dynamic Type up to accessibility sizes in all sheets
- [ ] Fuzz the importer with malformed and oversized files
- [ ] Test exports play in WhatsApp, TikTok, Instagram and X

**Launch and portfolio**

- [ ] Open-source the repo with an MIT licence and a clear README with GIFs
- [ ] Write a case study: problem, research, design decisions, metrics
- [ ] Record a 30-second 9:16 demo made in the app itself
- [ ] Submit to the App Store with a privacy label of "Data Not Collected"
- [ ] Post demo clips on X, TikTok and r/footballmanagergames with a tactic link
- [ ] Share on FM Scout forums following their tactic sharing guidelines
- [ ] Add the project to Chime's portfolio site and Dribbble or Behance

## Insights and considerations

- **Trademarks and likeness.** Ship no club badges, league names, real kits or player database. Lineup apps sell "league" and "champion shirt" packs; we will not. Apple expects the submitter to own or license the IP in an app ([Apple Developer Forums](https://developer.apple.com/forums/thread/114606)). Users may type any names themselves, but presets stay generic.
- **Game names.** Say "works with tactics from FM and EA FC" in plain text only. Do not use Sports Interactive, SEGA or EA logos or screenshots in the store listing. Write role names in our own words.
- **Privacy.** No account, no tracking, no analytics SDK in v1. Tactic links carry data in the URL fragment, which browsers do not send to servers. Lineup cards may hold children's names in youth teams, so keep everything on device.
- **Accessibility.** Players need VoiceOver labels such as "Number 8, central midfielder, step 2". Never use colour alone to separate sides; add shape or outline. Respect Reduce Motion with a step-through mode instead of tweening.
- **App Store review.** Avoid copying an existing app's name; "Tactics Board - Soccer" already exists, so the store name needs a suffix or a new name. Declare microphone and camera usage strings clearly. Show a full free experience before any paywall.
- **Monetisation later.** Free core with a one-time Pro unlock around $9.99 to $14.99: unlimited steps, voiceover, watermark-free 4K export, extra pitch styles. That undercuts TacticalPad's $39.99 a year. A later option is a creator pack of templates.
- **Lagos context.** Price local tiers for Nigeria in App Store Connect. Keep exports small for mobile data: target under 8 MB for a 15-second 1080p clip.
- **Portfolio story.** Lead with the 10-second demo clip. Then show the research gap, the JSON format, the renderer that powers both screen and export, and the metrics. Tag the GitHub repo with releases that match each phase.

## Success metrics

| Metric | Target |
| --- | --- |
| Phase 0 export time, 10 s clip on iPhone 13 | Under 10 seconds |
| Crash-free sessions | 99.5% or higher |
| New users who export a video or image in their first session | 40% |
| Tactics shared by link or QR in the first 90 days | 1,000 |
| Weekly active users at 6 months | 2,000 |
| App Store rating | 4.6 or higher |
| GitHub stars in the first 6 months | 500 |
| Pro conversion once launched | 3% of monthly actives |

## Sources

- [FM Scout: FM26 Tactics Index](https://www.fmscout.com/f-fm26-tactics-index.html)
- [GummySearch: r/footballmanagergames](https://gummysearch.com/r/footballmanagergames/)
- [GamingBolt: FM26 possession tactics and formations](https://gamingbolt.com/football-manager-26-gets-new-trailer-showcasing-new-possession-tactics-and-formations)
- [FUT.GG: EA FC tactics codes](https://www.fut.gg/tactics/codes/)
- [Canva: football templates](https://www.canva.com/templates/s/football/)
- [App Store: TacticalPad](https://apps.apple.com/app/id946927077)
- [SoccerTutor: Tactics Manager](https://www.soccertutor.com/tacticsmanager/)
- [Software Advice: Tacticsboard](https://www.softwareadvice.com/product/546220-Tacticsboard/)
- [easy2coach: Tactics app](https://www.easy2coach.net/en/tactics/)
- [App Store: Lineup11](https://apps.apple.com/app/id860716153)
- [App Store: Soccer Line Up Builder 11](https://apps.apple.com/us/app/-/id6737229261)
- [App Store: Tactics Board - Soccer](https://apps.apple.com/app/id6743544146)
- [App Store: Strike Lite](https://apps.apple.com/app/id6745530915)
- [App Store: Football Tactic Board: moves](https://apps.apple.com/us/app/-/id1458656274)
- [CoachNow: Analyze pricing](https://help.coachnow.io/en/articles/8534029-what-s-the-price-of-coachnow-analyze)
- [Apple: PencilKit documentation](https://developer.apple.com/documentation/pencilkit.md)
- [Kodeco: TimelineView and Canvas in SwiftUI](https://www.kodeco.com/27594491-using-timelineview-and-canvas-in-swiftui?page=1)
- [IMG.LY: Videos from still images with AVFoundation](https://img.ly/blog/how-to-make-videos-from-still-images-with-avfoundation-and-swift)
- [Create with Swift: ImageRenderer](https://createwithswift.com/exporting-swiftui-views-to-images-with-imagerender)
- [Apple Developer Forums: Guideline 5.2.1](https://developer.apple.com/forums/thread/114606)
