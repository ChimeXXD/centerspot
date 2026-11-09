"""The CenterSpot mark ("7 · Depth", picked 9 Nov 2026) and the archive of every direction shown on the way there."""
import os, re

LOGO_DIR = os.path.join(os.path.dirname(__file__), "logo-rounds")  # the five rounds as shown to Chime

# The mark exactly as picked (logo-rounds/index5.html, symbol e7a), on a 100-unit grid.
LINE = '<path d="M8 55 H 92" stroke="currentColor" stroke-width="6" stroke-linecap="round"/>'
MARK_DEFS = (
    '<mask id="cs-cut" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100"><rect width="100" height="100" fill="white"/>'
    '<ellipse cx="50" cy="53.5" rx="26" ry="10.5" fill="black"/></mask>'
    '<symbol id="cs-mark" viewBox="0 0 100 100">' + LINE +
    '<ellipse cx="50" cy="56" rx="33" ry="17" fill="currentColor" mask="url(#cs-cut)"/>'
    '<ellipse cx="50" cy="55" rx="9" ry="5.5" fill="var(--spot, #C6FF3D)" stroke="var(--key, none)" stroke-width="5" paint-order="stroke"/></symbol>'
    # Small sizes (16 and 20 px): the same drawing with a heavier far side, line and spot, so nothing drops below a pixel.
    '<mask id="cs-cut-s" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100"><rect width="100" height="100" fill="white"/>'
    '<ellipse cx="50" cy="54" rx="24" ry="9" fill="black"/></mask>'
    '<symbol id="cs-mark-s" viewBox="0 0 100 100"><path d="M8 55 H 92" stroke="currentColor" stroke-width="8" stroke-linecap="round"/>'
    '<ellipse cx="50" cy="56" rx="33" ry="17" fill="currentColor" mask="url(#cs-cut-s)"/>'
    '<ellipse cx="50" cy="55" rx="10" ry="6.5" fill="var(--spot, #C6FF3D)" stroke="var(--key, none)" stroke-width="5" paint-order="stroke"/></symbol>'
)


def mark(size, cls="mk", small=None, label=None):
    sym = "cs-mark-s" if (small if small is not None else size <= 20) else "cs-mark"
    a = f'role="img" aria-label="{label}"' if label else 'aria-hidden="true"'
    return f'<svg class="{cls}" width="{size}" height="{size}" viewBox="0 0 100 100" {a}><use href="#{sym}"/></svg>'


def standalone_mark(fg="#F2F5F7", spot="#C6FF3D", key=None, bg=None, size=100, small=False):
    cut = ("54", "24", "9") if small else ("53.5", "26", "10.5")
    lw, sp = ("8", ("10", "6.5")) if small else ("6", ("9", "5.5"))
    k = f' stroke="{key}" stroke-width="5" paint-order="stroke"' if key else ""
    b = f'<rect width="100" height="100" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 100 100">'
            f'<defs><mask id="c" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100"><rect width="100" height="100" fill="white"/>'
            f'<ellipse cx="50" cy="{cut[0]}" rx="{cut[1]}" ry="{cut[2]}" fill="black"/></mask></defs>{b}'
            f'<path d="M8 55 H 92" stroke="{fg}" stroke-width="{lw}" stroke-linecap="round"/>'
            f'<ellipse cx="50" cy="56" rx="33" ry="17" fill="{fg}" mask="url(#c)"/>'
            f'<ellipse cx="50" cy="55" rx="{sp[0]}" ry="{sp[1]}" fill="{spot}"{k}/></svg>\n')


def app_icon_svg(size=1024, bg="#0B0F14", fg="#F2F5F7", spot="#C6FF3D", key=None):
    """The 1024 master: the mark at 72% of the tile, centred on its optical middle (the line), on a full square;
    iOS applies the rounded mask itself."""
    m = standalone_mark(fg, spot, key).split("<svg", 1)[1].split(">", 1)[1].rsplit("</svg>", 1)[0]
    s = 0.72 * size / 100
    off = (size - 100 * s) / 2
    dy = size / 2 - (off + 56 * s)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f'<rect width="{size}" height="{size}" fill="{bg}"/><g transform="translate({off:.1f} {off + dy:.1f}) scale({s:.4f})">{m}</g></svg>\n')


def wordmark_svg(fg="#F2F5F7", spot="#C6FF3D", stacked=False):
    """Lockup files with live text (Nunito 900); outline the text in a vector tool before print."""
    m = standalone_mark(fg, spot).split(">", 1)[1].rsplit("</svg>", 1)[0]
    if stacked:
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="360" height="220" viewBox="0 0 360 220">'
                f'<g transform="translate(110 0) scale(1.4)">{m}</g>'
                f'<text x="180" y="200" text-anchor="middle" font-family="Nunito" font-weight="900" font-size="52" letter-spacing="-0.5" fill="{fg}">CenterSpot</text></svg>\n')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="420" height="100" viewBox="0 0 420 100">{m.replace("<defs>", "<defs>", 1)}'
            f'<text x="104" y="69" font-family="Nunito" font-weight="900" font-size="52" letter-spacing="-0.5" fill="{fg}">CenterSpot</text></svg>\n')


ROUNDS = [
    ("index.html", "Round 1", "Five marks about the app's ideas: the run, a monogram, us and them, the clip, on the march.", None,
     "Rejected: too abstract, not enough of a tactics board."),
    ("index2.html", "Round 2", "Five marks with more tactics-board grammar: X and O, the box, a formation A, the overlap, beat your man.", None,
     "Rejected: busy at small sizes; Chime asked for simple and effective."),
    ("index3.html", "Round 3", "Ten different, simple marks. Chime picked number 3, the centre circle.", "s3",
     "Picked: Centre circle."),
    ("index4.html", "Refinements", "Seven ways to take the centre circle further.", None,
     "Chime liked As picked, Chalk gaps, Bolder and Broadcast; asked to elevate those."),
    ("index5.html", "Elevated", "Eight elevated versions of the four. Chime picked 7 · Depth.", "e7a",
     "Picked: 7 · Depth, now the CenterSpot mark."),
]


def archive():
    blocks, defs = [], ""
    for n, (fname, title, lead, picked, verdict) in enumerate(ROUNDS, 1):
        html = open(os.path.join(LOGO_DIR, fname)).read()
        d = re.search(r"<defs>(.*?)</defs>", html, re.S).group(1)
        d = re.sub(r"<!--.*?-->", "", d, flags=re.S)
        p = f"r{n}-"
        d = re.sub(r'id="([^"]+)"', lambda m: f'id="{p}{m.group(1)}"', d)
        d = re.sub(r'url\(#([^)]+)\)', lambda m: f'url(#{p}{m.group(1)})', d)
        defs += d
        opts = re.findall(r"\{\s*id:\s*'([^']+)',\s*name:\s*'((?:[^'\\]|\\.)*)',\s*why:\s*'((?:[^'\\]|\\.)*)'", html)
        cards = ""
        for oid, name, why in opts:
            why = why.replace("\\'", "'")
            name = name.replace("\\'", "'")
            on = ' class="arch-card picked"' if oid == picked else ' class="arch-card"'
            cards += (f'<figure{on}><div class="arch-art"><svg viewBox="0 0 100 100" aria-hidden="true"><use href="#{p}{oid}"/></svg></div>'
                      f'<figcaption><b>{name}</b>{"<em>Picked</em>" if oid == picked else ""}<span>{why}</span></figcaption></figure>')
        blocks.append(f'<div class="arch-round"><div class="arch-head"><h4>{title}</h4><p>{lead}</p><p class="verdict">{verdict}</p></div>'
                      f'<div class="arch-grid">{cards}</div></div>')
    return defs, "".join(blocks)
