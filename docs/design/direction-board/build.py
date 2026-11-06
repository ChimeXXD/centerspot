# Builds index.html from template.html with the hero move injected from examples/ (no hand-typed positions).
import json, pathlib
here = pathlib.Path(__file__).parent
hero = json.loads((here / "../../../examples/overlap-left.tactic").read_text())
html = (here / "template.html").read_text().replace("/*HERO*/null", json.dumps(hero))
(here / "index.html").write_text(html)
print("index.html written:", len(html), "bytes")
