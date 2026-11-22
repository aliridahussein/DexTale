"""Builds the UI scenes (all layouts are absolute, in the 480x270 viewport)."""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, Raw, V2, Col, ROOT  # noqa: E402

FULL = {"anchors_preset": 15, "anchor_right": 1.0, "anchor_bottom": 1.0, "grow_horizontal": 2, "grow_vertical": 2}
INK = Col("#3a2a20")
INK_DIM = Col("#7a6650")
GOLD = Col("#e8c86e")
DIM = Col("#9a8eaa")
NO_SHADOW = {"theme_override_colors/font_shadow_color": Col(0, 0, 0, 0)}


def rect(x, y, w, h):
    return {"offset_left": float(x), "offset_top": float(y), "offset_right": float(x + w), "offset_bottom": float(y + h)}


def fill_parent(margin=0):
    return {"anchors_preset": 15, "anchor_right": 1.0, "anchor_bottom": 1.0,
            "offset_left": float(margin), "offset_top": float(margin),
            "offset_right": float(-margin), "offset_bottom": float(-margin)}


def ninepatch(sc, tex_path, m=8):
    p = {"texture": sc.ext("Texture2D", tex_path), "patch_margin_left": m, "patch_margin_top": m,
         "patch_margin_right": m, "patch_margin_bottom": m}
    if "parchment" in tex_path:
        p["axis_stretch_horizontal"] = 1  # tile the paper grain instead of stretching it
        p["axis_stretch_vertical"] = 1
    return p


def label(text="", size=None, color=None, align=None, extra=None):
    p = {"text": text}
    if size:
        p["theme_override_font_sizes/font_size"] = size
    if color is not None:
        p["theme_override_colors/font_color"] = color
    if align is not None:
        p["horizontal_alignment"] = align
    if extra:
        p.update(extra)
    return p


def dim(sc, parent=".", a=0.6):
    sc.add("Dim", "ColorRect", parent=parent, props={**FULL, "color": Col(0.02, 0.01, 0.04, a)})


def build_dialogue_box():
    sc = Scene("DialogueBox", "Control", {**FULL, "mouse_filter": 2, "process_mode": 1})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/dialogue_box.gd")
    sc.add("Panel", "NinePatchRect", props={**rect(6, 194, 468, 72), **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")},
           unique_name=True)
    sc.add("PortraitFrame", "TextureRect", props={**rect(15, 211, 38, 38),
           "texture": sc.ext("Texture2D", "res://assets/sprites/ui/portrait_frame.png")}, unique_name=True)
    sc.add("Portrait", "TextureRect", props={**rect(18, 214, 32, 32)}, unique_name=True)
    plate = sc.add("NamePlate", "NinePatchRect", props={**rect(54, 184, 104, 16),
                   **ninepatch(sc, "res://assets/sprites/ui/panel_small.png", 4)}, unique_name=True)
    sc.add("NameLabel", "Label", parent=plate, props={**rect(6, 2, 94, 12), **label("Name", color=GOLD)},
           unique_name=True)
    sc.add("Text", "RichTextLabel", props={**rect(60, 204, 400, 56), "bbcode_enabled": True, "scroll_active": False,
           "text": ""}, unique_name=True)
    sc.add("Next", "Label", props={**rect(456, 252, 12, 12), **label("▼", color=GOLD)}, unique_name=True)
    ch = sc.add("Choices", "NinePatchRect", props={**rect(300, 120, 170, 70),
                **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")}, unique_name=True)
    sc.add("ChoiceList", "VBoxContainer", parent=ch, props={**fill_parent(), "offset_left": 9.0, "offset_top": 7.0,
           "offset_right": -9.0, "offset_bottom": -7.0, "theme_override_constants/separation": 2}, unique_name=True)
    sc.save("scenes/ui/dialogue_box.tscn")


def build_journal():
    sc = Scene("Journal", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/journal.gd")
    dim(sc)
    book = sc.add("Book", "NinePatchRect", props={**rect(28, 14, 424, 242),
                  **ninepatch(sc, "res://assets/sprites/ui/panel_parchment.png")})
    sc.add("Title", "Label", parent=book, props={**rect(0, 7, 424, 20), **label("Journal", 18, INK, 1, NO_SHADOW)})
    rich = {"bbcode_enabled": True, "theme_override_colors/default_color": INK,
            "theme_override_colors/font_shadow_color": Col(0, 0, 0, 0)}
    sc.add("Left", "RichTextLabel", parent=book, props={**rect(14, 32, 190, 190), **rich, "scroll_active": False},
           unique_name=True)
    sc.add("Divider", "ColorRect", parent=book, props={**rect(211, 34, 1, 186), "color": Col("#b0a080")})
    sc.add("Right", "RichTextLabel", parent=book, props={**rect(218, 32, 194, 190), **rich, "scroll_active": True},
           unique_name=True)
    sc.add("Footer", "Label", parent=book, props={**rect(0, 225, 424, 12),
           **label("J / Esc: close      W / S: scroll discoveries", None, INK_DIM, 1, NO_SHADOW)})
    sc.save("scenes/ui/journal.tscn")


def build_document_view():
    sc = Scene("DocumentView", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/document_view.gd")
    dim(sc)
    paper = sc.add("Paper", "NinePatchRect", props={**rect(56, 12, 368, 246),
                   **ninepatch(sc, "res://assets/sprites/ui/panel_parchment.png")})
    sc.add("DocTitle", "Label", parent=paper, props={**rect(0, 8, 368, 20), **label("", 18, INK, 1, NO_SHADOW)},
           unique_name=True)
    sc.add("DocBody", "RichTextLabel", parent=paper, props={**rect(18, 34, 332, 150), "bbcode_enabled": True,
           "scroll_active": False, "theme_override_colors/default_color": INK,
           "theme_override_colors/font_shadow_color": Col(0, 0, 0, 0)}, unique_name=True)
    sc.add("DocImage", "TextureRect", parent=paper, props={**rect(118, 188, 132, 26), "stretch_mode": 3},
           unique_name=True)
    sc.add("DocHint", "Label", parent=paper, props={**rect(16, 225, 260, 12), **label("", None, INK_DIM, 0, NO_SHADOW)},
           unique_name=True)
    sc.add("DocPage", "Label", parent=paper, props={**rect(290, 225, 62, 12), **label("", None, INK_DIM, 2, NO_SHADOW)},
           unique_name=True)
    sc.save("scenes/ui/document_view.tscn")


def build_pause_menu():
    sc = Scene("PauseMenu", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/pause_menu.gd")
    dim(sc, a=0.55)
    panel = sc.add("Panel", "NinePatchRect", props={**rect(158, 40, 164, 190),
                   **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")})
    sc.add("Title", "Label", parent=panel, props={**rect(0, 10, 164, 20), **label("Paused", 18, GOLD, 1)})
    box = sc.add("PauseButtons", "VBoxContainer", parent=panel, props={**rect(26, 36, 112, 112),
                 "theme_override_constants/separation": 1}, unique_name=True)
    for name, text in (("Resume", "Resume"), ("JournalBtn", "Journal"), ("SaveBtn", "Save Game"),
                       ("SettingsBtn", "Settings"), ("TitleBtn", "Return to Title"), ("QuitBtn", "Quit Game")):
        sc.add(name, "Button", parent=box, props={"text": text}, unique_name=True)
    sc.add("PauseStatus", "Label", parent=panel, props={**rect(10, 152, 144, 30),
           **label("", None, DIM, 1, {"autowrap_mode": 3})}, unique_name=True)
    sc.save("scenes/ui/pause_menu.tscn")


def build_settings_menu():
    sc = Scene("SettingsMenu", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/settings_menu.gd")
    dim(sc, a=0.55)
    panel = sc.add("Panel", "NinePatchRect", props={**rect(106, 24, 268, 222),
                   **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")})
    sc.add("Title", "Label", parent=panel, props={**rect(0, 10, 268, 20), **label("Settings", 18, GOLD, 1)})
    sc.add("SettingsRows", "VBoxContainer", parent=panel, props={**rect(18, 36, 236, 150),
           "theme_override_constants/separation": 4}, unique_name=True)
    sc.add("SettingsBack", "Button", parent=panel, props={**rect(94, 194, 80, 16), "text": "Back"}, unique_name=True)
    sc.save("scenes/ui/settings_menu.tscn")


def build_ui_root():
    sc = Scene("UI", "Node")
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/ui.gd")
    small = sc.sub("StyleBoxTexture", {"texture": sc.ext("Texture2D", "res://assets/sprites/ui/panel_small.png"),
                                       "texture_margin_left": 4.0, "texture_margin_top": 4.0,
                                       "texture_margin_right": 4.0, "texture_margin_bottom": 4.0,
                                       "content_margin_left": 4.0, "content_margin_top": 2.0,
                                       "content_margin_right": 5.0, "content_margin_bottom": 2.0})
    fx = sc.add("EffectsLayer", "CanvasLayer", props={"layer": 5})
    sc.add("Vignette", "TextureRect", parent=fx, props={**FULL, "mouse_filter": 2, "expand_mode": 1, "stretch_mode": 0,
           "texture": sc.ext("Texture2D", "res://assets/sprites/fx/vignette.png"),
           "modulate": Col(1, 1, 1, 0.8)}, unique_name=True)
    mat = sc.sub("ShaderMaterial", {"shader": sc.ext("Shader", "res://assets/shaders/echo_overlay.gdshader"),
                                    "shader_parameter/strength": 0.0})
    sc.add("EchoOverlay", "ColorRect", parent=fx, props={**FULL, "mouse_filter": 2, "material": mat},
           unique_name=True)
    hl = sc.add("HudLayer", "CanvasLayer", props={"layer": 10})
    hud = sc.add("Hud", "Control", parent=hl, props={**FULL, "mouse_filter": 2}, unique_name=True)
    # objective (top-left)
    obj = sc.add("Objective", "PanelContainer", parent=hud, props={**rect(5, 5, 20, 16), "mouse_filter": 2,
                 "theme_override_styles/panel": small}, unique_name=True)
    ob = sc.add("Row", "HBoxContainer", parent=obj, props={"theme_override_constants/separation": 3, "mouse_filter": 2})
    sc.add("Icon", "TextureRect", parent=ob, props={"texture": sc.ext("Texture2D", "res://assets/sprites/ui/icon_bell.png"),
           "stretch_mode": 3, "custom_minimum_size": V2(12, 12), "expand_mode": 1})
    sc.add("ObjectiveLabel", "Label", parent=ob, props={**label("", None, Col("#e8dcc0"))}, unique_name=True)
    # interact prompt
    pr = sc.add("Prompt", "PanelContainer", parent=hud, props={**rect(0, 0, 20, 14), "mouse_filter": 2,
                "theme_override_styles/panel": small}, unique_name=True)
    pb = sc.add("Row", "HBoxContainer", parent=pr, props={"theme_override_constants/separation": 3})
    sc.add("Key", "TextureRect", parent=pb, props={"texture": sc.ext("Texture2D", "res://assets/sprites/ui/key_e.png"),
           "stretch_mode": 3})
    sc.add("PromptLabel", "Label", parent=pb, props={**label("Inspect")}, unique_name=True)
    # echo prompt
    ep = sc.add("EchoPrompt", "PanelContainer", parent=hud, props={**rect(0, 0, 20, 14), "mouse_filter": 2,
                "theme_override_styles/panel": small}, unique_name=True)
    eb = sc.add("Row", "HBoxContainer", parent=ep, props={"theme_override_constants/separation": 3})
    sc.add("Key", "TextureRect", parent=eb, props={"texture": sc.ext("Texture2D", "res://assets/sprites/ui/key_f.png"),
           "stretch_mode": 3})
    sc.add("EchoLabel", "Label", parent=eb, props={**label("Listen", None, Col("#9ad8f0"))})
    # toast
    to = sc.add("Toast", "PanelContainer", parent=hud, props={**rect(180, 24, 20, 16), "mouse_filter": 2,
                "theme_override_styles/panel": small}, unique_name=True)
    tb = sc.add("Row", "HBoxContainer", parent=to, props={"theme_override_constants/separation": 4})
    sc.add("ToastIcon", "TextureRect", parent=tb, props={"stretch_mode": 3}, unique_name=True)
    sc.add("ToastLabel", "Label", parent=tb, props={**label("", None, Col("#f0e4c8"))}, unique_name=True)
    # area title
    at = sc.add("AreaTitle", "VBoxContainer", parent=hud, props={**rect(0, 46, 480, 40), "mouse_filter": 2,
                "theme_override_constants/separation": 2}, unique_name=True)
    sc.add("AreaTitleLabel", "Label", parent=at, props={**label("", 18, GOLD, 1)}, unique_name=True)
    sc.add("AreaSubLabel", "Label", parent=at, props={**label("", None, DIM, 1)}, unique_name=True)
    # save note
    sn = sc.add("SaveNote", "HBoxContainer", parent=hud, props={**rect(414, 251, 62, 16), "mouse_filter": 2,
                "theme_override_constants/separation": 2}, unique_name=True)
    sc.add("Icon", "TextureRect", parent=sn, props={"texture": sc.ext("Texture2D", "res://assets/sprites/ui/icon_quill.png"),
           "stretch_mode": 3})
    sc.add("Text", "Label", parent=sn, props={**label("Saved", None, Col("#d8ccb4"))})
    dl = sc.add("DialogueLayer", "CanvasLayer", props={"layer": 15})
    sc.add("DialogueBox", None, parent=dl, instance=sc.ext("PackedScene", "res://scenes/ui/dialogue_box.tscn"),
           unique_name=True)
    ml = sc.add("MenuLayer", "CanvasLayer", props={"layer": 20})
    for name, path in (("DocumentView", "document_view"), ("Journal", "journal"), ("PauseMenu", "pause_menu"),
                       ("SettingsMenu", "settings_menu")):
        sc.add(name, None, parent=ml, instance=sc.ext("PackedScene", f"res://scenes/ui/{path}.tscn"), unique_name=True)
    sc.save("scenes/ui/ui.tscn")


# ---------------------------------------------------------------- screens --
def build_main_menu():
    sc = Scene("MainMenu", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/main_menu.gd")
    sc.add("Background", "TextureRect", props={**FULL, "texture": sc.ext("Texture2D", "res://assets/backgrounds/vista_dusk.png")})
    add = sc.sub("CanvasItemMaterial", {"blend_mode": 1})
    sc.add("TowerGlow", "TextureRect", props={**rect(372, 66, 40, 40), "material": add, "expand_mode": 1,
           "texture": sc.ext("Texture2D", "res://assets/sprites/fx/light_radial.png"),
           "modulate": Col(0.5, 0.85, 1.0, 0.45)}, unique_name=True)
    for name, tex, y, h in (("MistB", "mist_band_b", 166, 50), ("MistA", "mist_band_a", 196, 60)):
        holder = sc.add(name, "Control", props={**rect(0, y, 960, h), "mouse_filter": 2}, unique_name=True)
        t = sc.ext("Texture2D", f"res://assets/backgrounds/{tex}.png")
        sc.add("A", "TextureRect", parent=holder, props={**rect(0, 0, 480, h), "texture": t, "mouse_filter": 2})
        sc.add("B", "TextureRect", parent=holder, props={**rect(480, 0, 480, h), "texture": t, "mouse_filter": 2})
    sc.add("Logo", "TextureRect", props={**rect(104, 22, 271, 68),
           "texture": sc.ext("Texture2D", "res://assets/sprites/ui/logo.png")}, unique_name=True)
    sc.add("Tagline", "Label", props={**rect(0, 98, 480, 12),
           **label("Every night the bell saves the village. Every night, someone forgets why.", None, Col("#c8bcd8"), 1)},
           unique_name=True)
    menu = sc.add("Menu", "VBoxContainer", props={**rect(186, 122, 108, 92), "theme_override_constants/separation": 0},
                  unique_name=True)
    for name, text in (("NewGame", "New Game"), ("Continue", "Continue"), ("SettingsBtn", "Settings"),
                       ("CreditsBtn", "Credits"), ("QuitBtn", "Quit")):
        sc.add(name, "Button", parent=menu, props={"text": text}, unique_name=True)
    sc.add("SaveInfo", "Label", props={**rect(0, 222, 480, 12), **label("", None, DIM, 1)}, unique_name=True)
    sc.add("Version", "Label", props={**rect(5, 255, 220, 12), **label("v0.1 - prototype", None, Col("#6e6482"))})
    sc.add("Hint", "Label", props={**rect(255, 255, 220, 12),
           **label("Arrows/WASD + Enter    F11: fullscreen", None, Col("#6e6482"), 2)})
    # credits panel
    cr = sc.add("Credits", "Control", props={**FULL, "visible": False}, unique_name=True)
    dim(sc, cr, 0.7)
    cp = sc.add("Panel", "NinePatchRect", parent=cr, props={**rect(70, 20, 340, 230),
                **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")})
    sc.add("CreditsText", "RichTextLabel", parent=cp, props={**rect(14, 12, 312, 186), "bbcode_enabled": True,
           "scroll_active": False}, unique_name=True)
    sc.add("CreditsBack", "Button", parent=cp, props={**rect(130, 204, 80, 16), "text": "Back"}, unique_name=True)
    # new game confirmation
    cf = sc.add("Confirm", "Control", props={**FULL, "visible": False}, unique_name=True)
    dim(sc, cf, 0.7)
    fp = sc.add("Panel", "NinePatchRect", parent=cf, props={**rect(120, 90, 240, 90),
                **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")})
    sc.add("Question", "Label", parent=fp, props={**rect(12, 12, 216, 40),
           **label("Start a new game? Your saved progress will be replaced.", None, None, 1, {"autowrap_mode": 3})})
    sc.add("ConfirmYes", "Button", parent=fp, props={**rect(40, 60, 70, 16), "text": "Start"}, unique_name=True)
    sc.add("ConfirmNo", "Button", parent=fp, props={**rect(130, 60, 70, 16), "text": "Cancel"}, unique_name=True)
    sc.save("scenes/main/main_menu.tscn")


def build_prologue():
    sc = Scene("Prologue", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/prologue.gd")
    sc.add("Black", "ColorRect", props={**FULL, "color": Col("#050307")})
    sc.add("Tolls", "HBoxContainer", props={**rect(150, 196, 180, 8), "alignment": 1,
           "theme_override_constants/separation": 6}, unique_name=True)
    sc.add("Line", "Label", props={**rect(40, 104, 400, 50), **label("", None, Col("#e0d6c4"), 1,
           {"autowrap_mode": 3, "vertical_alignment": 1})}, unique_name=True)
    lt = sc.add("Letter", "NinePatchRect", props={**rect(110, 66, 260, 120), "visible": False,
                **ninepatch(sc, "res://assets/sprites/ui/panel_parchment.png")}, unique_name=True)
    sc.add("LetterText", "RichTextLabel", parent=lt, props={**rect(16, 14, 228, 96), "bbcode_enabled": True,
           "scroll_active": False, "theme_override_colors/default_color": INK,
           "theme_override_colors/font_shadow_color": Col(0, 0, 0, 0)}, unique_name=True)
    sc.add("Skip", "Label", props={**rect(256, 255, 220, 12), **label("Esc: skip", None, Col("#4e465a"), 2)},
           unique_name=True)
    sc.save("scenes/main/prologue.tscn")


def build_ending():
    sc = Scene("Ending", "Control", {**FULL})
    sc.nodes[0][3]["script"] = sc.ext("Script", "res://scripts/ui/ending.gd")
    sc.add("Sky", "TextureRect", props={**FULL, "texture": sc.ext("Texture2D", "res://assets/backgrounds/vista_night.png")},
           unique_name=True)
    sc.add("Tint", "ColorRect", props={**FULL, "mouse_filter": 2, "color": Col(1, 1, 1, 0)}, unique_name=True)
    sc.add("FX", "Node2D", unique_name=True)
    for name, tex, y, h in (("MistB", "mist_band_b", 166, 50), ("MistA", "mist_band_a", 192, 60)):
        holder = sc.add(name, "Control", props={**rect(0, y, 960, h), "mouse_filter": 2}, unique_name=True)
        t = sc.ext("Texture2D", f"res://assets/backgrounds/{tex}.png")
        sc.add("A", "TextureRect", parent=holder, props={**rect(0, 0, 480, h), "texture": t, "mouse_filter": 2})
        sc.add("B", "TextureRect", parent=holder, props={**rect(480, 0, 480, h), "texture": t, "mouse_filter": 2})
    dmat = sc.sub("ShaderMaterial", {"shader": sc.ext("Shader", "res://assets/shaders/dissolve.gdshader"),
                                     "shader_parameter/progress": 0.0,
                                     "shader_parameter/noise_tex": sc.ext("Texture2D", "res://assets/sprites/fx/noise.png")})
    sc.add("Memory", "TextureRect", props={**rect(156, 52, 168, 104), "visible": False, "material": dmat,
           "texture": sc.ext("Texture2D", "res://assets/backgrounds/memory_orin.png")}, unique_name=True)
    sc.add("Shade", "ColorRect", props={**FULL, "mouse_filter": 2, "color": Col(0.02, 0.016, 0.03, 0)}, unique_name=True)
    sc.add("NarrationBack", "ColorRect", props={**rect(0, 186, 480, 62), "mouse_filter": 2,
           "color": Col(0.02, 0.01, 0.04, 0.6)}, unique_name=True)
    sc.add("Narration", "Label", props={**rect(36, 190, 408, 54), **label("", None, Col("#ece2cc"), 1,
           {"autowrap_mode": 3, "vertical_alignment": 1})}, unique_name=True)
    sc.add("TitleCard", "Label", props={**rect(0, 100, 480, 40), **label("", 27, GOLD, 1, {"vertical_alignment": 1})},
           unique_name=True)
    sm = sc.add("Summary", "Control", props={**FULL, "visible": False}, unique_name=True)
    dim(sc, sm, 0.55)
    sp = sc.add("Panel", "NinePatchRect", parent=sm, props={**rect(50, 14, 380, 242),
                **ninepatch(sc, "res://assets/sprites/ui/panel_dark.png")})
    sc.add("SummaryTitle", "Label", parent=sp, props={**rect(0, 9, 380, 20), **label("", 18, GOLD, 1)},
           unique_name=True)
    sc.add("SummaryText", "RichTextLabel", parent=sp, props={**rect(16, 34, 348, 172), "bbcode_enabled": True,
           "scroll_active": False}, unique_name=True)
    bx = sc.add("Buttons", "HBoxContainer", parent=sp, props={**rect(60, 214, 260, 16), "alignment": 1,
                "theme_override_constants/separation": 16})
    sc.add("ToCredits", "Button", parent=bx, props={"text": "Credits"}, unique_name=True)
    sc.add("ToTitle", "Button", parent=bx, props={"text": "Return to Title"}, unique_name=True)
    cr = sc.add("CreditsRoll", "Control", props={**FULL, "visible": False, "clip_contents": True}, unique_name=True)
    sc.add("CreditsText", "RichTextLabel", parent=cr, props={**rect(60, 270, 360, 560), "bbcode_enabled": True,
           "scroll_active": False, "fit_content": True}, unique_name=True)
    sc.add("Hint", "Label", props={**rect(256, 255, 220, 12), **label("", None, Col("#6e6482"), 2)}, unique_name=True)
    sc.save("scenes/main/ending.tscn")


def build_all():
    build_dialogue_box()
    build_journal()
    build_document_view()
    build_pause_menu()
    build_settings_menu()
    build_ui_root()
    build_main_menu()
    build_prologue()
    build_ending()


if __name__ == "__main__":
    build_all()
    print("ui scenes ok")
