// Reads the scenario mockup (mockup/scenario-data.js, scenarios.js, scenario-motion.js and the tile picture
// `pitchSVG` from scenarios-screens.js) and prints what the design system's Scenarios section shows, as JSON, so the
// page never retypes a name, a position or a note. Run by build.py: node scenario_export.js <repo root>
const fs = require("fs"), vm = require("vm"), path = require("path");
const root = process.argv[2];
const read = f => fs.readFileSync(path.join(root, "mockup", f), "utf8");

// scenarios-screens.js draws the mockup's frames when it loads; only its picture function is taken.
const screens = read("scenarios-screens.js");
const from = screens.indexOf("// A pitch with the scenario on it."), to = screens.indexOf("function miniShape(");
if (from < 0 || to < from) throw new Error("pitchSVG not found in mockup/scenarios-screens.js");

const ctx = {};
vm.createContext(ctx);
vm.runInContext([read("scenario-data.js"), read("scenarios.js"), read("scenario-motion.js"), screens.slice(from, to),
  "this.api = { FORMATIONS, SCENARIOS, MOTIONS, buildScenario, buildMotion, scenariosFor, sizeCount, formation, pitchSVG };"].join("\n;\n"), ctx);
const { SCENARIOS, MOTIONS, buildScenario, buildMotion, scenariosFor, formation, pitchSVG } = ctx.api;

// The side help line, as the sheet words it.
const help = screens.match(/attacking \? "([^"]+)" : "([^"]+)"/);
if (!help) throw new Error("side help line not found in mockup/scenarios-screens.js");

const SHAPE = "4-3-3", TILE_W = 146, EXAMPLE = "final-third", FRAMED = "2v2-box";
const sizes = ["full", "sevenASide", "fiveASide"];
const offered = Object.fromEntries(sizes.map(s => [s, scenariosFor(s).map(x => x.id)]));
const kind = formation(SHAPE).pitch;
// Two decimals are plenty for a picture 146 pt wide; the page carries a few dozen of them.
const slim = svg => svg.replace(/\s*\n\s*/g, "").replace(/-?\d+\.\d{3,}/g, m => (+m).toFixed(2).replace(/\.?0+$/, ""));
const picture = (id, attacking, opts = {}) => {
  const sc = SCENARIOS.find(s => s.id === id);
  return slim(pitchSVG(kind, buildScenario(id, SHAPE, attacking), TILE_W, { fit: !sc.team, ...opts }));
};

const catalogue = SCENARIOS.map(sc => {
  const att = buildMotion(sc.id, SHAPE, true), def = buildMotion(sc.id, SHAPE, false);
  const board = buildScenario(sc.id, SHAPE, true);
  return {
    id: sc.id, group: sc.group, name: sc.name, line: sc.line,
    sizes: sizes.filter(s => offered[s].includes(sc.id)),
    kind: sc.team ? "team" : sc.n !== undefined ? "small" : sc.set ? "set" : "kickOff",
    n: sc.n ?? null, m: sc.m ?? null, keeper: !!sc.keeper, players: board.home.length + board.away.length,
    steps: att ? att.length : null, end: att ? att.at(-1).note : null, endDefending: def ? def.at(-1).note : null,
    hasMotion: !!MOTIONS[sc.id],
  };
});

const lengths = catalogue.filter(c => c.steps).map(c => c.steps);
console.log(JSON.stringify({
  help: { attacking: help[1], defending: help[2] },
  shape: SHAPE, tileWidth: TILE_W, offered, catalogue,
  stepRange: [Math.min(...lengths), Math.max(...lengths)],
  tiles: Object.fromEntries(offered[kind].map(id => [id, picture(id, true)])),
  defending: { [EXAMPLE]: picture(EXAMPLE, false) },
  framing: { id: FRAMED, whole: picture(FRAMED, true, { fit: false }), framed: picture(FRAMED, true) },
  example: { id: EXAMPLE, attacking: buildMotion(EXAMPLE, SHAPE, true), defending: buildMotion(EXAMPLE, SHAPE, false) },
}));
