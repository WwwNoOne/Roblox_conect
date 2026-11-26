"""Level_4 · Escuela. Edificio en L de 3 plantas + azotea; dentro de la L, el patio de juegos cerrado por una tapia, con un autobús
escolar abandonado. Pasillos con taquillas (escondites) que miran al patio."""
from __future__ import annotations

import rbx
from arch import C, H, Building, Plan, wing
from common import Frame, against_wall

THEME = {
    "wall_int": (236, 222, 190), "zocalo": (70, 120, 170), "floor_corr": (196, 186, 160), "floor_default": (180, 150, 110),
    "ceil": (220, 216, 206), "roof": (120, 110, 104), "facade_default": (178, 96, 72), "glass": (160, 196, 210),
    "frame": (230, 226, 216), "parapet": (186, 110, 84), "rail": (60, 110, 170), "door_frame": (60, 110, 170),
    "stair": (176, 170, 160), "stair_edge": (240, 200, 60), "stall": (110, 170, 150), "outwall": (196, 120, 90), "wall_h": 11,
    "ground": {"court": ((96, 104, 110), "SmoothPlastic"), "roof": ((126, 120, 116), "SmoothPlastic")},
    "floor_room": {"Gimnasio": (196, 150, 96), "Comedor": (200, 196, 180), "Biblioteca": (150, 110, 80), "Baños": (200, 220, 220)},
    "street_light": (255, 214, 150),
}


class School(Building):
    NAME = "Level_4"
    THEME = THEME
    ROOM_DECOR = {
        "Aula": (["blackboard", "cabinet", "bookcase"], 0.25, [("school_desk", 3.6, 4.6, -2)]),
        "Biblioteca": (["bookcase", "bookcase", "bookcase", "desk"], 0.8, [("picnic", 7, 7, -14)]),
        "Laboratorio": (["tank", "bench", "tank", "cabinet"], 0.5, []),
        "Informática": (["desk", "desk", "desk"], 0.7, []),
        "Música": (["piano", "cabinet"], 0.3, [("school_desk", 3.6, 4.6, -6)]),
        "Arte": (["bench", "crates", "shelf"], 0.5, []),
        "Comedor": (["counter", "vending"], 0.3, [("picnic", 7, 7, -8)]),
        "Cocina": (["kitchen", "fridge", "kitchen", "shelf"], 0.7, []),
        "Gimnasio": (["crates", "waiting"], 0.3, [("hoop", 5, 3, 1)]),
        "Dirección": (["desk", "bookcase", "cabinet", "painting"], 0.6, []),
        "Enfermería": (["cot", "cabinet"], 0.5, []),
        "Sala de profesores": (["sofa", "desk", "vending"], 0.5, []),
        "Conserjería": (["shelf", "crates", "boiler"], 0.5, []),
        "Baños": (["stall", "stall", "stall", "sink_row"], 0.8, []),
        "Vestuarios": ("lockers", 0.0, []),
    }

    def plan(self) -> Plan:
        rng = self.rng
        P = Plan(72, 72, self.seed, 0, 3)
        shaft = {(x, z) for x in range(48, 51) for z in range(50, 54)}
        yard = P.area("hall", "Patio", 0, 20, 20, 55, 59, outdoor=True, ground="court", edge="wall", exclude=shaft, type="Patio")
        P.elevator_shaft(48, 50, yard)
        self.yard = yard
        A_types = {0: ["Comedor", "Cocina", "Gimnasio", "Dirección", "Enfermería"], 1: ["Aula", "Aula", "Biblioteca", "Aula"],
                   2: ["Laboratorio", "Informática", "Música", "Arte", "Aula"]}
        B_types = {0: ["Sala de profesores", "Conserjería", "Aula", "Baños"], 1: ["Aula", "Aula", "Baños", "Aula"],
                   2: ["Aula", "Aula", "Vestuarios", "Baños"]}

        def tA(l, band, i, span):
            if band == "small":
                return rng.choice(["Baños", "Conserjería"])
            lst = A_types[l]
            return lst[i % len(lst)]

        def tB(l, band, i, span):
            if band == "small":
                return "Baños"
            lst = B_types[l]
            return lst[i % len(lst)]

        A = wing(P, rng, "Ala Norte", "x", 12, 55, (12, 17), (18, 19), None, [0, 1, 2], tA, roof_layer=3, size=(4, 7))
        B = wing(P, rng, "Ala Oeste", "z", 20, 59, (12, 17), (18, 19), None, [0, 1, 2], tB, stairs=("end",), roof_layer=3,
                 size=(4, 7))
        for l in (0, 1, 2):
            P.open_between(A["corr"][l], B["corr"][l])
        P.open_between(A["roof"], B["roof"])
        for wg in (A, B):
            P.connect(wg["corr"][0], yard, n=3)
        self.wings = (A, B)
        return P

    def decor_corridor(self, p, s, slots):
        """Pasillos de escuela: filas de taquillas (la mitad sirven de escondite) y alguna vitrina de trofeos."""
        n = 0
        for (c, d) in slots:
            if self.rng.random() < 0.35:
                fr = against_wall(self.B, c, d, 2.8)
                if self.place_locker(p, fr, c, hideable=(n % 3 == 0)):
                    n += 1
            elif self.rng.random() < 0.05:
                fr = against_wall(self.B, c, d, 2.4)
                if self.take(fr, 5, 2.4, c[0]):
                    m = rbx.model(p, "Vitrina")
                    fr.part(m, "Mueble", (0, 4, 0), (5, 8, 2.2), (120, 84, 56))
                    fr.part(m, "Vidrio", (0, 5, -1.15), (4.4, 5, 0.1), (200, 230, 240), "Glass", transparency=0.6, collide=False)
                    for k in range(3):
                        fr.part(m, "Trofeo", (-1.4 + k * 1.4, 4.6, 0), (0.6, 1.2, 0.6), (230, 190, 60), "Metal", collide=False)

    def decor_outdoor(self, p, s, slots):
        B, rng = self.B, self.rng
        if s.data.get("roof"):
            for i in range(5):
                def ac(pp, fr):
                    fr.part(pp, "Clima", (0, 2, 0), (5, 4, 3), (190, 192, 190), "Metal")
                self.place_free(p, s, ac, 6, 4, 1, pad=2)
            return
        # Pista de baloncesto pintada junto al ala norte, con dos canastas
        kw = dict(collide=False, query=False, shadow=False)
        x0, x1, z0, z1 = 22 * C, 40 * C, 22 * C, 32 * C
        rbx.box(p, "Pista", x0, x1, 0.0, 0.05, z0, z1, (150, 80, 60), **kw)
        for (a, b, c, d) in ((x0, x1, z0, z0 + 0.3), (x0, x1, z1 - 0.3, z1), (x0, x0 + 0.3, z0, z1), (x1 - 0.3, x1, z0, z1),
                             ((x0 + x1) / 2 - 0.15, (x0 + x1) / 2 + 0.15, z0, z1)):
            rbx.box(p, "Linea", a, b, 0.05, 0.08, c, d, (240, 240, 230), **kw)
        B.block(x0, x1, z0, z1, 0)
        self.hoop(p, Frame((x0 + 1.5, 0, (z0 + z1) / 2), -90))
        self.hoop(p, Frame((x1 - 1.5, 0, (z0 + z1) / 2), 90))
        # Autobús abandonado, de lado, en el centro del patio
        bx, bz = 36 * C, 46 * C
        if B.free_spot(bx - 17, bx + 17, bz - 5, bz + 5, 0):
            B.block(bx - 18, bx + 18, bz - 5, bz + 5, 0)
            self.bus(p, Frame((bx, 0, bz), 90 + rng.uniform(-8, 8)))
        self.place_free(p, s, self.swing, 10, 5, 2, pad=2)
        self.place_free(p, s, self.slide, 9, 5, 2, pad=2)
        self.place_free(p, s, self.seesaw, 10, 3, 2, pad=2)
        self.place_free(p, s, self.sandbox, 10, 10, 1, pad=2)
        self.place_free(p, s, self.park_bench, 6.5, 2.5, 10, pad=1.5)
        self.place_free(p, s, self.picnic, 7, 7, 4, pad=2)
        cells = self.free_cells(s, True)
        rng.shuffle(cells)
        nt = nb = 0
        for c in cells:
            l, x, z = c
            cx, cy, cz = B.cell_center(x, z, l)
            if nt < 10 and B.free_spot(cx - 2, cx + 2, cz - 2, cz + 2, 0, pad=2):
                B.block(cx - 2, cx + 2, cz - 2, cz + 2, 0)
                self.tree(p, cx, cz, rng.uniform(0.7, 0.9))
                nt += 1
            elif nb < 8 and B.free_spot(cx - 3, cx + 3, cz - 3, cz + 3, 0, pad=1):
                B.block(cx - 3, cx + 3, cz - 3, cz + 3, 0)
                self.hide_bush(p, Frame((cx, 0, cz), rng.choice((0, 90, 180, 270))))
                nb += 1
        # Portón cerrado con cadena en la tapia sur
        g = B.folder("Decoracion/Porton")
        gx, gz = 38 * C, 60 * C
        for k in range(12):
            rbx.part(g, "Barrote", (gx - 5.5 + k, 5, gz - 0.9), (0.25, 10, 0.25), (60, 70, 66), "Metal", collide=False, query=False)
        rbx.part(g, "Cadena", (gx, 5, gz - 1.1), (1.4, 1.4, 0.3), (150, 150, 150), "Metal", collide=False, query=False)
        rbx.part(g, "Cartel", (gx, 11.5, gz - 0.9), (8, 1.6, 0.3), (40, 80, 50), collide=False, query=False)

    def boundaries(self):
        F = self.B.folder("Limites")
        lay = self.lay
        self.outer_ground(F, "Barrio", (64, 80, 58), "Grass")
        self.skyline(F, rings=((60, 0.55, 1.0, 40), (140, 0.42, 1.3, 60)), kind="houses")
        self.skyline(F, rings=((100, 0.5, 1.1, 50), (220, 0.32, 1.8, 80)), kind="trees")


def build(seed=3):
    return School(seed)
