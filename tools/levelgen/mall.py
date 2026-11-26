"""Level_6 · Centro comercial Galerías del Norte (nivel final, con baliza). Dos edificios largos unidos en H por un cuerpo central
(patio de comidas abajo, cine arriba); a cada lado del cuerpo central, un aparcamiento. En cada edificio, atrio de doble altura con
pasarelas y escaleras mecánicas, tiendas a ambos lados; azoteas por las escaleras de servicio."""
from __future__ import annotations

import rbx
from arch import C, H, Building, Plan, split
from common import Frame
from layout import DIRS

THEME = {
    "wall_int": (232, 228, 220), "zocalo": (150, 140, 130), "floor_corr": (214, 210, 200), "floor_default": (200, 196, 186),
    "ceil": (230, 230, 226), "roof": (120, 122, 126), "facade_default": (176, 182, 190), "glass": (120, 170, 190),
    "frame": (70, 74, 80), "parapet": (160, 166, 172), "rail": (190, 196, 200), "door_frame": (70, 74, 80),
    "stair": (120, 124, 130), "stair_edge": (240, 210, 60), "stall": (220, 200, 160), "curtain": (120, 40, 60),
    "ground": {"asphalt": ((54, 56, 60), "SmoothPlastic"), "roof": ((126, 128, 132), "SmoothPlastic")},
    "floor_room": {"Supermercado": (220, 220, 210), "Cine": (60, 30, 36), "Baños": (200, 220, 220), "Almacén": (140, 136, 126)},
    "street_light": (255, 230, 190),
}
STORES = ["Ropa", "Juguetería", "Electrónica", "Zapatería", "Librería", "Deportes", "Farmacia", "Joyería", "Cafetería", "Ropa",
          "Baños", "Arcade"]


class Mall(Building):
    NAME = "Level_6"
    THEME = THEME
    ROOM_DECOR = {
        "Ropa": (["fitting", "fitting", "counter"], 0.3, [("clothes_rack", 6.5, 2.5, -4), ("mannequin", 2, 2, 2)]),
        "Juguetería": (["shelf", "shelf", "counter", "crates"], 0.6, []),
        "Electrónica": (["tvwall", "counter", "shelf"], 0.4, [("display_case", 6.5, 3, 1)]),
        "Zapatería": (["shelf", "shelf", "counter"], 0.5, [("waiting_free", 6, 2, 1)]),
        "Librería": (["bookcase", "bookcase", "counter", "bookcase"], 0.7, []),
        "Deportes": (["shelf", "counter"], 0.4, [("clothes_rack", 6.5, 2.5, -5)]),
        "Farmacia": (["counter", "shelf", "shelf"], 0.6, []),
        "Joyería": (["counter"], 0.2, [("display_case", 6.5, 3, -6)]),
        "Cafetería": (["counter", "vending", "kitchen"], 0.4, [("picnic", 7, 7, -10)]),
        "Baños": (["stall", "stall", "stall", "sink_row"], 0.8, []),
        "Arcade": (["vending", "console", "vending", "console"], 0.7, []),
        "Supermercado": (["counter", "fridge", "fridge", "shelf"], 0.5, [("gondola", 11, 3, -4)]),
        "Cine": (["counter"], 0.1, [("cinema_seat", 12, 3, -2)]),
        "Seguridad": (["console", "desk", "cabinet"], 0.6, []),
        "Almacén": (["shelf", "crates", "shelf"], 0.6, []),
        "Sala de juegos": (["vending", "console"], 0.5, []),
    }

    def plan(self) -> Plan:
        rng = self.rng
        P = Plan(86, 88, self.seed, 0, 2)
        self.lots = []
        shaft = {(x, z) for x in range(41, 44) for z in range(18, 22)}
        north = P.area("hall", "Aparcamiento Norte", 0, 26, 12, 59, 37, outdoor=True, ground="asphalt", edge="fence", exclude=shaft,
                       type="Aparcamiento")
        south = P.area("hall", "Aparcamiento Sur", 0, 26, 50, 59, 75, outdoor=True, ground="asphalt", edge="fence", type="Aparcamiento")
        P.elevator_shaft(41, 18, north)
        self.lots = [north, south]
        self.galleries = {}
        bars = {"Oeste": (10, False), "Este": (60, True)}
        self.bars = {}
        for name, (x0, mirror) in bars.items():
            self.bars[name] = self.bar(P, rng, name, x0, mirror, north, south)
        # Cuerpo central: patio de comidas (planta baja) y cine (planta 1)
        food = P.area("hall", "Patio de comidas", 0, 26, 38, 59, 49, type="Patio de comidas", wall=(240, 220, 190))
        for nm in self.bars:
            P.open_between(food, self.bars[nm]["pass0"])
        P.connect(food, north, n=2)
        P.connect(food, south, n=2)
        cine = P.area("room", "Cine", 1, 30, 38, 55, 49, type="Cine", wall=(70, 30, 40), zocalo=(40, 20, 24))
        lw = P.area("corridor", "Pasillo del cine O", 1, 26, 42, 29, 45)
        le = P.area("corridor", "Pasillo del cine E", 1, 56, 42, 59, 45)
        P.open_between(lw, self.bars["Oeste"]["pass1"])
        P.open_between(le, self.bars["Este"]["pass1"])
        P.connect(cine, lw)
        P.connect(cine, le)
        for (nm, r, c) in (("Sala de juegos", (26, 38, 29, 41), lw), ("Baños", (26, 46, 29, 49), lw), ("Seguridad", (56, 38, 59, 41), le),
                           ("Almacén", (56, 46, 59, 49), le)):
            s = P.area("room", nm, 1, *r, type=nm)
            P.connect(s, c)
        occupied = {(x, z) for (l, x, z) in P.occ if l == 2}
        roofc = P.area("room", "Azotea central", 2, 26, 38, 59, 49, outdoor=True, roof=True, edge="parapet", ground="roof",
                       type="Azotea", label=False, exclude=occupied)
        for nm in self.bars:
            P.open_between(roofc, self.bars[nm]["roof"])
        self.food, self.cine = food, cine
        return P

    def bar(self, P, rng, name, x0, mirror, north, south):
        """Edificio largo (16 x 62 celdas, eje Z): tiendas | atrio central (pasarelas arriba) | tiendas. El lado que da al cuerpo
        central y a los aparcamientos tiene pasos y entradas."""
        z0, z1 = 12, 75
        if not mirror:
            outer, atr, inner = (x0, x0 + 4), (x0 + 5, x0 + 10), (x0 + 11, x0 + 15)
        else:
            inner, atr, outer = (x0, x0 + 4), (x0 + 5, x0 + 10), (x0 + 11, x0 + 15)
        a0, a1 = atr
        galx = (a0, a1)  # pasarelas de la planta 1 (columnas extremas del atrio)
        void_cols = range(a0 + 1, a1)
        bridges_z = [24, 43, 63]
        # escaleras mecánicas: subida en la columna a0+2 (hacia +Z) y bajada... también subida en a0+3 (hacia -Z) a cada puente
        esc = []
        for bz in bridges_z:
            esc.append(([(a0 + 2, bz - 3), (a0 + 2, bz - 2), (a0 + 2, bz - 1)], 0))
            esc.append(([(a0 + 3, bz + 3), (a0 + 3, bz + 2), (a0 + 3, bz + 1)], 2))
        esc_cells = {c for (cells, d) in esc for c in cells}
        # pasos (tienda interior convertida en paso): al cuerpo central y a los aparcamientos
        pass_z = {"centro": (38, 49), "entN": (24, 25), "entS": (62, 63)}
        pass_cells = {(x, z) for x in range(inner[0], inner[1] + 1) for (za, zb) in pass_z.values() for z in range(za, zb + 1)}
        # escaleras de servicio en la banda exterior, junto al atrio, en ambos extremos
        if not mirror:
            wells = [P.stairwell(outer[1] - 1, z0, 0, 2, axis="z", name=f"Servicio {name}"),
                     P.stairwell(outer[1] - 1, z1 - 4, 0, 2, axis="z", name=f"Servicio {name}")]
        else:
            wells = [P.stairwell(outer[0] + 1, z0, 0, 2, axis="z", name=f"Servicio {name}", flip=True),
                     P.stairwell(outer[0] + 1, z1 - 4, 0, 2, axis="z", name=f"Servicio {name}", flip=True)]
        hall = P.area("hall", f"Galería {name}", 0, a0, z0, a1, z1, exclude=esc_cells, type="Atrio", wall=(232, 228, 220), label=False)
        hall.data["atrium"] = True
        pass0 = P.area("hall", f"Paso {name}", 0, inner[0], 38, inner[1], 49, type="Paso", label=False)
        P.open_between(pass0, hall)
        for k in ("entN", "entS"):
            za, zb = pass_z[k]
            e = P.area("hall", f"Entrada {name} {k}", 0, inner[0], za, inner[1], zb, type="Entrada", label=False)
            P.open_between(e, hall)
            P.connect(e, north if k == "entN" else south) if P.shared(e, north if k == "entN" else south) else None
        # planta 1: pasarelas laterales, puentes y huecos del atrio
        gal = P.new_space("corridor", f"Pasarelas {name}")
        gal.data.update(outdoor=False)
        for z in range(z0, z1 + 1):
            for x in galx:
                P.take(gal, (1, x, z))
            if z in bridges_z:
                for x in void_cols:
                    P.take(gal, (1, x, z))
        esc_void = set()
        for (cells, d) in esc:
            f = P.flight(0, cells, d, name="Escalera mecánica", inner=True)
            esc_void |= {(1, x, z) for (x, z) in cells[1:]}
            first, last = cells[0], cells[-1]
            P.link((0, first[0] - DIRS[d][0], first[1] - DIRS[d][1]), (0, *first), "open")
            P.link((1, *last), (1, last[0] + DIRS[d][0], last[1] + DIRS[d][1]), "open")
            for i, (x, z) in enumerate(cells):
                for dd in (1, 3):
                    n = (0, x + DIRS[dd][0], z + DIRS[dd][1])
                    if n in hall.cells:
                        P.link((0, x, z), n, "open" if i == 0 else "rail")
        for z in range(z0, z1 + 1):
            for x in void_cols:
                c = (1, x, z)
                if c not in P.occ:
                    P.take(hall, c, void=True)
        for z in range(z0, z1 + 1):
            for x in void_cols:
                c = (1, x, z)
                if c in hall.void:
                    for d in range(4):
                        n = (1, x + DIRS[d][0], z + DIRS[d][1])
                        if n in gal.cells:
                            P.link(c, n, "rail")
        pass1 = P.area("corridor", f"Paso alto {name}", 1, inner[0], 42, inner[1], 45)
        P.open_between(pass1, gal)
        # tiendas
        types = list(STORES)
        rng.shuffle(types)
        k = 0
        for l in (0, 1):
            corr = hall if l == 0 else gal
            for band in (outer, inner):
                cells_taken = {(x, z) for (ll, x, z) in P.occ if ll == l}
                zs = [z for z in range(z0, z1 + 1) if not any((x, z) in cells_taken for x in range(band[0], band[1] + 1))]
                runs = []
                for z in zs:
                    if runs and runs[-1][1] == z - 1:
                        runs[-1][1] = z
                    else:
                        runs.append([z, z])
                for (ra, rb) in runs:
                    for (s0, s1) in split(rng, ra, rb, 4, 8):
                        t = "Supermercado" if (l == 0 and band == outer and s1 - s0 >= 7 and k % 3 == 0) else types[k % len(types)]
                        k += 1
                        st = P.area("room", f"{t} {name} {l}-{k}", l, band[0], s0, band[1], s1, type=t, facade="mall")
                        if P.shared(st, corr):
                            P.connect(st, corr, n=2 if s1 - s0 >= 5 else 1)
                        else:
                            for w in wells:
                                if l in w and P.shared(st, w[l]):
                                    P.connect(st, w[l])
                                    break
        for w in wells:
            for l in (0, 1):
                corr = hall if l == 0 else gal
                if P.shared(w[l], corr):
                    P.connect(w[l], corr)
        occupied = {(x, z) for (l, x, z) in P.occ if l == 2}
        roof = P.area("room", f"Azotea {name}", 2, x0, z0, x0 + 15, z1, outdoor=True, roof=True, edge="parapet", ground="roof",
                      type="Azotea", label=False, exclude=occupied)
        for w in wells:
            P.connect(w[2], roof)
        return {"hall": hall, "gal": gal, "pass0": pass0, "pass1": pass1, "roof": roof, "atr": atr}

    # ---------------------------------------------------------------- decoración
    def waiting_free(self, p, fr):
        m = rbx.model(p, "Banco")
        fr.part(m, "Asiento", (0, 1.6, 0), (5.5, 1.2, 1.6), (90, 90, 96))

    def planter(self, p, fr):
        m = rbx.model(p, "Jardinera")
        fr.part(m, "Maceta", (0, 1.4, 0), (4, 2.8, 4), (200, 196, 186))
        fr.ell(m, "Planta", (0, 4.2, 0), (4.6, 3.6, 4.6), (60, 110, 60))

    def decor_room(self, p, s, slots):
        t = s.data.get("type")
        if t in ("Atrio", "Paso", "Entrada", "Patio de comidas"):
            if t == "Atrio":
                self.place_free(p, s, self.planter, 5, 5, 6, pad=2)
                self.place_free(p, s, self.park_bench, 6.5, 2.5, 6, pad=2)
                self.place_free(p, s, self.food_cart, 6, 6, 2, pad=2)
            elif t == "Patio de comidas":
                self.place_free(p, s, self.food_stall, 9, 8, 6, pad=2)
                self.place_free(p, s, self.picnic, 7, 7, 14, pad=1.5)
                self.place_free(p, s, self.planter, 5, 5, 4, pad=2)
            return
        super().decor_room(p, s, slots)
        # escaparate de tienda: rótulo luminoso sobre la puerta (cada tienda su color)
        doors = [k for k in self.lay.links if self.lay.links[k] in ("door", "puzzle") and any(c in s.cells for c in k)]
        if doors and self.rng.random() < 0.7:
            a, b = sorted(tuple(doors[0]))
            l = a[0]
            mx, mz = (a[1] + b[1] + 1) / 2 * C, (a[2] + b[2] + 1) / 2 * C
            g = rbx.part(p, "Rotulo", (mx, l * H + 11, mz), (6, 1.4, 6) if a[2] == b[2] else (6, 1.4, 6),
                         self.rng.choice([(255, 80, 120), (80, 200, 255), (255, 210, 80), (140, 255, 140), (220, 120, 255)]), "Neon",
                         collide=False, query=False, shadow=False, transparency=0.2)
            g.props["size"] = (1.2, 1.4, 6) if a[1] != b[1] else (6, 1.4, 1.2)
            if self.rng.random() < 0.35:
                g.tags.append("LamparaInstalacion")
                g.attrs["Parpadeo"] = True

    def decor_outdoor(self, p, s, slots):
        B, rng = self.B, self.rng
        if s.data.get("roof"):
            for i in range(4):
                def ac(pp, fr):
                    fr.part(pp, "Clima", (0, 2.5, 0), (7, 5, 4), (186, 190, 194), "Metal")
                    fr.part(pp, "Ventilador", (0, 5.1, 0), (3, 0.3, 3), (60, 60, 64), shape="Cylinder", lrot=rbx.rot_z(90), collide=False)
                self.place_free(p, s, ac, 8, 5, 1, pad=2)
            return
        # Aparcamiento: plazas pintadas en filas, coches abandonados, carritos, casetas
        x0, x1, z0, z1 = s.rect()
        kw = dict(collide=False, query=False, shadow=False)
        rows = range(z0 + 2, z1 - 1, 5)
        for rz in rows:
            for x in range(x0 + 1, x1, 1):
                X = x * C
                Z = rz * C
                rbx.box(p, "Linea", X - 0.15, X + 0.15, 0.0, 0.05, Z, Z + 12, (230, 230, 220), **kw)
                if rng.random() < 0.35:
                    cx, cz = X + C / 2, Z + 6
                    if B.free_spot(cx - 3, cx + 3, cz - 5.5, cz + 5.5, 0):
                        B.block(cx - 3, cx + 3, cz - 5.5, cz + 5.5, 0)
                        self.car(p, Frame((cx, 0, cz), rng.choice((0, 180)) + rng.uniform(-8, 8)))
        self.place_free(p, s, self.cart, 3, 4, 8, pad=1)
        cells = self.free_cells(s, True)
        rng.shuffle(cells)
        nb = 0
        for c in cells:
            if nb >= 5:
                break
            l, x, z = c
            cx, cy, cz = B.cell_center(x, z, l)
            if B.free_spot(cx - 3, cx + 3, cz - 3, cz + 3, 0, pad=1):
                B.block(cx - 3, cx + 3, cz - 3, cz + 3, 0)
                self.hide_bush(p, Frame((cx, 0, cz), rng.choice((0, 90, 180, 270))))
                nb += 1

    def decor_extra(self):
        """Lucernario sobre cada atrio, rótulos de las fachadas y la baliza final en el extremo del edificio este."""
        B = self.B
        F = B.folder("Decoracion/Fachada")
        for nm, x in (("Oeste", 10), ("Este", 60)):
            g = rbx.part(F, "Rotulo", ((x + 8) * C, 2 * H + 4, 11.6 * C), (60, 6, 0.6), (255, 220, 120), "Neon", collide=False,
                         query=False, shadow=False)
            rbx.light(g, "PointLight", (255, 210, 120), 1.5, 40)
            if nm == "Este":
                g.tags.append("LamparaInstalacion")
                g.attrs["Parpadeo"] = True
        a0, a1 = self.bars["Este"]["atr"]
        site = rbx.part(B.root, "BeaconSite", ((a0 + a1 + 1) / 2 * C, 0.2, 72 * C), (4, 0.4, 4), (40, 40, 40), collide=False,
                        query=False, shadow=False, transparency=1)
        B.block((a0 + a1 + 1) / 2 * C - 6, (a0 + a1 + 1) / 2 * C + 6, 72 * C - 6, 72 * C + 6, 0)

    def boundaries(self):
        F = self.B.folder("Limites")
        lay = self.lay
        self.outer_ground(F, "Calle", (50, 52, 56))
        self.skyline(F, kind="city")
        # valla publicitaria de la autopista (2.5D)
        g = rbx.part(F, "Valla", (lay.w * C / 2, 60, -160), (90, 30, 1), (30, 30, 34), collide=False, query=False, shadow=False)
        t = rbx.part(F, "Anuncio", (lay.w * C / 2, 60, -159.2), (84, 24, 0.3), (255, 120, 60), "Neon", collide=False, query=False,
                     shadow=False, transparency=0.3)
        t.tags.append("LamparaInstalacion")
        t.attrs["Parpadeo"] = True


def build(seed=3):
    return Mall(seed)
