"""Piezas compartidas por los dos niveles: marcadores del manifiesto, escondites, colocación contra muros y perspectiva forzada."""
from __future__ import annotations

import math

from build import Builder
from layout import DIRS
import rbx


def yaw_for(d: int) -> float:
    """Ángulo rot_y que lleva el +Z local a la dirección DIRS[d] (el fondo del mueble contra el muro)."""
    dx, dz = DIRS[d]
    return math.degrees(math.atan2(dx, dz))


class Frame:
    """Marco local de un mueble: X a lo largo del muro, Y arriba, +Z hacia el muro (fondo)."""

    def __init__(self, pos, yaw):
        self.pos = pos
        self.rot = rbx.rot_y(yaw)
        self.yaw = yaw

    def w(self, lx, ly, lz):
        v = rbx.mat_apply(self.rot, (lx, ly, lz))
        return (self.pos[0] + v[0], self.pos[1] + v[1], self.pos[2] + v[2])

    def part(self, parent, name, lpos, size, color, mat="SmoothPlastic", **kw):
        rot = kw.pop("lrot", None)
        r = self.rot if rot is None else rbx.mat_mul(self.rot, rot)
        return rbx.part(parent, name, self.w(*lpos), size, color, mat, rot=r, **kw)

    def ell(self, parent, name, lpos, size, color, mat="SmoothPlastic", **kw):
        p = rbx.ellipsoid(parent, name, self.w(*lpos), size, color, mat, **kw)
        p.props["rot"] = self.rot
        return p


def against_wall(B: Builder, cell, d, depth, inset=0.6):
    """Marco para un mueble de fondo `depth` apoyado en el muro del lado d de la celda."""
    l, x, z = cell
    cx, cy, cz = B.cell_center(x, z, l)
    dx, dz = DIRS[d]
    off = B.C / 2 - inset - depth / 2
    return Frame((cx + dx * off, cy, cz + dz * off), yaw_for(d))


def wall_slots(B: Builder, space, avoid_doors=True):
    """(celda, d) con muro macizo en el lado d: sitio para apoyar muebles."""
    out = []
    for c in sorted(space.cells):
        if c in space.void:
            continue
        l, x, z = c
        if avoid_doors and c in B.door_cells:
            continue
        for d in range(4):
            n = (l, x + DIRS[d][0], z + DIRS[d][1])
            if B.classify(c, n) == "wall":
                # que no sea la jamba de una puerta vecina
                near_door = False
                for sd in ((d + 1) % 4, (d + 3) % 4):
                    s2 = (l, x + DIRS[sd][0], z + DIRS[sd][1])
                    if s2 in B.door_cells and s2 in space.cells:
                        n2 = (l, s2[1] + DIRS[d][0], s2[2] + DIRS[d][1])
                        if B.lay.link_kind(s2, n2) in ("door", "puzzle"):
                            near_door = True
                if not near_door:
                    out.append((c, d))
    return out


def marker(B: Builder, folder, part_name, att_name, pos, att_attrs=None, part_attrs=None):
    p = rbx.part(folder, part_name, pos, (0.4, 0.4, 0.4), (40, 40, 40), collide=False, query=False, shadow=False,
                 transparency=1.0, attrs=part_attrs)
    if att_name:
        rbx.attachment(p, att_name, (0, 0, 0), att_attrs)
    B.markers.append((att_name or part_name, pos[0], pos[1], pos[2]))
    return p


def hide_volume(parent, pos, size, kind, label, rot=None):
    """Volumen `Escondite` (lo usa HidingHandlers): el jugador queda en su centro. Kind: Locker | Bush."""
    return rbx.part(parent, "Escondite", pos, size, (60, 60, 60), collide=False, query=False, shadow=False, transparency=1.0,
                    rot=rot, attrs={"Kind": kind, "Label": label})


def locker(B: Builder, parent, fr: Frame, idx: int, body=(92, 112, 120), trim=(50, 58, 64), hideable=True, name="Taquilla"):
    """Taquilla de 3.2 de ancho, 2.8 de fondo y 7.4 de alto, con rejilla en la puerta. Origen = centro del suelo."""
    m = rbx.model(parent, f"{name}{idx:02d}")
    fr.part(m, "Cuerpo", (0, 3.7, 0.2), (3.2, 7.4, 2.6), body)
    fr.part(m, "Puerta", (0, 3.6, -1.15), (2.9, 6.9, 0.15), tuple(min(255, c + 14) for c in body), collide=False)
    for i in range(5):
        fr.part(m, "Rejilla", (0, 5.9 - i * 0.32, -1.25), (1.9, 0.1, 0.06), trim, collide=False, shadow=False)
    fr.part(m, "Asa", (1.0, 3.6, -1.28), (0.18, 0.9, 0.12), (190, 190, 180), "Metal", collide=False)
    fr.part(m, "Placa", (0, 6.9, -1.27), (1.0, 0.35, 0.05), (220, 220, 200), collide=False, shadow=False)
    if hideable:
        hide_volume(m, fr.w(0, 3.0, 0.2), (2.6, 6.0, 2.0), "Locker", "Taquilla", rot=fr.rot)
        B.markers.append(("Escondite", *fr.w(0, 0, 0)))
    return m


def forced_corridor(B: Builder, parent, edge_mid, d, floor_y, length, height, width, palette, segs=9, eye=5.5):
    """Pasillo falso en perspectiva forzada detrás de una reja: las paredes convergen hacia un punto de fuga a la altura de los
    ojos, así 40 studs parecen 150. Sin colisión ni consultas (no estorba a criaturas ni rayos)."""
    dx, dz = DIRS[d]
    m = rbx.model(parent, "PasilloFalso")
    seg_len = length / segs
    kw = dict(collide=False, query=False, shadow=False)
    for i in range(segs):
        t0 = i / segs
        s = 1 - 0.78 * (t0 + 0.5 / segs)
        w = width * s
        y_floor = floor_y + eye * (1 - s)
        y_ceil = floor_y + eye + (height - eye) * s
        dist = (i + 0.5) * seg_len
        cx, cz = edge_mid[0] + dx * dist, edge_mid[1] + dz * dist
        shade = 1 - 0.75 * t0
        floor_c = tuple(int(c * shade) for c in palette["floor"])
        wall_c = tuple(int(c * shade) for c in palette["wall"])
        ceil_c = tuple(int(c * shade) for c in palette["ceil"])
        along = (seg_len + 0.05, 0.2, w) if dx else (w, 0.2, seg_len + 0.05)
        rbx.part(m, "Suelo", (cx, y_floor, cz), along, floor_c, **kw)
        rbx.part(m, "Techo", (cx, y_ceil, cz), along, ceil_c, **kw)
        side = (0.2, y_ceil - y_floor, seg_len + 0.05) if dx == 0 else (seg_len + 0.05, y_ceil - y_floor, 0.2)
        for sgn in (-1, 1):
            ox, oz = (sgn * w / 2, 0) if dx == 0 else (0, sgn * w / 2)
            rbx.part(m, "Pared", (cx + ox, (y_floor + y_ceil) / 2, cz + oz), side, wall_c, **kw)
        if i % 2 == 0:
            lamp = (seg_len * 0.4, 0.1, 0.3 * s) if dx else (0.3 * s, 0.1, seg_len * 0.4)
            rbx.part(m, "Luz", (cx, y_ceil - 0.1, cz), lamp, palette["lamp"], "Neon", **kw)
    end = length + 0.2
    s = 1 - 0.78
    ex, ez = edge_mid[0] + dx * end, edge_mid[1] + dz * end
    size = (0.2, height * s + 1, width * s + 1) if dx else (width * s + 1, height * s + 1, 0.2)
    rbx.part(m, "Fondo", (ex, floor_y + eye, ez), size, (4, 4, 4), **kw)
    # Una luz tenue a media distancia para que se lea la profundidad
    li = rbx.part(m, "Brillo", (edge_mid[0] + dx * length * 0.35, floor_y + height * 0.55, edge_mid[1] + dz * length * 0.35),
                  (0.2, 0.2, 0.2), (0, 0, 0), transparency=1, **kw)
    rbx.light(li, "PointLight", palette["lamp"], 0.6, 18)
    return m


def grate(B: Builder, parent, axis, line, a0, a1, y0, y1, color=(70, 74, 70)):
    """Reja de barrotes con colisión invisible (cierra un fondo de saco dejando ver lo que hay detrás)."""
    m = rbx.model(parent, "Reja")
    n = int((a1 - a0) / 0.9)
    for i in range(n + 1):
        a = a0 + 0.3 + i * (a1 - a0 - 0.6) / max(1, n)
        if axis == "x":
            rbx.part(m, "Barrote", (a, (y0 + y1) / 2, line), (0.22, y1 - y0, 0.22), color, "Metal", collide=False, query=False)
        else:
            rbx.part(m, "Barrote", (line, (y0 + y1) / 2, a), (0.22, y1 - y0, 0.22), color, "Metal", collide=False, query=False)
    for y in (y0 + 0.4, y0 + (y1 - y0) * 0.5, y1 - 0.4):
        B.wall_box(m, "Travesano", axis, line, a0, a1, y - 0.15, y + 0.15, 0.3, color, "Metal", collide=False, query=False)
    B.wall_box(m, "Colision", axis, line, a0, a1, y0, y1, 0.4, color, transparency=1, shadow=False)
    return m
