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


def render(lay: Layout, path: str, title: str, cell_world: float, markers=None, labels=None, px: int = 9, theme=None):
    theme = theme or {}
    bg = theme.get("bg", (32, 34, 36))
    W = lay.w * px
    H = lay.h * px
    pad = 40
    img = Image.new("RGB", (W * 2 + pad * 3, H + pad * 2 + 30), bg)
    dr = ImageDraw.Draw(img)
    f = _font(16)
    fs = _font(10)
    dr.text((pad, 8), title, fill=(240, 240, 230), font=f)
    for l in range(2):
        ox, oy = pad + l * (W + pad), pad + 20
        dr.rectangle([ox, oy, ox + W, oy + H], outline=(80, 80, 80))
        dr.text((ox, oy - 16), "Planta baja" if l == 0 else "Segundo piso / pasarelas", fill=(200, 200, 190), font=fs)
        for (cl, x, z), sid in lay.occ.items():
            if cl != l:
                continue
            s = lay.spaces[sid]
            c = theme.get(s.kind, COL.get(s.kind, (200, 0, 200)))
            if (cl, x, z) in s.void:
                c = tuple(int(v * 0.45) for v in c)
            dr.rectangle([ox + x * px, oy + z * px, ox + (x + 1) * px - 1, oy + (z + 1) * px - 1], fill=c)
        # uniones con puerta
        for k, kind in lay.links.items():
            a, b = tuple(k)
            if a[0] != l or b[0] != l or kind not in ("door", "puzzle"):
                continue
            mx = ox + (a[1] + b[1] + 1) / 2 * px
            mz = oy + (a[2] + b[2] + 1) / 2 * px
            col = (230, 50, 70) if kind == "puzzle" else (250, 250, 250)
            dr.rectangle([mx - 2, mz - 2, mx + 2, mz + 2], fill=col)
        if markers:
            for (name, wx, wy, wz) in markers:
                ml = 1 if wy > 10 else 0
                if ml != l:
                    continue
                key = next((k for k in MARK if name.startswith(k)), None)
                if not key or key == "Patrol":
                    continue
                mx, mz = ox + wx / cell_world * px, oy + wz / cell_world * px
                dr.ellipse([mx - 2.5, mz - 2.5, mx + 2.5, mz + 2.5], fill=MARK[key])
        if labels:
            for (text, wx, wz, ll) in labels:
                if ll == l:
                    dr.text((ox + wx / cell_world * px - 20, oy + wz / cell_world * px - 5), text, fill=(250, 250, 250), font=fs)
    leg = "  ".join(f"● {k}" for k in MARK if k != "Patrol")
    dr.text((pad, H + pad + 26), f"{lay.w * cell_world:.0f} × {lay.h * cell_world:.0f} studs · celda {cell_world:g} · {leg}",
            fill=(200, 200, 190), font=fs)
    img.save(path)
