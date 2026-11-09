"""Builds the CenterSpot design system: ../index.html and ../downloads/. Values come from the app at git 89a0eb9
(Design/Tokens.swift and the views), read from this repo (mockup/, presets/). Run: python3 design-system/src/build.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import icons, logo, components, scenarios
from icons import svg as I
from board import board_svg, KITS, token, RATIO

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..")
DL = os.path.join(OUT, "downloads")
os.makedirs(os.path.join(DL, "icons"), exist_ok=True)
os.makedirs(os.path.join(DL, "logo"), exist_ok=True)

# ---------------- Tokens (Design/Tokens.swift) ----------------
COLOURS = [  # name, hex, alpha, role
    ("bg", "#0B0F14", 1, "App background; ink on lime; disc outline"),
    ("surface", "#151B23", 1, "Toolbar, sheets, iPad column cards"),
    ("surface2", "#1E2630", 1, "Controls: segment tracks, chips, fields, tiles, row capsules"),
    ("surface3", "#27313D", 1, "Picked segment, toast, tip"),
    ("hairline", "#2A3440", 1, "Rare dividers"),
    ("text", "#F2F5F7", 1, "Primary text, icons, the selection ring"),
    ("muted", "#93A0AD", 1, "Secondary text, idle icons, dashed add outlines"),
    ("accent", "#C6FF3D", 1, "The one lead per screen: Play, current step, primary capsule, scrubber fill"),
    ("accentInk", "#0B0F14", 1, "Text and icons on accent"),
    ("danger", "#FF6B6B", 1, "Delete player"),
    ("chalk", "#FFFFFF", .55, "Formation diagrams"),
]
BOARD_COLOURS = [
    ("bcPitchA", "#0E1216", 1, "Pitch, stripe A"), ("bcPitchB", "#13181D", 1, "Pitch, stripe B"), ("bcLine", "#FFFFFF", .42, "Pitch lines"),
    ("zoneFill", "#C6FF3D", .13, "Zone fill (kit colour at 13%)"), ("zoneStroke", "#C6FF3D", .72, "Zone edge"),
    ("heat", "#FF5A2E", 1, "Heat"), ("heatCore", "#FFB547", 1, "Heat's hot centre"),
    ("discOutline", "#0B0F14", 1, "Thin outline round every disc (D-67)"), ("awayInner", "#0B0F14", 1, "Their ring's dark centre, solid so nothing shows through (D-93)"),
    ("awayInk", "#FFFFFF", 1, "Their numbers"), ("ball", "#FFFFFF", 1, "Ball"),
    ("run", "#FFFFFF", 1, "Run arrow"), ("pass", "#C6FF3D", 1, "Pass arrow"), ("dribble", "#FFD84A", 1, "Dribble arrow, cones"), ("press", "#FF6B4A", 1, "Press arrow"),
]
TYPE = [  # token, family, size, weight, dynamic type, sample, use
    ("largeTitle", "Nunito", 34, 700, ".largeTitle", "Draw the move, not just the shape", "Welcome titles"),
    ("wordmark", "Nunito", 34, 900, ".largeTitle", "CenterSpot", "The library's name; the one 900 word, as in the logo"),
    ("title", "Nunito", 22, 700, ".title2", "Formation", "Sheet titles, Video ready, step numbers in rows"),
    ("headline", "Nunito", 17, 700, ".headline", "Up to 4 MB · 8 s · 1080 × 1920", "Nav titles, buttons, tip titles, step chip numbers"),
    ("body", "Nunito", 15, 500, ".body", "Players run from step to step, and the Broadcast camera follows the ball.", "Reading text, fields, toasts; semibold 600 on segments and tiles"),
    ("caption", "Nunito", 12, 500, ".caption", "Step 1 of 5 · 1.2 s", "Toolbar labels, row capsules (600), context row, help lines"),
    ("note", "Kalam", 18, 400, ".body", "11 drives inside", "Step notes, hints, the tagline: the coach's handwriting"),
    ("barIcon", "Nunito", 22, 500, ".title2", None, "Icons in the toolbar, nav and playback bars"),
    ("inlineIcon", "Nunito", 17, 500, ".headline", None, "×, ✓, + next to text or alone in a small button"),
    ("number(size:)", "Nunito", "fixed", 800, "none (scales with the board)", "7", "Shirt numbers on the pitch: 1.05 × disc radius"),
]
SPACE = [("s1", 4), ("s2", 8), ("s3", 12), ("s4", 16), ("s5", 24), ("s6", 32)]
RADIUS = [("item", 12, "Fields, options, step chips and rows"), ("tile", 16, "Formation and kind tiles, cards, toast, column cards"),
          ("sheet", 20, "Sheets and the iPad column's tool card"), ("panel", 24, "The draw panel"), ("capsule", 999, "Buttons, segments, tags (Capsule())")]
SIZES = [("touch", "44", "Minimum hit target, segments, close buttons, rows"), ("capsule", "52", "Primary and quiet capsules"),
         ("field", "48", "Text fields and role options"), ("stepChip", "48 × 58", "Step chips"), ("playDisc", "48", "Play and Pause disc"),
         ("toolbarHeight", "82", "Board toolbar and playback controls"), ("toast", "52", "Toast height"), ("liveStroke", "3", "The line under the finger while drawing"),
         ("scrubberBar", "6", "Scrubber bar thickness"), ("scrubberGap", "6", "Gap between scrubber bars"), ("kindTile", "50", "Draw tool tiles (64 in the iPad column)"),
         ("navBarItems", "208", "Nav bar width kept clear of the title")]
MOTION = [("select", .15, "Selecting a token or tile"), ("step", .22, "Going to a step; the chip pulse"), ("sheet", .32, "Sheets; welcome page turns"),
          ("toast", .2, "Toast in and out (stays 4 s)"), ("camera", .48, "The Broadcast camera's tilt"), ("crossfade", .3, "Reduce Motion's replacement")]


def lum(hx):
    c = [int(hx[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [v / 12.92 if v <= .03928 else ((v + .055) / 1.055) ** 2.4 for v in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + .05) / (lb + .05)


def rgba(hx, a):
    if a == 1:
        return hx
    return f"rgba({int(hx[1:3], 16)},{int(hx[3:5], 16)},{int(hx[5:7], 16)},{a})"


def swatches(rows):
    out = '<div class="swatches">'
    for n, hx, a, role in rows:
        check = " check" if a < 1 else ""
        out += (f'<div class="sw"><div class="swc{check}"><i style="background:{rgba(hx, a)}"></i></div><div class="meta"><b>{n}</b>'
                f'<code>{hx}{"" if a == 1 else f" · {int(a*100)}%"}</code><p>{role}</p></div></div>')
    return out + "</div>"


def matrix():
    fgs = [("text", "#F2F5F7"), ("muted", "#93A0AD"), ("accent", "#C6FF3D"), ("danger", "#FF6B6B"), ("accentInk", "#0B0F14")]
    bgs = [("bg", "#0B0F14"), ("surface", "#151B23"), ("surface2", "#1E2630"), ("surface3", "#27313D"), ("accent", "#C6FF3D")]
    head = "".join(f"<th>on {n}<br><code>{h}</code></th>" for n, h in bgs)
    body = ""
    for fn, fh in fgs:
        body += f'<tr><th class="rowh">{fn} <code>{fh}</code></th>'
        for bn, bh in bgs:
            if fh == bh:
                body += '<td class="muted">—</td>'
                continue
            r = ratio(fh, bh)
            grade = "AAA" if r >= 7 else "AA" if r >= 4.5 else "AA large" if r >= 3 else "Fails"
            body += f'<td><span class="s" style="background:{bh};color:{fh};border:1px solid rgba(127,127,127,.25)">{r:.2f}</span><small>{grade}</small></td>'
        body += "</tr>"
    return f'<div class="scroll-x"><table class="matrix"><thead><tr><th class="rowh">Text</th>{head}</tr></thead><tbody>{body}</tbody></table></div>'


def kits():
    out = '<div class="kits">'
    for name, (fill, ink, outline) in KITS.items():
        disc = f'<svg width="120" height="40" viewBox="0 0 120 40" aria-hidden="true">{token({"kind": "player", "side": "home", "number": 7}, 36, 20, 400, kit_home=name)}{token({"kind": "player", "side": "away", "number": 4}, 84, 20, 400, kit_away=name)}</svg>'
        out += f'<div class="kit"><div class="discs">{disc}</div><b>{name}</b><code>{fill} · ink {ink}{" · edge " + outline if outline else ""}</code></div>'
    return out + "</div>"


def type_rows():
    out = ""
    for tok, fam, size, wt, dyn, sample, use in TYPE:
        fs = 34 if size == "fixed" else size
        if sample is None:
            sample_html = f'<span style="display:flex;gap:16px;align-items:center">{I("play", fs + 4, "ic")}{I("undo", fs + 4, "ic")}{I("close", fs + 4, "ic")}</span>'
        elif tok.startswith("number"):
            sample_html = f'<svg width="60" height="60" viewBox="0 0 60 60" aria-label="Shirt number 7" role="img">{token({"kind": "player", "side": "home", "number": 7}, 30, 30, 640)}</svg>'
        else:
            sample_html = f'<span style="font:{wt} {fs}px/1.25 {fam}{", cursive" if fam == "Kalam" else ""}">{sample}</span>'
        out += (f'<div class="type-row"><div class="tspec"><b>{tok}</b>{fam} {size}{" pt" if size != "fixed" else ""} · {wt}<br>Dynamic Type: {dyn}<br>{use}</div>'
                f'<div>{sample_html}</div></div>')
    return out


def curve(name, d):
    # cubic-bezier(0.2, 0, 0, 1) in a 160 × 100 box
    return (f'<div class="card"><b style="font-size:14px">{name}</b> <span class="muted mono">{int(d*1000)} ms</span><div class="mo-track"><span class="mo-dot" '
            f'style="transition-duration:{d}s;transition-timing-function:cubic-bezier(.2,0,0,1)"></span></div><p class="muted" style="font-size:13px">{MOTION_USE[name]}</p></div>')


MOTION_USE = {n: u for n, _, u in MOTION}


def icon_cells():
    out = '<div class="icon-grid">'
    for n, (label, sf, use, _) in icons.ICONS.items():
        out += (f'<div class="icon-cell"><div class="sizes-row">{I(n, 16, "ic")}{I(n, 24, "ic")}{I(n, 32, "ic", label)}</div><b>{label}</b>'
                f'<span class="from">cs-{n} · {"was " + sf if not sf.startswith("(") else sf.strip("()")}</span><span class="use">{use}</span></div>')
    out += "</div>"
    tools = '<div class="icon-grid" style="margin-top:16px">'
    for n, (label, help_, _) in icons.TOOLS.items():
        sz = lambda s: f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" aria-hidden="true"><use href="#t-{n}"/></svg>'
        tools += (f'<div class="icon-cell tool-cell"><div class="sizes-row">{sz(16)}{sz(24)}{sz(32)}</div><b>{label}</b>'
                  f'<span class="from">cs-tool-{n}</span><span class="use">{help_}</span></div>')
    return out, tools + "</div>"


def keyline():
    grid = "".join(f'<line x1="{i}" y1="0" x2="{i}" y2="24" stroke="rgba(255,255,255,{.18 if i % 4 == 0 else .07})" stroke-width=".06"/>'
                   f'<line x1="0" y1="{i}" x2="24" y2="{i}" stroke="rgba(255,255,255,{.18 if i % 4 == 0 else .07})" stroke-width=".06"/>' for i in range(25))
    live = '<rect x="2" y="2" width="20" height="20" fill="none" stroke="#C6FF3D" stroke-width=".08" stroke-dasharray=".3 .3"/>'
    shapes = ('<circle cx="12" cy="12" r="10" fill="none" stroke="#FF6B4A" stroke-width=".08"/><rect x="3" y="3" width="18" height="18" rx="2" fill="none" stroke="#5BC8FF" stroke-width=".08"/>'
              '<rect x="5" y="2" width="14" height="20" rx="2" fill="none" stroke="#FFD84A" stroke-width=".08"/>')
    def fig(name, cap):
        return (f'<figure><div class="k"><svg viewBox="0 0 24 24" width="100%" style="display:block">{grid}<g color="#4A5868"><use href="#i-{name}"/></g>{live}{shapes}'
                f'</svg></div><figcaption>{cap}</figcaption></figure>')
    return ('<div class="keyline">' + fig("formation", "Formation: a 16 × 19 pitch, five dots") +
            fig("export", "Export: the 9:16 frame on the tall keyline") + fig("add", "Add: the circle keyline, 9 units") + "</div>")


def write_downloads():
    tokens = {
        "name": "CenterSpot", "source": "CenterSpot/Design/Tokens.swift",
        "colour": {n: (hx if a == 1 else {"hex": hx, "alpha": a}) for n, hx, a, _ in COLOURS + BOARD_COLOURS},
        "kit": {n: {"fill": fl, "ink": ik, **({"outline": o} if o else {})} for n, (fl, ik, o) in KITS.items()},
        "type": {t: {"family": fam, "size": size, "weight": wt, "dynamicType": dyn} for t, fam, size, wt, dyn, _, _ in TYPE},
        "space": {n: v for n, v in SPACE},
        "radius": {n: v for n, v, _ in RADIUS},
        "size": {n: v for n, v, _ in SIZES},
        "motion": {"curve": [0.2, 0, 0, 1], **{n: d for n, d, _ in MOTION}, "toastLifetime": 4},
        "board": {"tokenRadiusRatio": 0.038, "referenceWidth": 345, "hitRadius": 22, "arrowWidth": 2.6, "arrowHead": 9, "passDash": [7, 5]},
    }
    json.dump(tokens, open(os.path.join(DL, "tokens.json"), "w"), indent=2)
    open(os.path.join(DL, "icons", "centerspot-icons.svg"), "w").write(icons.sprite_file())
    for n in icons.ICONS:
        open(os.path.join(DL, "icons", f"{n}.svg"), "w").write(icons.standalone(n))
    L = os.path.join(DL, "logo")
    open(os.path.join(L, "mark.svg"), "w").write(logo.standalone_mark())
    open(os.path.join(L, "mark-small.svg"), "w").write(logo.standalone_mark(small=True))
    open(os.path.join(L, "mark-on-dark.svg"), "w").write(logo.standalone_mark(bg="#0B0F14"))
    open(os.path.join(L, "mark-paper.svg"), "w").write(logo.standalone_mark(fg="#0B0F14", spot="#C6FF3D", key="#0B0F14", bg="#F2F5F7"))
    open(os.path.join(L, "mark-lime.svg"), "w").write(logo.standalone_mark(fg="#0B0F14", spot="#0B0F14", key="#C6FF3D", bg="#C6FF3D"))
    open(os.path.join(L, "lockup-horizontal.svg"), "w").write(logo.wordmark_svg())
    open(os.path.join(L, "lockup-stacked.svg"), "w").write(logo.wordmark_svg(stacked=True))
    open(os.path.join(L, "app-icon-1024.svg"), "w").write(logo.app_icon_svg())
    open(os.path.join(L, "app-icon-lime-1024.svg"), "w").write(logo.app_icon_svg(bg="#C6FF3D", fg="#0B0F14", spot="#0B0F14", key="#C6FF3D"))


def main():
    write_downloads()
    css = open(os.path.join(HERE, "page.css")).read()
    arch_defs, arch_html = logo.archive()
    icon_html, tool_html = icon_cells()
    mk = logo.mark

    nav = [("overview", "00", "Overview", []), ("logo", "01", "Logo", [("logo-story", "Story"), ("logo-build", "Construction"), ("logo-sizes", "Sizes and space"),
           ("logo-lockups", "Lockups"), ("logo-colour", "Colourways"), ("logo-misuse", "Misuse"), ("logo-icon", "App icon"), ("logo-archive", "Archive")]),
           ("colour", "02", "Colour", [("colour-app", "Interface"), ("colour-board", "Board"), ("colour-kits", "Kits"), ("colour-contrast", "Contrast")]),
           ("type", "03", "Typography", []), ("space", "04", "Space and shape", []), ("motion", "05", "Motion", []),
           ("icons", "06", "Icons", [("icons-grid", "Grid"), ("icons-set", "Interface set"), ("icons-tools", "Draw tools")]),
           ("components", "07", "Components", [("which", "Which component?")] + [(f"c-{items[0][0]}", g) for g, items in components.INDEX]),
           ("scenarios", "08", "Scenarios", [("c-scenario-sheet", "Sheet"), ("c-scenario-tile", "Tile"), ("scn-catalogue", "Catalogue"),
            ("scn-motion", "Moves"), ("scn-copy", "Copy"), ("scn-live-sub", "Live example")]),
           ("voice", "09", "Voice and tone", []), ("a11y", "10", "Accessibility", []), ("downloads", "11", "Downloads", [])]
    nav_html = "<ol>" + "".join(
        f'<li><a href="#{i}"><span class="n">{n}</span>{t}</a>' + ("<ol>" + "".join(f'<li><a href="#{a}">{b}</a></li>' for a, b in subs) + "</ol>" if subs else "") + "</li>"
        for i, n, t, subs in nav) + "</ol>"

    def head(i, n, t, lead):
        # The signature: each section is a step, numbered on a step chip like the app's strip
        return f'<div class="sec-head"><span class="sec-num" aria-hidden="true">{int(n)}</span><h2>{t}</h2><p>{lead}</p></div>'

    hero_board = board_svg(280, step=0, label="The example move, Overlap down the left, at step 1")

    overview = f'''<section class="sec" id="overview">
<div class="hero"><div><span class="kicker">Design system · v1 · 9 Nov 2026</span><h1>CenterSpot</h1><p class="tag">Draw the move, not just the shape.</p>
<p class="intro">An iPhone and iPad app that turns a formation into a step-by-step animated move and exports it as a vertical video, an image or a <code>.tactic</code> file. This page is the system it is built from: the mark, the tokens, the icons, every component and the words.</p>
<dl class="facts"><dt>Built with</dt><dd>Swift 6 and SwiftUI, iOS and iPadOS 26</dd><dt>Renderer</dt><dd>One, for the screen and the export</dd><dt>Theme</dt><dd>Dark only</dd><dt>Source</dt><dd><code>CenterSpot/Design/Tokens.swift</code></dd></dl></div>
<div class="hero-art">{hero_board}</div></div>
<div class="principles">
<div><h3>The pitch is the hero</h3><p>Chrome stays quiet so the board carries the colour. One lime lead per screen (D-80).</p></div>
<div><h3>Never colour alone</h3><p>Us filled, them rings. Runs solid, passes dashed, dribbles wavy (D-15).</p></div>
<div><h3>What plays is what exports</h3><p>One renderer and one timeline for the screen, the preview and the file (D-06, D-07).</p></div>
<div><h3>A coach's voice</h3><p>Plain football words. Handwriting only for what a coach would write on the board.</p></div>
</div></section>'''

    ladder = "".join(f'<figure>{mk(s)}<figcaption>{s}{" · small" if s <= 20 else ""}</figcaption></figure>' for s in (16, 20, 24, 32, 48, 64, 128))
    construct = f'''<svg viewBox="-42 26 184 62" role="img" aria-label="The mark on its 100-unit grid">
<rect x="-42" y="26" width="184" height="62" fill="#0B0F14"/>
{"".join(f'<line x1="{i}" y1="30" x2="{i}" y2="84" stroke="rgba(255,255,255,{.16 if i % 10 == 0 else .05})" stroke-width=".15"/>' for i in range(0, 101, 5))}
{"".join(f'<line x1="0" y1="{i}" x2="100" y2="{i}" stroke="rgba(255,255,255,{.16 if i % 10 == 0 else .05})" stroke-width=".15"/>' for i in range(30, 86, 5))}
<g color="#F2F5F7" opacity=".9"><use href="#cs-mark" width="100" height="100"/></g>
<g fill="none" stroke-width=".3" stroke-dasharray="1 .7">
<ellipse cx="50" cy="56" rx="33" ry="17" stroke="#FF6B4A"/><ellipse cx="50" cy="53.5" rx="26" ry="10.5" stroke="#5BC8FF"/>
<ellipse cx="50" cy="55" rx="9" ry="5.5" stroke="#FFD84A"/><line x1="8" y1="55" x2="92" y2="55" stroke="#FFD84A"/></g>
<g stroke="#93A0AD" stroke-width=".2"><path d="M83 44 L104 38"/><path d="M24 52 L-4 44"/><path d="M50 39 V33"/><path d="M50 73 V80"/><path d="M92 55 H104"/><path d="M59 55 L66 76"/><path d="M17 56 L-4 60"/></g>
<g font-family="ui-monospace, Menlo, monospace" font-size="2.4" fill="#93A0AD">
<text x="105" y="37">outer ellipse 33 × 17</text><text x="105" y="40">centre 50, 56</text>
<text x="-40" y="43">cut ellipse 26 × 10.5</text><text x="-40" y="46">centre 50, 53.5</text>
<text x="52" y="33">far side 4</text><text x="52" y="81">near side 9</text><text x="-40" y="61">sides 7</text>
<text x="105" y="56">line 8 → 92, 6 wide</text><text x="67" y="78">spot 18 × 11 at 50, 55</text></g>
</svg>'''

    logo_sec = f'''<section class="sec" id="logo">{head("logo", "01", "Logo", "The centre circle as the Broadcast camera sees it. The lime dot in the middle is the centre spot: the mark says the name.")}
<div class="sub" id="logo-story"><h3>Story</h3><p class="lead">Every move starts at the centre spot. The mark is the halfway line and centre circle, tilted the way CenterSpot's Broadcast camera tilts the pitch, with the near side drawn thicker than the far side, as perspective draws it. The spot is lime, the colour of our side.</p>
<div class="grid g2"><div class="logo-stage dark" style="min-height:340px"><div class="lockup-h" style="color:#F2F5F7">{mk(120, label="CenterSpot")}<span class="w">CenterSpot</span></div></div>
<div class="grid" style="gap:12px"><div class="card"><h4>Halfway line</h4><p>Runs edge to edge, like the line on a pitch: the board is split, the move goes forward.</p></div>
<div class="card"><h4>Tilted circle</h4><p>The Broadcast camera's view, the app's own look. Far side 4 units, near side 9.</p></div>
<div class="card"><h4>Centre spot</h4><p>The only colour. Lime on dark, lime with an ink keyline on paper, ink cut out of a lime tile.</p></div></div></div></div>

<div class="sub" id="logo-build"><h3>Construction</h3><p class="lead">Drawn on a 100-unit grid. Two ellipses make the ring: the outer one, and an inner cut raised 2.5 units so the far side thins to 4 and the near side thickens to 9.</p>
<div class="grid" style="gap:20px"><div class="construct" style="max-width:920px;margin:0">{construct}</div>
<div class="scroll-x"><table class="sizes"><thead><tr><th>Part</th><th>Geometry (100-unit grid)</th></tr></thead><tbody>
<tr><td>Halfway line</td><td><code>M8 55 H92</code>, 6 wide, round caps</td></tr>
<tr><td>Ring, outer</td><td>ellipse centre 50, 56 · radii 33 × 17</td></tr>
<tr><td>Ring, cut</td><td>ellipse centre 50, 53.5 · radii 26 × 10.5 (a mask)</td></tr>
<tr><td>Ring thickness</td><td>far 4 · sides 7 · near 9</td></tr>
<tr><td>Centre spot</td><td>ellipse centre 50, 55 · radii 9 × 5.5 · accent <code>#C6FF3D</code></td></tr>
<tr><td>Bounding box</td><td>x 5 → 95 · y 39 → 73</td></tr>
<tr><td>Small cut (≤ 20 px)</td><td>line 8 wide · cut 24 × 9 at 50, 54 · spot 10 × 6.5</td></tr>
</tbody></table></div></div></div>

<div class="sub" id="logo-sizes"><h3>Sizes and clear space</h3><p class="lead">At 20 px and below, use the small drawing: a heavier line and far side, so nothing falls under a pixel. Keep clear space of one spot width (18 units) on every side; nothing else enters it.</p>
<div class="logo-stage dark" style="min-height:0"><div class="ladder" style="color:#F2F5F7">{ladder}</div></div>
<div class="grid g2" style="margin-top:16px"><div class="logo-stage dark" style="min-height:240px"><svg width="240" height="240" viewBox="-18 21 136 70" aria-label="Clear space" role="img">
<rect x="-18" y="21" width="136" height="70" fill="none" stroke="#C6FF3D" stroke-width=".4" stroke-dasharray="1.5 1"/><rect x="5" y="39" width="90" height="34" fill="none" stroke="#93A0AD" stroke-width=".3"/>
<g color="#F2F5F7"><use href="#cs-mark" width="100" height="100"/></g><ellipse cx="-9" cy="56" rx="9" ry="5.5" fill="none" stroke="#C6FF3D" stroke-width=".4"/>
<ellipse cx="109" cy="56" rx="9" ry="5.5" fill="none" stroke="#C6FF3D" stroke-width=".4"/></svg></div>
<div class="card"><h4>Minimums</h4><p>Mark alone: 16 px (small drawing). Horizontal lockup: 96 px wide. Stacked lockup: 64 px wide. App icon: every size iOS asks for, from the 1024 master.</p>
<h4 style="margin-top:14px">Clear space</h4><p>One spot width (18 units at the mark's scale) round the bounding box. In a lockup, the gap between mark and word is a quarter of the mark's width.</p></div></div></div>

<div class="sub" id="logo-lockups"><h3>Lockups</h3><p class="lead">The word is Nunito 900, CenterSpot in one word with two capitals. The mark sits on the word's middle, not its baseline.</p>
<div class="grid g3"><div class="logo-stage dark"><div class="lockup-h">{mk(64)}<span class="w" style="font-size:36px">CenterSpot</span></div></div>
<div class="logo-stage dark"><div class="lockup-v">{mk(96)}<span class="w">CenterSpot</span></div></div>
<div class="logo-stage dark">{mk(120, label="CenterSpot mark")}</div></div>
<div class="grid g3" style="margin-top:8px"><p class="muted" style="font-size:13px">Horizontal: nav, README, the clip's end card</p><p class="muted" style="font-size:13px">Stacked: splash, square spaces</p><p class="muted" style="font-size:13px">Mark: app icon, favicon, avatars</p></div></div>

<div class="sub" id="logo-colour"><h3>Colourways</h3><p class="lead">Three, and only three. The spot keeps its lime wherever the background lets it read.</p>
<div class="grid g3"><div class="logo-stage dark"><div class="lockup-h">{mk(56)}<span class="w" style="font-size:30px">CenterSpot</span></div></div>
<div class="logo-stage paper" style="--key:#0B0F14"><div class="lockup-h">{mk(56)}<span class="w" style="font-size:30px">CenterSpot</span></div></div>
<div class="logo-stage limebg" style="--spot:#0B0F14;--key:#C6FF3D"><div class="lockup-h">{mk(56)}<span class="w" style="font-size:30px">CenterSpot</span></div></div></div>
<div class="grid g3" style="margin-top:8px"><p class="muted" style="font-size:13px">Dark: #F2F5F7 on #0B0F14, lime spot. The default.</p><p class="muted" style="font-size:13px">Paper: ink on #F2F5F7, lime spot with an ink keyline (lime alone is 1.1:1 on paper).</p><p class="muted" style="font-size:13px">Lime: ink on #C6FF3D, an ink spot cut free of the line by a lime keyline.</p></div></div>

<div class="sub" id="logo-misuse"><h3>Misuse</h3><p class="lead">The tilt is the idea; keep it, and keep everything else plain.</p>
<div class="grid g4 misuse">
<figure><div class="art"><svg width="110" height="110" viewBox="0 0 100 100" style="transform:scaleX(1.5)" aria-hidden="true"><use href="#cs-mark"/></svg></div><figcaption>{I("close", 16, "ic")}<span>Don't stretch or squash it</span></figcaption></figure>
<figure><div class="art"><svg width="110" height="110" viewBox="0 0 100 100" style="transform:rotate(-20deg)" aria-hidden="true"><use href="#cs-mark"/></svg></div><figcaption>{I("close", 16, "ic")}<span>Don't rotate it</span></figcaption></figure>
<figure><div class="art"><svg width="110" height="110" viewBox="0 0 100 100" aria-hidden="true"><path d="M8 50H92" stroke="#F2F5F7" stroke-width="6" stroke-linecap="round"/><circle cx="50" cy="50" r="24" fill="none" stroke="#F2F5F7" stroke-width="6"/><circle cx="50" cy="50" r="7" fill="#C6FF3D"/></svg></div><figcaption>{I("close", 16, "ic")}<span>Don't flatten the circle: the tilt is the mark</span></figcaption></figure>
<figure><div class="art" style="--spot:#FF6B4A"><svg width="110" height="110" viewBox="0 0 100 100" aria-hidden="true"><use href="#cs-mark"/></svg></div><figcaption>{I("close", 16, "ic")}<span>Don't recolour the spot (coral is their side)</span></figcaption></figure>
<figure><div class="art"><svg width="110" height="110" viewBox="0 0 100 100" style="filter:drop-shadow(0 0 8px #C6FF3D)" aria-hidden="true"><use href="#cs-mark"/></svg></div><figcaption>{I("close", 16, "ic")}<span>No glows, shadows or gradients</span></figcaption></figure>
<figure><div class="art"><div class="lockup-h">{mk(40)}<span style="font:italic 300 22px Georgia, serif">CenterSpot</span></div></div><figcaption>{I("close", 16, "ic")}<span>Don't set the word in another face</span></figcaption></figure>
<figure><div class="art"><div class="lockup-h">{mk(40)}<span style="font:900 22px Nunito">Center Spot</span></div></div><figcaption>{I("close", 16, "ic")}<span>One word, two capitals: CenterSpot</span></figcaption></figure>
<figure><div class="art" style="background:repeating-linear-gradient(45deg,#2BD67B 0 12px,#FFD84A 12px 24px)"><svg width="110" height="110" viewBox="0 0 100 100" aria-hidden="true"><use href="#cs-mark"/></svg></div><figcaption>{I("close", 16, "ic")}<span>Not on busy backgrounds</span></figcaption></figure>
</div></div>

<div class="sub" id="logo-icon"><h3>App icon</h3><p class="lead">The mark at 72% of the tile, centred on its optical middle, on the app's background. The 1024 master is a full square; iOS draws the rounded corners. A lime variant is kept for a light home screen test.</p>
<div class="logo-stage dark" style="min-height:0;padding:28px"><div class="appicons">
<img class="appicon" src="downloads/logo/app-icon-1024.svg" width="180" height="180" alt="CenterSpot app icon">
<img class="appicon" src="downloads/logo/app-icon-1024.svg" width="120" height="120" alt="">
<img class="appicon" src="downloads/logo/app-icon-1024.svg" width="60" height="60" alt="">
<img class="appicon" src="downloads/logo/app-icon-1024.svg" width="40" height="40" alt="">
<img class="appicon" src="downloads/logo/app-icon-1024.svg" width="29" height="29" alt="">
<img class="appicon" src="downloads/logo/app-icon-lime-1024.svg" width="120" height="120" alt="Lime variant">
</div></div></div>

<div class="sub" id="logo-archive"><h3>Archive</h3><p class="lead">Every direction shown on the way to the mark, 8–9 November 2026, as they were drawn and described. The app still had its earlier Latin name then. The picks are outlined.</p>{arch_html}</div>
</section>'''

    colour_sec = f'''<section class="sec" id="colour">{head("colour", "02", "Colour", "Floodlight Chalk: tinted near-blacks for the chrome, one lime lead, and the board's own colours, which always mean something.")}
<div class="sub" id="colour-app"><h3>Interface</h3><p class="lead">Surfaces step up from bg to surface3; depth comes from those steps, not shadows. Lime appears once per screen.</p>{swatches(COLOURS)}</div>
<div class="sub" id="colour-board"><h3>Board</h3><p class="lead">The broadcast pitch everywhere the board is drawn (D-65), marks that lie on the grass, and the four arrow colours, each paired with its own line style.</p>{swatches(BOARD_COLOURS)}</div>
<div class="sub" id="colour-kits"><h3>Kits</h3><p class="lead">Twelve kit colours for either side. Dark fills (black, maroon) get a light edge so they hold on the dark pitch; numbers use each kit's ink.</p>{kits()}</div>
<div class="sub" id="colour-contrast"><h3>Contrast</h3><p class="lead">WCAG 2 contrast ratios, computed from the hex values. Muted text stays AA on every surface; lime is for fills and the playback bar, and ink is the only text on it.</p>{matrix()}</div>
</section>'''

    type_sec = f'''<section class="sec" id="type">{head("type", "03", "Typography", "Nunito for the interface and numbers, Kalam for what a coach would write by hand. Every size scales with Dynamic Type except shirt numbers, which scale with the board.")}
<div class="specimen"><div class="big">CenterSpot</div><div class="t-note" style="font:400 30px/1.3 Kalam;color:#93A0AD;margin-top:8px">8 finds the winger · 11 drives inside · 3 overlaps</div>
<div class="glyphs">Aa Bb Cc 0123456789 · 4-3-3 · 1.2 s · ½× 1× · 1080 × 1920</div></div>
<div style="margin-top:16px">{type_rows()}</div>
<div class="grid g2" style="margin-top:24px"><div class="card"><h4>Weights</h4><p>900 only for the wordmark (as in the logo), 800 for shirt numbers. 700 for titles and buttons, 600 for segment and tile labels, 500 for reading text (D-80).</p></div>
<div class="card"><h4>Handwriting</h4><p>Kalam is the coach's voice: step notes, draw hints, the tagline. Never for buttons, labels or anything you tap.</p></div></div>
</section>'''

    space_rows = "".join(f'<div class="space-row"><code>{n}</code><span>{v} pt</span><i style="width:{v*4}px"></i></div>' for n, v in SPACE)
    radii = "".join(f'<figure><div class="r" style="border-radius:{min(v, 42)}px"></div><b>{n}</b> · {v if v < 999 else "capsule"}<br>{use}</figure>' for n, v, use in RADIUS)
    sizes = "".join(f'<tr><td><code>{n}</code></td><td>{v} pt</td><td>{use}</td></tr>' for n, v, use in SIZES)
    space_sec = f'''<section class="sec" id="space">{head("space", "04", "Space and shape", "A 4 pt grid, six steps. Space inside a group is smaller than space between groups. Corners nest: inner radius is the outer one less the padding.")}
<div class="grid g2"><div><h3 style="font:800 18px Nunito;margin-bottom:8px">Spacing · Tokens.Space</h3>{space_rows}
<p class="muted" style="font-size:13px;margin-top:12px">Sheets: 24 pt sides and top. Library: 24 pt margins on phones, 32 on wide screens. Chips and rows: 8 pt apart.</p></div>
<div><h3 style="font:800 18px Nunito;margin-bottom:12px">Radius · Tokens.Radius</h3><div class="radii">{radii}</div></div></div>
<div class="sub"><h3>Sizes · Tokens.Size</h3><p class="lead">Every touch target is at least 44 pt (UI-BRIEF §2).</p><div class="scroll-x"><table class="sizes"><thead><tr><th>Token</th><th>Value</th><th>Use</th></tr></thead><tbody>{sizes}</tbody></table></div></div>
</section>'''

    curve_svg = ('<svg viewBox="-10 -10 180 132" width="100%" style="max-width:320px;display:block" role="img" aria-label="The ease curve, cubic-bezier 0.2, 0, 0, 1">'
                 '<rect x="0" y="0" width="160" height="100" fill="none" stroke="currentColor" stroke-opacity=".15"/>'
                 '<line x1="0" y1="100" x2="32" y2="100" stroke="#93A0AD" stroke-width=".8" stroke-dasharray="2 2"/><line x1="160" y1="0" x2="0" y2="0" stroke="#93A0AD" stroke-width=".8" stroke-dasharray="2 2"/>'
                 '<circle cx="32" cy="100" r="3" fill="#93A0AD"/><circle cx="0" cy="0" r="3" fill="#93A0AD"/>'
                 '<path d="M0 100 C32 100 0 0 160 0" fill="none" stroke="#C6FF3D" stroke-width="3" stroke-linecap="round"/>'
                 '<text x="0" y="114" font-size="9" fill="#93A0AD" font-family="ui-monospace,Menlo,monospace">cubic-bezier(0.2, 0, 0, 1)</text></svg>')
    motion_sec = f'''<section class="sec" id="motion">{head("motion", "05", "Motion", "One curve, six durations. Fast out of the gate, a long gentle settle. Playback motion is the Timeline, not these; Reduce Motion swaps UI motion for crossfades and never touches an exported video.")}
<div class="grid g2" style="align-items:center"><div class="curve">{curve_svg}</div><div class="card"><h4>Tokens.Motion.ease(_:)</h4><p><code>.timingCurve(0.2, 0, 0, 1, duration:)</code>. Hover or focus a card below to play its duration.</p>
<h4 style="margin-top:14px">Reduce Motion</h4><p>Playback steps through with 0.3 s crossfades; the camera holds one still framing of the whole move; the chip pulse is off.</p></div></div>
<div class="motion" style="margin-top:16px">{"".join(curve(n, d) for n, d, _ in MOTION)}</div></section>'''

    icons_sec = f'''<section class="sec" id="icons">{head("icons", "06", "Icons", "CenterSpot's own set (this lifts the D-51 hold), one icon for each SF Symbol the app uses, plus a few it needs. Drawn for football: the formation is a pitch, export is the 9:16 clip, tips are a whistle.")}
<div class="sub" id="icons-grid"><h3>Grid</h3><p class="lead">24-unit square, 2-unit padding (live area 20). One 2-unit stroke, round caps and joins, <code>currentColor</code>. Fills only where meaning needs one: our side is filled, play is solid. Keylines: circle 10, square 18, tall rectangle 14 × 20.</p>{keyline()}</div>
<div class="sub" id="icons-set"><h3>Interface set</h3><p class="lead">Shown at 16, 24 and 32. In the app they take the type's colour (muted when idle, text when lit, ink on lime) and the bar or inline size: 22 pt and 17 pt.</p>{icon_html}</div>
<div class="sub" id="icons-tools"><h3>Draw tools</h3><p class="lead">Already custom in the app (ToolIcon): each draws its line style in its own colour, so kinds never differ by colour alone. They keep their colours everywhere.</p>{tool_html}</div>
</section>'''

    comps_sec = f'''<section class="sec" id="components">{head("components", "07", "Components", "Every component in the app, rendered here from its SwiftUI source with the app's tokens. Each one lists its type, ink, copy, VoiceOver label, accessibility IDs, hit target and source file. Icons shown are the new set.")}
<div class="sub" id="which"><h3>Which component?</h3><p class="lead">Start from what the person is doing.</p>{components.which()}</div>
{components.build()}</section>'''

    scen_sec, scen_js = scenarios.section(head)

    pairs = [
        ("Removed number 7", "Player deleted successfully!", "Say what changed, in football words, and offer Undo. No exclamation marks."),
        ("Couldn't make the video. Try again, or export an image.", "Error: export failed (code -11800).", "Say what happened and what to do next. Never a code."),
        ("Up to 4 MB · 8 s · 1080 × 1920", "Your video is being prepared…", "Be honest about size before sharing (rule 7). Numbers, not reassurance."),
        ("About 3 seconds left. Keep CenterSpot open until it's done.", "Please wait while we process your request.", "Tell people how long and what not to do."),
        ("Names and numbers stay. 4 players leave the board.", "Are you sure? This action may affect your tactic.", "State the consequence, with the count."),
        ("Pick a formation to start", "Get started by selecting a formation from the options below!", "Short, sentence case, no period on a label."),
        ("Drag any player to where they should be.", "Tap and hold on a player token to reposition it on the pitch canvas.", "Players, not tokens; pitch, not canvas."),
        ("A move can have up to 40 steps.", "Maximum step limit reached.", "Name the limit in plain words."),
    ]
    pair_html = ('<div class="scroll-x"><table class="pairs"><thead><tr><th>Write this</th><th>Not that</th><th>Why</th></tr></thead><tbody>' +
                 "".join(f'<tr><td class="yes"><span class="lbl">Write this</span>{a}</td><td class="no"><span class="lbl">Not that</span>{b}</td><td class="why">{w}</td></tr>' for a, b, w in pairs) +
                 "</tbody></table></div>")
    moments = [("First launch", "Warm and brief. One idea per page.", "Draw the move, not just the shape · Press Play. Watch it move"),
               ("Editing", "Out of the way. Labels name the thing.", "Step 2 · 1.4 s · Edit · Draw run · Remove"),
               ("Teaching", "A coach at your shoulder. Do this, see that.", "Tap step 2 to see where everyone goes."),
               ("Waiting", "Honest numbers, what to do meanwhile.", "Rendering 96 of 240 frames"),
               ("Done", "The result and its real size.", "Video ready · 3.1 MB · 8 s · 1080 × 1920"),
               ("Something went wrong", "Calm, specific, a way out.", "Couldn't save. Allow Photos in Settings"),
               ("The coach's notes", "Handwritten, short, about players.", "8 finds the winger")]
    moment_rows = "".join(f'<tr><td><b>{m}</b></td><td>{t}</td><td class="muted">{e}</td></tr>' for m, t, e in moments)
    voice_sec = f'''<section class="sec" id="voice">{head("voice", "09", "Voice and tone", "A coach who knows the game and respects your time. Plain football words, numbers when they help, never hype.")}
<div class="principles p3"><div><h3>Plain football words</h3><p>Player, run, step, pitch, the box. Never token, canvas, entity, keyframe.</p></div>
<div><h3>Short and calm</h3><p>Sentence case. No exclamation marks. Labels and titles end without a period; sentences keep theirs.</p></div>
<div><h3>Honest</h3><p>Real sizes before sharing, real frame counts while rendering, what was removed and how to undo it.</p></div></div>
<div class="sub"><h3>Write this, not that</h3><p class="lead">Real copy from the app, next to what a template would say.</p>{pair_html}</div>
<div class="sub"><h3>Tone by moment</h3><div class="scroll-x"><table class="a11y"><thead><tr><th>Moment</th><th>Tone</th><th>Example</th></tr></thead><tbody>{moment_rows}</tbody></table></div></div>
<div class="sub"><h3>Words we use</h3><div class="scroll-x"><table class="a11y"><thead><tr><th>Say</th><th>Not</th></tr></thead><tbody>
<tr><td>Us, them · our player, their player</td><td>Home team, away team, team A</td></tr><tr><td>Step</td><td>Keyframe, frame, slide</td></tr>
<tr><td>Run, pass, dribble, press</td><td>Arrow type, path</td></tr><tr><td>Tactic, move</td><td>Project, document, file (except .tactic)</td></tr>
<tr><td>Formation, shape</td><td>Template, preset</td></tr><tr><td>Export, share</td><td>Render, publish</td></tr>
<tr><td>CenterSpot</td><td>Center Spot, Centerspot, centerspot (except in IDs and URLs)</td></tr></tbody></table></div></div>
</section>'''

    a11y = [("VoiceOver: tokens", "Every token is its own element, labelled in football words from its role and zone, with the step.", "“Number 9, striker, edge of the box, step 3”"),
            ("VoiceOver: steps", "Chips and rows read their number, time and note; the current one is Selected with a hint for its actions.", "“Step 2 of 5, 1.4 seconds, 11 drives inside”"),
            ("VoiceOver: playback", "The scrubber is one adjustable element; swipe up and down to change step.", "“Step 2 of 5”, value “0:01.9 / 0:06.4”"),
            ("VoiceOver: pictures", "Welcome art and the export preview have their own labels; decoration is hidden.", "“Preview, Vertical 9:16, broadcast camera”"),
            ("Dynamic Type", "Every sheet scales. Bars cap at Large and show the Large Content Viewer; rows scroll sideways; segments stack; export stacks the preview above.", "Toolbar labels never truncate to “Fo…”"),
            ("Reduce Motion", "Playback steps through with crossfades; the camera holds a still framing; the chip pulse is off. Exported videos never change.", "Rule 8"),
            ("Never colour alone", "Us filled, them rings. Run solid, pass dashed, dribble wavy, press chevrons. Page dots differ by width.", "D-15"),
            ("Touch targets", "44 pt minimum everywhere; tokens have a 44 pt round hit area on the pitch.", "UI-BRIEF §2"),
            ("Contrast", "Text and muted pass AA on every surface; only ink sits on lime.", "See the matrix in Colour"),
            ("Keyboard", "⌘Z and ⇧⌘Z for Undo and Redo on iPad and Mac.", "nav.undo, nav.redo")]
    a11y_rows = "".join(f'<tr><td><b>{a}</b></td><td>{b}</td><td class="muted">{c}</td></tr>' for a, b, c in a11y)
    a11y_sec = f'''<section class="sec" id="a11y">{head("a11y", "10", "Accessibility", "A coach using VoiceOver should be able to build and play a move. Labels speak football, not geometry.")}
<div class="scroll-x"><table class="a11y"><thead><tr><th>Area</th><th>What the app does</th><th>Example</th></tr></thead><tbody>{a11y_rows}</tbody></table></div></section>'''

    dls = [("tokens.json", "JSON", "Every token: colour, kits, type, space, radius, sizes, motion, board"),
           ("icons/centerspot-icons.svg", "SVG", f"Sprite: {len(icons.ICONS)} interface icons + {len(icons.TOOLS)} draw tools"),
           ("logo/mark.svg", "SVG", "The mark, transparent"), ("logo/mark-small.svg", "SVG", "The mark for 16–20 px"),
           ("logo/mark-on-dark.svg", "SVG", "The mark on #0B0F14"), ("logo/mark-paper.svg", "SVG", "Paper colourway"), ("logo/mark-lime.svg", "SVG", "Lime colourway"),
           ("logo/lockup-horizontal.svg", "SVG", "Mark + word (live Nunito 900 text)"), ("logo/lockup-stacked.svg", "SVG", "Stacked lockup (live text)"),
           ("logo/app-icon-1024.svg", "SVG", "App icon master, 1024"), ("logo/app-icon-1024.png", "PNG", "App icon, 1024 × 1024"),
           ("logo/app-icon-lime-1024.svg", "SVG", "Lime app icon variant")]
    dl_html = "".join(f'<a href="downloads/{p}" download><span class="ext">{e}</span><span><b>{p.split("/")[-1]}</b><span>{d}</span></span></a>' for p, e, d in dls)
    dl_sec = f'''<section class="sec" id="downloads">{head("downloads", "11", "Downloads", "The files behind this page. Single icons are in downloads/icons/ by name.")}
<div class="dl">{dl_html}</div>
<footer class="foot">CenterSpot design system · v1 · 9 November 2026 · Values from <code>CenterSpot/Design/Tokens.swift</code> and the SwiftUI views (git 89a0eb9). The app is the source of truth (D-12): when they differ, the app wins and this page is updated.</footer></section>'''

    page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CenterSpot Design System</title>
<meta name="description" content="The CenterSpot design system: logo, colour, type, space, motion, icons, every component, scenarios, voice and accessibility.">
<link rel="icon" href="downloads/logo/app-icon-1024.svg">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Kalam:wght@400&family=Nunito:ital,wght@0,500;0,600;0,700;0,800;0,900&display=swap" rel="stylesheet">
<style>{css}</style>
</head>
<body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>{logo.MARK_DEFS}{icons.sprite_defs()}{arch_defs}</defs></svg>
<header class="topbar"><a class="lock" href="#overview" aria-label="CenterSpot design system, top">{mk(30)}<span class="word">CenterSpot</span></a>
<span class="ds">Design System</span><span class="spacer"></span><span class="ver">v1 · 9 Nov 2026</span>
<button class="theme-btn" id="theme" type="button" aria-label="Switch colour theme">Theme</button></header>
<div class="layout"><nav class="sidenav" aria-label="Sections">{nav_html}</nav>
<main>{overview}{logo_sec}{colour_sec}{type_sec}{space_sec}{motion_sec}{icons_sec}{comps_sec}{scen_sec}{voice_sec}{a11y_sec}{dl_sec}</main></div>
<script>
(function () {{
  var root = document.documentElement, btn = document.getElementById('theme');
  function get() {{ try {{ return localStorage.getItem('cs-theme'); }} catch (e) {{ return null; }} }}
  function set(v) {{ try {{ localStorage.setItem('cs-theme', v); }} catch (e) {{}} }}
  function current() {{ return root.dataset.theme || (matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'); }}
  function label() {{ btn.textContent = current() === 'dark' ? 'Light' : 'Dark'; }}
  var saved = get(); if (saved) root.dataset.theme = saved; label();
  btn.addEventListener('click', function () {{ var next = current() === 'dark' ? 'light' : 'dark'; root.dataset.theme = next; set(next); label(); }});
  var links = Array.prototype.slice.call(document.querySelectorAll('.sidenav > ol > li > a'));
  var secs = links.map(function (a) {{ return document.getElementById(a.getAttribute('href').slice(1)); }});
  if ('IntersectionObserver' in window) {{
    var io = new IntersectionObserver(function (es) {{ es.forEach(function (e) {{ if (e.isIntersecting) {{
      links.forEach(function (l) {{ l.classList.toggle('on', l.getAttribute('href') === '#' + e.target.id); }}); }} }}); }}, {{ rootMargin: '-30% 0px -65% 0px' }});
    secs.forEach(function (s) {{ if (s) io.observe(s); }});
  }}
  document.querySelectorAll('.motion .card').forEach(function (c) {{ c.tabIndex = 0; c.addEventListener('click', function () {{ c.classList.toggle('play'); }}); }});
}})();
</script>
{scen_js}
</body>
</html>
'''
    open(os.path.join(OUT, "index.html"), "w").write(page)
    print("wrote index.html", len(page) // 1024, "KB")


if __name__ == "__main__":
    main()
