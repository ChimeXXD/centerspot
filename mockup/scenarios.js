// Scenarios (D-94): a ready-made start for a move, built from the formation picked on the Formation sheet.
// This file is the spec the app ports: `Scenario.build` in Swift must give the same players, numbers and positions
// (mockup/scenario-fixtures.json is written from it). Coordinates as in presets: x across 0 (left) to 1, y up the
// pitch from our goal (0) to theirs (1). "Attacking" means we have the ball; "Defending" means they do.

const round = v => Math.round(v * 1000) / 1000;
const clamp = (v, lo = 0.02, hi = 0.98) => Math.min(hi, Math.max(lo, v));
const pt = (x, y) => ({ x: round(clamp(x)), y: round(clamp(y)) });
const mirror = p => ({ x: round(1 - p.x), y: round(1 - p.y) });

// Every role in presets/roles.json falls in one of nine groups; phases and set pieces speak in groups.
const GROUP = {
  "goalkeeper": "GK", "sweeper-keeper": "GK",
  "centre-back": "CB", "ball-playing-centre-back": "CB",
  "full-back": "FB", "inverted-full-back": "FB", "wing-back": "FB",
  "holding-midfielder": "DM", "deep-playmaker": "DM",
  "central-midfielder": "CM", "box-to-box": "CM",
  "wide-midfielder": "WM",
  "attacking-midfielder": "AM", "advanced-playmaker": "AM", "free-role": "AM",
  "winger": "W", "inside-forward": "W",
  "striker": "ST", "shadow-striker": "ST", "target-forward": "ST", "false-nine": "ST", "pressing-forward": "ST",
};

// The opponent's shape for each pitch size: the most common one there.
const OPPONENT = { full: "4-4-2", sevenASide: "7-2-3-1", fiveASide: "5-2-2" };

const formation = id => FORMATIONS.find(f => f.id === id);
const slotsOf = f => f.slots.map(([number, role, x, y]) => ({ number, role, group: GROUP[role] || "CM", x, y }));

// Team phases: how a formation stands in each phase. Lines move up or down (y' = a + b·y), the team narrows or
// widens about the middle (w), and some groups move further (dy, wx). The keeper has a fixed height per phase.
const PHASES = {
  // In possession
  buildUp:    { a: 0.02, b: 0.74, w: 1.05, gk: 0.05, g: { CB: { wx: 1.75, dy: -0.04 }, FB: { dy: 0.1, wx: 1.15 }, DM: { dy: -0.04 } } },
  midfield:   { a: 0.12, b: 0.8, w: 1.05, gk: 0.1, g: { FB: { dy: 0.1, wx: 1.1 }, CB: { wx: 1.25 } } },
  finalThird: { a: 0.26, b: 0.7, w: 1.0, gk: 0.16, g: { FB: { dy: 0.22, wx: 1.12 }, CB: { wx: 1.3 }, W: { dy: 0.04, wx: 1.15 }, WM: { dy: 0.12, wx: 1.15 } } },
  counter:    { a: 0.12, b: 0.86, w: 1.1, gk: 0.08, g: { W: { dy: 0.08, wx: 1.2 }, ST: { dy: 0.06 }, FB: { dy: 0.04 } } },
  justWon:    { a: 0.22, b: 0.7, w: 0.95, gk: 0.14, g: { FB: { dy: 0.12 } } },
  // Out of possession
  highPress:  { a: 0.3, b: 0.62, w: 0.95, gk: 0.14, g: { ST: { dy: 0.04 }, W: { dy: 0.04, wx: 1.05 } } },
  midBlock:   { a: 0.14, b: 0.5, w: 0.78, gk: 0.06, g: {} },
  lowBlock:   { a: 0.05, b: 0.36, w: 0.72, gk: 0.03, g: { W: { dy: -0.04 }, WM: { dy: -0.03 } } },
  caught:     { a: 0.26, b: 0.7, w: 1.0, gk: 0.16, g: { FB: { dy: 0.2, wx: 1.12 } } },
  counterPress: { a: 0.24, b: 0.68, w: 0.85, gk: 0.15, g: {} },
};

// A formation in a phase, in its own team's frame (attacking up), squeezed toward `focus` by `pull` (0…1).
function inPhase(slots, phase, { focus = null, pull = 0, shiftX = 0 } = {}) {
  const p = PHASES[phase];
  return slots.map(s => {
    if (s.group === "GK") return { ...s, p: pt(0.5, p.gk) };
    const g = p.g[s.group] || {};
    // A shift toward the ball leaves the far touchline's player wide (the switch's free winger).
    let x = 0.5 + (s.x - 0.5) * p.w * (g.wx || 1) + (s.x > 0.75 ? 0 : shiftX);
    let y = p.a + p.b * s.y + (g.dy || 0);
    if (focus) { x += (focus.x - x) * pull; y += (focus.y - y) * pull; }
    return { ...s, p: pt(x, y) };
  });
}

// Where the ball is in each team shape, in the frame of the side on it; the player standing nearest carries it.
const BALL_AT = { deep: [0.5, 0.36], leftWide: [0.08, 0.72], central: [0.5, 0.42] };

function carrier(placed, who) {
  if (who === "GK") return placed.find(s => s.group === "GK") || placed[0];
  const [x, y] = BALL_AT[who];
  const outfield = placed.filter(s => s.group !== "GK");
  return outfield[nearest(outfield.map(s => s.p), { x, y })];
}

// ---------------------------------------------------------------------------------------------------------------
// The catalogue. Each entry: id, name, line (the one-liner under the picture), group and the sizes it offers.

const SCENARIOS = [
  // Team shape: the side on the ball is in `on`, the other in `off`; `ball` names who carries it.
  { id: "build-up", group: "Team shape", name: "Build-up v press", line: "Keeper on the ball, centre-backs split, their front line presses",
    sizes: ["full", "sevenASide", "fiveASide"], team: { on: "buildUp", off: "highPress", ball: "GK" } },
  { id: "midfield", group: "Team shape", name: "Through midfield", line: "On the ball in the middle third, against a mid block",
    sizes: ["full", "sevenASide", "fiveASide"], team: { on: "midfield", off: "midBlock", ball: "deep" } },
  { id: "final-third", group: "Team shape", name: "Final third v low block", line: "Full-backs high, everyone in their half, they sit deep",
    sizes: ["full", "sevenASide", "fiveASide"], team: { on: "finalThird", off: "lowBlock", ball: "leftWide" } },
  { id: "switch", group: "Team shape", name: "Switch of play", line: "Overloaded on the left, the far winger free",
    sizes: ["full", "sevenASide"], team: { on: "finalThird", off: "midBlock", ball: "leftWide", onShift: -0.08, offShift: 0.1 } },
  { id: "counter", group: "Team shape", name: "Counter-attack", line: "Ball just won deep, their team caught upfield",
    sizes: ["full", "sevenASide", "fiveASide"], team: { on: "counter", off: "caught", ball: "central" } },
  { id: "counter-press", group: "Team shape", name: "Counter-press", line: "Ball just lost high: swarm it before they break",
    sizes: ["full", "sevenASide", "fiveASide"], team: { on: "justWon", off: "counterPress", ball: "deep", press: true } },

  // Small-sided: n of the side on the ball v m of the other, around `at` (in the attackers' frame).
  // `support` places the attackers off the ball, relative to the carrier ("in" points toward the middle).
  { id: "1v1-wing", group: "Small-sided", name: "1v1 on the wing", line: "Winger runs at the full-back", who: ["W,WM"], vs: ["FB"], n: 1, m: 1, at: [0.12, 0.74], support: [],
    sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "1v1-keeper", group: "Small-sided", name: "1v1 with the keeper", line: "Through on goal, only the keeper to beat", who: ["ST,W,AM"], vs: [], n: 1, m: 0, keeper: true,
    at: [0.5, 0.8], support: [], sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "2v1-overlap", group: "Small-sided", name: "2v1 overlap", line: "Full-back runs round the winger", who: ["W,WM", "FB"], vs: ["FB"], n: 2, m: 1, at: [0.16, 0.64],
    support: [[-0.06, -0.08]], sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "2v1-one-two", group: "Small-sided", name: "2v1 one-two", line: "Give and go past one defender", who: ["AM,CM", "ST"], vs: ["CB"], n: 2, m: 1, at: [0.42, 0.66],
    support: [[0.16, 0.06]], sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "2v2-box", group: "Small-sided", name: "2v2 in the box", line: "Two attackers, two defenders, the keeper", who: ["ST", "W,AM"], vs: ["CB", "CB,FB"], n: 2, m: 2, keeper: true, at: [0.34, 0.8],
    support: [[0.22, 0.06]], sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "3v1-rondo", group: "Small-sided", name: "3v1 keep the ball", line: "A triangle round one presser", who: ["CM,DM", "CM,AM", "CM,DM,AM"], vs: ["ST,AM"], n: 3, m: 1, at: [0.5, 0.48],
    support: [[0.14, 0.1], [-0.14, 0.1]], sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "3v2-counter", group: "Small-sided", name: "3v2 counter", line: "Three break on two, the keeper back", who: ["AM,CM,ST", "W,ST", "W,ST"], vs: ["CB", "CB"], n: 3, m: 2, keeper: true, at: [0.5, 0.6],
    support: [[0.24, -0.02], [-0.24, -0.02]], sizes: ["full", "sevenASide", "fiveASide"] },
  { id: "3v3-midfield", group: "Small-sided", name: "3v3 in midfield", line: "Even numbers in the middle third", who: ["DM,CM", "CM,AM", "CM,AM"], vs: ["CM,DM", "CM,AM", "CM,AM"], n: 3, m: 3, at: [0.5, 0.48],
    support: [[0.2, 0.08], [-0.2, 0.08]], sizes: ["full", "sevenASide"] },
  { id: "3v4-build-up", group: "Small-sided", name: "3v4 outnumbered", line: "Playing out with one fewer", who: ["DM,CB", "CB", "CB,FB"], vs: ["ST", "ST,AM", "W,WM", "W,WM,CM"], n: 3, m: 4, at: [0.5, 0.2],
    support: [[0.26, 0.04], [-0.26, 0.04]], sizes: ["full", "sevenASide"] },
  { id: "4v3-overload", group: "Small-sided", name: "4v3 flank overload", line: "One more on the left side", who: ["W,WM", "FB", "CM,AM", "ST,AM"], vs: ["FB", "CB", "WM,CM"], n: 4, m: 3, at: [0.2, 0.62],
    support: [[-0.08, -0.1], [0.16, 0.04], [0.12, 0.16]], sizes: ["full", "sevenASide"] },
  { id: "1v3-surrounded", group: "Small-sided", name: "1v3 surrounded", line: "One on the ball, three closing in", who: ["CM,AM"], vs: ["CM,DM", "CM", "AM,ST,W"], n: 1, m: 3, at: [0.5, 0.56],
    support: [], surround: true, sizes: ["full", "sevenASide"] },

  // Set pieces: fixed spots for the side taking it (`take`) and the other (`face`), in the taker's frame, each spot
  // with the groups that go there first. 11-a-side only, except kick-off.
  { id: "corner", group: "Set pieces", name: "Corner", line: "Near post, far post, edge of the box", sizes: ["full"], set: "corner" },
  { id: "free-kick-edge", group: "Set pieces", name: "Free kick, edge of the box", line: "A wall of four, runners ready", sizes: ["full"], set: "freeKickEdge" },
  { id: "free-kick-wide", group: "Set pieces", name: "Free kick, wide", line: "Whipped in from the right", sizes: ["full"], set: "freeKickWide" },
  { id: "goal-kick", group: "Set pieces", name: "Goal kick", line: "Keeper to a centre-back in the box", sizes: ["full"], set: "goalKick" },
  { id: "throw-in", group: "Set pieces", name: "Throw-in", line: "Down the left, in their half", sizes: ["full"], set: "throwIn" },
  { id: "penalty", group: "Set pieces", name: "Penalty", line: "Everyone outside the box", sizes: ["full"], set: "penalty" },
  { id: "kick-off", group: "Set pieces", name: "Kick-off", line: "Both teams in their own half", sizes: ["full", "sevenASide", "fiveASide"], kickOff: true },
];

const SET_PIECES = {
  corner: {
    take: [["GK", 0.5, 0.12], ["CB", 0.56, 0.93], ["CB", 0.46, 0.9], ["ST", 0.42, 0.95], ["ST,W", 0.52, 0.88],
           ["W,WM,AM", 0.01, 0.995], ["AM,CM", 0.34, 0.82], ["CM,DM", 0.6, 0.8], ["FB", 0.3, 0.62], ["DM,FB", 0.55, 0.58], ["W,FB,WM", 0.82, 0.74]],
    face: [["GK", 0.5, 0.985], ["W,WM", 0.44, 0.99], ["CB", 0.48, 0.95], ["CB", 0.56, 0.95], ["FB", 0.4, 0.94], ["FB", 0.62, 0.92],
           ["DM,CM", 0.47, 0.89], ["CM", 0.58, 0.87], ["AM,CM", 0.36, 0.84], ["WM,W", 0.07, 0.95], ["ST", 0.5, 0.62]],
    ball: [0.01, 0.995] },
  freeKickEdge: {
    take: [["GK", 0.5, 0.16], ["AM,W", 0.47, 0.76], ["W,AM", 0.53, 0.75], ["ST", 0.4, 0.86], ["ST,CB", 0.6, 0.86], ["CB", 0.56, 0.82],
           ["CM", 0.34, 0.74], ["CB,DM", 0.44, 0.6], ["FB", 0.2, 0.6], ["FB", 0.8, 0.62], ["DM,CM", 0.58, 0.6]],
    face: [["GK", 0.48, 0.985], ["ST,W", 0.42, 0.81], ["AM,CM", 0.46, 0.81], ["CM,W", 0.5, 0.81], ["CM,WM", 0.54, 0.81],
           ["CB", 0.42, 0.88], ["CB", 0.6, 0.88], ["FB", 0.32, 0.88], ["FB", 0.68, 0.87], ["DM", 0.56, 0.84], ["WM,W", 0.22, 0.8]],
    ball: [0.5, 0.75] },
  freeKickWide: {
    take: [["GK", 0.5, 0.18], ["W,WM,AM", 0.86, 0.82], ["CB", 0.48, 0.88], ["CB", 0.58, 0.86], ["ST", 0.42, 0.9], ["ST,W", 0.36, 0.84],
           ["AM,CM", 0.54, 0.78], ["CM", 0.4, 0.72], ["FB", 0.2, 0.62], ["DM,FB", 0.55, 0.6], ["FB,W", 0.76, 0.66]],
    face: [["GK", 0.5, 0.985], ["W,WM", 0.84, 0.86], ["CB", 0.47, 0.91], ["CB", 0.57, 0.89], ["FB", 0.4, 0.92], ["FB", 0.63, 0.9],
           ["DM,CM", 0.5, 0.86], ["CM", 0.44, 0.84], ["AM,CM", 0.58, 0.82], ["WM,W", 0.3, 0.8], ["ST", 0.5, 0.6]],
    ball: [0.86, 0.82] },
  goalKick: {
    take: [["GK", 0.5, 0.03], ["CB", 0.36, 0.09], ["CB", 0.64, 0.09], ["FB", 0.08, 0.2], ["FB", 0.92, 0.2], ["DM", 0.5, 0.24],
           ["CM,AM", 0.32, 0.36], ["CM,AM", 0.68, 0.36], ["W,WM", 0.12, 0.52], ["W,WM", 0.88, 0.52], ["ST", 0.5, 0.56]],
    face: [["GK", 0.5, 0.86], ["ST", 0.42, 0.18], ["ST,AM", 0.58, 0.18], ["WM,W", 0.18, 0.28], ["WM,W", 0.82, 0.28], ["CM", 0.42, 0.34],
           ["CM,DM", 0.58, 0.34], ["CB", 0.4, 0.56], ["CB", 0.6, 0.56], ["FB", 0.2, 0.5], ["FB", 0.8, 0.5]],
    ball: [0.44, 0.04] },
  throwIn: {
    take: [["GK", 0.5, 0.2], ["FB,WM", 0.0, 0.66], ["W,WM", 0.1, 0.74], ["ST", 0.2, 0.8], ["AM,CM", 0.18, 0.62], ["CM", 0.34, 0.66],
           ["DM", 0.36, 0.52], ["CB", 0.38, 0.4], ["CB", 0.62, 0.4], ["FB", 0.74, 0.5], ["W,ST", 0.66, 0.78]],
    face: [["GK", 0.5, 0.97], ["FB", 0.1, 0.7], ["WM,W", 0.12, 0.6], ["CM", 0.24, 0.68], ["CB", 0.3, 0.82], ["CB", 0.48, 0.84],
           ["FB", 0.64, 0.82], ["DM,CM", 0.3, 0.58], ["CM,AM", 0.44, 0.66], ["WM,W", 0.62, 0.66], ["ST", 0.46, 0.5]],
    ball: [0.0, 0.66] },
  penalty: {
    take: [["ST", 0.5, 0.88], ["GK", 0.5, 0.1], ["CB", 0.38, 0.82], ["W", 0.3, 0.83], ["AM,CM", 0.62, 0.82], ["W,WM", 0.7, 0.83],
           ["CM", 0.44, 0.8], ["CB,DM", 0.56, 0.79], ["FB", 0.34, 0.6], ["FB", 0.66, 0.6], ["DM,CM", 0.5, 0.62]],
    face: [["GK", 0.5, 0.995], ["CB", 0.36, 0.83], ["CB", 0.64, 0.83], ["FB", 0.28, 0.82], ["FB", 0.72, 0.82], ["DM,CM", 0.42, 0.79],
           ["CM", 0.58, 0.79], ["AM,CM", 0.47, 0.8], ["WM,W", 0.24, 0.78], ["WM,W", 0.76, 0.78], ["ST", 0.5, 0.6]],
    ball: [0.5, 0.895] },
};

// Fills `spots` ([groups, x, y]) from `slots`: each spot takes the first unused slot whose group is listed (in the
// listed order), else the nearest unused slot. Smaller teams fill the spots in order until they run out.
function fill(slots, spots) {
  const free = [...slots];
  const out = [];
  for (const [groups, x, y] of spots) {
    if (!free.length) break;
    let i = -1;
    for (const g of groups.split(",")) { i = free.findIndex(s => s.group === g); if (i >= 0) break; }
    if (i < 0) i = nearest(free, { x, y });
    out.push({ ...free[i], p: pt(x, y) });
    free.splice(i, 1);
  }
  return out;
}

const dist = (a, b) => Math.hypot((a.x - b.x) * 0.65, a.y - b.y);  // a pitch is about 0.65 as wide as long
// The nearest (the first where level: within 1e-9, so mirror-image players tie the same way in every language).
const nearest = (list, p) => list.reduce((best, s, i) => (dist(s, p) < dist(list[best], p) - 1e-9 ? i : best), 0);

// Who plays each spot of a small-sided game: for each spot, the nearest player (where they stand in `phase`) of the
// first listed group that has one left (`prefs[i]`, e.g. "W,WM"), else the nearest player left. Keepers excluded.
function pick(slots, spots, phase, prefs = []) {
  const placed = inPhase(slots, phase).filter(s => s.group !== "GK");
  return spots.map((p, k) => {
    let pool = placed;
    for (const g of (prefs[k] || "").split(",").filter(Boolean)) {
      const of = placed.filter(s => s.group === g);
      if (of.length) { pool = of; break; }
    }
    const chosen = pool[nearest(pool.map(s => s.p), p)];
    placed.splice(placed.indexOf(chosen), 1);
    return { ...chosen, p };
  });
}

// Attackers around the ball, defenders goal-side of them, in the attackers' frame (attacking up).
function smallSided(sc) {
  const [bx, by] = sc.at;
  const inward = bx < 0.4 ? 1 : bx > 0.6 ? -1 : 1;
  const attack = [pt(bx, by), ...sc.support.map(([dx, dy]) => pt(bx + dx * inward, by + dy))];
  const goal = { x: 0.5, y: 1 };
  const defend = [];
  const step = (from, toward, d) => {
    const vx = (toward.x - from.x) * 0.65, vy = toward.y - from.y, len = Math.hypot(vx, vy) || 1;
    return pt(from.x + (vx / len) * d / 0.65, from.y + (vy / len) * d);
  };
  for (let i = 0; i < sc.m; i++) {
    if (sc.surround && i > 0) {
      const side = i % 2 ? -1 : 1;
      defend.push(pt(bx + side * 0.09, by - 0.02 + 0.04 * Math.floor((i - 1) / 2)));
    } else if (i < attack.length) {
      defend.push(step(attack[i], goal, i === 0 ? 0.05 : 0.06));
    } else {
      // Spare defenders cover the space behind, between the ball and goal.
      const k = i - attack.length, side = k % 2 ? -1 : 1;
      defend.push(pt(0.5 + side * 0.1 * (1 + Math.floor(k / 2)) * 0.6 + (bx - 0.5) * 0.4, Math.min(0.9, by + 0.14)));
    }
  }
  return { attack, defend, ball: attack[0], keeper: sc.keeper };
}

// Kick-off: each side in its own half, its shape squeezed into it; we kick off when attacking.
function kickOff(slots) {
  return slots.map(s => ({ ...s, p: s.group === "GK" ? pt(0.5, 0.05) : pt(0.5 + (s.x - 0.5) * 0.95, Math.min(0.47, 0.04 + s.y * 0.62)) }));
}

// ---------------------------------------------------------------------------------------------------------------
// Build: the board for scenario `id` with our formation `formationId`, attacking or not. Returns home and away
// players (number, role, position) and the ball, in board coordinates (we attack up).

function buildScenario(id, formationId, attacking) {
  const sc = SCENARIOS.find(s => s.id === id);
  const ours = formation(formationId);
  const size = ours.pitch;
  const theirs = formation(OPPONENT[size]);
  const home = slotsOf(ours), away = slotsOf(theirs);
  const on = attacking ? home : away, off = attacking ? away : home;
  // Everything is worked out in the frame of the side on the ball; their frame is ours turned round.
  const toBoard = p => (attacking ? p : mirror(p));
  const toBoardOff = p => (attacking ? mirror(p) : p);
  let onPlaced, offPlaced, ball;

  if (sc.team) {
    const t = sc.team;
    onPlaced = inPhase(on, t.on, { shiftX: t.onShift || 0 });
    const c = carrier(onPlaced, t.ball);
    ball = c.p;
    // The other side's frame: the ball, seen from their end.
    const ballThere = mirror(ball);
    offPlaced = inPhase(off, t.off, { focus: t.press ? ballThere : null, pull: t.press ? 0.3 : 0 });
    // They slide toward the ball's side (their right, our left).
    if (t.offShift) offPlaced = offPlaced.map(s => (s.group === "GK" ? s : { ...s, p: pt(s.p.x + t.offShift, s.p.y) }));
  } else if (sc.n !== undefined) {
    const g = smallSided(sc);
    const onPhase = "finalThird", offPhase = "lowBlock";
    onPlaced = pick(on, g.attack, onPhase, sc.who);
    // Defenders stand in the other side's frame: our attack frame turned round.
    offPlaced = pick(off, g.defend.map(mirror), offPhase, sc.vs);
    if (g.keeper) {
      const gk = off.find(s => s.group === "GK");
      if (gk) offPlaced.push({ ...gk, p: pt(0.5, 0.03) });
    }
    ball = g.ball;
  } else if (sc.set) {
    const set = SET_PIECES[sc.set];
    onPlaced = fill(on, set.take);
    offPlaced = fill(off, set.face.map(([g, x, y]) => [g, 1 - x, 1 - y]));
    ball = pt(set.ball[0], set.ball[1]);
    // A ball on the line or at the flag stays there (clamp keeps it on the pitch).
  } else if (sc.kickOff) {
    onPlaced = kickOff(on);
    offPlaced = kickOff(off);
    const taker = onPlaced.filter(s => ["ST", "AM", "CM"].includes(s.group)).sort((a, b) => b.p.y - a.p.y)[0];
    if (taker) taker.p = pt(0.5, 0.49);
    ball = pt(0.5, 0.5);
  }

  const homeSide = attacking ? onPlaced.map(s => ({ ...s, p: toBoard(s.p) })) : offPlaced.map(s => ({ ...s, p: toBoardOff(s.p) }));
  const awaySide = attacking ? offPlaced.map(s => ({ ...s, p: toBoardOff(s.p) })) : onPlaced.map(s => ({ ...s, p: toBoard(s.p) }));
  return {
    id, formation: formationId, attacking,
    home: homeSide.map(s => ({ number: s.number, role: s.role, x: s.p.x, y: s.p.y })),
    away: awaySide.map(s => ({ number: s.number, role: s.role, x: s.p.x, y: s.p.y })),
    ball: toBoard(ball),
  };
}

const scenariosFor = size => SCENARIOS.filter(s => s.sizes.includes(size) && (s.n === undefined || (s.n <= sizeCount(size) - 1 && s.m <= sizeCount(size) - 1)));
const sizeCount = size => ({ full: 11, sevenASide: 7, fiveASide: 5 }[size]);
