"""Genera los niveles: python3 tools/levelgen/gen.py [level1|level2|all] [--seed N]

Escribe assets_build/exports/Level_N.rbxmx y Level_N_Planta.png y muestra un resumen (piezas, luces, marcadores)."""
from __future__ import annotations

import argparse
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(__file__))

import plan  # noqa: E402
import rbx  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets_build", "exports")


def report(name, lvl, B):
    kinds = Counter(i.cls for i in B.root.iter())
    marks = Counter(m[0] for m in B.markers)
    print(f"== {name}: {B.root.count()} instancias · {kinds.get('Part', 0)} Part · luces {kinds.get('PointLight', 0)}+"
          f"{kinds.get('SpotLight', 0)} · {lvl.lay.summary()}")
    print("   marcadores:", dict(sorted(marks.items(), key=lambda kv: kv[0])) if len(marks) < 12 else
          {k: v for k, v in marks.items() if not k.startswith("Patrol")} | {"Patrol*": sum(v for k, v in marks.items() if k.startswith("Patrol"))})


def run(which: str, seed: int | None, out_dir: str):
    if which in ("level1", "all"):
        import level1
        lvl = level1.Level1(seed or 27)
        B = lvl.build()
        rbx.write_rbxmx(B.root, os.path.join(out_dir, "Level_1.rbxmx"), primary=lvl.dock)
        plan.render(lvl.lay, os.path.join(out_dir, "Level_1_Planta.png"), "Level_1 · Complejo Fabril", level1.C, B.markers, lvl.labels)
        report("Level_1", lvl, B)
    if which in ("level2", "all"):
        import level2
        lvl = level2.Level2(seed or 5)
        B = lvl.build()
        rbx.write_rbxmx(B.root, os.path.join(out_dir, "Level_2.rbxmx"), primary=lvl.dock)
        plan.render(lvl.lay, os.path.join(out_dir, "Level_2_Planta.png"), "Level_2 · Pantano de la Esclusa", level2.C, B.markers,
                    lvl.labels, theme=level2.PLAN_THEME)
        report("Level_2", lvl, B)
    arch_levels = {"level3": ("hospital", "Hospital", "Level_3", "Level_3 · Hospital San Judas"),
                   "level4": ("school", "School", "Level_4", "Level_4 · Escuela"),
                   "level5": ("mansion", "Mansion", "Level_5", "Level_5 · Mansión"),
                   "level6": ("mall", "Mall", "Level_6", "Level_6 · Centro comercial")}
    for key, (mod, cls, name, title) in arch_levels.items():
        if which not in (key, "all", "arch"):
            continue
        m = __import__(mod)
        lvl = getattr(m, cls)(seed or 3)
        B = lvl.build()
        rbx.write_rbxmx(B.root, os.path.join(out_dir, f"{name}.rbxmx"), primary=lvl.dock)
        plan.render(lvl.lay, os.path.join(out_dir, f"{name}_Planta.png"), title, 10, B.markers, lvl.labels, px=6)
        report(name, lvl, B)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("which", nargs="?", default="all")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    run(a.which, a.seed, a.out)
