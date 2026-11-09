"""Every component in the app, rendered in HTML/CSS from its SwiftUI source (git 89a0eb9), with its spec."""
from icons import svg as I
from board import board_svg, formation_diagram, formations, STEPS, pitch, token, arrow, marks, TOK, RATIO, KITS, f

SRC = "CenterSpot/"


def spec(rows):
    return '<dl class="spec">' + "".join(f"<dt>{k}</dt><dd>{v}</dd>" for k, v in rows) + "</dl>"


def comp(cid, group, title, desc, demo, rows):
    return (f'<article class="comp" id="c-{cid}"><header><span class="grp">{group}</span><h3>{title}</h3><p>{desc}</p></header>'
            f'<div class="app">{demo}</div>{spec(rows)}</article>')


def src(*paths):
    return "<br>".join(f"<code>{SRC}{p}</code>" for p in paths)


def ids(*xs):
    return " ".join(f"<code>{x}</code>" for x in xs)


X = lambda cls="in-ic": I("close", 20, f"ic {cls}")


def segs(options, on, cls=""):
    return f'<div class="segs {cls}">' + "".join(f'<button class="{"on" if o == on else ""}">{o}</button>' for o in options) + "</div>"


def chips(current=1, n=5, durs=("1.2 s", "1.4 s", "1 s", "1.6 s", "1.2 s"), pulse=False):
    out = '<div class="strip">'
    for i in range(n):
        cls = "chip on" + (" pulse" if pulse and i == current else "") if i == current else "chip"
        out += f'<div class="{cls}"><b>{i+1}</b><small>{durs[i]}</small></div>'
    return out + f'<div class="chip add">{I("plus", 20, "ic in-ic")}</div></div>'


def toolbar(drawing=False):
    def item(icon, label, lit=False, off=False):
        return f'<div class="item{" lit" if lit else ""}{" off" if off else ""}"><span class="ib">{I(icon, 26, "ic bar-ic")}</span>{label}</div>'
    o = drawing
    return ('<div class="toolbar">' + item("formation", "Formation", off=o) + item("add", "Add", off=o) +
            f'<div class="item play{" off" if o else ""}"><span class="disc">{I("play", 26, "ic bar-ic")}</span>Play</div>' +
            item("draw", "Draw", lit=o) + item("export", "Export", off=o) + "</div>")


def sideways(W, step):
    """TacticCard's thumbnail: step 1 at rest with the whole pitch turned sideways."""
    inner = board_svg(W, step=step, arrows=[], label="")
    inner = inner.split(">", 1)[1].rsplit("</svg>", 1)[0]
    H = W * RATIO
    return (f'<svg viewBox="0 0 {f(H)} {f(W)}" preserveAspectRatio="xMidYMid meet" aria-hidden="true">'
            f'<g transform="translate(0 {f(W)}) rotate(-90)">{inner}</g></svg>')


def build():
    out = []
    A = out.append

    # ---------- Controls ----------
    A(comp("primary", "Controls", "Primary capsule",
           "The one lime action on a sheet or screen: New tactic, Use 4-3-3, Export video, Save note, Next. One per screen (D-80).",
           f'<div class="stack" style="max-width:345px"><button class="cap-primary">{I("plus", 20, "ic in-ic")}New tactic</button>'
           '<button class="cap-primary">Use 4-3-3</button><button class="cap-primary pressed">Export video <span style="font-weight:500;font-size:12px">(pressed: 80%)</span></button></div>',
           [("Type", "Headline 17 bold"), ("Ink", "accentInk on accent"), ("Size", "Full width × 52 pt capsule"),
            ("Pressed", "Opacity 0.8"), ("Copy", "Verb first, says what happens: Use 4-3-3, Export video, Save note"),
            ("VoiceOver", "The button's own title"), ("IDs", ids("launch.new", "formation.apply", "export.start", "note.save", "onboarding.next")),
            ("Hit target", "52 pt tall"), ("Source", src("Design/Components.swift · PrimaryCapsuleStyle"))]))
    A(comp("quiet", "Controls", "Quiet capsule",
           "The second action under a primary, or a destructive one in danger red: Delete player, Cancel, Save to Photos.",
           '<div class="stack" style="max-width:345px"><button class="cap-quiet">Save to Photos</button><button class="cap-quiet danger">Delete player</button></div>',
           [("Type", "Headline 17 bold"), ("Ink", "text, or danger #FF6B6B, on surface2"), ("Size", "Full width × 52 pt"),
            ("Pressed", "Opacity 0.8"), ("IDs", ids("inspector.delete", "export.cancel", "export.save")), ("Hit target", "52 pt tall"),
            ("Source", src("Design/Components.swift · QuietCapsuleStyle"))]))
    A(comp("rowcap", "Controls", "Row capsule",
           "Small actions in the row under the pitch and on mark rows: Edit, Draw run, Remove, Duplicate, Note. Disabled at 40%.",
           '<div class="row"><button class="cap-row">Edit</button><button class="cap-row">Draw run</button><button class="cap-row">Remove</button>'
           '<button class="cap-row">1.2 s</button><button class="cap-row" disabled>Delete</button></div>',
           [("Type", "Caption 12 semibold"), ("Ink", "text on surface2"), ("Size", "44 pt tall, 12 pt side padding"),
            ("States", "Pressed 0.7 · disabled 0.4"), ("IDs", ids("selection.edit", "selection.run", "selection.delete", "step.duration", "step.delete")),
            ("Hit target", "44 pt"), ("Source", src("Design/Components.swift · RowCapsuleStyle"))]))
    A(comp("sheethead", "Controls", "Sheet header and close",
           "Every sheet opens with its title on the left and a round close button on the right. Sheets are surface with 20 pt corners and a drag indicator.",
           f'<div class="sheet" style="max-width:393px"><span class="grab"></span><div class="sheet-head"><span class="t-title">Formation</span>'
           f'<button class="close-btn">{X()}</button></div></div>',
           [("Type", "Title 22 bold (header trait)"), ("Close", "44 pt circle, surface2, × inline icon"), ("VoiceOver", "“Close”"),
            ("IDs", ids("formation.close", "inspector.close", "export.close", "note.close")), ("Sheet", "surface, radius 20, dark, drag indicator"),
            ("Source", src("Design/Components.swift · SheetHeader, SheetCloseButton, centerSpotSheet()"))]))
    A(comp("segments", "Controls", "Capsule segments",
           "A segmented choice on a capsule track: pitch sizes, the player's side, Straight or Curved, Flat or Broadcast, speed. At accessibility sizes it stacks into a column when the row won't fit.",
           '<div class="stack" style="max-width:345px">' + segs(["11-a-side", "7-a-side", "5-a-side"], "11-a-side") +
           segs(["Us (filled)", "Them (ring)"], "Us (filled)") + segs(["Flat", "Broadcast"], "Broadcast") + "</div>",
           [("Type", "Body 15 semibold"), ("Ink", "Selected text on surface3, others muted"), ("Track", "surface2 capsule, 4 pt inset, 2 pt gaps"),
            ("VoiceOver", "Each segment by its title, the picked one Selected"),
            ("IDs", ids("formation.size.full", "inspector.side.home", "export.camera.broadcast", "draw.shape.curved", "playback.speed.half")),
            ("Hit target", "44 pt tall"), ("Source", src("Design/Components.swift · CapsuleSegments"))]))
    A(comp("fields", "Controls", "Field, group label and role option",
           "The player sheet's parts: a name and number field on one row, small grey group labels, and role rows with a check on the chosen one.",
           '<div class="stack" style="max-width:345px;gap:8px"><div class="row" style="flex-wrap:nowrap;gap:12px"><div class="field" style="flex:1">Ade</div>'
           '<div class="field" style="width:88px;justify-content:center">7</div></div><div class="group-label">Role · Attackers ⌄</div>'
           f'<div class="option">Winger{I("check", 20, "ic in-ic")}</div><div class="option">Inside forward</div><div class="option">Striker</div></div>',
           [("Field", "Body 15 on surface2, radius 12, 48 pt tall, 16 pt padding; number 88 pt wide, two digits"),
            ("Group label", "Caption 12, muted, 12 pt above"), ("Option", "Body 15, surface2, radius 12, min 48 pt, check when chosen"),
            ("VoiceOver", "“Name”, “Shirt number”, “Role line, Attackers”"),
            ("IDs", ids("inspector.name", "inspector.number", "inspector.role-line", "inspector.role.winger")),
            ("Source", src("Features/Inspector/PlayerSheet.swift", "Design/Components.swift · GroupLabel"))]))
    A(comp("toggle", "Controls", "Switch",
           "The system switch, tinted muted rather than green or lime, so the sheet's one lime element stays the action.",
           '<div class="stack" style="max-width:240px;gap:4px"><div class="toggle-row">Title band<span class="toggle"></span></div>'
           '<div class="toggle-row">Step notes<span class="toggle off"></span></div></div>',
           [("Type", "Headline 17 bold, text"), ("Tint", "muted #93A0AD"), ("IDs", ids("export.title-band", "export.notes")),
            ("Hit target", "The whole row"), ("Source", src("Features/Export/ExportSheet.swift"))]))

    # ---------- Board chrome ----------
    A(comp("toolbar", "Board", "Board toolbar",
           "Formation · Add · Play · Draw · Export (D-55). Play is the lime disc in the middle. In iPad landscape draw mode, Draw is lit and the rest fade to 40%.",
           f'<div class="stack"><div style="width:393px;max-width:100%">{toolbar()}</div><div style="width:393px;max-width:100%">{toolbar(True)}</div></div>',
           [("Type", "Caption 12 labels; bar icons 22 pt medium (here the new set)"), ("Ink", "muted; Play label and lit Draw in text; disc accent"),
            ("Size", "82 pt tall, surface; disc 48 pt"), ("Dynamic Type", "Capped at Large, Large Content Viewer above"),
            ("VoiceOver", "Formation, Add (hint: “Adds a player, the ball or a cone on the centre spot”), Play, Draw, Export"),
            ("IDs", ids("toolbar.formation", "toolbar.add", "toolbar.play", "toolbar.draw", "toolbar.export")),
            ("Hit target", "Each item a fifth of the bar × 60 pt"), ("Source", src("Features/Board/BoardToolbar.swift"))]))
    A(comp("addmenu", "Board", "Add menu",
           "Add's system menu. A new token lands on the centre spot. Ball is disabled when the board already has one.",
           f'<div class="menu"><div>Our player{I("our-player", 20, "ic in-ic")}</div><div>Their player{I("their-player", 20, "ic in-ic")}</div>'
           f'<div class="dis">Ball{I("ball", 20, "ic in-ic")}</div><div>Cone{I("cone", 20, "ic in-ic")}</div></div>',
           [("Type", "System menu"), ("Icons", "our-player, their-player, ball, cone"), ("Toast when full", "“There's already a ball on the board.”"),
            ("Source", src("Features/Board/BoardToolbar.swift · addMenu"))]))
    A(comp("nav-edit", "Board", "Nav bar · editing",
           "Back to the library, the title menu in the middle, Undo and Redo on the right. On iPad portrait Share sits beside them; on iPhone it lives in the title menu (D-83).",
           f'<div style="width:393px;max-width:100%" class="navbar"><button class="glass"><span style="display:grid;place-items:center;width:44px;height:44px">{I("back", 22, "ic")}</span></button>'
           f'<span class="title">Overlap down the left {I("chevron-down", 14, "ic")}</span>'
           f'<span class="glass"><button>{I("undo", 22, "ic")}</button><button class="dis">{I("redo", 22, "ic")}</button></span></div>',
           [("Type", "Headline 17 bold title, truncates; chevron in caption, muted"), ("Width", "Title gets the bar minus 208 pt (navBarItems)"),
            ("Keys", "⌘Z, ⇧⌘Z"), ("VoiceOver", "The title, hint “Share, rename or change the pitch”"),
            ("IDs", ids("nav.title", "nav.undo", "nav.redo", "nav.share")), ("Source", src("Features/Board/BoardScreen+Navigation.swift"))]))
    A(comp("titlemenu", "Board", "Title menu",
           "The board title opens Share (iPhone), Rename and the pitch: 11, 7 or 5-a-side, Stripes or Plain.",
           f'<div class="menu"><div>Share{I("share", 20, "ic in-ic")}</div><div>Rename{I("rename", 20, "ic in-ic")}</div><div class="sep"></div>'
           '<div>Pitch<span class="msub">11-a-side ›</span></div><div>Pitch style<span class="msub">Stripes ›</span></div></div>',
           [("Copy", "Share · Rename · Pitch · Pitch style"), ("Rename alert", "“Rename tactic” with a Title field, Cancel, Rename"),
            ("Source", src("Features/Board/BoardScreen+Navigation.swift · titleMenu", "Features/Board/SharedTactic.swift"))]))
    A(comp("nav-play", "Board", "Nav bar · playing, and the camera switch",
           "Flat or Broadcast on its own dark track, the title, and Done. The picked camera is lit, remembered, and shared with Export.",
           f'<div style="width:393px;max-width:100%" class="navbar"><span class="camsw"><button>{I("camera-flat", 22, "ic")}</button>'
           f'<button class="on">{I("camera-broadcast", 22, "ic")}</button></span><span class="title">Overlap down the left</span>'
           '<button class="textbtn">Done</button></div>',
           [("Camera switch", "Two 44 pt buttons on a surface2 capsule, 2 pt inset; on = surface3 + text, off = muted; icons 22 pt, 2 pt stroke"),
            ("VoiceOver", "“Camera”: “Flat camera”, “Broadcast camera”, one Selected; Done hint “Back to editing this step”"),
            ("IDs", ids("playback.camera.flat", "playback.camera.broadcast", "playback.done")),
            ("Source", src("Features/Playback/CameraSwitch.swift", "Features/Board/BoardScreen+Navigation.swift"))]))
    A(comp("nav-draw", "Board", "Nav bar · drawing",
           "Cancel on the left, “Draw” in the middle, and a lime check disc to finish.",
           f'<div style="width:393px;max-width:100%" class="navbar"><span class="glass"><button>{I("close", 22, "ic")}</button></span>'
           f'<span class="title">Draw</span><button class="check-disc">{I("check", 20, "ic in-ic")}</button></div>',
           [("VoiceOver", "“Cancel drawing”, “Draw” (header), “Done”"), ("IDs", ids("draw.cancel", "draw.title", "draw.done")),
            ("Hit target", "44 pt"), ("Source", src("Features/Board/BoardScreen+Navigation.swift · drawingItems"))]))
    A(comp("context", "Board", "Context row",
           "The row under the pitch. Nothing floats over the pitch (UI-BRIEF §1). Summary by default; a selected player's actions; the current step's actions once its chip is tapped again.",
           '<div class="stack" style="max-width:345px;gap:4px"><div class="ctx"><span class="tag">4-3-3</span><span style="flex:1"></span>'
           '<span class="t-caption mut">Step 1 of 5 · 1.2 s</span></div><div class="ctx"><span class="lbl">7 · Winger</span><button class="cap-row">Edit</button>'
           '<button class="cap-row">Draw run</button><button class="cap-row">Remove</button></div><div class="ctx"><span class="lbl">Step 2</span>'
           '<button class="cap-row">1.4 s</button><button class="cap-row">Duplicate</button><button class="cap-row">Note</button><button class="cap-row">Delete</button></div></div>',
           [("Type", "Caption 12; formation tag on a surface2 capsule; label muted"), ("Height", "44 pt; scrolls sideways at accessibility sizes"),
            ("Durations", "0.3, 0.5, 0.8, 1, 1.2, 1.4, 1.6, 2, 2.5, 3, 4, 5 s"), ("VoiceOver", "“Duration, 1.4 s”"),
            ("IDs", ids("board.formation-tag", "board.step-label", "selection.label", "steps.hint", "step.duplicate", "step.note")),
            ("Source", src("Features/Board/BoardContextRow.swift"))]))
    A(comp("strip", "Board", "Steps strip",
           "Numbered chips with their times, the current one lime, + at the end. Tap goes to a step; tap the current again for its actions; press, hold and drag reorders. A new chip pulses once (not with Reduce Motion).",
           chips(),
           [("Chip", "48 × 58 pt, radius 12, surface2; number headline 17 bold, time caption 12 semibold muted"),
            ("Current", "accent fill, accentInk, time at 75%"), ("Add", "Dashed 1.5 pt muted outline, 4/4 dash"), ("Spacing", "8 pt; 24 pt side inset"),
            ("Motion", "Pulse to 1.12 and back over 0.22 s"), ("VoiceOver", "“Step 2, 1.4 s”, hint “Double-tap for step actions” on the current one; “Add a step”"),
            ("IDs", ids("steps.chip.1", "steps.add")), ("Source", src("Features/Board/StepsStrip.swift", "Features/Board/StepChip.swift"))]))
    A(comp("stepslist", "Board", "Steps list (iPad landscape)",
           "Every step as a row with its handwritten note, in the iPad's right column. Scrolls when the steps don't fit.",
           f'<div class="steps-list"><div class="hd"><span class="t-headline mut">Steps</span><span class="addc">{I("plus", 20, "ic in-ic")}</span></div>'
           '<div class="srow"><span class="n">1</span><span class="d">1.2 s</span><span class="t">8 finds the winger</span></div>'
           '<div class="srow on"><span class="n">2</span><span class="d">1.4 s</span><span class="t">11 drives inside</span></div>'
           '<div class="srow"><span class="n">3</span><span class="d">1 s</span><span class="t empty">No note</span></div></div>',
           [("Row", "Number title 22 bold, time caption 12 semibold, note Kalam 18 (two lines); min 58 pt, radius 12"),
            ("VoiceOver", "“Step 2 of 5, 1.4 seconds, 11 drives inside”"), ("IDs", ids("steps.title", "steps.row.2", "steps.add")),
            ("Built", "Off the main thread on iPadOS 26 hardware: nonisolated inits, @Sendable closures"),
            ("Source", src("Features/Board/StepsList.swift", "Features/Board/StepRow.swift"))]))
    A(comp("colcard", "Board", "Column card (iPad)",
           "The iPad column's row card: the context row while editing, the mark row while drawing.",
           '<div style="max-width:360px;background:#0B0F14"><div class="colcard"><span class="t-headline" style="flex:1">7 · Winger</span>'
           '<button class="cap-row">Edit</button><button class="cap-row">Remove</button></div></div>',
           [("Size", "min 64 pt; 20 pt leading, 12 pt trailing and vertical padding"), ("Fill", "surface, radius 16"),
            ("Type", "Headline 17 label in text"), ("Source", src("Design/Components.swift · columnCard()"))]))
    A(comp("playback", "Board", "Playback bar",
           "Replaces the strip and toolbar while the move plays: one bar per step that fills, the step's note, the time, then Loop · Previous · Play/Pause · Next · speed.",
           '<div class="pbar" style="width:393px;max-width:100%"><div class="scrub"><i><b style="width:100%"></b></i><i><b style="width:55%"></b></i><i></i><i></i><i></i></div>'
           '<div class="pnote"><span class="t-caption mut">Step 2 of 5 · </span><span class="t-note">11 drives inside</span></div>'
           '<div class="time">0:01.9 / 0:06.4</div><div class="ctrls">'
           f'<span class="ib">{I("loop", 26, "ic bar-ic")}</span><span class="ib">{I("step-back", 26, "ic bar-ic")}</span>'
           f'<span class="play"><span class="disc">{I("pause", 26, "ic bar-ic")}</span>Pause</span><span class="ib">{I("step-forward", 26, "ic bar-ic")}</span>'
           f'<span class="speed">{segs(["½×", "1×"], "1×")}</span></div></div>',
           [("Scrubber", "6 pt bars, 6 pt apart, surface2 track, accent fill; 44 pt tall to drag"),
            ("Time", "Caption 12 monospaced digits, “0:04.2 / 0:06.5” (the timeline's length)"),
            ("Note", "“Step 2 of 5 · ” caption muted + Kalam note in text"), ("Loop", "text when on, muted when off"),
            ("VoiceOver", "Scrubber: “Step 2 of 5”, value is the time, swipe up/down for next/previous"),
            ("IDs", ids("playback.scrubber", "playback.note", "playback.time", "playback.loop", "playback.prev", "playback.toggle", "playback.next", "playback.speed.one")),
            ("Source", src("Features/Playback/PlaybackBar.swift"))]))
    tools_row = lambda names, on: "".join(f'<div class="ktile{" on" if n == on else ""}"><svg viewBox="0 0 24 24" preserveAspectRatio="{"none" if n in ("run","pass","dribble","press") else "xMidYMid meet"}"><use href="#t-{n}"/></svg><span>{n.capitalize()}</span></div>' for n in names)
    A(comp("drawpanel", "Board", "Draw panel",
           "Under the pitch in draw mode: the handwritten hint, the Shape switch (or the mark's help line), then four arrows that move players and three marks that explain. Each tile draws its line style in its colour, so kinds never differ by colour alone.",
           '<div style="max-width:393px"><div class="hint">Start on a player to draw their run.</div><div class="dpanel">'
           f'<div class="shape-row"><span class="lab">Shape</span>{segs(["Straight", "Curved"], "Straight", "inset2")}</div>'
           f'<div class="tiles c4">{tools_row(["run", "pass", "dribble", "press"], "run")}</div><div class="tiles c3">{tools_row(["zone", "line", "glow"], None)}</div></div></div>',
           [("Panel", "surface2, radius 24, 12 pt padding, shadow black 50% / 15 / y 8"), ("Tile", "50 pt (64 in the iPad column), radius 16, 2 pt text border when picked"),
            ("Tile label", "Body 15 semibold"), ("Hint", "Kalam 18 muted, centred"), ("Shape label", "13 semibold muted on a surface track, 2 pt inset"),
            ("VoiceOver", "Tool name, hint = its help line: “Pass · dashed line · the ball follows it”"),
            ("IDs", ids("draw.kind.run", "draw.shape.straight", "draw.hint", "draw.kind-help", "draw.mark.remove")),
            ("Source", src("Features/Draw/DrawPanel.swift", "Features/Draw/ToolIcon.swift", "Features/Draw/DrawTool.swift"))]))

    # ---------- Sheets ----------
    A(comp("playersheet", "Sheets", "Player sheet",
           "Name and number on one row, the role grouped by line, the side, and Delete player. Edits commit as one undo step each.",
           f'<div class="sheet" style="max-width:393px"><span class="grab"></span><div class="stack" style="gap:0"><div class="sheet-head" style="margin-bottom:16px">'
           f'<span class="t-title">Number 7</span><button class="close-btn">{X()}</button></div><div class="row" style="flex-wrap:nowrap;gap:12px">'
           '<div class="field" style="flex:1">Ade</div><div class="field" style="width:88px;justify-content:center">7</div></div>'
           f'<div class="group-label" style="padding-bottom:8px">Role · Attackers ⌄</div><div class="stack" style="gap:8px"><div class="option">Winger{I("check", 20, "ic in-ic")}</div>'
           '<div class="option">Inside forward</div></div><div class="group-label" style="padding-bottom:8px">Side</div>' + segs(["Us (filled)", "Them (ring)"], "Us (filled)") +
           '<div style="padding-top:16px"><button class="cap-quiet danger">Delete player</button></div></div></div>',
           [("Title", "“Number 7”, else the name, else “Their player” / “Player”"), ("Detents", "72%, large"),
            ("Undo names", "Rename player · Change number · Change role · Change side"),
            ("IDs", ids("inspector.close", "inspector.name", "inspector.number", "inspector.role", "inspector.side", "inspector.delete")),
            ("Source", src("Features/Inspector/PlayerSheet.swift"))]))
    fm = formations("full")[:6]
    tiles = "".join(f'<div class="ftile{" on" if i == 0 else ""}">{formation_diagram(x["slots"])}{x["name"]}</div>' for i, x in enumerate(fm))
    A(comp("formation", "Sheets", "Formation picker",
           "11 / 7 / 5-a-side, chalk dot diagrams with the chosen one outlined, and “Use 4-3-3” kept in reach under the scrolling grid.",
           f'<div class="sheet" style="max-width:393px"><span class="grab"></span><div class="stack" style="gap:16px"><div class="sheet-head"><span class="t-title">Formation</span>'
           f'<button class="close-btn">{X()}</button></div>{segs(["11-a-side", "7-a-side", "5-a-side"], "11-a-side")}<div class="ftiles">{tiles}</div>'
           f'<button class="cap-primary">Use {fm[0]["name"]}</button></div></div>',
           [("Tile", "min 128 pt, surface2, radius 16, 2 pt text border when chosen; diagram 74 × 92 pt; name caption 12 semibold"),
            ("Diagram", "chalk (white 55%) outline and halfway line, 3.6 pt text dots"), ("Grid", "3 columns, 12 pt gaps"),
            ("IDs", ids("formation.size.full", "formation.4-3-3", "formation.apply")), ("Source", src("Features/Formation/FormationPicker.swift"))]))
    A(comp("alerts", "Sheets", "Confirmations",
           "System alerts, in our words. Changing the shape on a board with players asks first and says who leaves; deleting a tactic says it can't be undone.",
           '<div class="row" style="gap:20px;align-items:flex-start"><div class="alert"><div class="body"><h5>Move players to 2-3-1 (7-a-side)?</h5>'
           '<p>Names and numbers stay. 4 players leave the board.</p></div><div class="btns"><div>Cancel</div><div>Move</div></div></div>'
           '<div class="alert"><div class="body"><h5>Delete “Overlap down the left”?</h5><p>This can\'t be undone.</p></div><div class="btns red"><div>Cancel</div><div>Delete</div></div></div></div>',
           [("Copy", "Question title; message states the consequence in plain numbers"), ("After", "Toast “Removed 4 players” with Undo"),
            ("IDs", ids("library.delete.confirm")), ("Source", src("Features/Formation/FormationPicker.swift", "Features/Library/LibraryScreen.swift"))]))
    pv = board_svg(150 * 0.86, step=0, label="Preview, Vertical 9:16, broadcast camera")
    preview = (f'<div class="preview"><div class="frame" style="width:150px;height:266px;display:flex;flex-direction:column;align-items:center;gap:6px;padding-top:14px">'
               f'<span style="font:800 10px Nunito">Overlap down the left</span>{pv}<span class="t-note" style="font-size:10px">8 finds the winger</span>'
               '<span class="safe" style="top:12%;left:15%;right:15%;bottom:20%"></span></div></div>')
    ptiles = "".join(f'<div class="ptile{" on" if n == "Vertical 9:16" else ""}"><i style="width:{w}px;height:{h}px"></i>{n}</div>'
                     for n, w, h in (("Vertical 9:16", 14, 24), ("Square 1:1", 21, 21), ("Wide 16:9", 26, 14), ("Image", 21, 18)))
    A(comp("export", "Sheets", "Export sheet · choosing",
           "The export itself playing at the chosen ratio with dashed safe zones, four presets, the switches, the camera for videos, and an honest size before you export.",
           f'<div class="sheet" style="max-width:420px"><span class="grab"></span><div class="sheet-head" style="margin-bottom:16px"><span class="t-title">Export</span>'
           f'<button class="close-btn">{X()}</button></div><div class="row" style="flex-wrap:nowrap;align-items:flex-start;gap:16px">{preview}'
           f'<div class="stack" style="gap:8px;flex:1;min-width:0"><div class="ptiles">{ptiles}</div><div class="toggle-row">Title band<span class="toggle"></span></div>'
           '<div class="toggle-row">Step notes<span class="toggle"></span></div></div></div>'
           f'<div class="row" style="justify-content:space-between;margin-top:12px;flex-wrap:nowrap"><span class="t-headline">Camera</span><div style="width:220px">{segs(["Flat", "Broadcast"], "Broadcast")}</div></div>'
           '<div style="margin-top:24px"><div class="t-headline">Up to 4 MB · 8 s · 1080 × 1920</div><div class="t-caption mut" style="margin-top:2px">Estimate. Plays in WhatsApp and Discord.</div>'
           '<div style="margin-top:12px"><button class="cap-primary">Export video</button></div></div></div>',
           [("Preview", "150 × 266 pt box, radius 12, drawn by ExportFrame (the export's own renderer)"),
            ("Safe zone", "1 pt dashed (4/3) text at 60%; vertical insets 12% top, 15% sides, 20% bottom; others 6%"),
            ("Preset tile", "min 78 pt, radius 16, ratio outline 2 pt with radius 4, caption 12 semibold"),
            ("Copy", "“Up to 4 MB · 8 s · 1080 × 1920”, “Estimate. Plays in WhatsApp and Discord.”; image: “PNG · 708 × 1259”"),
            ("VoiceOver", "“Preview, Vertical 9:16, broadcast camera”"),
            ("IDs", ids("export.preview", "export.preset.vertical", "export.title-band", "export.notes", "export.camera.broadcast", "export.size", "export.start")),
            ("Source", src("Features/Export/ExportSheet.swift", "Features/Export/ExportPreview.swift", "Features/Export/ExportModel.swift"))]))
    A(comp("export-states", "Sheets", "Export sheet · rendering, done, error",
           "An honest frame count with time left while rendering, the real size before sharing, and a way out of an error.",
           '<div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:24px">'
           '<div class="stack" style="gap:4px"><span class="t-headline">Rendering 96 of 240 frames</span><span class="t-caption mut">About 3 seconds left. Keep CenterSpot open until it\'s done.</span>'
           '<div class="pbar-prog" style="margin-top:12px"><b style="width:40%"></b></div><div style="margin-top:20px"><button class="cap-quiet">Cancel</button></div></div>'
           '<div class="stack" style="gap:4px"><span class="t-title">Video ready</span><span class="t-body mut">3.1 MB · 8 s · 1080 × 1920</span>'
           '<div class="stack" style="margin-top:20px"><button class="cap-primary">Share video</button><button class="cap-quiet">Save to Photos</button></div></div>'
           '<div class="stack" style="gap:4px"><span class="t-headline">Couldn\'t make the video. Try again, or export an image.</span>'
           '<div class="stack" style="margin-top:20px"><button class="cap-primary">Try again</button><button class="cap-quiet">Export an image</button></div></div></div>',
           [("Progress bar", "8 pt capsule, surface3 track, accent fill; VoiceOver “Progress, 40 percent”"),
            ("Sizes", "1 MB = 1,000,000 bytes, as Files and WhatsApp count"), ("Photos", "Save to Photos → Saved to Photos, or “Couldn't save. Allow Photos in Settings”"),
            ("IDs", ids("export.progress", "export.progress-bar", "export.cancel", "export.done", "export.done-size", "export.share", "export.save", "export.error", "export.retry")),
            ("Source", src("Features/Export/ExportSheet.swift", "Features/Export/ExportModel.swift"))]))
    W9 = 140
    def frame(w, h, ins, label):
        b = board_svg(min(w * .7, h * .7 / RATIO), step=1, label=label)
        return (f'<figure style="margin:0"><div style="position:relative;width:{w}px;height:{h}px;background:#0B0F14;border:1px solid #27313D;border-radius:8px;'
                f'display:grid;place-items:center;overflow:hidden">{b}<span class="safe" style="top:{ins[0]*100}%;left:{ins[1]*100}%;right:{ins[1]*100}%;bottom:{ins[2]*100}%"></span></div>'
                f'<figcaption class="t-caption mut" style="margin-top:8px">{label}</figcaption></figure>')
    A(comp("frames", "Sheets", "Export frames and safe zones",
           "Three video ratios and their safe zones. On vertical the zone keeps the same margin on both sides (D-82), clear of the platform buttons and captions.",
           '<div class="row" style="gap:24px;align-items:flex-end;flex-wrap:nowrap">' + frame(W9 * 9 / 16, W9, (.12, .15, .2), "Vertical 9:16 · 1080 × 1920") +
           frame(W9, W9, (.06, .06, .06), "Square 1:1") + frame(W9 * 16 / 9, W9, (.06, .06, .06), "Wide 16:9") + "</div>",
           [("Video", "H.264, 30 fps, AVAssetWriter (D-11); target under 8 MB for 15 s at 1080 × 1920"),
            ("Safe zones", "Preview only, never in the file"), ("Source", src("Render/ExportFrame.swift", "Render/ExportLayout.swift", "Features/Export/ExportPreview.swift"))]))
    A(comp("note", "Sheets", "Step note sheet",
           "The coach's handwriting: a note for one step, up to 140 characters, shown in playback and in the clip.",
           f'<div class="sheet" style="max-width:393px"><span class="grab"></span><div class="stack"><div class="sheet-head"><span class="t-title">Step 2 note</span><button class="close-btn">{X()}</button></div>'
           '<div class="t-note" style="background:#1E2630;border-radius:12px;padding:12px;min-height:72px">11 drives inside</div><span class="t-caption mut">16 of 140</span>'
           '<button class="cap-primary">Save note</button></div></div>',
           [("Field", "Kalam 18, 2–4 lines, surface2, radius 12, 12 pt padding; placeholder “What happens in this step?”"),
            ("Count", "Caption 12 muted “16 of 140”"), ("IDs", ids("note.field", "note.count", "note.save", "note.close")),
            ("Source", src("Features/Steps/StepNoteSheet.swift"))]))

    # ---------- Feedback ----------
    A(comp("toast", "Feedback", "Toast",
           "A short message over the bottom of the pitch for 4 seconds, with Undo when it's about an edit.",
           '<div class="stack" style="max-width:361px"><div class="toast">Deleted step 3<button>Undo</button></div><div class="toast">Removed number 7<button>Undo</button></div>'
           '<div class="toast">There\'s already a ball on the board.</div></div>',
           [("Type", "Body 15; Undo body semibold"), ("Fill", "surface3, radius 16, shadow bg 40% / 12 / y 8"), ("Size", "min 52 pt; 16 pt leading"),
            ("Lifetime", "4 s; motion 0.2 s"), ("IDs", ids("toast.message", "toast.undo")), ("Source", src("Features/Board/BoardToast.swift"))]))
    tip_arrow = '<svg class="arr" viewBox="0 0 20 10" aria-hidden="true"><path d="M0 0h20L10 10z" fill="#27313D"/></svg>'
    A(comp("tip", "Feedback", "Tip",
           "Five TipKit tips on the example move, one at a time: Move a player, Every step is a moment, Watch it move, Draw a run, Share the clip. × closes one and the next can come.",
           f'<div class="stack" style="gap:20px;max-width:345px"><div class="tip"><div class="tx"><h5>Move a player</h5><p>Drag any player to where they should be.</p></div>'
           f'<span class="x">{I("close", 20, "ic in-ic")}</span>{tip_arrow}</div><div class="tip"><div class="tx"><h5>Watch it move</h5><p>Press Play to run the move. Pick Flat or Broadcast at the top.</p></div>'
           f'<span class="x">{I("close", 20, "ic in-ic")}</span>{tip_arrow}</div></div>',
           [("Type", "Headline 17 title, body 15 muted message"), ("Fill", "surface3 popover with its arrow"), ("Close", "44 pt, muted ×"),
            ("VoiceOver", "“Close tip”"), ("IDs", ids("tip.close")), ("Rule", "Only a control with a tip due carries the popover"),
            ("Source", src("Features/Onboarding/OnboardingTips.swift", "Features/Onboarding/CenterSpotTipStyle.swift"))]))

    # ---------- Library & welcome ----------
    cards = ""
    for t, n, st in (("Overlap down the left", "5 steps", 0), ("High press from a goal kick", "4 steps", 1), ("Switch of play", "3 steps", 0),
                     ("Corner routine, near post", "2 steps", 1), ("Counter after a turnover", "6 steps", 0), ("Five-a-side diamond", "1 step", 1)):
        th = sideways(160, st)
        cards += f'<div class="card-t"><div class="th">{th}</div><div class="nm">{t}</div><div class="mt">{n}</div></div>'
    A(comp("library", "Library", "Library",
           "The home: the wordmark and the handwritten tagline over a faint chalk pitch, the lime New tactic, then tactics as cards, newest first. Press and hold a card for Rename · Duplicate · Share · Delete.",
           f'<div style="max-width:393px"><div class="lib-head"><div style="flex:1"><div class="lib-w" style="font:800 34px/1.1 Nunito">CenterSpot</div><div class="t-note mut">Draw the move, not just the shape.</div></div>'
           f'<span style="width:44px;height:44px;display:grid;place-items:center">{I("more", 26, "ic bar-ic")}</span></div>'
           f'<div style="margin:24px 0"><button class="cap-primary">{I("plus", 20, "ic in-ic")}New tactic</button></div><div class="t-headline mut" style="margin-bottom:12px">Recent</div>'
           f'<div class="libgrid">{cards}</div><p class="t-caption mut" style="margin-top:24px">Saved on this iPhone. Find them in Files › On My iPhone › CenterSpot.</p></div>',
           [("Wordmark", "Typeface.wordmark: Nunito 34 black (900), the logo's weight"), ("Card", "surface2, radius 16; thumbnail radius 16 − inset; name 13/15 bold, meta 11/12 medium"),
            ("Grid", "Compact: 24 pt margins, cards ≥ 100 pt, 10 pt gaps (3 a row on iPhone). Wide: 32 pt margins, cards ≥ 201 pt, 16 pt gaps, up to 6"),
            ("Empty", "“Your tactics show up here.”"), ("Card menu", "Rename · Duplicate · Share · Delete"),
            ("VoiceOver", "“Overlap down the left, 5 steps”, actions in the rotor"),
            ("IDs", ids("library.title", "library.tagline", "library.more", "launch.new", "library.recent", "library.card.1", "library.recents-hint")),
            ("Source", src("Features/Library/LibraryScreen.swift", "Features/Library/TacticCard.swift", "Features/Library/LibraryGrid.swift", "Features/Launch/LaunchArt.swift"))]))
    A(comp("welcome", "Library", "Welcome page",
           "Three pages before the first board: Draw the move, not just the shape · Press Play. Watch it move · Share it as a 9:16 clip. Centred text, Skip at the top, page dots, Next or Start.",
           f'<div style="max-width:393px;text-align:center"><div style="text-align:right"><button class="textbtn mut" style="color:#93A0AD">Skip</button></div>'
           f'<div style="display:grid;place-items:center;padding:8px 0 24px">{board_svg(210, step=1, label="A pitch showing a five-step move")}'
           f'<div class="strip" style="margin-top:12px">' + "".join(f'<div class="chip{" on" if i == 1 else ""}" style="width:40px;height:48px"><b>{i+1}</b></div>' for i in range(5)) + '</div></div>'
           '<div class="t-large" style="font-size:30px">Draw the move, not just the shape</div><p class="t-body mut" style="margin-top:8px">Place your players, then add steps. Each step is one moment of the move.</p>'
           '<div class="dots" style="margin:16px 0"><i class="on"></i><i></i><i></i></div><button class="cap-primary">Next</button></div>',
           [("Title", "Large title 34 bold, centred"), ("Body", "Body 15 muted, centred"), ("Dots", "Active a 24 × 8 text capsule, others 8 × 8 muted, 8 pt apart (shape, not only colour)"),
            ("Art", "404 pt tall; grows on iPad; pages 2 and 3 in Broadcast"), ("VoiceOver", "Art has its own label (“A pitch showing a five-step move”); dots: “Page 1 of 3”, adjustable"),
            ("IDs", ids("onboarding.skip", "onboarding.art.1", "onboarding.title", "onboarding.body", "onboarding.dots", "onboarding.next")),
            ("Source", src("Features/Onboarding/WelcomeView.swift", "Features/Onboarding/WelcomeArt.swift"))]))

    # ---------- On the pitch ----------
    W = 300
    H = W * RATIO
    A(comp("pitch", "On the pitch", "Pitch",
           "One look everywhere the board is drawn (D-65): near-black with faint stripes and thin light lines. Screen and export share BoardRenderer (D-07).",
           f'<div class="pitch-box"><figure>{board_svg(240, step=0, label="Board at step 1")}<figcaption>Stripes · step 1 of the example move</figcaption></figure>'
           f'<figure><svg class="board" width="240" height="{f(240*RATIO)}" viewBox="0 0 240 {f(240*RATIO)}" aria-hidden="true">{pitch(240, 240*RATIO, stripes=False)}</svg><figcaption>Plain</figcaption></figure></div>',
           [("Colours", "bcPitchA #0E1216, bcPitchB #13181D (10 stripes), lines white 42%"), ("Line width", "1.4 pt at a 345 pt board, scaled"),
            ("Geometry", "105 × 68 m, normalised 0…1, attacking upward (D-05); 11, 7 and 5-a-side"),
            ("VoiceOver", "Every token is an element: “Number 9, striker, edge of the box, step 3”"),
            ("Source", src("Render/PitchDrawing.swift", "Render/BoardRenderer.swift", "Render/BoardGeometry.swift"))]))
    tw = 300
    demo_tokens = [({"kind": "player", "side": "home", "number": 7}, 40, False), ({"kind": "player", "side": "away", "number": 4}, 100, False),
                   ({"kind": "player", "side": "home", "number": 10}, 160, True), ({"kind": "ball"}, 215, False), ({"kind": "cone"}, 262, False)]
    tsvg = f'<svg class="board" width="{tw}" height="64" viewBox="0 0 {tw} 64" role="img" aria-label="Tokens"><rect width="{tw}" height="64" fill="#0E1216"/>'
    tsvg += "".join(token(t, x, 32, 474, selected=s) for t, x, s in demo_tokens) + "</svg>"
    A(comp("tokens", "On the pitch", "Tokens",
           "Us are filled discs, them are rings (D-15): colour is never the only difference. Every disc has a thin dark outline (D-67); the selection is a white chalk ring; the ball sits at its carrier's feet, never over the number.",
           tsvg + '<div class="legend"><span>Our 7</span><span>Their 4</span><span>Selected 10</span><span>Ball</span><span>Cone</span></div>',
           [("Radius", "3.8% of the board's width (13.1 pt on a 345 pt board)"), ("Home", "Kit fill, number in kit ink, heavy Nunito at 1.05 r"),
            ("Away", "Dark centre (bg 85%) at 0.9 r, kit ring 0.24 r, white number"), ("Outline", "discOutline #0B0F14, 0.1 r, just outside"),
            ("Selection", "Text ring at 1.45 r, 0.14 r wide; a slight lift on screen only"), ("Ball", "White, 0.42 r, dark 0.14 r outline; offset 0.95 r when carried"),
            ("Cone", "dribble yellow triangle, dark edge"), ("Hit target", "44 pt round each token"), ("Source", src("Render/TokenDrawing.swift"))]))
    aw, ah = 320, 120
    arrows_demo = [{"kind": k, "points": [{"x": .08, "y": y}, {"x": .9, "y": y}]} for k, y in (("run", .82), ("pass", .6), ("dribble", .38), ("press", .16))]
    asvg = f'<svg class="board" width="{aw}" height="{ah}" viewBox="0 0 {aw} {ah}" role="img" aria-label="Arrow kinds"><rect width="{aw}" height="{ah}" fill="#0E1216"/>'
    asvg += "".join(arrow(a, aw, ah, {}) for a in arrows_demo) + "</svg>"
    A(comp("arrows", "On the pitch", "Arrows",
           "Four kinds that move players, told apart by line style as well as colour: run solid, pass dashed, dribble wavy, press chevrons. An arrow that ends on a player stops short so its head shows.",
           asvg + '<div class="legend"><span>Run · white solid</span><span>Pass · lime dashed 7/5</span><span>Dribble · yellow zigzag</span><span>Press · coral chevrons</span></div>',
           [("Width", "2.6 pt at 345 pt, round caps and joins"), ("Head", "9 pt, ±0.45 rad"), ("Pass dash", "7 / 5"), ("Dribble", "9 pt teeth, 3.5 pt amplitude, flat at the end"),
            ("Press", "Two 8 pt chevrons, 6 pt apart"), ("Shape", "Straight or Curved (D-72), bend by the middle dot"),
            ("Source", src("Render/ArrowDrawing.swift", "Engine/ShapedPath.swift"))]))
    pos = STEPS[2]["positions"]
    mk = {"zones": [{"x": .05, "y": .55, "w": .4, "h": .25}], "heat": [{"x": .7, "y": .62, "r": .14}], "lines": [{"ids": ["h5", "h4", "h2"]}], "rings": ["h9"]}
    A(comp("marks", "On the pitch", "Marks",
           "Three marks that explain, lying on the grass under every token: a see-through zone, a line that joins a unit, and glow (rings that follow a player, heat that stays on the grass).",
           board_svg(300, step=2, arrows=[], m=mk, label="Zone, heat, shape line and glow rings"),
           [("Zone", "lime 13% fill, 72% edge, 1.4 pt; corner handles 6 pt when selected"), ("Line", "kit colour, 2.2 pt, 90%"),
            ("Glow rings", "kit tint 18% under the disc; rings at 1.3 / 1.85 / 2.45 r at 95 / 60 / 30%"), ("Heat", "radial #FFB547 → #FF5A2E, squashed to 0.8"),
            ("Order", "zones, heat, lines, rings, then arrows and tokens"), ("Source", src("Render/MarkDrawing.swift", "Model/Zone.swift", "Model/Glow.swift"))]))
    plane = board_svg(420, step=1, label="The move in the Broadcast camera")
    A(comp("broadcast", "On the pitch", "Broadcast camera",
           "Play and export tilt the pitch and follow the ball, like a match on TV (D-76). Editing stays flat. Reduce Motion holds a still framing of the whole move.",
           f'<div class="tilt"><div class="plane">{plane}</div></div>',
           [("Camera", "Follows the ball; with no ball, the centre of the players moving in that step"), ("Motion", "camera 0.48 s; Reduce Motion: crossfade 0.3 s, no panning"),
            ("Discs", "Lie flat on the grass (projected), numbers stay upright"), ("Here", "A CSS illustration; the app projects in BroadcastCamera"),
            ("Source", src("Render/BroadcastCamera.swift", "Engine/CameraTrack.swift", "Render/BoardRenderer+Broadcast.swift"))]))
    return "".join(out)


INDEX = [
    ("Controls", [("primary", "Primary capsule", "The one main action on a screen or sheet"), ("quiet", "Quiet capsule", "A second action, or a destructive one"),
                  ("rowcap", "Row capsule", "Small actions in a row under the pitch"), ("sheethead", "Sheet header", "Every sheet's title and close"),
                  ("segments", "Capsule segments", "Two to three exclusive choices"), ("fields", "Field, label, option", "Typing a name or number, picking from a list"),
                  ("toggle", "Switch", "On or off for an export detail")]),
    ("Board", [("toolbar", "Board toolbar", "The five things you do to a board"), ("addmenu", "Add menu", "Putting a player, ball or cone on"),
               ("nav-edit", "Nav bar · editing", "Back, title menu, undo"), ("titlemenu", "Title menu", "Share, rename, pitch"),
               ("nav-play", "Nav bar · playing", "Camera choice and Done"), ("nav-draw", "Nav bar · drawing", "Cancel or finish drawing"),
               ("context", "Context row", "What's selected and what you can do to it"), ("strip", "Steps strip", "Moving between steps on iPhone"),
               ("stepslist", "Steps list", "Steps with notes on iPad landscape"), ("colcard", "Column card", "The iPad column's row"),
               ("playback", "Playback bar", "Watching the move"), ("drawpanel", "Draw panel", "Picking what to draw")]),
    ("Sheets", [("playersheet", "Player sheet", "Naming and placing a player"), ("formation", "Formation picker", "Starting from a shape"),
                ("alerts", "Confirmations", "Before something that can't be taken back"), ("export", "Export sheet", "Making the clip or image"),
                ("export-states", "Export states", "Rendering, done, error"), ("frames", "Export frames", "Ratios and safe zones"),
                ("note", "Step note sheet", "Writing what happens in a step"),
                ("scenario-sheet", "Scenarios sheet", "Starting from a situation, attacking or defending"),
                ("scenario-tile", "Scenario tile", "Seeing the board a scenario sets up")]),
    ("Feedback", [("toast", "Toast", "After an edit worth undoing"), ("tip", "Tip", "Teaching the five first moves")]),
    ("Library", [("library", "Library", "Your tactics"), ("welcome", "Welcome page", "The first launch")]),
    ("On the pitch", [("pitch", "Pitch", "The grass and its lines"), ("tokens", "Tokens", "Players, ball, cone"), ("arrows", "Arrows", "Runs, passes, dribbles, presses"),
                      ("marks", "Marks", "Zones, lines, glow, heat"), ("broadcast", "Broadcast camera", "Play and export")]),
]


def which():
    rows = ""
    for g, items in INDEX:
        for cid, name, use in items:
            rows += f'<tr><td class="muted">{g}</td><td><a href="#c-{cid}">{name}</a></td><td>{use}</td></tr>'
    return f'<div class="scroll-x"><table class="which"><thead><tr><th>Group</th><th>Component</th><th>Use it for</th></tr></thead><tbody>{rows}</tbody></table></div>'
