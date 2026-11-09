// The scenario mockup's frames (scenarios.html: phone; scenarios-ipad.html sets window.IPAD for the iPad frame).
const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;");
const txt = (id, text, cls = "", tag = "span", style = "") => `<${tag} data-testid="${id}" class="${cls}" ${style ? `style="${style}"` : ""}>${esc(text)}</${tag}>`;
const btn = (id, inner, cls = "", label = "", extra = "") => `<button data-testid="${id}" class="${cls}" ${label ? `aria-label="${esc(label)}"` : ""} ${extra}>${inner}</button>`;
const ICON = {
  close: '<path d="M6 6l12 12M18 6L6 18" stroke-width="2.4" stroke-linecap="round"/>',
  chevron: '<path d="M9 6l6 6-6 6" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  back: '<path d="M15 5l-7 7 7 7" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  undo: '<path d="M9 7L4 12l5 5M4 12h11a5 5 0 010 10h-3" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  more: '<circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/>',
  formation: '<circle cx="7" cy="17" r="2.5" stroke-width="2" fill="none"/><circle cx="17" cy="17" r="2.5" stroke-width="2" fill="none"/><circle cx="12" cy="7" r="2.5" stroke-width="2" fill="none"/>',
  add: '<path d="M12 5v14M5 12h14" stroke-width="2.4" stroke-linecap="round"/>',
  play: '<path d="M8 5l12 7-12 7z"/>',
  draw: '<path d="M4 20l4-1 11-11-3-3L5 16z" stroke-width="2" fill="none" stroke-linejoin="round"/>',
  share: '<path d="M12 3v12M7 8l5-5 5 5M5 13v6h14v-6" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
};
const ic = (name, size = 22, colour = "currentColor") => `<svg width="${size}" height="${size}" viewBox="0 0 24 24" stroke="${colour}" fill="${colour}" aria-hidden="true">${ICON[name]}</svg>`;
const status = () => `<div class="status">${txt("status.time", "9:41")}${txt("status.battery", "100%")}</div>`;

// A pitch with the scenario on it. `side`: turned with our attack to the right (tiles); else upright (the board).
const PITCH = { full: [105, 68], sevenASide: [60, 40], fiveASide: [40, 25] };
// `fit`: frame the play, not the whole pitch (small-sided and set pieces): the players and ball with a margin, at
// least half the pitch long, at the tile's aspect, kept on the pitch; discs stay the same size on screen.
function pitchSVG(kind, built, w, { side = true, numbers = false, r = null, fit = false } = {}) {
  const [L, Wd] = PITCH[kind];
  const h = side ? w * Wd / L : w * L / Wd;
  const P = p => side ? [p.y * w, p.x * h] : [p.x * w, (1 - p.y) * h];
  const lineW = Math.max(1, w / 240);
  const m = (x, y) => side ? [y / L * w, x / Wd * h] : [x / Wd * w, (1 - y / L) * h];  // metres → px
  const rect = (x0, y0, x1, y1) => { const [a, b] = m(x0, y0), [c, d] = m(x1, y1); return `<rect x="${Math.min(a, c)}" y="${Math.min(b, d)}" width="${Math.abs(c - a)}" height="${Math.abs(d - b)}" fill="none"/>`; };
  const boxW = Math.min(40.3, Wd * 0.6), boxD = Math.min(16.5, L * 0.16), sixW = Math.min(18.3, Wd * 0.3), sixD = Math.min(5.5, L * 0.06);
  const [cx, cy] = m(Wd / 2, L / 2);
  const stripes = Array.from({ length: 8 }, (_, i) => side
    ? `<rect x="${i * w / 8}" y="0" width="${w / 8}" height="${h}" fill="${i % 2 ? "var(--bc-pitch-b)" : "var(--bc-pitch-a)"}"/>`
    : `<rect x="0" y="${i * h / 8}" width="${w}" height="${h / 8}" fill="${i % 2 ? "var(--bc-pitch-b)" : "var(--bc-pitch-a)"}"/>`).join("");
  const half = side ? `<line x1="${w / 2}" y1="0" x2="${w / 2}" y2="${h}"/>` : `<line x1="0" y1="${h / 2}" x2="${w}" y2="${h / 2}"/>`;
  let rad = r ?? Math.max(4, w / 30);
  const disc = (p, home, num) => {
    const [x, y] = P(p);
    const body = home
      ? `<circle cx="${x}" cy="${y}" r="${rad + rad * 0.1}" fill="var(--disc-outline)"/><circle cx="${x}" cy="${y}" r="${rad}" fill="var(--home)"/>`
      : `<circle cx="${x}" cy="${y}" r="${rad * 1.12}" fill="var(--disc-outline)"/><circle cx="${x}" cy="${y}" r="${rad * 0.9}" fill="var(--away-inner)" stroke="var(--away)" stroke-width="${rad * 0.24}"/>`;
    const n = numbers && num != null ? `<text x="${x}" y="${y + rad * 0.37}" text-anchor="middle" font-family="Nunito" font-weight="800" font-size="${rad * 1.05}" fill="${home ? "var(--home-ink)" : "var(--away-ink)"}">${num}</text>` : "";
    return body + n;
  };
  // Back to front, as the app draws them (D-93): whoever is nearer our goal end last on the upright board.
  const all = [...built.away.map(p => ({ p, home: false })), ...built.home.map(p => ({ p, home: true }))];
  let vb = [0, 0, w, h];
  if (fit) {
    const pts = [...built.home, ...built.away, built.ball].map(P);
    const xs = pts.map(q => q[0]), ys = pts.map(q => q[1]);
    const cx0 = (Math.min(...xs) + Math.max(...xs)) / 2, cy0 = (Math.min(...ys) + Math.max(...ys)) / 2;
    const cw = Math.min(w, Math.max(w * 0.5, (Math.max(...xs) - Math.min(...xs)) * 1.4 + rad * 6, ((Math.max(...ys) - Math.min(...ys)) * 1.4 + rad * 6) * w / h));
    const chh = cw * h / w;
    vb = [Math.min(Math.max(cx0 - cw / 2, 0), w - cw), Math.min(Math.max(cy0 - chh / 2, 0), h - chh), cw, chh];
  }
  const k = vb[2] / w;  // discs and lines keep their on-screen size in a zoomed frame
  rad *= k;
  const players = all.map(o => disc(o.p, o.home, o.p.number)).join("");
  const [bx, by] = P(built.ball);
  const ball = `<circle cx="${bx + rad * 0.8}" cy="${by + rad * 0.8}" r="${rad * 0.5}" fill="var(--ball)" stroke="var(--disc-outline)" stroke-width="${rad * 0.14}"/>`;
  return `<svg viewBox="${vb.join(" ")}" width="${w}" height="${h}" aria-hidden="true" style="--k:${k}">${stripes}
    <g stroke="var(--bc-line)" stroke-width="${lineW * k}" fill="none">${rect(0, 0, Wd, L)}${half}<circle cx="${cx}" cy="${cy}" r="${(Math.min(9.15, Wd * 0.13)) / Wd * (side ? h : w)}"/>
    ${rect((Wd - boxW) / 2, 0, (Wd + boxW) / 2, boxD)}${rect((Wd - boxW) / 2, L - boxD, (Wd + boxW) / 2, L)}
    ${rect((Wd - sixW) / 2, 0, (Wd + sixW) / 2, sixD)}${rect((Wd - sixW) / 2, L - sixD, (Wd + sixW) / 2, L)}</g>${players}${ball}</svg>`;
}

function miniShape(f) {
  const dots = f.slots.map(([, , x, y]) => `<circle cx="${4 + x * 66}" cy="${4 + (1 - y) * 84}" r="3.6" fill="var(--text)"/>`).join("");
  return `<svg width="74" height="92" viewBox="0 0 74 92" aria-hidden="true"><rect x="1" y="1" width="72" height="90" rx="4" fill="none" stroke="rgba(255,255,255,.55)"/><line x1="1" y1="46" x2="73" y2="46" stroke="rgba(255,255,255,.55)"/>${dots}</svg>`;
}

const tile = (sc, formationId, attacking, on, w) =>
  btn(`scenario.${sc.id}`, `${pitchSVG(formation(formationId).pitch, buildScenario(sc.id, formationId, attacking), w, { fit: !sc.team })}
    <b>${esc(sc.name)}</b><span>${esc(sc.line)}</span>`, "tile", sc.name, `role="radio" aria-selected="${on}"`);

function scenarioBody(formationId, attacking, chosen, { from = null, w = 146, groups = null } = {}) {
  const f = formation(formationId);
  const sizeName = { full: "11-a-side", sevenASide: "7-a-side", fiveASide: "5-a-side" }[f.pitch];
  const shapeName = f.name.replace(/\s*\(.*\)$/, "");  // "2-3-1 (7-a-side)" → "2-3-1"; the size is said beside it
  const list = scenariosFor(f.pitch);
  const byGroup = ["Team shape", "Small-sided", "Set pieces"].filter(g => !groups || groups.includes(g));
  return `<div class="inner" ${from ? `data-scroll-to="${from}"` : ""}>
    <div class="shape-row">${btn("scenario.shape", `${shapeName} <small>${sizeName}</small>${ic("chevron", 16)}`, "shape-chip", `Your shape, ${shapeName}, ${sizeName}. Change it`)}</div>
    <div class="seg" role="tablist">${btn("scenario.side.attacking", "Attacking", "", "", `role="tab" aria-selected="${attacking}"`)}${btn("scenario.side.defending", "Defending", "", "", `role="tab" aria-selected="${!attacking}"`)}</div>
    ${txt("scenario.side.help", attacking ? "You have the ball. Lime is your team." : "They have the ball. Lime is your team.", "side-help", "p")}
    ${byGroup.map(g => {
      const items = list.filter(s => s.group === g);
      if (!items.length) return "";
      const slug = g.toLowerCase().replace(/ /g, "-");
      return `<div class="group">${txt(`scenario.group.${slug}`, g, "", "h3")}<div class="grid">${items.map(s => tile(s, formationId, attacking, s.id === chosen, w)).join("")}</div></div>`;
    }).join("")}
  </div>`;
}

function formationSheet({ tab, formationId = "4-3-3", attacking = true, chosen = null, from = null, top = 120, w = 146, form = false }) {
  const sc = SCENARIOS.find(s => s.id === chosen);
  const f = formation(formationId);
  const head = `<div class="pinned">${form ? "" : '<div class="grabber"></div>'}
    <div class="sheet-head">${txt("formation.title", "Formation", "", "h2")}${btn("formation.close", ic("close", 20), "icon-btn close", "Close")}</div>
    <div class="seg" role="tablist">${btn("formation.tab.shapes", "Shapes", "", "", `role="tab" aria-selected="${tab === "shapes"}"`)}${btn("formation.tab.scenarios", "Scenarios", "", "", `role="tab" aria-selected="${tab === "scenarios"}"`)}</div></div>`;
  let body, label, ready = true;
  if (tab === "shapes") {
    const shapes = FORMATIONS.filter(x => x.pitch === "full").slice(0, 9);
    body = `<div class="inner"><div class="seg" role="tablist">${["11-a-side", "7-a-side", "5-a-side"].map((l, i) => btn(`formation.size.${["full", "seven", "five"][i]}`, l, "", "", `role="tab" aria-selected="${i === 0}"`)).join("")}</div>
      <div class="shapes">${shapes.map(x => btn(`formation.${x.id}`, `${miniShape(x)}<span>${esc(x.name)}</span>`, "shape", x.name, `role="radio" aria-selected="${x.id === formationId}"`)).join("")}</div></div>`;
    label = `Use ${f.name}`;
  } else {
    body = scenarioBody(formationId, attacking, chosen, { from, w });
    ready = !!sc;
    label = sc ? `Use ${sc.name}` : "Pick a scenario";
  }
  const foot = `<div class="foot">${btn("formation.apply", label, "capsule", label, ready ? "" : 'aria-disabled="true"')}</div>`;
  const cls = form ? "form" : "sheet";
  return `<div class="scrim"></div><div class="${cls}" ${form ? "" : `style="top:${top}px"`}>${head}<div class="body">${body}</div>${foot}</div>`;
}

// The board behind a sheet, or on its own after a scenario is set up.
function boardScreen(built, { tag = "4-3-3", toast = null, dim = false } = {}) {
  return `${status()}<div class="nav">${btn("nav.back", ic("back"), "icon-btn", "Library")}${txt("nav.title", "New tactic", "title")}
      ${btn("nav.undo", ic("undo"), "icon-btn", "Undo")}${btn("nav.more", ic("more"), "icon-btn", "More")}</div>
    <div class="pitch-wrap" data-testid="board.pitch">${pitchSVG("full", built, 338, { side: false, numbers: true, r: 12 })}</div>
    <div class="meta">${txt("board.formation-tag", tag, "chip-tag")}${txt("board.step-label", "Step 1 of 1", "muted")}</div>
    ${toast ? `<div class="toast">${txt("toast.message", toast)}${btn("toast.undo", "Undo", "", "Undo")}</div>` : ""}
    <div class="toolbar">${[["formation", "Formation"], ["add", "Add"], ["play", "Play"], ["draw", "Draw"], ["share", "Export"]].map(([i, l]) =>
      btn(`toolbar.${i === "share" ? "export" : i}`, i === "play" ? `<span class="disc">${ic("play", 22)}</span>${l}` : `${ic(i)}${l}`, "tool", l)).join("")}</div>`;
}

const frames = [];
const add = (id, cap, cls, html) => frames.push(`<div><p class="cap">${esc(cap)}</p><div class="frame ${cls}" data-screen="${id}">${html}<div class="home-bar"></div></div></div>`);
const blank = { home: [], away: [], ball: { x: 0.5, y: 0.5 } };
const behind = buildScenario("kick-off", "4-3-3", true);

if (!window.IPAD) {
add("formation--shapes", "1 · Shapes: today's sheet, now with a Scenarios tab", "phone",
  boardScreen(behind) + formationSheet({ tab: "shapes" }));
add("formation--scenarios", "2 · Scenarios, nothing picked yet", "phone",
  boardScreen(behind) + formationSheet({ tab: "scenarios" }));
add("formation--scenarios-picked", "3 · Scrolled to small-sided, 3v2 counter picked", "phone",
  boardScreen(behind) + formationSheet({ tab: "scenarios", chosen: "3v2-counter", from: "scenario.3v2-counter" }));
add("formation--scenarios-defending", "4 · Defending: they have the ball", "phone",
  boardScreen(behind) + formationSheet({ tab: "scenarios", attacking: false, chosen: "3v2-counter", from: "scenario.3v2-counter" }));
add("formation--scenarios-seven", "5 · 7-a-side shape: the list fits the size", "phone",
  boardScreen(behind) + formationSheet({ tab: "scenarios", formationId: "7-2-3-1", chosen: "counter" }));
add("formation--scenario-confirm", "6 · A board with players: confirm first", "phone",
  boardScreen(behind) + formationSheet({ tab: "scenarios", chosen: "3v2-counter", from: "scenario.3v2-counter" }) +
  `<div class="alert" role="alertdialog"><div class="msg">${txt("scenario.confirm.title", "Set up 3v2 counter?", "", "h4")}
    ${txt("scenario.confirm.message", "This replaces the move on the board. You can undo.", "", "p")}</div>
    <div class="acts">${btn("scenario.confirm.cancel", "Cancel", "", "Cancel")}${btn("scenario.confirm.go", "Set up", "go", "Set up")}</div></div>`);
add("board--scenario-applied", "7 · The board, set up: 10, 7 and 11 break on two centre-backs", "phone",
  boardScreen(buildScenario("3v2-counter", "4-3-3", true), { tag: "3v2 counter", toast: "3v2 counter set up" }));
}

// iPad: the sheet is a form sheet over the board, three tiles a row (scenarios-ipad.html, checked at iPad size).
if (window.IPAD) frames.length = 0;
if (window.IPAD) add("ipad-formation--scenarios", "8 · iPad: the same sheet, three tiles a row", "ipad",
  `<div class="status">${txt("ipad.status.time", "9:41 Mon 9 Nov")}${txt("ipad.status.battery", "100%")}</div>` +
  formationSheet({ tab: "scenarios", chosen: "final-third", w: 172, form: true }));

document.getElementById("gallery").innerHTML = frames.join("");
// A frame scrolled to a group: its heading at the top of the sheet's list, as after scrolling there.
for (const inner of document.querySelectorAll("[data-scroll-to]")) {
  const target = inner.querySelector(`[data-testid="${inner.dataset.scrollTo}"]`);
  if (target) inner.style.marginTop = `${-(target.offsetTop - inner.offsetTop) + 120}px`;
}
