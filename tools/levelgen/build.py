"""Geometría común de un nivel a partir de la planta (layout): suelos, techos, muros, puertas, barandillas y escaleras.

Coordenadas locales: celda (x, z) ocupa [x*C, (x+1)*C] x [z*C, (z+1)*C]; la planta baja pisa y = 0 y el segundo piso y = H.
El tema (level1/level2) decide colores, materiales y la forma de cada elemento; aquí solo se clasifica y se agrupa.
"""
from __future__ import annotations

from layout import DIRS, Layout, Space
import rbx


def merge_rects(cells: set) -> list[tuple[int, int, int, int]]:
    """Rectángulos (x0, x1, z0, z1, inclusivos) que cubren el conjunto de celdas (x, z) — fusión voraz por filas."""
    left = set(cells)
    out = []
    for (x, z) in sorted(cells, key=lambda c: (c[1], c[0])):
        if (x, z) not in left:
            continue
        x1 = x
        while (x1 + 1, z) in left:
            x1 += 1
        z1 = z
        while all((xx, z1 + 1) in left for xx in range(x, x1 + 1)):
            z1 += 1
        for xx in range(x, x1 + 1):
            for zz in range(z, z1 + 1):
                left.discard((xx, zz))
        out.append((x, x1, z, z1))
    return out


class Builder:
    def __init__(self, lay: Layout, C: float, H: float, name: str):
        self.lay, self.C, self.H = lay, C, H
        self.root = rbx.model(None, name)
        self.f = {}
        self.markers: list[tuple[str, float, float, float]] = []
        self.blocked: list[tuple[float, float, float, float, int]] = []  # huellas de muebles (x0, x1, z0, z1, layer)
        self.override: dict = {}  # frozenset({a, b}) -> tipo forzado (p. ej. "grate")
        self.door_cells: set = set()
        for k, v in lay.links.items():
            if v in ("door", "puzzle", "open"):
                for c in k:
                    self.door_cells.add(c)

    def folder(self, path: str) -> rbx.Inst:
        if path not in self.f:
            parent = self.root
            parts = path.split("/")
            for i, p in enumerate(parts):
                key = "/".join(parts[: i + 1])
                if key not in self.f:
                    self.f[key] = rbx.folder(parent, p)
                parent = self.f[key]
        return self.f[path]

    # ---------------------------------------------------------------- utilidades de coordenadas
    def cell_center(self, x, z, l=0):
        return ((x + 0.5) * self.C, l * self.H, (z + 0.5) * self.C)

    def floor_y(self, l):
        return l * self.H

    def space(self, c) -> Space | None:
        return self.lay.space_of(c)

    def is_void(self, c):
        s = self.space(c)
        return s is not None and c in s.void

    def block(self, x0, x1, z0, z1, l):
        self.blocked.append((min(x0, x1), max(x0, x1), min(z0, z1), max(z0, z1), l))

    def free_spot(self, x0, x1, z0, z1, l, pad=0.0):
        for (a0, a1, b0, b1, bl) in self.blocked:
            if bl == l and x0 - pad < a1 and x1 + pad > a0 and z0 - pad < b1 and z1 + pad > b0:
                return False
        return True

    # ---------------------------------------------------------------- clasificación de aristas
    def classify(self, a, b):
        lay = self.lay
        o = self.override.get(frozenset((a, b)))
        if o:
            return o
        sa, sb = lay.space_of(a), lay.space_of(b)
        if sa is None and sb is None:
            return None
        if sa is not None and sb is not None and sa.sid == sb.sid:
            return None
        k = lay.link_kind(a, b)
        if k == "rail":
            return "rail"
        if k == "open":
            return None
        if k in ("door", "puzzle"):
            return k
        va = sa is not None and a in sa.void
        vb = sb is not None and b in sb.void
        if va and vb:
            return None
        return "wall"

    def edges(self, l):
        """Aristas con algo: (tipo, eje, línea, desde, a, celda_a, celda_b). eje 'x' = muro a lo largo de X en z=línea."""
        lay = self.lay
        out = []
        for x in range(lay.w):
            for z in range(lay.h):
                a = (l, x, z)
                for (dx, dz, axis) in ((0, 1, "x"), (1, 0, "z")):
                    b = (l, x + dx, z + dz)
                    t = self.classify(a, b)
                    if t is None:
                        continue
                    if axis == "x":
                        out.append((t, "x", (z + 1) * self.C, x * self.C, (x + 1) * self.C, a, b))
                    else:
                        out.append((t, "z", (x + 1) * self.C, z * self.C, (z + 1) * self.C, a, b))
        return out

    def wall_runs(self, l, key_fn):
        """Agrupa aristas 'wall' contiguas en la misma línea y con la misma clave de estilo."""
        runs = {}
        for (t, axis, line, a0, a1, ca, cb) in self.edges(l):
            if t != "wall":
                continue
            key = (axis, line, key_fn(ca, cb))
            runs.setdefault(key, []).append((a0, a1, ca, cb))
        out = []
        for (axis, line, style), segs in runs.items():
            segs.sort()
            cur = None
            for (a0, a1, ca, cb) in segs:
                if cur and abs(cur[1] - a0) < 1e-6:
                    cur[1] = a1
                    cur[2].append((ca, cb))
                else:
                    if cur:
                        out.append((axis, line, cur[0], cur[1], style, cur[2]))
                    cur = [a0, a1, [(ca, cb)]]
            if cur:
                out.append((axis, line, cur[0], cur[1], style, cur[2]))
        return out

    # ---------------------------------------------------------------- piezas genéricas
    def wall_box(self, parent, name, axis, line, a0, a1, y0, y1, t, color, mat="SmoothPlastic", **kw):
        if axis == "x":
            return rbx.box(parent, name, a0, a1, y0, y1, line - t / 2, line + t / 2, color, mat, **kw)
        return rbx.box(parent, name, line - t / 2, line + t / 2, y0, y1, a0, a1, color, mat, **kw)

    def doorway(self, parent, name, axis, line, a0, a1, y0, y1, t, width, height, color, mat="SmoothPlastic", **kw):
        mid = (a0 + a1) / 2
        d0, d1 = mid - width / 2, mid + width / 2
        self.wall_box(parent, name + "_L", axis, line, a0, d0, y0, y1, t, color, mat, **kw)
        self.wall_box(parent, name + "_R", axis, line, d1, a1, y0, y1, t, color, mat, **kw)
        self.wall_box(parent, name + "_Dintel", axis, line, d0, d1, y0 + height, y1, t, color, mat, **kw)
        return mid

    def stair_steps(self, parent, st: dict, width, color, mat="SmoothPlastic", steps=14, prefix="Escalon", **kw):
        """Escalones macizos. La escalera ocupa 3 celdas en la dirección `dir`; sube H hacia el extremo alto."""
        C, H = self.C, self.H
        d = st["dir"]
        cells = st["cells"]
        dx, dz = DIRS[d]
        # inicio = borde de entrada de la primera celda
        fx, fz = cells[0]
        cx0 = (fx + 0.5) * C - dx * C / 2
        cz0 = (fz + 0.5) * C - dz * C / 2
        run = 3 * C
        depth = run / steps
        rising = st["high_end"] == 2
        for i in range(steps):
            top = (i + 1) * H / steps if rising else (steps - i) * H / steps
            off = (i + 0.5) * depth
            cx, cz = cx0 + dx * off, cz0 + dz * off
            if dx != 0:
                size = (depth + 0.02, top, width)
            else:
                size = (width, top, depth + 0.02)
            rbx.part(parent, f"{prefix}{i + 1:02d}", (cx, top / 2, cz), size, color, mat, **kw)
        return (cx0, cz0, dx, dz, run)
