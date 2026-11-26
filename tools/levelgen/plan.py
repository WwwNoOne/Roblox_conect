"""Planta en PNG: planta baja y segundo piso lado a lado, con uniones, escaleras y marcadores."""
from __future__ import annotations

from PIL import Image, ImageDraw, ImageFont

from layout import DIRS, Layout

COL = {
    "hub": (214, 196, 120), "shaft": (90, 90, 90), "corridor": (170, 176, 168), "room": (132, 160, 190), "hall": (176, 140, 110),
    "stair": (230, 120, 60), "catwalk": (240, 210, 90), "closet": (150, 120, 160),
}
MARK = {"TreasureSpawn": (80, 220, 230), "MachineSpawn": (255, 220, 60), "Cofre": (255, 140, 0), "Puerta": (230, 50, 70),
        "CreatureSpawn": (200, 30, 200), "Escondite": (60, 200, 90), "Patrol": (255, 255, 255)}


def _font(size):
    for p in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/noto/NotoSans-Bold.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(lay: Layout, path: str, title: str, cell_world: float, markers=None, labels=None, px: int = 9, theme=None,
           layer_h: float = 14.0):
    theme = theme or {}
    bg = theme.get("bg", (32, 34, 36))
    layers = list(range(getattr(lay, "lmin", 0), getattr(lay, "lmax", 1) + 1))
    cols = min(3, len(layers))
    rows = (len(layers) + cols - 1) // cols
    W = lay.w * px
    H = lay.h * px
    pad = 40
    img = Image.new("RGB", (W * cols + pad * (cols + 1), (H + pad) * rows + pad + 30), bg)
    dr = ImageDraw.Draw(img)
    f = _font(16)
    fs = _font(10)
    dr.text((pad, 8), title, fill=(240, 240, 230), font=f)
    names = {-1: "Sótano", 0: "Planta baja"}
    for k, l in enumerate(layers):
        ox, oy = pad + (k % cols) * (W + pad), pad + 20 + (k // cols) * (H + pad)
        dr.rectangle([ox, oy, ox + W, oy + H], outline=(80, 80, 80))
        dr.text((ox, oy - 16), names.get(l, f"Planta {l}"), fill=(200, 200, 190), font=fs)
        for (cl, x, z), sid in lay.occ.items():
            if cl != l:
                continue
            s = lay.spaces[sid]
            c = theme.get(s.kind, COL.get(s.kind, (200, 0, 200)))
            if s.data.get("outdoor"):
                c = theme.get("outdoor", (86, 120, 80)) if not s.data.get("roof") else (110, 110, 116)
            if (cl, x, z) in s.void:
                c = tuple(int(v * 0.45) for v in c)
            dr.rectangle([ox + x * px, oy + z * px, ox + (x + 1) * px - 1, oy + (z + 1) * px - 1], fill=c)
        for kk in getattr(lay, "blocked", ()):
            a, b = sorted(tuple(kk))
            if a[0] != l:
                continue
            if a[1] == b[1]:  # muro horizontal entre (x, z) y (x, z+1)
                yy = oy + b[2] * px
                dr.line([ox + a[1] * px, yy, ox + (a[1] + 1) * px, yy], fill=(20, 50, 20), width=2)
            else:
                xx = ox + b[1] * px
                dr.line([xx, oy + a[2] * px, xx, oy + (a[2] + 1) * px], fill=(20, 50, 20), width=2)
        for kk, kind in lay.links.items():
            a, b = tuple(kk)
            if a[0] != l or b[0] != l or kind not in ("door", "puzzle"):
                continue
            mx = ox + (a[1] + b[1] + 1) / 2 * px
            mz = oy + (a[2] + b[2] + 1) / 2 * px
            col = (230, 50, 70) if kind == "puzzle" else (250, 250, 250)
            dr.rectangle([mx - 2, mz - 2, mx + 2, mz + 2], fill=col)
        if markers:
            for (name, wx, wy, wz) in markers:
                ml = int((wy + 4) // layer_h)
                if ml != l:
                    continue
                key = next((kk for kk in MARK if name.startswith(kk)), None)
                if not key or key == "Patrol":
                    continue
                mx, mz = ox + wx / cell_world * px, oy + wz / cell_world * px
                dr.ellipse([mx - 2.5, mz - 2.5, mx + 2.5, mz + 2.5], fill=MARK[key])
        if labels:
            for (text, wx, wz, ll) in labels:
                if ll == l:
                    dr.text((ox + wx / cell_world * px - 20, oy + wz / cell_world * px - 5), text, fill=(250, 250, 250), font=fs)
    leg = "  ".join(f"● {kk}" for kk in MARK if kk != "Patrol")
    dr.text((pad, img.size[1] - 24), f"{lay.w * cell_world:.0f} × {lay.h * cell_world:.0f} studs · celda {cell_world:g} · {leg}",
            fill=(200, 200, 190), font=fs)
    img.save(path)
