"""Level_1 · Complejo Fabril. Red de pasillos en raíz con dos plantas, naves de doble altura con pasarela, estilo plástico."""
from __future__ import annotations

import math
import random
from collections import deque

import rbx
from build import Builder, merge_rects
from common import Frame, against_wall, forced_corridor, grate, hide_volume, locker, marker, wall_slots, yaw_for
from layout import DIRS, Layout

C, H = 10.0, 14.0
T = 1.0  # grosor de muro
CEIL0 = 12.0
CEIL1 = H + 12.0
DOOR_W, DOOR_H = 6.0, 9.0

SECTOR_COLORS = [(64, 118, 122), (156, 118, 52), (146, 68, 58), (70, 88, 146), (84, 126, 72), (120, 80, 130)]
WALL_UP = (184, 176, 156)
CEIL = (60, 60, 64)
FLOOR = {"corridor": (92, 94, 98), "room": (128, 120, 104), "hall": (86, 88, 84), "hub": (132, 120, 92), "stair": (104, 104, 108),
         "catwalk": (118, 118, 112), "closet": (94, 88, 80), "shaft": (58, 58, 60)}
LAMP = (255, 236, 196)
ROOM_TYPES = [("Almacén", 3), ("Taller", 3), ("Vestuarios", 2), ("Calderas", 2), ("Oficina", 3), ("Control", 2),
              ("Laboratorio", 2), ("Enfermería", 1), ("Comedor", 1)]
HALL_TYPES = ["Nave de montaje", "Sala de turbinas", "Nave de prensas", "Nave de envasado"]
ROOM_FLOOR = {"Almacén": (118, 112, 96), "Taller": (110, 104, 92), "Vestuarios": (120, 134, 136), "Calderas": (104, 92, 84),
              "Oficina": (136, 124, 102), "Control": (90, 98, 110), "Laboratorio": (170, 176, 172), "Enfermería": (176, 180, 176),
              "Comedor": (150, 128, 100)}


def generate(seed: int) -> Layout:
    lay = Layout(84, 84, seed)
    lay.params.update(budget=2300, p_side=0.14, p_down=0.15, p_stairs=0.06)
    lay.place_hub()
    lay.grow()
    lay.prune()
    lay.add_loops()
    lay.prune()
    return lay


def sectors(lay: Layout) -> dict:
    """Sector de cada espacio = salida del vestíbulo por la que se llega antes (BFS multi-fuente). Se usa para el color del zócalo."""
    hub = lay.hub
    starts = []
    for k, v in lay.links.items():
        a, b = tuple(k)
        if a in hub.cells and b not in hub.cells and lay.space_of(b).kind != "shaft":
            starts.append(b)
        elif b in hub.cells and a not in hub.cells and lay.space_of(a).kind != "shaft":
            starts.append(a)
    starts.sort()
    owner = {}
    q = deque()
    for i, c in enumerate(starts):
        owner[c] = i % len(SECTOR_COLORS)
        q.append(c)
    while q:
        c = q.popleft()
        for n in lay.neighbors(c):
            if n not in owner and n not in hub.cells:
                owner[n] = owner[c]
                q.append(n)
    by_space = {}
    for c, sec in owner.items():
        sid = lay.occ.get(c)
        if sid is not None and sid not in by_space:
            by_space[sid] = sec
    return by_space


class Level1:
    CELL, LH, CEIL1 = C, H, CEIL1

    def __init__(self, seed=27):
        self.seed = seed
        self.rng = random.Random(seed * 7 + 1)
        self.lay = self.generate(seed)
        self.B = Builder(self.lay, self.CELL, self.LH, self.NAME)
        self.sector = sectors(self.lay)
        self.dist = self.lay.bfs(self.lay.hub_cell())
        self.labels = []
        self.puzzle_rooms = set()

    NAME = "Level_1"

    def generate(self, seed):
        return generate(seed)

    # ------------------------------------------------------------------ preparación
    def assign(self):
        rng = self.rng
        bag = [t for (t, w) in ROOM_TYPES for _ in range(w)]
        counts = {}
        for s in self.lay.spaces:
            if not s.cells:
                continue
            if s.kind == "room":
                t = rng.choice(bag)
                n = len([c for c in s.cells if c not in s.void])
                if n <= 6 and t in ("Comedor", "Calderas"):
                    t = "Oficina"
                counts[t] = counts.get(t, 0) + 1
                s.name = f"{t} {counts[t]}"
                s.data["type"] = t
            elif s.kind == "hall":
                t = rng.choice(HALL_TYPES)
                counts[t] = counts.get(t, 0) + 1
                s.name = f"{t} {counts[t]}"
                s.data["type"] = t
        # Puertas con puzzle: salas hoja alejadas del vestíbulo
        leaves = [(s, k) for (s, k) in self.lay.leaf_rooms() if min(self.dist.get(c, 0) for c in s.cells if c in self.dist) > 18]
        rng.shuffle(leaves)
        chosen = []
        for (s, k) in leaves:
            a, b = tuple(k)
            if a[0] != b[0]:
                continue
            if any(abs(a[1] - o[1]) + abs(a[2] - o[2]) < 20 for o in chosen):
                continue
            self.lay.links[k] = "puzzle"
            self.puzzle_rooms.add(s.sid)
            chosen.append(a)
            if len(chosen) >= 5:
                break

    def fake_corridors(self):
        """Fondos de saco con reja y pasillo falso en perspectiva forzada (límite del mapa que parece seguir)."""
        lay, B = self.lay, self.B
        out = []
        for s in lay.spaces:
            if s.kind != "corridor":
                continue
            for c in s.cells:
                l, x, z = c
                nb = list(lay.neighbors(c))
                if len(nb) != 1:
                    continue
                n0 = nb[0]
                d = next(i for i, (dx, dz) in enumerate(DIRS) if (x - dx, z - dz) == (n0[1], n0[2]))
                ok = True
                for k in range(1, 5):
                    for side in (-1, 0, 1):
                        sd = (d + 1) % 4
                        cx = x + DIRS[d][0] * k + DIRS[sd][0] * side
                        cz = z + DIRS[d][1] * k + DIRS[sd][1] * side
                        if (l, cx, cz) in lay.occ or not (0 <= cx < lay.w and 0 <= cz < lay.h):
                            ok = False
                if ok:
                    out.append((c, d))
        self.rng.shuffle(out)
        chosen = []
        for (c, d) in out:
            if any(abs(c[1] - o[0][1]) + abs(c[2] - o[0][2]) < 14 for o in chosen):
                continue
            chosen.append((c, d))
            n = (c[0], c[1] + DIRS[d][0], c[2] + DIRS[d][1])
            B.override[frozenset((c, n))] = "grate"
            if len(chosen) >= 14:
                break
        self.fakes = chosen

    # ------------------------------------------------------------------ estructura
    def floor_color(self, s):
        if s.kind == "room":
            return ROOM_FLOOR.get(s.data.get("type"), FLOOR["room"])
        return FLOOR.get(s.kind, (100, 100, 100))

    def structure(self):
        lay, B = self.lay, self.B
        S = B.folder("Estructura/Suelos")
        for s in lay.spaces:
            if not s.cells or s.kind == "stair":
                continue
            for l in (0, 1):
                cells = {(x, z) for (cl, x, z) in s.cells if cl == l and (cl, x, z) not in s.void}
                for (x0, x1, z0, z1) in merge_rects(cells):
                    X0, X1, Z0, Z1 = x0 * C, (x1 + 1) * C, z0 * C, (z1 + 1) * C
                    col = self.floor_color(s)
                    if l == 0:
                        name = "Platform" if s.kind == "hub" else "Suelo"
                        p = rbx.box(S if s.kind != "hub" else B.root, name, X0, X1, -1, 0, Z0, Z1, col)
                        if s.kind == "hub":
                            self.platform = p
                    elif s.kind == "catwalk":
                        rbx.box(S, "Pasarela", X0 + 1.2, X1 - 1.2, H - 0.6, H, Z0 + 1.2, Z1 - 1.2, col, "DiamondPlate")
                        if not (X1 - X0 > C + 1 and Z1 - Z0 > C + 1):
                            pass
                    else:
                        rbx.box(S, "Suelo", X0, X1, CEIL0 + 0.6, H, Z0, Z1, col)
        # La pasarela es más estrecha que la celda: bordes con chapa para que no quede hueco hasta la barandilla
        for s in lay.spaces:
            if s.kind != "catwalk":
                continue
            for (l, x, z) in s.cells:
                for d in range(4):
                    n = (l, x + DIRS[d][0], z + DIRS[d][1])
                    if n in s.cells:
                        cx, _, cz = B.cell_center(x, z)
                        ox, oz = DIRS[d][0] * (C / 2 - 0.6), DIRS[d][1] * (C / 2 - 0.6)
                        sz = (1.2, 0.6, C - 2.4) if DIRS[d][0] else (C - 2.4, 0.6, 1.2)
                        rbx.part(S, "Pasarela", (cx + ox, H - 0.3, cz + oz), sz, self.floor_color(s), "DiamondPlate")
                    elif B.classify((l, x, z), n) in ("rail", "wall", "door", "puzzle") or lay.link_kind((l, x, z), n):
                        cx, _, cz = B.cell_center(x, z)
                        ox, oz = DIRS[d][0] * (C / 2 - 0.6), DIRS[d][1] * (C / 2 - 0.6)
                        sz = (1.2, 0.6, C) if DIRS[d][0] else (C, 0.6, 1.2)
                        rbx.part(S, "Pasarela", (cx + ox, H - 0.3, cz + oz), sz, self.floor_color(s), "DiamondPlate")
                # vigas bajo la pasarela
                cx, _, cz = B.cell_center(x, z)
                rbx.part(S, "Viga", (cx, H - 1.0, cz), (C, 0.8, 0.8) if self._axis(s, (l, x, z)) == "x" else (0.8, 0.8, C),
                         (70, 72, 70), "Metal")
        # Techos
        R = B.folder("Estructura/Techos")
        ceil0 = set()
        for (l, x, z), sid in lay.occ.items():
            s = lay.spaces[sid]
            if l != 0 or (l, x, z) in s.void:
                continue
            up = (1, x, z)
            us = lay.space_of(up)
            if us is not None and up in us.void:
                continue
            if us is not None and us.kind == "catwalk":
                continue
            ceil0.add((x, z))
        for (x0, x1, z0, z1) in merge_rects(ceil0):
            rbx.box(R, "Techo", x0 * C, (x1 + 1) * C, CEIL0, CEIL0 + 0.6, z0 * C, (z1 + 1) * C, CEIL, shadow=False)
        ceil1 = {(x, z) for (l, x, z) in lay.occ if l == 1}
        for (x0, x1, z0, z1) in merge_rects(ceil1):
            rbx.box(R, "Techo", x0 * C, (x1 + 1) * C, CEIL1, CEIL1 + 1, z0 * C, (z1 + 1) * C, CEIL, shadow=False)
        # Muros
        W = B.folder("Estructura/Muros")
        for l in (0, 1):
            y0 = l * H
            y1 = H if l == 0 else CEIL1 + 1
            for (axis, line, a0, a1, color, segs) in B.wall_runs(l, self.wall_key):
                B.wall_box(W, "Zocalo", axis, line, a0 - T / 2, a1 + T / 2, y0, y0 + 3.6, T + 0.1, color)
                B.wall_box(W, "Muro", axis, line, a0 - T / 2, a1 + T / 2, y0 + 3.6, y1, T, WALL_UP)
        # Puertas, rejas y barandillas
        D = B.folder("Estructura/Vanos")
        for l in (0, 1):
            y0 = l * H
            y1 = H if l == 0 else CEIL1 + 1
            for (t, axis, line, a0, a1, ca, cb) in B.edges(l):
                if t in ("door", "puzzle"):
                    col = self.wall_key(ca, cb)
                    mid = (a0 + a1) / 2
                    B.wall_box(D, "Zocalo", axis, line, a0 - T / 2, mid - DOOR_W / 2, y0, y0 + 3.6, T + 0.1, col)
                    B.wall_box(D, "Zocalo", axis, line, mid + DOOR_W / 2, a1 + T / 2, y0, y0 + 3.6, T + 0.1, col)
                    B.doorway(D, "Vano", axis, line, a0 - T / 2, a1 + T / 2, y0 + 3.6, y1, T, DOOR_W, DOOR_H - 3.6, WALL_UP)
                    for sgn in (-1, 1):
                        a = mid + sgn * (DOOR_W / 2 + 0.2)
                        B.wall_box(D, "Marco", axis, line, a - 0.2, a + 0.2, y0, y0 + DOOR_H, T + 0.3, (220, 176, 40))
                    B.wall_box(D, "Marco", axis, line, mid - DOOR_W / 2 - 0.4, mid + DOOR_W / 2 + 0.4, y0 + DOOR_H, y0 + DOOR_H + 0.4,
                               T + 0.3, (220, 176, 40))
                    if t == "puzzle":
                        self.door_markers.append((axis, line, mid, y0, ca, cb))
                elif t == "rail":
                    self.rail(D, l, axis, line, a0, a1, ca, cb)
                elif t == "grate":
                    grate(B, D, axis, line, a0, a1, y0, y0 + CEIL0)
                    B.wall_box(D, "Muro", axis, line, a0 - T / 2, a1 + T / 2, y0 + CEIL0, y1, T, WALL_UP)
        # Escaleras
        E = B.folder("Estructura/Escaleras")
        for st in lay.stairs:
            sp = lay.spaces[st["sid"]]
            m = rbx.model(E, sp.name.replace(" ", ""))
            B.stair_steps(m, st, C - T, FLOOR["stair"], steps=14)
            # banda amarilla en el borde de cada tramo
            cx0, cz0, dx, dz, run = B.stair_steps(m, st, 0.3, (220, 176, 40), steps=14, prefix="Borde") if False else (0, 0, 0, 0, 0)

    def _axis(self, s, c):
        l, x, z = c
        if (l, x + 1, z) in s.cells or (l, x - 1, z) in s.cells:
            return "x"
        return "z"

    def wall_key(self, ca, cb):
        lay = self.lay
        for c in (ca, cb):
            s = lay.space_of(c)
            if s is not None and s.kind not in ("shaft",):
                sec = self.sector.get(s.sid)
                if s.kind == "hub":
                    return (96, 90, 70)
                if sec is not None:
                    return tuple(int(v * 0.85) for v in SECTOR_COLORS[sec])
        return (70, 72, 74)

    def rail(self, parent, l, axis, line, a0, a1, ca, cb):
        lay, B = self.lay, self.B
        sa, sb = lay.space_of(ca), lay.space_of(cb)
        stair = sa if sa and sa.kind == "stair" else (sb if sb and sb.kind == "stair" else None)
        if stair and l == 0:
            c = ca if sa is stair else cb
            st = stair.data
            i = st["cells"].index((c[1], c[2]))
            top = (i + 1) * H / 3 if st["high_end"] == 2 else (3 - i) * H / 3
            B.wall_box(parent, "Pretil", axis, line, a0, a1, 0, top + 3.2, 0.8, (150, 146, 136))
            B.wall_box(parent, "Pasamanos", axis, line, a0, a1, top + 3.2, top + 3.5, 1.0, (220, 176, 40))
            return
        y = l * H
        m = rbx.model(parent, "Barandilla")
        B.wall_box(m, "Pasamanos", axis, line, a0, a1, y + 3.3, y + 3.6, 0.35, (220, 176, 40), "Metal", collide=False)
        B.wall_box(m, "Barra", axis, line, a0, a1, y + 1.8, y + 2.0, 0.2, (90, 92, 90), "Metal", collide=False)
        B.wall_box(m, "Rodapie", axis, line, a0, a1, y, y + 0.5, 0.2, (90, 92, 90), "Metal", collide=False)
        for a in (a0 + 0.3, (a0 + a1) / 2, a1 - 0.3):
            B.wall_box(m, "Poste", axis, line, a - 0.15, a + 0.15, y, y + 3.6, 0.3, (90, 92, 90), "Metal", collide=False)
        B.wall_box(m, "Colision", axis, line, a0, a1, y, y + 4.2, 0.4, (0, 0, 0), transparency=1, shadow=False)

    # ------------------------------------------------------------------ luces
    def lamp(self, parent, pos, axis, ceil_y, length=4.0, rng_light=20.0, bright=1.1):
        r = self.rng.random()
        m = rbx.model(parent, "Fluorescente")
        sx, sz = (length, 1.0) if axis == "x" else (1.0, length)
        rbx.part(m, "Carcasa", (pos[0], ceil_y - 0.2, pos[2]), (sx, 0.35, sz), (200, 200, 196), collide=False, query=False, shadow=False)
        dead = r < 0.12
        tube = rbx.part(m, "Tubo", (pos[0], ceil_y - 0.42, pos[2]), (sx * 0.9, 0.12, sz * 0.5),
                        (120, 120, 116) if dead else LAMP, "SmoothPlastic" if dead else "Neon", collide=False, query=False, shadow=False)
        if not dead:
            rbx.light(tube, "PointLight", LAMP, bright, rng_light)
            if r < 0.34:
                tube.tags.append("LamparaInstalacion")
                tube.attrs["Parpadeo"] = True
        return m

    def lights(self):
        lay, B = self.lay, self.B
        L = B.folder("Iluminacion")
        n = 0
        for s in lay.spaces:
            if not s.cells:
                continue
            for c in sorted(s.cells):
                l, x, z = c
                if c in s.void:
                    continue
                ceil = CEIL0 if l == 0 else CEIL1
                cx, _, cz = B.cell_center(x, z, l)
                if s.kind == "corridor" and (x + z) % 4 == 0:
                    self.lamp(L, (cx, 0, cz), self._axis(s, c), ceil)
                    n += 1
                elif s.kind in ("room", "hub", "closet") and x % 3 == 1 and z % 3 == 1:
                    self.lamp(L, (cx, 0, cz), "x", ceil, length=5, rng_light=26, bright=1.2)
                    n += 1
                elif s.kind == "catwalk" and (x + z) % 3 == 0:
                    lp = rbx.part(L, "LuzPasarela", (cx, H + 3.6, cz), (0.6, 0.6, 0.6), (255, 190, 110), "Neon", collide=False,
                                  query=False, shadow=False)
                    rbx.light(lp, "PointLight", (255, 190, 110), 0.9, 16)
            if s.kind == "hall":
                for (l, x, z) in s.cells:
                    if l == 0 and x % 2 == 0 and z % 2 == 0 and (1, x, z) in s.void:
                        cx, _, cz = B.cell_center(x, z)
                        m = rbx.model(L, "LamparaColgante")
                        rbx.part(m, "Cable", (cx, CEIL1 - 2, cz), (0.15, 4, 0.15), (30, 30, 30), collide=False, query=False)
                        rbx.part(m, "Campana", (cx, CEIL1 - 4.3, cz), (2.6, 0.8, 2.6), (60, 64, 60), "Metal", collide=False, query=False)
                        bulb = rbx.part(m, "Foco", (cx, CEIL1 - 4.9, cz), (1.0, 0.4, 1.0), (255, 214, 150), "Neon", collide=False,
                                        query=False, shadow=False)
                        sp = rbx.light(bulb, "SpotLight", (255, 214, 150), 2.2, 40, face="Bottom", angle=70, shadows=True)
                        if self.rng.random() < 0.25:
                            bulb.tags.append("LamparaInstalacion")
                            bulb.attrs["Parpadeo"] = True
                        n += 1
            if s.kind == "stair":
                st = s.data
                mx, mz = st["cells"][1]
                cx, _, cz = B.cell_center(mx, mz)
                lp = rbx.part(L, "LuzEscalera", (cx, CEIL1 - 0.4, cz), (1.6, 0.2, 1.6), LAMP, "Neon", collide=False, query=False,
                              shadow=False)
                rbx.light(lp, "PointLight", LAMP, 1.0, 22)
                n += 1
        # Vestíbulo: luz verde de zona segura sobre la boca del ascensor
        hub = lay.hub
        x0, x1, z0, z1 = hub.rect(0)
        sign = rbx.part(L, "SenalSegura", ((x0 + x1 + 1) / 2 * C, 10.2, z0 * C + 0.7), (8, 1.0, 0.3), (80, 255, 140), "Neon",
                        collide=False, query=False, shadow=False)
        rbx.light(sign, "PointLight", (90, 255, 150), 1.2, 22)
        self.light_count = n

    # ------------------------------------------------------------------ decoración
    def pipes(self):
        lay, B = self.lay, self.B
        P = B.folder("Decoracion/Tuberias")
        rng = self.rng
        for s in lay.spaces:
            if s.kind != "corridor" or len(s.cells) < 4:
                continue
            for axis in ("x", "z"):
                lines = {}
                for (l, x, z) in s.cells:
                    key = (l, z) if axis == "x" else (l, x)
                    lines.setdefault(key, []).append(x if axis == "x" else z)
                for (l, k), vals in lines.items():
                    vals.sort()
                    run = [vals[0]]
                    for v in vals[1:] + [None]:
                        if v is not None and v == run[-1] + 1:
                            run.append(v)
                            continue
                        if len(run) >= 3 and rng.random() < 0.75:
                            a0, a1 = run[0] * C, (run[-1] + 1) * C
                            side = rng.choice((-1, 1))
                            off = (k + 0.5) * C + side * (C / 2 - 1.4)
                            ceil = CEIL0 if l == 0 else CEIL1
                            col = rng.choice([(150, 70, 52), (70, 110, 130), (120, 120, 112), (160, 140, 60)])
                            for j, (dia, yy, oo) in enumerate(((1.1, ceil - 1.0, 0), (0.6, ceil - 2.1, -side * 0.9))):
                                if j == 1 and rng.random() < 0.5:
                                    continue
                                if axis == "x":
                                    rbx.part(P, "Tubo", ((a0 + a1) / 2, yy, off + oo), (a1 - a0, dia, dia), col, shape="Cylinder",
                                             collide=False, query=False)
                                else:
                                    rbx.part(P, "Tubo", (off + oo, yy, (a0 + a1) / 2), (a1 - a0, dia, dia), col, shape="Cylinder",
                                             rot=rbx.rot_y(90), collide=False, query=False)
                            # abrazaderas
                            for a in range(int(a0) + 5, int(a1), 10):
                                pos = (a, ceil - 0.5, off) if axis == "x" else (off, ceil - 0.5, a)
                                rbx.part(P, "Soporte", pos, (0.3, 1.0, 0.3), (60, 60, 60), collide=False, query=False)
                        run = [v] if v is not None else []

    def decor(self):
        lay, B = self.lay, self.B
        rng = self.rng
        Dfold = B.folder("Decoracion")
        self.locker_n = 0
        for s in lay.spaces:
            if not s.cells:
                continue
            t = s.data.get("type")
            m = rbx.folder(Dfold, (s.name or s.kind).replace(" ", "_"))
            slots = wall_slots(B, s)
            rng.shuffle(slots)
            if s.kind == "room":
                getattr(self, "room_" + _ident(t))(m, s, slots)
            elif s.kind == "hall":
                self.hall(m, s, slots)
            elif s.kind == "closet":
                for (c, d) in slots[:2]:
                    fr = against_wall(B, c, d, 2.8)
                    self.place_locker(m, fr, c)
            elif s.kind == "corridor":
                self.corridor_props(m, s, slots)
        self.pipes()
        # Relieves 2.5D en la parte alta de las naves: maquinaria pintada en el muro (casi sin coste)
        for s in lay.spaces:
            if s.kind == "hall":
                self.hall_relief(B.folder("Decoracion/Relieves"), s)

    def place_locker(self, parent, fr, c, hideable=True):
        x0, z0 = fr.w(-1.7, 0, -1.6), fr.w(1.7, 0, 1.6)
        if not self.B.free_spot(min(x0[0], z0[0]), max(x0[0], z0[0]), min(x0[2], z0[2]), max(x0[2], z0[2]), c[0]):
            return False
        self.locker_n += 1
        locker(self.B, parent, fr, self.locker_n, hideable=hideable)
        self.B.block(x0[0], z0[0], x0[2], z0[2], c[0])
        return True

    def take(self, fr, w, dep, l):
        a, b = fr.w(-w / 2, 0, -dep / 2), fr.w(w / 2, 0, dep / 2)
        x0, x1, z0, z1 = min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2])
        if not self.B.free_spot(x0, x1, z0, z1, l, pad=0.3):
            return False
        self.B.block(x0, x1, z0, z1, l)
        return True

    # Muebles (marco: X a lo largo del muro, +Z hacia el muro, y = suelo)
    def shelf(self, p, fr, l):
        if not self.take(fr, 8, 2.6, l):
            return
        m = rbx.model(p, "Estanteria")
        for sx in (-3.8, 3.8):
            for sz in (-1.1, 1.1):
                fr.part(m, "Poste", (sx, 4.5, sz), (0.3, 9, 0.3), (60, 90, 140), "Metal")
        for i, y in enumerate((0.5, 3.2, 5.9, 8.6)):
            fr.part(m, "Balda", (0, y, 0), (8, 0.25, 2.5), (200, 120, 40) if i % 2 else (190, 190, 180))
            if y < 8:
                xx = -3.2
                while xx < 3.0:
                    w = self.rng.uniform(0.9, 2.0)
                    h = self.rng.uniform(0.8, 2.2)
                    if self.rng.random() < 0.75:
                        col = self.rng.choice([(170, 130, 80), (150, 112, 70), (90, 120, 160), (180, 70, 60), (200, 190, 160)])
                        fr.part(m, "Caja", (xx + w / 2, y + 0.12 + h / 2, self.rng.uniform(-0.2, 0.2)), (w, h, 1.8), col,
                                collide=False)
                    xx += w + 0.2

    def bench(self, p, fr, l):
        if not self.take(fr, 7, 3, l):
            return None
        m = rbx.model(p, "BancoTrabajo")
        fr.part(m, "Tablero", (0, 3.2, 0), (7, 0.4, 3), (150, 106, 64))
        for sx in (-3.2, 3.2):
            for sz in (-1.2, 1.2):
                fr.part(m, "Pata", (sx, 1.5, sz), (0.35, 3, 0.35), (60, 64, 70), "Metal")
        fr.part(m, "Balda", (0, 0.8, 0), (6.6, 0.2, 2.6), (80, 84, 88), "Metal")
        fr.part(m, "Panel", (0, 6, 1.4), (7, 5, 0.2), (196, 170, 110))
        for i in range(5):
            fr.part(m, "Herramienta", (-2.6 + i * 1.3, 6 + self.rng.uniform(-0.8, 0.8), 1.25), (0.25, 1.6, 0.1),
                    self.rng.choice([(200, 40, 40), (40, 40, 40), (210, 170, 40)]), collide=False)
        fr.part(m, "Torno", (2.4, 3.8, -0.6), (1.0, 0.8, 0.8), (40, 70, 140), "Metal", collide=False)
        fr.part(m, "CajaHerramientas", (-2.2, 3.85, 0), (1.8, 0.9, 1.0), (200, 40, 40), collide=False)
        return fr.w(0.5, 3.4, -0.3)

    def desk(self, p, fr, l):
        if not self.take(fr, 6, 3, l):
            return None
        m = rbx.model(p, "Escritorio")
        fr.part(m, "Tablero", (0, 3.0, 0), (6, 0.3, 3), (176, 150, 112))
        fr.part(m, "Cajonera", (2.2, 1.4, 0), (1.6, 2.8, 2.8), (130, 130, 126))
        fr.part(m, "Pata", (-2.8, 1.4, 0), (0.3, 2.8, 2.8), (130, 130, 126))
        fr.part(m, "Monitor", (-0.5, 4.2, 0.6), (2.4, 1.6, 0.3), (40, 40, 44), collide=False)
        fr.part(m, "Pantalla", (-0.5, 4.2, 0.44), (2.1, 1.3, 0.05), self.rng.choice([(60, 110, 90), (40, 60, 90), (20, 20, 22)]),
                "Neon", collide=False, shadow=False)
        fr.part(m, "Silla", (0, 1.8, -2.4), (1.8, 0.4, 1.8), (50, 54, 60), collide=False)
        fr.part(m, "Respaldo", (0, 3.0, -3.2), (1.8, 2.2, 0.3), (50, 54, 60), collide=False)
        for i in range(self.rng.randint(0, 3)):
            fr.part(m, "Papel", (self.rng.uniform(-2.5, 1), 3.17, self.rng.uniform(-1, 1)), (0.9, 0.04, 1.2), (236, 232, 220),
                    collide=False, shadow=False, lrot=rbx.rot_y(self.rng.uniform(-30, 30)))
        return fr.w(1.6, 3.15, -0.6)

    def cabinet(self, p, fr, l):
        if not self.take(fr, 2.4, 2.4, l):
            return
        m = rbx.model(p, "Archivador")
        fr.part(m, "Cuerpo", (0, 2.6, 0), (2.2, 5.2, 2.2), (120, 128, 120))
        for i in range(4):
            fr.part(m, "Cajon", (0, 0.8 + i * 1.2, -1.12), (1.9, 1.0, 0.06), (140, 150, 140), collide=False)
            fr.part(m, "Tirador", (0, 0.8 + i * 1.2, -1.18), (0.6, 0.12, 0.08), (200, 200, 190), "Metal", collide=False)

    def boiler(self, p, fr, l):
        if not self.take(fr, 6.5, 6.5, l):
            return
        m = rbx.model(p, "Caldera")
        rbx.cylinder_y(m, "Cuerpo", fr.w(0, 5, 0), 9, 6, (150, 72, 54))
        rbx.cylinder_y(m, "Tapa", fr.w(0, 9.7, 0), 0.6, 6.4, (90, 90, 90), "Metal")
        rbx.cylinder_y(m, "Base", fr.w(0, 0.4, 0), 0.8, 6.6, (70, 70, 70), "Metal")
        fr.part(m, "Manometro", (0, 6, -3.05), (1.1, 1.1, 0.2), (230, 230, 220), collide=False)
        fr.part(m, "Aguja", (0.15, 6.1, -3.17), (0.08, 0.5, 0.05), (200, 30, 30), collide=False, lrot=rbx.rot_z(30))
        g = fr.part(m, "Piloto", (1.3, 3, -3.0), (0.4, 0.4, 0.2), (255, 120, 40), "Neon", collide=False, shadow=False)
        rbx.light(g, "PointLight", (255, 120, 40), 0.8, 10)
        fr.part(m, "Chimenea", (0, 11, 0.8), (1.2, 2.5, 1.2), (80, 80, 80), "Metal", collide=False)

    def console(self, p, fr, l):
        if not self.take(fr, 7, 3, l):
            return
        m = rbx.model(p, "Consola")
        fr.part(m, "Base", (0, 1.6, 0.2), (7, 3.2, 2.6), (90, 96, 104))
        fr.part(m, "Pupitre", (0, 3.5, -0.2), (7, 0.4, 2.4), (70, 74, 82), lrot=rbx.rot_x(-18))
        for i in range(10):
            col = self.rng.choice([(255, 60, 50), (60, 255, 120), (255, 200, 40), (60, 160, 255)])
            fr.part(m, "Boton", (-3 + (i % 5) * 1.5, 3.75, -0.8 + (i // 5) * 0.8), (0.35, 0.12, 0.35), col, "Neon",
                    collide=False, shadow=False, lrot=rbx.rot_x(-18))
        for i, x in enumerate((-2.3, 0, 2.3)):
            fr.part(m, "Monitor", (x, 6.2, 1.1), (2.1, 1.7, 0.4), (36, 38, 42), collide=False)
            scr = fr.part(m, "Pantalla", (x, 6.2, 0.88), (1.8, 1.4, 0.05), (40, 120, 90), "Neon", collide=False, shadow=False)
            if i == 1:
                rbx.light(scr, "PointLight", (60, 200, 140), 0.6, 10)

    def tank(self, p, fr, l):
        if not self.take(fr, 4.5, 4.5, l):
            return
        m = rbx.model(p, "Tanque")
        rbx.cylinder_y(m, "Base", fr.w(0, 0.5, 0), 1.0, 4.4, (90, 96, 100), "Metal")
        rbx.cylinder_y(m, "Liquido", fr.w(0, 4, 0), 5.6, 3.4, self.rng.choice([(90, 220, 120), (90, 190, 230), (230, 160, 60)]),
                       "Neon", collide=False, transparency=0.25, shadow=False)
        rbx.cylinder_y(m, "Vidrio", fr.w(0, 4, 0), 6.0, 4.0, (200, 230, 240), "Glass", transparency=0.6)
        rbx.cylinder_y(m, "Tapa", fr.w(0, 7.3, 0), 0.8, 4.4, (90, 96, 100), "Metal")

    def crates(self, p, fr, l, small=False):
        """Palé con cajas. small: versión plana (fondo 2.4) para pasillos, que deja paso a las criaturas (radio 2)."""
        dep = 2.4 if small else 4
        if not self.take(fr, 5, dep, l):
            return
        m = rbx.model(p, "Cajas")
        fr.part(m, "Palet", (0, 0.3, 0), (5, 0.6, dep), (160, 120, 70))
        h = 0.6
        for i in range(self.rng.randint(1, 3)):
            w = self.rng.uniform(2.5, 4.5)
            hh = self.rng.uniform(1.8, 3.0)
            fr.part(m, "Caja", (self.rng.uniform(-0.4, 0.4), h + hh / 2, 0), (w, hh, self.rng.uniform(1.6, 2.2) if small else self.rng.uniform(2.4, 3.6)),
                    self.rng.choice([(170, 130, 80), (140, 104, 64), (190, 160, 110)]), lrot=rbx.rot_y(self.rng.uniform(-8, 8)))
            h += hh

    def bed(self, p, fr, l):
        if not self.take(fr, 3.6, 7, l):
            return
        m = rbx.model(p, "Camilla")
        fr.part(m, "Somier", (0, 2.0, -0.4), (3.4, 0.4, 6.6), (190, 190, 190), "Metal")
        fr.part(m, "Colchon", (0, 2.5, -0.4), (3.2, 0.6, 6.4), (220, 226, 230))
        fr.part(m, "Almohada", (0, 3.0, 2.2), (2.4, 0.5, 1.2), (240, 240, 240), collide=False)
        for sx in (-1.5, 1.5):
            for sz in (-3.4, 2.6):
                fr.part(m, "Pata", (sx, 1.0, sz), (0.25, 2, 0.25), (160, 160, 160), "Metal", collide=False)
        fr.part(m, "Cortina", (2.3, 4.5, -0.4), (0.1, 6.6, 6.8), (150, 190, 180), "Fabric", collide=False, transparency=0.1)

    def table(self, p, center, l, w=7, d=3.5):
        x, y, z = center
        if not self.B.free_spot(x - w / 2 - 2, x + w / 2 + 2, z - d / 2 - 2, z + d / 2 + 2, l):
            return None
        self.B.block(x - w / 2 - 1.6, x + w / 2 + 1.6, z - d / 2 - 1.6, z + d / 2 + 1.6, l)
        m = rbx.model(p, "Mesa")
        rbx.part(m, "Tablero", (x, y + 3, z), (w, 0.3, d), (196, 180, 150))
        for sx in (-w / 2 + 0.4, w / 2 - 0.4):
            for sz in (-d / 2 + 0.4, d / 2 - 0.4):
                rbx.part(m, "Pata", (x + sx, y + 1.5, z + sz), (0.3, 3, 0.3), (90, 90, 90), "Metal")
        for sz in (-d / 2 - 1.1, d / 2 + 1.1):
            rbx.part(m, "Banco", (x, y + 1.6, z + sz), (w, 0.3, 1.1), (140, 90, 60), collide=False)
        return (x, y + 3.15, z)

    # Salas
    def _fill(self, p, s, slots, fns, count):
        tops = []
        for (c, d) in slots[:count]:
            fn = self.rng.choice(fns)
            dep = {"shelf": 2.6, "bench": 3, "desk": 3, "cabinet": 2.4, "boiler": 6.5, "console": 3, "tank": 4.5, "crates": 4,
                   "bed": 7}[fn]
            fr = against_wall(self.B, c, d, dep)
            r = getattr(self, fn)(p, fr, c[0])
            if r:
                tops.append(r)
        return tops

    def room_almacen(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["shelf", "shelf", "crates"], len(slots) // 2 + 1)

    def room_taller(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["bench", "bench", "crates", "cabinet"], len(slots) // 2 + 1)

    def room_vestuarios(self, p, s, slots):
        n = 0
        for (c, d) in slots:
            for off in (-3.4, 0, 3.4):
                fr = against_wall(self.B, c, d, 2.8)
                dx, dz = DIRS[(d + 1) % 4]
                fr.pos = (fr.pos[0] + dx * off, fr.pos[1], fr.pos[2] + dz * off)
                if self.place_locker(p, fr, c, hideable=(n % 2 == 0)):
                    n += 1
            if n >= 9:
                break
        cells = [c for c in s.cells if c not in s.void and c not in self.B.door_cells]
        if cells:
            l, x, z = self.rng.choice(cells)
            cx, cy, cz = self.B.cell_center(x, z, l)
            if self.B.free_spot(cx - 3.5, cx + 3.5, cz - 1, cz + 1, l):
                rbx.part(p, "Banco", (cx, cy + 1.4, cz), (7, 0.4, 1.4), (150, 110, 70))
                self.B.block(cx - 3.5, cx + 3.5, cz - 1, cz + 1, l)
        self.tops = []

    def room_calderas(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["boiler", "boiler", "crates"], len(slots) // 2 + 1)

    def room_oficina(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["desk", "desk", "cabinet", "shelf"], len(slots) // 2 + 1)

    def room_control(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["console", "console", "cabinet"], len(slots) // 2 + 1)

    def room_laboratorio(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["tank", "bench", "tank", "cabinet"], len(slots) // 2 + 1)

    def room_enfermeria(self, p, s, slots):
        self.tops = self._fill(p, s, slots, ["bed", "bed", "cabinet"], len(slots) // 2 + 1)

    def room_comedor(self, p, s, slots):
        self.tops = []
        for c in sorted(s.cells):
            l, x, z = c
            if c in s.void or c in self.B.door_cells:
                continue
            if x % 2 == 0 and z % 2 == 1:
                r = self.table(p, self.B.cell_center(x, z, l), l)
                if r:
                    self.tops.append(r)
        self._fill(p, s, slots, ["cabinet", "crates"], 3)

    def hall(self, p, s, slots):
        B = self.B
        t = s.data.get("type", "")
        x0, x1, z0, z1 = s.rect(0)
        cells = [c for c in s.cells if c[0] == 0 and c not in s.void and c not in B.door_cells]
        # bloquea pie de la escalera interior
        cw = s.data.get("catwalk")
        for st in self.lay.stairs:
            if st.get("inner") and self.lay.spaces[st["sid"]].cells and any((0, a, b) in self.lay.spaces[st["sid"]].cells for (a, b) in st["cells"]):
                fx, fz = st["cells"][0]
                d = st["dir"]
                bx, bz = fx - DIRS[d][0], fz - DIRS[d][1]
                if (0, bx, bz) in s.cells:
                    cx, _, cz = B.cell_center(bx, bz)
                    B.block(cx - 4, cx + 4, cz - 4, cz + 4, 0)
        self._fill(p, s, slots, ["crates", "shelf", "crates", "cabinet"], len(slots) // 3 + 2)
        rng = self.rng
        if "turbinas" in t:
            for (l, x, z) in cells:
                if (x - x0) % 3 == 1 and (z - z0) % 4 == 1 and z + 1 <= z1:
                    cx, _, cz = B.cell_center(x, z)
                    if not B.free_spot(cx - 4, cx + 4, cz - 2, cz + 12, 0):
                        continue
                    B.block(cx - 4, cx + 4, cz - 2, cz + 12, 0)
                    m = rbx.model(p, "Turbina")
                    rbx.part(m, "Carcasa", (cx, 4, cz + 5), (12, 7, 7), (70, 110, 130), shape="Cylinder", rot=rbx.rot_y(90))
                    rbx.part(m, "Brida", (cx, 4, cz - 1.2), (0.8, 8, 8), (90, 90, 96), "Metal", shape="Cylinder", rot=rbx.rot_y(90))
                    rbx.box(m, "Bancada", cx - 3.4, cx + 3.4, 0, 1.2, cz - 1.5, cz + 11.5, (80, 82, 84), "Metal")
                    g = rbx.part(m, "Indicador", (cx + 3.6, 4, cz + 5), (0.2, 1, 1), (80, 255, 120), "Neon", collide=False, shadow=False)
                    rbx.light(g, "PointLight", (80, 255, 120), 0.5, 8)
        else:
            # cintas transportadoras a lo largo de la nave con cajas encima
            horizontal = (x1 - x0) >= (z1 - z0)
            lanes = range(z0 + 1, z1, 3) if horizontal else range(x0 + 1, x1, 3)
            for lane in lanes:
                a0 = (x0 + 1) * C if horizontal else (z0 + 1) * C
                a1 = x1 * C if horizontal else z1 * C
                mid = (lane + 0.5) * C
                if horizontal:
                    fx0, fx1, fz0, fz1 = a0, a1, mid - 1.8, mid + 1.8
                else:
                    fx0, fx1, fz0, fz1 = mid - 1.8, mid + 1.8, a0, a1
                if not B.free_spot(fx0, fx1, fz0, fz1, 0, pad=1.0):
                    continue
                B.block(fx0, fx1, fz0, fz1, 0)
                m = rbx.model(p, "Cinta")
                rbx.box(m, "Bastidor", fx0, fx1, 0, 2.8, fz0, fz1, (64, 70, 74), "Metal")
                rbx.box(m, "Banda", fx0, fx1, 2.8, 3.1, fz0 + 0.3, fz1 - 0.3, (34, 34, 36))
                L = (a1 - a0)
                k = 0
                while k < L - 3:
                    k += rng.uniform(3, 7)
                    pos = (a0 + k, 0, mid) if horizontal else (mid, 0, a0 + k)
                    sz = rng.uniform(1.6, 2.6)
                    rbx.part(m, "Caja", (pos[0], 3.1 + sz / 2, pos[2]), (sz, sz, sz), rng.choice([(170, 130, 80), (200, 180, 140)]),
                             collide=False, rot=rbx.rot_y(rng.uniform(-10, 10)))
            # máquina grande en una esquina libre
            for (l, x, z) in cells:
                cx, _, cz = B.cell_center(x, z)
                if B.free_spot(cx - 5, cx + 5, cz - 5, cz + 5, 0, pad=1.0):
                    B.block(cx - 5, cx + 5, cz - 5, cz + 5, 0)
                    m = rbx.model(p, "Prensa")
                    rbx.box(m, "Base", cx - 4.5, cx + 4.5, 0, 2, cz - 4.5, cz + 4.5, (90, 94, 98), "Metal")
                    for sx in (-3.6, 3.6):
                        rbx.box(m, "Columna", cx + sx - 0.6, cx + sx + 0.6, 2, 11, cz - 0.6, cz + 0.6, (200, 150, 40))
                    rbx.box(m, "Cabezal", cx - 4.5, cx + 4.5, 9, 11.5, cz - 2, cz + 2, (200, 150, 40))
                    rbx.box(m, "Martillo", cx - 2.5, cx + 2.5, 5, 9, cz - 1.5, cz + 1.5, (110, 110, 116), "Metal")
                    g = rbx.part(m, "Baliza", (cx, 12, cz), (0.8, 0.8, 0.8), (255, 140, 30), "Neon", shape="Ball", collide=False)
                    rbx.light(g, "PointLight", (255, 140, 30), 1.0, 18)
                    break
        # Puente grúa: viga a 22 studs de lado a lado (la ven desde la pasarela)
        if (x1 - x0) >= (z1 - z0):
            zz = ((z0 + z1 + 1) / 2) * C
            rbx.box(p, "PuenteGrua", x0 * C, (x1 + 1) * C, 22, 23.4, zz - 0.8, zz + 0.8, (220, 170, 40), "Metal", collide=False, query=False)
            rbx.box(p, "Gancho", x0 * C + 14, x0 * C + 15, 15, 22, zz - 0.15, zz + 0.15, (40, 40, 40), collide=False, query=False)
        else:
            xx = ((x0 + x1 + 1) / 2) * C
            rbx.box(p, "PuenteGrua", xx - 0.8, xx + 0.8, 22, 23.4, z0 * C, (z1 + 1) * C, (220, 170, 40), "Metal", collide=False, query=False)

    def hall_relief(self, parent, s):
        """Maquinaria en relieve plano sobre los muros altos de la nave (2.5D): siluetas de depósitos y tubos de órgano."""
        B, rng = self.B, self.rng
        for (t, axis, line, a0, a1, ca, cb) in B.edges(1):
            if t != "wall":
                continue
            inside = ca if ca in s.void else (cb if cb in s.void else None)
            if inside is None:
                continue
            sgn = 1 if (inside == cb) else -1  # lado del muro que mira a la nave
            off = sgn * (T / 2 + 0.15)
            kw = dict(collide=False, query=False, shadow=False)
            if rng.random() < 0.5:
                h = rng.uniform(6, 11)
                col = rng.choice([(70, 96, 104), (104, 80, 66), (88, 92, 86)])
                for k in range(3):
                    a = a0 + 2 + k * 3
                    hh = h - k * 1.6
                    if axis == "x":
                        rbx.part(parent, "Relieve", (a, H + hh / 2, line + off), (2.2, hh, 0.3), col, **kw)
                    else:
                        rbx.part(parent, "Relieve", (line + off, H + hh / 2, a), (0.3, hh, 2.2), col, **kw)
            else:
                cy = H + rng.uniform(4, 8)
                if axis == "x":
                    rbx.part(parent, "Deposito", ((a0 + a1) / 2, cy, line + off), (0.3, 7, 7), (120, 120, 110), shape="Cylinder",
                             rot=rbx.rot_y(90), **kw)
                else:
                    rbx.part(parent, "Deposito", (line + off, cy, (a0 + a1) / 2), (0.3, 7, 7), (120, 120, 110), shape="Cylinder", **kw)

    def corridor_props(self, p, s, slots):
        rng = self.rng
        for (c, d) in slots:
            r = rng.random()
            if r < 0.035:
                fr = against_wall(self.B, c, d, 2.8)
                self.place_locker(p, fr, c)
            elif r < 0.06:
                fr = against_wall(self.B, c, d, 2.4)
                self.crates(p, fr, c[0], small=True)
            elif r < 0.08:
                # charco reflectante
                l, x, z = c
                cx, cy, cz = self.B.cell_center(x, z, l)
                rbx.part(p, "Charco", (cx + rng.uniform(-2, 2), cy + 0.03, cz + rng.uniform(-2, 2)),
                         (rng.uniform(3, 6), 0.06, rng.uniform(2, 4)), (30, 34, 38), "Glass", collide=False, query=False,
                         reflect=0.35, transparency=0.2, shadow=False)
            elif r < 0.1:
                # cuadro eléctrico con piloto
                fr = against_wall(self.B, c, d, 0.6, inset=0.5)
                m = rbx.model(p, "CuadroElectrico")
                fr.part(m, "Caja", (0, 5, 0), (2.4, 3, 0.6), (150, 156, 150), collide=False)
                g = fr.part(m, "Piloto", (0.7, 6, -0.32), (0.3, 0.3, 0.1), (255, 60, 40), "Neon", collide=False, shadow=False)
                fr.part(m, "Rayo", (-0.3, 5, -0.32), (0.8, 0.8, 0.05), (230, 190, 30), collide=False, shadow=False)

    # ------------------------------------------------------------------ marcadores
    def markers(self):
        lay, B, rng = self.lay, self.B, self.rng
        M = B.folder("Marcadores")
        hub = lay.hub
        cx = (lay.w // 2 + 0.5) * self.CELL
        cz = (lay.h // 2) * self.CELL - 16.5
        self.dock = rbx.part(B.root, "ElevatorDock", (cx, 6, cz), (0.35, 0.35, 0.35), (40, 40, 40), collide=False, query=False,
                             shadow=False, transparency=1.0)
        hx0, hx1, hz0, hz1 = hub.rect(0)
        rbx.box(B.root, "Bounds", 0, lay.w * self.CELL, -2, self.CEIL1 + 2, 0, lay.h * self.CELL, (0, 0, 0), collide=False, query=False,
                transparency=1.0, shadow=False)
        # Puertas con puzzle (antes que nada: marcan el vano)
        for i, (axis, line, mid, y0, ca, cb) in enumerate(self.door_markers):
            pos = (mid, y0 + 0.2, line) if axis == "x" else (line, y0 + 0.2, mid)
            marker(B, M, f"Puerta{i + 1:02d}", "PuzzleSpawn", pos, part_attrs={"Width": DOOR_W, "Height": DOOR_H})
        locked = set()
        for sid in self.puzzle_rooms:
            locked |= {c for c in lay.spaces[sid].cells}

        def far(c):
            return self.dist.get(c, 0)

        # Generadores: contra muros de salas, repartidos (muestreo del más lejano)
        cands = []
        for s in lay.spaces:
            if s.kind in ("room", "hall") and s.sid not in self.puzzle_rooms:
                for (c, d) in wall_slots(B, s):
                    if far(c) >= 12:
                        cands.append((c, d))
        machines = self.spread(cands, 12, 6.0, depth=4.0, w=5.0)
        for (fr, c) in machines:
            marker(B, M, "Generador", "MachineSpawn", fr.w(0, 0.05, 0))
        # Cajas fuertes: salas hoja (preferentemente tras puerta con puzzle)
        cands = []
        for s in lay.spaces:
            if s.kind == "room" and (s.sid in self.puzzle_rooms or len(s.cells) >= 9):
                for (c, d) in wall_slots(B, s):
                    cands.append((c, d))
        safes = self.spread(cands, 6, 4.0, depth=3.5, w=4.0, prefer=lambda c: 30 if lay.occ[c] in self.puzzle_rooms else 0)
        for i, (fr, c) in enumerate(safes):
            marker(B, M, f"Cofre{i + 1:02d}", "PuzzleSpawn", fr.w(0, 0.05, 0))
        # Tesoros
        n = 0
        for s in lay.spaces:
            if not s.cells or s.kind in ("shaft", "hub", "stair"):
                continue
            cells = [c for c in s.cells if c not in s.void and c not in B.door_cells]
            if not cells:
                continue
            want = {"room": 3, "hall": 5, "closet": 1, "catwalk": 1, "corridor": 0}[s.kind]
            if s.kind == "corridor" and rng.random() < 0.12:
                want = 1
            if s.sid in self.puzzle_rooms:
                want += 2
            rng.shuffle(cells)
            for c in cells:
                if want <= 0:
                    break
                l, x, z = c
                px, py, pz = B.cell_center(x, z, l)
                px += rng.uniform(-2.5, 2.5)
                pz += rng.uniform(-2.5, 2.5)
                if s.kind == "catwalk":
                    px, pz = B.cell_center(x, z, l)[0], B.cell_center(x, z, l)[2]
                if B.free_spot(px - 1.2, px + 1.2, pz - 1.2, pz + 1.2, l):
                    B.block(px - 1.2, px + 1.2, pz - 1.2, pz + 1.2, l)
                    marker(B, M, "Tesoro", "TreasureSpawn", (px, py + 0.05, pz))
                    n += 1
                    want -= 1
        self.treasures = n
        # Criaturas: pasillos lejanos
        cands = [c for s in lay.spaces if s.kind == "corridor" for c in s.cells if far(c) >= 28]
        rng.shuffle(cands)
        chosen = []
        for c in cands:
            if all(abs(c[1] - o[1]) + abs(c[2] - o[2]) > 22 for o in chosen):
                chosen.append(c)
            if len(chosen) >= 6:
                break
        for c in chosen:
            px, py, pz = B.cell_center(c[1], c[2], c[0])
            marker(B, M, "Criatura", "CreatureSpawn", (px, py + 0.1, pz))
        # Patrullas: cruces de pasillo y tramos de escalera
        pts = []
        for s in lay.spaces:
            if s.kind != "corridor":
                continue
            for c in s.cells:
                if len(list(lay.neighbors(c))) >= 3:
                    pts.append(B.cell_center(c[1], c[2], c[0]))
        rng.shuffle(pts)
        keep = []
        for p in pts:
            if all((p[0] - q[0]) ** 2 + (p[2] - q[2]) ** 2 + (p[1] - q[1]) ** 2 > 28 ** 2 for q in keep):
                keep.append(p)
        for st in lay.stairs:
            d = st["dir"]
            f0 = st["cells"][0]
            dx, dz = DIRS[d]
            sx = (f0[0] + 0.5) * self.CELL - dx * self.CELL / 2
            sz = (f0[1] + 0.5) * self.CELL - dz * self.CELL / 2
            for k in range(5):
                t = k / 4
                y = self.LH * t if st["high_end"] == 2 else self.LH * (1 - t)
                keep.append((sx + dx * (3 * self.CELL * t + (-2 if k == 0 else 2 if k == 4 else 0)), y,
                             sz + dz * (3 * self.CELL * t + (-2 if k == 0 else 2 if k == 4 else 0))))
        for i, p in enumerate(keep):
            marker(B, M, f"Patrulla{i + 1}", f"Patrol{i + 1}", (p[0], p[1] + 0.1, p[2]))
        self.patrols = len(keep)

    def spread(self, cands, count, min_gap_cells, depth, w, prefer=None):
        """Elige `count` huecos contra muro lo más separados posible (y libres de muebles)."""
        B = self.B
        out = []
        pool = list(cands)
        self.rng.shuffle(pool)
        while len(out) < count and pool:
            best, bestv = None, -1
            for (c, d) in pool[:400]:
                fr = against_wall(B, c, d, depth)
                a, b = fr.w(-w / 2, 0, -depth / 2), fr.w(w / 2, 0, depth / 2)
                x0, x1, z0, z1 = min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2])
                if not B.free_spot(x0, x1, z0, z1, c[0], pad=0.5):
                    continue
                dmin = min([math.hypot(c[1] - o[1][1], c[2] - o[1][2]) for o in out] or [999])
                v = dmin + (prefer(c) if prefer else 0) + self.rng.random()
                if dmin >= min_gap_cells and v > bestv:
                    best, bestv = (fr, c, (x0, x1, z0, z1)), v
            if not best:
                break
            fr, c, (x0, x1, z0, z1) = best
            B.block(x0, x1, z0, z1, c[0])
            out.append((fr, c))
            pool = [p for p in pool if p[0] != c]
        return out

    # ------------------------------------------------------------------ límites 2.5D
    def boundaries(self):
        B = self.B
        F = B.folder("Limites")
        pal = {"floor": FLOOR["corridor"], "wall": WALL_UP, "ceil": CEIL, "lamp": LAMP}
        for (c, d) in self.fakes:
            l, x, z = c
            cx, cy, cz = B.cell_center(x, z, l)
            edge = (cx + DIRS[d][0] * C / 2, cz + DIRS[d][1] * C / 2)
            forced_corridor(B, F, edge, d, cy, 4 * C - 1, CEIL0, C - T, pal)

    def build(self):
        self.door_markers = []
        self.assign()
        self.fake_corridors()
        self.structure()
        self.lights()
        self.decor()
        self.markers()
        self.boundaries()
        for s in self.lay.spaces:
            if s.kind in ("room", "hall") and s.cells:
                x0, x1, z0, z1 = s.rect()
                l = min(c[0] for c in s.cells)
                self.labels.append((s.name, (x0 + x1 + 1) / 2 * C, (z0 + z1 + 1) / 2 * C, l))
        self.B.root.props["primary"] = self.dock
        # MapNav: malla de navegación en la planta baja y en el segundo piso (alturas sobre el suelo del acople)
        nav = dict(NavFloors=f"0,{self.LH:g}", NavSpacing=self.CELL, Seed=self.seed)
        self.B.root.attrs.update(nav)
        # Rojo descarta los atributos del modelo raíz de un .rbxmx: copia en Bounds (MapNav mira los dos)
        for inst in self.B.root.children:
            if inst.name == "Bounds":
                inst.attrs.update(nav)
        return self.B


def _ident(t):
    return t.lower().replace("é", "e").replace("í", "i").replace("á", "a").replace("ó", "o").replace(" ", "_")
