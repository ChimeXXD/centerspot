// Scenario motion (D-96, D-97): every scenario becomes a move of 3 to 5 steps. Attacking ends in a goal (3v1: the
// ball kept); Defending ends with our side winning the ball. Played out
// from the board `buildScenario` sets up. Load after scenario-data.js and scenarios.js.
//
// How it works, so it fits every shape:
// - The side on the ball follows a short script of beats. A beat is what happens between two steps: passes, runs,
//   dribbles, a shot. Players are named by role (the cast: "CB:left" is the left-most centre-back, with fallbacks),
//   never by shirt number, so a 3-5-2 plays it with its wing-back where a 4-3-3 uses its full-back.
// - The other side reacts by rule after every beat: the nearest player presses the ball, one tracks each runner, the
//   keeper sets himself on the ball's side, and the rest slide across and up with the ball (at a set piece they
//   mostly hold their zones).
// - Everything is worked out in the attackers' frame (attacking up), then turned to the board: when we defend, the
//   opponent attacks down and our players are the ones reacting.
// - Each step's note says what happens next, in shirt numbers ("1 plays it short to 5"); "Their" when it's them.

const MOTION_GOAL = { x: 0.5, y: 1 };

// A cast entry: [groups in order, side ("left" | "right" | "centre"), fallback point when no group matches].
// Acts: ["run" | "dribble", who, to], ["pass", from, to-who], ["shot", who, goal x], ["beat", defender, to] (left
// behind for good), ["beatPresser"] (the defender nearest the ball is left behind). Small-sided aliases are fixed: A0 (on the ball), A1, A2… in the attackers' order, D0, D1… the defenders, K their keeper.
// Set pieces: S0, S1… are the taking side's spots in SET_PIECES order.
const MOTIONS = {
  // Team shape
  "build-up": {
    cast: { GK: ["GK", "centre", [0.5, 0.05]], CBL: ["CB", "left", [0.3, 0.14]], DM: ["DM,CM", "centre", [0.5, 0.28]],
            WL: ["W,WM,AM", "left", [0.16, 0.55]] },
    beats: [
      { note: "{GK} plays it short to {CBL}", acts: [["run", "CBL", { dx: -0.04, dy: -0.02 }], ["pass", "GK", "CBL"]] },
      { note: "{CBL} finds {DM}, dropping in to take it", acts: [["run", "DM", [0.4, 0.3]], ["pass", "CBL", "DM"]] },
      { note: "{DM} plays it over the press to {WL} running in behind",
        acts: [["run", "WL", [0.3, 0.84]], ["pass", "DM", "WL"]] },
      { note: "{WL} finishes", acts: [["shot", "WL", 0.44]] },
    ],
    end: "Goal",
  },
  midfield: {
    cast: { CAR: ["@ball"], AM: ["AM,CM,ST", "centre", [0.5, 0.6]], WR: ["W,WM,FB", "right", [0.85, 0.62]],
            ST: ["ST,AM,W", "centre", [0.5, 0.78]] },
    beats: [
      { note: "{CAR} plays it into {AM} between the lines", acts: [["run", "AM", [0.46, 0.6]], ["pass", "CAR", "AM"]] },
      { note: "{AM} turns and finds {WR}", acts: [["run", "WR", [0.82, 0.76]], ["pass", "AM", "WR"]] },
      { note: "{WR} crosses; {ST} attacks the far post", acts: [["run", "ST", [0.44, 0.9]], ["pass", "WR", "ST"]] },
      { note: "{ST} finishes", acts: [["shot", "ST", 0.46]] },
    ],
    end: "Goal",
  },
  "final-third": {
    cast: { CAR: ["@ball"], OVL: ["FB,WM,CB", "left", [0.1, 0.6]], AM: ["AM,CM,ST", "centre", [0.45, 0.7]],
            ST: ["ST,AM,W", "centre", [0.5, 0.82]] },
    beats: [
      { note: "{CAR} plays inside to {AM}; {OVL} overlaps",
        acts: [["run", "AM", [0.4, 0.76]], ["pass", "CAR", "AM"], ["run", "OVL", [0.07, 0.82]]] },
      { note: "{AM} slips {OVL} in behind the block", acts: [["run", "OVL", [0.09, 0.91]], ["pass", "AM", "OVL"]] },
      { note: "{OVL} cuts it back; {ST} attacks the near post", acts: [["run", "ST", [0.45, 0.9]], ["pass", "OVL", "ST"]] },
      { note: "{ST} finishes", acts: [["shot", "ST", 0.47]] },
    ],
    end: "Goal",
  },
  switch: {
    cast: { CAR: ["@ball"], CM: ["CM,DM,AM", "centre", [0.42, 0.62]], WR: ["W,WM,FB", "right", [0.9, 0.7]],
            ST: ["ST,AM", "centre", [0.48, 0.8]] },
    beats: [
      { note: "{CAR} plays it back inside to {CM}", acts: [["pass", "CAR", "CM"]] },
      { note: "{CM} switches it to {WR}, free on the far side", acts: [["run", "WR", [0.88, 0.76]], ["pass", "CM", "WR"]] },
      { note: "{WR} cuts it back to {ST}", acts: [["run", "ST", [0.54, 0.88]], ["pass", "WR", "ST"]] },
      { note: "{ST} finishes", acts: [["shot", "ST", 0.55]] },
    ],
    end: "Goal",
  },
  counter: {
    cast: { CAR: ["@ball"], WR: ["W,WM,FB", "right", [0.85, 0.6]], ST: ["ST,AM", "centre", [0.5, 0.7]],
            WL: ["W,WM,FB", "left", [0.15, 0.6]] },
    beats: [
      { note: "{CAR} plays it long to {WR}; {ST} and {WL} sprint",
        acts: [["run", "WR", [0.84, 0.66]], ["pass", "CAR", "WR"], ["run", "ST", [0.52, 0.72]], ["run", "WL", [0.2, 0.7]]] },
      { note: "{WR} drives at the box", acts: [["dribble", "WR", [0.74, 0.84]], ["run", "ST", [0.5, 0.88]], ["run", "WL", [0.34, 0.9]]] },
      { note: "{WR} squares it to {WL}", acts: [["pass", "WR", "WL"]] },
      { note: "{WL} finishes", acts: [["shot", "WL", 0.44]] },
    ],
    end: "Goal",
  },
  "counter-press": {
    cast: { CAR: ["@ball"], OUT: ["CM,AM,W,WM", "right", [0.66, 0.6]], ST: ["ST,AM", "centre", [0.5, 0.78]],
            WL: ["W,WM,AM,CM", "left", [0.3, 0.75]] },
    beats: [
      { note: "{CAR} beats the first presser with a pass to {OUT}", acts: [["run", "OUT", [0.66, 0.62]], ["pass", "CAR", "OUT"]] },
      { note: "{OUT} plays it first time into {ST}", acts: [["run", "ST", [0.52, 0.76]], ["pass", "OUT", "ST"]] },
      { note: "{ST} lays it off to {WL}, arriving in the box", acts: [["run", "WL", [0.36, 0.87]], ["pass", "ST", "WL"]] },
      { note: "{WL} finishes", acts: [["shot", "WL", 0.45]] },
    ],
    end: "Goal",
  },

  // Small-sided
  "1v1-wing": {
    beats: [
      { note: "{A0} shows {D0} inside", acts: [["dribble", "A0", [0.22, 0.79]]] },
      { note: "{A0} cuts back outside and goes past", acts: [["dribble", "A0", [0.12, 0.9]], ["beat", "D0", [0.2, 0.84]]] },
      { note: "{A0} comes inside into the box", acts: [["dribble", "A0", [0.3, 0.91]], ["beat", "D0", [0.18, 0.88]]] },
      { note: "{A0} shoots across {K}", acts: [["shot", "A0", 0.56]] },
    ],
    end: "Goal",
  },
  "1v1-keeper": {
    beats: [
      { note: "{A0} runs at {K}", acts: [["dribble", "A0", [0.5, 0.86]]] },
      { note: "{A0} goes round {K}", acts: [["dribble", "A0", [0.4, 0.93]], ["beat", "K", [0.5, 0.92]]] },
      { note: "{A0} rolls it into the empty net", acts: [["shot", "A0", 0.46]] },
    ],
    end: "Goal",
  },
  "2v1-overlap": {
    beats: [
      { note: "{A0} drives inside; {A1} overlaps", acts: [["dribble", "A0", [0.26, 0.7]], ["run", "A1", [0.08, 0.74]]] },
      { note: "{A0} slips {A1} in", acts: [["run", "A1", [0.09, 0.84]], ["pass", "A0", "A1"]] },
      { note: "{A1} crosses; {A0} attacks the box", acts: [["run", "A0", [0.45, 0.89]], ["pass", "A1", "A0"]] },
      { note: "{A0} finishes past {K}", acts: [["shot", "A0", 0.54]] },
    ],
    end: "Goal",
  },
  "2v1-one-two": {
    beats: [
      { note: "{A0} plays it into {A1} and runs", acts: [["pass", "A0", "A1"], ["run", "A0", [0.5, 0.8]], ["beat", "D0", [0.52, 0.72]]] },
      { note: "{A1} returns it into {A0}'s run", acts: [["pass", "A1", "A0"]] },
      { note: "{A0} finishes past {K}", acts: [["shot", "A0", 0.44]] },
    ],
    end: "Goal",
  },
  "2v2-box": {
    beats: [
      { note: "{A0} drops; {A1} spins in behind", acts: [["dribble", "A0", [0.38, 0.77]], ["run", "A1", [0.52, 0.9]]] },
      { note: "{A0} slides {A1} through", acts: [["pass", "A0", "A1"]] },
      { note: "{A1} finishes past {K}", acts: [["shot", "A1", 0.56]] },
    ],
    end: "Goal",
  },
  "3v1-rondo": {
    beats: [
      { note: "{A0} plays it to {A1}", acts: [["pass", "A0", "A1"]] },
      { note: "{A1} finds {A2} across the presser", acts: [["pass", "A1", "A2"]] },
      { note: "{A2} carries it forward into space", acts: [["dribble", "A2", [0.4, 0.7]], ["beat", "D0", [0.52, 0.6]]] },
    ],
    end: "Kept it, into space",
  },
  "3v2-counter": {
    beats: [
      { note: "{A0} drives at the two; {A1} and {A2} spread",
        acts: [["dribble", "A0", [0.5, 0.72]], ["run", "A1", [0.72, 0.78]], ["run", "A2", [0.3, 0.8]]] },
      { note: "{A0} slips {A1} in", acts: [["pass", "A0", "A1"]] },
      { note: "{A1} squares it to {A2}", acts: [["run", "A2", [0.42, 0.9]], ["pass", "A1", "A2"]] },
      { note: "{A2} finishes", acts: [["shot", "A2", 0.45]] },
    ],
    end: "Goal",
  },
  "3v3-midfield": {
    beats: [
      { note: "{A0} finds {A1}", acts: [["pass", "A0", "A1"]] },
      { note: "{A1} switches it to {A2}, running beyond", acts: [["run", "A2", [0.32, 0.72]], ["pass", "A1", "A2"]] },
      { note: "{A2} carries it into the box", acts: [["dribble", "A2", [0.38, 0.87]], ["beatPresser"]] },
      { note: "{A2} finishes past {K}", acts: [["shot", "A2", 0.53]] },
    ],
    end: "Goal",
  },
  "3v4-build-up": {
    beats: [
      { note: "{A0} plays it wide to {A1}", acts: [["pass", "A0", "A1"]] },
      { note: "{A1} plays it long to {A2}, breaking", acts: [["run", "A2", [0.3, 0.6]], ["pass", "A1", "A2"]] },
      { note: "{A2} runs it all the way into the box", acts: [["dribble", "A2", [0.4, 0.86]], ["beatPresser"]] },
      { note: "{A2} finishes past {K}", acts: [["shot", "A2", 0.54]] },
    ],
    end: "Goal",
  },
  "4v3-overload": {
    beats: [
      { note: "{A0} plays inside to {A2}; {A1} overlaps", acts: [["pass", "A0", "A2"], ["run", "A1", [0.08, 0.74]]] },
      { note: "{A2} finds {A1} on the overlap", acts: [["run", "A1", [0.09, 0.84]], ["pass", "A2", "A1"]] },
      { note: "{A1} crosses for {A3}", acts: [["run", "A3", [0.46, 0.9]], ["pass", "A1", "A3"]] },
      { note: "{A3} finishes", acts: [["shot", "A3", 0.5]] },
    ],
    end: "Goal",
  },
  "1v3-surrounded": {
    beats: [
      { note: "{A0} shields it from the three", acts: [["dribble", "A0", [0.47, 0.6]]] },
      { note: "{A0} spins out of the trap", acts: [["dribble", "A0", [0.57, 0.7]], ["beat", "D0", [0.5, 0.64]]] },
      { note: "{A0} drives at goal", acts: [["dribble", "A0", [0.53, 0.85]], ["beatPresser"]] },
      { note: "{A0} finishes past {K}", acts: [["shot", "A0", 0.44]] },
    ],
    end: "Goal",
  },

  // Set pieces: S0, S1… are the taking side's spots in SET_PIECES order; K is the other side's keeper.
  corner: {
    beats: [
      { note: "{S5} whips it to the near post; {S3} attacks it",
        acts: [["run", "S3", [0.44, 0.95]], ["run", "S2", [0.5, 0.93]], ["pass", "S5", "S3"]] },
      { note: "{S3} flicks it on to {S1} at the far post", acts: [["run", "S1", [0.58, 0.95]], ["pass", "S3", "S1"]] },
      { note: "{S1} heads it in", acts: [["shot", "S1", 0.52]] },
    ],
    end: "Goal",
  },
  "free-kick-edge": {
    beats: [
      { note: "{S2} runs over it", acts: [["run", "S2", [0.6, 0.8]]] },
      { note: "{S1} curls it over the wall", acts: [["shot", "S1", 0.42], ["beat", "K", [0.55, 0.985]]] },
    ],
    end: "Goal",
  },
  "free-kick-wide": {
    beats: [
      { note: "{S1} whips it in; {S2} attacks it", acts: [["run", "S2", [0.5, 0.92]], ["pass", "S1", "S2"]] },
      { note: "{S2} heads it in", acts: [["shot", "S2", 0.44]] },
    ],
    end: "Goal",
  },
  "goal-kick": {
    beats: [
      { note: "{S0} plays it short to {S1}", acts: [["pass", "S0", "S1"]] },
      { note: "{S1} finds {S5}, dropping in", acts: [["run", "S5", [0.42, 0.28]], ["pass", "S1", "S5"]] },
      { note: "{S5} plays it long to {S10} running in behind", acts: [["run", "S10", [0.52, 0.82]], ["pass", "S5", "S10"]] },
      { note: "{S10} finishes", acts: [["shot", "S10", 0.45]] },
    ],
    end: "Goal",
  },
  "throw-in": {
    beats: [
      { note: "{S1} throws it to {S2}", acts: [["pass", "S1", "S2"]] },
      { note: "{S2} turns and crosses for {S3}", acts: [["run", "S3", [0.46, 0.9]], ["pass", "S2", "S3"]] },
      { note: "{S3} finishes", acts: [["shot", "S3", 0.53]] },
    ],
    end: "Goal",
  },
  penalty: {
    winner: "K",  // nobody else may be in the box: on Defending the keeper saves it
    beats: [
      { note: "{S0} steps up", acts: [["run", "S0", [0.5, 0.875]]] },
      { note: "{S0} sends {K} the wrong way", acts: [["beat", "K", [0.6, 0.985]], ["shot", "S0", 0.42]] },
    ],
    end: "Goal",
  },
  "kick-off": {
    cast: { CAR: ["@ball"], CM: ["CM,DM,AM", "centre", [0.5, 0.4]], WR: ["W,WM,FB", "right", [0.85, 0.45]],
            ST: ["ST,AM,W", "centre", [0.45, 0.5]] },
    beats: [
      { note: "{CAR} rolls it back to {CM}", acts: [["pass", "CAR", "CM"]] },
      { note: "{CM} plays it long to {WR} down the line", acts: [["run", "WR", [0.86, 0.72]], ["pass", "CM", "WR"]] },
      { note: "{WR} crosses for {ST}", acts: [["run", "ST", [0.48, 0.9]], ["pass", "WR", "ST"]] },
      { note: "{ST} finishes", acts: [["shot", "ST", 0.53]] },
    ],
    end: "Goal",
  },
};

const motionRound = v => Math.round(v * 1000) / 1000;
const onPitch = (x, y) => ({ x: motionRound(Math.min(0.98, Math.max(0.02, x))), y: motionRound(Math.min(0.98, Math.max(0.02, y))) });
const toward = (from, to, d) => {
  const vx = (to.x - from.x) * 0.65, vy = to.y - from.y, len = Math.hypot(vx, vy) || 1;
  return onPitch(from.x + (vx / len) * d / 0.65, from.y + (vy / len) * d);
};
const gap = (a, b) => Math.hypot((a.x - b.x) * 0.65, a.y - b.y);

// The move for scenario `id` with our shape `formationId`: one entry per step, the first the set-up, each with
// where everyone stands, the arrows shown on it and its note. Null when the scenario has no motion yet.
function buildMotion(id, formationId, attacking) {
  const script = MOTIONS[id];
  if (!script) return null;
  const sc = SCENARIOS.find(s => s.id === id);
  const board = buildScenario(id, formationId, attacking);
  // To the attackers' frame: when we defend, they attack down the board, so turn everything round.
  const frame = p => (attacking ? { x: p.x, y: p.y } : { x: motionRound(1 - p.x), y: motionRound(1 - p.y) });
  const unframe = frame;  // turning round twice is the identity
  const mk = (list, side) => list.map(p => ({ number: p.number, role: p.role, group: GROUP[p.role] || "CM", side, p: frame(p) }));
  const att = mk(attacking ? board.home : board.away, attacking ? "home" : "away");
  const def = mk(attacking ? board.away : board.home, attacking ? "away" : "home");
  let ball = frame(board.ball);

  // The cast: aliases to players.
  const cast = {};
  const taken = new Set();
  const carrierNow = () => att.reduce((best, s) => (gap(s.p, ball) < gap(best.p, ball) ? s : best), att[0]);
  if (sc.n !== undefined) {
    att.forEach((s, i) => { cast[`A${i}`] = s; });
    def.filter(s => s.group !== "GK").forEach((s, i) => { cast[`D${i}`] = s; });
    const k = def.find(s => s.group === "GK");
    if (k) cast.K = k;
  } else if (sc.set) {
    att.forEach((s, i) => { cast[`S${i}`] = s; });
    const k = def.find(s => s.group === "GK");
    if (k) cast.K = k;
  } else {
    for (const [alias, entry] of Object.entries(script.cast || {})) {
      if (entry[0] === "@ball") { cast[alias] = carrierNow(); taken.add(cast[alias]); continue; }
    }
    for (const [alias, [groups, side, fallback]] of Object.entries(script.cast || {})) {
      if (groups === "@ball") continue;
      const free = att.filter(s => !taken.has(s));
      let pick = null;
      for (const g of groups.split(",")) {
        const of = free.filter(s => s.group === g);
        if (!of.length) continue;
        pick = of.reduce((best, s) => {
          const key = side === "left" ? s.p.x : side === "right" ? -s.p.x : Math.abs(s.p.x - 0.5);
          const bestKey = side === "left" ? best.p.x : side === "right" ? -best.p.x : Math.abs(best.p.x - 0.5);
          return key < bestKey - 1e-9 ? s : best;
        });
        break;
      }
      if (!pick) {
        const outfield = free.filter(s => s.group !== "GK");
        const target = { x: fallback[0], y: fallback[1] };
        pick = outfield.reduce((best, s) => (gap(s.p, target) < gap(best.p, target) - 1e-9 ? s : best), outfield[0]);
      }
      cast[alias] = pick;
      taken.add(pick);
    }
  }
  const name = alias => (cast[alias] ? String(cast[alias].number) : alias);
  const say = text => {
    const filled = text.replace(/\{(\w+)\}/g, (_, a) => name(a));
    return attacking ? filled : `Their ${filled}`;
  };

  const snapshot = () => ({
    home: (attacking ? att : def).map(s => ({ number: s.number, ...unframe(s.p) })),
    away: (attacking ? def : att).map(s => ({ number: s.number, ...unframe(s.p) })),
    ball: unframe(ball),
  });

  const steps = [];
  // A defender beaten once stays beaten: they chase from behind the ball, never back goal-side of it.
  const outOfIt = new Set();
  let carrier = sc.team ? cast.CAR || carrierNow() : carrierNow();
  // On Defending (D-97) the opponent runs the move but nobody on our side is beaten, and their last action (the shot)
  // never comes: our nearest player steps in and wins the ball instead (the keeper at a penalty or a 1v1 with him).
  const beats = attacking ? script.beats : script.beats.slice(0, -1);
  for (const beat of beats) {
    const before = snapshot();
    const arrows = [];
    const start = new Map([...att, ...def].map(s => [s, { ...s.p }]));
    const ballStart = { ...ball };
    const runners = [];
    let shot = null;
    const beaten = new Set();
    let through = false;  // a carry past the presser: nobody else steps in this beat
    for (const [kind, alias, target] of beat.acts) {
      if (!attacking && (kind === "beat" || kind === "beatPresser")) continue;
      if (kind === "beatPresser") {
        // The defender nearest the ball as the beat starts is left where they were: the carrier goes past them.
        const near = def.filter(s => s.group !== "GK" && !outOfIt.has(s));
        if (near.length) beaten.add(near.reduce((best, s) => (gap(s.p, ballStart) < gap(best.p, ballStart) - 1e-9 ? s : best)));
        through = true;
        continue;
      }
      const who = cast[alias];
      if (!who) continue;
      const to = Array.isArray(target) ? onPitch(target[0], target[1])
        : target && typeof target === "object" ? onPitch(who.p.x + (target.dx || 0), who.p.y + (target.dy || 0)) : null;
      if (kind === "run") {
        arrows.push({ kind: "run", points: [start.get(who), to] });
        who.p = to;
        runners.push(who);
      } else if (kind === "dribble") {
        arrows.push({ kind: "dribble", points: [start.get(who), to] });
        who.p = to;
        ball = { ...to };
        carrier = who;
      } else if (kind === "pass") {
        const receiver = cast[target];
        if (!receiver) continue;
        arrows.push({ kind: "pass", points: [{ ...ball }, receiver.p] });
        ball = { ...receiver.p };
        carrier = receiver;
      } else if (kind === "shot") {
        const goal = { x: target, y: 1 };
        arrows.push({ kind: "pass", points: [ball, goal] });
        ball = { x: target, y: 1 };
        shot = goal;
      } else if (kind === "beat") {
        who.p = to;
        beaten.add(who);
      }
    }

    // The other side reacts: keeper, presser, trackers, then the rest slide with the ball.
    for (const s of beaten) outOfIt.add(s);
    const moved = new Set(beaten);
    for (const s of outOfIt) {
      if (beaten.has(s)) continue;
      const target = shot ? ballStart : ball;
      s.p = onPitch(s.p.x + (target.x - s.p.x) * 0.35, Math.min(s.p.y + (target.y - s.p.y) * 0.35, target.y - 0.03));
      moved.add(s);
    }
    const keeper = def.find(s => s.group === "GK");
    const ballThen = shot ? ballStart : ball;
    if (keeper && !moved.has(keeper)) {
      const aim = shot ? shot.x : 0.5 + (ballThen.x - 0.5) * 0.35;
      keeper.p = onPitch(keeper.p.x + (aim - keeper.p.x) * (shot ? 0.8 : 1), Math.max(keeper.p.y, 0.95));
      moved.add(keeper);
    }
    const field = def.filter(s => s.group !== "GK" && !moved.has(s));
    if (!shot && !through && field.length) {
      const presser = field.reduce((best, s) => (gap(s.p, ballThen) < gap(best.p, ballThen) ? s : best));
      presser.p = toward(ballThen, MOTION_GOAL, 0.045);
      moved.add(presser);
      for (const runner of runners.filter(r => r !== carrier)) {
        const free = def.filter(s => s.group !== "GK" && !moved.has(s));
        if (!free.length) break;
        const marker = free.reduce((best, s) => (gap(s.p, runner.p) < gap(best.p, runner.p) ? s : best));
        marker.p = toward(runner.p, MOTION_GOAL, 0.05);
        moved.add(marker);
      }
    }
    // How far the rest slide with the ball: a team shape shifts as a unit; at a set piece they hold their zones.
    const slide = sc.set ? { x: 0.1, y: 0.1 } : { x: 0.45, y: 0.5 };
    const dx = ballThen.x - ballStart.x, dy = ballThen.y - ballStart.y;
    for (const s of def) {
      if (moved.has(s) || s.group === "GK") continue;
      s.p = onPitch(s.p.x + dx * slide.x, s.p.y + dy * slide.y);
    }
    for (const s of att) {
      if (start.get(s).x !== s.p.x || start.get(s).y !== s.p.y || s === carrier || s.group === "GK") continue;
      s.p = onPitch(s.p.x, s.p.y + Math.max(dy, 0) * 0.35);
    }

    const duration = shot ? 0.8 : beat.acts.some(a => a[0] === "pass") ? 1.0 : 1.2;
    steps.push({ ...before, arrows: arrows.map(a => ({ kind: a.kind, points: a.points.map(unframe) })), note: say(beat.note), duration });
  }
  if (!attacking) {
    const before = snapshot();
    const keeper = def.find(s => s.group === "GK");
    const field = def.filter(s => s.group !== "GK");
    const winner = script.winner === "K" || !field.length ? keeper
      : field.reduce((best, s) => (gap(s.p, ball) < gap(best.p, ball) - 1e-9 ? s : best));
    if (winner) {  // no keeper to take it (a penalty with nobody in goal): no win step, as ScenarioMotion.swift
      // A keeper saves the shot on his line; an outfield player steps in goal-side and takes the ball onto his feet.
      const shotAct = script.beats[script.beats.length - 1].acts.find(a => a[0] === "shot");
      let arrows;
      if (winner.group === "GK" && shotAct) {
        const save = onPitch(shotAct[2], winner.p.y);
        arrows = [{ kind: "pass", points: [{ ...ball }, save] }];
        winner.p = save;
      } else {
        arrows = [{ kind: "press", points: [{ ...winner.p }, { ...ball }] }];
        winner.p = toward(ball, MOTION_GOAL, 0.03);
      }
      ball = { ...winner.p };
      const note = `${winner.number} ${winner.group === "GK" ? "saves it" : "wins the ball"}`;
      steps.push({ ...before, arrows: arrows.map(a => ({ kind: a.kind, points: a.points.map(unframe) })), note, duration: 1.0 });
    }
  }
  steps.push({ ...snapshot(), arrows: [], note: attacking ? script.end : "Ball won", duration: 1.2 });
  return steps;
}
