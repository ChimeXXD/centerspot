"""The board as static SVG, ported from mockup/board.js + broadcast.js and checked against Render/ (TokenDrawing,
ArrowDrawing, MarkDrawing, BoardGeometry). The app draws with BoardRenderer; this is the design system's picture of it."""
import json, math, os

SRC = os.path.join(os.path.dirname(__file__), "..", "..")  # the repo root: mockup/ and presets/

C = {  # Tokens.Colour
    "bg": "#0B0F14", "text": "#F2F5F7", "bcPitchA": "#0E1216", "bcPitchB": "#13181D", "bcLine": "rgba(255,255,255,.42)",
    "zoneFill": "rgba(198,255,61,.13)", "zoneStroke": "rgba(198,255,61,.72)", "heat": "#FF5A2E", "heatCore": "#FFB547",
    "awayInner": "rgba(11,15,20,.85)", "awayInk": "#FFFFFF", "ball": "#FFFFFF", "discOutline": "#0B0F14",
    "run": "#FFFFFF", "pass": "#C6FF3D", "dribble": "#FFD84A", "press": "#FF6B4A",
}
KITS = {  # Tokens.kit(_:)  fill, ink, outline
    "lime": ("#C6FF3D", "#0B0F14", None), "coral": ("#FF6B4A", "#0B0F14", None), "blue": ("#4C8DFF", "#0B0F14", None),
    "red": ("#FF5252", "#0B0F14", None), "orange": ("#FF9F1C", "#0B0F14", None), "yellow": ("#FFD84A", "#0B0F14", None),
    "green": ("#2BD67B", "#0B0F14", None), "purple": ("#B79CFF", "#0B0F14", None), "black": ("#15181C", "#FFFFFF", "#E6E9EC"),
    "white": ("#F2F5F7", "#0B0F14", None), "sky": ("#5BC8FF", "#0B0F14", None), "maroon": ("#8C1D40", "#FFFFFF", "#F2F5F7"),
}
RATIO = 105 / 68
_uid = [0]


def load_hero():
    raw = open(os.path.join(SRC, "mockup", "hero.js")).read()
    return json.JSONDecoder().raw_decode(raw, raw.index("{"))[0]


HERO = load_hero()
TOK = {t["id"]: t for t in HERO["tokens"]}
STEPS = HERO["phases"][0]["steps"]


def pt(p, W, H):
    return p["x"] * W, (1 - p["y"]) * H


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def pitch(W, H, stripes=True):
    s, cx, L, w = W / 68, W / 2, C["bcLine"], 1.4 * (W / 345)
    out = ""
    for i in range(10):
        fill = C["bcPitchB"] if (i % 2 and stripes) else C["bcPitchA"]
        out += f'<rect x="0" y="{f(i * H / 10)}" width="{f(W)}" height="{f(H / 10 + .5)}" fill="{fill}"/>'
    out += f'<g fill="none" stroke="{L}" stroke-width="{f(w)}" stroke-linecap="round"><rect x="0" y="0" width="{f(W)}" height="{f(H)}"/>'
    out += f'<line x1="0" y1="{f(H/2)}" x2="{f(W)}" y2="{f(H/2)}"/><circle cx="{f(cx)}" cy="{f(H/2)}" r="{f(9.15*s)}"/>'
    out += f'<circle cx="{f(cx)}" cy="{f(H/2)}" r="{f(1.4*w)}" fill="{L}"/>'
    for top in (True, False):
        e, d = (0, 1) if top else (H, -1)
        by, dx = e + d * 16.5 * s, 7.31 * s
        out += f'<rect x="{f(cx-20.16*s)}" y="{f(e if top else e-16.5*s)}" width="{f(40.32*s)}" height="{f(16.5*s)}"/>'
        out += f'<rect x="{f(cx-9.16*s)}" y="{f(e if top else e-5.5*s)}" width="{f(18.32*s)}" height="{f(5.5*s)}"/>'
        out += f'<circle cx="{f(cx)}" cy="{f(e+d*11*s)}" r="{f(1.4*w)}" fill="{L}"/>'
        out += f'<path d="M {f(cx-dx)} {f(by)} A {f(9.15*s)} {f(9.15*s)} 0 0 {0 if top else 1} {f(cx+dx)} {f(by)}"/>'
    return out + "</g>"


def _head(ex, ey, ang, h, spread):
    return (f"M {f(ex - h*math.cos(ang-spread))} {f(ey - h*math.sin(ang-spread))} L {f(ex)} {f(ey)} "
            f"L {f(ex - h*math.cos(ang+spread))} {f(ey - h*math.sin(ang+spread))}")


def arrow(a, W, H, positions, opacity=1.0):
    k, r = W / 345, W * 0.038
    P = [list(pt(p, W, H)) for p in a["points"]]
    last, prev = P[-1], P[-2]
    if any(math.hypot(pt(q, W, H)[0] - last[0], pt(q, W, H)[1] - last[1]) < r * 1.2 for q in positions.values()):
        ln = math.hypot(last[0] - prev[0], last[1] - prev[1]); cut = min(r * 1.35, ln / 2)
        P[-1] = [last[0] - (last[0] - prev[0]) / ln * cut, last[1] - (last[1] - prev[1]) / ln * cut]
    col, sw = C[a["kind"]], 2.6 * k
    ex, ey = P[-1]; px, py = P[-2]; ang = math.atan2(ey - py, ex - px)
    g = f'<g opacity="{opacity}" fill="none" stroke="{col}" stroke-width="{f(sw)}" stroke-linecap="round" stroke-linejoin="round">'
    if a["kind"] == "press":
        gap = 6 * k
        heads = "".join(f'<path d="{_head(ex - math.cos(ang)*gap*i, ey - math.sin(ang)*gap*i, ang, 8*k, .75)}"/>' for i in range(2))
        return g + heads + "</g>"
    d = f"M {f(P[0][0])} {f(P[0][1])}"
    if a["kind"] == "dribble":
        for i in range(1, len(P)):
            ax, ay = P[i - 1]; bx, by = P[i]; ln = math.hypot(bx - ax, by - ay)
            n = max(2, round(ln / (9 * k))); nx, ny = -(by - ay) / ln, (bx - ax) / ln
            for j in range(1, n + 1):
                t = j / n; amp = 0 if j == n else (3.5 if j % 2 else -3.5) * k
                d += f" L {f(ax + (bx-ax)*t + nx*amp)} {f(ay + (by-ay)*t + ny*amp)}"
    else:
        d += "".join(f" L {f(x)} {f(y)}" for x, y in P[1:])
    dash = f' stroke-dasharray="{f(7*k)} {f(5*k)}"' if a["kind"] == "pass" else ""
    return g + f'<path d="{d}"{dash}/><path d="{_head(ex, ey, ang, 9*k, .45)}"/></g>'


def token(t, x, y, W, kit_home="lime", kit_away="coral", selected=False, positions=None, carried=False):
    """TokenDrawing.drawBody + drawNumber: home filled disc, away ring on a dark centre, D-67 outline."""
    r = W * 0.038
    if t["kind"] == "ball":
        if carried:
            x += r * .95; y += r * .95
        return (f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r*.42)}" fill="{C["ball"]}"/>'
                f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r*.42)}" fill="none" stroke="{C["bg"]}" stroke-width="{f(r*.14)}"/>')
    if t["kind"] == "cone":
        h = r * .95
        return (f'<path d="M {f(x)} {f(y-h*.75)} L {f(x+h*.6)} {f(y+h*.5)} L {f(x-h*.6)} {f(y+h*.5)} Z" fill="{C["dribble"]}" '
                f'stroke="{C["bg"]}" stroke-width="{f(r*.12)}" stroke-linejoin="round"/>')
    out = ""
    if selected:
        out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r*1.45)}" fill="none" stroke="{C["text"]}" stroke-width="{f(r*.14)}"/>'
    away = t.get("side") == "away"
    fill, ink, outline = KITS[kit_away if away else kit_home]
    if away:
        out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r*.9)}" fill="{C["awayInner"]}" stroke="{fill}" stroke-width="{f(r*.24)}"/>'
        edge = r * 1.02
        if outline:
            out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r*1.06)}" fill="none" stroke="{outline}" stroke-width="{f(r*.08)}"/>'
            edge = r * 1.1
        ink = C["awayInk"]
    else:
        out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{fill}"/>'
        if outline:
            out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r*.95)}" fill="none" stroke="{outline}" stroke-width="{f(r*.1)}"/>'
        edge = r
    out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(edge + r*.05)}" fill="none" stroke="{C["discOutline"]}" stroke-width="{f(r*.1)}"/>'
    if t.get("number") is not None:
        out += (f'<text x="{f(x)}" y="{f(y + r*.36)}" text-anchor="middle" font-family="Nunito, sans-serif" font-weight="800" '
                f'font-size="{f(r*1.05)}" fill="{ink}">{t["number"]}</text>')
    return out


def marks(m, W, H, positions):
    """MarkDrawing order: zones, heat, shape lines, glow rings, all under the tokens."""
    k, R, out = W / 345, W * 0.038, ""
    P = lambda p: pt(p, W, H)
    for z in m.get("zones", []):
        x0, y0 = P({"x": z["x"], "y": z["y"] + z["h"]}); x1, y1 = P({"x": z["x"] + z["w"], "y": z["y"]})
        out += (f'<rect x="{f(x0)}" y="{f(y0)}" width="{f(x1-x0)}" height="{f(y1-y0)}" fill="{C["zoneFill"]}" '
                f'stroke="{C["zoneStroke"]}" stroke-width="{f(1.4*k)}"/>')
    for g in m.get("heat", []):
        _uid[0] += 1; gid = f"heat{_uid[0]}"; x, y = P(g); r = g.get("r", .1) * W
        out += (f'<defs><radialGradient id="{gid}"><stop offset="0" stop-color="{C["heatCore"]}" stop-opacity=".7"/>'
                f'<stop offset=".35" stop-color="{C["heat"]}" stop-opacity=".55"/><stop offset="1" stop-color="{C["heat"]}" stop-opacity="0"/>'
                f'</radialGradient></defs><ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r)}" ry="{f(r*.8)}" fill="url(#{gid})"/>')
    for l in m.get("lines", []):
        pts = [P(positions[i]) for i in l["ids"] if i in positions]
        kit = KITS["lime"][0] if TOK[l["ids"][0]].get("side") == "home" else KITS["coral"][0]
        out += (f'<polyline points="{" ".join(f"{f(a)},{f(b)}" for a, b in pts)}" fill="none" stroke="{kit}" '
                f'stroke-width="{f(2.2*k)}" stroke-linecap="round" stroke-linejoin="round" opacity=".9"/>')
    for i in m.get("rings", []):
        x, y = P(positions[i]); kit = KITS["lime"][0] if TOK[i].get("side") == "home" else KITS["coral"][0]
        out += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(R*1.3)}" fill="{kit}" fill-opacity=".18"/>'
        out += "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(R*fr)}" fill="none" stroke="{kit}" stroke-width="{f(1.6*k)}" opacity="{o}"/>'
                       for fr, o in ((1.3, .95), (1.85, .6), (2.45, .3)))
    return out


def board_svg(W, step=0, arrows=None, m=None, selected=None, only=None, crop=None, label="Board", extra=""):
    """A whole board at width W from the hero tactic's step. `only` limits the tokens drawn; `crop` is a viewBox."""
    H = W * RATIO
    positions = STEPS[step]["positions"]
    if only:
        positions = {k: v for k, v in positions.items() if k in only}
    svg = pitch(W, H)
    if m:
        svg += marks(m, W, H, positions)
    for a in (STEPS[step].get("arrows", []) if arrows is None else arrows):
        svg += arrow(a, W, H, positions)
    svg += extra
    r = W * 0.038
    for tid, p in sorted(positions.items(), key=lambda kv: TOK[kv[0]]["kind"] == "ball"):
        x, y = pt(p, W, H)
        carried = TOK[tid]["kind"] == "ball" and any(
            TOK[o]["kind"] == "player" and math.hypot(pt(q, W, H)[0] - x, pt(q, W, H)[1] - y) < r * 1.2
            for o, q in positions.items())
        svg += token(TOK[tid], x, y, W, selected=(tid == selected), carried=carried)
    vb = crop or (0, 0, W, H)
    return (f'<svg class="board" viewBox="{" ".join(f(v) for v in vb)}" width="{f(vb[2])}" height="{f(vb[3])}" '
            f'role="img" aria-label="{label}">{svg}</svg>')


def formation_diagram(slots, w=74, h=92):
    """FormationPicker.FormationDiagram: chalk outline and halfway line, a dot per slot."""
    chalk = "rgba(255,255,255,.55)"
    out = (f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" aria-hidden="true"><rect x="1" y="1" width="{w-2}" height="{h-2}" '
           f'rx="4" fill="none" stroke="{chalk}"/><line x1="1" y1="{h/2}" x2="{w-1}" y2="{h/2}" stroke="{chalk}"/>')
    for s in slots:
        x, y = 4 + s["x"] * (w - 8), 4 + (1 - s["y"]) * (h - 8)
        out += f'<circle cx="{f(x)}" cy="{f(y)}" r="3.6" fill="#F2F5F7"/>'
    return out + "</svg>"


def formations(pitch_kind="full"):
    d = json.load(open(os.path.join(SRC, "presets", "formations.json")))
    return [x for x in d["formations"] if x["pitch"] == pitch_kind]
