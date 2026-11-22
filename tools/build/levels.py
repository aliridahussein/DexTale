"""The five areas of THE THIRTEENTH BELL, described with level_kit.

Regenerating overwrites scenes/world/*.tscn. Once you start editing those
scenes in the Godot editor, treat the editor copies as the source of truth.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from level_kit import Level, PROPS  # noqa: E402
from tscn import V2, Col  # noqa: E402

FX = "res://assets/sprites/fx/"
CH = "res://assets/sprites/characters/"
WARM = "#ffb46a"


def scatter(L: Level, kind, zones, count, seed, avoid=()):
    import random
    rng = random.Random(seed)
    placed = 0
    tries = 0
    while placed < count and tries < count * 40:
        tries += 1
        x0, y0, x1, y1 = rng.choice(zones)
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        if any(ax0 <= x <= ax1 and ay0 <= y <= ay1 for (ax0, ay0, ax1, ay1) in avoid):
            continue
        L.prop(kind, x, y, f"{kind.title().replace('_', '')}{placed + 1}")
        placed += 1


# =============================================================== village ===
def village():
    L = Level("Village", "village", 48, 36, "res://scripts/world/village.gd", seed=7,
              display_name="Dawnmere", subtitle="Village square, at sundown", music="village_dusk",
              ambience="village_evening", footstep_surface="grass")
    L.fill("grass")
    L.rect(0, 0, 47, 4, "grass_dark")
    L.rect(0, 4, 47, 8, "canopy", "overlay")
    L.rect(0, 11, 2, 35, "canopy", "overlay")
    L.rect(45, 11, 47, 35, "canopy", "overlay")
    L.rect(0, 34, 47, 35, "canopy", "overlay")
    L.rect(21, 34, 26, 35, None, "overlay")
    L.rect(0, 9, 47, 9, "cap:village")
    L.rect(0, 10, 47, 10, "face:village:lower")
    L.rect(22, 9, 25, 10, "cobble")
    L.rect(22, 11, 25, 15, "cobble")
    L.ellipse(24, 20.5, 10.5, 6, "cobble")
    L.rect(22, 25, 25, 35, "cobble")
    L.rect(6, 18, 14, 19, "dirt")
    L.rect(33, 17, 37, 18, "cobble")
    L.path([(26, 27), (30, 29), (34.5, 32)], 2, "dirt")
    L.path([(12, 22), (12, 31)], 1.6, "dirt")
    L.backdrop("res://assets/backgrounds/village_backdrop.png", 0, 0, "Horizon")
    # individual trees along the forest band so the canopy doesn't read as wallpaper
    for i, (x, y) in enumerate([(36, 128), (92, 120), (150, 136), (214, 124), (276, 138), (318, 118),
                                (458, 122), (500, 138), (556, 120), (618, 134), (676, 122), (738, 136)]):
        L.prop("tree_pine_dark" if i % 3 == 0 else ("tree_oak_b" if i % 3 == 1 else "tree_pine"), x, y,
               f"ForestTree{i + 1}")
    # buildings
    L.prop("forge_ext", 128, 288, "Forge")
    L.prop("chapel_ext", 592, 272, "Chapel")
    L.prop("house_cottage", 184, 216, "CottageNW")
    L.prop("house_cottage_b", 488, 216, "CottageNE")
    L.prop("house_narrow", 152, 496, "HouseSW")
    L.prop("house_tavern", 584, 512, "Tavern")
    L.prop("well", 384, 344, "Well")
    L.prop("gate_north", 384, 176, "Gate")
    L.prop("market_stall", 312, 296, "StallA")
    L.prop("market_stall_b", 464, 296, "StallB")
    L.prop("notice_board", 336, 428, "NoticeBoard")
    L.prop("signpost", 432, 428, "Signpost")
    for i, (x, y) in enumerate([(232, 256), (536, 256), (232, 408), (536, 408), (338, 190), (430, 190),
                                (346, 520), (422, 520), (158, 302), (626, 292)]):
        L.prop("lantern_post", x, y, f"Lantern{i + 1}")
    L.prop("bench", 344, 374)
    L.prop("bench", 424, 374)
    for (k, x, y) in [("barrel", 282, 302), ("crate", 274, 314), ("crate_stack", 496, 302), ("sack", 506, 312),
                      ("barrel", 178, 294), ("barrel", 188, 302), ("crate", 174, 310), ("barrel", 532, 504),
                      ("barrel", 528, 515), ("hay_bale", 652, 512), ("cart", 664, 476), ("bucket", 404, 350),
                      ("flower_pot_0", 166, 222), ("flower_pot_1", 202, 222), ("flower_pot_2", 566, 520),
                      ("flower_pot_0", 600, 520), ("flower_pot_1", 472, 222), ("flower_pot_2", 170, 504),
                      ("fence", 112, 516), ("fence", 128, 516), ("fence_broken", 96, 516)]:
        L.prop(k, x, y)
    for (k, x, y) in [("tree_oak", 64, 236), ("tree_pine", 60, 356), ("tree_oak_b", 74, 456), ("tree_pine", 100, 544),
                      ("tree_pine", 712, 240), ("tree_oak", 708, 344), ("tree_oak_b", 714, 444), ("tree_pine", 724, 544),
                      ("tree_oak", 266, 540), ("tree_oak_b", 500, 548), ("tree_pine", 610, 200)]:
        L.prop(k, x, y)
    for (k, x, y) in [("bush", 236, 198), ("bush_flowers", 212, 232), ("bush", 538, 200), ("bush_flowers", 516, 234),
                      ("bush", 128, 346), ("bush_flowers", 178, 362), ("bush", 628, 340), ("bush", 292, 470),
                      ("bush_flowers", 478, 472), ("bush", 646, 400), ("bush", 96, 260), ("rock", 300, 556),
                      ("stump", 690, 300), ("rock", 80, 300)]:
        L.prop(k, x, y)
    scatter(L, "tall_grass", [(56, 200, 120, 520), (650, 200, 712, 530), (250, 450, 330, 540), (450, 450, 520, 540)],
            26, 3, avoid=[(330, 400, 440, 576)])
    # characters
    L.player(384, 552)
    L.npc("Pip", 420, 322, "pip", "pip", facing="up")
    L.npc("Tobin", 296, 392, "tobin", "tobin", facing="down", wander_radius=40.0, wander_speed=18.0)
    L.npc("Cat", 356, 302, "cat", "cat", facing="right", wander_radius=48.0, wander_speed=16.0, talk_prompt="Pet")
    # interactions
    L.interact("WellInspect", 384, 338, "village_well", r=16, prompt_offset=V2(0, -40))
    L.echo("WellEcho", 384, 338, "well", "village_well_echo", texture=FX + "echo_names.png", r=18,
           reveal_offset=V2(-30, -58), hint_offset=V2(0, -52))
    L.interact("NoticeRead", 336, 432, "village_notice", "Read", r=14, prompt_offset=V2(0, -36))
    L.interact("SignRead", 432, 432, "village_signpost", "Read", r=10, prompt_offset=V2(0, -34))
    L.interact("StallInspect", 312, 302, "village_stall", r=14, prompt_offset=V2(0, -44))
    L.interact("GateUse", 384, 184, "village_gate", "Open", r=14, prompt_offset=V2(0, -42), hidden_when="gate_unlocked")
    L.interact("DoorNW", 184, 220, "village_door_nw", "Knock", r=9, prompt_offset=V2(0, -26))
    L.interact("DoorNE", 478, 220, "village_door_ne", "Knock", r=9, prompt_offset=V2(0, -26))
    L.interact("DoorSW", 158, 500, "village_door_sw", "Knock", r=9, prompt_offset=V2(0, -26))
    L.interact("TavernDoor", 583, 516, "village_tavern", "Knock", r=9, prompt_offset=V2(0, -26))
    L.interact("CartLook", 664, 482, "village_cart", r=12)
    # travel
    L.exit("ToForge", 122, 293, 18, 8, "forge", "from_village")
    L.exit("ToChapel", 592, 277, 18, 8, "chapel", "from_village")
    L.exit("ToPath", 384, 152, 64, 10, "mist_path", "from_village", requires="gate_unlocked")
    L.trigger("LeaveVillage", 384, 570, 96, 12, conversation_id="village_leave")
    L.spawn("default", 384, 392, "down")
    L.spawn("start", 384, 552, "up")
    L.spawn("from_forge", 122, 312, "down")
    L.spawn("from_chapel", 592, 298, "down")
    L.spawn("from_path", 384, 200, "down")
    # light
    L.ambient = Col(0.97, 0.82, 0.74)
    L.light("ForgeDoorGlow", 122, 282, "#ff9a4a", 1.1, 1.1)
    for i, (x, y) in enumerate([(559, 487), (603, 487), (584, 466), (169, 196), (197, 196)]):
        L.light(f"WindowGlow{i + 1}", x, y, WARM, 0.55, 0.45)
    L.light("TowerGlow", 400, 34, "#7ad0ff", 0.55, 0.45, flicker=False)
    for i, x in enumerate((60, 260, 470)):
        L.shaft(f"SunRay{i + 1}", x, -10, -32, 3.0, 4.2, "#ffb878", 0.13)
    L.particles("Fireflies", 384, 330, amount=22, lifetime=7.0, emission_shape=3, emission_rect_extents=(320.0, 200.0),
                direction=(0.0, -1.0), spread=180.0, gravity=(0.0, 0.0), initial_velocity_min=2.0,
                initial_velocity_max=6.0, texture="px2", color=Col("#e8f08a"),
                ramp=[(0.0, (1, 1, 1, 0)), (0.3, (1, 1, 1, 1)), (0.7, (1, 1, 1, 0.8)), (1.0, (1, 1, 1, 0))])
    for name, (x, y) in (("ForgeSmoke", (104, 226)), ("CottageSmoke", (200, 162))):
        L.particles(name, x, y, amount=9, lifetime=3.5, emission_shape=1, emission_sphere_radius=2.0,
                    direction=(0.3, -1.0), spread=12.0, gravity=(3.0, -3.0), initial_velocity_min=5.0,
                    initial_velocity_max=9.0, texture="mote", additive=False, scale_amount_min=1.0,
                    scale_amount_max=2.6, ramp=[(0.0, (0.55, 0.55, 0.6, 0.0)), (0.2, (0.55, 0.55, 0.6, 0.55)),
                                                (1.0, (0.4, 0.4, 0.45, 0.0))])
    L.mist = {"density": 0.32, "edge_only": True, "tint": "#c4ccd8"}
    return L


# ================================================================= forge ===
def forge():
    L = Level("Forge", "forge", 20, 14, "res://scripts/world/forge.gd", seed=11, display_name="Mara's Forge",
              music="", ambience="forge", reverb=0.15, footstep_surface="stone")
    L.fill("cap:forge")
    L.rect(1, 1, 18, 1, "face:forge:upper")
    L.rect(1, 2, 18, 2, "face:forge:lower")
    L.rect(1, 3, 18, 12, "forgefloor")
    L.rect(9, 13, 10, 13, "forgefloor")
    L.prop("furnace", 88, 70)
    L.prop("forge_plaque", 160, 36, "FamilyPlaque")
    L.prop("tool_rack", 214, 42)
    L.prop("workbench", 256, 70)
    L.prop("shelf_jar", 302, 60, "Shelf")
    L.prop("bellows", 128, 72)
    L.prop("anvil", 150, 132)
    L.prop("quench_barrel", 118, 120)
    L.prop("coal_pile", 40, 102)
    L.prop("weapon_rack", 290, 132)
    L.prop("cradle", 38, 190)
    L.prop("crate", 296, 186)
    L.prop("crate_stack", 278, 196)
    L.prop("barrel", 24, 74)
    L.prop("wall_lantern", 48, 40, "LanternW")
    L.prop("wall_lantern", 240, 40, "LanternE")
    L.sprite("Objects", "TuningPin", "res://assets/sprites/props/tuning_pin_item.png", 252, 71, offset=(-7, -18),
             visible=False)
    L.player(160, 196)
    L.npc("Mara", 176, 136, "mara", "mara", facing="left")
    L.interact("PinInspect", 252, 76, "forge_pin", r=12, prompt_offset=V2(0, -32),
               requires="mara_showed_pin", hidden_when="has_tuning_pin")
    L.echo("PinEcho", 252, 76, "pin_marking", "forge_pin_echo", texture=FX + "symbol_bell13.png", r=14,
           requires="mara_showed_pin", hidden_when="has_tuning_pin", sets_flag="discovered_bell_markings",
           reveal_offset=V2(-20, -66), hint_offset=V2(0, -44))
    L.interact("PlaqueRead", 160, 54, "forge_plaque", "Read", r=12, prompt_offset=V2(0, -30))
    L.interact("SwordsLook", 290, 136, "forge_swords", r=12, prompt_offset=V2(0, -36))
    L.interact("BarrelLook", 118, 124, "forge_barrel", r=9)
    L.interact("JarLook", 302, 66, "forge_jar", r=10, prompt_offset=V2(0, -30))
    L.interact("CradleLook", 38, 194, "forge_cradle", r=11)
    L.echo("CradleEcho", 38, 194, "cradle", "forge_cradle_echo", atlas=(CH + "mara.png", (0, 0, 16, 24)), r=14,
           reveal_offset=V2(14, -16), hint_offset=V2(0, -26))
    L.interact("FurnaceLook", 88, 76, "forge_furnace", r=12, prompt_offset=V2(0, -60))
    L.interact("AnvilLook", 150, 136, "forge_anvil", r=9)
    L.exit("ToVillage", 160, 222, 32, 8, "village", "from_forge")
    L.spawn("default", 160, 196, "up")
    L.spawn("from_village", 160, 196, "up")
    L.ambient = Col(0.58, 0.47, 0.46)
    L.particles("Embers", 88, 52, amount=14, lifetime=1.8, emission_shape=3, emission_rect_extents=(10.0, 3.0),
                direction=(0.0, -1.0), spread=25.0, gravity=(0.0, -18.0), initial_velocity_min=10.0,
                initial_velocity_max=24.0, texture="px1", color=Col("#ffd080"),
                ramp=[(0.0, (1, 0.9, 0.5, 1)), (0.6, (1, 0.5, 0.2, 0.9)), (1.0, (0.8, 0.2, 0.1, 0))])
    L.particles("AnvilSparks", 150, 120, emitting=False, one_shot=True, explosiveness=0.9, amount=16, lifetime=0.6,
                emission_shape=0, direction=(0.0, -1.0), spread=70.0, gravity=(0.0, 160.0),
                initial_velocity_min=30.0, initial_velocity_max=70.0, texture="px1", color=Col("#ffe7a0"),
                ramp=[(0.0, (1, 1, 0.7, 1)), (1.0, (1, 0.4, 0.1, 0))])
    return L


# ================================================================ chapel ===
def chapel():
    L = Level("Chapel", "chapel", 22, 22, "res://scripts/world/chapel.gd", seed=13,
              display_name="The Forgotten Chapel", music="chapel", ambience="chapel", reverb=0.6,
              footstep_surface="stone")
    L.fill("cap:chapel")
    L.rect(13, 1, 20, 1, "face:chapel:upper")
    L.rect(13, 2, 20, 2, "face:chapel:lower")
    L.rect(13, 3, 20, 5, "flag")
    L.rect(1, 7, 20, 7, "face:chapel:upper")
    L.rect(1, 8, 20, 8, "face:chapel:lower")
    L.rect(16, 6, 17, 8, "flag")
    L.rect(1, 9, 20, 20, "flag")
    L.rect(9, 9, 9, 20, "carpet_l")
    L.rect(10, 9, 10, 20, "carpet_m")
    L.rect(11, 9, 11, 20, "carpet_r")
    L.rect(10, 21, 11, 21, "flag")
    L.prop("bookshelf", 40, 146, "ShelfA")
    L.prop("bookshelf_b", 78, 146, "ShelfB")
    L.prop("stained_window", 116, 143, "WindowA")
    L.prop("stained_window", 204, 143, "WindowB")
    L.prop("altar", 160, 178)
    L.prop("candle_stand", 128, 182, "CandleL")
    L.prop("candle_stand", 192, 182, "CandleR")
    L.prop("inscription_plaque", 234, 138, "Plaque")
    L.prop("archive_door", 272, 144, "ArchiveDoor")
    L.prop("seal_flame", 298, 134, "SealFlame")
    L.prop("seal_moon", 316, 134, "SealMoon")
    L.prop("seal_crown", 334, 134, "SealCrown")
    for y in (214, 246, 278, 310):
        L.prop("pew", 92, y)
        L.prop("pew", 228, y)
    L.prop("statue_broken", 314, 238, "Statue")
    L.prop("donation_box", 210, 326)
    L.prop("banner_torn", 30, 226, "Banner")
    L.decal("papers", 64, 190)
    L.prop("lectern", 272, 92, "Lectern")
    L.prop("bookshelf_b", 232, 52, "ArchiveShelf")
    L.prop("candle_stand", 310, 84, "ArchiveCandle")
    L.decal("papers", 300, 94, "ArchivePapers")
    L.player(176, 324)
    L.npc("Alden", 70, 172, "alden", "alden", facing="down")
    L.interact("PlaqueRead", 234, 152, "chapel_inscription", "Read", r=8, prompt_offset=V2(0, -32))
    L.echo("PlaqueEcho", 234, 152, "inscription", "chapel_inscription_echo", texture=FX + "echo_inscription.png",
           r=14, sets_flag="inscription_clear", reveal_offset=V2(-100, -70), hint_offset=V2(0, -44))
    for name, x, sym in (("SealFlameUse", 298, "flame"), ("SealMoonUse", 316, "moon"), ("SealCrownUse", 334, "crown")):
        L.interact(name, x, 152, "", "Press", r=7, prompt_offset=V2(0, -34), hidden_when="solved_chapel_puzzle")
    L.interact("ArchiveDoorLook", 272, 152, "chapel_archive_door", r=7, prompt_offset=V2(0, -46),
               hidden_when="solved_chapel_puzzle")
    L.interact("LedgerRead", 272, 98, "chapel_ledger", "Read", r=12, prompt_offset=V2(0, -32))
    L.echo("LedgerEcho", 272, 98, "ledger", "chapel_ledger_echo", atlas=(CH + "orin.png", (0, 48, 16, 24)), r=16,
           requires="read_bellkeeper_ledger", reveal_offset=V2(-16, -12), hint_offset=V2(0, -40))
    L.echo("ChorusEcho", 176, 250, "chorus", "chapel_chorus_echo", texture=FX + "echo_chorus.png", r=22,
           reveal_offset=V2(-48, -40), hint_offset=V2(0, -18))
    L.interact("ShelfSearch", 59, 152, "chapel_shelves", "Search", r=14, prompt_offset=V2(0, -46))
    L.interact("AltarLook", 160, 184, "chapel_altar", r=14, prompt_offset=V2(0, -40))
    L.interact("StatueLook", 314, 242, "chapel_statue", r=12, prompt_offset=V2(0, -42))
    L.interact("DonationBox", 210, 330, "chapel_donations", r=8)
    L.interact("WindowLook", 116, 152, "chapel_window", "Look", r=8, prompt_offset=V2(0, -46))
    L.interact("ArchiveShelfSearch", 232, 58, "chapel_archive_shelf", "Search", r=12, prompt_offset=V2(0, -44))
    L.exit("ToVillage", 176, 350, 32, 8, "village", "from_chapel")
    L.spawn("default", 176, 324, "up")
    L.spawn("from_village", 176, 324, "up")
    L.ambient = Col(0.44, 0.42, 0.58)
    L.shaft("WindowRayA", 116, 112, -16, 1.4, 1.9, "#c0a0ff", 0.16)
    L.shaft("WindowRayB", 204, 112, -16, 1.4, 1.9, "#ffd890", 0.13)
    L.light("ArchiveGlow", 272, 72, "#ffc890", 0.55, 0.55)
    L.particles("Dust", 176, 236, amount=34, lifetime=9.0, emission_shape=3, emission_rect_extents=(150.0, 90.0),
                direction=(0.2, 1.0), spread=180.0, gravity=(0.0, 1.0), initial_velocity_min=1.0,
                initial_velocity_max=3.0, texture="px1", color=Col("#f0e0c0"),
                ramp=[(0.0, (1, 1, 1, 0)), (0.4, (1, 1, 1, 0.55)), (1.0, (1, 1, 1, 0))])
    return L


# ============================================================= mist path ===
def mist_path():
    L = Level("MistPath", "mist_path", 24, 46, "res://scripts/world/mist_path.gd", seed=17,
              display_name="The Mistbound Path", subtitle="The road to the tower", music="mist",
              ambience="mist_forest", reverb=0.25, footstep_surface="dirt")
    L.fill("forest")
    L.fill("canopy", "overlay")
    L.rect(4, 0, 19, 11, None, "overlay")
    L.rect(6, 12, 17, 25, None, "overlay")
    L.rect(10, 26, 13, 27, None, "overlay")
    L.path([(12, 27), (12, 31), (9, 35), (9, 38), (12, 41), (12, 46)], 5.2, None, "overlay")
    L.rect(4, 34, 8, 39, None, "overlay")
    L.rect(4, 0, 19, 11, "grass_dark")
    L.rect(6, 12, 17, 25, "grass_dark")
    L.path([(12, 10.5), (12, 31), (9, 35), (9, 38), (12, 41), (12, 46)], 2.4, "dirt")
    L.rect(8, 32, 10, 33, "steps")
    L.rect(10, 9, 13, 11, "cobble_dark")
    L.prop("tower_base", 192, 152, "TowerBase")
    for (k, x, y) in [("tree_dead", 104, 224), ("tree_pine_dark", 282, 236), ("tree_dead", 276, 368),
                      ("tree_pine_dark", 104, 352), ("tree_dead", 92, 600), ("tree_pine_dark", 252, 640),
                      ("tree_dead", 228, 712), ("tree_pine_dark", 84, 120), ("tree_dead", 300, 96),
                      ("rock_large", 150, 432), ("rock_large", 236, 434), ("rock", 120, 300), ("rock", 270, 420),
                      ("stump", 130, 690), ("fence_broken", 150, 486), ("fence_broken", 232, 490),
                      ("fence", 216, 490), ("fence_broken", 168, 610), ("shrine", 100, 590),
                      ("mushrooms", 112, 368), ("mushrooms", 268, 300), ("mushrooms", 134, 528),
                      ("mushrooms", 246, 692), ("mushrooms", 80, 600), ("bush_dark", 270, 560),
                      ("bush_dark", 110, 470), ("bush_dark", 290, 180)]:
        L.prop(k, x, y)
    for i, (x, y) in enumerate([(100, 476), (288, 572), (84, 660), (292, 336), (96, 168)]):
        L.prop("silhouette", x, y, f"Silhouette{i + 1}")
    scatter(L, "tall_grass_dark", [(100, 200, 280, 400), (140, 520, 240, 720)], 18, 5,
            avoid=[(170, 180, 214, 736)])
    L.player(192, 716)
    L.npc("Sentinel", 192, 426, "sentinel", "sentinel", facing="down", spectral=True,
          present_when="!passed_sentinel", face_player=False, talk_prompt="Speak")
    L.echo("SentinelEcho", 192, 426, "sentinel", "sentinel_echo",
           atlas=(CH + "tobin.png", (0, 0, 16, 24)), r=26, hidden_when="passed_sentinel",
           reveal_offset=V2(-28, -30), hint_offset=V2(0, -46))
    L.interact("ShrineLook", 100, 594, "path_shrine", r=12, prompt_offset=V2(0, -38))
    L.echo("ShrineEcho", 100, 594, "shrine", "path_shrine_echo", texture=FX + "echo_figure.png", r=16,
           reveal_offset=V2(10, -28), hint_offset=V2(0, -46))
    for i, y in enumerate((360, 296, 232)):
        L.node("Encounter", f"MistPulse{i + 1}", "Node2D", 192, y, script_path="res://scripts/systems/mist_pulse.gd",
               width=176.0, phase=float(i) * 0.85)
    L.trigger("SentinelApproach", 192, 474, 96, 12, conversation_id="sentinel_first", once_flag="met_sentinel")
    L.exit("ToVillage", 192, 734, 80, 8, "village", "from_path")
    L.exit("ToTower", 192, 158, 28, 8, "bell_tower", "from_path", requires="passed_sentinel")
    L.spawn("default", 192, 690, "up")
    L.spawn("from_village", 192, 712, "up")
    L.spawn("from_tower", 192, 176, "down")
    L.spawn("challenge_start", 192, 404, "up")
    L.spawn("challenge_retreat", 192, 458, "up")
    L.ambient = Col(0.42, 0.5, 0.6)
    L.light("TowerSlit", 196, 52, "#7ad0ff", 0.5, 0.5, flicker=False)
    L.light("TowerSlit2", 196, 88, "#7ad0ff", 0.4, 0.4, flicker=False)
    L.light("SentinelLight", 192, 400, "#8ad8ff", 0.7, 0.9, flicker=True)
    L.particles("Motes", 192, 420, amount=16, lifetime=4.0, emission_shape=3, emission_rect_extents=(40.0, 30.0),
                direction=(0.0, -1.0), spread=40.0, gravity=(0.0, -4.0), initial_velocity_min=2.0,
                initial_velocity_max=6.0, texture="mote", color=Col("#9ae0ff"),
                ramp=[(0.0, (1, 1, 1, 0)), (0.3, (1, 1, 1, 0.8)), (1.0, (1, 1, 1, 0))])
    L.particles("Leaves", 192, 360, amount=10, lifetime=8.0, emission_shape=3, emission_rect_extents=(170.0, 340.0),
                direction=(1.0, 0.4), spread=30.0, gravity=(2.0, 4.0), initial_velocity_min=4.0,
                initial_velocity_max=9.0, texture="leaf", additive=False, color=Col("#6a5a40"),
                ramp=[(0.0, (1, 1, 1, 0)), (0.2, (1, 1, 1, 1)), (1.0, (1, 1, 1, 0))])
    L.mist = {"density": 0.5, "edge_only": False, "tint": "#a9c2cc"}
    return L


# ============================================================ bell tower ===
def bell_tower():
    L = Level("BellTower", "bell_tower", 20, 16, "res://scripts/world/bell_tower.gd", seed=19,
              display_name="The Bell Tower", music="tower", ambience="tower_wind", reverb=0.75,
              footstep_surface="wood")
    L.fill("cap:tower")
    L.rect(1, 1, 18, 1, "face:tower:upper")
    L.rect(1, 2, 18, 2, "face:tower:lower")
    L.rect(1, 3, 18, 14, "plank")
    L.prop("window_arch", 48, 46, "WindowW")
    L.prop("window_arch", 272, 46, "WindowE")
    L.prop("bell_yoke", 160, 56, "Yoke")
    L.prop("chains", 112, 96, "ChainL")
    L.prop("chains", 208, 96, "ChainR")
    L.prop("bell", 160, 118, "Bell")
    L.prop("pillar", 72, 132, "PillarW")
    L.prop("pillar", 268, 132, "PillarE")
    L.prop("mechanism", 224, 168, "Mechanism")
    L.prop("desk", 62, 212, "Desk")
    L.prop("chair", 92, 206, "Chair")
    L.prop("candle_stand", 34, 208, "Candle")
    L.decal("stairs_down", 160, 252, "Stairs")
    L.decal("papers", 120, 230)
    L.player(160, 222)
    L.npc("Orin", 160, 156, "orin", "orin_after", facing="down", spectral=True, present_when="orin_appeared")
    L.interact("MechanismUse", 224, 172, "tower_mechanism", r=14, prompt_offset=V2(0, -50),
               hidden_when="orin_appeared")
    L.interact("BellLook", 160, 124, "tower_bell", r=16, prompt_offset=V2(0, -70), hidden_when="orin_appeared")
    L.echo("BellEcho", 160, 124, "tower_memories", "tower_memories_echo", texture=FX + "echo_crowd.png", r=24,
           hidden_when="orin_appeared", reveal_offset=V2(-48, -96), hint_offset=V2(0, -84))
    L.interact("DeskRead", 62, 216, "tower_desk", "Read", r=12, prompt_offset=V2(0, -30))
    L.interact("ChairLook", 92, 210, "tower_chair", r=8)
    L.interact("WindowLook", 48, 58, "tower_window", "Look", r=12, prompt_offset=V2(0, -46))
    L.exit("ToPath", 160, 246, 24, 10, "mist_path", "from_tower")
    L.spawn("default", 160, 222, "up")
    L.spawn("from_path", 160, 222, "up")
    L.ambient = Col(0.32, 0.35, 0.5)
    L.light("BellGlow", 160, 100, "#6ad0ff", 0.9, 1.25, flicker=False)
    L.shaft("MoonW", 48, 36, -14, 1.1, 1.9, "#9ab8ff", 0.11)
    L.shaft("MoonE", 272, 36, 14, 1.1, 1.9, "#9ab8ff", 0.11)
    L.particles("Dust", 160, 150, amount=26, lifetime=9.0, emission_shape=3, emission_rect_extents=(140.0, 90.0),
                direction=(0.0, 1.0), spread=180.0, gravity=(0.0, 0.6), initial_velocity_min=1.0,
                initial_velocity_max=3.0, texture="px1", color=Col("#d8e0ff"),
                ramp=[(0.0, (1, 1, 1, 0)), (0.4, (1, 1, 1, 0.5)), (1.0, (1, 1, 1, 0))])
    L.particles("BellMotes", 160, 100, amount=18, lifetime=3.2, emission_shape=3, emission_rect_extents=(26.0, 12.0),
                direction=(0.0, -1.0), spread=60.0, gravity=(0.0, -6.0), initial_velocity_min=3.0,
                initial_velocity_max=8.0, texture="mote", color=Col("#8ae0ff"),
                ramp=[(0.0, (1, 1, 1, 0)), (0.3, (1, 1, 1, 0.9)), (1.0, (1, 1, 1, 0))])
    return L


def build_all():
    out = {}
    for fn, rel in ((village, "scenes/world/village.tscn"), (forge, "scenes/world/forge.tscn"),
                    (chapel, "scenes/world/chapel.tscn"), (mist_path, "scenes/world/mist_path.tscn"),
                    (bell_tower, "scenes/world/bell_tower.tscn")):
        L = fn()
        out[rel] = L.build(rel)
    return out


if __name__ == "__main__":
    for k, v in build_all().items():
        print(k, "ground/overlay cells:", v)
