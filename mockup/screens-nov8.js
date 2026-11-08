// Chime's 8 Nov decisions: D-72 Straight / Curved arrows, D-73 the iPad board using the big screen, D-74 small wide
// library cards with the pitch turned sideways. Built from the broadcast parts in screens-broadcast.js and board.js.
//
// Notes for engineering
// - D-72: the Shape row shows only for Run, Pass, Dribble and Press. For Zone, Line and Glow it is hidden and the
//   panel is the approved draw--tools panel (help line on top). The switch sets how the next arrow is drawn; Straight is
//   the default. A curved arrow is a quadratic bend whose middle point is the dot (the line passes through it); the file
//   stores sampled path points, so the format doesn't change. Straight arrows have no dot.
// - D-73: iPad landscape puts the nav row at the top of the right column, so the pitch runs from under the status bar
//   to the toolbar (580 x 896 pt). An upright pitch can't fill the portrait width: 1032 pt wide would be 1594 pt tall,
//   so portrait is as tall as the screen allows (724 pt wide) with one row of controls under it.
// - D-74: cards draw discs at 1.5x the board's size (r = 5.7% of the card's pitch height) with a thin dark outline.
//   Numbers are drawn only when they come out at 7 pt or more, which needs a pitch at least 181 pt long (a card at
//   least 201 pt wide with 8 pt padding and its 2 pt border). Below that (every iPhone card) the discs have no numbers: home filled, away rings (D-15).
//   In cards, pitch lines keep at least 0.75 pt and marks/arrows at least 1.2 pt so they hold at the small size.

const ARROW_KINDS = ["run", "pass", "dribble", "press"];
const quad = (a, c, b, t) => ({ x: (1 - t) ** 2 * a.x + 2 * (1 - t) * t * c.x + t * t * b.x, y: (1 - t) ** 2 * a.y + 2 * (1 - t) * t * c.y + t * t * b.y });
// The dot is the curve's middle point (t = 0.5), so the control point is 2 * mid - (from + to) / 2.
const control = c => ({ x: 2 * c.mid.x - (c.from.x + c.to.x) / 2, y: 2 * c.mid.y - (c.from.y + c.to.y) / 2 });

// One curved arrow, in the same style as Board.arrow: solid run and press, dashed pass, wavy dribble along the curve.
function curveArrow(c, W, H, positions) {
  const k = W / 345, r = Board.radius(W), ctl = control(c);
  const P = Array.from({ length: 65 }, (_, i) => Board.pt(quad(c.from, ctl, c.to, i / 64), W, H));
  const [ex, ey] = P.at(-1);
  if (Object.values(positions).some(q => { const [qx, qy] = Board.pt(q, W, H); return Math.hypot(qx - ex, qy - ey) < r * 1.2; }))
    while (P.length > 3 && Math.hypot(P.at(-1)[0] - ex, P.at(-1)[1] - ey) < r * 1.35) P.pop();
  const L = [0];
  for (let i = 1; i < P.length; i++) L.push(L[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]));
  const at = s => {
    let i = L.findIndex(v => v >= s); if (i < 1) i = s <= 0 ? 1 : L.length - 1;
    const [ax, ay] = P[i - 1], [bx, by] = P[i], seg = Math.hypot(bx - ax, by - ay) || 1, f = Math.min(1, Math.max(0, (s - L[i - 1]) / seg));
    return [ax + (bx - ax) * f, ay + (by - ay) * f, -(by - ay) / seg, (bx - ax) / seg];
  };
  const total = L.at(-1);
  let d = `M ${P[0].join(" ")}`;
  if (c.kind === "dribble") {
    const n = Math.max(2, Math.round(total / (9 * k)));
    for (let j = 1; j <= n; j++) { const [x, y, nx, ny] = at(j / n * total), amp = j === n ? 0 : (j % 2 ? 3.5 : -3.5) * k; d += ` L ${x + nx * amp} ${y + ny * amp}`; }
  } else d += P.slice(1).map(p => ` L ${p.join(" ")}`).join("");
  const [hx, hy] = P.at(-1), [px, py] = at(total - 6 * k), ang = Math.atan2(hy - py, hx - px), h = 9 * k;
  const head = `M ${hx - h * Math.cos(ang - .45)} ${hy - h * Math.sin(ang - .45)} L ${hx} ${hy} L ${hx - h * Math.cos(ang + .45)} ${hy - h * Math.sin(ang + .45)}`;
  const dash = c.kind === "pass" ? `stroke-dasharray="${7 * k} ${5 * k}"` : "";
  return `<g fill="none" stroke="${css(`--${c.kind}`)}" stroke-width="${2.6 * k}" stroke-linecap="round" stroke-linejoin="round"><path d="${d}" ${dash}/><path d="${head}"/></g>`;
}
// The middle dot that nudges the bend: the same white dot as a zone corner.
const bendDot = (p, W, H) => { const k = W / 345, [x, y] = Board.pt(p, W, H); return `<circle cx="${x}" cy="${y}" r="${6 * k}" fill="${css("--text")}" stroke="${css("--bg")}" stroke-width="${2 * k}"/>`; };
const curves = (list, dot) => (W, H, positions) => list.map(c => curveArrow(c, W, H, positions)).join("") + (dot ? bendDot(dot, W, H) : "");
const bendHit = (p, W, left, top) => { const [x, y] = Board.pt(p, W, W * Board.ratio);
  return `<button class="hit" data-testid="draw.bend.handle" aria-label="Bend of 3's run. Drag to change the curve." style="left:${left + x - 22}px;top:${top + y - 22}px"></button>`; };

// Step 2: 3 overlaps down the left while 11 drives inside.
const RUN3 = { kind: "run", from: { x: .15, y: .24 }, mid: { x: .05, y: .41 }, to: { x: .07, y: .58 } };
const DRIB11 = { kind: "dribble", from: { x: .15, y: .66 }, mid: { x: .27, y: .66 }, to: { x: .36, y: .76 } };
const STRAIGHT = [{ kind: "dribble", points: [DRIB11.from, DRIB11.to] }, { kind: "run", points: [RUN3.from, RUN3.to] }];

// The Draw panel with the Shape row (D-72). Arrows get the switch; marks get their help line instead.
const shapeRow = shape => `<div class="shape-row">${txt("draw.shape-label", "Shape", "label")}
  <div class="seg" role="radiogroup" aria-label="Arrow shape">${[["straight", "Straight"], ["curved", "Curved"]].map(([s, l]) =>
    `<button role="radio" data-testid="draw.shape.${s}" aria-checked="${s === shape}" aria-selected="${s === shape}">${l}</button>`).join("")}</div></div>`;
const panelBody = (on, shape, tileH) => (ARROW_KINDS.includes(on) ? shapeRow(shape) : txt("draw.kind-help", HELP[on], "", "p", "margin:2px 6px 4px;font:var(--t-caption);color:var(--muted)"))
  + ["run pass dribble press", "zone line glow"].map(row => `<div class="kinds" style="grid-template-columns:repeat(${row.split(" ").length},1fr);margin-top:5px;--tile-h:${tileH}px">${row.split(" ").map(k =>
    `<button role="tab" data-testid="draw.kind.${k}" aria-selected="${k === on}" class="tile" style="${k === on ? "border-color:var(--accent)" : ""}"><svg width="40" height="22" viewBox="0 0 24 24" fill="none" stroke="var(${KIND_COLOUR[k]})" stroke-linecap="round" aria-hidden="true">${KINDS[k][1]}</svg>${KINDS[k][0]}</button>`).join("")}</div>`).join("");
const shapePanel = (on, shape) => `<div class="abs" style="left:16px;right:16px;bottom:26px;background:var(--surface-2);border-radius:24px;padding:6px 10px 8px;box-shadow:0 8px 30px rgba(0,0,0,.5)">${panelBody(on, shape, 48)}</div>`;
const hint2 = text => txt("draw.hint", text, "note", "p", "position:absolute;top:626px;left:24px;right:24px;margin:0;text-align:center;font-size:17px;line-height:22px;color:var(--muted)");

// iPad parts (D-73).
const ipadStatus = () => `<div class="ipad-status" data-testid="status"><span>9:41&nbsp;&nbsp;Sat 8 Nov</span><span>100%</span></div>`;
const at = (html, left, top) => html.replace('class="board" style="', `class="board" style="left:${left}px;top:${top}px;`);
const chips = (current, cls = "") => `<div class="chips ${cls}">${STEPS.map((s, i) =>
  btn(`steps.chip.${i + 1}`, `<b>${i + 1}</b><small>${s.duration} s</small>`, `step ${i === current ? "on" : ""}`, `Step ${i + 1}, ${s.duration} seconds`)).join("")}${btn("steps.add", "+", "step add", "Add a step")}</div>`;
const ipadToolbar = drawing => {
  const off = drawing ? 'aria-disabled="true" style="opacity:.4"' : "";
  return `<div class="toolbar" style="height:88px;justify-content:center;gap:72px;padding-top:8px">
  ${btn("toolbar.formation", `${ic("formation")}Formation`, "tool", "", off)}${btn("toolbar.add", `${ic("add")}Add`, "tool", "", off)}
  ${btn("toolbar.play", `<span class="disc" style="color:var(--accent-ink)">${ic("play")}</span>Play`, "tool primary", "", off)}
  ${btn("toolbar.draw", `${ic("draw")}Draw`, "tool", "", drawing ? 'aria-pressed="true" style="color:var(--accent)"' : "")}${btn("toolbar.export", `${ic("export")}Export`, "tool", "", off)}</div><div class="home-bar"></div>`;
};
const IPAD_W = 580, IPAD_TOP = 32, IPAD_LEFT = 24;  // landscape pitch: 580 x 896 pt, from under the status bar to the toolbar
const stepsBlock = i => `<div>${txt("steps.title", "Steps", "col-head", "h2")}${chips(i)}
  ${txt("steps.current", `Step ${i + 1} of ${STEPS.length} · ${STEPS[i].duration} s`, "", "p", "margin:14px 0 2px;font:var(--t-caption);color:var(--muted)")}
  ${txt("steps.note", STEPS[i].note, "note", "p", "margin:0;font-size:22px")}</div>`;
const rowCard = (labelId, label, buttons) => `<div class="row-card">${txt(labelId, label, "", "span", "flex:1;font:var(--t-headline)")}${buttons.map(([id, l]) => btn(id, l, "col-btn")).join("")}</div>`;

// Library cards (D-74): the whole pitch turned sideways, attacking right; numbers stay upright.
const thick = (svg, min) => svg.replace(/stroke-width="([\d.]+)"/g, (m, v) => `stroke-width="${Math.max(+v, min)}"`);
function thumbArrow(a, W, H, positions, r) {
  const k = .55, P = a.points.map(p => Board.pt(p, W, H)), last = P.at(-1), prev = P.at(-2);
  if (Object.values(positions).some(q => { const [qx, qy] = Board.pt(q, W, H); return Math.hypot(qx - last[0], qy - last[1]) < r * 1.2; })) {
    const len = Math.hypot(last[0] - prev[0], last[1] - prev[1]), cut = Math.min(r * 1.4, len / 2);
    P[P.length - 1] = [last[0] - (last[0] - prev[0]) / len * cut, last[1] - (last[1] - prev[1]) / len * cut];
  }
  let d = `M ${P[0].join(" ")}`;
  if (a.kind === "dribble") for (let i = 1; i < P.length; i++) {
    const [ax, ay] = P[i - 1], [bx, by] = P[i], len = Math.hypot(bx - ax, by - ay), n = Math.max(2, Math.round(len / (9 * k))), nx = -(by - ay) / len, ny = (bx - ax) / len;
    for (let j = 1; j <= n; j++) { const t = j / n, amp = j === n ? 0 : (j % 2 ? 3.5 : -3.5) * k; d += ` L ${ax + (bx - ax) * t + nx * amp} ${ay + (by - ay) * t + ny * amp}`; }
  } else d += P.slice(1).map(p => ` L ${p.join(" ")}`).join("");
  const [ex, ey] = P.at(-1), [px, py] = P.at(-2), ang = Math.atan2(ey - py, ex - px), h = 9 * k;
  const head = `M ${ex - h * Math.cos(ang - .45)} ${ey - h * Math.sin(ang - .45)} L ${ex} ${ey} L ${ex - h * Math.cos(ang + .45)} ${ey - h * Math.sin(ang + .45)}`;
  return `<g fill="none" stroke="${css(`--${a.kind}`)}" stroke-width="${2.6 * k}" stroke-linecap="round" stroke-linejoin="round"><path d="${d}" ${a.kind === "pass" ? `stroke-dasharray="${7 * k} ${5 * k}"` : ""}/><path d="${head}"/></g>`;
}
const MIN_NUMBER_PT = 7;
function sideways(L, positions, arrows = [], marks = {}) {
  const Wd = L / Board.ratio, r = Wd * .057, numbers = r * 1.05 >= MIN_NUMBER_PT;
  // Draw upright (W = Wd, H = L), then turn it a quarter clockwise: own goal on the left, attacking right.
  let up = thick(Board.pitch(Wd, L, "bc"), .75) + thick(BC.under(marks)(Wd, L, positions), 1.2) + arrows.map(a => thumbArrow(a, Wd, L, positions, r)).join("");
  const pt = p => [p.y * L, p.x * Wd], ids = TOKENS.filter(t => positions[t.id]);
  let discs = "", nums = "";
  ids.filter(t => t.kind === "player").forEach(t => {
    const [x, y] = pt(positions[t.id]);
    discs += t.side === "home" ? `<circle cx="${x}" cy="${y}" r="${r}" fill="${css("--home")}" stroke="${css("--bg")}" stroke-width=".6"/>`
      : `<circle cx="${x}" cy="${y}" r="${r * .9}" fill="${css("--away-inner")}" stroke="${css("--away")}" stroke-width="${r * .24}"/><circle cx="${x}" cy="${y}" r="${r * 1.02 + .3}" fill="none" stroke="${css("--bg")}" stroke-width=".6"/>`;
    if (numbers) nums += `<text x="${x}" y="${y + r * .36}" text-anchor="middle" font-family="${css("--font-ui")}" font-weight="800" font-size="${r * 1.05}" fill="${css(t.side === "home" ? "--home-ink" : "--away-ink")}">${t.number}</text>`;
  });
  ids.filter(t => t.kind === "ball").forEach(t => {
    let [x, y] = pt(positions[t.id]);
    if (ids.some(o => o.kind === "player" && Math.hypot(...pt(positions[o.id]).map((v, i) => v - [x, y][i])) < r * 1.2)) { x += r * .95; y += r * .95; }
    discs += `<circle cx="${x}" cy="${y}" r="${r * .45}" fill="${css("--ball")}" stroke="${css("--bg")}" stroke-width=".6"/>`;
  });
  return `<svg width="${L}" height="${Wd}" viewBox="0 0 ${L} ${Wd}" aria-hidden="true"><g transform="translate(${L} 0) rotate(90)">${up}</g>${discs}${nums}</svg>`;
}

// Tactics in the library. Names are our own words (D-13). Positions come from presets/formations.json.
const shift = (base, over) => ({ ...base, ...over });
const LIB = [
  ["Overlap down the left", 5, pos(0), STEPS[0].arrows, {}],
  ["Press their keeper", 3, fromFormation("4-4-2", .22), [], { zones: [{ x: .18, y: .8, w: .64, h: .2 }] }],
  ["Back three, then five", 4, fromFormation("3-4-3"), [], { lines: [{ ids: ["h5", "h4", "h6"] }] }],
  ["Hold the edge of the box", 2, fromFormation("5-3-2"), [], { heat: [{ x: .5, y: .27, r: .14 }] }],
  ["Switch to the far side", 4, fromFormation("4-3-3", .08), [{ kind: "pass", points: [{ x: .32, y: .55 }, { x: .85, y: .74 }] }], {}],
  ["Third-man run through the middle", 5, fromFormation("4-2-3-1", .06), [{ kind: "pass", points: [{ x: .38, y: .42 }, { x: .5, y: .62 }] }, { kind: "run", points: [{ x: .62, y: .42 }, { x: .6, y: .84 }] }], {}],
  ["Near-post corner flick", 3, shift(fromFormation("4-4-2", .26), { ball: { x: .99, y: .99 } }), [{ kind: "pass", points: [{ x: .99, y: .99 }, { x: .6, y: .9 }] }], { heat: [{ x: .58, y: .9, r: .1 }] }],
  ["Low block after we score", 3, fromFormation("5-3-2", -.02), [], { zones: [{ x: .08, y: .04, w: .84, h: .38 }] }],
  ["Back-post free kick", 2, shift(fromFormation("4-4-2", .22), { ball: { x: .2, y: .72 } }), [{ kind: "pass", points: [{ x: .2, y: .72 }, { x: .74, y: .93 }] }], {}],
  ["Counter from our own box", 6, fromFormation("4-3-3"), [{ kind: "dribble", points: [{ x: .68, y: .47 }, { x: .7, y: .68 }] }, { kind: "run", points: [{ x: .15, y: .66 }, { x: .3, y: .88 }] }], {}],
  ["Sunday kick-off routine", 3, shift(fromFormation("4-4-2"), { h10: { x: .42, y: .5 }, h9: { x: .58, y: .5 }, h8: { x: .34, y: .38 }, h6: { x: .66, y: .38 }, ball: { x: .5, y: .5 } }), [{ kind: "pass", points: [{ x: .5, y: .5 }, { x: .34, y: .38 }] }], {}],
  ["Striker drops, 10 runs beyond", 4, fromFormation("4-2-3-1"), [{ kind: "run", points: [{ x: .5, y: .7 }, { x: .34, y: .64 }] }, { kind: "run", points: [{ x: .5, y: .56 }, { x: .58, y: .84 }] }], {}],
  ["Full-backs step inside", 4, fromFormation("4-3-3"), [{ kind: "run", points: [{ x: .15, y: .24 }, { x: .35, y: .36 }] }, { kind: "run", points: [{ x: .85, y: .24 }, { x: .65, y: .36 }] }], {}],
  ["Throw-in down the line", 2, shift(fromFormation("4-4-2", .1), { ball: { x: .01, y: .6 } }), [{ kind: "pass", points: [{ x: .01, y: .6 }, { x: .15, y: .72 }] }], {}],
  ["Trap them on the touchline", 3, fromFormation("4-1-4-1", .12), [], { zones: [{ x: .62, y: .5, w: .38, h: .3 }], rings: ["h7"] }],
  ["Long ball, win the second", 3, fromFormation("4-4-2"), [{ kind: "pass", points: [{ x: .62, y: .2 }, { x: .62, y: .76 }] }], { heat: [{ x: .58, y: .72, r: .12 }] }],
  ["Goal kick: play out short", 5, fromFormation("4-3-3", -.03), [{ kind: "pass", points: [{ x: .5, y: .03 }, { x: .36, y: .17 }] }], {}],
  ["Wing-back underlap", 4, fromFormation("3-5-2", .04), [{ kind: "run", points: [{ x: .9, y: .48 }, { x: .72, y: .8 }] }], {}],
  ["Cut-back from the byline", 3, shift(fromFormation("4-3-3", .18), { h11: { x: .1, y: .95 }, h8: { x: .4, y: .8 }, ball: { x: .1, y: .95 } }), [{ kind: "pass", points: [{ x: .1, y: .95 }, { x: .4, y: .8 }] }], { rings: ["h8"] }],
  ["Keeper sweeps behind a high line", 2, fromFormation("4-3-3", .1), [], { lines: [{ ids: ["h3", "h5", "h4", "h2"] }] }],
  ["Two up top, both press", 3, fromFormation("3-5-2", .2), [{ kind: "press", points: [{ x: .4, y: .88 }, { x: .4, y: .96 }] }, { kind: "press", points: [{ x: .6, y: .88 }, { x: .6, y: .96 }] }], {}],
  ["Late run from the edge", 3, fromFormation("4-1-4-1", .14), [{ kind: "run", points: [{ x: .38, y: .62 }, { x: .44, y: .9 }] }], {}],
];
const libCard = (n, [title, steps, positions, arrows, marks], L) => `<button class="tile lib-card" data-testid="library.card.${n}" aria-label="${title}, ${steps} steps">
  ${sideways(L, positions, arrows, marks)}<span class="lib-name">${title}</span><span class="lib-meta">${steps} steps</span></button>`;
const libArt = width => `<div class="abs" data-testid="library.art" style="left:0;right:0;top:0;height:200px;overflow:hidden;opacity:.5" aria-hidden="true">${staticBoard(width, 0, {}, { arrows: [] }).replace(/<g opacity="1">[\s\S]*?<\/g>/g, "").replace(/<circle opacity[^>]*>/g, "")}</div>
  <div class="abs" style="left:0;right:0;top:120px;height:80px;background:linear-gradient(rgba(11,15,20,0),var(--bg))"></div>`;

const PHONE_CARD = (393 - 48 - 2 * 10) / 3 - 16;          // 92.3 pt pitch in a 108 pt card (6 pt padding, 2 pt border): no numbers
const PAD_CARD = (1376 - 64 - 5 * 16) / 6 - 20;          // 185.3 pt pitch in a 205 pt card (8 pt padding, 2 pt border): numbers at 7.1 pt

const NOV8 = [
  ["draw--shape-straight", "D-72 · Draw › Run, Straight (default): the run joins where the stroke starts and ends", () => `${drawNav()}
    ${Board.html(W, pos(1), STRAIGHT, { look: "bc", selected: "h3" })}
    ${hint2("The run goes straight to where you lift.")}${shapePanel("run", "straight")}`],

  ["draw--shape-curved", "D-72 · Draw › Run, Curved: one smooth bend; the middle dot nudges it. Dribble stays wavy along its curve", () => `${drawNav()}
    ${Board.html(W, pos(1), [], { look: "bc", selected: "h3", under: curves([DRIB11, RUN3], RUN3.mid) })}${bendHit(RUN3.mid, W, 29.5, 104)}
    ${hint2("Drag the middle dot to change the bend.")}${shapePanel("run", "curved")}`],

  ["library--compact", "D-74 · Library on iPhone: small wide cards, 3 a row, pitch sideways (attacking right). Too small for numbers", () => `${status()}${libArt(393)}
    <div class="abs" style="top:64px;left:24px;right:24px">${txt("library.title", "Agmen", "", "h1", "font:var(--t-largetitle);margin:0")}
      ${txt("library.tagline", "Draw the move, not just the shape.", "note", "p", "margin:4px 0 0;color:var(--muted)")}</div>
    <div class="abs" style="top:164px;left:24px;right:24px">${btn("launch.new", `${ic("plus", 20)} New tactic`, "capsule", "", 'style="display:flex;align-items:center;justify-content:center;gap:8px"')}
      ${txt("library.recent", "Recent", "", "h2", "margin:24px 0 12px;font:var(--t-headline);color:var(--muted)")}
      <div class="lib-grid" style="grid-template-columns:repeat(3,1fr)">${LIB.slice(0, 12).map((t, i) => libCard(i + 1, t, PHONE_CARD)).join("")}</div></div>
    <div class="home-bar"></div>`],

  ["ipad-board--landscape", "D-73 · iPad landscape: upright pitch full height on the left; steps and the selected player on the right", () => `${ipadStatus()}
    ${at(Board.html(IPAD_W, pos(3), STEPS[3].arrows, { look: "bc", under: BC.under(M4), selected: "h3" }), IPAD_LEFT, IPAD_TOP)}
    <div class="col" style="left:628px;right:24px;top:28px">${navEdit().replace('class="nav"', 'class="nav" style="position:static;height:50px;margin:0 -12px"')}
      ${stepsBlock(3)}${rowCard("selection.label", "3 · Full-back", [["selection.edit", "Edit"], ["selection.run", "Draw run"], ["selection.delete", "Remove"]])}</div>
    ${ipadToolbar(false)}`, 1376, 1032],

  ["ipad-draw--landscape", "D-73 · iPad landscape, Draw: the tools live in the column; the toolbar stays, Draw lit", () => `${ipadStatus()}
    ${at(Board.html(IPAD_W, pos(1), [], { look: "bc", selected: "h3", under: curves([DRIB11, RUN3], RUN3.mid) }), IPAD_LEFT, IPAD_TOP)}${bendHit(RUN3.mid, IPAD_W, IPAD_LEFT, IPAD_TOP)}
    <div class="col" style="left:628px;right:24px;top:28px">
      <div class="nav" style="position:static;height:50px;margin:0 -12px">${btn("draw.cancel", ic("close"), "icon-btn", "Cancel drawing")}${txt("draw.title", "Draw", "title")}${btn("draw.done", ic("check"), "icon-btn", "Done", 'style="background:var(--accent);color:var(--accent-ink)"')}</div>
      <div>${txt("steps.title", "Steps", "col-head", "h2")}${chips(1)}</div>
      ${rowCard("draw.mark.label", "3's run · drag the dot to bend", [["draw.mark.remove", "Remove"]])}
      <div class="tools-card">${panelBody("run", "curved", 64)}</div>
      ${txt("draw.hint", "Start on a player to draw their run.", "note", "p", "margin:0;text-align:center;font-size:20px;color:var(--muted)")}</div>
    ${ipadToolbar(true)}`, 1376, 1032],

  ["ipad-board--portrait", "D-73 · iPad portrait: the pitch as big as the height allows (724 pt), one row of controls under it", () => `${ipadStatus()}
    ${navEdit().replace('class="nav"', 'class="nav" style="top:26px;left:12px;right:12px;height:50px"')}
    ${at(Board.html(724, pos(3), STEPS[3].arrows, { look: "bc", under: BC.under(M4), selected: "h3" }), 154, 84)}
    <div class="abs" style="left:24px;right:24px;top:1212px;height:72px;display:flex;align-items:center;gap:24px">${chips(3, "tight")}
      ${ctx("selection.label", "3 · Full-back", [["selection.edit", "Edit"], ["selection.run", "Draw run"], ["selection.delete", "Remove"]]).replace('class="ctx"', 'class="ctx" style="position:static;flex:1"')}</div>
    ${ipadToolbar(false)}`, 1032, 1376],

  ["ipad-library", "D-74 · iPad landscape library: 6 a row; cards are wide enough for upright numbers", () => `${ipadStatus()}${libArt(1376).replace("height:200px", "height:176px").replace("top:120px;height:80px", "top:96px;height:80px")}
    <div class="abs" style="top:56px;left:32px;right:32px;display:flex;align-items:flex-end;justify-content:space-between">
      <div>${txt("library.title", "Agmen", "", "h1", "font:var(--t-largetitle);margin:0")}${txt("library.tagline", "Draw the move, not just the shape.", "note", "p", "margin:4px 0 0;color:var(--muted)")}</div>
      ${btn("launch.new", `${ic("plus", 20)} New tactic`, "capsule", "", 'style="width:240px;display:flex;align-items:center;justify-content:center;gap:8px"')}</div>
    <div class="abs" style="top:156px;left:32px;right:32px">${txt("library.recent", "Recent", "", "h2", "margin:0 0 12px;font:var(--t-headline);color:var(--muted)")}
      <div class="lib-grid wide" style="grid-template-columns:repeat(6,1fr)">${LIB.map((t, i) => libCard(i + 1, t, PAD_CARD)).join("")}</div></div>
    <div class="home-bar"></div>`, 1376, 1032],
];

document.body.insertAdjacentHTML("beforeend", `<main class="gallery wide" id="gallery-nov8"><div class="section-head"><h2>8 Nov: arrow shape, iPad layout, small cards (D-72, D-73, D-74)</h2>
  <p>Straight / Curved switch for Run, Pass, Dribble and Press (hidden for Zone, Line and Glow, which keep their help line). iPad landscape: pitch full height on the left, column on the right. Library: wide cards with the pitch sideways. Numbers on card discs need a card at least 201 pt wide (7 pt text); smaller cards, like every iPhone card, show discs only.</p></div></main>`);
const nov8 = document.getElementById("gallery-nov8");
NOV8.forEach(([id, caption, render, w, h]) => {
  const wrap = document.createElement("div");
  wrap.innerHTML = `<p class="cap">${caption}</p><section class="frame${w ? " ipad" : ""}" data-screen="${id}" ${w ? `style="width:${w}px;height:${h}px"` : ""}>${render()}</section>`;
  nov8.appendChild(wrap);
});
