// The broadcast look (D-65, D-66): zones, shape lines, glow rings, heat, and the tilted camera. Players stay the editor's
// numbered discs everywhere. Everything that lies on the grass is drawn in pitch-plane coordinates (normalised, D-05),
// so the flat board and the tilted camera share it.
let bcGradient = 0;
const BC = {
  // Marks on the grass, in the order they stack: zones, heat, shape lines, glow rings. `m` is one step's marks.
  under(m, opts = {}) {
    return (W, H, positions) => {
      const P = p => Board.pt(p, W, H), k = W / 345;
      let out = "";
      (m.zones || []).forEach(z => {
        const [x0, y0] = P({ x: z.x, y: z.y + z.h }), [x1, y1] = P({ x: z.x + z.w, y: z.y });
        out += `<rect x="${x0}" y="${y0}" width="${x1 - x0}" height="${y1 - y0}" fill="${css("--zone-fill")}" stroke="${css("--zone-stroke")}" stroke-width="${1.4 * k}"/>`;
        if (opts.handles) out += [[x0, y0], [x1, y0], [x0, y1], [x1, y1]].map(([hx, hy]) =>
          `<circle cx="${hx}" cy="${hy}" r="${6 * k}" fill="${css("--text")}" stroke="${css("--bg")}" stroke-width="${2 * k}"/>`).join("");
      });
      (m.heat || []).forEach(g => {
        const id = `heat${++bcGradient}`, [x, y] = P(g), r = (g.r || .1) * W;
        out += `<defs><radialGradient id="${id}"><stop offset="0" stop-color="${css("--heat-core")}" stop-opacity=".7"/>
          <stop offset=".35" stop-color="${css("--heat")}" stop-opacity=".55"/><stop offset="1" stop-color="${css("--heat")}" stop-opacity="0"/></radialGradient></defs>
          <ellipse cx="${x}" cy="${y}" rx="${r}" ry="${r * .8}" fill="url(#${id})"/>`;
      });
      (m.lines || []).forEach(l => {
        const pts = l.ids.filter(id => positions[id]).map(id => P(positions[id]));
        const kit = css(tokenById(l.ids[0]).side === "home" ? "--home" : "--away");
        out += `<polyline points="${pts.map(p => p.join(",")).join(" ")}" fill="none" stroke="${kit}" stroke-width="${2.2 * k}" stroke-linecap="round" stroke-linejoin="round" opacity=".9"/>`;
        if (opts.pending) out += `<circle cx="${pts.at(-1)[0]}" cy="${pts.at(-1)[1]}" r="${Board.radius(W) * 1.75}" fill="none" stroke="${kit}" stroke-width="${1.6 * k}" stroke-dasharray="${3 * k} ${3 * k}"/>`;
      });
      (m.rings || []).forEach(id => {
        if (!positions[id]) return;
        const [x, y] = P(positions[id]), kit = css(tokenById(id).side === "home" ? "--home" : "--away"), R = Board.radius(W);
        out += `<circle cx="${x}" cy="${y}" r="${R * 1.3}" fill="${kit}" fill-opacity="${css("--glow-fill-opacity")}"/>`;
        out += [[1.3, .95], [1.85, .6], [2.45, .3]].map(([f, o]) => `<circle cx="${x}" cy="${y}" r="${R * f}" fill="none" stroke="${kit}" stroke-width="${1.6 * k}" opacity="${o}"/>`).join("");
      });
      return out;
    };
  },

  // The tilted broadcast camera. The pitch plane (lines, marks, arrows, glow rings) is one SVG under a CSS perspective
  // transform, the way BoardRenderer will project the plane. Discs lie flat on the grass too, but are drawn by
  // placeDiscs below: each token has a 10 pt marker in the plane, and its projected box gives the disc's centre, size and
  // foreshortening, so the disc is an ellipse on the grass while its number stays upright and readable (D-66).
  // With numbers: "upright" (default) or "plane" (the number is painted on the grass and squashes with the disc).
  // cam: { pw: plane width, tilt: degrees, focus: the pitch y at the bottom edge of the view, cx: the pitch x at the centre
  // (the camera follows the ball), persp: eye distance, horizon: where the eye sits above the view, lift: how far that
// line sits above the bottom of the view }.
  tilted(vw, vh, positions, arrows, m, cam, testid = "board.pitch", numbers = BC.numbers) {
    const pw = cam.pw, ph = pw * Board.ratio, oy = ph * (1 - cam.focus);
    let svg = Board.pitch(pw, ph, "bc") + BC.under(m)(pw, ph, positions);
    arrows.forEach(a => svg += Board.arrow(a, pw, ph, positions));
    let markers = "";
    if (numbers === "plane") TOKENS.forEach(t => positions[t.id] && (svg += Board.token(t.id, positions[t.id], pw, ph, positions)));
    else markers = Object.entries(positions).map(([id, p]) => { const [x, y] = Board.pt(p, pw, ph);
      return `<i class="mk" data-id="${id}" style="left:${x - 5}px;top:${y - 5}px"></i>`; }).join("");
    BC.cams.push({ positions, pw });
    return `<div class="bc3d" data-testid="${testid}" data-cam="${BC.cams.length - 1}" style="width:${vw}px;height:${vh}px;perspective:${cam.persp}px;perspective-origin:50% ${cam.horizon}px">
      <div class="plane" style="width:${pw}px;height:${ph}px;left:${vw / 2 - (cam.cx ?? .5) * pw}px;top:${vh - oy - (cam.lift ?? 0)}px;transform-origin:50% ${oy}px;transform:rotateX(${cam.tilt}deg)">
      <svg width="${pw}" height="${ph}" viewBox="0 0 ${pw} ${ph}" aria-hidden="true">${svg}</svg>${markers}</div>
      <svg class="figs" width="${vw}" height="${vh}" viewBox="0 0 ${vw} ${vh}" aria-hidden="true"></svg></div>`;
  },
  cams: [],
  numbers: location.hash === "#plane-numbers" ? "plane" : "upright",
};

// Draws each disc flat on the grass (an ellipse with the projected size and foreshortening) with an upright number,
// far to near so nearer discs overlap farther ones. The ball sits at its carrier's feet, as in the editor.
function placeDiscs() {
  document.querySelectorAll(".bc3d").forEach(box => {
    const cam = BC.cams[box.dataset.cam], f = box.getBoundingClientRect(), R = Board.radius(cam.pw);
    const pts = [...box.querySelectorAll(".mk")].map(mk => {
      const r = mk.getBoundingClientRect();
      return { id: mk.dataset.id, x: r.left + r.width / 2 - f.left, y: r.top + r.height / 2 - f.top, s: r.width / 10, k: r.height / r.width };
    }).filter(p => p.y > -40 && p.y < f.height + 40).sort((a, b) => a.y - b.y || (tokenById(a.id).kind === "ball") - (tokenById(b.id).kind === "ball"));
    // Two passes: every disc far to near, then every number, so a disc that overlaps a neighbour never hides its number.
    const nums = [];
    box.querySelector(".figs").innerHTML = pts.map(p => {
      const t = tokenById(p.id), r = R * p.s;
      if (t.kind === "ball") {
        const carried = pts.some(o => o.id !== p.id && tokenById(o.id).kind === "player" && Math.hypot(o.x - p.x, (o.y - p.y) / p.k) < r * 1.2);
        const bx = p.x + (carried ? r * .95 : 0), by = p.y + (carried ? r * .95 * p.k : 0);
        return `<ellipse cx="${bx}" cy="${by}" rx="${r * .42}" ry="${r * .42 * p.k}" fill="${css("--ball")}" stroke="${css("--bg")}" stroke-width="${r * .14}"/>`;
      }
      const num = `<text x="${p.x}" y="${p.y + r * .36}" text-anchor="middle" font-family="${css("--font-ui")}" font-weight="800" font-size="${r * 1.05}"`;
      nums.push(`${num} fill="${css(t.side === "home" ? "--home-ink" : "--away-ink")}">${t.number}</text>`);
      return t.side === "home" ? `<ellipse cx="${p.x}" cy="${p.y}" rx="${r}" ry="${r * p.k}" fill="${css("--home")}"/>`
        : `<ellipse cx="${p.x}" cy="${p.y}" rx="${r * .9}" ry="${r * .9 * p.k}" fill="${css("--away-inner")}" stroke="${css("--away")}" stroke-width="${r * .24}"/>`;
    }).join("") + nums.join("");
  });
}
