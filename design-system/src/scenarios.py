"""The Scenarios section (D-94, moves D-96): the sheet, the tile, the catalogue, the moves and their copy. Every name,
picture, position and note comes from the mockup at build time (scenario_export.js runs mockup/scenarios.js and
scenario-motion.js in node), so nothing here is retyped. Sizes and spacing are the app's (FormationPicker,
ScenarioPicture)."""
import html, json, os, subprocess
from icons import svg as I
from board import C, KITS, arrow, pitch, RATIO, f
from components import comp, spec, src, ids, segs, X

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
E = html.escape
SIZE_NAME = {"full": "11", "sevenASide": "7", "fiveASide": "5"}
SIZE_LONG = {"full": "11-a-side", "sevenASide": "7-a-side", "fiveASide": "5-a-side"}
GROUPS = ["Team shape", "Small-sided", "Set pieces"]


def load():
    out = subprocess.run(["node", os.path.join(HERE, "scenario_export.js"), ROOT], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def colours():
    """The pitch picture's CSS variables (mockup pitchSVG), from the board tokens. D-93: their ring's centre is solid."""
    home, home_ink, _ = KITS["lime"]
    away = KITS["coral"][0]
    v = {"home": home, "home-ink": home_ink, "away": away, "away-inner": C["bg"], "away-ink": C["awayInk"], "ball": C["ball"],
         "disc-outline": C["discOutline"], "bc-pitch-a": C["bcPitchA"], "bc-pitch-b": C["bcPitchB"], "bc-line": C["bcLine"]}
    return ";".join(f"--{k}:{x}" for k, x in v.items())


def tile(d, sid, on=False, picture=None):
    c = next(x for x in d["catalogue"] if x["id"] == sid)
    return (f'<div class="scn-tile{" on" if on else ""}">{picture or d["tiles"][sid]}'
            f'<div class="tx"><b>{E(c["name"])}</b><span>{E(c["line"])}</span></div></div>')


def players(c):
    if c["kind"] != "small":
        return "Both teams"
    if c["m"] == 0:
        return f'{c["n"]} v the keeper'
    return f'{c["n"]} v {c["m"]}' + (" + keeper" if c["keeper"] else "")


def sheet(d, chosen):
    """The Scenarios tab on a phone, scrolled to the top: shape chip, side switch, Team shape, then Small-sided."""
    shape = d["shape"]
    groups = ""
    for g in GROUPS[:1]:  # the frame ends inside Team shape; the other groups are below the fold
        items = [c for c in d["catalogue"] if c["group"] == g and c["id"] in d["offered"]["full"]]
        groups += (f'<div class="scn-group"><h4>{E(g)}</h4><div class="scn-grid">' +
                   "".join(tile(d, c["id"], c["id"] == chosen) for c in items) + "</div></div>")
    name = next(c["name"] for c in d["catalogue"] if c["id"] == chosen)
    chev = f'<span style="display:inline-grid;transform:rotate(-90deg)">{I("chevron-down", 14, "ic")}</span>'
    return (f'<div class="scn-phone" role="img" aria-label="The Formation sheet on its Scenarios tab, {E(name)} picked">'
            f'<div class="scn-behind" aria-hidden="true"></div><div class="sheet" aria-hidden="true"><span class="grab"></span>'
            f'<div class="scn-pinned"><div class="sheet-head"><span class="t-title">Formation</span><button class="close-btn">{X()}</button></div>'
            f'{segs(["Shapes", "Scenarios"], "Scenarios")}</div>'
            f'<div class="scn-list"><span class="scn-chip">{shape}<small>{SIZE_LONG["full"]}</small>{chev}</span>'
            f'{segs(["Attacking", "Defending"], "Attacking")}<p class="scn-help">{E(d["help"]["attacking"])}</p>{groups}</div>'
            f'<div class="scn-foot"><div class="toggle-row scn-move"><span>Include the move<small>Starting position only</small></span>'
            f'<span class="toggle off"></span></div><button class="cap-primary">Use {E(name)}</button></div></div></div>')


def catalogue_table(d):
    rows = ""
    for g in GROUPS:
        items = [c for c in d["catalogue"] if c["group"] == g]
        rows += f'<tr class="grp"><th colspan="4">{E(g)} <span class="muted">· {len(items)}</span></th></tr>'
        for c in items:
            sizes = " · ".join(SIZE_NAME[s] for s in c["sizes"]) + "-a-side" + (" only" if len(c["sizes"]) == 1 else "")
            # Defending runs as many steps and always ends "Ball won"; the cell says who wins it.
            move = (f'{c["steps"]} steps · {E(c["end"])}<br><span class="muted">Defending: {E(c["won"])}</span>'
                    if c["steps"] else '<span class="muted">No move yet</span>')
            rows += (f'<tr><td><b>{E(c["name"])}</b><br><span class="muted">{E(c["line"])}</span><br><code>scenario.{c["id"]}</code></td>'
                     f'<td>{players(c)}</td><td>{sizes}</td><td>{move}</td></tr>')
    return (f'<div class="scroll-x"><table class="sizes scn-cat"><thead><tr><th>Scenario</th><th>Players</th><th>Sizes</th>'
            f'<th>Move</th></tr></thead><tbody>{rows}</tbody></table></div>')


def legend():
    aw, ah = 300, 96
    kinds = (("run", .82), ("pass", .61), ("dribble", .4), ("press", .18))
    a = "".join(arrow({"kind": k, "points": [{"x": .08, "y": y}, {"x": .9, "y": y}]}, aw, ah, {}) for k, y in kinds)
    return (f'<svg class="board" width="{aw}" height="{ah}" viewBox="0 0 {aw} {ah}" role="img" aria-label="Run, pass or shot, dribble, press">'
            f'<rect width="{aw}" height="{ah}" fill="{C["bcPitchA"]}"/>{a}</svg>'
            '<div class="legend"><span>Run · white solid</span><span>Pass or shot · lime dashed</span><span>Dribble · yellow wavy</span>'
            '<span>Press · coral chevrons</span></div>')


def notes_table(d):
    att, dfd = d["example"]["attacking"], d["example"]["defending"]
    rows = "".join(f'<tr><td>{i + 1}</td><td class="t-note-cell">{E(a["note"])}</td><td class="t-note-cell">{E(b["note"])}</td>'
                   f'<td class="muted" style="white-space:nowrap">{f(a["duration"]) + " s" if i < len(att) - 1 else "holds"}</td></tr>'
                   for i, (a, b) in enumerate(zip(att, dfd)))
    return (f'<div class="scroll-x"><table class="sizes"><thead><tr><th>Step</th><th>Attacking</th><th>Defending</th><th>Move</th></tr></thead>'
            f'<tbody>{rows}</tbody></table></div>')


W = 300
H = W * RATIO


def live(d):
    name = next(c["name"] for c in d["catalogue"] if c["id"] == d["example"]["id"])
    ctrl = lambda i, cls, label, inner: f'<button type="button" class="{cls}" data-act="{i}" aria-label="{label}">{inner}</button>'
    return (f'<div class="app scn-live" id="scn-live" style="{colours()}"><div class="stack" style="gap:12px;max-width:{W}px;margin:0 auto">'
            f'<div class="t-headline">{E(name)} <span class="t-caption mut">· {d["shape"]}</span></div>'
            '<div class="segs" role="group" aria-label="Who has the ball"><button type="button" class="on" data-side="attacking" aria-pressed="true">Attacking</button>'
            '<button type="button" data-side="defending" aria-pressed="false">Defending</button></div>'
            f'<p class="scn-help" style="margin:-4px 0 0 4px" data-help>{E(d["help"]["attacking"])}</p>'
            f'<svg class="board scn-board" viewBox="0 0 {f(W)} {f(H)}" width="{f(W)}" height="{f(H)}" role="img" aria-label="The move">{pitch(W, H)}<g class="scn-layer"></g></svg>'
            '<div class="pbar"><div class="scrub" data-scrub style="padding:0"></div></div>'
            '<p class="pnote" style="padding:0;min-height:48px" aria-live="polite"><span class="t-caption mut" data-step></span><span class="t-note" data-note></span></p>'
            '<div class="scn-ctrls">' + ctrl("prev", "ib", "Previous step", I("step-back", 26, "ic bar-ic")) +
            ctrl("play", "disc", "Play", I("play", 26, "ic bar-ic") + I("pause", 26, "ic bar-ic")) +
            ctrl("next", "ib", "Next step", I("step-forward", 26, "ic bar-ic")) + "</div></div></div>")


def script(d):
    home, home_ink, _ = KITS["lime"]
    data = {"W": W, "H": H, "steps": {"attacking": d["example"]["attacking"], "defending": d["example"]["defending"]},
            "help": d["help"],
            "c": {"home": home, "homeInk": home_ink, "away": KITS["coral"][0], "awayInner": C["bg"], "awayInk": C["awayInk"],
                  "outline": C["discOutline"], "ball": C["ball"], "run": C["run"], "pass": C["pass"], "dribble": C["dribble"], "press": C["press"]}}
    js = open(os.path.join(HERE, "scenario_live.js")).read()
    return "<script>" + js.replace("__DATA__", json.dumps(data, separators=(",", ":")).replace("</", "<\\/")) + "</script>"


def section(head):
    d = load()
    n = {k: len(v) for k, v in d["offered"].items()}
    teams = sum(1 for c in d["catalogue"] if c["group"] == "Team shape" and c["id"] in d["offered"]["full"])
    small = sum(1 for c in d["catalogue"] if c["group"] == "Small-sided" and c["id"] in d["offered"]["full"])
    sets = sum(1 for c in d["catalogue"] if c["group"] == "Set pieces" and c["id"] in d["offered"]["full"])
    lo, hi = d["stepRange"]
    ex = d["example"]["id"]
    ex_name = next(c["name"] for c in d["catalogue"] if c["id"] == ex)
    rondo = next(c for c in d["catalogue"] if c["id"] == "3v1-rondo")
    pen = next(c for c in d["catalogue"] if c["id"] == "penalty")
    one = next(c for c in d["catalogue"] if c["id"] == "1v1-keeper")
    won = next(c for c in d["catalogue"] if c["id"] == ex)["won"]
    first = d["example"]["attacking"][0]["note"]
    no_keeper = " and ".join(E(c["name"]) for c in d["catalogue"] if c["kind"] == "small" and not c["keeper"])

    sheet_comp = comp("scenario-sheet", "Scenarios", "Scenarios sheet",
        "The Formation sheet's second tab. Your shape on a chip (tap it to change shape), who has the ball, then the scenarios that "
        f"fit your shape's size in three groups. Use sets up the scenario's starting position; with Include the move on, it brings the scenario's whole move (D-99). Here: {d['shape']}, "
        f"{E(ex_name)} picked.",
        f'<div class="scn-wrap" style="{colours()}">{sheet(d, ex)}</div>',
        [("Tabs", "Capsule segments: Shapes · Scenarios"),
         ("Shape chip", "Body 15 bold name, caption 12 muted size, chevron; surface2 capsule, 44 pt; opens Shapes"),
         ("Side", "Capsule segments Attacking · Defending; help line caption 12 muted, 8 pt under it, 4 pt in"),
         ("Groups", f"Headline 17, 12 pt above the tiles. {teams} team shapes, {small} small-sided, {sets} set pieces on 11-a-side; "
                    f"{n['sevenASide']} on 7-a-side, {n['fiveASide']} on 5-a-side"),
         ("Include the move", "Switch pinned above Use, off by default and remembered: off, Use sets up the starting position only (one step); on, the 3 to 5 ready-made steps (D-99). Headline 17 with a caption 12 muted line that says which"),
         ("Button", "Pinned under the list: quiet “Pick a scenario”, muted and disabled, until a tile is picked; then primary “Use &lt;name&gt;”"),
         ("Spacing", "24 pt sides, 16 pt between parts"),
         ("VoiceOver", "Chip: “Your shape, 4-3-3, 11-a-side. Change it”; group titles are headers"),
         ("IDs", ids("formation.tab.scenarios", "scenario.shape", "scenario.side.attacking", "scenario.side.defending",
                     "scenario.side.help", "scenario.group.team-shape", "scenario.include-move", "formation.apply")),
         ("Source", src("Features/Formation/FormationPicker.swift", "Model/Scenario.swift", "Engine/ScenarioBuilder.swift", "Engine/ScenarioMotion.swift") +
          "<br><code>mockup/scenarios.js</code>, <code>scenario-motion.js</code> (the spec)")])

    fr = d["framing"]
    fr_name = next(c["name"] for c in d["catalogue"] if c["id"] == fr["id"])
    tile_demo = (f'<div class="scn-wrap stack" style="{colours()};gap:20px">'
                 f'<div class="scn-grid c3">{tile(d, ex, True)}{tile(d, fr["id"])}{tile(d, "corner")}</div>'
                 '<p class="t-caption mut" style="margin-top:-8px">Team shape, picked · small-sided, framed on the play · '
                 'set piece, framed on the play (with both keepers in it, that is the whole pitch)</p>'
                 f'<div class="scn-grid"><figure class="scn-fig">{fr["whole"]}<figcaption>{E(fr_name)} on the whole pitch</figcaption></figure>'
                 f'<figure class="scn-fig">{fr["framed"]}<figcaption>Framed on the play: the pitch grows, the discs keep their size</figcaption></figure></div>'
                 f'<div class="scn-grid">{tile(d, ex, False)}{tile(d, ex, False, d["defending"][ex])}</div>'
                 '<p class="t-caption mut" style="margin-top:-8px">Attacking · Defending: the other side has the ball, lime is still your team</p></div>')
    tile_comp = comp("scenario-tile", "Scenarios", "Scenario tile",
        "A picture of the board the scenario sets up, its name and one line. Built from your shape by the same rules as the board, "
        "so what you pick is what you get.",
        tile_demo,
        [("Tile", "surface2, radius 16; 8 pt sides and top, 12 pt bottom; 2 pt text border when picked (no fill change)"),
         ("Picked", "With Include the move on, the picture loops the scenario's move: each step held, then eased to the next, a 1 s pause on the last. Off, and under Reduce Motion, it shows the set-up still (D-99)"),
         ("Words", "Name card title 15 bold; line caption 12 muted, two lines kept for it; 2 pt apart, 4 pt in, 6 pt under the picture"),
         ("Picture", "The pitch turned, our attack to the right, in the size's proportions (105 × 68, 60 × 40, 40 × 25 m); corners 8; hidden from VoiceOver"),
         ("Framing", "Team shapes: the whole pitch. Small-sided and set pieces: framed on the players and the ball across the whole move "
                     "(so a playing tile never jumps), with a margin, at least half the pitch long, at the picture's aspect, kept on the pitch"),
         ("Discs", "Radius max(4, width ÷ 30) pt on screen however the picture is framed; no numbers; lines max(1, width ÷ 240)"),
         ("Grid", "Two a row; three when the list is at least 480 pt wide (iPad); 12 pt gaps; a row is as tall as its tallest tile"),
         ("VoiceOver", "The name, hint the line, Selected when picked"),
         ("IDs", ids(f"scenario.{ex}", f"scenario.{fr['id']}")),
         ("Source", src("Features/Formation/FormationPicker.swift · scenarioTile", "Features/Formation/ScenarioPicture.swift") +
          "<br>Pictures here: <code>pitchSVG</code> in <code>mockup/scenarios-screens.js</code>, the set-up only")])

    motion_rows = [
        ("Steps", f"Every scenario is a move of {lo} to {hi} steps: the set-up, then one step after each beat (passes, runs, dribbles, a shot); the last step is the end."),
        ("Who moves", "The side on the ball follows a short script by role, never by shirt number (“the left-most centre-back”), "
                      "so a 3-5-2 plays it with its wing-back where a 4-3-3 uses its full-back."),
        ("The other side", "Reacts by rule after every beat: the nearest player presses, one tracks each runner, the keeper sets on the ball's side, "
                           "the rest slide across and up with the ball. At set pieces they hold their zones. A beaten defender stays beaten."),
        ("How it ends", f"Attacking: in a goal, except {E(rondo['name'])}, which ends “{E(rondo['end'])}”. Defending: your team wins the ball, “{E(pen['endDefending'])}”."),
        ("Defending", "The opponent runs the same move down the board and your team reacts, but nobody on your side is beaten and their last action "
                      "(the shot) never comes. Instead your nearest outfield player wins the ball: a press arrow onto it and the note "
                      f"“{E(won)}”. The keeper takes it only at a {E(pen['name'].lower())} or when there is no outfield defender "
                      f"({E(one['name'])}): “{E(one['won'])}”. Their notes start “Their”; the last step is “{E(pen['endDefending'])}”."),
        ("Notes", f"Each step's note says what happens next, in shirt numbers, in the coach's handwriting: “{E(first)}”."),
        ("Arrows", "Shown on the step they start from, fading as the players move. Run, pass or shot, dribble (below); "
                   "a press only for the player who wins the ball on Defending."),
    ]
    motion_html = ('<div class="scroll-x"><table class="a11y scn-stack"><tbody>' +
                   "".join(f'<tr><td class="scn-rule"><b>{a}</b></td><td>{b}</td></tr>' for a, b in motion_rows) + "</tbody></table></div>")

    toast = f'{ex_name} set up'
    copy_rows = [
        ("Side help", E(d["help"]["attacking"]) + "<br>" + E(d["help"]["defending"]), "Under Attacking · Defending"),
        ("Switch", "Include the move<br>Starting position only · 3 to 5 ready-made steps", "Above Use, off by default, remembered (D-99)"),
        ("Button", f"Pick a scenario → Use {E(ex_name)}", "Disabled until a tile is picked"),
        ("Confirm", f"Set up {E(ex_name)}?<br>This replaces the move on the board. You can undo.", "When there's anything to replace: players, more than one step, or arrows, runs, marks or a note on the one step. Cancel · Set up (D-96)"),
        ("Toast", f"{E(toast)} · Undo", "4 s. When a full board can't take everyone: “… set up. 2 players didn't fit”"),
        ("Undo name", f"Set up {E(ex_name.lower())}", "One undoable edit"),
        ("Wins the ball", f"{E(won)} · {E(one['won'])}", "Defending, the step before the end: an outfield player, or the keeper at a penalty or 1v1"),
        ("Ends", f"Goal · {E(rondo['end'])}<br>{E(pen['endDefending'])}", "The last step's note: attacking, then defending"),
    ]
    copy_html = ('<div class="scroll-x"><table class="a11y scn-stack"><thead><tr><th>Where</th><th>Copy</th><th>Note</th></tr></thead><tbody>' +
                 "".join(f'<tr><td><b>{a}</b></td><td>{b}</td><td class="muted">{c}</td></tr>' for a, b, c in copy_rows) + "</tbody></table></div>")
    copy_demo = ('<div class="app"><div class="row" style="gap:24px;align-items:flex-start">'
                 f'<div class="alert"><div class="body"><h5>Set up {E(ex_name)}?</h5><p>This replaces the move on the board. You can undo.</p></div>'
                 '<div class="btns"><div>Cancel</div><div>Set up</div></div></div>'
                 f'<div class="toast" style="flex:1;min-width:240px">{E(toast)}<button>Undo</button></div></div></div>')

    return (f'<section class="sec" id="scenarios">{head("scenarios", "08", "Scenarios", "A ready-made start for a move, on the Formation sheet. Pick your shape, a situation and who has the ball: the board is set up with both teams and the ball, and plays out as a short move. Attacking, it ends in a goal (3v1 keep the ball ends with the ball kept); defending, your team wins the ball before they shoot.")}'
            '<div class="principles p3"><div><h3>Built from your shape</h3><p>Your players keep their numbers and roles; the opponent stands in the size\'s most common shape. Rules place everyone, not hand-drawn boards (D-94).</p></div>'
            '<div><h3>Lime is always your team</h3><p>Attacking or Defending only says who has the ball. On Defending the other side runs the move and your team wins the ball.</p></div>'
            f'<div><h3>Every scenario is a move</h3><p>{lo} to {hi} steps with arrows and a note on each, so Play works the moment it is set up (D-96).</p></div></div>'
            f'{sheet_comp}{tile_comp}'
            f'<div class="sub" id="scn-catalogue"><h3>Catalogue</h3><p class="lead">{n["full"]} scenarios on 11-a-side, {n["sevenASide"]} on 7-a-side, {n["fiveASide"]} on 5-a-side. '
            f'Small-sided games count the side on the ball first, and have their keeper in goal except {no_keeper}. Set pieces are 11-a-side only, except kick-off.</p>'
            f'{catalogue_table(d)}</div>'
            f'<div class="sub" id="scn-motion"><h3>Moves</h3><p class="lead">How a scenario plays out. The script is the same for every shape; who plays each part comes from the shape.</p>'
            f'{motion_html}<div style="margin-top:20px">{legend()}</div></div>'
            f'<div class="sub" id="scn-copy"><h3>Copy</h3><p class="lead">What the sheet, the confirm and the toast say.</p>{copy_demo}<div style="margin-top:16px">{copy_html}</div></div>'
            f'<div class="sub" id="scn-live-sub"><h3>Live example</h3><p class="lead">{E(ex_name)} from a {d["shape"]}, as built by the move rules. Switch sides to see the same move run by them, until your team wins the ball.</p>'
            f'<div class="grid scn-live-grid">{live(d)}<div>{notes_table(d)}</div></div></div>'
            "</section>"), script(d)
