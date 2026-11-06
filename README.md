# Agmen

**Draw the move, not just the shape.** An iPhone and iPad app that turns a formation into a step-by-step animated move and exports it as a vertical video, an image or an open `.tactic` file.

> Work in progress. A one-week portfolio build by [Chime Ekpendu](https://chimexd.work) with Claude Code. This README is rewritten on Day 7, when the repo goes public.

- **Format:** [`docs/FORMAT.md`](docs/FORMAT.md): open JSON that any tool can read and write.
- **Plan:** [`docs/PLAN.md`](docs/PLAN.md) · **Decisions:** [`docs/DECISIONS.md`](docs/DECISIONS.md) · **Spec:** [`docs/SPEC.md`](docs/SPEC.md)

## Build

Requires Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig   # set your Team ID
xcodegen generate
open Agmen.xcodeproj
```

## Licence

Code: MIT. No club badges, league names, real kits or game assets are included or used.
