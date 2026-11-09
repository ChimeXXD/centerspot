"""CenterSpot's own icon set (lifts D-51). 24-unit grid, 2-unit live padding, one 2-unit stroke with round caps and
joins, currentColor. Fills only where the app's meaning needs one: our side is filled, play is solid."""

STROKE = 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'
FILL = 'fill="currentColor" stroke="none"'
SOLID = 'fill="currentColor"'  # filled and stroked: rounded corners on solid shapes

# name: (label, SF Symbol it replaces, where the app uses it, inner SVG)
ICONS = {
    "undo": ("Undo", "arrow.uturn.backward", "Board nav bar, iPad column", '<path d="M9 13.5 4.5 9 9 4.5"/><path d="M4.5 9h10a5.5 5.5 0 0 1 0 11H10"/>'),
    "redo": ("Redo", "arrow.uturn.forward", "Board nav bar, iPad column", '<path d="M15 13.5 19.5 9 15 4.5"/><path d="M19.5 9h-10a5.5 5.5 0 0 0 0 11H14"/>'),
    "share": ("Share", "square.and.arrow.up", "Title menu, library card menu, iPad nav", '<path d="M8.5 9.5H7a2 2 0 0 0-2 2V19a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7.5a2 2 0 0 0-2-2h-1.5"/><path d="M12 14.5V3"/><path d="M8 7l4-4 4 4"/>'),
    "rename": ("Rename", "pencil", "Title menu, library card menu", '<path d="M4.5 19.5l.7-3.6L15.6 5.5a2.05 2.05 0 0 1 2.9 2.9L8.1 18.8z"/><path d="M13.8 7.3l2.9 2.9"/><path d="M12.5 19.5h7"/>'),
    "draw": ("Draw", "pencil", "Board toolbar", '<path d="M3.5 20.5c3 0 4.5-2.5 7-6"/><path d="M10.5 14.5l.85-3.39 5.66-5.66a1.8 1.8 0 0 1 2.54 2.54l-5.66 5.66z"/>'),
    "formation": ("Formation", "circle.grid.2x1", "Board toolbar", f'<rect x="4" y="2.5" width="16" height="19" rx="2"/><g {FILL}><circle cx="9" cy="8" r="1.6"/><circle cx="15" cy="8" r="1.6"/><circle cx="7.5" cy="15.5" r="1.6"/><circle cx="12" cy="15.5" r="1.6"/><circle cx="16.5" cy="15.5" r="1.6"/></g>'),
    "add": ("Add", "plus.circle", "Board toolbar (player, ball, cone)", '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>'),
    "plus": ("New, add a step", "plus", "New tactic, steps strip, steps list", '<path d="M12 5v14M5 12h14"/>'),
    "play": ("Play", "play.fill", "Toolbar disc, playback", f'<path {SOLID} d="M8 5.5v13l10.5-6.5z"/>'),
    "pause": ("Pause", "pause.fill", "Playback", f'<g {FILL}><rect x="6.5" y="5" width="3.5" height="14" rx="1"/><rect x="14" y="5" width="3.5" height="14" rx="1"/></g>'),
    "step-back": ("Previous step", "backward.end.fill", "Playback", f'<path d="M6 5.5v13"/><path {SOLID} d="M18 6v12l-8.5-6z"/>'),
    "step-forward": ("Next step", "forward.end.fill", "Playback", f'<path d="M18 5.5v13"/><path {SOLID} d="M6 6v12l8.5-6z"/>'),
    "loop": ("Loop", "repeat", "Playback", '<path d="M16.5 3l3 3-3 3"/><path d="M19.5 6h-11a4 4 0 0 0-4 4v1"/><path d="M7.5 21l-3-3 3-3"/><path d="M4.5 18h11a4 4 0 0 0 4-4v-1"/>'),
    "export": ("Export", "film", "Board toolbar", f'<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path {SOLID} stroke-width="1.5" d="M10.5 9.5v5l4-2.5z"/>'),
    "close": ("Close", "xmark", "Sheets, tips, cancel drawing", '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>'),
    "check": ("Done, selected", "checkmark", "Draw Done, role list, column nav", '<path d="M5 12.5l5 5 9-11"/>'),
    "chevron-down": ("Opens a menu", "chevron.down", "Title menu, role line", '<path d="M6 9l6 6 6-6"/>'),
    "back": ("Back", "chevron.backward", "Nav bar back to the library", '<path d="M15 4.5 7.5 12l7.5 7.5"/>'),
    "more": ("More", "ellipsis", "Library", f'<g {FILL}><circle cx="5.5" cy="12" r="1.75"/><circle cx="12" cy="12" r="1.75"/><circle cx="18.5" cy="12" r="1.75"/></g>'),
    "tips": ("Show tips again", "lightbulb", "Library More menu", f'<circle cx="10" cy="14" r="5.5"/><path d="M10 8.5h10v4h-4.7"/><circle {FILL} cx="10" cy="14" r="1.3"/>'),
    "duplicate": ("Duplicate", "plus.square.on.square", "Library card menu", '<rect x="8" y="8" width="12.5" height="12.5" rx="2.5"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/><path d="M14.25 11.5V17M11.5 14.25H17"/>'),
    "delete": ("Delete", "trash", "Library card menu", '<path d="M4 7h16"/><path d="M9.5 7V5a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v2"/><path d="M6 7l1 12.2A2 2 0 0 0 9 21h6a2 2 0 0 0 2-1.8L18 7"/><path d="M10 11v6M14 11v6"/>'),
    "our-player": ("Our player", "circle.fill", "Add menu", f'<circle {FILL} cx="12" cy="12" r="7.5"/>'),
    "their-player": ("Their player", "circle", "Add menu", '<circle cx="12" cy="12" r="7"/>'),
    "ball": ("Ball", "soccerball", "Add menu", f'<circle cx="12" cy="12" r="8.5"/><path {FILL} d="M12 8.8l3.04 2.21-1.16 3.58h-3.76l-1.16-3.58z"/><path d="M12 8.8V3.5M15.04 11.01l5.04-1.64M13.88 14.59l3.12 4.29M10.12 14.59 7 18.88M8.96 11.01 3.92 9.37"/>'),
    "cone": ("Cone", "cone", "Add menu", '<path d="M10 4h4l4 14.5H6z"/><path d="M3.5 20.5h17"/><path d="M8 12h8"/>'),
    "camera-flat": ("Flat camera", "(already custom)", "Playback nav bar", '<rect x="6" y="3" width="12" height="18" rx="1.5"/><path d="M6 12h12"/>'),
    "camera-broadcast": ("Broadcast camera", "(already custom)", "Playback nav bar", '<path d="M8 5h8l5 14H3z"/><path d="M5.2 12.5h13.6"/>'),
    "steps": ("Steps", "(new)", "iPad steps list header, docs", f'<rect x="2.5" y="6" width="5" height="12" rx="1.5"/><rect {SOLID} x="9.5" y="6" width="5" height="12" rx="1.5"/><rect x="16.5" y="6" width="5" height="12" rx="1.5"/>'),
    "note": ("Step note", "(new)", "Step actions: Note", '<path d="M3.5 14c1.5-4 3-4 4 0s2.5 4 4 0 2.5-4 4 0 2.5 3 5-1"/><path d="M3.5 20h17"/>'),
    "duration": ("Duration", "(new)", "Step actions: time", '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 13.5v-4M10 2.5h4M12 2.5V6M18.2 7.3l1.4-1.4"/>'),
    "pitch": ("Pitch", "(new)", "Title menu: Pitch", '<rect x="4.5" y="2.5" width="15" height="19" rx="1.5"/><path d="M4.5 12h15"/><circle cx="12" cy="12" r="2.5"/><path d="M8.5 2.5v3h7v-3M8.5 21.5v-3h7v3"/>'),
    "image": ("Image", "(new)", "Export: Image preset", '<rect x="3" y="4.5" width="18" height="15" rx="2.5"/><path d="M3.5 17l5.5-5.5 4 4 2.5-2.5 5 5"/><circle cx="16" cy="9" r="1.5"/>'),
    "library": ("Library", "(new)", "Back to your tactics", '<rect x="3.5" y="3.5" width="7.5" height="7.5" rx="1.8"/><rect x="13" y="3.5" width="7.5" height="7.5" rx="1.8"/><rect x="3.5" y="13" width="7.5" height="7.5" rx="1.8"/><rect x="13" y="13" width="7.5" height="7.5" rx="1.8"/>'),
}

# The draw panel's tools, as ToolIcon draws them (24 × 24, its own colours: line style and colour both carry meaning).
TOOLS = {
    "run": ("Run", "solid line · the player follows it", '<path d="M3 12h18" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round"/>'),
    "pass": ("Pass", "dashed line · the ball follows it", '<path d="M3 12h18" stroke="#C6FF3D" stroke-width="2.6" stroke-linecap="round" stroke-dasharray="4 3"/>'),
    "dribble": ("Dribble", "wavy line · player and ball follow it", '<path d="M3 12l3-3 3 6 3-6 3 6 3-6 3 3" fill="none" stroke="#FFD84A" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'),
    "press": ("Press", "chevrons · the player closes in", '<path d="M6 7l5 5-5 5M12 7l5 5-5 5" fill="none" stroke="#FF6B4A" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>'),
    "zone": ("Zone", "see-through box · drag across the grass", '<rect x="3" y="5" width="18" height="14" rx="1" fill="rgba(198,255,61,.13)" stroke="rgba(198,255,61,.72)" stroke-width="1.8"/>'),
    "line": ("Line", "joins a unit · tap the last player again to finish", '<path d="M3 15l9-6 9 4" fill="none" stroke="#C6FF3D" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><g fill="#C6FF3D"><circle cx="3" cy="15" r="2.2"/><circle cx="12" cy="9" r="2.2"/><circle cx="21" cy="13" r="2.2"/></g>'),
    "glow": ("Glow", "rings follow a player · heat stays on the grass", '<circle cx="12" cy="12" r="3.2" fill="#FF5A2E"/><circle cx="12" cy="12" r="6.5" fill="none" stroke="#C6FF3D" stroke-opacity=".8" stroke-width="1.6"/><circle cx="12" cy="12" r="10" fill="none" stroke="#C6FF3D" stroke-opacity=".4" stroke-width="1.4"/>'),
}


def svg(name, size=24, cls="ic", label=None):
    a = f'role="img" aria-label="{label}"' if label else 'aria-hidden="true"'
    return f'<svg class="{cls}" width="{size}" height="{size}" viewBox="0 0 24 24" {a}><use href="#i-{name}"/></svg>'


def sprite_defs():
    return "".join(f'<symbol id="i-{n}" viewBox="0 0 24 24"><g {STROKE}>{v[3]}</g></symbol>' for n, v in ICONS.items()) + \
        "".join(f'<symbol id="t-{n}" viewBox="0 0 24 24">{v[2]}</symbol>' for n, v in TOOLS.items())


def sprite_file():
    return ('<svg xmlns="http://www.w3.org/2000/svg" style="display:none">\n' +
            "\n".join(f'  <symbol id="cs-{n}" viewBox="0 0 24 24"><title>{v[0]}</title><g {STROKE}>{v[3]}</g></symbol>'
                      for n, v in ICONS.items()) +
            "\n" + "\n".join(f'  <symbol id="cs-tool-{n}" viewBox="0 0 24 24"><title>{v[0]}</title>{v[2]}</symbol>'
                             for n, v in TOOLS.items()) + "\n</svg>\n")


def standalone(name):
    v = ICONS[name]
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g {STROKE}>{v[3]}</g></svg>\n'
