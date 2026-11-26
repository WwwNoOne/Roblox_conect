"""Muebles y objetos de los niveles de arquitectura (estilo plástico, piezas simples).

Contra muro: f(p, fr, l) con fr = Frame (X a lo largo del muro, +Z hacia el muro, y = suelo); su fondo va en DEPTH_EXTRA.
Sueltos: g(p, fr) con fr centrado en el objeto (los coloca ArchLevel.place_free).
"""
from __future__ import annotations

import math

import rbx
from common import hide_volume

DEPTH_EXTRA = {"xray": 4, "morgue": 3, "vending": 3, "waiting": 2.4, "blackboard": 0.8, "bookcase": 2.4, "piano": 4.5, "sofa": 3.2,
               "fireplace": 2.6, "grandclock": 2, "bathtub": 3.6, "stall": 4.4, "kitchen": 3, "fridge": 3, "fitting": 4.4,
               "tvwall": 1.2, "counter": 3, "iv_bed": 7, "cot": 6.5, "trunk": 3, "painting": 0.6}


class Props:
    def _blocked(self, fr, w, d, l):
        return not self.take(fr, w, d, l)

    def _hide(self, m, fr, local, size, label, kind="Locker"):
        hide_volume(m, fr.w(*local), size, kind, label, rot=fr.rot)
        self.B.markers.append(("Escondite", *fr.w(0, 0, 0)))

    # ---------------------------------------------------------------- hospital
    def iv_bed(self, p, fr, l):
        if self._blocked(fr, 4, 7, l):
            return
        m = rbx.model(p, "CamaHospital")
        fr.part(m, "Somier", (0, 2.0, -0.4), (3.6, 0.5, 6.6), (200, 204, 210), "Metal")
        fr.part(m, "Colchon", (0, 2.6, -0.4), (3.3, 0.6, 6.4), (226, 236, 240))
        fr.part(m, "Sabana", (0, 2.95, -1.6), (3.4, 0.15, 3.8), (150, 190, 200), "Fabric", collide=False)
        fr.part(m, "Cabecero", (0, 3.4, 2.9), (3.6, 2.6, 0.3), (180, 186, 196))
        fr.part(m, "Gotero", (2.4, 3.6, 1.8), (0.15, 7.2, 0.15), (200, 200, 200), "Metal", collide=False)
        fr.part(m, "Bolsa", (2.4, 6.6, 1.8), (0.7, 1.0, 0.3), (220, 240, 230), "Glass", collide=False, transparency=0.3)
        mon = fr.part(m, "Monitor", (-2.4, 5.2, 2.6), (1.6, 1.2, 0.4), (40, 44, 48), collide=False)
        g = fr.part(m, "Pantalla", (-2.4, 5.2, 2.38), (1.3, 0.9, 0.05), (40, 220, 120), "Neon", collide=False, shadow=False)
        if self.rng.random() < 0.3:
            rbx.light(g, "PointLight", (60, 220, 120), 0.5, 8)

    def cot(self, p, fr, l):
        """Camilla de urgencias con cortina (la cortina tapa el escondite de detrás)."""
        if self._blocked(fr, 4, 6.5, l):
            return
        m = rbx.model(p, "Box")
        fr.part(m, "Camilla", (0, 2.3, -0.2), (3, 0.6, 6), (210, 214, 220))
        for sx in (-1.3, 1.3):
            fr.part(m, "Pata", (sx, 1.0, -0.2), (0.2, 2, 5.6), (170, 170, 176), "Metal", collide=False)
        fr.part(m, "Riel", (0, 8.5, -3.4), (5, 0.15, 0.15), (200, 200, 200), "Metal", collide=False)
        fr.part(m, "Cortina", (0, 5.2, -3.4), (5, 6.5, 0.12), self.rng.choice([(140, 190, 200), (170, 200, 170), (200, 190, 150)]),
                "Fabric", collide=False, transparency=0.05)

    def xray(self, p, fr, l):
        if self._blocked(fr, 6, 4, l):
            return
        m = rbx.model(p, "RayosX")
        fr.part(m, "Mesa", (0, 2.4, -0.5), (6, 0.5, 2.6), (220, 224, 226))
        fr.part(m, "Columna", (2.6, 5, 1.4), (0.8, 10, 0.8), (190, 194, 200), "Metal")
        fr.part(m, "Brazo", (0.6, 8.6, 0.2), (4.5, 0.6, 0.6), (190, 194, 200), "Metal", collide=False)
        fr.part(m, "Cabezal", (-1.2, 7.6, -0.4), (1.6, 1.4, 1.6), (230, 230, 230), collide=False)
        g = fr.part(m, "Negatoscopio", (-1.5, 6, 1.85), (3, 2, 0.1), (230, 240, 255), "Neon", collide=False, shadow=False)

    def morgue(self, p, fr, l):
        """Pared de cámaras frigoríficas; una se puede abrir para esconderse."""
        if self._blocked(fr, 9, 3, l):
            return
        m = rbx.model(p, "Camaras")
        fr.part(m, "Bloque", (0, 4, 0.3), (9, 8, 2.4), (170, 176, 180), "Metal")
        for i in range(3):
            for j in range(2):
                fr.part(m, "Puerta", (-3 + i * 3, 2.2 + j * 3.6, -0.95), (2.6, 3.0, 0.1), (200, 206, 210), "Metal", collide=False)
                fr.part(m, "Asa", (-3 + i * 3 + 0.9, 2.2 + j * 3.6, -1.05), (0.15, 0.8, 0.15), (120, 120, 120), "Metal", collide=False)
        self._hide(m, fr, (0, 3.0, 0.3), (2.4, 6.0, 2.0), "Cámara frigorífica")

    def vending(self, p, fr, l):
        if self._blocked(fr, 4, 3, l):
            return
        m = rbx.model(p, "Expendedora")
        col = self.rng.choice([(190, 40, 40), (40, 90, 170), (40, 140, 80)])
        fr.part(m, "Cuerpo", (0, 4, 0), (3.6, 8, 2.8), col)
        g = fr.part(m, "Escaparate", (-0.4, 4.8, -1.42), (2.4, 5, 0.05), (220, 240, 255), "Neon", collide=False, shadow=False,
                    transparency=0.2)
        rbx.light(g, "PointLight", (200, 230, 255), 0.7, 10)
        if self.rng.random() < 0.3:
            g.tags.append("LamparaInstalacion")
            g.attrs["Parpadeo"] = True

    def waiting(self, p, fr, l):
        if self._blocked(fr, 8, 2.4, l):
            return
        m = rbx.model(p, "Asientos")
        fr.part(m, "Barra", (0, 1.0, 0), (8, 0.3, 0.3), (120, 120, 126), "Metal")
        col = self.rng.choice([(70, 120, 160), (170, 120, 60), (120, 150, 110)])
        for i in range(4):
            fr.part(m, "Asiento", (-3 + i * 2, 1.8, -0.1), (1.7, 0.3, 1.8), col)
            fr.part(m, "Respaldo", (-3 + i * 2, 2.9, 0.75), (1.7, 2.0, 0.3), col, collide=False)

    def op_table(self, p, fr):
        m = rbx.model(p, "Quirofano")
        fr.part(m, "Mesa", (0, 3, 0), (3, 0.5, 7), (90, 140, 150))
        fr.part(m, "Pie", (0, 1.4, 0), (1.2, 2.8, 1.2), (180, 186, 190), "Metal")
        fr.part(m, "Brazo", (0, 10.5, 0), (0.4, 3, 0.4), (200, 200, 200), "Metal", collide=False)
        lamp = fr.part(m, "Foco", (0, 9, 0), (3.5, 0.6, 3.5), (250, 250, 240), "Neon", shape="Cylinder", collide=False,
                       lrot=rbx.rot_z(90), shadow=False)
        rbx.light(lamp, "SpotLight", (255, 250, 235), 2.5, 16, face="Left", angle=60)
        fr.part(m, "Carrito", (3.5, 2.5, 1.5), (2, 0.3, 3), (190, 194, 200), "Metal", collide=False)

    def wheelchair(self, p, fr):
        m = rbx.model(p, "SillaRuedas")
        fr.part(m, "Asiento", (0, 1.8, 0), (2, 0.3, 2), (40, 40, 44), "Fabric", collide=False)
        fr.part(m, "Respaldo", (0, 3, 0.9), (2, 2.2, 0.2), (40, 40, 44), "Fabric", collide=False)
        for sx in (-1.15, 1.15):
            fr.part(m, "Rueda", (sx, 1.3, 0.2), (0.2, 2.6, 2.6), (150, 150, 156), "Metal", shape="Cylinder", collide=False)

    # ---------------------------------------------------------------- escuela
    def blackboard(self, p, fr, l):
        if self._blocked(fr, 10, 0.8, l):
            return
        m = rbx.model(p, "Pizarra")
        fr.part(m, "Marco", (0, 6, 0.2), (10, 4.4, 0.3), (150, 110, 70), collide=False)
        fr.part(m, "Pizarra", (0, 6, 0.0), (9.4, 3.8, 0.12), (40, 70, 50), collide=False)
        fr.part(m, "Bandeja", (0, 3.75, -0.15), (9, 0.15, 0.5), (150, 110, 70), collide=False)
        for i in range(self.rng.randint(1, 4)):
            fr.part(m, "Tiza", (self.rng.uniform(-4, 4), 6 + self.rng.uniform(-1.4, 1.4), -0.08), (self.rng.uniform(1, 3), 0.1, 0.02),
                    (230, 230, 220), collide=False, shadow=False, lrot=rbx.rot_z(self.rng.uniform(-10, 10)))

    def school_desk(self, p, fr):
        m = rbx.model(p, "Pupitre")
        fr.part(m, "Tablero", (0, 2.5, 0), (3, 0.2, 2), (200, 170, 120))
        for sx in (-1.3, 1.3):
            fr.part(m, "Pata", (sx, 1.2, 0), (0.2, 2.4, 1.8), (90, 110, 140), "Metal", collide=False)
        fr.part(m, "Silla", (0, 1.5, 1.9), (1.8, 0.2, 1.6), (90, 130, 170))
        fr.part(m, "Respaldo", (0, 2.6, 2.7), (1.8, 1.8, 0.2), (90, 130, 170), collide=False)
        if self.rng.random() < 0.25:
            fr.part(m, "Cuaderno", (0.3, 2.65, -0.2), (1.0, 0.08, 1.3), self.rng.choice([(200, 60, 60), (60, 100, 200), (230, 200, 60)]),
                    collide=False, shadow=False, lrot=rbx.rot_y(self.rng.uniform(-30, 30)))

    def bookcase(self, p, fr, l):
        if self._blocked(fr, 7, 2.4, l):
            return
        m = rbx.model(p, "Librero")
        fr.part(m, "Cuerpo", (0, 4.5, 0.6), (7, 9, 1.0), (120, 84, 56))
        for y in (0.4, 2.6, 4.8, 7.0):
            fr.part(m, "Balda", (0, y, 0), (7, 0.25, 2.2), (130, 92, 60))
            x = -3.3
            while x < 3.0:
                w = self.rng.uniform(1.2, 2.4)  # bloques de libros (un color por bloque): pocas piezas
                h = self.rng.uniform(1.3, 1.9)
                if self.rng.random() < 0.8:
                    fr.part(m, "Libros", (x + w / 2, y + 0.12 + h / 2, 0.1), (w, h, 1.6),
                            self.rng.choice([(150, 50, 50), (50, 80, 140), (60, 120, 70), (200, 170, 90), (90, 60, 110)]), collide=False)
                x += w + 0.1

    def toilet(self, p, fr, l):
        m = rbx.model(p, "Inodoro")
        fr.part(m, "Taza", (0, 1.0, 0.2), (1.6, 2.0, 2.2), (236, 236, 236))
        fr.part(m, "Cisterna", (0, 2.6, 1.3), (2.0, 1.6, 0.8), (236, 236, 236))

    def stall(self, p, fr, l):
        """Cubículo de baño con puerta: escondite."""
        if self._blocked(fr, 4.4, 4.4, l):
            return
        m = rbx.model(p, "Cubiculo")
        col = self.th("stall", (120, 170, 190))
        for sx in (-2.1, 2.1):
            fr.part(m, "Tabique", (sx, 3.8, 0), (0.2, 7, 4.4), col)
        fr.part(m, "Puerta", (0, 4.0, -2.15), (3.8, 6.4, 0.15), col, collide=False)
        fr.part(m, "Pestillo", (1.4, 4.0, -2.25), (0.3, 0.3, 0.1), (200, 60, 60), collide=False)
        self.toilet(m, fr, l)
        self._hide(m, fr, (0, 3.0, 0), (3.0, 6.0, 3.0), "Cubículo")

    def sink_row(self, p, fr, l):
        if self._blocked(fr, 8, 2.2, l):
            return
        m = rbx.model(p, "Lavabos")
        fr.part(m, "Encimera", (0, 3, 0.2), (8, 0.4, 2), (220, 220, 214))
        for i in range(3):
            fr.part(m, "Pila", (-2.6 + i * 2.6, 3.1, 0.1), (1.6, 0.3, 1.2), (190, 196, 200), "Metal", collide=False)
            fr.part(m, "Espejo", (-2.6 + i * 2.6, 6, 0.95), (2.2, 2.6, 0.1), (200, 220, 230), "Glass", collide=False, reflect=0.4)

    # ---------------------------------------------------------------- mansión
    def piano(self, p, fr, l):
        if self._blocked(fr, 6, 4.5, l):
            return
        m = rbx.model(p, "Piano")
        fr.part(m, "Caja", (0, 3.2, 0.4), (6, 4.4, 2.6), (24, 20, 20))
        fr.part(m, "Teclado", (0, 2.9, -1.4), (5.4, 0.3, 1.2), (240, 236, 226), collide=False)
        fr.part(m, "Banqueta", (0, 1.4, -3), (3, 0.5, 1.2), (60, 40, 30), collide=False)

    def sofa(self, p, fr, l):
        if self._blocked(fr, 7, 3.2, l):
            return
        m = rbx.model(p, "Sofa")
        col = self.th("fabric", self.rng.choice([(120, 40, 50), (60, 80, 60), (80, 60, 90), (150, 120, 80)]))
        fr.part(m, "Asiento", (0, 1.4, 0), (7, 1.4, 3), col, "Fabric")
        fr.part(m, "Respaldo", (0, 3.0, 1.2), (7, 2.4, 0.8), col, "Fabric")
        for sx in (-3.3, 3.3):
            fr.part(m, "Brazo", (sx, 2.2, 0), (0.6, 1.6, 3), col, "Fabric")

    def fireplace(self, p, fr, l):
        if self._blocked(fr, 7, 2.6, l):
            return
        m = rbx.model(p, "Chimenea")
        fr.part(m, "Marco", (0, 4, 0.6), (7, 8, 1.4), (150, 140, 130), "Marble")
        fr.part(m, "Hogar", (0, 2.2, -0.2), (4, 3.6, 0.6), (20, 16, 14), collide=False)
        fr.part(m, "Repisa", (0, 6.2, -0.4), (7.6, 0.4, 1.6), (120, 100, 90), "Marble", collide=False)
        if self.rng.random() < 0.6:
            g = fr.part(m, "Brasas", (0, 1.0, -0.3), (2.6, 0.6, 0.6), (255, 110, 40), "Neon", collide=False, shadow=False)
            rbx.light(g, "PointLight", (255, 120, 50), 1.6, 18, shadows=True)
            g.tags.append("LamparaInstalacion")
            g.attrs["Parpadeo"] = True

    def grandclock(self, p, fr, l):
        if self._blocked(fr, 2.4, 2, l):
            return
        m = rbx.model(p, "Reloj")
        fr.part(m, "Caja", (0, 4.5, 0), (2.2, 9, 1.8), (80, 50, 30), "Wood")
        fr.part(m, "Esfera", (0, 7.5, -0.95), (1.6, 1.6, 0.1), (230, 220, 190), shape="Cylinder", collide=False, lrot=rbx.rot_y(90))

    def painting(self, p, fr, l):
        m = rbx.model(p, "Cuadro")
        w, h = self.rng.uniform(3, 6), self.rng.uniform(3, 5)
        fr.part(m, "Marco", (0, 6.5, 0.25), (w + 0.6, h + 0.6, 0.2), (170, 130, 60), collide=False)
        fr.part(m, "Lienzo", (0, 6.5, 0.12), (w, h, 0.1), self.rng.choice([(60, 50, 40), (40, 60, 70), (90, 40, 40), (70, 80, 50)]),
                collide=False, shadow=False)

    def bathtub(self, p, fr, l):
        if self._blocked(fr, 6.5, 3.6, l):
            return
        m = rbx.model(p, "Banera")
        fr.part(m, "Cuerpo", (0, 1.4, 0), (6.4, 2.8, 3.4), (236, 236, 230))
        fr.part(m, "Agua", (0, 2.4, 0), (5.6, 0.2, 2.6), (90, 110, 100), "Glass", collide=False, transparency=0.2)

    def kitchen(self, p, fr, l):
        if self._blocked(fr, 8, 3, l):
            return
        m = rbx.model(p, "Cocina")
        fr.part(m, "Mueble", (0, 1.6, 0), (8, 3.2, 2.8), (200, 196, 184))
        fr.part(m, "Encimera", (0, 3.3, 0), (8.2, 0.3, 3), (90, 90, 96))
        for i in range(4):
            fr.part(m, "Fuego", (1.5 + (i % 2) * 1.4, 3.5, -0.4 + (i // 2) * 1.2), (0.9, 0.1, 0.9), (30, 30, 30), shape="Cylinder",
                    collide=False, lrot=rbx.rot_z(90))
        fr.part(m, "Fregadero", (-2, 3.4, 0), (2.4, 0.2, 1.8), (170, 176, 180), "Metal", collide=False)
        fr.part(m, "Altillo", (0, 8, 1), (8, 2.4, 1.2), (200, 196, 184), collide=False)

    def fridge(self, p, fr, l):
        if self._blocked(fr, 3.4, 3, l):
            return
        m = rbx.model(p, "Nevera")
        fr.part(m, "Cuerpo", (0, 3.6, 0), (3.2, 7.2, 2.8), (220, 224, 226))
        fr.part(m, "Asa", (1.2, 4.5, -1.45), (0.15, 2, 0.15), (150, 150, 150), "Metal", collide=False)

    def trunk(self, p, fr, l):
        if self._blocked(fr, 4, 3, l):
            return
        m = rbx.model(p, "Baul")
        fr.part(m, "Cuerpo", (0, 1.2, 0), (4, 2.4, 2.6), (100, 70, 40), "WoodPlanks")
        fr.part(m, "Tapa", (0, 2.6, 0), (4.1, 0.5, 2.7), (80, 56, 32), "Wood")
        fr.part(m, "Cierre", (0, 2.2, -1.36), (0.6, 0.6, 0.1), (200, 170, 80), "Metal", collide=False)

    def long_table(self, p, fr):
        m = rbx.model(p, "MesaLarga")
        fr.part(m, "Tablero", (0, 3, 0), (14, 0.4, 4), (90, 56, 34), "Wood")
        for sx in (-6, 6):
            fr.part(m, "Pata", (sx, 1.4, 0), (0.6, 2.8, 3.4), (70, 44, 26), "Wood")
        for i in range(5):
            for sz in (-2.8, 2.8):
                fr.part(m, "Silla", (-5 + i * 2.5, 1.8, sz), (1.6, 0.3, 1.6), (70, 44, 26), "Wood", collide=False)
                fr.part(m, "Respaldo", (-5 + i * 2.5, 3.6, sz + (0.8 if sz > 0 else -0.8)), (1.6, 3.2, 0.2), (70, 44, 26), "Wood",
                        collide=False)
        for x in (-4, 0, 4):
            fr.part(m, "Candelabro", (x, 3.9, 0), (0.3, 1.4, 0.3), (200, 170, 80), "Metal", collide=False)
        g = fr.part(m, "Vela", (0, 4.8, 0), (0.25, 0.4, 0.25), (255, 190, 110), "Neon", collide=False, shadow=False)
        rbx.light(g, "PointLight", (255, 170, 90), 0.9, 14)

    # ---------------------------------------------------------------- centro comercial
    def clothes_rack(self, p, fr):
        m = rbx.model(p, "Burro")
        fr.part(m, "Barra", (0, 5, 0), (6, 0.2, 0.2), (180, 180, 186), "Metal", collide=False)
        for sx in (-2.9, 2.9):
            fr.part(m, "Pie", (sx, 2.5, 0), (0.2, 5, 1.6), (180, 180, 186), "Metal", collide=False)
        for i in range(4):
            fr.part(m, "Prenda", (-2.2 + i * 1.45, 3.6, 0), (0.9, 2.6, 1.8),
                    self.rng.choice([(180, 60, 60), (60, 90, 160), (230, 210, 170), (40, 40, 44), (90, 150, 90)]), "Fabric",
                    collide=False, shadow=False)
        fr.part(m, "Colision", (0, 2.5, 0), (6, 5, 2), (0, 0, 0), transparency=1, shadow=False)

    def mannequin(self, p, fr):
        m = rbx.model(p, "Maniqui")
        col = (230, 226, 218)
        fr.part(m, "Base", (0, 0.2, 0), (1.6, 0.4, 1.6), (60, 60, 60), shape="Cylinder", lrot=rbx.rot_z(90))
        fr.part(m, "Pierna", (0, 2.4, 0), (1.2, 4, 0.8), col)
        fr.part(m, "Torso", (0, 5.4, 0), (1.8, 2.6, 1.0), self.rng.choice([(180, 60, 60), (60, 90, 160), (230, 210, 170)]), "Fabric")
        fr.ell(m, "Cabeza", (0, 7.3, 0), (1.0, 1.3, 1.0), col, collide=False)
        if self.rng.random() < 0.15:  # alguno mira hacia otro lado...
            fr.part(m, "Brazo", (1.2, 6, -0.6), (0.4, 0.4, 2.4), col, collide=False)

    def fitting(self, p, fr, l):
        """Probador con cortina: escondite."""
        if self._blocked(fr, 4.4, 4.4, l):
            return
        m = rbx.model(p, "Probador")
        for sx in (-2.1, 2.1):
            fr.part(m, "Tabique", (sx, 4, 0), (0.25, 8, 4.4), (210, 204, 196))
        fr.part(m, "Cortina", (0, 4.2, -2.1), (3.9, 7, 0.15), self.th("curtain", (130, 40, 50)), "Fabric", collide=False)
        fr.part(m, "Espejo", (0, 4.5, 2.0), (2.4, 5, 0.1), (200, 220, 230), "Glass", collide=False, reflect=0.5)
        self._hide(m, fr, (0, 3.0, 0), (3.0, 6.0, 3.0), "Probador")

    def gondola(self, p, fr):
        m = rbx.model(p, "Gondola")
        fr.part(m, "Cuerpo", (0, 2.8, 0), (10, 5.6, 1.2), (220, 220, 214))
        for side in (-1, 1):
            for y in (1.0, 2.8, 4.6):
                fr.part(m, "Balda", (0, y, side * 1.0), (10, 0.15, 0.9), (200, 200, 196), "Metal", collide=False)
                x = -4.6
                while x < 4.4:
                    w = self.rng.uniform(1.2, 2.4)
                    if self.rng.random() < 0.6:
                        fr.part(m, "Producto", (x + w / 2, y + 0.6, side * 1.0), (w, 1.0, 0.7),
                                self.rng.choice([(200, 60, 50), (240, 200, 60), (60, 140, 200), (90, 170, 90), (240, 240, 230)]),
                                collide=False, shadow=False)
                    x += w + 0.1

    def counter(self, p, fr, l):
        if self._blocked(fr, 7, 3, l):
            return
        m = rbx.model(p, "Mostrador")
        fr.part(m, "Cuerpo", (0, 2, 0), (7, 4, 2.6), self.th("counter", (170, 150, 120)))
        fr.part(m, "Encimera", (0, 4.1, 0), (7.2, 0.25, 2.8), (60, 60, 64))
        fr.part(m, "Caja", (1.8, 4.7, 0), (1.6, 1.0, 1.4), (50, 50, 54), collide=False)
        g = fr.part(m, "Pantalla", (1.8, 5.4, 0.5), (1.2, 0.8, 0.05), (90, 200, 255), "Neon", collide=False, shadow=False)

    def tvwall(self, p, fr, l):
        if self._blocked(fr, 9, 1.2, l):
            return
        m = rbx.model(p, "Televisores")
        for i in range(3):
            for j in range(2):
                fr.part(m, "Tele", (-3 + i * 3, 4 + j * 2.4, 0.2), (2.8, 2, 0.4), (20, 20, 24), collide=False)
                g = fr.part(m, "Imagen", (-3 + i * 3, 4 + j * 2.4, -0.02), (2.5, 1.7, 0.05),
                            self.rng.choice([(60, 80, 255), (240, 240, 250), (20, 20, 20), (200, 60, 200)]), "Neon", collide=False,
                            shadow=False)
        rbx.light(g, "PointLight", (140, 160, 255), 0.8, 14)

    def display_case(self, p, fr):
        m = rbx.model(p, "Vitrina")
        fr.part(m, "Base", (0, 1.6, 0), (6, 3.2, 2.6), (60, 50, 50))
        fr.part(m, "Vidrio", (0, 4.2, 0), (6, 2, 2.6), (200, 230, 240), "Glass", transparency=0.7)
        for i in range(4):
            fr.part(m, "Joya", (-2.2 + i * 1.5, 3.5, 0), (0.4, 0.4, 0.4), (255, 220, 120), "Neon", shape="Ball", collide=False,
                    shadow=False)

    def cinema_seat(self, p, fr):
        m = rbx.model(p, "Butacas")
        for i in range(4):
            fr.part(m, "Asiento", (-4.5 + i * 3, 1.5, 0), (2.6, 1.0, 2.4), (130, 30, 40), "Fabric")
            fr.part(m, "Respaldo", (-4.5 + i * 3, 3.2, 1.1), (2.6, 2.6, 0.5), (130, 30, 40), "Fabric", collide=False)

    def cart(self, p, fr):
        m = rbx.model(p, "Carrito")
        fr.part(m, "Cesta", (0, 2.6, 0), (2, 1.8, 3), (170, 176, 180), "Metal", transparency=0.3, collide=False)
        fr.part(m, "Asa", (0, 3.8, 1.6), (2, 0.2, 0.2), (200, 40, 40), collide=False)
        fr.part(m, "Chasis", (0, 1.0, 0), (1.8, 0.2, 2.8), (150, 150, 156), "Metal", collide=False)

    # ---------------------------------------------------------------- exteriores
    def park_bench(self, p, fr):
        m = rbx.model(p, "Banco")
        fr.part(m, "Asiento", (0, 1.8, 0), (6, 0.3, 1.6), (130, 90, 56), "WoodPlanks")
        fr.part(m, "Respaldo", (0, 3.0, 0.8), (6, 1.6, 0.2), (130, 90, 56), "WoodPlanks", collide=False)
        for sx in (-2.6, 2.6):
            fr.part(m, "Pata", (sx, 0.9, 0), (0.3, 1.8, 1.6), (50, 50, 54), "Metal")

    def picnic(self, p, fr):
        m = rbx.model(p, "MesaPicnic")
        fr.part(m, "Tablero", (0, 3, 0), (6, 0.3, 3), (140, 100, 64), "WoodPlanks")
        for sz in (-2.4, 2.4):
            fr.part(m, "Banco", (0, 1.7, sz), (6, 0.3, 1.2), (140, 100, 64), "WoodPlanks")
        fr.part(m, "Pie", (0, 1.5, 0), (5, 3, 0.3), (100, 70, 44), "Wood")
        if self.rng.random() < 0.4:
            fr.part(m, "Sombrilla", (0, 8, 0), (7, 0.4, 7), self.rng.choice([(200, 60, 50), (60, 110, 180)]), "Fabric",
                    shape="Cylinder", lrot=rbx.rot_z(90), collide=False)
            fr.part(m, "Mastil", (0, 5, 0), (0.2, 6, 0.2), (200, 200, 200), "Metal", collide=False)

    def food_stall(self, p, fr):
        """Puesto de comida: mostrador, toldo a rayas, rótulo con neón y una luz cálida."""
        m = rbx.model(p, "PuestoComida")
        col = self.rng.choice([(200, 70, 60), (60, 120, 170), (230, 170, 50), (80, 150, 90)])
        fr.part(m, "Mostrador", (0, 2, -1.5), (8, 4, 2), (230, 226, 214))
        fr.part(m, "Caseta", (0, 4.5, 1.5), (8, 9, 4), col)
        fr.part(m, "Hueco", (0, 5.6, -0.5), (6.6, 3.2, 0.2), (30, 30, 30), collide=False)
        for i in range(5):
            fr.part(m, "Toldo", (-3.2 + i * 1.6, 9.2, -1.8), (1.6, 0.3, 3), col if i % 2 else (240, 240, 236), "Fabric", collide=False,
                    lrot=rbx.rot_x(-15))
        name = fr.part(m, "Rotulo", (0, 10.6, -0.4), (6, 1.4, 0.3), self.rng.choice([(255, 220, 80), (255, 120, 160), (120, 240, 255)]),
                       "Neon", collide=False, shadow=False)
        rbx.light(name, "PointLight", (255, 200, 140), 1.1, 20)
        if self.rng.random() < 0.4:
            name.tags.append("LamparaInstalacion")
            name.attrs["Parpadeo"] = True
        for i in range(3):
            fr.part(m, "Taburete", (-2.5 + i * 2.5, 1.5, -3.6), (1.2, 3, 1.2), (90, 90, 96), shape="Cylinder", collide=False,
                    lrot=rbx.rot_z(90))

    def food_cart(self, p, fr):
        m = rbx.model(p, "CarroComida")
        fr.part(m, "Caja", (0, 2.8, 0), (5, 2.6, 2.6), (220, 220, 214))
        for sx in (-1.8, 1.8):
            fr.part(m, "Rueda", (sx, 1.0, 1.4), (0.3, 2, 2), (40, 40, 40), shape="Cylinder", collide=False)
        fr.part(m, "Sombrilla", (0, 7.6, 0), (6, 0.3, 6), self.rng.choice([(230, 80, 60), (250, 200, 60)]), "Fabric", shape="Cylinder",
                lrot=rbx.rot_z(90), collide=False)
        fr.part(m, "Mastil", (0, 5.6, 0), (0.2, 4, 0.2), (200, 200, 200), "Metal", collide=False)

    def fountain(self, p, fr):
        m = rbx.model(p, "Fuente")
        rbx.cylinder_y(m, "Pilon", fr.w(0, 0.9, 0), 1.8, 12, (170, 166, 156))
        rbx.cylinder_y(m, "Agua", fr.w(0, 1.6, 0), 0.4, 11, (60, 110, 120), "Glass", collide=False, transparency=0.25)
        rbx.cylinder_y(m, "Columna", fr.w(0, 3.6, 0), 4, 1.4, (170, 166, 156))
        rbx.cylinder_y(m, "Taza", fr.w(0, 5.6, 0), 0.8, 4.4, (170, 166, 156))

    def parallel_bars(self, p, fr):
        m = rbx.model(p, "Paralelas")
        for sz in (-1, 1):
            fr.part(m, "Barra", (0, 3.4, sz), (8, 0.3, 0.3), (230, 230, 230), "Metal", collide=False)
            for sx in (-3.8, 3.8):
                fr.part(m, "Poste", (sx, 1.7, sz), (0.3, 3.4, 0.3), (60, 110, 170), "Metal")

    def rehab_steps(self, p, fr):
        m = rbx.model(p, "EscaleraRehab")
        for i in range(3):
            fr.part(m, "Peldano", (-2 + i * 1.6, 0.4 + i * 0.4, 0), (1.6, 0.8 + i * 0.8, 3), (120, 160, 200))
        fr.part(m, "Rampa", (3.4, 0.6, 0), (3, 0.3, 3), (120, 160, 200), cls="WedgePart", lrot=rbx.rot_y(-90))

    def swing(self, p, fr):
        m = rbx.model(p, "Columpios")
        col = (200, 60, 60)
        for sx in (-4, 4):
            for sz in (-1.5, 1.5):
                fr.part(m, "Pata", (sx, 4, sz * 0.6), (0.4, 8.4, 0.4), col, "Metal", lrot=rbx.rot_x(sz * 10))
        fr.part(m, "Travesano", (0, 8, 0), (8.4, 0.4, 0.4), col, "Metal", collide=False)
        for sx in (-2, 2):
            for cx in (-0.6, 0.6):
                fr.part(m, "Cadena", (sx + cx, 5.2, 0), (0.1, 5.4, 0.1), (160, 160, 160), "Metal", collide=False)
            fr.part(m, "Asiento", (sx, 2.4, 0), (1.6, 0.2, 0.8), (40, 40, 40), collide=False)

    def slide(self, p, fr):
        m = rbx.model(p, "Tobogan")
        fr.part(m, "Torre", (-3, 3, 0), (3, 6, 3), (240, 190, 50))
        fr.part(m, "Tejadillo", (-3, 7.5, 0), (3.6, 1.6, 3.6), (200, 60, 60), cls="WedgePart")
        fr.part(m, "Rampa", (1.6, 3, 0), (2.4, 6, 6.4), (60, 140, 220), cls="WedgePart", lrot=rbx.rot_y(-90))

    def seesaw(self, p, fr):
        m = rbx.model(p, "Balancin")
        fr.part(m, "Eje", (0, 1, 0), (0.8, 2, 0.8), (90, 90, 96), "Metal")
        fr.part(m, "Tabla", (0, 1.5, 0), (9, 0.3, 1.2), (60, 160, 90), lrot=rbx.rot_z(12))

    def hoop(self, p, fr):
        m = rbx.model(p, "Canasta")
        fr.part(m, "Poste", (0, 6, 1.5), (0.6, 12, 0.6), (60, 60, 66), "Metal")
        fr.part(m, "Tablero", (0, 11, 0.6), (5, 3.4, 0.3), (240, 240, 240))
        fr.part(m, "Aro", (0, 10, -0.4), (1.8, 0.15, 1.8), (230, 100, 40), "Metal", shape="Cylinder", collide=False, lrot=rbx.rot_z(90))

    def sandbox(self, p, fr):
        m = rbx.model(p, "Arenero")
        fr.part(m, "Arena", (0, 0.3, 0), (9, 0.6, 9), (220, 200, 150), "Sand", collide=False)
        for (x, z, w, d) in ((-4.6, 0, 0.6, 10), (4.6, 0, 0.6, 10), (0, -4.6, 9, 0.6), (0, 4.6, 9, 0.6)):
            fr.part(m, "Borde", (x, 0.6, z), (w, 1.2, d), (200, 90, 60))
        fr.part(m, "Cubo", (1.5, 1.0, -1), (1, 1, 1), (60, 120, 220), shape="Cylinder", collide=False, lrot=rbx.rot_z(90))

    def car(self, p, fr):
        """Coche abandonado (bloque con cabina, ventanillas y ruedas)."""
        m = rbx.model(p, "Coche")
        col = self.rng.choice([(150, 40, 40), (40, 70, 130), (200, 200, 196), (60, 60, 64), (120, 130, 90), (180, 150, 60)])
        fr.part(m, "Carroceria", (0, 2.2, 0), (5, 2.4, 10), col)
        fr.part(m, "Cabina", (0, 4.2, 0.4), (4.6, 1.8, 5.4), col)
        fr.part(m, "Lunas", (0, 4.25, 0.4), (4.7, 1.3, 5.5), (40, 50, 60), "Glass", collide=False, transparency=0.2)
        for sx in (-2.5, 2.5):
            for sz in (-3.2, 3.2):
                fr.part(m, "Rueda", (sx, 1.1, sz), (0.8, 2.2, 2.2), (25, 25, 25), shape="Cylinder", collide=False)
        if self.rng.random() < 0.15:
            g = fr.part(m, "Faro", (1.6, 2.4, -5.02), (1, 0.5, 0.1), (255, 240, 200), "Neon", collide=False, shadow=False)
            rbx.light(g, "SpotLight", (255, 240, 200), 2, 40, face="Front", angle=50)

    def bus(self, p, fr):
        """Autobús escolar abandonado. Dentro, entre los asientos, hay un escondite."""
        m = rbx.model(p, "Autobus")
        y = (235, 180, 30)
        fr.part(m, "Suelo", (0, 1.6, 0), (8, 1, 30), (70, 70, 70))
        for sx in (-3.8, 3.8):
            fr.part(m, "Lateral", (sx, 3.6, 0), (0.4, 3, 30), y)
            fr.part(m, "Ventanas", (sx, 6.0, 0), (0.3, 1.8, 28), (40, 46, 50), "Glass", transparency=0.35, collide=False)
            fr.part(m, "Franja", (sx, 4.6, 0), (0.45, 0.3, 30), (30, 30, 30), collide=False)
        fr.part(m, "Techo", (0, 7.4, 0), (8, 0.8, 30), y)
        fr.part(m, "Trasera", (0, 4.5, 14.8), (8, 6, 0.4), y)
        fr.part(m, "Morro", (0, 3.2, -16.5), (8, 3.6, 3), y)
        fr.part(m, "Frente", (0, 4.8, -14.9), (8, 6.2, 0.4), (40, 46, 50), "Glass", transparency=0.35)
        for sz in (-12, -4, 8, 12):
            for sx in (-3.9, 3.9):
                fr.part(m, "Rueda", (sx, 1.3, sz), (0.8, 2.6, 2.6), (25, 25, 25), shape="Cylinder", collide=False)
        for i in range(7):
            for sx in (-2.3, 2.3):
                fr.part(m, "Asiento", (sx, 2.6, -10 + i * 3.6), (2.8, 1.0, 1.4), (120, 60, 40), "Fabric", collide=False)
                fr.part(m, "Respaldo", (sx, 3.6, -10 + i * 3.6 + 0.7), (2.8, 1.8, 0.3), (120, 60, 40), "Fabric", collide=False)
        fr.part(m, "Rotulo", (0, 7.0, -15.2), (5, 0.8, 0.1), (20, 20, 20), collide=False)
        self._hide(m, fr, (2.3, 3.6, 8), (2.6, 5.0, 2.6), "Autobús")

    def gazebo(self, p, fr):
        m = rbx.model(p, "Templete")
        rbx.cylinder_y(m, "Suelo", fr.w(0, 0.5, 0), 1, 12, (220, 216, 206))
        for i in range(6):
            a = i * math.pi / 3
            rbx.cylinder_y(m, "Columna", fr.w(math.cos(a) * 5, 4.5, math.sin(a) * 5), 8, 0.7, (236, 232, 222))
        rbx.cylinder_y(m, "Cupula", fr.w(0, 9.2, 0), 1.2, 13, (220, 216, 206), collide=False)
        rbx.ellipsoid(m, "Remate", fr.w(0, 10.5, 0), (8, 3, 8), (220, 216, 206))

    def pergola_light(self, p, pos, col=(255, 200, 140)):
        g = rbx.part(p, "Guirnalda", pos, (0.4, 0.4, 0.4), col, "Neon", shape="Ball", collide=False, query=False, shadow=False)
        return g
