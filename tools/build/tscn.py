"""Minimal writer for Godot 4 text scenes (.tscn) and resources (.tres)."""
from __future__ import annotations

import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


class Raw(str):
    """Emitted verbatim (Vector2(...), ExtResource(...), etc.)."""


def num(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    f = float(v)
    if f == int(f) and abs(f) < 1e9:
        return str(int(f)) if not isinstance(v, float) else f"{int(f)}.0" if False else str(int(f))
    s = f"{f:.5f}".rstrip("0").rstrip(".")
    return s


def fnum(v) -> str:
    """Float formatting that always keeps a decimal point."""
    f = float(v)
    s = f"{f:.5f}".rstrip("0")
    if s.endswith("."):
        s += "0"
    return s


def fmt(v) -> str:
    if isinstance(v, Raw):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return fnum(v)
    if isinstance(v, str):
        esc = v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{esc}"'
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(fmt(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{\n" + ",\n".join(f"{fmt(k)}: {fmt(x)}" for k, x in v.items()) + "\n}"
    if v is None:
        return "null"
    raise TypeError(type(v))


def V2(x, y) -> Raw:
    return Raw(f"Vector2({num(x)}, {num(y)})")


def V2i(x, y) -> Raw:
    return Raw(f"Vector2i({int(x)}, {int(y)})")


def Col(r, g=None, b=None, a=1.0) -> Raw:
    if isinstance(r, str):
        h = r.lstrip("#")
        r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
        if len(h) == 8:
            a = int(h[6:8], 16) / 255
    return Raw(f"Color({fnum(r)}, {fnum(g)}, {fnum(b)}, {fnum(a)})")


def R2(x, y, w, h) -> Raw:
    return Raw(f"Rect2({num(x)}, {num(y)}, {num(w)}, {num(h)})")


def PV2(points) -> Raw:
    return Raw("PackedVector2Array(" + ", ".join(f"{num(x)}, {num(y)}" for x, y in points) + ")")


def SN(s: str) -> Raw:
    return Raw(f'&"{s}"')


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")[:24] or "res"


class _Base:
    def __init__(self):
        self._ext: list[tuple[str, str, str]] = []
        self._ext_by_path: dict[str, str] = {}
        self._sub: list[tuple[str, str, dict]] = []
        self._n = 0

    def ext(self, type_: str, path: str) -> Raw:
        if path in self._ext_by_path:
            return Raw(f'ExtResource("{self._ext_by_path[path]}")')
        self._n += 1
        rid = f"{self._n}_{slug(os.path.basename(path))}"
        self._ext.append((type_, path, rid))
        self._ext_by_path[path] = rid
        return Raw(f'ExtResource("{rid}")')

    def sub(self, type_: str, props: dict | None = None) -> Raw:
        self._n += 1
        rid = f"{type_}_{self._n}"
        self._sub.append((type_, rid, props or {}))
        return Raw(f'SubResource("{rid}")')

    def _header_body(self) -> list[str]:
        out = []
        for type_, path, rid in self._ext:
            out.append(f'[ext_resource type="{type_}" path="{path}" id="{rid}"]')
        if self._ext:
            out.append("")
        for type_, rid, props in self._sub:
            out.append(f'[sub_resource type="{type_}" id="{rid}"]')
            for k, v in props.items():
                out.append(f"{k} = {fmt(v)}")
            out.append("")
        return out

    @staticmethod
    def write(rel: str, text: str):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", newline="\n", encoding="utf-8") as f:
            f.write(text)


class Scene(_Base):
    def __init__(self, root_name: str, root_type: str | None = None, props: dict | None = None,
                 instance: Raw | None = None, groups=None):
        super().__init__()
        self.nodes: list[tuple] = []
        self.root = root_name
        self._names: dict[str, set] = {}
        self.nodes.append((root_name, root_type, None, props or {}, instance, groups))

    def add(self, name: str, type_: str | None = None, parent: str = ".", props: dict | None = None,
            instance: Raw | None = None, groups=None, unique_name: bool = False) -> str:
        siblings = self._names.setdefault(parent, set())
        base = name
        i = 2
        while name in siblings:
            name = f"{base}{i}"
            i += 1
        siblings.add(name)
        p = dict(props or {})
        if unique_name:
            p = {"unique_name_in_owner": True, **p}
        self.nodes.append((name, type_, parent, p, instance, groups))
        return name if parent == "." else f"{parent}/{name}"

    def text(self) -> str:
        out = ["[gd_scene format=3]", ""]
        out += self._header_body()
        for (name, type_, parent, props, instance, groups) in self.nodes:
            head = f'[node name="{name}"'
            if type_:
                head += f' type="{type_}"'
            if parent is not None:
                head += f' parent="{parent}"'
            if instance is not None:
                head += f" instance={instance}"
            if groups:
                head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
            head += "]"
            out.append(head)
            for k, v in props.items():
                out.append(f"{k} = {fmt(v)}")
            out.append("")
        return "\n".join(out)

    def save(self, rel: str):
        self.write(rel, self.text())


class Resource(_Base):
    def __init__(self, type_: str, props: dict | None = None):
        super().__init__()
        self.type = type_
        self.props = props or {}

    def text(self) -> str:
        out = [f'[gd_resource type="{self.type}" format=3]', ""]
        out += self._header_body()
        out.append("[resource]")
        for k, v in self.props.items():
            out.append(f"{k} = {fmt(v)}")
        out.append("")
        return "\n".join(out)

    def save(self, rel: str):
        self.write(rel, self.text())
