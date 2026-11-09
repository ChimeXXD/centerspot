// Every screen and state, built from shared parts. Copy comes from docs/design/UI-BRIEF.md where it exists.
const W = 334;
const ICONS = {
  back: '<path d="M14 4 L6 12 L14 20" stroke-width="2.4"/>',
  undo: '<path d="M8 8 H15 a5 5 0 0 1 0 10 H10 M8 8 l4 -4 M8 8 l4 4" stroke-width="2"/>',
  redo: '<path d="M16 8 H9 a5 5 0 0 0 0 10 H14 M16 8 l-4 -4 M16 8 l-4 4" stroke-width="2"/>',
  more: '<circle cx="5" cy="12" r="1.6" fill="currentColor"/><circle cx="12" cy="12" r="1.6" fill="currentColor"/><circle cx="19" cy="12" r="1.6" fill="currentColor"/>',
  formation: '<circle cx="7" cy="17" r="2.5" stroke-width="2"/><circle cx="17" cy="17" r="2.5" stroke-width="2"/><circle cx="12" cy="7" r="2.5" stroke-width="2"/>',
  draw: '<path d="M4 20 L5 15 L16 4 L20 8 L9 19 Z M14 6 L18 10" stroke-width="2"/>',
  play: '<path d="M8 5 L19 12 L8 19 Z" fill="currentColor" stroke="none"/>',
  pause: '<rect x="6" y="5" width="4" height="14" rx="1.2" fill="currentColor" stroke="none"/><rect x="14" y="5" width="4" height="14" rx="1.2" fill="currentColor" stroke="none"/>',
  export: '<rect x="4" y="3" width="16" height="18" rx="3" stroke-width="2"/><path d="M4 8 H20 M4 16 H20" stroke-width="2"/>',
  share: '<path d="M12 3 V15 M7 8 L12 3 L17 8 M5 12 V20 H19 V12" stroke-width="2"/>',
  close: '<path d="M6 6 L18 18 M18 6 L6 18" stroke-width="2.2"/>',
  check: '<path d="M5 12 L10 17 L19 7" stroke-width="2.6"/>',
  loop: '<path d="M4 12 a6 6 0 0 1 6 -6 H18 M15 3 l3 3 l-3 3 M20 12 a6 6 0 0 1 -6 6 H6 M9 21 l-3 -3 l3 -3" stroke-width="2"/>',
  prev: '<path d="M6 5 V19 M18 5 L9 12 L18 19 Z" stroke-width="2" fill="currentColor"/>',
  next: '<path d="M18 5 V19 M6 5 L15 12 L6 19 Z" stroke-width="2" fill="currentColor"/>',
  plus: '<path d="M12 5 V19 M5 12 H19" stroke-width="2.4"/>',
  trash: '<path d="M5 7 H19 M10 7 V4 H14 V7 M7 7 L8 20 H16 L17 7" stroke-width="2"/>',
  file: '<path d="M6 3 H14 L19 8 V21 H6 Z M14 3 V8 H19" stroke-width="2"/>',
  video: '<rect x="3" y="5" width="13" height="14" rx="3" stroke-width="2"/><path d="M16 10 L21 7 V17 L16 14" stroke-width="2"/>',
  photo: '<rect x="3" y="5" width="18" height="14" rx="3" stroke-width="2"/><circle cx="9" cy="10" r="2" stroke-width="2"/><path d="M3 17 L9 13 L13 16 L16 13 L21 17" stroke-width="2"/>',
};
const ic = (name, size = 24) => `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;
const btn = (id, inner, cls = "icon-btn", label = "", extra = "") => `<button class="${cls}" data-testid="${id}" ${label ? `aria-label="${label}"` : ""} ${extra}>${inner}</button>`;
const txt = (id, text, cls = "", tag = "span", style = "") => `<${tag} class="${cls}" data-testid="${id}" style="${style}">${text}</${tag}>`;

const status = () => `<div class="status" data-testid="status">9:41<span>${ic("more", 18)}</span></div>`;
const nav = (title, canUndo = true) => `<div class="nav">${btn("nav.back", ic("back"), "icon-btn", "Back to tactics")}
  ${txt("nav.title", title, "title")}
  <div class="undo-pill">${btn("nav.undo", ic("undo", 20), "icon-btn", "Undo", canUndo ? "" : 'aria-disabled="true"')}${btn("nav.redo", ic("redo", 20), "icon-btn", "Redo", 'aria-disabled="true"')}</div>
  ${btn("nav.more", ic("more"), "icon-btn", "More")}</div>`;
const meta = (left, right) => `<div class="meta">${txt("board.formation-tag", left, "chip-tag")}${txt("board.step-label", right, "meta-right")}</div>`;
const toolbar = (playing = false) => `<div class="toolbar">
  ${btn("toolbar.formation", `${ic("formation")}Formation`, "tool")}${btn("toolbar.draw", `${ic("draw")}Draw`, "tool")}
  ${btn(playing ? "playback.toggle" : "toolbar.play", `<span class="disc" style="color:var(--accent-ink)">${ic(playing ? "pause" : "play")}</span>${playing ? "Pause" : "Play"}`, "tool primary")}
  ${btn("toolbar.export", `${ic("export")}Export`, "tool")}${btn("toolbar.share", `${ic("share")}Share`, "tool")}</div><div class="home-bar"></div>`;
const strip = (current, count = STEPS.length) => `<div class="strip">${STEPS.slice(0, count).map((s, i) =>
  btn(`steps.chip.${i + 1}`, `<b>${i + 1}</b><small>${s.duration} s</small>`, `step ${i === current ? "on" : ""}`, `Step ${i + 1}, ${s.duration} seconds`)).join("")}
  ${btn("steps.add", "+", "step add", "Add a step")}</div>`;
const pos = i => STEPS[i].positions;
const board = (i, opts = {}) => Board.html(W, pos(i), opts.arrows ?? STEPS[i].arrows ?? [], opts);
const sheet = (top, title, body, closeId) => `<div class="scrim"></div><div class="sheet" ${top ? `style="top:${top}px"` : ""}><div class="grabber"></div>
  <div class="sheet-head">${txt(`${closeId.split(".")[0]}.title`, title, "", "h2")}${btn(closeId, ic("close", 20), "icon-btn close", "Close")}</div>${body}</div>`;
// The row under the pitch shows the formation and step, or the actions for whatever is selected, so nothing covers a player.
const editor = (i, label, opts = {}) => status() + nav(HERO.title, opts.canUndo) + (opts.ctx ?? meta(label, opts.right ?? `Step ${i + 1} of ${STEPS.length} · ${STEPS[i].duration} s`)) + board(i, opts);
const ctx = (labelId, label, buttons) => `<div class="ctx">${txt(labelId, label, "label")}${buttons.map(([id, l]) => btn(id, l, "")).join("")}</div>`;

const miniFormation = f => {
  const w = 74, h = w * 1.25;
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true"><rect x="1" y="1" width="${w - 2}" height="${h - 2}" rx="4" fill="none" stroke="var(--chalk)"/>
    <line x1="1" y1="${h / 2}" x2="${w - 1}" y2="${h / 2}" stroke="var(--chalk)"/>${f.slots.map(s => `<circle cx="${4 + s.x * (w - 8)}" cy="${4 + (1 - s.y) * (h - 8)}" r="3.6" fill="var(--text)"/>`).join("")}</svg>`;
};

const SCREENS = [
  ["library", "Library: New tactic first, then recents", () => `${status()}
    <div class="abs" style="top:64px;left:24px;right:24px">${txt("library.title", "CenterSpot", "", "h1", "font:var(--t-largetitle);margin:0")}
      ${txt("library.tagline", "Draw the move, not just the shape.", "note", "p", "margin:4px 0 0;color:var(--muted)")}</div>
    <div class="abs" style="top:160px;left:24px;right:24px;display:grid;grid-template-columns:1fr 1fr;gap:16px">
      ${btn("launch.new", `${ic("plus", 30)}<span>New tactic</span>`, "tile", "New tactic", 'style="height:290px;border:2px dashed var(--muted);background:none;font:800 16px var(--font-ui)"')}
      <button class="tile" data-testid="library.card.overlap-left" style="height:290px;justify-content:flex-start;padding:10px;align-items:flex-start;text-align:left">
        ${Board.html(126, pos(4), [], { hits: false, testid: "unused" }).replace(/data-testid="unused"/, "").replace('class="board"', 'class="board" style="position:static"')}
        <span style="font:800 14px var(--font-ui)">${HERO.title}</span><span style="font:600 12px var(--font-ui);color:var(--muted)">11-a-side · ${STEPS.length} steps</span></button></div>
    ${txt("library.recents-hint", "Your tactics live in Files, so they sync with iCloud Drive and AirDrop.", "muted", "p", "position:absolute;top:470px;left:24px;right:24px;font:var(--t-caption)")}
    <div class="home-bar"></div>`],

  ["formation", "Formation picker (sheet)", () => `${editor(0, "4-3-3", { hits: false })}${sheet(200, "Formation", `
    <div class="seg" role="tablist">${["11-a-side", "7-a-side", "5-a-side"].map((l, i) => `<button role="tab" data-testid="formation.size.${["full", "seven", "five"][i]}" aria-selected="${i === 0}">${l}</button>`).join("")}</div>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:16px 0">${FORMATIONS.filter(f => f.pitch === "full").slice(0, 6).map(f =>
      `<button class="tile" role="tab" data-testid="formation.${f.id}" aria-selected="${f.id === "4-3-3"}" style="height:128px">${miniFormation(f)}${f.name}</button>`).join("")}</div>
    ${btn("formation.apply", "Use 4-3-3", "capsule")}`, "formation.close")}`],

  ["board", "Board: player 3 selected, actions under the pitch", () => `${editor(0, "4-3-3", { selected: "h3", canUndo: false,
      ctx: ctx("selection.label", "3 · Full-back", [["selection.edit", "Edit"], ["selection.run", "Draw run"], ["selection.delete", "Remove"]]) })}
    ${strip(0)}${toolbar()}`],

  ["board--empty", "Board: empty (blank pitch)", () => `${status()}${nav("Untitled tactic", false)}${meta("No players", "Step 1 of 1 · 1.2 s")}${Board.html(W, {}, [], {})}
    <div class="abs" style="top:300px;left:48px;right:48px;text-align:center">${txt("board.empty.message", "Pick a formation to start", "", "p", "font:var(--t-title);margin:0 0 16px")}
      ${btn("board.empty.pick", "Choose formation", "capsule")}</div>${toolbar()}`],

  ["inspector", "Player sheet: name, number, role, side", () => `${editor(0, "4-3-3", { selected: "h3", dim: true, hits: false })}${sheet(260, "Number 3", `
    <div style="display:flex;gap:10px"><input class="field" data-testid="inspector.name" placeholder="Name" value="Ade" aria-label="Name">
      <input class="field" data-testid="inspector.number" value="3" inputmode="numeric" aria-label="Shirt number" style="width:88px;text-align:center"></div>
    ${txt("inspector.role-label", "Role · Defenders", "group-label", "p")}
    ${ROLES.filter(r => r.line === "def").slice(0, 4).map(r => btn(`inspector.role.${r.id}`, `<span>${r.name}</span>${r.id === "full-back" ? `<span style="color:var(--accent)">${ic("check", 20)}</span>` : ""}`, "option")).join("")}
    ${txt("inspector.side-label", "Side", "group-label", "p")}
    <div class="seg" role="tablist" data-testid-group="side"><button role="tab" data-testid="inspector.side.home" aria-selected="true">Us (filled)</button><button role="tab" data-testid="inspector.side.away" aria-selected="false">Them (ring)</button></div>
    ${btn("inspector.delete", "Delete player", "capsule quiet", "", 'style="margin-top:18px;color:var(--danger)"')}`, "inspector.close")}`],

  ["board--step-selected", "Board: step 3 selected (duration and actions)", () => `${editor(2, "4-3-3", {
      ctx: ctx("steps.hint", "Step 3", [["step.duration", "1.2 s"], ["step.duplicate", "Duplicate"], ["step.note", "Note"], ["step.delete", "Delete"]]) })}
    ${strip(2)}${toolbar()}`],

  ["board--undo-toast", "Board: step deleted, with Undo", () => `${editor(1, "4-3-3", { right: "Step 2 of 4 · 1.4 s" })}
    <div class="toast" data-testid-group="toast">${txt("toast.message", "Deleted step 3")}${btn("toast.undo", "Undo", "")}</div>${strip(1, 4)}${toolbar()}`],

  ["playback", "Playing: step 4, segments and handwritten note", () => {
    const trails = Object.values(STEPS[1].runs || {}).map(r => ({ kind: "run", points: r.points }));
    return `${status()}${nav(HERO.title)}${board(3, { trails })}${txt("playback.time", "0:05 / 0:08", "", "span", "position:absolute;top:706px;right:24px;font:var(--t-caption);color:var(--muted)")}
    <div class="abs" data-testid="playback.scrubber" role="slider" aria-label="Step 4 of 5" tabindex="0" style="top:622px;left:24px;right:24px;height:44px;display:flex;gap:6px;align-items:center">
      ${STEPS.map((_, i) => `<i style="flex:1;height:6px;border-radius:3px;background:linear-gradient(90deg,var(--accent) ${i < 3 ? 100 : i === 3 ? 55 : 0}%,var(--surface-2) 0)"></i>`).join("")}</div>
    ${txt("playback.note", `<span style="font:var(--t-caption);color:var(--muted)">Step 4 of 5 · </span>${STEPS[3].note}`, "note", "p", "position:absolute;top:670px;left:24px;right:24px;margin:0;font-size:19px")}
    <div class="toolbar" style="justify-content:space-between;padding:6px 18px 0">
      ${btn("playback.loop", ic("loop", 22), "icon-btn", "Loop", 'aria-pressed="true" style="color:var(--accent)"')}${btn("playback.prev", ic("prev", 22), "icon-btn", "Previous step")}
      ${btn("playback.toggle", `<span class="disc" style="color:var(--accent-ink)">${ic("pause")}</span>Pause`, "tool primary")}
      ${btn("playback.next", ic("next", 22), "icon-btn", "Next step")}
      <div class="seg" style="width:96px;align-self:flex-start;margin-top:6px"><button role="tab" data-testid="playback.speed.half" aria-selected="false">½×</button><button role="tab" data-testid="playback.speed.one" aria-selected="true">1×</button></div></div><div class="home-bar"></div>`;
  }],

  ["draw", "Draw mode: drawing 3's run with a finger", () => {
    const stroke = STEPS[1].runs.h3.points.slice(0, 2).concat([{ x: 0.065, y: 0.5 }]);
    return `${status()}<div class="nav">${btn("draw.cancel", ic("close"), "icon-btn", "Cancel drawing")}${txt("draw.title", "Draw", "title")}${btn("draw.done", ic("check"), "icon-btn", "Done", 'style="background:var(--accent);color:var(--accent-ink)"')}</div>
    ${txt("draw.hint", "Start on a player to draw their run.", "note", "p", "position:absolute;top:632px;left:24px;right:24px;margin:0;text-align:center;font-size:18px;color:var(--muted)")}
    ${Board.html(W, pos(1), [], { stroke, selected: "h3" })}
    <div class="abs" style="left:16px;right:16px;bottom:34px;background:var(--surface-2);border-radius:24px;padding:10px 12px;box-shadow:0 8px 30px rgba(0,0,0,.5)">
      ${txt("draw.kind-help", "Run · solid line · the player follows it", "", "p", "margin:2px 6px 8px;font:var(--t-caption);color:var(--muted)")}
      <div style="display:flex;gap:6px">${[["run", "Run", '<path d="M3 12 H21" stroke-width="2.6"/>'], ["pass", "Pass", '<path d="M3 12 H21" stroke-width="2.6" stroke-dasharray="4 3"/>'],
        ["dribble", "Dribble", '<path d="M3 12 l3 -3 l3 6 l3 -6 l3 6 l3 -6 l3 3" stroke-width="2.2"/>'], ["press", "Press", '<path d="M6 7 L11 12 L6 17 M12 7 L17 12 L12 17" stroke-width="2.4"/>']].map(([k, l, d], i) =>
        `<button role="tab" data-testid="draw.kind.${k}" aria-selected="${i === 0}" class="tile" style="flex:1;height:64px;${i === 0 ? "border-color:var(--accent)" : ""}"><svg width="40" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--${k})" stroke-linecap="round" aria-hidden="true">${d}</svg>${l}</button>`).join("")}</div></div>`;
  }],

  ["export", "Export sheet: 9:16 with size before export", () => exportSheet(`
    ${presets()}${btn("export.title-band", `Title band<i></i>`, "switch", "", 'role="switch" aria-checked="true"')}${btn("export.notes", `Step notes<i></i>`, "switch", "", 'role="switch" aria-checked="true"')}`,
    `${txt("export.size", "About 4 MB · 8 s · 1080 × 1920", "", "p", "margin:0;font:var(--t-headline)")}${txt("export.size-help", "Estimate. Plays in WhatsApp and Discord.", "muted", "p", "margin:2px 0 14px;font:var(--t-caption)")}${btn("export.start", "Export video", "capsule")}`)],

  ["export--rendering", "Export: rendering, with an honest count", () => exportSheet(`
    ${txt("export.progress", "Rendering 126 of 240 frames", "", "p", "margin:24px 0 4px;font:var(--t-headline)")}
    ${txt("export.progress-help", "About 3 seconds left. Keep CenterSpot open until it's done.", "muted", "p", "margin:0;font:var(--t-caption)")}
    <div data-testid="export.progress-bar" role="progressbar" aria-valuenow="53" style="height:8px;border-radius:4px;margin-top:16px;background:linear-gradient(90deg,var(--accent) 53%,var(--surface-3) 0)"></div>`,
    btn("export.cancel", "Cancel", "capsule quiet"), 0.53)],

  ["export--done", "Export: done, with the real size", () => exportSheet(`
    ${txt("export.done", "Video ready", "", "p", "margin:24px 0 4px;font:var(--t-title)")}${txt("export.done-size", "4.0 MB · 8 s · 1080 × 1920", "muted", "p", "margin:0;font:var(--t-body)")}`,
    `${btn("export.share", "Share video", "capsule")}<div style="height:10px"></div>${btn("export.save", "Save to Photos", "capsule quiet")}`)],

  ["export--error", "Export: failed, with a way out", () => exportSheet(`
    ${txt("export.error", "Couldn't make the video. Try again, or export an image.", "", "p", "margin:24px 0 0;font:var(--t-headline)")}`,
    `${btn("export.retry", "Try again", "capsule")}<div style="height:10px"></div>${btn("export.image", "Export an image", "capsule quiet")}`)],

  ["share", "Share: the video, or the editable file", () => `${editor(0, "4-3-3", { hits: false })}${sheet(470, "Share", `
    ${btn("share.video", `${ic("video", 26)}<span style="flex:1;margin-left:12px;text-align:left"><b style="display:block;font:var(--t-headline)">Video</b><small class="muted" style="font:var(--t-caption)">9:16 · about 4 MB · for WhatsApp, Discord, TikTok</small></span>`, "option", "", 'style="min-height:72px;justify-content:flex-start"')}
    ${btn("share.image", `${ic("photo", 26)}<span style="flex:1;margin-left:12px;text-align:left"><b style="display:block;font:var(--t-headline)">Image of step 1</b><small class="muted" style="font:var(--t-caption)">PNG for a lineup post</small></span>`, "option", "", 'style="min-height:72px;justify-content:flex-start"')}
    ${btn("share.file", `${ic("file", 26)}<span style="flex:1;margin-left:12px;text-align:left"><b style="display:block;font:var(--t-headline)">Tactic file</b><small class="muted" style="font:var(--t-caption)">${HERO.title}.tactic · ${Math.round(HERO_BYTES / 1024)} KB · opens in CenterSpot to edit</small></span>`, "option", "", 'style="min-height:72px;justify-content:flex-start"')}`, "share.close")}`],

  ["import-error", "Opening a file that isn't a tactic", () => `${status()}${nav("Untitled tactic", false)}${Board.html(W, {}, [], {})}<div class="scrim"></div>
    <div class="alert">${txt("import.error.title", "Can't open this file", "", "h3")}${txt("import.error.message", "This file isn't a tactic we can open.", "muted", "p", "margin:0 0 16px")}${btn("import.error.ok", "OK", "capsule quiet")}</div>`],
];

// Onboarding (D-58). Welcome: three pages on first launch, each showing the real board (BoardRenderer + Timeline in the app,
// decorative, one VoiceOver label). Then tips on the example move, one at a time, each pointing at the real control.
const runArrows = i => Object.values(STEPS[i].runs || {}).map(r => ({ kind: "run", points: r.points }));
const lerpPos = (a, b, t) => Object.fromEntries(Object.entries(a).map(([k, p]) => [k, b[k] ? { x: p.x + (b[k].x - p.x) * t, y: p.y + (b[k].y - p.y) * t } : p]));
const still = (w, positions, arrows, opts = {}) => Board.html(w, positions, arrows, { ...opts, hits: false, testid: "x" }).replace(' data-testid="x"', "");
const WELCOME = [
  { title: "Draw the move, not just the shape.", body: "Place your players, then add steps. Each step is one moment of the move.",
    label: "A pitch showing a five-step move", art: () => `${still(222, pos(1), [...STEPS[1].arrows, ...runArrows(1)])}
      <div class="ob-chips">${STEPS.map((s, i) => `<span class="step ${i === 1 ? "on" : ""}"><b>${i + 1}</b><small>${s.duration} s</small></span>`).join("")}</div>` },
  { title: "Press Play. Watch it move.", body: "Every player runs from step to step, along the runs and passes you draw.",
    label: "A pitch with the move playing: a run and a pass", art: () => `${still(222, lerpPos(pos(2), pos(3), 0.45), STEPS[2].arrows, { trails: runArrows(1) })}
      <div class="ob-scrub">${STEPS.map((_, i) => `<i style="background:linear-gradient(90deg,var(--accent) ${i < 2 ? 100 : i === 2 ? 45 : 0}%,var(--surface-2) 0)"></i>`).join("")}</div>` },
  { title: "Share it as a 9:16 clip.", body: "One tap makes a vertical video for the team chat, with your title on top.",
    label: "A vertical video of the move, with its title at the top", art: () => `<div class="ob-clip"><div class="title-band">${HERO.title}</div>
      ${still(203, lerpPos(pos(0), pos(1), 0.8), STEPS[0].arrows)}<div class="clip-note">${STEPS[0].note}</div><div class="mark">CenterSpot</div></div>` },
];
const dots = (page, extra = "") => `<div class="dots" data-testid="onboarding.dots" role="slider" tabindex="0" aria-label="Page ${page} of 3" aria-valuenow="${page}" aria-valuemin="1" aria-valuemax="3" ${extra}>${[1, 2, 3].map(i => `<i class="${i === page ? "on" : ""}"></i>`).join("")}</div>`;
const cta = page => page < 3 ? btn("onboarding.next", "Next", "capsule ob-cta") : btn("onboarding.start", "Start", "capsule ob-cta");
const welcome = page => {
  const p = WELCOME[page - 1];
  return `${status()}<div class="abs" style="inset:0" data-testid="onboarding.page">
    <div class="ob-art" role="img" aria-label="${p.label}" data-testid="onboarding.art.${page}">${p.art()}</div>
    <div class="ob-copy">${txt("onboarding.title", p.title, "", "h1")}${txt("onboarding.body", p.body, "", "p")}</div></div>
    ${btn("onboarding.skip", "Skip", "skip")}${dots(page)}${cta(page)}<div class="home-bar"></div>`;
};
// At accessibility text sizes the decorative board steps aside, the copy scrolls, and Skip, the dots and Next stay pinned.
const welcomeAX5 = () => `${status()}<div class="abs" data-testid="onboarding.page" style="top:104px;left:0;right:0;height:572px;overflow:hidden">
    <div style="padding:8px 24px 0">${txt("onboarding.title", WELCOME[0].title, "", "h1", "margin:0 0 16px;font:800 60px/1.1 var(--font-ui)")}
    ${txt("onboarding.body", WELCOME[0].body, "", "p", "margin:0;font:600 47px/1.25 var(--font-ui);color:var(--muted)")}</div>
    <div style="position:absolute;left:0;right:0;bottom:0;height:56px;background:linear-gradient(rgba(11,15,20,0),var(--bg))"></div>
    <div data-testid="onboarding.scroll-indicator" style="position:absolute;right:4px;top:6px;width:3px;height:180px;border-radius:2px;background:var(--muted);opacity:.7"></div></div>
  ${btn("onboarding.skip", "Skip", "skip")}${dots(1, 'style="top:684px"')}${btn("onboarding.next", "Next", "capsule ob-cta", "", 'style="height:76px;font-size:53px;bottom:36px"')}<div class="home-bar"></div>`;

// A tip is a Floodlight Chalk popover: title, one line, a close button, and an arrow at the control it names.
// data-anchor names that control; placeTips() below positions the tip from its real frame, as popoverTip(arrowEdge:) does.
const TIPS = [
  ["drag", "Move a player", "Drag any player to where they should be.", "board.token.h3", "bottom"],
  ["step", "Every step is a moment", "Tap step 2 to see where everyone goes.", "steps.chip.2", "top"],
  ["play", "Watch it move", "Press Play and your players run the move.", "toolbar.play", "top"],
  ["draw", "Draw a run", "Tap Draw, then drag from a player to show their run.", "toolbar.draw", "top"],
  ["export", "Share the clip", "Export turns it into a 9:16 video.", "toolbar.export", "top"],
];
const tip = name => {
  const [, title, message, anchor, edge] = TIPS.find(t => t[0] === name);
  return `<div class="tip" role="dialog" aria-label="Tip: ${title}" data-testid="tip.${name}" data-anchor="${anchor}" data-edge="${edge}">
    <div class="tip-text">${txt(`tip.${name}.title`, title, "", "h4")}${txt(`tip.${name}.message`, message, "", "p")}</div>
    ${btn(`tip.${name}.close`, ic("close", 18), "icon-btn", "Close tip")}
    <svg class="arrow" data-testid="tip.${name}.arrow" viewBox="0 0 20 10" aria-hidden="true"><path d="M0 1.5 L10 9.5 L20 1.5 Z" fill="var(--surface-3)"/>
      <rect x="0.5" y="0" width="19" height="2.5" fill="var(--surface-3)"/><path d="M0 1.5 L10 9.5 L20 1.5" fill="none" stroke="var(--accent)" stroke-width="1.5" stroke-linejoin="round"/></svg></div>`;
};
const boardWithTip = (i, name, opts = {}) => `${editor(i, "4-3-3", opts)}${strip(i)}${toolbar()}${tip(name)}`;
SCREENS.push(
  ["onboarding-1", "Welcome 1 of 3: steps are the idea (board cycles steps 1 to 5)", () => welcome(1)],
  ["onboarding-2", "Welcome 2 of 3: Play (the overlap plays, with a run and a pass)", () => welcome(2)],
  ["onboarding-3", "Welcome 3 of 3: the 9:16 clip (plays inside the frame)", () => welcome(3)],
  ["onboarding-1--ax5", "Welcome 1 at AX5 text: board hidden, copy scrolls, Skip and Next pinned", welcomeAX5],
  ["tip-drag", "Tip 1: drag a player (after Start opens the example)", () => boardWithTip(0, "drag")],
  ["tip-step", "Tip 2: tap a step (after a player is dragged)", () => boardWithTip(0, "step")],
  ["tip-play", "Tip 3: press Play (after step 2 is tapped)", () => boardWithTip(1, "play")],
  ["tip-draw", "Tip 4: draw a run (after playback stops)", () => boardWithTip(0, "draw")],
  ["tip-export", "Tip 5: export (after a run is drawn)", () => boardWithTip(1, "export", { arrows: [...STEPS[1].arrows, ...runArrows(1)] })],
);

function presets() {
  return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:6px">${[["vertical", "Story 9:16", 18, 30], ["square", "Square 1:1", 26, 26], ["wide", "Wide 16:9", 32, 18], ["image", "Image", 26, 22]].map(([id, l, w, h], i) =>
    `<button role="tab" class="tile" data-testid="export.preset.${id}" aria-selected="${i === 0}" style="height:78px;gap:6px;font-size:12px"><i style="width:${w * .8}px;height:${h * .8}px;border:2px solid var(--text);border-radius:4px"></i>${l}</button>`).join("")}</div>`;
}

function exportSheet(controls, footer, progress) {
  const vw = 128, vh = vw * 16 / 9;
  const veil = progress ? `<div style="position:absolute;inset:0;background:rgba(11,15,20,.55);border-radius:10px"></div><div style="position:absolute;left:8px;right:8px;bottom:8px;height:5px;border-radius:3px;background:linear-gradient(90deg,var(--accent) ${progress * 100}%,rgba(255,255,255,.25) 0)"></div>` : "";
  return `${editor(0, "4-3-3", { hits: false })}${sheet(null, "Export", `
    <div style="display:flex;gap:16px"><div data-testid="export.preview" style="position:relative;width:${vw}px;height:${vh}px;flex-shrink:0;background:var(--bg);border-radius:10px;padding:10px 6px">
      <div style="font:800 9px var(--font-ui);margin:0 2px 4px">${HERO.title}</div>${Board.html(116, pos(3), STEPS[3].arrows, { hits: false, testid: "x" }).replace('data-testid="x"', "").replace('class="board"', 'class="board" style="position:static"')}
      <div style="font:400 9px var(--font-note);margin:4px 2px 0">${STEPS[3].note}</div><div style="position:absolute;right:8px;bottom:${progress ? 18 : 8}px;font:800 8px var(--font-ui);color:var(--muted)">CenterSpot</div>${veil}</div>
      <div style="flex:1">${controls}</div></div><div style="margin-top:18px">${footer}</div>`, "export.close")}`;
}

const gallery = document.getElementById("gallery");
SCREENS.forEach(([id, caption, render]) => {
  const wrap = document.createElement("div");
  wrap.innerHTML = `<p class="cap">${caption}</p><section class="frame" data-screen="${id}">${render()}</section>`;
  gallery.appendChild(wrap);
});

// Puts each tip next to the control it names: full width less 16 pt each side (TipKit on iPhone), arrow on the control's centre,
// its point touching, never covering, what the control draws (a token's 44 pt hit area; the Play disc, which rises above its button).
function placeTips() {
  document.querySelectorAll(".tip[data-anchor]").forEach(t => {
    const frame = t.closest("[data-screen]"), f = frame.getBoundingClientRect();
    const el = frame.querySelector(`[data-testid="${t.dataset.anchor}"]`);
    const rects = [el, ...el.querySelectorAll("*")].map(e => e.getBoundingClientRect()).filter(r => r.width && r.height);
    const a = { top: Math.min(...rects.map(r => r.top)), bottom: Math.max(...rects.map(r => r.bottom)), cx: el.getBoundingClientRect().left + el.offsetWidth / 2 };
    const cx = a.cx - f.left, w = t.offsetWidth, gap = 0, arrowH = 8, left = 16, arrow = t.querySelector(".arrow");
    arrow.style.left = `${Math.min(Math.max(14, cx - left - 10), w - 34)}px`;
    if (t.dataset.edge === "top") {
      t.style.bottom = `${f.bottom - a.top + gap + arrowH}px`;
      arrow.style.top = "calc(100% - 1px)";
    } else {
      t.style.top = `${a.bottom - f.top + gap + arrowH}px`;
      arrow.style.bottom = "calc(100% - 1px)";
      arrow.style.transform = "rotate(180deg)";
    }
  });
}
placeTips();
