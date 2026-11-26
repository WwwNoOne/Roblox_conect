"""Level_3 · Hospital San Judas. Cuatro pabellones de 4 plantas + azotea alrededor de un parque de rehabilitación con puestos de
comida. Pasarelas acristaladas en las esquinas (planta 1 y 3) unen los pabellones en anillo."""
from __future__ import annotations

import rbx
from arch import C, H, Building, Plan, wing
from common import Frame

THEME = {
    "wall_int": (222, 228, 222), "zocalo": (104, 158, 150), "floor_corr": (176, 186, 180), "floor_default": (196, 198, 190),
    "ceil": (206, 210, 206), "roof": (110, 112, 116), "facade_default": (206, 204, 194), "glass": (140, 186, 200),
    "frame": (80, 96, 104), "cornice": (150, 160, 160), "parapet": (186, 184, 176), "rail": (200, 206, 210),
    "door_frame": (90, 140, 150), "stair": (170, 172, 168), "stair_edge": (230, 190, 60), "stall": (150, 190, 200),
    "ground": {"grass": ((72, 108, 62), "Grass"), "paving": ((150, 146, 136), "SmoothPlastic"), "roof": ((118, 118, 122), "SmoothPlastic")},
    "floor_room": {"Quirófano": (170, 200, 196), "Morgue": (150, 160, 164), "Capilla": (150, 120, 96), "Cafetería": (200, 180, 150),
                   "Celda": (236, 236, 228), "UCI": (180, 200, 206)},
    "street_light": (220, 236, 255),
}

FLOORS = {
    "N": ["Urgencias", "Pabellón", "Quirófano", "UCI"],
    "S": ["Cafetería", "Pediatría", "Maternidad", "Laboratorio"],
    "W": ["Radiología", "Consulta", "Psiquiatría", "Administración"],
    "E": ["Morgue", "Archivo", "Aislamiento", "Aula médica"],
}
FILLER = ["Sala de espera", "Almacén", "Baños", "Vestuario", "Sala de médicos", "Consulta"]


class Hospital(Building):
    NAME = "Level_3"
    THEME = THEME
    ROOM_DECOR = {
        "Urgencias": (["cot", "cot", "cabinet"], 0.6, []),
        "Admisión": (["counter", "waiting", "waiting"], 0.5, []),
        "Vestíbulo": (["waiting", "vending", "counter"], 0.4, [("wheelchair", 2.5, 2.5, 1)]),
        "Pabellón": (["iv_bed", "iv_bed", "cabinet"], 0.6, []),
        "Quirófano": (["cabinet", "tank", "console"], 0.4, [("op_table", 4, 8, 1)]),
        "UCI": (["iv_bed", "console", "iv_bed"], 0.6, []),
        "Cafetería": (["counter", "vending", "kitchen"], 0.3, [("picnic", 6, 6, -10)]),
        "Pediatría": (["iv_bed", "crates", "painting"], 0.5, []),
        "Maternidad": (["iv_bed", "cabinet", "painting"], 0.5, []),
        "Laboratorio": (["tank", "bench", "tank", "cabinet"], 0.5, []),
        "Radiología": (["xray", "console", "cabinet"], 0.5, []),
        "Consulta": (["desk", "cot", "cabinet"], 0.5, []),
        "Psiquiatría": (["cot", "painting"], 0.3, [("wheelchair", 2.5, 2.5, 1)]),
        "Celda": (["bed_rustic"], 0.2, []),
        "Administración": (["desk", "desk", "cabinet", "shelf"], 0.5, []),
        "Morgue": (["morgue", "morgue", "cabinet"], 0.5, [("op_table", 4, 8, 1)]),
        "Archivo": (["shelf", "shelf", "cabinet"], 0.6, []),
        "Aislamiento": (["iv_bed", "tank"], 0.4, []),
        "Aula": ([], 0.0, [("school_desk", 3.6, 4.6, -3)]),
        "Sala de espera": (["waiting", "waiting", "vending"], 0.6, []),
        "Almacén": (["shelf", "crates", "shelf"], 0.5, []),
        "Baños": (["stall", "stall", "sink_row"], 0.7, []),
        "Vestuario": ("lockers", 0.0, []),
        "Sala de médicos": (["sofa", "desk", "vending"], 0.4, []),
        "Capilla": (["painting", "painting"], 0.3, [("park_bench", 6.5, 2.5, -4)]),
        "Farmacia": (["counter", "shelf", "shelf"], 0.6, []),
    }

    def plan(self) -> Plan:
        rng = self.rng
        P = Plan(84, 84, self.seed, 0, 4)
        shaft = {(x, z) for x in range(40, 43) for z in range(36, 40)}
        park = P.area("hall", "Parque de rehabilitación", 0, 26, 26, 57, 57, outdoor=True, ground="grass", edge="fence",
                      exclude=shaft, type="Parque")
        P.elevator_shaft(40, 36, park)
        self.park = park
        self.wings = {}
        specs = {
            "N": ("x", (16, 19), (20, 21), (22, 25)),
            "S": ("x", (64, 67), (62, 63), (58, 61)),
            "W": ("z", (16, 19), (20, 21), (22, 25)),
            "E": ("z", (64, 67), (62, 63), (58, 61)),
        }
        for key, (axis, outer, corr, inner) in specs.items():
            types = FLOORS[key]

            def room_type(l, band, i, span, types=types, key=key):
                if band == "small":
                    return rng.choice(["Baños", "Almacén", "Vestuario"])
                if l == 0 and band == "inner" and i in (1, 3):
                    return "Vestíbulo"
                if l == 0 and band == "inner" and i == 0 and key == "S":
                    return "Capilla"
                if l == 0 and band == "outer" and i == 0 and key == "S":
                    return "Farmacia"
                if l == 0 and key == "N" and band == "outer" and i == 0:
                    return "Admisión"
                if key == "W" and l == 2 and band == "outer":
                    return "Celda" if i % 2 == 0 else "Psiquiatría"
                return types[l] if rng.random() < 0.7 else rng.choice(FILLER)

            w = wing(P, rng, f"Pabellón {key}", axis, 26, 57, outer, corr, inner, [0, 1, 2, 3], room_type, roof_layer=4,
                     size=(3, 6))
            self.wings[key] = w
            for r in w["rooms"][0]:
                if r.data.get("type") == "Vestíbulo":
                    P.connect(r, park)
        # Pasarelas acristaladas en las esquinas (planta 1: las cuatro; planta 3: dos)
        self.bridges = []
        corners = {
            "NW": ("N", "W", [(x, z) for x in range(20, 26) for z in (20, 21)] + [(x, z) for x in (20, 21) for z in range(22, 26)]),
            "NE": ("N", "E", [(x, z) for x in range(58, 64) for z in (20, 21)] + [(x, z) for x in (62, 63) for z in range(22, 26)]),
            "SW": ("S", "W", [(x, z) for x in range(20, 26) for z in (62, 63)] + [(x, z) for x in (20, 21) for z in range(58, 62)]),
            "SE": ("S", "E", [(x, z) for x in range(58, 64) for z in (62, 63)] + [(x, z) for x in (62, 63) for z in range(58, 62)]),
        }
        for cname, (a, b, cells) in corners.items():
            for l in ([1, 3] if cname in ("NE", "SW") else [1]):
                br = P.new_space("corridor", f"Pasarela {cname} P{l}")
                br.data.update(outdoor=False, facade="glass", bridge=True)
                for (x, z) in cells:
                    P.take(br, (l, x, z))
                P.open_between(br, self.wings[a]["corr"][l])
                P.open_between(br, self.wings[b]["corr"][l])
                self.bridges.append((br, cells, l))
        return P

    # ---------------------------------------------------------------- decoración
    def decor_outdoor(self, p, s, slots):
        B, rng = self.B, self.rng
        if s.data.get("roof"):
            self.roof_props(p, s)
            return
        # Parque: caminos en cruz y en anillo (pintados), fuente, puestos de comida, rehabilitación, bancos, árboles, arbustos
        x0, x1, z0, z1 = 26 * C, 58 * C, 26 * C, 58 * C
        kw = dict(collide=False, query=False, shadow=False)
        for (a, b, c, d) in ((x0, x1, 41 * C, 43 * C), (41 * C, 43 * C, z0, z1)):
            rbx.box(p, "Camino", a, b, 0.0, 0.06, c, d, (176, 166, 146), **kw)
        for (a, b, c, d) in ((30 * C, 54 * C, 30 * C, 31 * C), (30 * C, 54 * C, 53 * C, 54 * C), (30 * C, 31 * C, 30 * C, 54 * C),
                             (53 * C, 54 * C, 30 * C, 54 * C)):
            rbx.box(p, "Camino", a, b, 0.0, 0.06, c, d, (176, 166, 146), **kw)
        self.place_free(p, s, self.fountain, 13, 13, 1, pad=2)
        self.place_free(p, s, self.food_stall, 9, 8, 6, pad=3)
        self.place_free(p, s, self.food_cart, 6, 6, 4, pad=2)
        self.place_free(p, s, self.picnic, 7, 7, 8, pad=2)
        self.place_free(p, s, self.parallel_bars, 9, 4, 3, pad=2)
        self.place_free(p, s, self.rehab_steps, 9, 4, 2, pad=2)
        self.place_free(p, s, self.park_bench, 6.5, 2.5, 12, pad=1.5)
        self.place_free(p, s, self.wheelchair, 2.5, 2.5, 4, pad=1)
        cells = self.free_cells(s, True)
        rng.shuffle(cells)
        n_tree = n_bush = 0
        for c in cells:
            l, x, z = c
            cx, cy, cz = B.cell_center(x, z, l)
            if n_tree < 22 and B.free_spot(cx - 2, cx + 2, cz - 2, cz + 2, 0, pad=2):
                B.block(cx - 2, cx + 2, cz - 2, cz + 2, 0)
                self.tree(p, cx, cz, rng.uniform(0.7, 0.95))
                n_tree += 1
            elif n_bush < 10 and B.free_spot(cx - 3, cx + 3, cz - 3, cz + 3, 0, pad=1):
                B.block(cx - 3, cx + 3, cz - 3, cz + 3, 0)
                self.hide_bush(p, Frame((cx, 0, cz), rng.choice((0, 90, 180, 270))))
                n_bush += 1

    def roof_props(self, p, s):
        B, rng = self.B, self.rng
        x0, x1, z0, z1 = s.rect()
        l = min(c[0] for c in s.cells)
        y = l * H
        if s.name.endswith("N"):
            cx, cz = (x0 + x1 + 1) / 2 * C, (z0 + z1 + 1) / 2 * C
            if B.free_spot(cx - 14, cx + 14, cz - 14, cz + 14, l):
                B.block(cx - 14, cx + 14, cz - 14, cz + 14, l)
                rbx.part(p, "Helipuerto", (cx, y + 0.05, cz), (0.1, 28, 28), (70, 74, 78), shape="Cylinder", rot=rbx.rot_z(90),
                         collide=False, query=False)
                rbx.part(p, "Aro", (cx, y + 0.07, cz), (0.1, 24, 24), (230, 230, 220), shape="Cylinder", rot=rbx.rot_z(90),
                         collide=False, query=False)
                rbx.part(p, "Aro", (cx, y + 0.09, cz), (0.1, 22.6, 22.6), (70, 74, 78), shape="Cylinder", rot=rbx.rot_z(90),
                         collide=False, query=False)
                for (a, b, c, d) in ((-4, -2.6, -5, 5), (2.6, 4, -5, 5), (-2.6, 2.6, -0.7, 0.7)):
                    rbx.box(p, "H", cx + a, cx + b, y + 0.1, y + 0.16, cz + c, cz + d, (230, 230, 220), collide=False, query=False)
                for k in range(8):
                    g = rbx.part(p, "Baliza", (cx + 13 * __import__("math").cos(k * 0.785), y + 0.4, cz + 13 * __import__("math").sin(k * 0.785)),
                                 (0.6, 0.6, 0.6), (255, 80, 60), "Neon", shape="Ball", collide=False, query=False, shadow=False)
        for i in range(4):
            def tank(pp, fr):
                rbx.cylinder_y(pp, "Deposito", fr.w(0, 4, 0), 8, 6, (170, 174, 178), "Metal")
                rbx.cylinder_y(pp, "Tapa", fr.w(0, 8.3, 0), 0.6, 6.4, (120, 124, 128), "Metal")

            def ac(pp, fr):
                fr.part(pp, "Clima", (0, 2, 0), (5, 4, 3), (190, 192, 190), "Metal")
                fr.part(pp, "Rejilla", (0, 2, -1.55), (4, 3, 0.1), (60, 60, 64), collide=False)
            self.place_free(p, s, tank if i % 2 else ac, 7, 7, 1, pad=2)
        self.place_free(p, s, self.crates, 6, 5, 1) if False else None

    def decor_extra(self):
        """Pilares bajo las pasarelas y puertas de ascensor falsas (2.5D) en los pasillos."""
        B = self.B
        F = B.folder("Decoracion/Pasarelas")
        for (br, cells, l) in self.bridges:
            for (x, z) in cells[::3]:
                if (0, x, z) not in self.lay.occ:
                    rbx.cylinder_y(F, "Pilar", ((x + 0.5) * C, l * H / 2 - 1, (z + 0.5) * C), l * H, 1.6, (180, 180, 176))

    def boundaries(self):
        B = self.B
        F = B.folder("Limites")
        lay = self.lay
        self.outer_ground(F, "Calle", (52, 54, 58))
        self.skyline(F, kind="city")


def build(seed=3):
    return Hospital(seed)
