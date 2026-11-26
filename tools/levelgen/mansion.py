"""Level_5 · Mansión Valcárcel. Mansión de 3 plantas + sótano + ático: vestíbulo de doble altura con escalera imperial y galería,
escalera de servicio del sótano al ático. Fuera: jardín cerrado por tapia, laberinto de setos y una piscina rodeada de setos."""
from __future__ import annotations

import math

import rbx
from arch import C, H, Building, Plan
from common import Frame, against_wall
from layout import DIRS

THEME = {
    "wall_int": (120, 64, 66), "zocalo": (84, 58, 38), "floor_corr": (112, 78, 52), "floor_default": (124, 88, 58),
    "ceil": (196, 186, 166), "roof": (60, 62, 72), "facade_default": (206, 196, 176), "glass": (150, 170, 160),
    "frame": (230, 226, 216), "cornice": (170, 160, 146), "parapet": (180, 170, 156), "rail": (90, 60, 40),
    "door_frame": (80, 50, 30), "stair": (110, 40, 44), "stair_edge": (200, 170, 90), "outwall": (126, 120, 110), "wall_h": 13,
    "hedge": (40, 82, 46), "hedge_h": 11,
    "ground": {"lawn": ((60, 92, 54), "Grass"), "gravel": ((150, 140, 126), "SmoothPlastic"), "maze": ((70, 100, 60), "Grass")},
    "floor_room": {"Cocina": (180, 176, 160), "Baño": (210, 214, 206), "Bodega": (96, 80, 66), "Calderas": (90, 90, 90),
                   "Desván": (120, 100, 76), "Salón de baile": (160, 120, 80)},
    "street_light": (255, 190, 120),
}
WALLPAPER = [(120, 64, 66), (70, 96, 80), (96, 84, 120), (150, 130, 96)]


class Mansion(Building):
    NAME = "Level_5"
    THEME = THEME
    ROOM_DECOR = {
        "Comedor": (["fireplace", "painting", "grandclock", "painting"], 0.4, [("long_table", 15, 9, 1)]),
        "Salón": (["sofa", "fireplace", "painting", "sofa", "painting"], 0.6, []),
        "Biblioteca": (["bookcase", "bookcase", "bookcase", "desk", "bookcase"], 0.8, []),
        "Sala de música": (["piano", "sofa", "painting"], 0.5, []),
        "Estudio": (["desk", "bookcase", "painting", "cabinet"], 0.6, []),
        "Cocina": (["kitchen", "fridge", "stove", "shelf_rustic", "kitchen"], 0.7, [("table_rustic_free", 6, 4, 1)]),
        "Despensa": (["shelf_rustic", "shelf_rustic", "crates"], 0.7, []),
        "Dormitorio": (["bed_rustic", "wardrobe", "painting", "fireplace"], 0.5, []),
        "Dormitorio principal": (["bed_rustic", "wardrobe", "wardrobe", "fireplace", "painting"], 0.6, []),
        "Baño": (["bathtub", "sink_row", "stall"], 0.6, []),
        "Vestidor": (["wardrobe", "wardrobe", "wardrobe"], 0.8, []),
        "Cuarto de juegos": (["trunk", "crates", "painting"], 0.5, []),
        "Habitación de invitados": (["bed_rustic", "wardrobe", "painting"], 0.5, []),
        "Galería de arte": (["painting", "painting", "painting"], 0.9, []),
        "Sala de billar": (["painting", "cabinet"], 0.3, [("table_rustic_free", 6, 4, 1)]),
        "Salón de baile": (["grandclock", "painting", "piano", "sofa", "painting"], 0.5, []),
        "Desván": (["trunk", "wardrobe", "shelf_rustic", "crates", "trunk"], 0.6, [("trunk_free", 4, 3, -12)]),
        "Cuarto cerrado": (["trunk", "painting"], 0.5, []),
        "Bodega": (["shelf_rustic", "shelf_rustic", "crates"], 0.8, []),
        "Calderas": (["boiler", "boiler", "crates"], 0.5, []),
        "Celda": (["bed_rustic"], 0.2, []),
        "Almacén": (["crates", "shelf", "trunk"], 0.6, []),
        "Vestíbulo": (["grandclock", "painting", "sofa"], 0.3, []),
    }

    # ---------------------------------------------------------------- planta
    def plan(self) -> Plan:
        rng = self.rng
        P = Plan(76, 76, self.seed, -1, 3)
        R = {}

        def room(l, t, x0, z0, x1, z1, **kw):
            s = P.area("room", t, l, x0, z0, x1, z1, type=t, wall=rng.choice(WALLPAPER), **kw)
            R[(l, t)] = s
            return s

        # escalera de servicio (sótano -> ático), pegada al vestíbulo/galería por x = 43
        wells = P.stairwell(45, 22, -1, 3, axis="z", name="Escalera de servicio", flip=True)
        # --- Sótano
        corrB = P.area("corridor", "Pasillo del sótano", -1, 36, 12, 43, 33, facade="blind")
        for t, r in (("Bodega", (28, 12, 35, 23)), ("Calderas", (28, 24, 35, 33)), ("Almacén", (44, 12, 51, 21)),
                     ("Celda", (46, 22, 51, 33))):
            room(-1, t, *r, facade="blind")
        P.extend(R[(-1, "Celda")], -1, 44, 27, 45, 33)
        for t in ("Bodega", "Calderas", "Almacén", "Celda"):
            P.connect(R[(-1, t)], corrB)
        P.connect(wells[-1], corrB)
        # --- Planta baja: vestíbulo de doble altura con escalera imperial
        stair_cells = {(x, z) for x in (39, 40) for z in (23, 24, 25)}
        hall = P.area("hall", "Vestíbulo", 0, 36, 22, 43, 33, type="Vestíbulo", wall=(150, 130, 96), exclude=stair_cells)
        gal0 = P.area("corridor", "Galería", 0, 28, 20, 51, 21)
        P.open_between(hall, gal0)
        for t, r in (("Comedor", (28, 12, 35, 19)), ("Salón", (36, 12, 43, 19)), ("Biblioteca", (44, 12, 51, 19))):
            P.connect(room(0, t, *r), gal0)
        for t, r in (("Sala de música", (28, 22, 35, 27)), ("Estudio", (28, 28, 35, 33))):
            s = room(0, t, *r)
            P.connect(s, hall)
        P.connect(R[(0, "Sala de música")], gal0)
        cocina = room(0, "Cocina", 46, 22, 51, 27)
        P.connect(cocina, gal0)
        despensa = room(0, "Despensa", 44, 28, 51, 33)
        P.connect(despensa, cocina)
        P.connect(wells[0], hall)
        # --- Planta 1: galería alrededor del hueco del vestíbulo
        void = {(x, z) for x in range(37, 43) for z in range(23, 33)} - {(39, 24), (39, 23), (40, 24), (40, 23)}
        ring = P.area("corridor", "Galería alta", 1, 36, 22, 43, 33, exclude=void | {(39, 24), (39, 23), (40, 24), (40, 23)})
        P.extend(ring, 1, 28, 20, 51, 21)
        for (x, z) in sorted(void):
            P.take(hall, (1, x, z), void=True)
        for xs in (39, 40):
            f = P.flight(0, [(xs, 25), (xs, 24), (xs, 23)], 2, name="Escalera imperial", inner=True)
            P.link((0, xs, 26), (0, xs, 25), "open")
            P.link((1, xs, 23), (1, xs, 22), "open")
            for (x, z) in [(xs, 25), (xs, 24), (xs, 23)]:
                for d in range(4):
                    n = (0, x + DIRS[d][0], z + DIRS[d][1])
                    if n in hall.cells and d in (1, 3) and z != 25:
                        P.link((0, x, z), n, "rail")
                    elif n in hall.cells and z == 25 and d in (1, 3):
                        P.link((0, x, z), n, "open")
        for (x, z) in sorted(void):
            for d in range(4):
                n = (1, x + DIRS[d][0], z + DIRS[d][1])
                if n in ring.cells:
                    P.link((1, x, z), n, "rail")
        for t, r in (("Dormitorio principal", (28, 12, 35, 19)), ("Dormitorio", (36, 12, 43, 19)), ("Baño", (44, 12, 47, 19)),
                     ("Vestidor", (48, 12, 51, 19))):
            P.connect(room(1, t, *r), ring)
        P.connect(R[(1, "Vestidor")], R[(1, "Dormitorio principal")]) if False else None
        for t, r in (("Cuarto de juegos", (28, 22, 35, 27)), ("Habitación de invitados", (28, 28, 35, 33))):
            P.connect(room(1, t, *r), ring)
        bano1 = P.area("room", "Baño de invitados", 1, 46, 22, 51, 26, type="Baño", wall=(200, 210, 206))
        P.connect(bano1, ring) if P.shared(bano1, ring) else None
        cost = room(1, "Habitación de invitados ", 44, 27, 51, 33)
        cost.data["type"] = "Habitación de invitados"
        P.connect(cost, ring)
        P.connect(bano1, cost)
        P.connect(wells[1], ring)
        # --- Planta 2
        corr2 = P.area("corridor", "Pasillo P2", 2, 28, 20, 51, 21)
        P.extend(corr2, 2, 42, 22, 43, 27)
        for t, r in (("Galería de arte", (28, 12, 35, 19)), ("Sala de billar", (36, 12, 43, 19)), ("Dormitorio", (44, 12, 51, 19))):
            P.connect(room(2, t, *r), corr2)
        baile = room(2, "Salón de baile", 28, 22, 41, 33)
        P.connect(baile, corr2, n=2)
        P.extend(baile, 2, 42, 28, 43, 33)
        criada = P.area("room", "Cuarto de la criada", 2, 46, 22, 51, 33, type="Dormitorio", wall=(150, 130, 96))
        P.extend(criada, 2, 44, 27, 45, 33)
        P.connect(criada, corr2)
        P.connect(wells[2], corr2)
        # --- Ático (techo bajo)
        occupied3 = {(x, z) for (l, x, z) in P.occ if l == 3}
        cerrado = room(3, "Cuarto cerrado", 28, 12, 31, 15, ceil=8.5)
        desvan = P.area("room", "Desván", 3, 28, 12, 51, 33, exclude=occupied3 | {(x, z) for x in range(28, 32) for z in range(12, 16)},
                        type="Desván", ceil=8.5, wall=(120, 100, 76), zocalo=(90, 70, 50))
        P.connect(cerrado, desvan)
        P.connect(wells[3], desvan)
        # --- Exteriores
        house = {(x, z) for x in range(28, 52) for z in range(12, 34)}
        maze_r = (54, 30, 71, 69)
        pool_r = (6, 40, 21, 55)
        maze_cells = {(x, z) for x in range(maze_r[0], maze_r[2] + 1) for z in range(maze_r[1], maze_r[3] + 1)}
        pool_cells = {(x, z) for x in range(pool_r[0], pool_r[2] + 1) for z in range(pool_r[1], pool_r[3] + 1)}
        shaft = {(x, z) for x in range(38, 41) for z in range(42, 46)}
        garden = P.area("hall", "Jardín", 0, 4, 4, 71, 71, outdoor=True, ground="lawn", edge="wall", type="Jardín",
                        exclude=house | maze_cells | pool_cells | shaft)
        P.elevator_shaft(38, 42, garden)
        P.connect(hall, garden)  # puerta principal (fachada sur)
        P.connect(despensa, garden)  # puerta de servicio
        maze = P.area("hall", "Laberinto", 0, *maze_r, outdoor=True, ground="maze", edge="hedge", type="Laberinto")
        pool = P.area("hall", "Jardín de la piscina", 0, *pool_r, outdoor=True, ground="gravel", edge="hedge", type="Piscina")
        P.connect(pool, garden, at=(21, 47))
        P.connect(pool, garden, at=(13, 40))
        self.maze_walls(P, maze, maze_r)
        P.connect(maze, garden, at=(54, 34))
        P.connect(maze, garden, at=(62, 69))
        P.connect(maze, garden, at=(54, 60))
        self.pool_rect = (10, 44, 16, 51)
        pool.data["holes"] = {(x, z) for x in range(10, 17) for z in range(44, 52)}
        self.garden, self.maze, self.pool = garden, maze, pool
        self.hall = hall
        return P

    def maze_walls(self, P, maze, r):
        """Laberinto perfecto (DFS) sobre las celdas, con ~12 % de aberturas extra (bucles) y una plaza central de 4x4."""
        rng = self.rng
        x0, z0, x1, z1 = r
        cells = [(x, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)]
        cx, cz = (x0 + x1) // 2, (z0 + z1) // 2
        plaza = {(x, z) for x in range(cx - 1, cx + 3) for z in range(cz - 1, cz + 3)}
        self.maze_center = ((cx + 1) * C, (cz + 1) * C)
        open_e = set()
        seen = {cells[0]}
        stack = [cells[0]]
        while stack:
            c = stack[-1]
            nbs = [(c[0] + dx, c[1] + dz) for dx, dz in DIRS if (c[0] + dx, c[1] + dz) in maze_cells_set(x0, z0, x1, z1)
                   and (c[0] + dx, c[1] + dz) not in seen]
            if not nbs:
                stack.pop()
                continue
            n = rng.choice(nbs)
            open_e.add(frozenset((c, n)))
            seen.add(n)
            stack.append(n)
        for (x, z) in cells:
            for dx, dz in ((1, 0), (0, 1)):
                n = (x + dx, z + dz)
                if n not in seen:
                    continue
                e = frozenset(((x, z), n))
                if (x, z) in plaza and n in plaza:
                    continue
                if e in open_e or rng.random() < 0.12:
                    continue
                P.blocked.add(frozenset(((0, x, z), (0, n[0], n[1]))))


def maze_cells_set(x0, z0, x1, z1, _cache={}):
    key = (x0, z0, x1, z1)
    if key not in _cache:
        _cache[key] = {(x, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)}
    return _cache[key]


class MansionLevel(Mansion):
    pass


def _extra_methods():
    def table_rustic_free(self, p, fr):
        m = rbx.model(p, "Mesa")
        fr.part(m, "Tablero", (0, 3.0, 0), (6, 0.35, 3.6), (130, 96, 62), "WoodPlanks")
        for sx in (-2.6, 2.6):
            fr.part(m, "Pata", (sx, 1.4, 0), (0.4, 2.8, 3), (92, 68, 44), "Wood")

    def trunk_free(self, p, fr):
        m = rbx.model(p, "Baul")
        fr.part(m, "Cuerpo", (0, 1.2, 0), (4, 2.4, 2.6), (100, 70, 40), "WoodPlanks")
        fr.part(m, "Tapa", (0, 2.6, 0), (4.1, 0.5, 2.7), (80, 56, 32), "Wood")

    Mansion.table_rustic_free = table_rustic_free
    Mansion.trunk_free = trunk_free


_extra_methods()


def _decor_outdoor(self, p, s, slots):
    B, rng = self.B, self.rng
    t = s.data.get("type")
    if t == "Laberinto":
        mx, mz = self.maze_center
        B.block(mx - 7, mx + 7, mz - 7, mz + 7, 0)
        self.gazebo(p, Frame((mx, 0, mz), 0))
        k = 0
        for (c, d) in slots:
            if k >= 10:
                break
            fr = against_wall(B, c, d, 4, inset=0.8)
            a, b = fr.w(-2.5, 0, -2), fr.w(2.5, 0, 2)
            if B.free_spot(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0):
                B.block(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0)
                if rng.random() < 0.6:
                    self.hide_bush(p, fr)
                else:
                    m = rbx.model(p, "Estatua")
                    fr.part(m, "Pedestal", (0, 1.5, 0), (2.4, 3, 2.4), (200, 196, 186), "Marble")
                    fr.ell(m, "Figura", (0, 5.2, 0), (1.6, 4.4, 1.2), (220, 216, 206), "Marble", collide=True, query=True)
                k += 1
        return
    if t == "Piscina":
        x0, z0, x1, z1 = self.pool_rect
        X0, X1, Z0, Z1 = x0 * C, (x1 + 1) * C, z0 * C, (z1 + 1) * C
        depth = 6
        rbx.box(p, "FondoPiscina", X0, X1, -depth - 1, -depth, Z0, Z1, (70, 150, 180))
        for (a, b, c, d) in ((X0 - 1, X0, Z0, Z1), (X1, X1 + 1, Z0, Z1), (X0, X1, Z0 - 1, Z0), (X0, X1, Z1, Z1 + 1)):
            rbx.box(p, "Pared", a, b, -depth, 0, c, d, (90, 170, 200))
        for (a, b, c, d) in ((X0 - 1.5, X1 + 1.5, Z0 - 1.5, Z0), (X0 - 1.5, X1 + 1.5, Z1, Z1 + 1.5), (X0 - 1.5, X0, Z0, Z1),
                             (X1, X1 + 1.5, Z0, Z1)):
            rbx.box(p, "Borde", a, b, 0, 0.3, c, d, (226, 222, 210))
        rbx.box(p, "Agua", X0, X1, -1.4, -1.0, Z0, Z1, (60, 130, 150), "Glass", collide=False, query=False, transparency=0.35,
                reflect=0.2)
        rbx.part(p, "Rampa", ((X0 + X1) / 2, -depth / 2, Z1 - 6), (X1 - X0 - 2, depth, 12), (90, 170, 200), cls="WedgePart",
                 rot=rbx.rot_y(0))
        g = rbx.part(p, "Foco", ((X0 + X1) / 2, -depth + 0.4, (Z0 + Z1) / 2), (2, 0.3, 2), (120, 220, 255), "Neon", collide=False,
                     query=False, shadow=False)
        rbx.light(g, "PointLight", (100, 200, 255), 2, 30)
        B.block(X0 - 2, X1 + 2, Z0 - 2, Z1 + 2, 0)

        def lounger(pp, fr):
            fr.part(pp, "Tumbona", (0, 1.2, 0), (2.4, 0.4, 6), (230, 230, 226))
            fr.part(pp, "Respaldo", (0, 2.0, 2.4), (2.4, 0.3, 2.2), (230, 230, 226), lrot=rbx.rot_x(40), collide=False)
        self.place_free(p, s, lounger, 3, 7, 4, pad=1)
        k = 0
        for (c, d) in slots:
            if k >= 3:
                break
            fr = against_wall(B, c, d, 4, inset=0.8)
            a, b = fr.w(-2.5, 0, -2), fr.w(2.5, 0, 2)
            if B.free_spot(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0):
                B.block(min(a[0], b[0]), max(a[0], b[0]), min(a[2], b[2]), max(a[2], b[2]), 0)
                self.hide_bush(p, fr)
                k += 1
        return
    # Jardín: camino de grava al portón, fuente, estatuas, árboles muertos, bancos, arbustos-escondite, coche viejo
    rbx.box(p, "Camino", 37 * C, 43 * C, 0.0, 0.06, 34 * C, 72 * C, (156, 146, 130), collide=False, query=False, shadow=False)
    B.block(37 * C, 43 * C, 46 * C, 72 * C, 0)
    self.place_free(p, s, self.fountain, 13, 13, 1, pad=3)
    self.place_free(p, s, self.park_bench, 6.5, 2.5, 8, pad=1.5)
    self.place_free(p, s, self.car, 6, 11, 1, pad=2)
    cells = self.free_cells(s, True)
    rng.shuffle(cells)
    nt = nb = 0
    for c in cells:
        l, x, z = c
        cx, cy, cz = B.cell_center(x, z, l)
        if nt < 28 and B.free_spot(cx - 2, cx + 2, cz - 2, cz + 2, 0, pad=3):
            B.block(cx - 2, cx + 2, cz - 2, cz + 2, 0)
            self.tree(p, cx, cz, rng.uniform(0.8, 1.2))
            nt += 1
        elif nb < 10 and B.free_spot(cx - 3, cx + 3, cz - 3, cz + 3, 0, pad=1):
            B.block(cx - 3, cx + 3, cz - 3, cz + 3, 0)
            self.hide_bush(p, Frame((cx, 0, cz), rng.choice((0, 90, 180, 270))))
            nb += 1


def _decor_extra(self):
    """Lámpara de araña sobre el vestíbulo y tejado a dos aguas sobre el ático (silueta de la mansión)."""
    B = self.B
    F = B.folder("Decoracion/Vestibulo")
    cx, cz = 40 * C, 28 * C
    rbx.part(F, "Cadena", (cx, H + 9, cz), (0.2, 6, 0.2), (180, 150, 80), "Metal", collide=False, query=False)
    rbx.ellipsoid(F, "Arana", (cx, H + 5, cz), (6, 3, 6), (200, 170, 90), "Metal")
    for k in range(6):
        a = k * math.pi / 3
        g = rbx.part(F, "Vela", (cx + math.cos(a) * 3, H + 5.8, cz + math.sin(a) * 3), (0.3, 0.5, 0.3), (255, 200, 120), "Neon",
                     collide=False, query=False, shadow=False)
    rbx.light(g, "PointLight", (255, 190, 110), 1.6, 40, shadows=True)
    R = B.folder("Estructura/TejadoMansion")
    self.gable(R, 28 * C - 2, 52 * C + 2, 12 * C - 2, 34 * C + 2, 3 * H + 9.7, slate=True, rise=26)
    for (x, z) in ((31, 15), (48, 30)):
        rbx.box(R, "Chimenea", x * C - 2, x * C + 2, 3 * H + 9, 3 * H + 19, z * C - 2, z * C + 2, (120, 70, 60), "Brick")


def _boundaries(self):
    F = self.B.folder("Limites")
    lay = self.lay
    self.outer_ground(F, "Campo", (40, 56, 40), "Grass")
    self.skyline(F, rings=((40, 0.6, 1.1, 22), (110, 0.45, 1.5, 32), (220, 0.3, 2.1, 46)), kind="trees")
    # verja del portón principal (2.5D: no se abre; detrás, el camino se pierde en la niebla)
    g = rbx.folder(F, "Porton")
    for k in range(14):
        rbx.part(g, "Barrote", (40 * C - 6.5 + k, 7, 72 * C + 0.2), (0.3, 14, 0.3), (30, 30, 30), "Metal", collide=False, query=False)
    rbx.part(g, "Arco", (40 * C, 14.5, 72 * C + 0.2), (14, 1.2, 0.4), (30, 30, 30), "Metal", collide=False, query=False)


Mansion.decor_outdoor = _decor_outdoor
Mansion.decor_extra = _decor_extra
Mansion.boundaries = _boundaries


def build(seed=3):
    return Mansion(seed)
