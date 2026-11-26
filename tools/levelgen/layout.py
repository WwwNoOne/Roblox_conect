"""Planta de un nivel en rejilla de celdas con dos alturas (layer 0 = planta baja, layer 1 = segundo piso).

La red crece como una raíz desde el acople del ascensor: pasillos que se alargan, giran y echan ramas laterales; en los extremos
aparecen salas (nodos del grafo) que a su vez sacan más pasillos. Algunas salas grandes son de doble altura y las cruza una pasarela
del segundo piso. Las escaleras suben y bajan entre plantas. Al final se abren atajos de una celda entre espacios lejanos en el
recorrido (bucles: grafo, no árbol) y se poda lo que no se alcanza desde el ascensor.

Regla de separación: un espacio nuevo nunca toca de lado a otro espacio salvo por la celda de la que sale. Así entre dos espacios
siempre queda al menos una celda maciza (muros gruesos, sin pasillos pegados) y las uniones son siempre explícitas (links).
"""
from __future__ import annotations

import random
from collections import deque
from dataclasses import dataclass, field

DIRS = [(0, 1), (1, 0), (0, -1), (-1, 0)]
WALKABLE_KINDS = {"corridor", "room", "hall", "hub", "stair", "catwalk", "closet"}


@dataclass
class Space:
    sid: int
    kind: str  # hub, shaft, corridor, room, hall, stair, catwalk, closet
    name: str = ""
    cells: set = field(default_factory=set)  # (l, x, z)
    void: set = field(default_factory=set)  # celdas sin suelo (hueco de escalera, aire de nave de doble altura)
    data: dict = field(default_factory=dict)

    def rect(self, layer=None):
        cs = [(x, z) for (l, x, z) in self.cells if layer is None or l == layer]
        xs = [c[0] for c in cs]
        zs = [c[1] for c in cs]
        return min(xs), max(xs), min(zs), max(zs)


@dataclass
class Tip:
    l: int
    x: int
    z: int
    d: int  # índice en DIRS
    prev: tuple  # (l, x, z) celda de la que sale
    sid: int | None  # espacio de pasillo que continúa (None = nuevo)
    depth: int


def add(c, d, n=1):
    return (c[0] + DIRS[d][0] * n, c[1] + DIRS[d][1] * n)


class Layout:
    def __init__(self, w: int, h: int, seed: int, layers: int = 2, margin: int = 3):
        self.w, self.h, self.layers, self.margin = w, h, layers, margin
        self.rng = random.Random(seed)
        self.occ: dict = {}
        self.spaces: list[Space] = []
        self.links: dict = {}  # frozenset({a, b}) -> "open" | "door" | "puzzle" | "rail"
        self.stairs: list[dict] = []
        self.tips: deque = deque()
        self.params = dict(seg=(3, 7), p_turn=0.45, p_branch=0.25, p_room=0.30, p_side=0.10, p_stairs=0.10,
                           p_down=0.18, room=(3, 6), hall=(6, 9), p_hall=0.22, room_exits=(0, 2), budget=1500,
                           loops=10, loop_gap=14, layer1_budget=0.30, p_closet=0.35)
        self.hub = None
        self.shaft = None

    # ------------------------------------------------------------------ utilidades
    def inb(self, x, z):
        m = self.margin
        return m <= x < self.w - m and m <= z < self.h - m

    def space_of(self, c) -> Space | None:
        sid = self.occ.get(c)
        return self.spaces[sid] if sid is not None else None

    def can_take(self, l, x, z, allow=()) -> bool:
        if not self.inb(x, z) or (l, x, z) in self.occ:
            return False
        for d in range(4):
            nx, nz = add((x, z), d)
            n = (l, nx, nz)
            if n in self.occ and n not in allow:
                return False
        return True

    def new_space(self, kind, name="") -> Space:
        s = Space(len(self.spaces), kind, name)
        self.spaces.append(s)
        return s

    def take(self, s: Space, c, void=False):
        self.occ[c] = s.sid
        s.cells.add(c)
        if void:
            s.void.add(c)

    def link(self, a, b, kind="open"):
        self.links[frozenset((a, b))] = kind

    def link_kind(self, a, b):
        return self.links.get(frozenset((a, b)))

    def cell_count(self, layer=None):
        return sum(1 for c, sid in self.occ.items() if (layer is None or c[0] == layer) and c not in self.spaces[sid].void)

    # ------------------------------------------------------------------ acople
    def place_hub(self, hub_w=7, hub_d=5, shaft_w=3, shaft_d=4):
        cx, cz = self.w // 2, self.h // 2
        shaft = self.new_space("shaft", "Acople")
        for x in range(cx - shaft_w // 2, cx + shaft_w // 2 + 1):
            for z in range(cz - shaft_d, cz):
                for l in range(self.layers):
                    self.take(shaft, (l, x, z), void=(l > 0))
        hub = self.new_space("hub", "Vestíbulo")
        x0 = cx - hub_w // 2
        for x in range(x0, x0 + hub_w):
            for z in range(cz, cz + hub_d):
                self.take(hub, (0, x, z))
        for x in range(cx - shaft_w // 2, cx + shaft_w // 2 + 1):
            self.link((0, x, cz - 1), (0, x, cz), "open")
        self.hub, self.shaft = hub, shaft
        mid = cz + hub_d // 2
        self.tips.append(Tip(0, x0 - 1, mid, 3, (0, x0, mid), None, 0))
        self.tips.append(Tip(0, x0 + hub_w, mid, 1, (0, x0 + hub_w - 1, mid), None, 0))
        self.tips.append(Tip(0, cx, cz + hub_d, 0, (0, cx, cz + hub_d - 1), None, 0))
        # Salidas laterales hacia el norte, por detrás del hueco del ascensor
        self.tips.append(Tip(0, x0, cz - 1, 2, (0, x0, cz), None, 0))
        self.tips.append(Tip(0, x0 + hub_w - 1, cz - 1, 2, (0, x0 + hub_w - 1, cz), None, 0))
        return hub

    # ------------------------------------------------------------------ crecimiento
    def _door_kind(self, prev):
        s = self.space_of(prev)
        return "door" if s and s.kind in ("room", "hall", "hub") else "open"

    def grow(self):
        P = self.params
        budget = P["budget"]
        guard = 0
        while self.tips and self.cell_count() < budget and guard < 20000:
            guard += 1
            # Mezcla: casi siempre la punta más antigua (crecimiento a lo ancho, raíz) y a veces una al azar (ramas largas)
            if self.rng.random() < 0.35 and len(self.tips) > 1:
                i = self.rng.randrange(len(self.tips))
                self.tips.rotate(-i)
            tip = self.tips.popleft()
            self._grow_tip(tip)

    def _grow_tip(self, tip: Tip):
        P, rng = self.params, self.rng
        l = tip.l
        if l == 1 and self.cell_count(1) > P["budget"] * P["layer1_budget"]:
            if not self._try_stairs(tip, down=True):
                self._closet(tip)
            return
        # Intentos especiales al principio de un tramo
        r = rng.random()
        if tip.depth > 1 and l == 0 and r < P["p_stairs"] and self._try_stairs(tip, down=False):
            return
        if l == 1 and r < P["p_down"] and self._try_stairs(tip, down=True):
            return
        sp = self.spaces[tip.sid] if tip.sid is not None else self.new_space("corridor")
        n = rng.randint(*P["seg"])
        prev = tip.prev
        placed = []
        c = (tip.x, tip.z)
        for i in range(n):
            if not self.can_take(l, c[0], c[1], allow=(prev,)):
                break
            cell = (l, c[0], c[1])
            self.take(sp, cell)
            if i == 0 and prev in self.occ and self.occ[prev] != sp.sid:
                self.link(prev, cell, self._door_kind(prev))
            placed.append(cell)
            prev = cell
            c = add(c, tip.d)
        if not placed:
            if tip.sid is None and not sp.cells:
                self.spaces.pop() if sp.sid == len(self.spaces) - 1 else None
            if tip.prev in self.occ and self.space_of(tip.prev).kind == "corridor":
                self._closet(tip)
            return
        last = placed[-1]
        depth = tip.depth + 1
        # Ramas laterales a lo largo del tramo (forma de raíz)
        for cell in placed[1:-1]:
            if rng.random() < P["p_side"]:
                sd = (tip.d + rng.choice((1, 3))) % 4
                nx, nz = add((cell[1], cell[2]), sd)
                self.tips.append(Tip(l, nx, nz, sd, cell, None, depth))
        r = rng.random()
        nxt = add((last[1], last[2]), tip.d)
        if r < P["p_room"]:
            if self._try_room(Tip(l, nxt[0], nxt[1], tip.d, last, None, depth)):
                return
        r = rng.random()
        if r < P["p_branch"]:
            for sd in ((tip.d + 1) % 4, (tip.d + 3) % 4):
                nx, nz = add((last[1], last[2]), sd)
                self.tips.append(Tip(l, nx, nz, sd, last, None, depth))
            if rng.random() < 0.4:
                self.tips.append(Tip(l, nxt[0], nxt[1], tip.d, last, sp.sid, depth))
        elif r < P["p_branch"] + P["p_turn"]:
            sd = (tip.d + rng.choice((1, 3))) % 4
            nx, nz = add((last[1], last[2]), sd)
            self.tips.append(Tip(l, nx, nz, sd, last, sp.sid, depth))
        else:
            self.tips.append(Tip(l, nxt[0], nxt[1], tip.d, last, sp.sid, depth))

    def _closet(self, tip: Tip):
        """Fondo de saco: un cuartucho de una celda (taquilla, trastero)."""
        if self.rng.random() > self.params["p_closet"]:
            return
        if self.can_take(tip.l, tip.x, tip.z, allow=(tip.prev,)) and tip.prev in self.occ:
            s = self.new_space("closet", "Cuartucho")
            cell = (tip.l, tip.x, tip.z)
            self.take(s, cell)
            self.link(tip.prev, cell, "door")
            s.data["dir"] = tip.d

    def _rect_cells(self, tip: Tip, wid: int, dep: int, off: int):
        """Celdas de un rectángulo que empieza en la punta y avanza `dep` en la dirección de la punta, `wid` de ancho."""
        d = tip.d
        side = (d + 1) % 4
        cells = []
        for a in range(dep):
            for b in range(wid):
                c = add(add((tip.x, tip.z), d, a), side, b - off)
                cells.append(c)
        return cells

    def _free_rect(self, l, cells, allow, layer_check=None):
        cs = set(cells)
        for (x, z) in cells:
            if not self.inb(x, z) or (l, x, z) in self.occ:
                return False
            for d in range(4):
                n = add((x, z), d)
                if n in cs:
                    continue
                if (l, n[0], n[1]) in self.occ and (l, n[0], n[1]) not in allow:
                    return False
        return True

    def _try_room(self, tip: Tip) -> bool:
        P, rng = self.params, self.rng
        l = tip.l
        for attempt in range(6):
            hall = l == 0 and rng.random() < P["p_hall"] and attempt < 3
            lo, hi = P["hall"] if hall else P["room"]
            wid, dep = rng.randint(lo, hi), rng.randint(lo, hi)
            if attempt >= 3:
                wid, dep = max(2, wid - 2), max(2, dep - 2)
            off = rng.randint(0, wid - 1)
            cells = self._rect_cells(tip, wid, dep, off)
            if not self._free_rect(l, cells, allow=(tip.prev,)):
                continue
            if hall and not self._free_rect(1, cells, allow=()):
                hall = False
                if wid > P["room"][1] + 1 or dep > P["room"][1] + 1:
                    continue
            s = self.new_space("hall" if hall else "room")
            for (x, z) in cells:
                self.take(s, (l, x, z))
                if hall:
                    self.take(s, (1, x, z), void=True)
            first = (l, tip.x, tip.z)
            self.link(tip.prev, first, self._door_kind(tip.prev) if self.space_of(tip.prev).kind != "corridor" else "door")
            s.data.update(dir=tip.d, door=first, wid=wid, dep=dep)
            if hall:
                self._catwalk(s, cells, tip)
            self._room_exits(s, l, cells, tip.depth)
            return True
        return False

    def _catwalk(self, s: Space, cells, tip: Tip):
        """Pasarela del segundo piso que cruza la nave de lado a lado, con escalera propia desde el suelo de la nave, y que sigue
        como pasillo alto por ambos extremos."""
        xs = [c[0] for c in cells]
        zs = [c[1] for c in cells]
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        along_x = self.rng.random() < 0.5
        if along_x and z1 - z0 < 4 or (not along_x and x1 - x0 < 4):
            along_x = not along_x
        if along_x:
            zr = self.rng.choice([z0 + 1, z1 - 1])
            row = [(x, zr) for x in range(x0, x1 + 1)]
            ends = [((x0, zr), 3), ((x1, zr), 1)]
            sd = 2 if zr == z0 + 1 else 0  # la escalera sube hacia la fila de la pasarela
            xs_ = self.rng.randint(x0 + 1, x1 - 1)
            stair = [(xs_, zr - 3 * (1 if sd == 0 else -1) + i * (1 if sd == 0 else -1)) for i in range(3)]
        else:
            xr = self.rng.choice([x0 + 1, x1 - 1])
            row = [(xr, z) for z in range(z0, z1 + 1)]
            ends = [((xr, z0), 2), ((xr, z1), 0)]
            sd = 3 if xr == x0 + 1 else 1
            zs_ = self.rng.randint(z0 + 1, z1 - 1)
            stair = [(xr - 3 * (1 if sd == 1 else -1) + i * (1 if sd == 1 else -1), zs_) for i in range(3)]
        cw = self.new_space("catwalk", "Pasarela")
        st = self.new_space("stair", "Escalera de la nave")
        for (x, z) in row:
            c = (1, x, z)
            s.cells.discard(c)
            s.void.discard(c)
            self.take(cw, c)
        for i, (x, z) in enumerate(stair):
            lo = (0, x, z)
            s.cells.discard(lo)
            self.take(st, lo)
            if i >= 1:
                hi = (1, x, z)
                s.cells.discard(hi)
                s.void.discard(hi)
                self.take(st, hi, void=True)
        # uniones: pie de la escalera abierto a la nave; costados con barandilla; cabeza a la pasarela
        for i, (x, z) in enumerate(stair):
            for d in range(4):
                n = add((x, z), d)
                if (0, n[0], n[1]) not in s.cells:
                    continue
                if i == 0:
                    self.link((0, x, z), (0, n[0], n[1]), "open")
                elif d not in (sd, (sd + 2) % 4):
                    # costados: barandilla; el frente del último peldaño queda como muro bajo (llega a la pasarela)
                    self.link((0, x, z), (0, n[0], n[1]), "rail")
        top = stair[2]
        self.link((1, top[0], top[1]), (1, top[0] + DIRS[sd][0], top[1] + DIRS[sd][1]), "open")
        for (x, z) in row:
            for d in range(4):
                n = add((x, z), d)
                nc = (1, n[0], n[1])
                if nc in s.void or (nc in st.void and n != top):
                    self.link((1, x, z), nc, "rail")
        st.data.update(dir=sd, cells=stair, high_end=2, low_layer=0, inner=True)
        self.stairs.append(st.data | {"sid": st.sid})
        cw.data["hall"] = s.sid
        s.data["catwalk"] = cw.sid
        for (c, d) in ends:
            n = add(c, d)
            self.tips.appendleft(Tip(1, n[0], n[1], d, (1, c[0], c[1]), None, 1))

    def _room_exits(self, s: Space, l, cells, depth):
        lo, hi = self.params["room_exits"]
        k = self.rng.randint(lo, hi)
        if s.kind == "hall":
            k += 1
        cs = set(cells)
        edges = []
        for (x, z) in cells:
            for d in range(4):
                n = add((x, z), d)
                if n not in cs:
                    edges.append(((x, z), d, n))
        self.rng.shuffle(edges)
        for (c, d, n) in edges[:k]:
            self.tips.append(Tip(l, n[0], n[1], d, (l, c[0], c[1]), None, depth + 1))

    def _try_stairs(self, tip: Tip, down: bool) -> bool:
        if self.layers < 2:
            return False
        d = tip.d
        f = [(tip.x, tip.z), add((tip.x, tip.z), d), add((tip.x, tip.z), d, 2)]
        land = add(f[2], d)
        if down:
            if tip.l != 1:
                return False
            low_cells = [(0, x, z) for (x, z) in f]
            void = [(1, f[0][0], f[0][1]), (1, f[1][0], f[1][1])]
            landing = (0, land[0], land[1])
            # planta baja: libre y sin vecinos
            if not self._free_rect(0, f, allow=()):
                return False
            if not self._free_rect(1, f[:2], allow=(tip.prev,)):
                return False
            if not self.can_take(0, landing[1], landing[2], allow=((0, f[2][0], f[2][1]),)):
                return False
            s = self.new_space("stair", "Escalera")
            for c in low_cells:
                self.take(s, c)
            for c in void:
                self.take(s, c, void=True)
            self.link(tip.prev, void[0], "open")
            s.data.update(dir=d, cells=f, high_end=0, low_layer=0)
            self.stairs.append(s.data | {"sid": s.sid})
            self._landing(landing, low_cells[2], d, tip.depth + 1)
            return True
        if tip.l != 0:
            return False
        if not self._free_rect(0, f, allow=(tip.prev,)):
            return False
        if not self._free_rect(1, f[1:], allow=()):
            return False
        if (1, f[0][0], f[0][1]) in self.occ:
            return False
        if not self.can_take(1, land[0], land[1], allow=((1, f[2][0], f[2][1]),)):
            return False
        s = self.new_space("stair", "Escalera")
        for (x, z) in f:
            self.take(s, (0, x, z))
        for (x, z) in f[1:]:
            self.take(s, (1, x, z), void=True)
        self.link(tip.prev, (0, f[0][0], f[0][1]), "open" if self.space_of(tip.prev).kind == "corridor" else "door")
        s.data.update(dir=d, cells=f, high_end=2, low_layer=0)
        self.stairs.append(s.data | {"sid": s.sid})
        self._landing((1, land[0], land[1]), (1, f[2][0], f[2][1]), d, tip.depth + 1)
        return True

    def _landing(self, cell, top, d, depth):
        """Rellano: se ocupa y se une a la escalera en el acto (si quedara como punta pendiente, otro pasillo podría quitarle la
        celda sin unirse y la escalera acabaría contra un muro)."""
        lc = self.new_space("corridor", "Rellano")
        self.take(lc, cell)
        self.link(top, cell, "open")
        n = add((cell[1], cell[2]), d)
        self.tips.appendleft(Tip(cell[0], n[0], n[1], d, cell, lc.sid, depth))

    # ------------------------------------------------------------------ recorrido
    def neighbors(self, c):
        """Celdas a las que se puede pasar andando desde c (mismo espacio o unión; la escalera une sus dos plantas)."""
        s = self.space_of(c)
        if s is None:
            return
        l, x, z = c
        for d in range(4):
            n = (l, x + DIRS[d][0], z + DIRS[d][1])
            if n not in self.occ:
                continue
            ns = self.space_of(n)
            k = self.link_kind(c, n)
            if k == "rail":
                continue
            if ns.sid == s.sid or k in ("open", "door", "puzzle"):
                if n in ns.void and ns.kind != "stair":
                    continue
                yield n
        if s.kind == "stair":
            for dl in (-1, 1):
                v = (l + dl, x, z)
                if v in s.cells:
                    yield v

    def bfs(self, start):
        dist = {start: 0}
        q = deque([start])
        while q:
            c = q.popleft()
            for n in self.neighbors(c):
                if n not in dist:
                    dist[n] = dist[c] + 1
                    q.append(n)
        return dist

    def hub_cell(self):
        cx, cz = self.w // 2, self.h // 2
        return (0, cx, cz)

    def prune(self):
        """Quita lo que no se alcanza desde el acople (las pasarelas sueltas vuelven a ser aire de la nave)."""
        dist = self.bfs(self.hub_cell())
        for s in self.spaces:
            if s.kind in ("shaft",) or not s.cells:
                continue
            reach = any(c in dist for c in s.cells if c not in s.void or s.kind == "stair")
            if s.kind == "catwalk" and not reach:
                hall = self.spaces[s.data["hall"]]
                for c in list(s.cells):
                    self.occ[c] = hall.sid
                    hall.cells.add(c)
                    hall.void.add(c)
                s.cells.clear()
                hall.data.pop("catwalk", None)
            elif not reach:
                for c in s.cells:
                    self.occ.pop(c, None)
                s.cells.clear()
                s.void.clear()
        self.links = {k: v for k, v in self.links.items() if all(c in self.occ for c in k)}
        self.stairs = [st for st in self.stairs if self.spaces[st["sid"]].cells]
        return dist

    def add_loops(self):
        """Atajos de una celda entre dos espacios separados por un muro y muy alejados en el recorrido."""
        dist = self.bfs(self.hub_cell())
        cands = []
        for l in range(self.layers):
            for x in range(self.margin, self.w - self.margin):
                for z in range(self.margin, self.h - self.margin):
                    if (l, x, z) in self.occ:
                        continue
                    for (da, db, dc, dd) in ((0, 2, 1, 3), (1, 3, 0, 2)):
                        a = (l, x + DIRS[da][0], z + DIRS[da][1])
                        b = (l, x + DIRS[db][0], z + DIRS[db][1])
                        c1 = (l, x + DIRS[dc][0], z + DIRS[dc][1])
                        c2 = (l, x + DIRS[dd][0], z + DIRS[dd][1])
                        if a in dist and b in dist and c1 not in self.occ and c2 not in self.occ:
                            sa, sb = self.space_of(a), self.space_of(b)
                            if sa.kind in ("stair", "shaft", "closet") or sb.kind in ("stair", "shaft", "closet"):
                                continue
                            if a in sa.void or b in sb.void:
                                continue
                            gain = abs(dist[a] - dist[b])
                            if gain >= self.params["loop_gap"]:
                                cands.append((gain + self.rng.random() * 8, (l, x, z), a, b))
        cands.sort(reverse=True)
        chosen = []
        for (_, g, a, b) in cands:
            if len(chosen) >= self.params["loops"]:
                break
            if any(abs(g[1] - o[1]) + abs(g[2] - o[2]) < 10 for o in chosen):
                continue
            if g in self.occ:
                continue
            s = self.new_space("corridor", "Atajo")
            self.take(s, g)
            for e in (a, b):
                self.link(e, g, self._door_kind(e) if self.space_of(e).kind != "corridor" else "open")
            chosen.append(g)
        return chosen

    def leaf_rooms(self):
        """Salas con una sola entrada (buenas para puerta con puzzle o caja fuerte)."""
        out = []
        for s in self.spaces:
            if s.kind not in ("room",) or not s.cells:
                continue
            ls = [k for k in self.links if any(c in s.cells for c in k) and self.links[k] != "rail"]
            if len(ls) == 1:
                out.append((s, next(iter(ls))))
        return out

    def summary(self):
        kinds = {}
        for s in self.spaces:
            if s.cells:
                kinds[s.kind] = kinds.get(s.kind, 0) + 1
        return dict(cells0=self.cell_count(0), cells1=self.cell_count(1), spaces=kinds, links=len(self.links), stairs=len(self.stairs))
