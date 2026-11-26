"""Level_2 · Pantano de la Esclusa. Senderos entre muros de maleza (pasillos), claros con colinas, cabañas, pasarelas sobre pilotes,
casas del árbol y puentes colgantes (segundo piso). Siempre de noche, niebla, estilo plástico. Límites: anillos de árboles 2.5D.

Reutiliza el crecimiento y los marcadores de Level1; cambia la lectura de cada espacio y toda la geometría.
"""
from __future__ import annotations

import math
import random

import rbx
from build import merge_rects
from common import Frame, against_wall, hide_volume, marker, wall_slots
from layout import DIRS, Layout
from level1 import DOOR_H, DOOR_W, Level1

C, H = 12.0, 14.0
CEIL0 = 12.0
CEIL1 = H + 11.0
T = 1.0

WATER = (28, 52, 50)
MUD = (86, 68, 48)
GRASS = (58, 86, 50)
PLANK = (122, 92, 60)
PLANK_D = (92, 68, 44)
LOG = (78, 58, 40)
LEAF = [(40, 74, 44), (50, 90, 52), (34, 62, 40), (62, 96, 54)]
LANTERN = (255, 172, 92)
PLAN_THEME = {"bg": (18, 28, 26), "corridor": (128, 104, 72), "room": (100, 130, 84), "hall": (70, 110, 70),
              "catwalk": (200, 170, 110), "closet": (150, 110, 80)}

CABIN_TYPES = ["Cabaña del pescador", "Casa de las redes", "Caseta del motor", "Hospedaje", "Casa de bombeo", "Bodega de juncos",
               "Choza del vigía", "Pensión"]
CLEARING_TYPES = ["Claro", "Colina", "Charca", "Juncal"]


def generate(seed):
    lay = Layout(72, 72, seed)
    lay.params.update(budget=1900, p_side=0.12, p_down=0.16, p_stairs=0.07, room=(3, 5), hall=(6, 8), p_hall=0.3, seg=(3, 6))
    lay.place_hub(hub_w=5, hub_d=4, shaft_w=3, shaft_d=3)
    lay.grow()
    lay.prune()
    lay.add_loops()
    lay.prune()
    return lay


class Level2(Level1):
    CELL, LH, CEIL1 = C, H, CEIL1
    NAME = "Level_2"

    def generate(self, seed):
        return generate(seed)

    def __init__(self, seed=5):
        super().__init__(seed)
        self.rng = random.Random(seed * 13 + 3)
        self.hills = []  # (x, z, R, h)

    # ------------------------------------------------------------------ semántica
    def indoor(self, s):
        if s is None:
            return False
        if s.kind in ("shaft", "closet"):
            return True
        if s.kind == "room":
            return s.data.get("indoor", False)
        return False

    def assign(self):
        rng = self.rng
        n = {}
        for s in self.lay.spaces:
            if not s.cells:
                continue
            l = min(c[0] for c in s.cells)
            if s.kind == "room":
                if l == 1:
                    s.data.update(indoor=True, type="Casa del árbol")
                elif rng.random() < 0.55:
                    s.data.update(indoor=True, type=rng.choice(CABIN_TYPES))
                else:
                    s.data.update(indoor=False, type=rng.choice(CLEARING_TYPES))
            elif s.kind == "hall":
                s.data.update(indoor=False, type="Gran claro")
            elif s.kind == "closet":
                s.data.update(type="Caseta")
            t = s.data.get("type")
            if t:
                n[t] = n.get(t, 0) + 1
                s.name = f"{t} {n[t]}"
        # Puertas con puzzle: solo en cabañas hoja (el vano necesita jambas)
        leaves = [(s, k) for (s, k) in self.lay.leaf_rooms() if self.indoor(s)]
        rng.shuffle(leaves)
        chosen = []
        for (s, k) in leaves:
            a, b = tuple(k)
            if a[0] != b[0] or min(self.dist.get(c, 0) for c in s.cells if c in self.dist) < 14:
                continue
            if any(abs(a[1] - o[1]) + abs(a[2] - o[2]) < 16 for o in chosen):
                continue
            self.lay.links[k] = "puzzle"
            self.puzzle_rooms.add(s.sid)
            chosen.append(a)
            if len(chosen) >= 4:
                break

    def fake_corridors(self):
        self.fakes = []

    def wall_key(self, ca, cb):
        sa, sb = self.lay.space_of(ca), self.lay.space_of(cb)
        if self.indoor(sa) or self.indoor(sb):
            s = sa if self.indoor(sa) else sb
            return "concrete" if s.kind == "shaft" else "wood"
        if ca[0] == 1:
            return "rail"
        return "hedge"

    # ------------------------------------------------------------------ estructura
    def structure(self):
        lay, B, rng = self.lay, self.B, self.rng
        S = B.folder("Estructura/Suelos")
        W, Hh = lay.w * C, lay.h * C
        # Agua de la ciénaga bajo todo y más allá del borde (el límite se pierde en la niebla)
        rbx.box(B.folder("Estructura"), "Cienaga", -260, W + 260, -2.6, -1.4, -260, Hh + 260, WATER, reflect=0.12)
        for s in lay.spaces:
            if not s.cells or s.kind == "stair":
                continue
            for l in (0, 1):
                cells = {(x, z) for (cl, x, z) in s.cells if cl == l and (cl, x, z) not in s.void}
                for (x0, x1, z0, z1) in merge_rects(cells):
                    X0, X1, Z0, Z1 = x0 * C, (x1 + 1) * C, z0 * C, (z1 + 1) * C
                    if l == 0:
                        if s.kind == "hub":
                            self.platform = rbx.box(B.root, "Platform", X0, X1, -1.5, 0, Z0, Z1, (96, 98, 94))
                        elif s.kind == "shaft":
                            rbx.box(S, "Suelo", X0, X1, -1.5, 0, Z0, Z1, (70, 72, 70))
                        elif self.indoor(s):
                            rbx.box(S, "Tarima", X0, X1, -1.5, 0, Z0, Z1, PLANK_D, "WoodPlanks")
                        elif s.kind == "corridor":
                            low = s.data.setdefault("boardwalk", rng.random() < 0.35)
                            if low:
                                self.planks(S, X0, X1, Z0, Z1, 0, posts=True)
                            else:
                                rbx.box(S, "Sendero", X0, X1, -1.5, 0, Z0, Z1, MUD)
                        else:
                            rbx.box(S, "Claro", X0, X1, -1.5, 0, Z0, Z1, GRASS)
                    elif s.kind == "catwalk":
                        pass  # puente colgante: abajo
                    else:
                        self.planks(S, X0, X1, Z0, Z1, H, posts=False)
        # Pilotes de las pasarelas altas y puentes colgantes
        P = B.folder("Estructura/Pilotes")
        for s in lay.spaces:
            if not s.cells:
                continue
            for c in s.cells:
                l, x, z = c
                if l != 1 or c in s.void:
                    continue
                below = lay.space_of((0, x, z))
                if s.kind == "catwalk":
                    self.rope_bridge(S, s, c)
                    continue
                for (sx, sz) in (((0.08, 0.08), (0.92, 0.92)) if (x + z) % 2 else ((0.08, 0.92), (0.92, 0.08))):
                    px, pz = (x + sx) * C, (z + sz) * C
                    if below is not None and below.kind not in ("shaft",) and (0, x, z) not in below.void:
                        # hay paso debajo: pilotes solo en los bordes, sin cruzar el camino
                        continue
                    rbx.cylinder_y(P, "Pilote", (px, (H - 0.5 - 2.6) / 2, pz), H - 0.5 + 2.6, 1.1, LOG, "Wood")
        # Techos de cabañas (planos por dentro, a dos aguas por fuera) y casas del árbol
        R = B.folder("Estructura/Tejados")
        for s in lay.spaces:
            if not self.indoor(s) or not s.cells:
                continue
            for l in (0, 1):
                cells = {(x, z) for (cl, x, z) in s.cells if cl == l}
                if not cells:
                    continue
                top = CEIL0 if l == 0 else CEIL1
                for (x0, x1, z0, z1) in merge_rects(cells):
                    rbx.box(R, "Techo", x0 * C, (x1 + 1) * C, top, top + 0.6, z0 * C, (z1 + 1) * C, (70, 54, 38), "WoodPlanks")
                if l == 0 and any((1, x, z) in lay.occ for (x, z) in cells):
                    continue
                x0, x1, z0, z1 = min(c[0] for c in cells), max(c[0] for c in cells), min(c[1] for c in cells), max(c[1] for c in cells)
                self.gable(R, x0 * C - 1, (x1 + 1) * C + 1, z0 * C - 1, (z1 + 1) * C + 1, top + 0.6,
                           (s.kind == "shaft"))
        # Muros, maleza y barandillas
        Wf = B.folder("Estructura/Muros")
        Hg = B.folder("Estructura/Maleza")
        for l in (0, 1):
            y0 = l * H
            for (axis, line, a0, a1, style, segs) in B.wall_runs(l, self.wall_key):
                if style == "wood":
                    y1 = y0 + (CEIL0 if l == 0 else CEIL1 - H) + 0.6
                    self.wood_wall(Wf, axis, line, a0, a1, y0, y1, windows=True)
                elif style == "concrete":
                    B.wall_box(Wf, "Hormigon", axis, line, a0 - T / 2, a1 + T / 2, y0 - 1.5, y0 + H + (11 if l else 0), T * 2,
                               (104, 108, 104), "Concrete")
                elif style == "hedge":
                    # Con segundo piso encima de la arista (escalera, rellano, pasarela) la barrera llega solo al suelo de arriba:
                    # si subiera hasta 34 cerraría la salida de las escaleras. Arriba ya protegen las barandillas.
                    for (ca, cb) in segs:
                        up = any((1, c[1], c[2]) in lay.occ for c in (ca, cb))
                        top = H - 0.7 if up else 34
                        if axis == "x":
                            sa0, sa1 = min(ca[1], cb[1]) * C, (min(ca[1], cb[1]) + 1) * C
                        else:
                            sa0, sa1 = min(ca[2], cb[2]) * C, (min(ca[2], cb[2]) + 1) * C
                        B.wall_box(Hg, "Barrera", axis, line, sa0, sa1, -1.5, top, 0.6, (0, 0, 0), transparency=1, shadow=False)
                else:  # rail
                    self.wood_rail(Wf, axis, line, a0, a1, y0)
        D = B.folder("Estructura/Vanos")
        for l in (0, 1):
            y0 = l * H
            for (t, axis, line, a0, a1, ca, cb) in B.edges(l):
                if t in ("door", "puzzle"):
                    sa, sb = lay.space_of(ca), lay.space_of(cb)
                    if self.indoor(sa) or self.indoor(sb):
                        y1 = y0 + (CEIL0 if l == 0 else CEIL1 - H) + 0.6
                        self.wood_wall(D, axis, line, a0, a1, y0, y1, door=True)
                        if t == "puzzle":
                            self.door_markers.append((axis, line, (a0 + a1) / 2, y0, ca, cb))
                    else:
                        # entrada de un claro: dos postes con farol
                        for sgn in (-1, 1):
                            a = (a0 + a1) / 2 + sgn * (C / 2 - 0.8)
                            pos = (a, y0, line) if axis == "x" else (line, y0, a)
                            self.lantern_post(B.folder("Iluminacion"), pos, lit=self.rng.random() < 0.5)
                elif t == "rail":
                    self.rail(D, l, axis, line, a0, a1, ca, cb)
        E = B.folder("Estructura/Escaleras")
        for st in lay.stairs:
            m = rbx.model(E, "Escalera")
            B.stair_steps(m, st, C - 2, PLANK, "WoodPlanks", steps=16)

    def rail(self, parent, l, axis, line, a0, a1, ca, cb):
        lay = self.lay
        sa, sb = lay.space_of(ca), lay.space_of(cb)
        stair = sa if sa and sa.kind == "stair" else (sb if sb and sb.kind == "stair" else None)
        if stair and l == 0:
            c = ca if sa is stair else cb
            st = stair.data
            i = st["cells"].index((c[1], c[2]))
            top = (i + 1) * H / 3 if st["high_end"] == 2 else (3 - i) * H / 3
            self.B.wall_box(parent, "Pretil", axis, line, a0, a1, 0, top + 3.2, 0.8, PLANK_D, "WoodPlanks")
            return
        self.wood_rail(parent, axis, line, a0, a1, l * H)

    def planks(self, parent, X0, X1, Z0, Z1, y, posts):
        """Tablones: una losa con colisión y juntas pintadas encima (pocas piezas)."""
        rbx.box(parent, "Tablones", X0, X1, y - 0.7, y, Z0, Z1, PLANK, "WoodPlanks")
        along_x = (X1 - X0) >= (Z1 - Z0)
        if along_x:
            for k in range(1, int((Z1 - Z0) / 2)):
                if k % 2:
                    rbx.box(parent, "Junta", X0, X1, y, y + 0.04, Z0 + k * 2 - 0.08, Z0 + k * 2 + 0.08, PLANK_D, collide=False,
                            query=False, shadow=False)
        else:
            for k in range(1, int((X1 - X0) / 2)):
                if k % 2:
                    rbx.box(parent, "Junta", X0 + k * 2 - 0.08, X0 + k * 2 + 0.08, y, y + 0.04, Z0, Z1, PLANK_D, collide=False,
                            query=False, shadow=False)
        if posts:
            for (px, pz) in ((X0 + 0.5, Z0 + 0.5), (X1 - 0.5, Z0 + 0.5), (X0 + 0.5, Z1 - 0.5), (X1 - 0.5, Z1 - 0.5)):
                rbx.cylinder_y(parent, "Poste", (px, y - 1.5, pz), 2.6, 0.8, LOG, "Wood", collide=False, query=False)

    def rope_bridge(self, parent, s, c):
        l, x, z = c
        axis = self._axis(s, c)
        cx, cz = (x + 0.5) * C, (z + 0.5) * C
        # tablones transversales con huecos
        for k in range(6):
            o = -C / 2 + 1 + k * 2
            if axis == "x":
                rbx.part(parent, "Tabla", (cx + o, H - 0.25, cz), (1.7, 0.5, 6.4), PLANK, "WoodPlanks",
                         rot=rbx.rot_y(self.rng.uniform(-3, 3)))
            else:
                rbx.part(parent, "Tabla", (cx, H - 0.25, cz + o), (6.4, 0.5, 1.7), PLANK, "WoodPlanks",
                         rot=rbx.rot_y(self.rng.uniform(-3, 3)))
        # suelo de colisión continuo e invisible (los huecos son solo visuales)
        if axis == "x":
            rbx.box(parent, "Piso", x * C, (x + 1) * C, H - 0.5, H - 0.1, cz - 3.2, cz + 3.2, (0, 0, 0), transparency=1, shadow=False)
            for sgn in (-1, 1):
                rbx.box(parent, "Cuerda", x * C, (x + 1) * C, H + 3.2, H + 3.45, cz + sgn * 3.3 - 0.12, cz + sgn * 3.3 + 0.12,
                        (176, 150, 100), "Fabric", collide=False, query=False)
                rbx.box(parent, "Red", x * C, (x + 1) * C, H, H + 4.4, cz + sgn * 3.4 - 0.2, cz + sgn * 3.4 + 0.2, (0, 0, 0),
                        transparency=1, shadow=False)
                for k in range(3):
                    rbx.part(parent, "Tirante", (x * C + 2 + k * 4, H + 1.6, cz + sgn * 3.3), (0.15, 3.2, 0.15), (176, 150, 100),
                             "Fabric", collide=False, query=False)
        else:
            rbx.box(parent, "Piso", cx - 3.2, cx + 3.2, H - 0.5, H - 0.1, z * C, (z + 1) * C, (0, 0, 0), transparency=1, shadow=False)
            for sgn in (-1, 1):
                rbx.box(parent, "Cuerda", cx + sgn * 3.3 - 0.12, cx + sgn * 3.3 + 0.12, H + 3.2, H + 3.45, z * C, (z + 1) * C,
                        (176, 150, 100), "Fabric", collide=False, query=False)
                rbx.box(parent, "Red", cx + sgn * 3.4 - 0.2, cx + sgn * 3.4 + 0.2, H, H + 4.4, z * C, (z + 1) * C, (0, 0, 0),
                        transparency=1, shadow=False)
                for k in range(3):
                    rbx.part(parent, "Tirante", (cx + sgn * 3.3, H + 1.6, z * C + 2 + k * 4), (0.15, 3.2, 0.15), (176, 150, 100),
                             "Fabric", collide=False, query=False)

    def gable(self, parent, X0, X1, Z0, Z1, y, slate=False, rise=4.5):
        """Tejado a dos aguas con dos WedgePart (cumbrera a lo largo del lado largo)."""
        col = (84, 90, 96) if slate else (96, 60, 44)
        if (X1 - X0) >= (Z1 - Z0):
            half = (Z1 - Z0) / 2
            zc = (Z0 + Z1) / 2
            rbx.part(parent, "Faldon", ((X0 + X1) / 2, y + rise / 2, zc - half / 2), (X1 - X0, rise, half), col, cls="WedgePart",
                     rot=rbx.rot_y(180))
            rbx.part(parent, "Faldon", ((X0 + X1) / 2, y + rise / 2, zc + half / 2), (X1 - X0, rise, half), col, cls="WedgePart")
        else:
            half = (X1 - X0) / 2
            xc = (X0 + X1) / 2
            rbx.part(parent, "Faldon", (xc - half / 2, y + rise / 2, (Z0 + Z1) / 2), (Z1 - Z0, rise, half), col, cls="WedgePart",
                     rot=rbx.rot_y(-90))
            rbx.part(parent, "Faldon", (xc + half / 2, y + rise / 2, (Z0 + Z1) / 2), (Z1 - Z0, rise, half), col, cls="WedgePart",
                     rot=rbx.rot_y(90))

    def wood_wall(self, parent, axis, line, a0, a1, y0, y1, windows=False, door=False):
        B = self.B
        a0e, a1e = a0 - T / 2, a1 + T / 2
        col = (110, 84, 58)
        if door:
            B.doorway(parent, "Pared", axis, line, a0e, a1e, y0, y1, T, DOOR_W, DOOR_H, col, "WoodPlanks")
            for sgn in (-1, 1):
                a = (a0 + a1) / 2 + sgn * (DOOR_W / 2 + 0.2)
                B.wall_box(parent, "Marco", axis, line, a - 0.25, a + 0.25, y0, y0 + DOOR_H, T + 0.3, PLANK_D, "Wood")
            return
        L = a1 - a0
        if windows and L >= C and self.rng.random() < 0.5:
            mid = (a0 + a1) / 2
            w0, w1 = mid - 1.8, mid + 1.8
            B.wall_box(parent, "Pared", axis, line, a0e, w0, y0, y1, T, col, "WoodPlanks")
            B.wall_box(parent, "Pared", axis, line, w1, a1e, y0, y1, T, col, "WoodPlanks")
            B.wall_box(parent, "Pared", axis, line, w0, w1, y0, y0 + 4.5, T, col, "WoodPlanks")
            B.wall_box(parent, "Pared", axis, line, w0, w1, y0 + 8, y1, T, col, "WoodPlanks")
            # ventana: cristal sucio que deja escapar luz cálida
            B.wall_box(parent, "Ventana", axis, line, w0, w1, y0 + 4.5, y0 + 8, 0.2, (255, 196, 120), "Glass", transparency=0.55,
                       query=False)
            B.wall_box(parent, "Cruceta", axis, line, mid - 0.12, mid + 0.12, y0 + 4.5, y0 + 8, T + 0.1, PLANK_D, collide=False,
                       query=False)
        else:
            B.wall_box(parent, "Pared", axis, line, a0e, a1e, y0, y1, T, col, "WoodPlanks")
        # vigas vistas (estilo cabaña)
        B.wall_box(parent, "Viga", axis, line, a0e, a1e, y0 + 0.2, y0 + 0.9, T + 0.4, LOG, "Wood", collide=False, query=False)

    def wood_rail(self, parent, axis, line, a0, a1, y):
        B = self.B
        m = rbx.model(parent, "Baranda")
        B.wall_box(m, "Pasamanos", axis, line, a0, a1, y + 3.2, y + 3.6, 0.4, PLANK, "Wood", collide=False)
        B.wall_box(m, "Larguero", axis, line, a0, a1, y + 1.6, y + 1.9, 0.3, PLANK_D, "Wood", collide=False)
        for a in (a0 + 0.4, (a0 + a1) / 2, a1 - 0.4):
            B.wall_box(m, "Poste", axis, line, a - 0.25, a + 0.25, y - 0.5, y + 3.8, 0.5, LOG, "Wood", collide=False)
        B.wall_box(m, "Colision", axis, line, a0, a1, y, y + 4.4, 0.4, (0, 0, 0), transparency=1, shadow=False)

    # ------------------------------------------------------------------ vegetación
    def tree(self, parent, x, z, scale=1.0, y=0.0, shadow=True):
        rng = self.rng
        h = rng.uniform(14, 24) * scale
        m = rbx.model(parent, "Arbol")
        rbx.cylinder_y(m, "Tronco", (x, y + h / 2 - 1.5, z), h + 3, rng.uniform(1.6, 2.6) * scale, LOG, "Wood", collide=False,
                       query=False, shadow=shadow)
        for k in range(rng.randint(1, 2)):
            s = rng.uniform(9, 14) * scale
            rbx.ellipsoid(m, "Copa", (x + rng.uniform(-2, 2), y + h - 1 + k * 2.6, z + rng.uniform(-2, 2)), (s, s * 0.7, s),
                          rng.choice(LEAF), shadow=shadow)
        # musgo colgante (cipreses del pantano)
        if rng.random() < 0.5:
            rbx.part(m, "Musgo", (x + rng.uniform(-3, 3), y + h - 5, z + rng.uniform(-3, 3)), (0.4, 6, 3.0), (90, 110, 80),
                     "Fabric", collide=False, query=False, transparency=0.2, shadow=False)
        return m

    def bush(self, parent, x, z, size=1.0, y=0.0):
        m = rbx.model(parent, "Arbusto")
        for k in range(2):
            s = self.rng.uniform(4, 6.5) * size
            rbx.ellipsoid(m, "Hojas", (x + self.rng.uniform(-1.6, 1.6), y + s * 0.33, z + self.rng.uniform(-1.6, 1.6)),
                          (s, s * 0.8, s), self.rng.choice(LEAF))
        return m

    def cutout_tree(self, parent, x, z, dist_shade=1.0, scale=1.0):
        """Árbol 2.5D: tronco y dos discos cruzados. Tres piezas, sin sombra ni colisión: relleno lejano barato."""
        rng = self.rng
        h = rng.uniform(16, 28) * scale
        col = tuple(int(c * dist_shade) for c in rng.choice(LEAF))
        trunk = tuple(int(c * dist_shade) for c in LOG)
        kw = dict(collide=False, query=False, shadow=False)
        rbx.part(parent, "Silueta", (x, h * 0.35, z), (1.6 * scale, h * 0.7, 0.3), trunk, **kw)
        w = rng.uniform(10, 16) * scale
        for yaw in (0, 90):
            p = rbx.ellipsoid(parent, "Silueta", (x, h * 0.75, z), (w, h * 0.55, 0.4), col, **kw)
            p.props["rot"] = rbx.rot_y(yaw + rng.uniform(-10, 10))

    def vegetation(self):
        lay, B, rng = self.lay, self.B, self.rng
        V = B.folder("Vegetacion")
        near = B.folder("Vegetacion/Maleza")
        far = B.folder("Vegetacion/Siluetas")
        walk0 = {(x, z) for (l, x, z), sid in lay.occ.items() if l == 0}
        walk1 = {(x, z) for (l, x, z), sid in lay.occ.items() if l == 1}
        for x in range(lay.w):
            for z in range(lay.h):
                if (x, z) in walk0:
                    continue
                adj = any((x + dx, z + dz) in walk0 for dx in (-1, 0, 1) for dz in (-1, 0, 1))
                cx, cz = (x + 0.5) * C, (z + 0.5) * C
                if adj:
                    over = (x, z) in walk1
                    r = rng.random()
                    if (x + z) % 2 and not over and r < 0.8:
                        self.tree(near, cx + rng.uniform(-3, 3), cz + rng.uniform(-3, 3), rng.uniform(0.8, 1.15))
                    else:
                        self.bush(near, cx + rng.uniform(-2, 2), cz + rng.uniform(-2, 2), rng.uniform(1.0, 1.5))
                    # juncos al pie del muro de maleza
                    for k in range(1 if rng.random() < 0.3 else 0):
                        rbx.part(near, "Junco", (cx + rng.uniform(-5, 5), 1.2, cz + rng.uniform(-5, 5)), (0.25, rng.uniform(3, 5), 0.25),
                                 (110, 130, 70), collide=False, query=False, shadow=False, rot=rbx.rot_z(rng.uniform(-12, 12)))
                elif (x + 2 * z) % 7 == 0 and (x, z) not in walk1:
                    self.cutout_tree(far, cx + rng.uniform(-4, 4), cz + rng.uniform(-4, 4), 0.8)

    def clearing_decor(self, p, s, slots):
        """Claros: colina (bola hundida, se puede subir), arbustos-escondite, tronco caído, charca o juncal."""
        B, rng = self.B, self.rng
        t = s.data.get("type", "")
        cells = sorted(c for c in s.cells if c[0] == 0 and c not in s.void)
        if not cells:
            return
        xs = [c[1] for c in cells]
        zs = [c[2] for c in cells]
        cx, cz = (min(xs) + max(xs) + 1) / 2 * C, (min(zs) + max(zs) + 1) / 2 * C
        span = min(max(xs) - min(xs) + 1, max(zs) - min(zs) + 1) * C
        if s.kind == "hall" or t == "Colina":
            n = 2 if s.kind == "hall" else 1
            for k in range(n):
                hx = cx + (rng.uniform(-0.25, 0.25) * span if n == 1 else (k - 0.5) * span * 0.45)
                hz = cz + rng.uniform(-0.2, 0.2) * span
                hh = rng.uniform(4.5, 6.5)
                rim = min(span * 0.42, 22)
                R = (rim * rim + hh * hh) / (2 * hh)
                # que no tape la escalera interior ni la entrada
                if not B.free_spot(hx - rim, hx + rim, hz - rim, hz + rim, 0, pad=2):
                    continue
                rbx.part(p, "Colina", (hx, hh - R, hz), (2 * R, 2 * R, 2 * R), GRASS, shape="Ball")
                self.hills.append((hx, hz, R, hh))
                B.block(hx - rim * 0.5, hx + rim * 0.5, hz - rim * 0.5, hz + rim * 0.5, 0)
                # árbol solitario en la cima
                if rng.random() < 0.6:
                    self.tree(p, hx, hz, 1.1, y=hh - 0.5)
        elif t == "Charca":
            r = span * 0.3
            if B.free_spot(cx - r, cx + r, cz - r, cz + r, 0):
                rbx.part(p, "Charca", (cx, 0.04, cz), (0.1, 2 * r, 2 * r), (36, 70, 66), "Glass", shape="Cylinder", rot=rbx.rot_z(90),
                         collide=False, query=False, reflect=0.3, transparency=0.1)
                B.block(cx - r, cx + r, cz - r, cz + r, 0)
                for k in range(8):
                    a = k / 8 * math.tau
                    rbx.part(p, "Junco", (cx + math.cos(a) * r, 1.6, cz + math.sin(a) * r), (0.25, 3.6, 0.25), (110, 130, 70),
                             collide=False, query=False, shadow=False)
        # arbustos escondite contra el muro de maleza
        k = 0
        for (c, d) in slots:
            if k >= (4 if s.kind == "hall" else 2):
                break
            fr = against_wall(B, c, d, 5, inset=0.4)
            a, b = fr.w(-3, 0, -2.5), fr.w(3, 0, 2.5)
            if not B.free_spot(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0):
                continue
            B.block(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0)
            self.hide_bush(p, fr)
            k += 1
        # tronco caído
        if rng.random() < 0.6:
            l, x, z = rng.choice(cells)
            px, _, pz = B.cell_center(x, z)
            if B.free_spot(px - 4, px + 4, pz - 4, pz + 4, 0):
                rbx.part(p, "Tronco", (px, 0.9, pz), (9, 2.2, 2.2), LOG, "Wood", shape="Cylinder", rot=rbx.rot_y(rng.uniform(0, 180)))
                B.block(px - 4, px + 4, pz - 4, pz + 4, 0)

    def hide_bush(self, p, fr):
        m = rbx.model(p, "ArbustoEscondite")
        for (lx, lz, s) in ((-1.4, 0.4, 5.6), (1.5, 0.2, 5.2), (0, -0.9, 5.0), (0, 1.0, 5.8)):
            fr.ell(m, "Hojas", (lx, s * 0.36, lz), (s, s * 0.85, s), self.rng.choice(LEAF))
        # flores pálidas: delatan el arbusto bueno a quien se fija
        for k in range(3):
            fr.part(m, "Flor", (self.rng.uniform(-2, 2), 3.6 + self.rng.uniform(0, 0.8), -2.3), (0.35, 0.35, 0.35), (220, 210, 240),
                    "Neon", shape="Ball", collide=False, query=False, shadow=False)
        hide_volume(m, fr.w(0, 3.0, 0), (3.5, 6.0, 3.5), "Bush", "Arbusto", rot=fr.rot)
        self.B.markers.append(("Escondite", *fr.w(0, 0, 0)))

    def wardrobe(self, p, fr, l):
        if not self.take(fr, 4.0, 2.8, l):
            return
        self.locker_n += 1
        m = rbx.model(p, f"Armario{self.locker_n:02d}")
        fr.part(m, "Cuerpo", (0, 3.9, 0.2), (4.0, 7.8, 2.6), (96, 70, 46), "WoodPlanks")
        for sx in (-1, 1):
            fr.part(m, "Hoja", (sx * 0.98, 3.8, -1.15), (1.9, 7.2, 0.15), (118, 88, 58), "WoodPlanks", collide=False)
            fr.part(m, "Pomo", (sx * 0.25, 3.8, -1.3), (0.25, 0.25, 0.25), (200, 170, 90), "Metal", shape="Ball", collide=False)
        fr.part(m, "Rendija", (0, 3.8, -1.25), (0.08, 7.0, 0.05), (10, 8, 6), collide=False, shadow=False)
        fr.part(m, "Corona", (0, 8.0, 0.1), (4.4, 0.5, 2.9), PLANK_D, "Wood", collide=False)
        hide_volume(m, fr.w(0, 3.0, 0.2), (3.2, 6.0, 2.0), "Locker", "Armario", rot=fr.rot)
        self.B.markers.append(("Escondite", *fr.w(0, 0, 0)))

    def cabin_decor(self, p, s, slots):
        rng = self.rng
        tops = []
        fns = ["wardrobe", "bed_rustic", "table_rustic", "shelf_rustic", "stove", "crates"]
        k = 0
        for (c, d) in slots:
            fn = fns[k % len(fns)] if k < 2 else rng.choice(fns)
            dep = {"wardrobe": 2.8, "bed_rustic": 7, "table_rustic": 3.5, "shelf_rustic": 2.4, "stove": 3, "crates": 4}[fn]
            fr = against_wall(self.B, c, d, dep)
            getattr(self, fn)(p, fr, c[0])
            k += 1
            if k >= len(slots) * 0.6 + 1:
                break
        # bombilla colgante
        cells = [c for c in s.cells if c not in s.void]
        l, x, z = sorted(cells)[len(cells) // 2]
        cx, cy, cz = self.B.cell_center(x, z, l)
        top = cy + (CEIL0 if l == 0 else CEIL1 - H)
        rbx.part(p, "Cable", (cx, top - 1.2, cz), (0.1, 2.4, 0.1), (20, 20, 20), collide=False, query=False)
        lit = rng.random() < 0.7
        b = rbx.part(p, "Bombilla", (cx, top - 2.6, cz), (0.7, 0.7, 0.7), (255, 190, 110) if lit else (90, 80, 70),
                     "Neon" if lit else "Glass", shape="Ball", collide=False, query=False, shadow=False)
        if lit:
            rbx.light(b, "PointLight", (255, 180, 100), 1.2, 22, shadows=True)
            if rng.random() < 0.35:
                b.tags.append("LamparaInstalacion")
                b.attrs["Parpadeo"] = True
        return tops

    def bed_rustic(self, p, fr, l):
        if not self.take(fr, 4, 7, l):
            return
        m = rbx.model(p, "Catre")
        fr.part(m, "Armazon", (0, 1.2, -0.4), (3.8, 0.8, 6.8), PLANK_D, "Wood")
        fr.part(m, "Colchon", (0, 1.9, -0.4), (3.4, 0.6, 6.4), (170, 160, 130), "Fabric")
        fr.part(m, "Manta", (0, 2.25, -1.4), (3.5, 0.2, 4.0), (120, 60, 50), "Fabric", collide=False)
        fr.part(m, "Cabecero", (0, 2.6, 2.95), (3.8, 3.2, 0.4), PLANK_D, "Wood")

    def table_rustic(self, p, fr, l):
        if not self.take(fr, 5, 3.5, l):
            return
        m = rbx.model(p, "Mesa")
        fr.part(m, "Tablero", (0, 3.0, 0), (5, 0.35, 3.2), PLANK, "WoodPlanks")
        for sx in (-2.2, 2.2):
            fr.part(m, "Pata", (sx, 1.4, 0), (0.4, 2.8, 2.6), PLANK_D, "Wood")
        v = fr.part(m, "Vela", (1.2, 3.5, 0), (0.3, 0.7, 0.3), (240, 230, 200), collide=False)
        if self.rng.random() < 0.5:
            f = fr.part(m, "Llama", (1.2, 4.0, 0), (0.2, 0.3, 0.2), (255, 170, 60), "Neon", collide=False, shadow=False)
            rbx.light(f, "PointLight", (255, 160, 70), 0.7, 10)

    def shelf_rustic(self, p, fr, l):
        if not self.take(fr, 5, 2.4, l):
            return
        m = rbx.model(p, "Alacena")
        for y in (0.6, 3.0, 5.4, 7.6):
            fr.part(m, "Balda", (0, y, 0), (5, 0.25, 2.2), PLANK, "WoodPlanks")
        for sx in (-2.4, 2.4):
            fr.part(m, "Lateral", (sx, 4, 0), (0.25, 8, 2.2), PLANK_D, "Wood")
        for k in range(6):
            fr.part(m, "Tarro", (self.rng.uniform(-2, 2), self.rng.choice((3.6, 6.0)), self.rng.uniform(-0.5, 0.5)),
                    (0.7, 1.1, 0.7), self.rng.choice([(150, 170, 120), (180, 120, 80), (200, 200, 180)]), "Glass", shape="Cylinder",
                    collide=False, lrot=rbx.rot_z(90), transparency=0.2)

    def stove(self, p, fr, l):
        if not self.take(fr, 3, 3, l):
            return
        m = rbx.model(p, "Estufa")
        fr.part(m, "Cuerpo", (0, 1.8, 0), (2.8, 3.6, 2.8), (50, 50, 52), "Metal")
        fr.part(m, "Tubo", (0, 7.5, 0.6), (0.8, 8, 0.8), (40, 40, 42), "Metal", collide=False)
        g = fr.part(m, "Brasas", (0, 1.4, -1.42), (1.4, 0.8, 0.05), (255, 110, 40), "Neon", collide=False, shadow=False)
        rbx.light(g, "PointLight", (255, 110, 50), 1.0, 14)

    def treehouse_trunk(self, s):
        """El árbol que sostiene la casa: tronco desde la ciénaga, atraviesa la casa y asoma la copa sobre el tejado (hito visual)."""
        B, lay = self.B, self.lay
        cells = sorted((x, z) for (l, x, z) in s.cells if l == 1)
        x, z = cells[len(cells) // 2]
        cx, cz = (x + 0.5) * C, (z + 0.5) * C
        top = CEIL1 + 14
        below = lay.space_of((0, x, z))
        y0 = -2 if below is None else H - 0.7
        m = rbx.model(B.folder("Vegetacion/ArbolesCasa"), "ArbolCasa")
        rbx.cylinder_y(m, "Tronco", (cx, (y0 + top) / 2, cz), top - y0, 4.2, LOG, "Wood")
        B.block(cx - 2.6, cx + 2.6, cz - 2.6, cz + 2.6, 1)
        for k in range(4):
            sz = self.rng.uniform(16, 22)
            rbx.ellipsoid(m, "Copa", (cx + self.rng.uniform(-4, 4), top + k * 3, cz + self.rng.uniform(-4, 4)), (sz, sz * 0.6, sz),
                          self.rng.choice(LEAF))
        if below is None:
            for a in range(4):
                ang = a * math.pi / 2 + 0.4
                rbx.part(m, "Raiz", (cx + math.cos(ang) * 3, 0, cz + math.sin(ang) * 3), (6, 1.4, 1.4), LOG, "Wood", shape="Cylinder",
                         rot=rbx.mat_mul(rbx.rot_y(-math.degrees(ang)), rbx.rot_z(-25)), collide=False, query=False)

    def decor(self):
        lay, B = self.lay, self.B
        Dfold = B.folder("Decoracion")
        self.locker_n = 0
        for s in lay.spaces:
            if not s.cells:
                continue
            m = rbx.folder(Dfold, (s.name or s.kind).replace(" ", "_"))
            slots = wall_slots(B, s)
            self.rng.shuffle(slots)
            if s.kind == "room" and self.indoor(s):
                self.cabin_decor(m, s, slots)
                if s.data.get("type") == "Casa del árbol":
                    self.treehouse_trunk(s)
            elif s.kind in ("room", "hall"):
                self.clearing_decor(m, s, slots)
            elif s.kind == "closet":
                for (c, d) in slots[:1]:
                    self.wardrobe(m, against_wall(B, c, d, 2.8), c[0])
            elif s.kind == "corridor":
                for (c, d) in slots:
                    if self.rng.random() < 0.03 and c[0] == 0:
                        fr = against_wall(B, c, d, 5, inset=0.3)
                        a, b = fr.w(-3, 0, -2.5), fr.w(3, 0, 2.5)
                        if B.free_spot(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0):
                            B.block(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0)
                            self.hide_bush(m, fr)
        self.vegetation()

    # ------------------------------------------------------------------ luces
    def lantern_post(self, parent, pos, lit=True):
        x, y, z = pos
        m = rbx.model(parent, "Farol")
        rbx.part(m, "Poste", (x, y + 3, z), (0.5, 6, 0.5), LOG, "Wood", collide=False, query=False)
        rbx.part(m, "Brazo", (x, y + 6.1, z), (1.6, 0.3, 0.3), LOG, "Wood", collide=False, query=False)
        g = rbx.part(m, "Farol", (x + 0.7, y + 5.4, z), (0.7, 1.0, 0.7), LANTERN if lit else (60, 50, 40), "Neon" if lit else "Glass",
                     collide=False, query=False, shadow=False)
        if lit:
            rbx.light(g, "PointLight", LANTERN, 1.3, 24)
            if self.rng.random() < 0.3:
                g.tags.append("LamparaInstalacion")
                g.attrs["Parpadeo"] = True
        return m

    def lights(self):
        lay, B, rng = self.lay, self.B, self.rng
        L = B.folder("Iluminacion")
        n = 0
        for s in lay.spaces:
            if not s.cells or self.indoor(s):
                continue
            for c in sorted(s.cells):
                l, x, z = c
                if c in s.void:
                    continue
                if s.kind in ("corridor", "catwalk") and (x * 3 + z * 5) % 7 == 0:
                    cx, cy, cz = B.cell_center(x, z, l)
                    side = rng.choice((-1, 1))
                    ax = self._axis(s, c)
                    off = (0, side * (C / 2 - 1.2)) if ax == "x" else (side * (C / 2 - 1.2), 0)
                    self.lantern_post(L, (cx + off[0], cy, cz + off[1]), lit=rng.random() < 0.75)
                    n += 1
        # Luciérnagas: puntos de luz verdosa flotando sobre los claros y senderos
        F = B.folder("Iluminacion/Luciernagas")
        cells = [c for c in lay.occ if c[0] == 0 and not self.indoor(lay.space_of(c)) and c not in lay.space_of(c).void]
        rng.shuffle(cells)
        for c in cells[:90]:
            cx, cy, cz = B.cell_center(c[1], c[2])
            f = rbx.part(F, "Luciernaga", (cx + rng.uniform(-5, 5), rng.uniform(2, 7), cz + rng.uniform(-5, 5)), (0.25, 0.25, 0.25),
                         (200, 255, 120), "Neon", shape="Ball", collide=False, query=False, shadow=False)
            if rng.random() < 0.3:
                rbx.light(f, "PointLight", (170, 255, 110), 0.5, 7)
        # Acople: focos de la esclusa
        hub = lay.hub
        x0, x1, z0, z1 = hub.rect(0)
        for sx in (x0, x1 + 1):
            self.lantern_post(L, (sx * C + (1 if sx == x0 else -1), 0, (z0 + 0.6) * C))
        sign = rbx.part(L, "SenalSegura", ((x0 + x1 + 1) / 2 * C, 10.2, z0 * C + 0.9), (8, 1.0, 0.3), (80, 255, 140), "Neon",
                        collide=False, query=False, shadow=False)
        rbx.light(sign, "PointLight", (90, 255, 150), 1.2, 22)
        self.light_count = n

    # ------------------------------------------------------------------ límites 2.5D
    def boundaries(self):
        """Anillos de árboles-silueta fuera del mapa, cada vez más oscuros: con la niebla parece un bosque infinito. Luna 2.5D."""
        B, lay, rng = self.B, self.lay, self.rng
        F = B.folder("Limites")
        W, Hh = lay.w * C, lay.h * C
        for ring, (dist, shade, scale, step) in enumerate(((24, 0.75, 1.1, 18), (70, 0.55, 1.4, 28), (140, 0.38, 1.9, 40))):
            per = 2 * (W + Hh + 4 * dist)
            k = 0.0
            while k < per:
                k += step * rng.uniform(0.7, 1.3)
                # recorre el rectángulo exterior
                t = k
                if t < W + 2 * dist:
                    x, z = -dist + t, -dist
                elif t < W + Hh + 4 * dist:
                    x, z = W + dist, -dist + (t - W - 2 * dist)
                elif t < 2 * W + Hh + 6 * dist:
                    x, z = W + dist - (t - W - Hh - 4 * dist), Hh + dist
                else:
                    x, z = -dist, Hh + dist - (t - 2 * W - Hh - 6 * dist)
                self.cutout_tree(F, x + rng.uniform(-6, 6), z + rng.uniform(-6, 6), shade, scale)
        moon = rbx.part(F, "Luna", (W * 0.5, 210, -520), (1, 120, 120), (220, 226, 236), "Neon", shape="Cylinder",
                        rot=rbx.rot_y(90), collide=False, query=False, shadow=False)
        moon.props["transparency"] = 0.15
        rbx.part(F, "Halo", (W * 0.5, 210, -526), (1, 220, 220), (90, 110, 130), "Neon", shape="Cylinder", rot=rbx.rot_y(90),
                 collide=False, query=False, shadow=False, transparency=0.85)

    def build(self):
        super().build()
        # Marcadores sobre colinas: subir los que caen encima
        for inst in self.B.root.iter():
            if inst.cls == "Part" and inst.children and inst.children[0].cls == "Attachment":
                x, y, z = inst.props["pos"]
                if y > 6:
                    continue
                for (hx, hz, R, hh) in self.hills:
                    d2 = (x - hx) ** 2 + (z - hz) ** 2
                    if d2 < R * R:
                        top = (hh - R) + math.sqrt(R * R - d2)
                        if top > y:
                            inst.props["pos"] = (x, top + 0.05, z)
        return self.B
