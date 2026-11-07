// Draws the pitch, arrows and tokens as SVG from normalised coordinates (D-05), the way BoardRenderer will.
// Colours come from the CSS tokens on :root, so the mockup has one source of truth.
const css = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const TOKENS = HERO.tokens;
const STEPS = HERO.phases[0].steps;
const tokenById = id => TOKENS.find(t => t.id === id);

const Board = {
  ratio: 105 / 68,
  radius: W => W * 0.038,
  pt: (p, W, H) => [p.x * W, (1 - p.y) * H],

  // look "bc" is the broadcast pitch (D-65): near-black, faint stripes, thinner-looking lines at lower opacity.
  pitch(W, H, look) {
    const bc = look === "bc", s = W / 68, cx = W / 2, L = css(bc ? "--bc-line" : "--chalk"), w = 1.4 * (W / 345);
    let out = "";
    for (let i = 0; i < 10; i++) out += `<rect x="0" y="${i * H / 10}" width="${W}" height="${H / 10 + .5}" fill="${css(i % 2 ? (bc ? "--bc-pitch-b" : "--pitch-b") : (bc ? "--bc-pitch-a" : "--pitch-a"))}"/>`;
    out += `<g fill="none" stroke="${L}" stroke-width="${w}" stroke-linecap="round"><rect x="0" y="0" width="${W}" height="${H}"/>`;
    out += `<line x1="0" y1="${H / 2}" x2="${W}" y2="${H / 2}"/><circle cx="${cx}" cy="${H / 2}" r="${9.15 * s}"/><circle cx="${cx}" cy="${H / 2}" r="${1.4 * w}" fill="${L}"/>`;
    for (const top of [true, false]) {
      const e = top ? 0 : H, d = top ? 1 : -1, by = e + d * 16.5 * s, dx = 7.31 * s;
      out += `<rect x="${cx - 20.16 * s}" y="${top ? e : e - 16.5 * s}" width="${40.32 * s}" height="${16.5 * s}"/>`;
      out += `<rect x="${cx - 9.16 * s}" y="${top ? e : e - 5.5 * s}" width="${18.32 * s}" height="${5.5 * s}"/>`;
      out += `<circle cx="${cx}" cy="${e + d * 11 * s}" r="${1.4 * w}" fill="${L}"/>`;
      out += `<path d="M ${cx - dx} ${by} A ${9.15 * s} ${9.15 * s} 0 0 ${top ? 0 : 1} ${cx + dx} ${by}"/>`;
    }
    return out + "</g>";
  },

  arrow(a, W, H, positions, opacity = 1) {
    const k = W / 345, r = Board.radius(W), P = a.points.map(p => Board.pt(p, W, H));
    const last = P[P.length - 1], prev = P[P.length - 2];
    // An arrow that ends on a player stops short of the disc, so its head stays visible.
    if (Object.values(positions).some(q => { const [qx, qy] = Board.pt(q, W, H); return Math.hypot(qx - last[0], qy - last[1]) < r * 1.2; })) {
      const len = Math.hypot(last[0] - prev[0], last[1] - prev[1]), cut = Math.min(r * 1.35, len / 2);
      P[P.length - 1] = [last[0] - (last[0] - prev[0]) / len * cut, last[1] - (last[1] - prev[1]) / len * cut];
    }
    const col = css(`--${a.kind}`), sw = 2.6 * k;
    let d = `M ${P[0].join(" ")}`;
    if (a.kind === "dribble") {
      for (let i = 1; i < P.length; i++) {
        const [ax, ay] = P[i - 1], [bx, by] = P[i], len = Math.hypot(bx - ax, by - ay), n = Math.max(2, Math.round(len / (9 * k)));
        const nx = -(by - ay) / len, ny = (bx - ax) / len;
        for (let j = 1; j <= n; j++) { const t = j / n, amp = j === n ? 0 : (j % 2 ? 3.5 : -3.5) * k; d += ` L ${ax + (bx - ax) * t + nx * amp} ${ay + (by - ay) * t + ny * amp}`; }
      }
    } else d += P.slice(1).map(p => ` L ${p.join(" ")}`).join("");
    const [ex, ey] = P[P.length - 1], [px, py] = P[P.length - 2], ang = Math.atan2(ey - py, ex - px), h = 9 * k;
    const head = `M ${ex - h * Math.cos(ang - .45)} ${ey - h * Math.sin(ang - .45)} L ${ex} ${ey} L ${ex - h * Math.cos(ang + .45)} ${ey - h * Math.sin(ang + .45)}`;
    const dash = a.kind === "pass" ? `stroke-dasharray="${7 * k} ${5 * k}"` : "";
    return `<g opacity="${opacity}" fill="none" stroke="${col}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"><path d="${d}" ${dash}/><path d="${head}"/></g>`;
  },

  token(id, p, W, H, positions, opts = {}) {
    let [x, y] = Board.pt(p, W, H);
    const r = Board.radius(W), t = tokenById(id), dim = opts.dim && opts.selected !== id ? .35 : 1;
    if (t.kind === "ball") {
      const carried = TOKENS.some(o => o.kind === "player" && positions[o.id] && Math.hypot(...Board.pt(positions[o.id], W, H).map((v, i) => v - [x, y][i])) < r * 1.2);
      if (carried) { x += r * .95; y += r * .95; }  // at the carrier's feet, never over the number
      return `<circle opacity="${dim}" cx="${x}" cy="${y}" r="${r * .42}" fill="${css("--ball")}" stroke="${css("--bg")}" stroke-width="${r * .14}"/>`;
    }
    const num = `<text x="${x}" y="${y + r * .36}" text-anchor="middle" font-family="${css("--font-ui")}" font-weight="800" font-size="${r * 1.05}"`;
    let s = opts.selected === id ? `<circle cx="${x}" cy="${y}" r="${r * 1.45}" fill="none" stroke="${css("--text")}" stroke-width="${r * .14}"/>` : "";  // white chalk: shows on every kit (UI-BRIEF §1)
    if (t.side === "home") s += `<circle cx="${x}" cy="${y}" r="${r}" fill="${css("--home")}"/>${num} fill="${css("--home-ink")}">${t.number}</text>`;
    else s += `<circle cx="${x}" cy="${y}" r="${r * .9}" fill="${css("--away-inner")}" stroke="${css("--away")}" stroke-width="${r * .24}"/>${num} fill="${css("--away-ink")}">${t.number}</text>`;
    return `<g opacity="${dim}">${s}</g>`;
  },

  // A pitch drawing plus one invisible 44 pt button per token, like the accessibility layer over the Canvas.
  html(W, positions, arrows = [], opts = {}) {
    const H = W * Board.ratio;
    let svg = Board.pitch(W, H, opts.look);
    if (opts.under) svg += opts.under(W, H, positions);  // zones, heat, shape lines and glow rings lie under everything (D-65)
    (opts.trails || []).forEach(a => svg += Board.arrow(a, W, H, positions, .3));
    arrows.forEach(a => svg += Board.arrow(a, W, H, positions));
    if (opts.stroke) svg += `<path d="${opts.stroke.map((p, i) => (i ? "L" : "M") + Board.pt(p, W, H).join(" ")).join(" ")}" fill="none" stroke="${css("--run")}" stroke-width="3" stroke-linecap="round" stroke-dasharray="1 0"/>`;
    TOKENS.map(t => t.id).sort((a, b) => (tokenById(a).kind === "ball") - (tokenById(b).kind === "ball"))
      .forEach(id => positions[id] && (svg += Board.token(id, positions[id], W, H, positions, opts)));
    let hits = "";
    if (opts.hits !== false) TOKENS.filter(t => t.kind === "player" && positions[t.id]).forEach(t => {
      const [x, y] = Board.pt(positions[t.id], W, H);
      const role = t.roleID ? t.roleID.replace(/-/g, " ") : "player";
      hits += `<button class="hit" data-testid="board.token.${t.id}" aria-label="Number ${t.number}, ${role}" style="left:${x - 22}px;top:${y - 22}px"></button>`;
    });
    return `<div class="board" style="width:${W}px;height:${H}px"><div class="pitch" data-testid="${opts.testid || "board.pitch"}"><svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${svg}</svg></div>${hits}</div>`;
  },
};
