// Onboarding in the broadcast look (D-58, D-78), replacing the 7 Nov draft's art and copy where they differ.
// Welcome: page 1 steps on the flat dark board; page 2 the tilted Broadcast camera playing the move; page 3 the 9:16
// clip in Broadcast. Then the five tips on the example move, on the dark board. "Show tips again" in the library's
// More menu replays the welcome and resets the tips.
//
// Notes for engineering
// - The welcome art is the real board (BoardRenderer + Timeline, Options.broadcast with CameraTrack on pages 2 and 3),
//   decorative, one VoiceOver label per page; hidden at the accessibility text sizes (onboarding-1--ax5 stands).
// - Tips: one TipGroup(.ordered), popover tips anchored to the real controls; never while playing, drawing or with a
//   sheet open. The camera switch only exists in playback, so the Play tip names it in words and points at Play.

ICONS.bulb = '<path d="M9 18 H15 M10 21 H14 M12 3 a6 6 0 0 0 -3.5 10.9 c.6 .5 1 1.2 1 2 V17 H14.5 V15.9 c0-.8 .4-1.5 1-2 A6 6 0 0 0 12 3 Z" stroke-width="2"/>';

const OB_CAM = { pw: 470, tilt: 54, focus: .3, cx: .32, persp: 790, horizon: 0 };
const OB_CLIP_CAM = { pw: 330, tilt: 54, focus: .32, cx: .32, persp: 560, horizon: 0, lift: 40 };

const WELCOME_BC = [
  { title: "Draw the move, not just the shape.", body: "Place your players, then add steps. Each step is one moment of the move.",
    label: "A pitch showing a five-step move",
    art: () => `${staticBoard(222, 1, {}, { arrows: [...STEPS[1].arrows, ...runArrows(1)] })}
      <div class="ob-chips">${STEPS.map((s, i) => `<span class="step ${i === 1 ? "on" : ""}"><b>${i + 1}</b><small>${s.duration} s</small></span>`).join("")}</div>` },
  { title: "Press Play. Watch it move.", body: "Players run from step to step, and the Broadcast camera follows the ball.",
    label: "The move playing in the tilted Broadcast camera",
    art: () => `<div style="position:relative;width:393px;height:340px">${BC.tilted(393, 340, lerpPos(pos(2), pos(3), 0.45), STEPS[2].arrows, {}, OB_CAM, "onboarding.board.2")}</div>
      <div class="ob-scrub">${STEPS.map((_, i) => `<i style="background:linear-gradient(90deg,var(--accent) ${i < 2 ? 100 : i === 2 ? 45 : 0}%,var(--surface-2) 0)"></i>`).join("")}</div>` },
  { title: "Share it as a 9:16 clip.", body: "One tap makes a vertical video for the team chat, with your title on top.",
    label: "A vertical video of the move in the Broadcast camera, with its title at the top",
    art: () => `<div class="ob-clip" style="padding:12px 0;overflow:hidden">${txt("onboarding.clip.title", HERO.title, "title-band", "div", "padding:0 10px")}
      <div style="position:relative;width:223px;height:300px">${BC.tilted(223, 300, pos(3), STEPS[3].arrows, M4, OB_CLIP_CAM, "onboarding.board.3")}</div>
      ${txt("onboarding.clip.note", STEPS[3].note, "clip-note", "div", "padding:0 10px")}${txt("onboarding.clip.mark", "Agmen", "mark", "div")}</div>` },
];

const welcomeBc = page => {
  const p = WELCOME_BC[page - 1];
  return `${status()}<div class="abs" style="inset:0" data-testid="onboarding.page">
    <div class="ob-art" role="img" aria-label="${p.label}" data-testid="onboarding.art.${page}">${p.art()}</div>
    <div class="ob-copy">${txt("onboarding.title", p.title, "", "h1")}${txt("onboarding.body", p.body, "", "p")}</div></div>
    ${btn("onboarding.skip", "Skip", "skip")}${dots(page)}${cta(page)}<div class="home-bar"></div>`;
};

const TIPS_BC = [
  ["drag", "Move a player", "Drag any player to where they should be.", "board.token.h3", "bottom"],
  ["step", "Every step is a moment", "Tap step 2 to see where everyone goes.", "steps.chip.2", "top"],
  ["play", "Watch it move", "Press Play to run the move. Pick Flat or Broadcast at the top.", "toolbar.play", "top"],
  ["draw", "Draw a run", "Tap Draw, then drag from a player to show their run.", "toolbar.draw", "top"],
  ["export", "Share the clip", "Export turns it into a 9:16 video.", "toolbar.export", "top"],
];
const tipBc = name => {
  const [, title, message, anchor, edge] = TIPS_BC.find(t => t[0] === name);
  return `<div class="tip" role="dialog" aria-label="Tip: ${title}" data-testid="tip.${name}" data-anchor="${anchor}" data-edge="${edge}">
    <div class="tip-text">${txt(`tip.${name}.title`, title, "", "h4")}${txt(`tip.${name}.message`, message, "", "p")}</div>
    ${btn(`tip.${name}.close`, ic("close", 18), "icon-btn", "Close tip")}
    <svg class="arrow" data-testid="tip.${name}.arrow" viewBox="0 0 20 10" aria-hidden="true"><path d="M0 1.5 L10 9.5 L20 1.5 Z" fill="var(--surface-3)"/>
      <rect x="0.5" y="0" width="19" height="2.5" fill="var(--surface-3)"/><path d="M0 1.5 L10 9.5 L20 1.5" fill="none" stroke="var(--accent)" stroke-width="1.5" stroke-linejoin="round"/></svg></div>`;
};
const boardTipBc = (i, name, arrows) => `${status()}${navEdit()}${flatBoard(W, i, {}, { hits: true, ...(arrows ? { arrows } : {}) })}
  ${meta("4-3-3", `Step ${i + 1} of ${STEPS.length} · ${STEPS[i].duration} s`)}${strip(i)}${toolbar2()}${tipBc(name)}`;

const libraryMenu = () => `${status()}${libArt(393)}
  <div class="abs" style="top:64px;left:24px;right:24px">${txt("library.title", "Agmen", "", "h1", "font:var(--t-largetitle);margin:0")}
    ${txt("library.tagline", "Draw the move, not just the shape.", "note", "p", "margin:4px 0 0;color:var(--muted)")}</div>
  ${btn("library.more", ic("more", 24), "icon-btn", "More", 'style="position:absolute;top:60px;right:12px;color:var(--text)"')}
  <div class="abs" style="top:164px;left:24px;right:24px">${btn("launch.new", `${ic("plus", 20)} New tactic`, "capsule", "", 'style="display:flex;align-items:center;justify-content:center;gap:8px"')}
    ${txt("library.recent", "Recent", "", "h2", "margin:24px 0 12px;font:var(--t-headline);color:var(--muted)")}
    <div class="lib-grid" style="grid-template-columns:repeat(3,1fr)">${LIB.slice(0, 12).map((t, i) => libCard(i + 1, t, PHONE_CARD)).join("")}</div></div>
  <div class="abs" style="inset:0;background:rgba(0,0,0,.35)" aria-hidden="true"></div>
  <div class="abs" role="menu" data-testid="library.menu" style="top:108px;right:16px;width:250px;background:var(--surface-2);border-radius:14px;box-shadow:0 12px 40px rgba(0,0,0,.6);overflow:hidden">
    ${btn("library.menu.tips", `Show tips again${ic("bulb", 22)}`, "", "", 'role="menuitem" style="display:flex;align-items:center;justify-content:space-between;width:100%;height:52px;padding:0 16px;font:var(--t-body);color:var(--text)"')}</div>
  <div class="home-bar"></div>`;

const OB_SCREENS = [
  ["onboarding-1--bc", "D-78 · Welcome 1 of 3: steps, on the dark flat board (cycles steps 1 to 5)", () => welcomeBc(1)],
  ["onboarding-2--bc", "D-78 · Welcome 2 of 3: Press Play, in the tilted Broadcast camera following the ball", () => welcomeBc(2)],
  ["onboarding-3--bc", "D-78 · Welcome 3 of 3: the 9:16 clip, in Broadcast (plays inside the frame)", () => welcomeBc(3)],
  ["tip-drag--bc", "D-78 · Tip 1: drag a player (after Start opens the example)", () => boardTipBc(0, "drag")],
  ["tip-step--bc", "D-78 · Tip 2: tap a step (after a player is dragged)", () => boardTipBc(0, "step")],
  ["tip-play--bc", "D-78 · Tip 3: press Play; the camera switch at the top picks Flat or Broadcast", () => boardTipBc(1, "play")],
  ["tip-draw--bc", "D-78 · Tip 4: draw a run (after playback stops)", () => boardTipBc(0, "draw")],
  ["tip-export--bc", "D-78 · Tip 5: export (after a run is drawn)", () => boardTipBc(1, "export", [...STEPS[1].arrows, ...runArrows(1)])],
  ["library--menu", "D-78 · Library › More: Show tips again replays the welcome and resets the tips", libraryMenu],
];

document.body.insertAdjacentHTML("beforeend", `<main class="gallery wide" id="gallery-onboarding"><div class="section-head"><h2>Onboarding in the broadcast look (D-58, D-78)</h2>
  <p>Three welcome pages (page 2 and the clip in the Broadcast camera), five tips on the example move, and Show tips again in the library's More menu. Skip goes to the library; × closes a tip and lets the next one come.</p></div></main>`);
const obGallery = document.getElementById("gallery-onboarding");
OB_SCREENS.forEach(([id, caption, render]) => {
  const wrap = document.createElement("div");
  wrap.innerHTML = `<p class="cap">${caption}</p><section class="frame" data-screen="${id}">${render()}</section>`;
  obGallery.appendChild(wrap);
});
placeDiscs();
placeTips();
