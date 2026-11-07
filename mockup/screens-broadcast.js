// Broadcast restyle frames (D-65, D-66): dark pitch, zones, shape lines, glows and the tilted camera; numbered discs everywhere.
Object.assign(ICONS, {
  add: '<circle cx="12" cy="12" r="8.5" stroke-width="2"/><path d="M12 8 V16 M8 12 H16" stroke-width="2"/>',
  chevron: '<path d="M7 10 L12 15 L17 10" stroke-width="2.6"/>',
  camFlat: '<rect x="6" y="3" width="12" height="18" rx="1.5" stroke-width="2"/><path d="M6 12 H18" stroke-width="1.6"/>',
  camBc: '<path d="M8 5 H16 L21 19 H3 Z" stroke-width="2" stroke-linejoin="round"/><path d="M5.2 12.5 H18.8" stroke-width="1.6"/>',
});
const KINDS = {
  run: ["Run", '<path d="M3 12 H21" stroke-width="2.6"/>'],
  pass: ["Pass", '<path d="M3 12 H21" stroke-width="2.6" stroke-dasharray="4 3"/>'],
  dribble: ["Dribble", '<path d="M3 12 l3 -3 l3 6 l3 -6 l3 6 l3 -6 l3 3" stroke-width="2.2"/>'],
  press: ["Press", '<path d="M6 7 L11 12 L6 17 M12 7 L17 12 L12 17" stroke-width="2.4"/>'],
  zone: ["Zone", '<rect x="3" y="5" width="18" height="14" rx="1" fill="var(--zone-fill)" stroke="var(--zone-stroke)" stroke-width="1.8"/>'],
  line: ["Line", '<path d="M3 15 L12 9 L21 13" stroke-width="2.2"/><circle cx="3" cy="15" r="2.2" fill="var(--home)"/><circle cx="12" cy="9" r="2.2" fill="var(--home)"/><circle cx="21" cy="13" r="2.2" fill="var(--home)"/>'],
  glow: ["Glow", '<circle cx="12" cy="12" r="3.2" fill="var(--heat)" stroke="none"/><circle cx="12" cy="12" r="6.5" stroke-width="1.6" opacity=".8"/><circle cx="12" cy="12" r="10" stroke-width="1.4" opacity=".4"/>'],
};
const KIND_COLOUR = { run: "--run", pass: "--pass", dribble: "--dribble", press: "--press", zone: "--home", line: "--home", glow: "--home" };
const HELP = {
  zone: "Zone · see-through box · drag across the grass",
  line: "Line · joins a unit · tap the last player again to finish",
  glow: "Glow · rings follow a player · heat stays on the grass",
};

// Step 4 (index 3, "3 crosses for 9"): the lane 3 overlapped into, their back line pulled apart, 3 in rings, heat where 9 arrives.
const M4 = { zones: [{ x: .02, y: .52, w: .2, h: .34 }], heat: [{ x: .5, y: .87, r: .11 }], lines: [{ ids: ["a2", "a5", "a4"] }], rings: ["h3"] };
const CAM = { pw: 660, tilt: 54, focus: .34, cx: .34, persp: 1100, horizon: 0 };

const navEdit = () => `<div class="nav">${btn("nav.back", ic("back"), "icon-btn", "Back to tactics")}
  ${btn("nav.title", `<span style="overflow:hidden;text-overflow:ellipsis">${HERO.title}</span><span style="color:var(--muted);flex-shrink:0">${ic("chevron", 14)}</span>`, "title", "", 'style="display:flex;align-items:center;justify-content:center;gap:4px;height:44px;min-width:0"')}
  <div class="undo-pill">${btn("nav.undo", ic("undo", 20), "icon-btn", "Undo")}${btn("nav.redo", ic("redo", 20), "icon-btn", "Redo", 'aria-disabled="true"')}</div>
  ${btn("nav.share", ic("share", 22), "icon-btn", "Share")}</div>`;
const toolbar2 = () => `<div class="toolbar">
  ${btn("toolbar.formation", `${ic("formation")}Formation`, "tool")}${btn("toolbar.add", `${ic("add")}Add`, "tool")}
  ${btn("toolbar.play", `<span class="disc" style="color:var(--accent-ink)">${ic("play")}</span>Play`, "tool primary")}
  ${btn("toolbar.draw", `${ic("draw")}Draw`, "tool")}${btn("toolbar.export", `${ic("export")}Export`, "tool")}</div><div class="home-bar"></div>`;
const camSeg = (on, prefix, extra = "") => `<div class="cam" role="radiogroup" aria-label="Camera" ${extra}>
  ${btn(`${prefix}.flat`, ic("camFlat", 22), "", "Flat camera", `role="radio" aria-checked="${on === "flat"}"`)}${btn(`${prefix}.broadcast`, ic("camBc", 22), "", "Broadcast camera", `role="radio" aria-checked="${on === "bc"}"`)}</div>`;
const navPlay = cam => `<div class="nav">${camSeg(cam, "playback.camera")}${txt("nav.title", HERO.title, "title")}${btn("playback.done", "Done", "text-btn")}</div>`;
const playBar = () => `${txt("playback.time", "0:04.4 / 0:06.2", "", "span", "position:absolute;top:706px;right:24px;font:var(--t-caption);color:var(--muted)")}
  <div class="abs" data-testid="playback.scrubber" role="slider" aria-label="Step 4 of 5" tabindex="0" style="top:622px;left:24px;right:24px;height:44px;display:flex;gap:6px;align-items:center">
    ${STEPS.map((_, i) => `<i style="flex:1;height:6px;border-radius:3px;background:linear-gradient(90deg,var(--accent) ${i < 3 ? 100 : i === 3 ? 55 : 0}%,var(--surface-2) 0)"></i>`).join("")}</div>
  ${txt("playback.note", `<span style="font:var(--t-caption);color:var(--muted)">Step 4 of 5 · </span>${STEPS[3].note}`, "note", "p", "position:absolute;top:670px;left:24px;right:24px;margin:0;font-size:19px")}
  <div class="toolbar" style="justify-content:space-between;padding:6px 18px 0">
    ${btn("playback.loop", ic("loop", 22), "icon-btn", "Loop", 'aria-pressed="true" style="color:var(--accent)"')}${btn("playback.prev", ic("prev", 22), "icon-btn", "Previous step")}
    ${btn("playback.toggle", `<span class="disc" style="color:var(--accent-ink)">${ic("pause")}</span>Pause`, "tool primary")}
    ${btn("playback.next", ic("next", 22), "icon-btn", "Next step")}
    <div class="seg" style="width:96px;align-self:flex-start;margin-top:6px"><button role="tab" data-testid="playback.speed.half" aria-selected="false">½×</button><button role="tab" data-testid="playback.speed.one" aria-selected="true">1×</button></div></div><div class="home-bar"></div>`;
const flatBoard = (w, i, marks, opts = {}) => Board.html(w, pos(i), opts.arrows ?? STEPS[i].arrows, { look: "bc", under: BC.under(marks, opts), hits: false, ...opts });
const staticBoard = (w, i, marks, opts = {}) => flatBoard(w, i, marks, { testid: "x", ...opts }).replace(' data-testid="x"', "").replace('class="board"', 'class="board" style="position:static"');

// Draw panel: the four arrows that move players (D-59), then the three marks that explain (D-65).
const drawPanel = on => `<div class="abs" style="left:16px;right:16px;bottom:34px;background:var(--surface-2);border-radius:24px;padding:8px 12px 10px;box-shadow:0 8px 30px rgba(0,0,0,.5)">
  ${txt("draw.kind-help", HELP[on], "", "p", "margin:2px 6px 4px;font:var(--t-caption);color:var(--muted)")}
  ${["run pass dribble press", "zone line glow"].map(row => `<div class="kinds" style="grid-template-columns:repeat(${row.split(" ").length},1fr);margin-top:6px;--tile-h:50px">${row.split(" ").map(k =>
    `<button role="tab" data-testid="draw.kind.${k}" aria-selected="${k === on}" class="tile" style="${k === on ? "border-color:var(--accent)" : ""}"><svg width="40" height="22" viewBox="0 0 24 24" fill="none" stroke="var(${KIND_COLOUR[k]})" stroke-linecap="round" aria-hidden="true">${KINDS[k][1]}</svg>${KINDS[k][0]}</button>`).join("")}</div>`).join("")}</div>`;
const drawNav = () => `${status()}<div class="nav">${btn("draw.cancel", ic("close"), "icon-btn", "Cancel drawing")}${txt("draw.title", "Draw", "title")}${btn("draw.done", ic("check"), "icon-btn", "Done", 'style="background:var(--accent);color:var(--accent-ink)"')}</div>`;
const drawHint = text => txt("draw.hint", text, "note", "p", "position:absolute;top:626px;left:24px;right:24px;margin:0;text-align:center;font-size:18px;color:var(--muted)");

// Library cards: other tactics are built from presets/formations.json, so nothing is typed by hand.
const fromFormation = (id, dy = 0) => Object.fromEntries(FORMATIONS.find(f => f.id === id).slots.map(s => [`h${s.number}`, { x: s.x, y: Math.min(.97, s.y + dy) }]));
const card = (n, title, steps, positions, arrows, marks) => `<button class="tile" data-testid="library.card.${n}" aria-label="${title}, ${steps}" style="padding:12px;align-items:flex-start;justify-content:flex-start;text-align:left;gap:4px">
  ${Board.html(140, positions, arrows, { look: "bc", under: BC.under(marks), hits: false, testid: "x" }).replace(' data-testid="x"', "").replace('class="board"', 'class="board" style="position:static;margin-bottom:8px"')}
  <span style="font:800 17px/1.3 var(--font-ui)">${title}</span><span style="font:var(--t-caption);color:var(--muted)">11-a-side · ${steps}</span></button>`;

// Export frames: a 1080 x 1920 or 1920 x 1080 frame drawn at 393 pt wide.
const mark = (size, style = "") => txt("export-frame.mark", "Agmen", "", "span", `position:absolute;font:800 ${size}px var(--font-ui);color:var(--muted);${style}`);
const vid916 = cam => `<div class="abs" style="left:24px;top:26px;right:24px">${txt("export-frame.title", HERO.title, "", "h1", "margin:0;font:800 24px/1.15 var(--font-ui)")}
    ${txt("export-frame.step", "Step 4 of 5", "", "p", "margin:4px 0 0;font:var(--t-caption);color:var(--muted)")}</div>
  ${cam === "bc" ? `<div class="abs" style="left:0;top:92px">${BC.tilted(393, 500, pos(3), STEPS[3].arrows, M4, { ...CAM, pw: 680 }, "export-frame.board")}</div>`
    : `<div class="abs" style="left:${(393 - 320) / 2}px;top:108px">${staticBoard(320, 3, M4, { testid: "export-frame.board" })}</div>`}
  ${txt("export-frame.note", STEPS[3].note, "note", "p", "position:absolute;left:24px;right:24px;top:612px;margin:0;font-size:26px")}${mark(13, "right:20px;bottom:16px")}`;
const vid169 = cam => `<div class="abs" style="left:14px;top:16px;width:${cam === "bc" ? 104 : 112}px">${txt("export-frame.title", HERO.title, "", "h1", "margin:0;font:800 14px/1.15 var(--font-ui)")}
    ${txt("export-frame.step", "Step 4 of 5", "", "p", "margin:3px 0 0;font:700 9px var(--font-ui);color:var(--muted)")}</div>
  ${cam === "bc" ? `<div class="abs" style="left:0;top:0">${BC.tilted(393, 221, pos(3), STEPS[3].arrows, M4, { pw: 320, tilt: 58, focus: .36, cx: .4, persp: 700, horizon: 0 }, "export-frame.board")}</div>`
    : `<div class="abs" style="left:${(393 - 190 / Board.ratio) / 2}px;top:15px">${staticBoard(190 / Board.ratio, 3, M4, { testid: "export-frame.board" })}</div>`}
  ${txt("export-frame.note", STEPS[3].note, "note", "p", `position:absolute;right:14px;top:16px;width:${cam === "bc" ? 96 : 110}px;margin:0;font-size:14px;line-height:1.15;text-align:right`)}${mark(8, "right:10px;bottom:7px")}`;

const BC_SCREENS = [
  ["board--broadcast", "D-65 · Editing on the dark pitch: discs stay, marks lie under them", () => `${status()}${navEdit()}
    ${flatBoard(W, 3, M4, { selected: "h3", hits: true })}
    ${ctx("selection.label", "3 · Full-back", [["selection.edit", "Edit"], ["selection.run", "Draw run"], ["selection.delete", "Remove"]])}${strip(3)}${toolbar2()}`],

  ["playback--broadcast", "D-65/66 · Playing, flat camera: discs, a zone, their back line, rings on 3, heat", () => `${status()}${navPlay("flat")}
    ${flatBoard(W, 3, M4)}${playBar()}`],

  ["playback--broadcast-3d", "D-66 · Same moment, broadcast camera: discs lie flat, numbers upright; follows the ball", () => `${status()}${navPlay("bc")}
    <div class="abs" style="left:0;top:104px">${BC.tilted(393, 516, pos(3), STEPS[3].arrows, M4, CAM)}</div>${playBar()}`],

  ["draw--tools", "D-65 · Draw › Zone: drag a box on the grass; drag a corner to resize", () => {
    const z = M4.zones[0], [x0, y0] = Board.pt({ x: z.x, y: z.y + z.h }, W, W * Board.ratio), [x1, y1] = Board.pt({ x: z.x + z.w, y: z.y }, W, W * Board.ratio), bx = 29.5, by = 104;
    const handle = (id, x, y, label) => `<button class="hit" data-testid="draw.zone.handle.${id}" aria-label="${label}" style="left:${bx + x - 22}px;top:${by + y - 22}px"></button>`;
    return `${drawNav()}${Board.html(W, pos(3), [], { look: "bc", under: BC.under({ zones: M4.zones }, { handles: true }) })}
    <button class="abs" data-testid="draw.zone.1" aria-label="Zone 1, left wing, step 4" style="left:${bx + x0}px;top:${by + y0}px;width:${x1 - x0}px;height:${y1 - y0}px;z-index:0"></button>
    ${handle("tl", x0, y0, "Zone corner, top left")}${handle("tr", x1, y0, "Zone corner, top right")}${handle("bl", x0, y1, "Zone corner, bottom left")}${handle("br", x1, y1, "Zone corner, bottom right")}
    ${ctx("draw.mark.label", "Zone 1 · step 4", [["draw.mark.remove", "Remove"]]).replace('class="ctx"', 'class="ctx" style="top:621px"')}${drawPanel("zone")}`;
  }],

  ["draw--tools-line", "D-65 · Draw › Line: tap 2, then 5, then 4 (5 tapped so far)", () => `${drawNav()}
    ${Board.html(W, pos(3), [], { look: "bc", under: BC.under({ lines: [{ ids: ["a2", "a5"] }] }, { pending: true }) })}
    ${drawHint("Tap players in order to join them.")}${drawPanel("line")}`],

  ["draw--tools-glow", "D-65 · Draw › Glow: tapped 3 (rings), then the penalty spot (heat)", () => `${drawNav()}
    ${Board.html(W, pos(3), [], { look: "bc", under: BC.under({ rings: ["h3"], heat: M4.heat }) })}
    ${drawHint("Tap a player, or a spot on the grass.")}${drawPanel("glow")}`],

  ["export--broadcast", "D-66 · Export sheet: Camera (Flat or Broadcast), no Spotlight; preview shows Broadcast", () => `${status()}${navEdit()}${flatBoard(W, 0, {}, {})}
    <div class="scrim"></div><div class="sheet"><div class="grabber"></div>
    <div class="sheet-head">${txt("export.title", "Export", "", "h2")}${btn("export.close", ic("close", 20), "icon-btn close", "Close")}</div>
    <div style="display:flex;gap:16px"><div data-testid="export.preview" role="img" aria-label="Preview: ${HERO.title}, broadcast camera" style="position:relative;width:128px;height:228px;flex-shrink:0;background:var(--bg);border-radius:10px;overflow:hidden;outline:1px solid var(--surface-3)">
      <div data-testid="export.preview.title" style="position:absolute;left:8px;top:8px;font:800 9px var(--font-ui)">${HERO.title}</div>
      <div style="position:absolute;left:0;top:26px">${BC.tilted(128, 164, pos(3), STEPS[3].arrows, M4, { pw: 220, tilt: 54, focus: .34, cx: .34, persp: 370, horizon: 0 }, "export.preview.board")}</div>
      <div data-testid="export.preview.note" style="position:absolute;left:8px;bottom:18px;font:400 10px var(--font-note)">${STEPS[3].note}</div><div data-testid="export.preview.mark" style="position:absolute;right:7px;bottom:6px;font:800 7px var(--font-ui);color:var(--muted)">Agmen</div></div>
      <div style="flex:1">${presets().replace("Story 9:16", "Vertical 9:16")}${btn("export.title-band", `Title band<i></i>`, "switch", "", 'role="switch" aria-checked="true"')}${btn("export.notes", `Step notes<i></i>`, "switch", "", 'role="switch" aria-checked="true"')}</div></div>
    <div class="row" style="margin-top:12px">${txt("export.camera-label", "Camera", "", "span", "font:var(--t-headline)")}
      <div class="seg" style="width:200px" role="radiogroup" aria-label="Camera"><button role="radio" data-testid="export.camera.flat" aria-checked="false" aria-selected="false">Flat</button><button role="radio" data-testid="export.camera.broadcast" aria-checked="true" aria-selected="true">Broadcast</button></div></div>
    <div style="margin-top:14px">${txt("export.size", "Up to 4 MB · 6.2 s · 1080 × 1920", "", "p", "margin:0;font:var(--t-headline)")}${txt("export.size-help", "Estimate. Plays in WhatsApp and Discord.", "muted", "p", "margin:2px 0 14px;font:var(--t-caption)")}${btn("export.start", "Export video", "capsule")}</div></div>`],

  ["export-frame--9x16", "D-65 · Video frame 9:16 (1080 × 1920), Broadcast camera, step 4", () => vid916("bc"), 699],
  ["export-frame--9x16-flat", "D-65 · Video frame 9:16, Flat camera, step 4", () => vid916("flat"), 699],
  ["export-frame--16x9", "D-65 · Video frame 16:9 (1920 × 1080), Broadcast camera fills the frame", () => vid169("bc"), 221],
  ["export-frame--16x9-flat", "D-65 · Video frame 16:9, Flat: pitch upright, title left, note right (D-63)", () => vid169("flat"), 221],

  ["library--broadcast", "D-65 · Library: cards drawn on the dark pitch", () => `${status()}
    <div class="abs" data-testid="library.art" style="left:0;right:0;top:0;height:200px;overflow:hidden;opacity:.5" aria-hidden="true">${staticBoard(393, 0, {}, { arrows: [] }).replace(/<g opacity="1">[\s\S]*?<\/g>/g, "").replace(/<circle opacity[^>]*>/g, "")}</div>
    <div class="abs" style="left:0;right:0;top:120px;height:80px;background:linear-gradient(rgba(11,15,20,0),var(--bg))"></div>
    <div class="abs" style="top:64px;left:24px;right:24px">${txt("library.title", "Agmen", "", "h1", "font:var(--t-largetitle);margin:0")}
      ${txt("library.tagline", "Draw the move, not just the shape.", "note", "p", "margin:4px 0 0;color:var(--muted)")}</div>
    <div class="abs" style="top:164px;left:24px;right:24px">${btn("launch.new", `${ic("plus", 20)} New tactic`, "capsule", "", 'style="display:flex;align-items:center;justify-content:center;gap:8px"')}
      ${txt("library.recent", "Recent", "", "h2", "margin:24px 0 12px;font:var(--t-headline);color:var(--muted)")}
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
        ${card(1, HERO.title, "5 steps", pos(0), STEPS[0].arrows, {})}
        ${card(2, "Press their keeper", "3 steps", fromFormation("4-4-2", .22), [], { zones: [{ x: .18, y: .8, w: .64, h: .2 }] })}
        ${card(3, "Back three, then five", "4 steps", fromFormation("3-4-3"), [], { lines: [{ ids: ["h5", "h4", "h6"] }] })}
        ${card(4, "Hold the edge of the box", "2 steps", fromFormation("5-3-2"), [], { heat: [{ x: .5, y: .27, r: .14 }] })}</div></div>`],
];

const bcGallery = document.getElementById("gallery");
bcGallery.insertAdjacentHTML("beforeend", `<div class="section-head"><h2>Broadcast restyle (D-65)</h2><p>Revised after D-66: numbered discs everywhere (flat on the grass in the tilted camera), dark pitch, zones, shape lines, glows, and a broadcast camera that follows the ball. Spotlight is gone; glow rings do that job.</p></div>`);
BC_SCREENS.forEach(([id, caption, render, height]) => {
  const wrap = document.createElement("div");
  wrap.innerHTML = `<p class="cap">${caption}</p><section class="frame${height ? " vid" : ""}" data-screen="${id}" ${height ? `style="height:${height}px"` : ""}>${render()}</section>`;
  bcGallery.appendChild(wrap);
});
placeDiscs();
