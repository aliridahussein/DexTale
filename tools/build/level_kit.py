"""Level description kit: paint tile families, place nodes, emit a .tscn.

Coordinates: tiles for painting, pixels for node positions.
"""
from __future__ import annotations

import json
import math
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, Raw, V2, Col, R2, PV2, SN, ROOT  # noqa: E402

T = 16
N, E, S, W = 1, 2, 4, 8

with open(os.path.join(ROOT, "tools", "build", "tiles_manifest.json")) as _f:
    TILES = json.load(_f)["tiles"]
with open(os.path.join(ROOT, "tools", "build", "props_manifest.json")) as _f:
    PROPS = json.load(_f)

FAMILIES = {
    "grass": (["grass_0", "grass_1", "grass_2", "grass_3"], ["grass_flowers_0", "grass_flowers_1"], 0.08),
    "grass_dark": (["grass_dark_0", "grass_dark_1", "grass_dark_2"], [], 0.0),
    "cobble": (["cobble_0", "cobble_1", "cobble_2", "cobble_3"], ["cobble_moss_0", "cobble_moss_1"], 0.06),
    "cobble_dark": (["cobble_dark_0", "cobble_dark_1"], ["cobble_moss_0"], 0.1),
    "dirt": (["dirt_0", "dirt_1", "dirt_2"], [], 0.0),
    "forest": (["forest_0", "forest_1", "forest_2"], [], 0.0),
    "flag": (["flag_0", "flag_1", "flag_2"], ["flag_crack"], 0.06),
    "forgefloor": (["forgefloor_0", "forgefloor_1", "forgefloor_2"], [], 0.0),
    "plank": (["plank_0", "plank_1", "plank_2"], [], 0.0),
    "steps": (["steps_0", "steps_1"], [], 0.0),
    # V2.2: the ravine at the Watchman's Crossing (not solid; the scene adds collision)
    "chasm_face": (["chasm_face_0", "chasm_face_1"], [], 0.0),
    "chasm": (["chasm_0", "chasm_1", "chasm_2"], [], 0.0),
    "chasm_lip": (["chasm_lip_0", "chasm_lip_1"], [], 0.0),
}
PATHLIKE = ("cobble", "cobble_dark", "dirt", "steps")


def pascal(s: str) -> str:
    return "".join(p.capitalize() for p in s.split("_"))


class Level:
    def __init__(self, name: str, area_id: str, w: int, h: int, script: str, seed: int = 1, **exports):
        self.name, self.area_id, self.w, self.h = name, area_id, w, h
        self.script = script
        self.exports = exports
        self.rng = random.Random(seed)
        self.ground = [[None] * w for _ in range(h)]
        self.overlay = [[None] * w for _ in range(h)]
        self.nodes: list[dict] = []      # generic node specs (group, kind, ...)
        self.ambient = Col(1, 1, 1, 1)
        self.mist = None

    # ------------------------------------------------------------- paint --
    def fill(self, fam, layer="ground"):
        self.rect(0, 0, self.w - 1, self.h - 1, fam, layer)

    def rect(self, x0, y0, x1, y1, fam, layer="ground"):
        grid = self.ground if layer == "ground" else self.overlay
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                grid[y][x] = fam

    def ellipse(self, cx, cy, rx, ry, fam, layer="ground"):
        grid = self.ground if layer == "ground" else self.overlay
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    grid[y][x] = fam

    def path(self, pts, width, fam, layer="ground"):
        grid = self.ground if layer == "ground" else self.overlay
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            steps = int(max(abs(bx - ax), abs(by - ay)) * 4) + 1
            for i in range(steps + 1):
                t = i / steps
                cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
                r = width / 2
                for y in range(int(cy - r - 1), int(cy + r + 2)):
                    for x in range(int(cx - r - 1), int(cx + r + 2)):
                        if 0 <= x < self.w and 0 <= y < self.h and (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                            grid[y][x] = fam

    def get(self, x, y, layer="ground"):
        grid = self.ground if layer == "ground" else self.overlay
        if 0 <= x < self.w and 0 <= y < self.h:
            return grid[y][x]
        return "__oob__"

    # -------------------------------------------------------------- nodes --
    def prop(self, kind, x, y, name=None, **props):
        assert kind in PROPS, kind
        self.nodes.append({"group": "Objects", "kind": "prop", "prop": kind, "pos": (x, y), "name": name or pascal(kind),
                           "props": props})

    def decal(self, kind, x, y, name=None, z=-1):
        self.nodes.append({"group": "Decals", "kind": "prop", "prop": kind, "pos": (x, y), "name": name or pascal(kind),
                           "props": {"z_index": z} if z else {}})

    def backdrop(self, texture, x, y, name="Backdrop"):
        self.nodes.append({"group": "Backdrop", "kind": "sprite", "texture": texture, "pos": (x, y), "name": name})

    def sprite(self, group, name, texture, x, y, offset=(0, 0), **props):
        self.nodes.append({"group": group, "kind": "sprite", "texture": texture, "pos": (x, y), "name": name,
                           "offset": offset, "props": props})

    def player(self, x, y):
        self.nodes.append({"group": "Objects", "kind": "player", "pos": (x, y), "name": "Player"})

    def npc(self, name, x, y, frames, conversation, facing="down", **props):
        self.nodes.append({"group": "Objects", "kind": "npc", "pos": (x, y), "name": name, "frames": frames,
                           "props": {"npc_id": name.lower(), "conversation": conversation, "facing_name": facing, **props}})

    def interact(self, name, x, y, conversation="", prompt="Inspect", r=12, size=None, **props):
        self.nodes.append({"group": "Interactions", "kind": "area", "script": "interactables/interactable.gd",
                           "pos": (x, y), "name": name, "r": r, "size": size,
                           "props": {"prompt": prompt, "conversation_id": conversation, **props}})

    def echo(self, name, x, y, echo_id, conversation="", texture=None, atlas=None, r=14, **props):
        p = {"echo_id": echo_id, "conversation_id": conversation, **props}
        self.nodes.append({"group": "Interactions", "kind": "area", "script": "interactables/echo_point.gd",
                           "pos": (x, y), "name": name, "r": r, "size": None, "props": p,
                           "texture": texture, "atlas": atlas})

    def item_target(self, name, x, y, conversation="", accepts="", prompt="Inspect", r=12, **props):
        """V2.2: something an inventory item can be used on (scripts/interactables/item_target.gd)."""
        self.nodes.append({"group": "Interactions", "kind": "area", "script": "interactables/item_target.gd",
                           "pos": (x, y), "name": name, "r": r, "size": None,
                           "props": {"prompt": prompt, "conversation_id": conversation, "accepts": accepts, **props}})

    def pickup(self, name, x, y, item_id, sprite_path="", r=10, **props):
        """V2.2: an item Rowan can take (scripts/interactables/item_pickup.gd)."""
        p = {"item_id": item_id, **props}
        if sprite_path:
            p["sprite_path"] = Raw(f'NodePath("{sprite_path}")')
        self.nodes.append({"group": "Interactions", "kind": "area", "script": "interactables/item_pickup.gd",
                           "pos": (x, y), "name": name, "r": r, "size": None, "props": p})

    def exit(self, name, x, y, w, h, target, spawn, **props):
        self.nodes.append({"group": "Triggers", "kind": "area", "script": "interactables/area_exit.gd",
                           "pos": (x, y), "name": name, "r": None, "size": (w, h),
                           "props": {"target_area": target, "target_spawn": spawn, **props}})

    def trigger(self, name, x, y, w, h, **props):
        self.nodes.append({"group": "Triggers", "kind": "area", "script": "interactables/story_trigger.gd",
                           "pos": (x, y), "name": name, "r": None, "size": (w, h), "props": props})

    def spawn(self, name, x, y, facing="down"):
        self.nodes.append({"group": "Spawns", "kind": "marker", "pos": (x, y), "name": name, "facing": facing})

    def light(self, name, x, y, color, energy=0.8, scale=0.8, flicker=True, group="Lights"):
        self.nodes.append({"group": group, "kind": "light", "pos": (x, y), "name": name, "color": color,
                           "energy": energy, "scale": scale, "flicker": flicker})

    def shaft(self, name, x, y, rot_deg, sx, sy, color, alpha=0.16, group="Effects"):
        self.nodes.append({"group": group, "kind": "shaft", "pos": (x, y), "name": name, "rot": rot_deg,
                           "scale": (sx, sy), "color": color, "alpha": alpha})

    def particles(self, name, x, y, **cfg):
        self.nodes.append({"group": cfg.pop("group", "Effects"), "kind": "particles", "pos": (x, y), "name": name,
                           "cfg": cfg})

    def node(self, group, name, type_, x=0, y=0, **props):
        self.nodes.append({"group": group, "kind": "raw", "type": type_, "pos": (x, y), "name": name, "props": props})

    # ------------------------------------------------------------ resolve --
    def _resolve_tile(self, x, y, fam):
        if fam is None:
            return None
        if fam in FAMILIES:
            base, rare, p = FAMILIES[fam]
            if rare and self.rng.random() < p:
                return self.rng.choice(rare)
            return self.rng.choice(base)
        if fam.startswith("cap:"):
            style = fam[4:]
            m = 0
            for bit, (dx, dy) in ((N, (0, -1)), (E, (1, 0)), (S, (0, 1)), (W, (-1, 0))):
                g = self.get(x + dx, y + dy)
                if g != "__oob__" and g != fam:
                    m |= bit
            return f"cap_{style}_{m}"
        if fam.startswith("face:"):
            _, style, part = fam.split(":")
            return f"face_{style}_{part}_{self.rng.randint(0, 1)}"
        if fam == "canopy":
            m = 0
            for bit, (dx, dy) in ((N, (0, -1)), (E, (1, 0)), (S, (0, 1)), (W, (-1, 0))):
                g = self.get(x + dx, y + dy, "overlay")
                if g != "__oob__" and g != "canopy":
                    m |= bit
            if m in (0, 4):
                return self.rng.choice([f"canopy_{m}", f"canopy_{m}b", f"canopy_{m}c"])
            return f"canopy_{m}"
        return fam  # a literal tile name

    def _fringe(self, x, y):
        g = self.ground[y][x]
        if g not in PATHLIKE or self.overlay[y][x] is not None:
            return None
        m = 0
        dark = False
        for bit, (dx, dy) in ((N, (0, -1)), (E, (1, 0)), (S, (0, 1)), (W, (-1, 0))):
            nb = self.get(x + dx, y + dy)
            if nb in ("grass", "grass_dark", "forest"):
                m |= bit
                dark = dark or nb != "grass"
        if m == 0:
            return None
        return f"fringe_dark_{m}" if dark else f"fringe_{m}"

    @staticmethod
    def _encode(cells):
        data = bytearray(struct.pack("<H", 0))
        for (x, y, name) in cells:
            ax, ay = TILES[name]["atlas"]
            data += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
        return Raw("PackedByteArray(" + ", ".join(str(b) for b in data) + ")")

    # --------------------------------------------------------------- emit --
    def build(self, rel_path: str):
        ground_cells, overlay_cells = [], []
        for y in range(self.h):
            for x in range(self.w):
                t = self._resolve_tile(x, y, self.ground[y][x])
                if t:
                    ground_cells.append((x, y, t))
        for y in range(self.h):
            for x in range(self.w):
                fam = self.overlay[y][x]
                t = self._resolve_tile(x, y, fam) if fam else self._fringe(x, y)
                if t:
                    overlay_cells.append((x, y, t))
        sc = Scene(self.name, "Node2D")
        root = sc.nodes[0][3]
        root["script"] = sc.ext("Script", self.script)
        root["area_id"] = self.area_id
        root["bounds"] = R2(0, 0, self.w * T, self.h * T)
        root.update(self.exports)
        tileset = sc.ext("TileSet", "res://assets/tilesets/world_tileset.tres")
        sc.add("Ambient", "CanvasModulate", props={"color": self.ambient})
        sc.add("Ground", "TileMapLayer", props={"tile_map_data": self._encode(ground_cells), "tile_set": tileset})
        sc.add("Backdrop", "Node2D")
        sc.add("Overlay", "TileMapLayer", props={"tile_map_data": self._encode(overlay_cells), "tile_set": tileset})
        sc.add("Decals", "Node2D")
        sc.add("Encounter", "Node2D")
        sc.add("Objects", "Node2D", props={"y_sort_enabled": True})
        sc.add("Interactions", "Node2D")
        sc.add("Triggers", "Node2D")
        sc.add("Spawns", "Node2D")
        sc.add("Lights", "Node2D")
        sc.add("Effects", "Node2D", props={"z_index": 6})
        light_tex = sc.ext("Texture2D", "res://assets/sprites/fx/light_radial.png")
        flicker = sc.ext("Script", "res://scripts/world/flicker_light.gd")
        add_mat = None
        for nd in self.nodes:
            g = nd["group"]
            x, y = nd["pos"]
            k = nd["kind"]
            if k == "prop":
                inst = sc.ext("PackedScene", f"res://scenes/props/{nd['prop']}.tscn")
                sc.add(nd["name"], None, parent=g, instance=inst, props={"position": V2(x, y), **nd.get("props", {})})
            elif k == "sprite":
                p = {"position": V2(x, y), "texture": sc.ext("Texture2D", nd["texture"]), "centered": False}
                off = nd.get("offset", (0, 0))
                p["offset"] = V2(*off)
                p.update(nd.get("props", {}))
                sc.add(nd["name"], "Sprite2D", parent=g, props=p)
            elif k == "player":
                sc.add("Player", None, parent=g, instance=sc.ext("PackedScene", "res://scenes/characters/player.tscn"),
                       props={"position": V2(x, y)})
            elif k == "npc":
                p = {"position": V2(x, y),
                     "sprite_frames": sc.ext("SpriteFrames", f"res://assets/sprites/characters/{nd['frames']}.tres")}
                p.update(nd["props"])
                sc.add(nd["name"], None, parent=g, instance=sc.ext("PackedScene", "res://scenes/characters/npc.tscn"),
                       props=p)
            elif k == "area":
                p = {"position": V2(x, y), "script": sc.ext("Script", "res://scripts/" + nd["script"])}
                if nd.get("texture"):
                    p["reveal_texture"] = sc.ext("Texture2D", nd["texture"])
                if nd.get("atlas"):
                    path, region = nd["atlas"]
                    p["reveal_texture"] = sc.sub("AtlasTexture", {"atlas": sc.ext("Texture2D", path), "region": R2(*region)})
                p.update(nd["props"])
                path_ = sc.add(nd["name"], "Area2D", parent=g, props=p)
                if nd.get("size"):
                    shape = sc.sub("RectangleShape2D", {"size": V2(*nd["size"])})
                else:
                    shape = sc.sub("CircleShape2D", {"radius": float(nd["r"])})
                sc.add("Shape", "CollisionShape2D", parent=path_, props={"shape": shape})
            elif k == "marker":
                sc.add(nd["name"], "Marker2D", parent=g, props={"position": V2(x, y), "metadata/facing": nd["facing"]})
            elif k == "light":
                c = nd["color"]
                p = {"position": V2(x, y), "color": Col(c) if isinstance(c, str) else Col(*c),
                     "energy": float(nd["energy"]), "texture": light_tex, "texture_scale": float(nd["scale"])}
                if nd["flicker"]:
                    p["script"] = flicker
                sc.add(nd["name"], "PointLight2D", parent=g, props=p)
            elif k == "shaft":
                c = nd["color"]
                sc.add(nd["name"], "Sprite2D", parent=g, props={
                    "position": V2(x, y), "rotation": math.radians(nd["rot"]), "scale": V2(*nd["scale"]),
                    "texture": sc.ext("Texture2D", "res://assets/sprites/fx/light_shaft.png"),
                    "offset": V2(0, 64), "modulate": Col(c) if isinstance(c, str) else Col(*c),
                    "script": sc.ext("Script", "res://scripts/world/light_shaft.gd"),
                    "base_alpha": float(nd["alpha"])})
            elif k == "particles":
                cfg = dict(nd["cfg"])
                p = {"position": V2(x, y)}
                tex = cfg.pop("texture", "mote")
                p["texture"] = sc.ext("Texture2D", f"res://assets/sprites/fx/{tex}.png")
                if cfg.pop("additive", True):
                    if add_mat is None:
                        add_mat = sc.sub("CanvasItemMaterial", {"blend_mode": 1})
                    p["material"] = add_mat
                ramp = cfg.pop("ramp", None)
                if ramp:
                    p["color_ramp"] = sc.sub("Gradient", {
                        "offsets": Raw("PackedFloat32Array(" + ", ".join(str(o) for o, _ in ramp) + ")"),
                        "colors": Raw("PackedColorArray(" + ", ".join(
                            ", ".join(str(round(v, 3)) for v in c) for _, c in ramp) + ")")})
                for kk, vv in cfg.items():
                    if isinstance(vv, tuple):
                        vv = V2(*vv)
                    p[kk] = vv
                sc.add(nd["name"], "CPUParticles2D", parent=g, props=p)
            elif k == "raw":
                p = {"position": V2(x, y), **nd["props"]}
                if "script_path" in p:
                    p["script"] = sc.ext("Script", p.pop("script_path"))
                sc.add(nd["name"], nd["type"], parent=g, props=p)
        if self.mist:
            m = self.mist
            mat = sc.sub("ShaderMaterial", {
                "shader": sc.ext("Shader", "res://assets/shaders/mist.gdshader"),
                "shader_parameter/noise_tex": sc.ext("Texture2D", "res://assets/sprites/fx/noise.png")})
            sc.add("Mist", "ColorRect", props={
                "z_index": 10, "offset_right": float(self.w * T), "offset_bottom": float(self.h * T),
                "mouse_filter": 2, "material": mat,
                "script": sc.ext("Script", "res://scripts/world/mist_layer.gd"),
                "density": float(m.get("density", 0.35)), "edge_only": bool(m.get("edge_only", False)),
                "tint": Col(m.get("tint", "#b8ccd8"))})
        # map boundary
        b = sc.add("Bounds", "StaticBody2D", props={"collision_layer": 1, "collision_mask": 0})
        W_, H_ = self.w * T, self.h * T
        for nm, (bx, by, bw, bh) in (("Left", (-16, -16, 16, H_ + 32)), ("Right", (W_, -16, 16, H_ + 32)),
                                     ("Top", (0, -16, W_, 16)), ("Bottom", (0, H_, W_, 16))):
            sc.add(nm, "CollisionShape2D", parent=b, props={"position": V2(bx + bw / 2, by + bh / 2),
                   "shape": sc.sub("RectangleShape2D", {"size": V2(bw, bh)})})
        sc.save(rel_path)
        return len(ground_cells), len(overlay_cells)

    def ascii_dump(self):
        ch = {None: " ", "grass": ".", "cobble": "#", "dirt": ":", "canopy": "T", "forest": ",", "flag": "_",
              "plank": "=", "forgefloor": "_", "void": "X"}
        lines = []
        for y in range(self.h):
            row = ""
            for x in range(self.w):
                o = self.overlay[y][x]
                g = self.ground[y][x]
                c = ch.get(o) if o else ch.get(g, (g or " ")[0] if g else " ")
                row += c if c else "?"
            lines.append(row)
        return "\n".join(lines)
