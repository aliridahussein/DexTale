"""Builds Godot resources from the generated art:
tileset, sprite frames, prop scenes, player/NPC scenes, theme, font import."""
from __future__ import annotations

import json
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, Resource, Raw, V2, V2i, Col, R2, PV2, SN, ROOT, fmt  # noqa: E402

BUILD = os.path.join(ROOT, "tools", "build")


def load_json(name):
    with open(os.path.join(BUILD, name)) as f:
        return json.load(f)


def pascal(s: str) -> str:
    return "".join(p.capitalize() for p in s.split("_"))


# ----------------------------------------------------------------- tileset --
SURFACES = [("grass", "grass"), ("flowers", "grass"), ("cobble", "stone"), ("dirt", "dirt"), ("forest", "dirt"),
            ("flag", "stone"), ("forgefloor", "stone"), ("plank", "wood"), ("carpet", "cloth"), ("steps", "stone")]


def build_tileset():
    man = load_json("tiles_manifest.json")
    res = Resource("TileSet")
    tex = res.ext("Texture2D", "res://assets/tilesets/world_tiles.png")
    props = {"texture": tex}
    for name, t in man["tiles"].items():
        ax, ay = t["atlas"]
        key = f"{ax}:{ay}/0"
        props[key] = 0
        for prefix, surf in SURFACES:
            if name.startswith(prefix):
                props[f"{key}/custom_data_0"] = surf
                break
        if t["solid"]:
            props[f"{key}/physics_layer_0/polygon_0/points"] = PV2([(-8, -8), (8, -8), (8, 8), (-8, 8)])
    src = res.sub("TileSetAtlasSource", props)
    res.props = {
        "physics_layer_0/collision_layer": 1,
        "physics_layer_0/collision_mask": 0,
        "custom_data_layer_0/name": "surface",
        "custom_data_layer_0/type": 4,
        "sources/0": src,
    }
    res.save("assets/tilesets/world_tileset.tres")


# ------------------------------------------------------------ sprite frames --
ANIMS = ["idle_down", "idle_up", "idle_left", "idle_right", "walk_down", "walk_up", "walk_left", "walk_right"]


def sprite_frames(cid: str, sheet: str, frame: tuple, rows: dict, speeds: dict):
    """rows: anim name -> (row index, frame count) ; speeds: anim -> fps"""
    res = Resource("SpriteFrames")
    tex = res.ext("Texture2D", sheet)
    anims = []
    fw, fh = frame
    for anim, (row, count, col0) in rows.items():
        frames = []
        for i in range(count):
            at = res.sub("AtlasTexture", {"atlas": tex, "region": R2((col0 + i) * fw, row * fh, fw, fh)})
            frames.append({"duration": 1.0, "texture": at})
        anims.append({"frames": frames, "loop": True, "name": SN(anim), "speed": float(speeds.get(anim, 6.0))})
    res.props = {"animations": anims}
    res.save(f"assets/sprites/characters/{cid}.tres")


def build_sprite_frames():
    meta = load_json("characters_manifest.json")
    for cid in ("rowan", "pip", "mara", "alden", "orin", "tobin"):
        rows = {a: (i, meta[cid]["anims"][a], 0) for i, a in enumerate(ANIMS)}
        speeds = {a: (1.6 if a.startswith("idle") else 7.0) for a in ANIMS}
        sprite_frames(cid, f"res://assets/sprites/characters/{cid}.png", (16, 24), rows, speeds)
    sprite_frames("sentinel", "res://assets/sprites/characters/sentinel.png", (24, 32),
                  {"idle_down": (0, 2, 0)}, {"idle_down": 1.2})
    # the cat only has side views; reuse them for every direction
    cat_rows = {
        "idle_right": (0, 1, 2), "idle_left": (1, 1, 2), "idle_down": (0, 1, 2), "idle_up": (1, 1, 2),
        "walk_right": (0, 2, 0), "walk_left": (1, 2, 0), "walk_down": (0, 2, 0), "walk_up": (1, 2, 0),
    }
    sprite_frames("cat", "res://assets/sprites/characters/cat.png", (16, 16), cat_rows,
                  {a: (1.0 if a.startswith("idle") else 6.0) for a in ANIMS})


# ------------------------------------------------------------------- props --
def build_props():
    man = load_json("props_manifest.json")
    for name, p in man.items():
        root_type = "StaticBody2D" if p["collide"] else "Node2D"
        props = {"collision_layer": 1, "collision_mask": 0} if p["collide"] else {}
        sc = Scene(pascal(name), root_type, props)
        tex = sc.ext("Texture2D", p["png"])
        sp = {"texture": tex, "centered": False, "offset": V2(-p["origin"][0], -p["origin"][1])}
        if p["frames"] > 1:
            sp["hframes"] = p["frames"]
        if p["frames"] > 1 and p["fps"] > 0:
            sp["script"] = sc.ext("Script", "res://scripts/world/prop_anim.gd")
            sp["fps"] = float(p["fps"])
        sc.add("Sprite", "Sprite2D", props=sp)
        if p["collide"]:
            x, y, w, h = p["collide"]
            shape = sc.sub("RectangleShape2D", {"size": V2(w, h)})
            sc.add("Shape", "CollisionShape2D", props={"position": V2(x + w / 2, y + h / 2), "shape": shape})
        if p["light"]:
            L = p["light"]
            c = L["color"]
            sc.add("Light", "PointLight2D", props={
                "position": V2(*L.get("offset", [0, 0])),
                "color": Col(c[0], c[1], c[2], 1.0),
                "energy": float(L["energy"]),
                "texture": sc.ext("Texture2D", "res://assets/sprites/fx/light_radial.png"),
                "texture_scale": float(L["scale"]),
                "script": sc.ext("Script", "res://scripts/world/flicker_light.gd"),
            })
        sc.save(f"scenes/props/{name}.tscn")


# --------------------------------------------------------------- characters --
def shadow_png():
    im = Image.new("RGBA", (14, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, 13, 5), fill=(6, 4, 12, 95))
    d.ellipse((3, 1, 10, 4), fill=(6, 4, 12, 130))
    im.save(os.path.join(ROOT, "assets/sprites/fx/shadow.png"))
    g = Image.new("RGBA", (5, 9), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.rectangle((0, 0, 4, 8), fill=(27, 20, 32, 255))
    gd.rectangle((1, 1, 3, 7), fill=(232, 200, 110, 255))
    gd.line((1, 1, 3, 1), fill=(248, 232, 170, 255))
    g.save(os.path.join(ROOT, "assets/sprites/ui/slider_grabber.png"))


def build_player():
    sc = Scene("Player", "CharacterBody2D", {
        "collision_layer": 2, "collision_mask": 5, "motion_mode": 1,
    })
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/player/player.gd")
    sc.add("Shadow", "Sprite2D", props={"texture": sc.ext("Texture2D", "res://assets/sprites/fx/shadow.png"),
                                         "position": V2(0, -1)})
    sc.add("Sprite", "AnimatedSprite2D", props={
        "sprite_frames": sc.ext("SpriteFrames", "res://assets/sprites/characters/rowan.tres"),
        "animation": SN("idle_down"), "offset": V2(0, -12)})
    sc.add("Collision", "CollisionShape2D", props={"position": V2(0, -3),
                                                   "shape": sc.sub("RectangleShape2D", {"size": V2(10, 6)})})
    sc.add("InteractionSensor", "Area2D", props={"collision_layer": 0, "collision_mask": 8, "monitorable": False})
    sc.add("Shape", "CollisionShape2D", parent="InteractionSensor",
           props={"position": V2(0, -6), "shape": sc.sub("CircleShape2D", {"radius": 20.0})})
    sc.add("EchoSensor", "Area2D", props={"collision_layer": 0, "collision_mask": 16, "monitorable": False})
    sc.add("Shape", "CollisionShape2D", parent="EchoSensor",
           props={"position": V2(0, -6), "shape": sc.sub("CircleShape2D", {"radius": 46.0})})
    sc.add("Echo", "Node2D", props={"position": V2(0, -10),
                                    "script": sc.ext("Script", "res://scripts/player/player_echo.gd")})
    grad = sc.sub("Gradient", {"offsets": Raw("PackedFloat32Array(0, 0.3, 1)"),
                               "colors": Raw("PackedColorArray(0.75, 0.85, 1, 0, 0.75, 0.85, 1, 1, 0.6, 0.55, 1, 0)")})
    add_mat = sc.sub("CanvasItemMaterial", {"blend_mode": 1})
    sc.add("Motes", "CPUParticles2D", parent="Echo", props={
        "material": add_mat, "emitting": False, "amount": 26, "lifetime": 1.6, "one_shot": True,
        "explosiveness": 0.55, "texture": sc.ext("Texture2D", "res://assets/sprites/fx/mote.png"),
        "emission_shape": 1, "emission_sphere_radius": 16.0, "direction": V2(0, -1), "spread": 180.0,
        "gravity": V2(0, -10), "initial_velocity_min": 4.0, "initial_velocity_max": 16.0,
        "color_ramp": grad})
    sc.add("Ripple", "Sprite2D", parent="Echo", props={
        "material": add_mat, "visible": False,
        "texture": sc.ext("Texture2D", "res://assets/sprites/fx/ring.png")})
    sc.add("Camera", "Camera2D", props={"position": V2(0, -12),
                                        "script": sc.ext("Script", "res://scripts/player/game_camera.gd")})
    sc.save("scenes/characters/player.tscn")


def build_npc():
    sc = Scene("NPC", "CharacterBody2D", {"collision_layer": 4, "collision_mask": 1, "motion_mode": 1})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/npc/npc.gd")
    sc.add("Shadow", "Sprite2D", props={"texture": sc.ext("Texture2D", "res://assets/sprites/fx/shadow.png"),
                                         "position": V2(0, -1)})
    sc.add("Sprite", "AnimatedSprite2D", props={"offset": V2(0, -12)})
    sc.add("Collision", "CollisionShape2D", props={"position": V2(0, -3),
                                                   "shape": sc.sub("RectangleShape2D", {"size": V2(10, 6)})})
    sc.add("Talk", "Area2D", props={"script": sc.ext("Script", "res://scripts/interactables/interactable.gd"),
                                    "prompt": "Talk", "prompt_offset": V2(0, -30)})
    sc.add("Shape", "CollisionShape2D", parent="Talk",
           props={"position": V2(0, -8), "shape": sc.sub("CircleShape2D", {"radius": 12.0})})
    sc.save("scenes/characters/npc.tscn")


def build_generic_nodes():
    """Small reusable scenes for the editor: interactable, echo point, area exit."""
    for name, script, layer in (("interactable", "res://scripts/interactables/interactable.gd", None),
                                ("echo_point", "res://scripts/interactables/echo_point.gd", None),
                                ("area_exit", "res://scripts/interactables/area_exit.gd", None),
                                ("story_trigger", "res://scripts/interactables/story_trigger.gd", None)):
        sc = Scene(pascal(name), "Area2D")
        sc.nodes[0][3]["script"] = sc.ext("Script", script)
        shape = sc.sub("RectangleShape2D", {"size": V2(16, 16)}) if "exit" in name or "trigger" in name \
            else sc.sub("CircleShape2D", {"radius": 12.0})
        sc.add("Shape", "CollisionShape2D", props={"shape": shape})
        sc.save(f"scenes/interactables/{name}.tscn")


# -------------------------------------------------------------------- theme --
def build_theme():
    res = Resource("Theme")
    font = res.ext("FontFile", "res://assets/fonts/dawnmere.fnt")
    panel_tex = res.ext("Texture2D", "res://assets/sprites/ui/panel_dark.png")
    grab = res.ext("Texture2D", "res://assets/sprites/ui/slider_grabber.png")
    margins = {f"texture_margin_{s}": 8.0 for s in ("left", "top", "right", "bottom")}
    cm = lambda l, t, r, b: {"content_margin_left": float(l), "content_margin_top": float(t),
                             "content_margin_right": float(r), "content_margin_bottom": float(b)}
    panel = res.sub("StyleBoxTexture", {"texture": panel_tex, **margins, **cm(10, 8, 10, 8)})
    empty = res.sub("StyleBoxEmpty", {})
    btn_normal = res.sub("StyleBoxFlat", {"bg_color": Col(0, 0, 0, 0), **cm(6, 2, 6, 3)})
    btn_hover = res.sub("StyleBoxFlat", {"bg_color": Col(0.35, 0.24, 0.1, 0.45), **cm(6, 2, 6, 3),
                                         "anti_aliasing": False})
    btn_focus = res.sub("StyleBoxFlat", {"draw_center": False, "border_width_left": 1, "border_width_top": 1,
                                         "border_width_right": 1, "border_width_bottom": 1,
                                         "border_color": Col("#c49a3e"), **cm(6, 2, 6, 3), "anti_aliasing": False})
    btn_pressed = res.sub("StyleBoxFlat", {"bg_color": Col(0.55, 0.38, 0.12, 0.6), **cm(6, 2, 6, 3),
                                           "anti_aliasing": False})
    slider = res.sub("StyleBoxFlat", {"bg_color": Col("#1a1422"), "border_width_left": 1, "border_width_top": 1,
                                      "border_width_right": 1, "border_width_bottom": 1,
                                      "border_color": Col("#5a3e16"), **cm(0, 2, 0, 2), "anti_aliasing": False})
    slider_fill = res.sub("StyleBoxFlat", {"bg_color": Col("#8c6826"), **cm(0, 2, 0, 2), "anti_aliasing": False})
    scroll = res.sub("StyleBoxFlat", {"bg_color": Col(0, 0, 0, 0.15), **cm(1, 0, 1, 0)})
    grabber = res.sub("StyleBoxFlat", {"bg_color": Col("#8c6826"), **cm(1, 0, 1, 0)})
    text = Col("#ebdec7")
    shadow = Col(0.02, 0.01, 0.04, 0.85)
    res.props = {
        "default_font": font,
        "default_font_size": 9,
        "Button/colors/font_color": Col("#cfc2ad"),
        "Button/colors/font_hover_color": Col("#f8e8aa"),
        "Button/colors/font_focus_color": Col("#f8e8aa"),
        "Button/colors/font_pressed_color": Col("#fff2c8"),
        "Button/colors/font_hover_pressed_color": Col("#fff2c8"),
        "Button/colors/font_disabled_color": Col("#5e5668"),
        "Button/colors/font_outline_color": Col(0, 0, 0, 0),
        "Button/styles/normal": btn_normal,
        "Button/styles/hover": btn_hover,
        "Button/styles/pressed": btn_pressed,
        "Button/styles/hover_pressed": btn_pressed,
        "Button/styles/focus": btn_focus,
        "Button/styles/disabled": btn_normal,
        "Label/colors/font_color": text,
        "Label/colors/font_shadow_color": shadow,
        "Label/constants/shadow_offset_x": 1,
        "Label/constants/shadow_offset_y": 1,
        "Label/constants/line_spacing": 2,
        "RichTextLabel/colors/default_color": text,
        "RichTextLabel/colors/font_shadow_color": shadow,
        "RichTextLabel/constants/shadow_offset_x": 1,
        "RichTextLabel/constants/shadow_offset_y": 1,
        "RichTextLabel/constants/line_separation": 2,
        "RichTextLabel/styles/normal": empty,
        "RichTextLabel/styles/focus": empty,
        "PanelContainer/styles/panel": panel,
        "Panel/styles/panel": panel,
        "HSlider/styles/slider": slider,
        "HSlider/styles/grabber_area": slider_fill,
        "HSlider/styles/grabber_area_highlight": slider_fill,
        "HSlider/styles/focus": btn_focus,
        "HSlider/icons/grabber": grab,
        "HSlider/icons/grabber_highlight": grab,
        "HSlider/icons/grabber_disabled": grab,
        "VScrollBar/styles/scroll": scroll,
        "VScrollBar/styles/grabber": grabber,
        "VScrollBar/styles/grabber_highlight": grabber,
        "VScrollBar/styles/grabber_pressed": grabber,
    }
    res.save("assets/ui/theme.tres")


def write_import_overrides():
    """Integer-only scaling keeps the bitmap font crisp at 9 / 18 / 27 px."""
    path = os.path.join(ROOT, "assets/fonts/dawnmere.fnt.import")
    if os.path.exists(path):
        txt = open(path, encoding="utf-8").read()
        if "scaling_mode=1" in txt:
            return
        import re
        txt = re.sub(r"scaling_mode=\d", "scaling_mode=1", txt)
        open(path, "w", newline="\n", encoding="utf-8").write(txt)
        return
    open(path, "w", newline="\n", encoding="utf-8").write(
        '[remap]\n\nimporter="font_data_bmfont"\ntype="FontFile"\n\n[deps]\n\n'
        'source_file="res://assets/fonts/dawnmere.fnt"\n\n[params]\n\nfallbacks=[]\ncompress=true\nscaling_mode=1\n')


def build_all():
    shadow_png()
    build_tileset()
    build_sprite_frames()
    build_props()
    build_player()
    build_npc()
    build_generic_nodes()
    build_theme()
    write_import_overrides()


if __name__ == "__main__":
    build_all()
    print("resources ok")
