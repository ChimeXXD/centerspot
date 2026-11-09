# The `.tactic` format, v1

A `.tactic` file is UTF-8 JSON. UTType `dev.chime.centerspot.tactic`, extension `.tactic`, conforms to `public.json` (D-09). It is the app's document format, the payload of a link or QR code (D-10), and a public spec that other tools may read and write.

## Shape

```json
{
  "schemaVersion": 1,
  "id": "6F1C2A40-9D7E-4C1B-8E52-0B0D7A1F3C11",
  "title": "Overlap down the left",
  "pitch": { "kind": "full", "style": "stripes" },
  "sides": [
    { "id": "home", "name": "Us", "colour": "lime" },
    { "id": "away", "name": "Them", "colour": "coral" }
  ],
  "tokens": [
    { "id": "h3", "kind": "player", "side": "home", "number": 3, "name": "Ade", "roleID": "full-back" },
    { "id": "ball", "kind": "ball" }
  ],
  "phases": [
    {
      "id": "main",
      "name": "Main",
      "steps": [
        {
          "id": "s1",
          "duration": 1.2,
          "positions": { "h3": { "x": 0.15, "y": 0.24 }, "ball": { "x": 0.5, "y": 0.5 } },
          "runs": { "h3": { "points": [ { "x": 0.15, "y": 0.24 }, { "x": 0.08, "y": 0.45 }, { "x": 0.1, "y": 0.66 } ] } },
          "arrows": [ { "kind": "pass", "points": [ { "x": 0.38, "y": 0.46 }, { "x": 0.1, "y": 0.66 } ] } ],
          "marks": {
            "zones": [ { "id": "z1", "x": 0.02, "y": 0.52, "w": 0.2, "h": 0.34, "colour": "lime" } ],
            "lines": [ { "id": "l1", "tokens": ["a2", "a5", "a4"] } ],
            "glows": [ { "id": "g1", "token": "h3" }, { "id": "g2", "x": 0.5, "y": 0.87, "r": 0.11 } ]
          },
          "note": "3 overlaps as 11 cuts inside"
        }
      ]
    }
  ],
  "app": { "createdWith": "CenterSpot 0.1.0" }
}
```

## Rules

Two outcomes (D-27): **refuse** means the whole file is rejected with a plain error ("This file isn't a tactic we can open.", or the newer-version message); **repair** means the value is fixed silently and the file opens. Structure and safety problems refuse; cosmetic values repair.

| Field | Rule | If broken |
| --- | --- | --- |
| Size | A file or decoded link payload over 256 KB. | Refuse, before decoding |
| Saved size | A tactic whose repaired, saved form would be over 256 KB (repairs such as filling missing positions can grow a file). CenterSpot saves compact JSON when pretty-printed JSON would pass the cap (D-68). | Refuse |
| File type | Only a regular file is read; a pipe, device or folder named `.tactic` is never waited on (D-68). | Refuse |
| `schemaVersion` | Must be `1`. | Refuse: "Made with a newer version of CenterSpot." when higher; the generic error otherwise |
| Coordinates | `x`, `y` in 0…1 (D-05): `x` left → right, `y` own goal line (0) → opponent's goal line (1). | Out of range: repair (clamp). NaN or infinity: refuse |
| `pitch.kind` | `full`, `sevenASide`, `fiveASide`. | Refuse |
| `sides` | Exactly two, ids `home` and `away`. `colour` is a palette key (`UI-BRIEF.md` §2). | Wrong count or ids: refuse. Unknown or missing colour: repair (default: `lime` home, `coral` away, D-53) |
| `tokens` | 0…30 (an empty board is valid). Unique ids. `kind`: `player` (needs `side`), `ball`, `cone`, `marker`. | Over 30, duplicate id, unknown kind, player without side: refuse |
| `tokens[].number` | An integer, 0…99. | Out of range: repair (clamp). Not an integer (7.5, 1e20): refuse (D-45) |
| `tokens[].name` | ≤ 24 characters. | Repair (truncate) |
| `tokens[].roleID` | From `roles.json`, or omitted. | Unknown: repair (drop) |
| `phases` | 1…2, unique ids from `main`, `inPossession`, `outOfPossession` (D-20). v1 UI edits the first. | Refuse |
| `steps` | 1…40 per phase, unique ids. | Refuse |
| `steps[].duration` | 0.3…5 seconds. | Repair (clamp) |
| `steps[].positions` | Should list every token. A token missing from a step keeps its position from the step before; missing from step 1, it starts at the centre spot (0.5, 0.5). Keys that name no token are ignored. | Repair |
| `steps[].runs` | 2…200 points, keyed by a token id. On read a run is **anchored**: its first point is set to the token's position in this step and its last point to the token's position in the next step, so playback never jumps (D-27). A run on the last step has nowhere to go and is dropped. | Over 200 points or fewer than 2: refuse. Unknown token: repair (drop) |
| `steps[].arrows` | ≤ 30 per step, 2…200 points each; `kind`: `run`, `pass`, `dribble`, `press`. | Over the limits or unknown kind: refuse |
| `steps[].marks` | Optional (D-65); older files have none and open unchanged, and `schemaVersion` stays `1`. `zones`, `lines` and `glows`, each optional (an empty list is left out on write). At most **12 marks per step** in all. Every mark has an `id`, unique within its step; the same id on the next step carries the mark on (see Timing notes). | Over 12: refuse. Missing `id`: refuse. A repeated id: repair (drop the later mark, after the repairs below) |
| `marks.zones[]` | `x`, `y` is the corner nearest the left touchline and your own goal line, `w`, `h` the size, in pitch units (D-05); inside the pitch and at least 0.04 each side. A negative `w` or `h` runs the other way. `colour` is a palette key, default `lime`. | NaN, infinity or a missing number: refuse. Off the pitch: repair (cut to it). Under 0.04: repair (grown about its middle). Unknown or missing colour: repair (`lime`) |
| `marks.lines[]` | `tokens`: player ids in the order the line joins them, at most 11; one side (the first known player's), each player once, at least 2. Drawn in that side's colour; the corners follow the players. | Over 11 ids: refuse. Unknown ids, non-players, the other side's players, repeats: repair (drop them). Fewer than 2 left: repair (drop the line) |
| `marks.glows[]` | Rings under a player: `{ "id", "token" }`. Or heat on the grass: `{ "id", "x", "y", "r" }`, `r` a radius of 0.03…0.25 of the pitch width (default 0.11). `token` wins if both are given. | Neither a token nor `x` and `y`, or NaN or infinity: refuse. Unknown token or not a player: repair (drop). `x`, `y` off the pitch or `r` out of range: repair (clamp) |
| `note` | ≤ 140 characters. | Repair (truncate) |
| Unknown keys | Ignored on read, dropped on write. | Repair |

## Timing notes (D-45)

The timeline measures a run's length in metres on the pitch (x scaled by pitch width, y by length), so a runner keeps a steady speed round a bend. Arrows fade in over the first 0.2 s of their step's hold and fade out over the last 0.2 s of the move to the next step; the last step's arrows stay.

Marks (D-65) fade the same way as their step's arrows, with one exception: a mark whose `id` is also on the next step, as the same kind (a zone in the same colour, a line joining the same players, rings on the same player, or heat), carries on without fading, and a zone's box or a heat's spot and radius ease to the next step's with the players' move. A line's corners and a player's rings follow the players wherever the timeline puts them. In CenterSpot, a new step copies the marks of the step it is added after, with their ids.

## Links and QR (D-10, D-25; built after Day 7, D-36)

`centerspot://t#v1.` + base64url (no padding) of the JSON compressed as **raw DEFLATE (RFC 1951, no zlib header or checksum)**. In Python: `zlib.decompress(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)), -15)`.

The decoder checks, in order: the `v1.` prefix; the encoded string is at most 256 KB; base64url decodes; the stream inflates **with a streaming decoder that stops as soon as output passes 256 KB** (Compression framework `compression_stream`, or `InputFilter`), so a decompression bomb never fills memory; then the JSON is validated as above. One-shot `NSData.decompressed(using:)` is not used for links, because it inflates everything before the size can be checked. Any failure shows the generic error.

The same string goes into a QR code. Link length is measured, not assumed: `LinkCodecTests` records the length of every fixture, including a full 11-v-11, 6-step tactic (a synthetic one with random 3-decimal positions measured 2,286 characters on 6 Nov). A link over 2,000 characters offers the file instead.

## Versioning

A breaking change bumps `schemaVersion` and adds a migration from every older version, with a fixture per version in `CenterSpotTests/Fixtures/`.
