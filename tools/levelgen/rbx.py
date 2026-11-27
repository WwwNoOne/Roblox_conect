"""Árbol de instancias Roblox mínimo y escritor .rbxmx (XML).

Solo lo que usan los niveles: Model, Folder, Part (Block/Ball/Cylinder), WedgePart, CornerWedgePart, Attachment, luces,
atributos y etiquetas. Las piezas van ancladas y en SmoothPlastic salvo que se diga otra cosa (estilo plástico).
"""
from __future__ import annotations

import base64
import math
import struct
import xml.etree.ElementTree as ET

MAT = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Marble": 784, "Slate": 800,
    "Concrete": 816, "Granite": 832, "Brick": 848, "Pebble": 864, "Cobblestone": 880, "CorrodedMetal": 1040,
    "DiamondPlate": 1056, "Foil": 1072, "Metal": 1088, "Grass": 1280, "Sand": 1296, "Fabric": 1312, "Glass": 1568,
    "Ice": 1536, "ForceField": 1584, "LeafyGrass": 1284, "Mud": 1344, "Ground": 1376,
}
SHAPE = {"Ball": 0, "Block": 1, "Cylinder": 2}
FACE = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}

IDENT = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)


def rot_y(deg: float):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c)


def rot_x(deg: float):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (1.0, 0.0, 0.0, 0.0, c, -s, 0.0, s, c)


def rot_z(deg: float):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0)


def mat_mul(a, b):
    return tuple(sum(a[i * 3 + k] * b[k * 3 + j] for k in range(3)) for i in range(3) for j in range(3))


def mat_apply(m, v):
    return (m[0] * v[0] + m[1] * v[1] + m[2] * v[2], m[3] * v[0] + m[4] * v[1] + m[5] * v[2], m[6] * v[0] + m[7] * v[1] + m[8] * v[2])


def encode_attributes(attrs: dict) -> str:
    buf = bytearray(struct.pack("<I", len(attrs)))
    for k, v in attrs.items():
        kb = k.encode("utf-8")
        buf += struct.pack("<I", len(kb)) + kb
        if isinstance(v, bool):
            buf += struct.pack("<BB", 3, 1 if v else 0)
        elif isinstance(v, str):
            vb = v.encode("utf-8")
            buf += struct.pack("<BI", 2, len(vb)) + vb
        else:
            buf += struct.pack("<Bd", 6, float(v))  # 0x06 = double (0x04 no es un tipo válido)
    return base64.b64encode(bytes(buf)).decode("ascii")


class Inst:
    __slots__ = ("cls", "name", "props", "children", "attrs", "tags")

    def __init__(self, cls: str, name: str):
        self.cls = cls
        self.name = name
        self.props: dict = {}
        self.children: list[Inst] = []
        self.attrs: dict = {}
        self.tags: list[str] = []

    def add(self, child: "Inst") -> "Inst":
        self.children.append(child)
        return child

    def count(self) -> int:
        return 1 + sum(c.count() for c in self.children)

    def iter(self):
        yield self
        for c in self.children:
            yield from c.iter()


def folder(parent: Inst | None, name: str) -> Inst:
    f = Inst("Folder", name)
    if parent is not None:
        parent.add(f)
    return f


def model(parent: Inst | None, name: str) -> Inst:
    m = Inst("Model", name)
    if parent is not None:
        parent.add(m)
    return m


def part(parent: Inst, name: str, pos, size, color, mat: str = "SmoothPlastic", *, rot=None, cls: str = "Part",
         shape: str | None = None, collide: bool = True, query: bool | None = None, shadow: bool = True,
         transparency: float = 0.0, reflect: float = 0.0, attrs: dict | None = None, tags: list[str] | None = None) -> Inst:
    p = Inst(cls, name)
    p.props.update(pos=tuple(pos), rot=rot or IDENT, size=tuple(max(0.05, s) for s in size), color=tuple(color), mat=mat,
                   collide=collide, query=collide if query is None else query, shadow=shadow, transparency=transparency,
                   reflect=reflect, shape=shape)
    if attrs:
        p.attrs.update(attrs)
    if tags:
        p.tags.extend(tags)
    parent.add(p)
    return p


def box(parent: Inst, name: str, x0, x1, y0, y1, z0, z1, color, mat="SmoothPlastic", **kw) -> Inst:
    return part(parent, name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), color,
                mat, **kw)


def attachment(parent: Inst, name: str, pos=(0.0, 0.0, 0.0), attrs: dict | None = None) -> Inst:
    a = Inst("Attachment", name)
    a.props["pos"] = tuple(pos)
    if attrs:
        a.attrs.update(attrs)
    parent.add(a)
    return a


def light(parent: Inst, kind: str, color, brightness: float, rng: float, *, face: str | None = None, angle: float | None = None,
          shadows: bool = False, name: str | None = None) -> Inst:
    li = Inst(kind, name or kind)
    li.props.update(color=tuple(color), brightness=brightness, range=rng, shadows=shadows)
    if face is not None:
        li.props["face"] = face
    if angle is not None:
        li.props["angle"] = angle
    parent.add(li)
    return li


def generic(parent: Inst, cls: str, name: str, **props) -> Inst:
    g = Inst(cls, name)
    g.props["generic"] = props
    parent.add(g)
    return g


# ---------------------------------------------------------------- escritor XML
class _Writer:
    def __init__(self):
        self.ref = 0
        self.prims: list[tuple[ET.Element, str]] = []

    def item(self, parent_el, inst: Inst):
        el = ET.SubElement(parent_el, "Item", {"class": inst.cls, "referent": f"RBX{self.ref}"})
        self.ref += 1
        props = ET.SubElement(el, "Properties")
        _s(props, "string", "Name", inst.name)
        p = inst.props
        if inst.cls in ("Part", "WedgePart", "CornerWedgePart"):
            _cf(props, "CFrame", p["pos"], p["rot"])
            _s(props, "bool", "Anchored", "true")
            _s(props, "bool", "CanCollide", _b(p["collide"]))
            _s(props, "bool", "CanQuery", _b(p["query"]))
            _s(props, "bool", "CanTouch", "false")
            _s(props, "bool", "CastShadow", _b(p["shadow"]))
            _s(props, "Color3uint8", "Color3uint8", str((int(p["color"][0]) << 16) | (int(p["color"][1]) << 8) | int(p["color"][2])))
            _s(props, "token", "Material", str(MAT[p["mat"]]))
            _v3(props, "size", p["size"])
            if p["transparency"]:
                _s(props, "float", "Transparency", f"{p['transparency']:.3g}")
            if p["reflect"]:
                _s(props, "float", "Reflectance", f"{p['reflect']:.3g}")
            for face in ("TopSurface", "BottomSurface"):
                _s(props, "token", face, "0")
            if p.get("shape") and inst.cls == "Part":
                _s(props, "token", "shape", str(SHAPE[p["shape"]]))
        elif inst.cls == "Attachment":
            _cf(props, "CFrame", p["pos"], IDENT)
        elif inst.cls in ("PointLight", "SpotLight", "SurfaceLight"):
            _s(props, "float", "Brightness", f"{p['brightness']:.3g}")
            _c3(props, "Color", p["color"])
            _s(props, "float", "Range", f"{p['range']:.3g}")
            _s(props, "bool", "Shadows", _b(p["shadows"]))
            if "face" in p:
                _s(props, "token", "Face", str(FACE[p["face"]]))
            if "angle" in p:
                _s(props, "float", "Angle", f"{p['angle']:.3g}")
        elif "generic" in p:
            for k, (typ, val) in p["generic"].items():
                if typ == "Color3":
                    _c3(props, k, val)
                elif typ == "string":
                    _s(props, "string", k, val)
                else:
                    _s(props, typ, k, str(val) if not isinstance(val, float) else f"{val:.4g}")
        if inst.attrs:
            _s(props, "BinaryString", "AttributesSerialize", encode_attributes(inst.attrs))
        if inst.tags:
            _s(props, "BinaryString", "Tags", base64.b64encode("\x00".join(inst.tags).encode()).decode())
        if inst.cls == "Model" and "primary" in p:
            self.prims.append((props, id(p["primary"])))
        inst.props["_ref"] = el.get("referent")
        for c in inst.children:
            self.item(el, c)
        return el


def _b(v: bool) -> str:
    return "true" if v else "false"


def _s(props, typ, name, text):
    e = ET.SubElement(props, typ, {"name": name})
    e.text = text


def _f(v: float) -> str:
    return f"{v:.9g}"  # Preserve 0.02-stud face separation, including large map coordinates.


def _cf(props, name, pos, rot):
    cf = ET.SubElement(props, "CoordinateFrame", {"name": name})
    for k, v in zip(("X", "Y", "Z"), pos):
        ET.SubElement(cf, k).text = _f(v)
    for i, v in enumerate(rot):
        ET.SubElement(cf, f"R{i // 3}{i % 3}").text = _f(v)


def _v3(props, name, v):
    e = ET.SubElement(props, "Vector3", {"name": name})
    for k, x in zip(("X", "Y", "Z"), v):
        ET.SubElement(e, k).text = _f(x)


def _c3(props, name, c):
    e = ET.SubElement(props, "Color3", {"name": name})
    for k, x in zip(("R", "G", "B"), c):
        ET.SubElement(e, k).text = f"{x / 255:.4f}"


def write_rbxmx(root: Inst, path: str, primary: Inst | None = None):
    doc = ET.Element("roblox", {"version": "4"})
    w = _Writer()
    el = w.item(doc, root)
    if primary is not None:
        ref = ET.SubElement(el.find("Properties"), "Ref", {"name": "PrimaryPart"})
        ref.text = primary.props["_ref"]
    with open(path, "w", encoding="utf-8") as f:
        f.write(ET.tostring(doc, encoding="unicode"))


def ellipsoid(parent: Inst, name: str, pos, size, color, mat: str = "SmoothPlastic", **kw) -> Inst:
    """Pieza con SpecialMesh esférica: elipsoide del tamaño de la pieza (arbustos, copas, siluetas 2.5D). Sin colisión."""
    kw.setdefault("collide", False)
    kw.setdefault("query", False)
    p = part(parent, name, pos, size, color, mat, **kw)
    generic(p, "SpecialMesh", "Mesh", MeshType=("token", 3))
    return p


def cylinder_y(parent: Inst, name: str, pos, height: float, diameter: float, color, mat: str = "SmoothPlastic", **kw) -> Inst:
    """Cilindro vertical (el eje del Cylinder de Roblox es X: se gira 90° en Z)."""
    return part(parent, name, pos, (height, diameter, diameter), color, mat, rot=rot_z(90), shape="Cylinder", **kw)
