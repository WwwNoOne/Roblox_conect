"""Marco para niveles de arquitectura dibujados a mano (hospital, escuela, mansión, centro comercial).

A diferencia de Level_1/Level_2 (crecimiento en raíz), aquí cada mapa coloca sus edificios, plantas, salas, pasillos, escaleras y
exteriores con coordenadas de celda. El marco se encarga de:
  * Plan: autoría (area, connect, open_between, stairwell en zigzag, flight) y validación (todo alcanzable desde el ascensor).
  * ArchLevel: geometría para N plantas (sótano negativo, azoteas), muros interiores a dos tonos, fachadas con ventanas, vallas,
    setos, pretiles, puertas, barandillas, escaleras; luces; marcadores del manifiesto; muebles (hereda los de Level1/Level2).
Cada celda mide C studs; la planta l pisa y = l * H. Interior con techo a 12 sobre el suelo (o data["ceil"]).
"""
from __future__ import annotations

import math
import random

import rbx
from build import Builder, merge_rects
from common import Frame, against_wall, hide_volume, locker, marker, wall_slots, yaw_for
from layout import DIRS, Layout, Space
from level1 import DOOR_H, DOOR_W, LAMP
from level2 import Level2

C, H = 10.0, 14.0
T = 1.0


class Plan(Layout):
    def __init__(self, w: int, h: int, seed: int, lmin: int = 0, lmax: int = 1):
        super().__init__(w, h, seed, layers=lmax + 1, margin=0)
        self.lmin, self.lmax = lmin, lmax
        self.hub_c = None
        self.dock = None  # (x, y, z) local
        self.blocked: set = set()  # aristas con muro dentro de un mismo espacio (laberinto)

    def neighbors(self, c):
        for n in super().neighbors(c):
            if frozenset((c, n)) not in self.blocked:
                yield n

    def hub_cell(self):
        return self.hub_c

    # ---------------------------------------------------------------- autoría
    def area(self, kind, name, l, x0, z0, x1, z1, outdoor=False, exclude=(), **data) -> Space:
        s = self.new_space(kind, name)
        s.data.update(outdoor=outdoor, **data)
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for z in range(min(z0, z1), max(z0, z1) + 1):
                if (x, z) in exclude:
                    continue
                c = (l, x, z)
                if c in self.occ:
                    raise ValueError(f"{name} solapa con {self.spaces[self.occ[c]].name} en {c}")
                self.take(s, c)
        return s

    def extend(self, s: Space, l, x0, z0, x1, z1, void=False):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for z in range(min(z0, z1), max(z0, z1) + 1):
                c = (l, x, z)
                if c in self.occ:
                    raise ValueError(f"{s.name} solapa con {self.spaces[self.occ[c]].name} en {c}")
                self.take(s, c, void=void)

    def shared(self, s1: Space, s2: Space, layer=None):
        out = []
        for c in s1.cells:
            if layer is not None and c[0] != layer:
                continue
            for d in range(4):
                n = (c[0], c[1] + DIRS[d][0], c[2] + DIRS[d][1])
                if n in s2.cells and n not in s2.void and c not in s1.void:
                    out.append((c, n))
        return sorted(out)

    def connect(self, s1: Space, s2: Space, kind="door", n=1, at=None, layer=None):
        """Une dos espacios por `n` puertas repartidas en su borde común (o la más cercana a `at` = (x, z))."""
        edges = self.shared(s1, s2, layer)
        if not edges:
            raise ValueError(f"{s1.name} y {s2.name} no se tocan")
        if at is not None:
            edges.sort(key=lambda e: abs(e[0][1] - at[0]) + abs(e[0][2] - at[1]))
            picks = edges[:n]
        elif n == 1:
            picks = [edges[len(edges) // 2]]
        else:
            step = len(edges) / n
            picks = [edges[int(step * (i + 0.5))] for i in range(n)]
        for (a, b) in picks:
            self.link(a, b, kind)
        return picks

    def open_between(self, s1: Space, s2: Space, layer=None):
        for (a, b) in self.shared(s1, s2, layer):
            self.link(a, b, "open")

    def flight(self, l, cells, d, name="Escalera", inner=False) -> Space:
        """Tramo recto de 3 celdas en la planta l que sube a l+1 en la dirección d (cells ordenadas en esa dirección)."""
        s = self.new_space("stair", name)
        for (x, z) in cells:
            c = (l, x, z)
            if c in self.occ:
                raise ValueError(f"{name} pisa {self.spaces[self.occ[c]].name} en {c}")
            self.take(s, c)
        for (x, z) in cells[1:]:
            c = (l + 1, x, z)
            if c in self.occ:
                raise ValueError(f"hueco de {name} pisa {self.spaces[self.occ[c]].name} en {c}")
            self.take(s, c, void=True)
        s.data.update(dir=d, cells=list(cells), high_end=2, low_layer=l, inner=inner)
        self.stairs.append(s.data | {"sid": s.sid})
        return s

    def stairwell(self, x0, z0, l0, l1, axis="z", name="Escalera", outdoor_top=False, flip=False):
        """Caja de escalera en zigzag de 2 x 5 celdas, de la planta l0 a la l1. El pasillo debe correr junto a la columna 2 local
        (x0+2 si axis='z', z0+2 si axis='x'). Rellanos: planta par (relativa) en la fila 0, impar en la fila 4.
        Devuelve {planta: espacio del rellano}; une cada tramo con sus rellanos."""
        sg = -1 if flip else 1  # flip: las columnas crecen hacia -X / -Z (el pasillo queda al otro lado)

        def T(col, row):
            return (x0 + sg * col, z0 + row) if axis == "z" else (x0 + row, z0 + sg * col)
        fwd, back = (0, 2) if axis == "z" else (1, 3)
        landings = {}
        flights = {}
        for l in range(l0, l1 + 1):
            rel = l - l0
            cells = [T(0, 0), T(1, 0)] if rel % 2 == 0 else [T(0, 4), T(1, 4)]
            s = self.new_space("stairwell", f"{name} P{l}")
            s.data.update(outdoor=False, landing_row=0 if rel % 2 == 0 else 4, axis=axis, origin=(x0, z0))
            for (x, z) in cells:
                self.take(s, (l, x, z))
            landings[l] = s
        for l in range(l0, l1):
            rel = l - l0
            if rel % 2 == 0:
                cells = [T(0, 1), T(0, 2), T(0, 3)]
                f = self.flight(l, cells, fwd, name)
                self.link((l, *T(0, 0)), (l, *T(0, 1)), "open")
                self.link((l + 1, *T(0, 3)), (l + 1, *T(0, 4)), "open")
                for r in (1, 2, 3):
                    if (l, *T(1, r)) in self.occ:
                        self.link((l, *T(0, r)), (l, *T(1, r)), "rail")
            else:
                cells = [T(1, 3), T(1, 2), T(1, 1)]
                f = self.flight(l, cells, back, name)
                self.link((l, *T(1, 4)), (l, *T(1, 3)), "open")
                self.link((l + 1, *T(1, 1)), (l + 1, *T(1, 0)), "open")
            flights[l] = f
        # barandilla entre el tramo y el hueco del tramo de abajo (misma planta, columnas vecinas)
        for l in range(l0 + 1, l1 + 1):
            for r in range(5):
                a, b = (l, *T(0, r)), (l, *T(1, r))
                sa, sb = self.space_of(a), self.space_of(b)
                if sa and sb and sa.sid != sb.sid and (sa.kind == "stair" or sb.kind == "stair") and not self.link_kind(a, b):
                    self.link(a, b, "rail")
        if outdoor_top:
            landings[l1].data["roof_kiosk"] = True
        return landings

    def elevator_shaft(self, x0, z0, front_space: Space):
        """Hueco del ascensor de 3 x 4 celdas con la boca hacia +Z, abierta a front_space (el acople)."""
        s = self.area("shaft", "Acople", 0, x0, z0, x0 + 2, z0 + 3)
        for l in range(1, 2):
            if self.lmax >= l:
                for x in range(x0, x0 + 3):
                    for z in range(z0, z0 + 4):
                        c = (l, x, z)
                        if c not in self.occ:
                            self.take(s, c, void=True)
        for x in range(x0, x0 + 3):
            a, b = (0, x, z0 + 3), (0, x, z0 + 4)
            if b not in front_space.cells:
                raise ValueError("la boca del ascensor no da al acople")
            self.link(a, b, "open")
        self.dock = ((x0 + 1.5) * C, 6.0, (z0 + 4) * C - 16.5)
        self.hub_c = (0, x0 + 1, z0 + 4)
        self.hub = front_space
        self.shaft_space = s
        return s

    def validate(self):
        dist = self.bfs(self.hub_c)
        bad = []
        for s in self.spaces:
            if not s.cells or s.kind in ("shaft",):
                continue
            walk = [c for c in s.cells if c not in s.void or s.kind == "stair"]
            if walk and not any(c in dist for c in walk):
                bad.append(f"{s.name}({s.kind}) en {sorted(walk)[0]}")
        if bad:
            raise ValueError("Inalcanzable desde el ascensor: " + "; ".join(bad[:20]))
        return dist


class ArchLevel(Level2):
    """Base de los niveles de arquitectura. Las subclases definen plan(), THEME y los ganchos de decoración y límites."""
    CELL, LH = C, H
    CEIL1 = 12.0
    NAME = "Level_X"
    THEME = {}
    NAV_SPACING = C

    def __init__(self, seed=1):
        self.seed = seed
        self.rng = random.Random(seed * 31 + 7)
        self.lay = self.plan()
        self.B = Builder(self.lay, C, H, self.NAME)
        for k in self.lay.blocked:
            self.B.override[k] = "wall"
        self.dist = self.lay.validate()
        self.labels = []
        self.puzzle_rooms = set()
        self.hills = []
        self.locker_n = 0
        self.door_markers = []
        self.sector = {}
        self.fakes = []

    def plan(self) -> Plan:
        raise NotImplementedError

    # ---------------------------------------------------------------- semántica
    def indoor(self, s):
        return s is not None and not s.data.get("outdoor", False)

    def th(self, key, default=None):
        return self.THEME.get(key, default)

    def ceil_of(self, s):
        return s.data.get("ceil", 12.0)

    def wall_key(self, ca, cb):
        lay = self.lay
        sa, sb = lay.space_of(ca), lay.space_of(cb)
        ia, ib = self.indoor(sa), self.indoor(sb)
        if ia or ib:
            inside = sa if ia else sb
            other = sb if ia else sa
            if other is None or not self.indoor(other):
                if inside.kind == "shaft":
                    return ("ext", "shaft", 12.0)
                return ("ext", inside.data.get("facade", "std"), self.ceil_of(inside))
            # tabique interior: color de la sala de mayor rango
            rank = {"room": 3, "hall": 3, "stairwell": 2, "corridor": 1}
            s = max((sa, sb), key=lambda q: rank.get(q.kind, 0))
            return ("int", s.data.get("wall", self.th("wall_int", (186, 182, 170))), s.data.get("zocalo", self.th("zocalo", (90, 110, 110))),
                    max(self.ceil_of(sa), self.ceil_of(sb)))
        out = sa if sa is not None else sb
        styles = [q.data.get("edge", "fence") for q in (sa, sb) if q is not None]
        prio = ["parapet", "hedge", "fence", "wall", "low"]
        st = min(styles, key=lambda e: prio.index(e) if e in prio else 9)
        return ("out", st)

    # ---------------------------------------------------------------- estructura
    def floor_style(self, s):
        t = s.data.get("type")
        if s.data.get("floor"):
            return s.data["floor"]
        if not self.indoor(s):
            g = s.data.get("ground", "paving")
            return self.th("ground", {}).get(g, ((120, 120, 116), "SmoothPlastic"))
        if s.kind == "corridor":
            return (self.th("floor_corr", (150, 150, 146)), "SmoothPlastic")
        if s.kind == "stairwell":
            return ((128, 128, 124), "SmoothPlastic")
        return (self.th("floor_room", {}).get(t, self.th("floor_default", (160, 150, 130))), "SmoothPlastic")

    def structure(self):
        lay, B = self.lay, self.B
        S = B.folder("Estructura/Suelos")
        for s in lay.spaces:
            if not s.cells or s.kind == "stair":
                continue
            layers = sorted({c[0] for c in s.cells})
            col, mat = self.floor_style(s)
            for l in layers:
                holes = s.data.get("holes", set())
                cells = {(x, z) for (cl, x, z) in s.cells if cl == l and (cl, x, z) not in s.void and (x, z) not in holes}
                y = l * H
                for (x0, x1, z0, z1) in merge_rects(cells):
                    name = "Platform" if s is lay.hub and l == 0 else "Suelo"
                    parent = B.root if name == "Platform" else S
                    p = rbx.box(parent, name, x0 * C, (x1 + 1) * C, y - 1.4, y, z0 * C, (z1 + 1) * C, col, mat)
                    if name == "Platform":
                        self.platform = p
        # techos (y tejado donde no hay nada encima)
        R = B.folder("Estructura/Techos")
        ceils, roofs = {}, {}
        for (l, x, z), sid in lay.occ.items():
            s = lay.spaces[sid]
            if not self.indoor(s) or s.kind == "stair":
                continue
            up = (l + 1, x, z)
            us = lay.space_of(up)
            if us is not None and up in us.void:
                continue
            ch = self.ceil_of(s)
            ceils.setdefault((l, ch), set()).add((x, z))
            if us is None:
                roofs.setdefault((l, ch), set()).add((x, z))
        for st in lay.stairs:  # techo sobre el tramo bajo de cada escalera (la parte alta queda abierta)
            sp = lay.spaces[st["sid"]]
            l = st["low_layer"]
            for (x, z) in st["cells"]:
                if (l + 1, x, z) not in sp.cells:
                    if (l + 1, x, z) not in lay.occ:
                        roofs.setdefault((l, 12.0), set()).add((x, z))
                    ceils.setdefault((l, 12.0), set()).add((x, z))
        for (l, ch), cells in ceils.items():
            for (x0, x1, z0, z1) in merge_rects(cells):
                rbx.box(R, "Techo", x0 * C, (x1 + 1) * C, l * H + ch, l * H + ch + 0.6, z0 * C, (z1 + 1) * C,
                        self.th("ceil", (70, 70, 74)), shadow=False)
        for (l, ch), cells in roofs.items():
            for (x0, x1, z0, z1) in merge_rects(cells):
                rbx.box(R, "Tejado", x0 * C, (x1 + 1) * C, l * H + ch + 0.6, l * H + ch + 1.2, z0 * C, (z1 + 1) * C,
                        self.th("roof", (84, 84, 88)))
        # muros
        W = B.folder("Estructura/Muros")
        for l in range(lay.lmin, lay.lmax + 1):
            for (axis, line, a0, a1, style, segs) in B.wall_runs(l, self.wall_key):
                self.render_wall(W, l, axis, line, a0, a1, style, segs)
        # vanos
        D = B.folder("Estructura/Vanos")
        runs = {}
        for l in range(lay.lmin, lay.lmax + 1):
            for (t, axis, line, a0, a1, ca, cb) in B.edges(l):
                if t in ("door", "puzzle"):
                    self.render_door(D, l, axis, line, a0, a1, ca, cb, t)
                elif t == "rail":
                    sa, sb = lay.space_of(ca), lay.space_of(cb)
                    on_stair = (sa and sa.kind == "stair" and ca not in sa.void) or (sb and sb.kind == "stair" and cb not in sb.void)
                    if on_stair:
                        self.rail(D, l, axis, line, a0, a1, ca, cb)
                    else:
                        runs.setdefault((l, axis, line), []).append((a0, a1))
        # barandillas fusionadas en tramos continuos (atrios, galerías): pocas piezas aunque midan cientos de studs
        col = self.th("rail", (200, 196, 186))
        for (l, axis, line), segs in runs.items():
            segs.sort()
            merged = []
            for (a0, a1) in segs:
                if merged and abs(merged[-1][1] - a0) < 1e-6:
                    merged[-1][1] = a1
                else:
                    merged.append([a0, a1])
            y = l * H
            for (a0, a1) in merged:
                m = rbx.model(D, "Barandilla")
                B.wall_box(m, "Pasamanos", axis, line, a0, a1, y + 3.3, y + 3.6, 0.35, col, "Metal", collide=False)
                B.wall_box(m, "Vidrio", axis, line, a0, a1, y + 0.3, y + 3.2, 0.15, (190, 220, 230), "Glass", transparency=0.7,
                           collide=False)
                B.wall_box(m, "Colision", axis, line, a0, a1, y, y + 4.2, 0.4, (0, 0, 0), transparency=1, shadow=False)
                a = a0
                while a <= a1 + 0.01:
                    B.wall_box(m, "Poste", axis, line, a - 0.12, a + 0.12, y, y + 3.6, 0.24, col, "Metal", collide=False)
                    a += 2 * C
        # escaleras
        E = B.folder("Estructura/Escaleras")
        for st in lay.stairs:
            sp = lay.spaces[st["sid"]]
            m = rbx.model(E, sp.name.replace(" ", ""))
            self.steps(m, st, C - T, self.th("stair", (130, 126, 118)))

    def steps(self, parent, st, width, color, n=14):
        d = st["dir"]
        cells = st["cells"]
        dx, dz = DIRS[d]
        fx, fz = cells[0]
        cx0 = (fx + 0.5) * C - dx * C / 2
        cz0 = (fz + 0.5) * C - dz * C / 2
        base = st["low_layer"] * H
        depth = 3 * C / n
        for i in range(n):
            top = (i + 1) * H / n
            off = (i + 0.5) * depth
            cx, cz = cx0 + dx * off, cz0 + dz * off
            size = (depth + 0.02, top + 1.4, width) if dx else (width, top + 1.4, depth + 0.02)
            rbx.part(parent, f"Escalon{i + 1:02d}", (cx, base + top / 2 - 0.7, cz), size, color)
            if i % 2 == 0:
                edge = (0.3, 0.06, width) if dx else (width, 0.06, 0.3)
                rbx.part(parent, "Borde", (cx + dx * (depth / 2 - 0.2), base + top + 0.03, cz + dz * (depth / 2 - 0.2)), edge,
                         self.th("stair_edge", (220, 180, 60)), collide=False, query=False, shadow=False)

    def render_wall(self, W, l, axis, line, a0, a1, style, segs):
        B = self.B
        y0 = l * H
        kind = style[0]
        if kind == "int":
            _, wall, zoc, ch = style
            top = y0 + (H if ch >= 12 else ch + 1.2)
            B.wall_box(W, "Zocalo", axis, line, a0 - T / 2, a1 + T / 2, y0, y0 + 3.6, T + 0.1, zoc)
            B.wall_box(W, "Muro", axis, line, a0 - T / 2, a1 + T / 2, y0 + 3.6, top, T, wall)
        elif kind == "ext":
            self.facade(W, l, axis, line, a0, a1, style[1], segs, style[2])
        else:
            self.outdoor_edge(W, l, axis, line, a0, a1, style[1], segs)

    def facade(self, W, l, axis, line, a0, a1, kind, segs, ch=12.0):
        """Fachada con ventanas en celdas alternas (las de la planta baja hacia el exterior también)."""
        B = self.B
        y0, y1 = l * H, l * H + (H if ch >= 12 else ch + 1.2)
        col = self.th("facade", {}).get(kind, self.th("facade_default", (196, 190, 176)))
        glass = self.th("glass", (150, 190, 200))
        if kind == "shaft" or kind == "blind":
            B.wall_box(W, "Fachada", axis, line, a0 - T / 2, a1 + T / 2, y0, y1, T + 0.4, col, "Concrete" if kind == "shaft" else "SmoothPlastic")
            return
        # bandas: zócalo y dintel corridos; en la franja de ventanas alternan machones y vidrio (tramos fusionados)
        B.wall_box(W, "Fachada", axis, line, a0 - T / 2, a1 + T / 2, y0, y0 + 4, T + 0.4, col)
        B.wall_box(W, "Fachada", axis, line, a0 - T / 2, a1 + T / 2, y0 + 9.5, y1, T + 0.4, col)
        n = int(round((a1 - a0) / C))
        kinds = []
        for k in range(n):
            kinds.append("glass" if (k + l + int(line / C)) % 2 == 0 else "pier")
        k = 0
        while k < n:
            j = k
            while j + 1 < n and kinds[j + 1] == kinds[k]:
                j += 1
            s0, s1 = a0 + k * C, a0 + (j + 1) * C
            if k == 0:
                s0 -= T / 2
            if j == n - 1:
                s1 += T / 2
            if kinds[k] == "pier":
                B.wall_box(W, "Fachada", axis, line, s0, s1, y0 + 4, y0 + 9.5, T + 0.4, col)
            else:
                B.wall_box(W, "Ventana", axis, line, s0, s1, y0 + 4, y0 + 9.5, 0.3, glass, "Glass", transparency=0.45)
            k = j + 1

    def outdoor_edge(self, W, l, axis, line, a0, a1, st, segs):
        B = self.B
        y0 = l * H
        if st == "parapet":
            B.wall_box(W, "Pretil", axis, line, a0 - 0.5, a1 + 0.5, y0, y0 + 3.4, 1.0, self.th("parapet", (170, 166, 156)))
            B.wall_box(W, "Colision", axis, line, a0, a1, y0, y0 + 8, 0.4, (0, 0, 0), transparency=1, shadow=False)
        elif st == "hedge":
            hh = self.th("hedge_h", 10)
            B.wall_box(W, "Seto", axis, line, a0 - 1, a1 + 1, y0 - 0.5, y0 + hh, 2.2, self.th("hedge", (52, 92, 52)), "Grass")
            B.wall_box(W, "Colision", axis, line, a0, a1, y0, y0 + 30, 0.4, (0, 0, 0), transparency=1, shadow=False)
        elif st == "wall":
            hh = self.th("wall_h", 12)
            B.wall_box(W, "Tapia", axis, line, a0 - 0.6, a1 + 0.6, y0 - 0.5, y0 + hh, 1.4, self.th("outwall", (150, 120, 100)), "Brick")
            B.wall_box(W, "Albardilla", axis, line, a0 - 0.6, a1 + 0.6, y0 + hh, y0 + hh + 0.5, 1.9, (120, 116, 110), collide=False)
            B.wall_box(W, "Colision", axis, line, a0, a1, y0, y0 + 30, 0.4, (0, 0, 0), transparency=1, shadow=False)
        elif st == "low":
            B.wall_box(W, "Bordillo", axis, line, a0, a1, y0, y0 + 1.2, 0.8, (130, 130, 126))
        else:  # fence
            m = rbx.model(W, "Valla")
            hh = 10
            B.wall_box(m, "Malla", axis, line, a0, a1, y0 + 0.2, y0 + hh, 0.15, (120, 130, 130), "Fabric", transparency=0.55,
                       collide=False, query=False)
            for a in range(int(a0), int(a1) + 1, int(C)):
                B.wall_box(m, "Poste", axis, line, a - 0.2, a + 0.2, y0, y0 + hh + 0.4, 0.4, (80, 86, 86), "Metal", collide=False)
            B.wall_box(m, "Larguero", axis, line, a0, a1, y0 + hh - 0.2, y0 + hh + 0.1, 0.3, (80, 86, 86), "Metal", collide=False)
            B.wall_box(m, "Colision", axis, line, a0, a1, y0, y0 + 30, 0.4, (0, 0, 0), transparency=1, shadow=False)

    def render_door(self, D, l, axis, line, a0, a1, ca, cb, t):
        lay, B = self.lay, self.B
        sa, sb = lay.space_of(ca), lay.space_of(cb)
        y0 = l * H
        mid = (a0 + a1) / 2
        if self.indoor(sa) or self.indoor(sb):
            key = self.wall_key((0, 0, 0), (0, 0, 0)) if False else None
            inside = sa if self.indoor(sa) else sb
            other = sb if inside is sa else sa
            if self.indoor(other):
                wall = inside.data.get("wall", self.th("wall_int", (186, 182, 170)))
                zoc = inside.data.get("zocalo", self.th("zocalo", (90, 110, 110)))
                B.doorway(D, "Vano", axis, line, a0 - T / 2, a1 + T / 2, y0, y0 + H, T, DOOR_W, DOOR_H, wall)
            else:
                col = self.th("facade", {}).get(inside.data.get("facade", "std"), self.th("facade_default", (196, 190, 176)))
                B.doorway(D, "Portal", axis, line, a0 - T / 2, a1 + T / 2, y0, y0 + H, T + 0.4, DOOR_W, DOOR_H, col)
            fc = self.th("door_frame", (230, 230, 224))
            for sgn in (-1, 1):
                a = mid + sgn * (DOOR_W / 2 + 0.2)
                B.wall_box(D, "Marco", axis, line, a - 0.2, a + 0.2, y0, y0 + DOOR_H, T + 0.3, fc)
            if t == "puzzle":
                self.door_markers.append((axis, line, mid, y0, ca, cb))
        else:
            # paso en una valla/seto/tapia: dos pilares
            st = self.wall_key(ca, cb)[1]
            for sgn in (-1, 1):
                a = mid + sgn * (C / 2 - 0.6)
                col = self.th("hedge", (52, 92, 52)) if st == "hedge" else (140, 130, 120)
                hh = self.th("hedge_h", 10) if st == "hedge" else 6
                B.wall_box(D, "Pilar", axis, line, a - 0.6, a + 0.6, y0 - 0.5, y0 + hh, 2.2 if st == "hedge" else 1.2, col,
                           "Grass" if st == "hedge" else "SmoothPlastic")

    def rail(self, parent, l, axis, line, a0, a1, ca, cb):
        lay, B = self.lay, self.B
        sa, sb = lay.space_of(ca), lay.space_of(cb)
        stair = sa if sa and sa.kind == "stair" and ca not in sa.void else (sb if sb and sb.kind == "stair" and cb not in sb.void else None)
        col = self.th("rail", (200, 196, 186))
        if stair:
            c = ca if sa is stair else cb
            st = stair.data
            i = st["cells"].index((c[1], c[2]))
            top = l * H + (i + 1) * H / 3
            B.wall_box(parent, "Pretil", axis, line, a0, a1, l * H, top + 3.2, 0.6, col)
            return
        y = l * H
        m = rbx.model(parent, "Barandilla")
        B.wall_box(m, "Pasamanos", axis, line, a0, a1, y + 3.3, y + 3.6, 0.35, col, "Metal", collide=False)
        for a in (a0 + 0.3, (a0 + a1) / 2, a1 - 0.3):
            B.wall_box(m, "Poste", axis, line, a - 0.12, a + 0.12, y, y + 3.6, 0.24, col, "Metal", collide=False)
        B.wall_box(m, "Vidrio", axis, line, a0, a1, y + 0.3, y + 3.2, 0.15, (190, 220, 230), "Glass", transparency=0.7, collide=False)
        B.wall_box(m, "Colision", axis, line, a0, a1, y, y + 4.2, 0.4, (0, 0, 0), transparency=1, shadow=False)

    # ---------------------------------------------------------------- luces
    def lights(self):
        lay, B, rng = self.lay, self.B, self.rng
        L = B.folder("Iluminacion")
        for s in lay.spaces:
            if not s.cells:
                continue
            if not self.indoor(s):
                continue
            ch = self.ceil_of(s)
            cells = sorted(c for c in s.cells if c not in s.void)
            if s.kind == "corridor":
                for c in cells:
                    l, x, z = c
                    if (x * 7 + z * 13) % 9 == 0:
                        cx, _, cz = B.cell_center(x, z, l)
                        self.lamp(L, (cx, 0, cz), self._axis(s, c), l * H + ch)
            elif s.kind in ("room", "hall", "stairwell"):
                # una lámpara por sala (dos en las grandes); una de cada cinco salas, a oscuras
                if rng.random() < 0.2 and s.kind == "room":
                    continue
                lit = cells[len(cells) // 2: len(cells) // 2 + 1]
                if len(cells) > 24:
                    lit = [cells[len(cells) // 4], cells[3 * len(cells) // 4]]
                for (l, x, z) in lit:
                    cx, _, cz = B.cell_center(x, z, l)
                    self.lamp(L, (cx, 0, cz), "x", l * H + ch, length=5, rng_light=26, bright=1.2)
        self.outdoor_lights(L)
        hub = lay.hub
        x, z = lay.dock[0], lay.dock[2] + 16.5
        sign = rbx.part(L, "SenalSegura", (x, 10.2, z - 0.6), (8, 1.0, 0.3), (80, 255, 140), "Neon", collide=False, query=False,
                        shadow=False)
        rbx.light(sign, "PointLight", (90, 255, 150), 1.2, 22)

    def outdoor_lights(self, L):
        """Farolas cada pocas celdas en los exteriores a ras de suelo."""
        lay, B, rng = self.lay, self.B, self.rng
        for s in lay.spaces:
            if self.indoor(s) or not s.cells or s.data.get("roof"):
                continue
            for c in sorted(s.cells):
                l, x, z = c
                if (x % 6 == 0 and z % 6 == 0) and not any(B.classify(c, (l, x + dx, z + dz)) for dx, dz in DIRS[:2]):
                    cx, cy, cz = B.cell_center(x, z, l)
                    self.street_lamp(L, (cx, cy, cz), lit=rng.random() < 0.7)

    def street_lamp(self, parent, pos, lit=True):
        x, y, z = pos
        m = rbx.model(parent, "Farola")
        rbx.cylinder_y(m, "Poste", (x, y + 6, z), 12, 0.5, (60, 64, 66), "Metal", collide=False, query=False)
        g = rbx.part(m, "Farol", (x, y + 12.2, z), (1.6, 0.6, 1.6), self.th("street_light", (255, 200, 130)) if lit else (70, 70, 70),
                     "Neon" if lit else "SmoothPlastic", collide=False, query=False, shadow=False)
        if lit:
            rbx.light(g, "PointLight", self.th("street_light", (255, 200, 130)), 1.4, 32)
            if self.rng.random() < 0.3:
                g.tags.append("LamparaInstalacion")
                g.attrs["Parpadeo"] = True
        return m

    # ---------------------------------------------------------------- muebles extra (marco: X a lo largo del muro, +Z al muro)
    DEPTH = {"shelf": 2.6, "bench": 3, "desk": 3, "cabinet": 2.4, "boiler": 6.5, "console": 3, "tank": 4.5, "crates": 4, "bed": 7,
             "wardrobe": 2.8, "bed_rustic": 7, "table_rustic": 3.5, "shelf_rustic": 2.4, "stove": 3}

    def furnish(self, p, s, slots, fns, frac=0.5, minimum=1):
        k = 0
        want = max(minimum, int(len(slots) * frac))
        for (c, d) in slots:
            if k >= want:
                break
            fn = fns[k % len(fns)] if k < len(fns) else self.rng.choice(fns)
            dep = self.DEPTH.get(fn, 3)
            fr = against_wall(self.B, c, d, dep)
            getattr(self, fn)(p, fr, c[0])
            k += 1

    def free_cells(self, s, margin_cells=False):
        cells = [c for c in s.cells if c not in s.void and c not in self.B.door_cells]
        if margin_cells:
            inner = []
            for c in cells:
                l, x, z = c
                if all((l, x + dx, z + dz) in s.cells for dx, dz in DIRS):
                    inner.append(c)
            return inner
        return cells

    def place_free(self, p, s, fn, w, d, count, pad=1.0, inner=True, yaw=None):
        """Coloca `count` objetos sueltos (fn(p, Frame)) en celdas libres del espacio, sin pisar otros muebles."""
        cells = self.free_cells(s, inner) or self.free_cells(s)
        self.rng.shuffle(cells)
        n = 0
        for c in cells:
            if n >= count:
                break
            l, x, z = c
            cx, cy, cz = self.B.cell_center(x, z, l)
            cx += self.rng.uniform(-2, 2)
            cz += self.rng.uniform(-2, 2)
            yw = yaw if yaw is not None else self.rng.choice((0, 90, 180, 270))
            ww, dd = (w, d) if yw % 180 == 0 else (d, w)
            if self.B.free_spot(cx - ww / 2, cx + ww / 2, cz - dd / 2, cz + dd / 2, l, pad=pad):
                self.B.block(cx - ww / 2, cx + ww / 2, cz - dd / 2, cz + dd / 2, l)
                fn(p, Frame((cx, cy, cz), yw))
                n += 1
        return n

    def decor(self):
        lay, B = self.lay, self.B
        Dfold = B.folder("Decoracion")
        for s in lay.spaces:
            if not s.cells or s.kind in ("stair", "shaft"):
                continue
            m = rbx.folder(Dfold, (s.name or s.kind).replace(" ", "_"))
            slots = wall_slots(B, s)
            self.rng.shuffle(slots)
            if not self.indoor(s):
                self.decor_outdoor(m, s, slots)
            elif s.kind == "corridor":
                self.decor_corridor(m, s, slots)
            elif s.kind in ("room", "hall"):
                self.decor_room(m, s, slots)
        self.decor_extra()

    def decor_corridor(self, p, s, slots):
        self.corridor_props(p, s, slots)

    def decor_room(self, p, s, slots):
        self.furnish(p, s, slots, ["cabinet", "shelf", "crates"])

    def decor_outdoor(self, p, s, slots):
        pass

    def decor_extra(self):
        pass

    # ---------------------------------------------------------------- marcadores
    def choose_puzzles(self, n=5, min_dist=14):
        leaves = [(s, k) for (s, k) in self.lay.leaf_rooms() if self.indoor(s)]
        self.rng.shuffle(leaves)
        chosen = []
        for (s, k) in leaves:
            a, b = tuple(k)
            if a[0] != b[0] or min(self.dist.get(c, 0) for c in s.cells if c in self.dist) < min_dist:
                continue
            if any(abs(a[1] - o[1]) + abs(a[2] - o[2]) + 10 * abs(a[0] - o[0]) < 14 for o in chosen):
                continue
            self.lay.links[k] = "puzzle"
            self.puzzle_rooms.add(s.sid)
            chosen.append(a)
            if len(chosen) >= n:
                break

    def markers(self):
        lay, B, rng = self.lay, self.B, self.rng
        M = B.folder("Marcadores")
        self.dock = rbx.part(B.root, "ElevatorDock", lay.dock, (0.35, 0.35, 0.35), (40, 40, 40), collide=False, query=False,
                             shadow=False, transparency=1.0)
        nav = dict(NavFloors=",".join(f"{l * H:g}" for l in range(lay.lmin, lay.lmax + 1)), NavSpacing=C, Seed=self.seed)
        bounds = rbx.box(B.root, "Bounds", 0, lay.w * C, lay.lmin * H - 2, (lay.lmax + 1) * H + 2, 0, lay.h * C, (0, 0, 0),
                         collide=False, query=False, transparency=1.0, shadow=False)
        bounds.attrs.update(nav)
        B.root.attrs.update(nav)
        for i, (axis, line, mid, y0, ca, cb) in enumerate(self.door_markers):
            pos = (mid, y0 + 0.2, line) if axis == "x" else (line, y0 + 0.2, mid)
            marker(B, M, f"Puerta{i + 1:02d}", "PuzzleSpawn", pos, part_attrs={"Width": DOOR_W, "Height": DOOR_H})

        def far(c):
            return self.dist.get(c, 0)

        rooms = [s for s in lay.spaces if s.kind in ("room", "hall") and s.cells and self.indoor(s)]
        cands = [(c, d) for s in rooms if s.sid not in self.puzzle_rooms for (c, d) in wall_slots(B, s) if far(c) >= 10]
        for (fr, c) in self.spread(cands, 12, 6.0, depth=4.0, w=5.0):
            marker(B, M, "Generador", "MachineSpawn", fr.w(0, 0.05, 0))
        cands = [(c, d) for s in rooms if (s.sid in self.puzzle_rooms or len(s.cells) >= 9) for (c, d) in wall_slots(B, s)]
        for i, (fr, c) in enumerate(self.spread(cands, 6, 4.0, depth=3.5, w=4.0,
                                                prefer=lambda c: 30 if lay.occ[c] in self.puzzle_rooms else 0)):
            marker(B, M, f"Cofre{i + 1:02d}", "PuzzleSpawn", fr.w(0, 0.05, 0))
        n = 0
        for s in lay.spaces:
            if not s.cells or s.kind in ("shaft", "stair", "stairwell") or s is lay.hub:
                continue
            cells = [c for c in s.cells if c not in s.void and c not in B.door_cells]
            if not cells:
                continue
            if self.indoor(s):
                want = {"room": (1 if rng.random() < 0.7 else 0) + len(cells) // 20, "hall": 4,
                        "corridor": 1 if rng.random() < 0.12 else 0}.get(s.kind, 1)
            else:
                want = 0 if s.data.get("roof") and rng.random() < 0.5 else max(1, len(cells) // 40)
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
                if B.free_spot(px - 1.2, px + 1.2, pz - 1.2, pz + 1.2, l):
                    B.block(px - 1.2, px + 1.2, pz - 1.2, pz + 1.2, l)
                    marker(B, M, "Tesoro", "TreasureSpawn", (px, py + 0.05, pz))
                    n += 1
                    want -= 1
        self.treasures = n
        cands = [c for s in lay.spaces if s.kind in ("corridor",) or (not self.indoor(s) and s.cells and not s.data.get("roof"))
                 for c in s.cells if far(c) >= 24 and c not in s.void]
        rng.shuffle(cands)
        chosen = []
        for c in cands:
            if all(abs(c[1] - o[1]) + abs(c[2] - o[2]) + 8 * abs(c[0] - o[0]) > 22 for o in chosen):
                chosen.append(c)
            if len(chosen) >= 6:
                break
        for c in chosen:
            px, py, pz = B.cell_center(c[1], c[2], c[0])
            marker(B, M, "Criatura", "CreatureSpawn", (px, py + 0.1, pz))
        pts = []
        for s in lay.spaces:
            if s.kind not in ("corridor",) and self.indoor(s):
                continue
            if s.data.get("roof"):
                continue
            for c in s.cells:
                if c not in s.void and len(list(lay.neighbors(c))) >= 3:
                    pts.append(B.cell_center(c[1], c[2], c[0]))
        rng.shuffle(pts)
        keep = []
        for p in pts:
            if all((p[0] - q[0]) ** 2 + (p[2] - q[2]) ** 2 + (3 * (p[1] - q[1])) ** 2 > 30 ** 2 for q in keep):
                keep.append(p)
        for st in lay.stairs:
            d = st["dir"]
            f0 = st["cells"][0]
            dx, dz = DIRS[d]
            sx = (f0[0] + 0.5) * C - dx * C / 2
            sz = (f0[1] + 0.5) * C - dz * C / 2
            base = st["low_layer"] * H
            for k in range(5):
                t = k / 4
                ext = -2 if k == 0 else (2 if k == 4 else 0)
                keep.append((sx + dx * (3 * C * t + ext), base + H * t, sz + dz * (3 * C * t + ext)))
        for i, p in enumerate(keep):
            marker(B, M, f"Patrulla{i + 1}", f"Patrol{i + 1}", (p[0], p[1] + 0.1, p[2]))
        self.patrols = len(keep)

    # ---------------------------------------------------------------- límites 2.5D comunes
    def outer_ground(self, parent, name, color, mat="SmoothPlastic", reach=400):
        """Suelo exterior decorativo alrededor del mapa (cuatro losas, sin colisión): nunca cruza el mapa ni sus sótanos."""
        W, Hh = self.lay.w * C, self.lay.h * C
        kw = dict(collide=False, query=False, shadow=False)
        for (x0, x1, z0, z1) in ((-reach, W + reach, -reach, 0), (-reach, W + reach, Hh, Hh + reach), (-reach, 0, 0, Hh), (W, W + reach, 0, Hh)):
            rbx.box(parent, name, x0, x1, -2.6, -1.4, z0, z1, color, mat, **kw)

    def skyline(self, parent, rings=((60, 0.55, 1.0, 46), (150, 0.4, 1.5, 70), (260, 0.28, 2.2, 96)), kind="city"):
        """Anillos de siluetas planas alrededor del mapa (edificios con ventanas encendidas, casas o árboles), cada vez más oscuras."""
        lay, rng = self.lay, self.rng
        W, Hh = lay.w * C, lay.h * C
        kw = dict(collide=False, query=False, shadow=False)
        for (dist, shade, scale, step) in rings:
            per = 2 * (W + Hh + 4 * dist)
            k = 0.0
            while k < per:
                k += step * rng.uniform(0.6, 1.2)
                t = k
                if t < W + 2 * dist:
                    x, z, yaw = -dist + t, -dist, 0
                elif t < W + Hh + 4 * dist:
                    x, z, yaw = W + dist, -dist + (t - W - 2 * dist), 90
                elif t < 2 * W + Hh + 6 * dist:
                    x, z, yaw = W + dist - (t - W - Hh - 4 * dist), Hh + dist, 0
                else:
                    x, z, yaw = -dist, Hh + dist - (t - 2 * W - Hh - 6 * dist), 90
                if kind == "trees":
                    self.cutout_tree(parent, x, z, shade, scale)
                    continue
                if kind == "houses":
                    w, h = rng.uniform(18, 30) * scale, rng.uniform(10, 16) * scale
                else:
                    w, h = rng.uniform(20, 40) * scale, rng.uniform(30, 110) * scale
                col = tuple(int(c * shade) for c in (60, 64, 72))
                rot = rbx.rot_y(yaw)
                rbx.part(parent, "Silueta", (x, h / 2 - 2, z), (w, h, 0.5), col, rot=rot, **kw)
                if kind == "houses":
                    p = rbx.part(parent, "Tejado", (x, h + h * 0.2 - 2, z), (0.5, h * 0.4, w * 0.75), col, cls="WedgePart",
                                 rot=rbx.mat_mul(rot, rbx.rot_y(90)), **kw)
                # ventanas encendidas (pocas, Neon cálido): leen como ciudad lejana en la niebla
                for i in range(rng.randint(1, 4 if kind == "city" else 2)):
                    wx = rng.uniform(-w / 2 + 2, w / 2 - 2)
                    wy = rng.uniform(4, h - 4)
                    off = rbx.mat_apply(rot, (wx, 0, -0.3))
                    rbx.part(parent, "Ventana", (x + off[0], wy, z + off[2]), (1.6 * scale, 1.8 * scale, 0.2),
                             rng.choice([(255, 210, 140), (230, 230, 200), (160, 200, 255)]), "Neon", rot=rot, **kw)

    def build(self):
        self.prepare()
        self.structure()
        self.lights()
        self.decor()
        self.markers()
        self.boundaries()
        for s in self.lay.spaces:
            if s.kind in ("room", "hall") and s.cells and s.data.get("type") and s.data.get("label", True):
                x0, x1, z0, z1 = s.rect()
                l = min(c[0] for c in s.cells)
                self.labels.append((s.data["type"], (x0 + x1 + 1) / 2 * C, (z0 + z1 + 1) / 2 * C, l))
        self.B.root.props["primary"] = self.dock
        return self.B

    def prepare(self):
        self.choose_puzzles()

    def boundaries(self):
        pass


from props import DEPTH_EXTRA, Props  # noqa: E402


class Building(Props, ArchLevel):
    DEPTH = {**ArchLevel.DEPTH, **DEPTH_EXTRA}
    ROOM_DECOR: dict = {}

    def decor_room(self, p, s, slots):
        """Decoración por tipo de sala: ROOM_DECOR[tipo] = (muebles contra muro, fracción de huecos, [(suelto, ancho, fondo, n)])."""
        t = s.data.get("type", "")
        spec = self.ROOM_DECOR.get(t) or self.ROOM_DECOR.get(t.split(" ")[0]) or (["cabinet", "shelf", "crates"], 0.4, [])
        wall, frac, free = spec
        if wall == "lockers":
            n = 0
            for (c, d) in slots:
                for off in (-3.4, 0, 3.4):
                    fr = against_wall(self.B, c, d, 2.8)
                    dx, dz = DIRS[(d + 1) % 4]
                    fr.pos = (fr.pos[0] + dx * off, fr.pos[1], fr.pos[2] + dz * off)
                    if self.place_locker(p, fr, c, hideable=(n % 2 == 0)):
                        n += 1
                if n >= 10:
                    break
        elif wall:
            self.furnish(p, s, slots, wall, frac)
        cells = len([c for c in s.cells if c not in s.void])
        for (fn, w, d, n) in free:
            count = n if n > 0 else max(1, cells // (-n))
            self.place_free(p, s, getattr(self, fn), w, d, count)


def split(rng, a0, a1, lo=3, hi=6):
    """Parte [a0, a1] (inclusivo) en tramos de lo..hi celdas."""
    out = []
    a = a0
    while a <= a1:
        rest = a1 - a + 1
        n = rest if rest <= hi else rng.randint(lo, min(hi, rest - lo)) if rest - lo >= lo else rest
        out.append((a, a + n - 1))
        a += n
    return out


def wing(P: Plan, rng, name, axis, a0, a1, outer, corr, inner, layers, room_type, stairs=("start", "end"), roof_layer=None,
         size=(3, 6), p_inner_door=0.25, facade="std"):
    """Ala de edificio: pasillo a lo largo (corr = (c0, c1) en el eje transversal), banda de salas exterior (outer) con las cajas
    de escalera pegadas al pasillo, y banda interior (inner, opcional). room_type(l, banda, i, tramo) -> tipo o None (sala sin tipo).
    axis 'x': el ala corre a lo largo de X (transversal = Z); axis 'z': a lo largo de Z."""
    def XZ(al, ac):
        return (al, ac) if axis == "x" else (ac, al)

    def rect(l, al0, al1, ac0, ac1, kind, nm, **data):
        x0, z0 = XZ(al0, ac0)
        x1, z1 = XZ(al1, ac1)
        return P.area(kind, nm, l, x0, z0, x1, z1, facade=facade, **data)

    o0, o1 = outer
    c0, c1 = corr
    lmin, lmax = layers[0], layers[-1]
    top = roof_layer if roof_layer is not None else lmax
    wells = []
    stair_spans = []
    if o1 < c0:
        origin, flip = o1 - 1, False
    else:
        origin, flip = o0 + 1, True
    for where in stairs:
        s0 = a0 if where == "start" else (a1 - 4 if where == "end" else where)
        stair_spans.append((s0, s0 + 4))
        if axis == "x":
            wells.append(P.stairwell(s0, origin, lmin, top, axis="x", name=f"Escalera {name}", flip=flip))
        else:
            wells.append(P.stairwell(origin, s0, lmin, top, axis="z", name=f"Escalera {name}", flip=flip))
    out = {"corr": {}, "rooms": {}, "wells": wells, "roof": None}
    for l in layers:
        corrs = rect(l, a0, a1, c0, c1, "corridor", f"Pasillo {name} P{l}")
        out["corr"][l] = corrs
        rooms = []
        # banda exterior: entre escaleras, salas a todo el fondo; junto a cada escalera, un cuarto con el fondo que sobra
        spans = []
        cur = a0
        for (s0, s1) in sorted(stair_spans):
            if s0 > cur:
                spans.append((cur, s0 - 1))
            cur = s1 + 1
        if cur <= a1:
            spans.append((cur, a1))
        band = []
        for (b0, b1) in spans:
            for (r0, r1) in split(rng, b0, b1, *size):
                t = room_type(l, "outer", len(band), (r0, r1))
                band.append(rect(l, r0, r1, o0, o1, "room", f"{t or 'Sala'} {name}{l}-{len(band)}", type=t))
        extra = []
        depth_left = (o1 - o0 + 1) - 2
        if depth_left > 0:
            for (s0, s1) in stair_spans:
                ac0, ac1 = (o0, o1 - 2) if not flip else (o0 + 2, o1)
                t = room_type(l, "small", len(extra), (s0, s1))
                extra.append(rect(l, s0, s1, ac0, ac1, "room", f"{t or 'Cuarto'} {name}{l}-e{len(extra)}", type=t))
        inner_band = []
        if inner:
            i0, i1 = inner
            for (r0, r1) in split(rng, a0, a1, *size):
                t = room_type(l, "inner", len(inner_band), (r0, r1))
                inner_band.append(rect(l, r0, r1, i0, i1, "room", f"{t or 'Sala'} {name}{l}-i{len(inner_band)}", type=t))
        for r in band + inner_band:
            P.connect(r, corrs)
        for r in extra:
            nb = [b for b in band if P.shared(r, b)]
            if nb:
                P.connect(r, nb[0])
            else:
                for w in wells:
                    if l in w and P.shared(r, w[l]):
                        P.connect(r, w[l])
                        break
        for seq in (band, inner_band):
            for r1_, r2_ in zip(seq, seq[1:]):
                if rng.random() < p_inner_door and P.shared(r1_, r2_):
                    P.connect(r1_, r2_)
        for w in wells:
            if l in w:
                P.connect(w[l], corrs)
        rooms += band + extra + inner_band
        out["rooms"][l] = rooms
    if roof_layer is not None:
        lo_ac = min(o0, c0, *(inner or (c0,)))
        hi_ac = max(o1, c1, *(inner or (c1,)))
        x0, z0 = XZ(a0, lo_ac)
        x1, z1 = XZ(a1, hi_ac)
        occupied = {(x, z) for (l, x, z) in P.occ if l == roof_layer}
        roof = P.area("room", f"Azotea {name}", roof_layer, x0, z0, x1, z1, outdoor=True, exclude=occupied, roof=True,
                      edge="parapet", ground="roof", type="Azotea", label=False)
        for w in wells:
            if roof_layer in w:
                P.connect(w[roof_layer], roof)
        out["roof"] = roof
    return out
