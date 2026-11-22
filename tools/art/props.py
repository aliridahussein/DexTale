"""Prop sprites (buildings, furniture, nature, the bell...) + manifest.

Every prop has an origin = the pixel that sits on the node origin (its base,
used for Y-sorting) and an optional collision rectangle relative to it.
"""
from __future__ import annotations

import json
import math
import os
import numpy as np

from px import Canvas, C, PAL, mix, darken, lighten, dither, smooth_noise, ROOT

MANIFEST: dict = {}


def register(name, frames, origin, collide=None, light=None, fps=0.0, ysort=True, extra=None):
    if isinstance(frames, Canvas):
        frames = [frames]
    w, h = frames[0].w, frames[0].h
    sheet = Canvas(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.blit(f, i * w, 0)
    sheet.save(f"assets/sprites/props/{name}.png")
    MANIFEST[name] = {
        "png": f"res://assets/sprites/props/{name}.png",
        "size": [w, h], "frames": len(frames), "fps": fps,
        "origin": list(origin), "collide": list(collide) if collide else None,
        "light": light, "ysort": ysort,
    }
    if extra:
        MANIFEST[name].update(extra)


# ======================================================== shared helpers ===
def shingles(cv: Canvas, mask, tones, rowh=3, tab=4, slope=None, seed=0):
    """Fill mask with shingle rows. slope(x,y)->row coordinate (default: y)."""
    rng = np.random.default_rng(seed)
    h, w = mask.shape
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            v = y if slope is None else slope(x, y)
            row = int(math.floor(v / rowh))
            within = v - row * rowh
            seg = int(math.floor((x + (row % 2) * (tab // 2)) / tab))
            col = tones[2]
            if within < 1:
                col = tones[0]  # shadow line under the row above
            elif within < 2:
                col = tones[3] if (seg + row) % 3 == 0 else tones[2]
            if (x + (row % 2) * (tab // 2)) % tab == 0 and within >= 1:
                col = tones[1]
            if rng.random() < 0.05:
                col = tones[1]
            cv.px(x, y, col)


def timber_wall(cv: Canvas, x0, y0, w, h, plaster=("pl1", "pl2", "pl3"), beam=("wd1", "wd2"), seed=0, braces=True):
    rng = np.random.default_rng(seed)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            v = rng.random()
            cv.px(x, y, plaster[1] if v < 0.8 else (plaster[2] if v < 0.93 else plaster[0]))
    cv.rect(x0, y0, w, 2, beam[0])            # top plate
    cv.rect(x0, y0 + h // 2, w, 2, beam[1])   # middle rail
    cv.hline(x0, y0 + h // 2 + 1, w, beam[0])
    step = 14
    for x in range(x0, x0 + w, step):
        cv.rect(x, y0, 2, h, beam[1])
        cv.vline(x + 1, y0, h, beam[0])
    cv.rect(x0 + w - 2, y0, 2, h, beam[0])
    if braces:
        for i, x in enumerate(range(x0, x0 + w - step, step)):
            if i % 2 == 0:
                cv.line(x + 2, y0 + h // 2 - 1, x + step - 1, y0 + 2, beam[1])
            else:
                cv.line(x + 2, y0 + 2, x + step - 1, y0 + h // 2 - 1, beam[1])


def stone_wall(cv: Canvas, x0, y0, w, h, tones=("st0", "st1", "st2", "st3"), bw=6, bh=4, seed=0, moss=0.0):
    rng = np.random.default_rng(seed)
    cv.rect(x0, y0, w, h, tones[0])
    for row, y in enumerate(range(y0, y0 + h, bh)):
        off = (row % 2) * (bw // 2)
        for x in range(x0 - bw + off, x0 + w, bw):
            bwid = bw - 1 + int(rng.integers(-1, 2))
            col = tones[2] if rng.random() < 0.6 else tones[1]
            for yy in range(y, min(y + bh - 1, y0 + h)):
                for xx in range(max(x, x0), min(x + bwid, x0 + w)):
                    cv.px(xx, yy, col)
            for xx in range(max(x, x0), min(x + bwid, x0 + w)):
                if y < y0 + h:
                    cv.px(xx, y, tones[3])
            if moss and rng.random() < moss:
                cv.px(max(x, x0) + 1, min(y + bh - 2, y0 + h - 1), "gr2")


def window(cv: Canvas, x, y, w=6, h=7, lit=True, frame="wd1", arch=False, box=True):
    cv.rect(x - 1, y - 1, w + 2, h + 2, frame)
    glass = ("fi3", "fi4") if lit else ("bl0", "bl1")
    for yy in range(h):
        for xx in range(w):
            cv.px(x + xx, y + yy, glass[1] if (yy < h // 2 and xx < w // 2 + 1) else glass[0])
    cv.vline(x + w // 2, y, h, frame)
    cv.hline(x, y + h // 2, w, frame)
    if arch:
        cv.px(x, y, frame)
        cv.px(x + w - 1, y, frame)
    if box:  # flower box under the window
        cv.rect(x - 1, y + h + 1, w + 2, 2, "wd2")
        for xx in range(w + 2):
            if xx % 2 == 0:
                cv.px(x - 1 + xx, y + h, ["flw4", "flw2", "flw3", "flw1"][xx % 4])
            else:
                cv.px(x - 1 + xx, y + h, "gr3")


def door(cv: Canvas, x, y, w=8, h=12, col=("wd1", "wd2", "wd3"), glow=False, arch=True):
    cv.rect(x - 1, y - 1, w + 2, h + 1, "wd0")
    for yy in range(h):
        for xx in range(w):
            cv.px(x + xx, y + yy, col[1] if xx % 3 else col[0])
    cv.hline(x, y + 2, w, col[0])
    cv.hline(x, y + h - 3, w, col[0])
    cv.px(x + w - 2, y + h // 2, "go2")
    if arch:
        cv.px(x, y, "wd0")
        cv.px(x + w - 1, y, "wd0")
    if glow:
        for xx in range(w):
            cv.px(x + xx, y + h - 1, "fi3")
    cv.rect(x - 2, y + h, w + 4, 1, "st2")  # doorstep


def soft_shadow(cv: Canvas, cx, cy, rx, ry, alpha=90):
    for y in range(cv.h):
        for x in range(cv.w):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1.0 and cv.a[y, x, 3] == 0:
                cv.a[y, x] = (8, 10, 16, int(alpha * (1.0 - d * 0.6)))


def foliage(cv: Canvas, cx, cy, rx, ry, seed, tones=("lf0", "lf1", "lf2", "lf3", "lf4"), puffs=11):
    rng = np.random.default_rng(seed)
    blobs = []
    for _ in range(puffs):
        a = rng.random() * math.tau
        r = math.sqrt(rng.random())
        bx = cx + math.cos(a) * rx * 0.62 * r
        by = cy + math.sin(a) * ry * 0.62 * r
        br = (rx + ry) * 0.5 * (0.32 + rng.random() * 0.18)
        blobs.append((bx, by, br))
    blobs.sort(key=lambda b: b[1])
    for (bx, by, br) in blobs:
        m = cv.ellipse_mask(bx, by, br, br * 0.92)
        cv.a[m] = C(tones[1])
        inner = cv.ellipse_mask(bx - br * 0.15, by - br * 0.2, br * 0.82, br * 0.72)
        cv.a[inner & m] = C(tones[2])
        hl = cv.ellipse_mask(bx - br * 0.35, by - br * 0.42, br * 0.48, br * 0.36)
        cv.a[hl & m] = C(tones[3])
        tip = cv.ellipse_mask(bx - br * 0.45, by - br * 0.55, br * 0.2, br * 0.16)
        cv.a[tip & m] = C(tones[4])
    # dark rim on lower-right
    full = cv.mask()
    res = cv.a.copy()
    for y in range(cv.h):
        for x in range(cv.w):
            if full[y, x] and (y + 1 >= cv.h or not full[y + 1, x] or x + 1 >= cv.w or not full[y, x + 1]):
                res[y, x] = C(tones[0])
    cv.a = res


# =============================================================== nature ===
def tree_oak(seed=1, dark=False):
    w, h = 44, 56
    cv = Canvas(w, h)
    soft_shadow(cv, 22, 52, 15, 4)
    trunk = "wd2" if not dark else "wd1"
    cv.rect(19, 34, 6, 19, trunk)
    cv.vline(19, 34, 19, "wd3" if not dark else "wd2")
    cv.vline(24, 34, 19, "wd0")
    cv.px(18, 51, trunk)
    cv.px(25, 51, "wd0")
    cv.px(17, 52, "wd1")
    cv.px(26, 52, "wd0")
    tones = ("lf0", "lf1", "lf2", "lf3", "lf4") if not dark else ("lf0", "lf0", "lf1", "lf2", "lf3")
    foliage(cv, 22, 22, 20, 19, seed, tones, puffs=13)
    cv.outline("ink")
    return cv


def tree_pine(seed=2, dark=False):
    w, h = 30, 52
    cv = Canvas(w, h)
    soft_shadow(cv, 15, 48, 11, 3)
    cv.rect(13, 38, 4, 11, "wd1")
    cv.vline(13, 38, 11, "wd2")
    tones = ("lf0", "lf1", "lf2", "lf3") if not dark else ("lf0", "lf0", "lf1", "lf2")
    tiers = [(4, 9), (12, 11), (21, 13), (30, 14)]
    rng = np.random.default_rng(seed)
    for (top, half) in tiers:
        hgt = 12
        for yy in range(hgt):
            span = int(half * (yy + 2) / (hgt + 1))
            y = top + yy
            for x in range(15 - span, 15 + span + 1):
                t = (x - (15 - span)) / max(1, 2 * span)
                c = tones[3] if t < 0.3 else (tones[2] if t < 0.7 else tones[1])
                if yy == hgt - 1 or (yy > hgt - 3 and rng.random() < 0.3):
                    c = tones[0]
                cv.px(x, y, c)
    cv.px(15, 2, tones[3])
    cv.px(15, 3, tones[2])
    cv.outline("ink")
    return cv


def tree_dead(seed=3):
    w, h = 36, 52
    cv = Canvas(w, h)
    soft_shadow(cv, 18, 49, 10, 3)
    cv.rect(16, 22, 5, 27, "#3a3034")
    cv.vline(16, 22, 27, "#54484a")
    branches = [((18, 24), (6, 10)), ((18, 26), (30, 8)), ((18, 30), (4, 22)), ((19, 28), (31, 20)),
                ((10, 15), (8, 4)), ((26, 13), (28, 2)), ((18, 22), (17, 3))]
    for (a, b) in branches:
        cv.line(a[0], a[1], b[0], b[1], "#3a3034")
        cv.line(a[0] + 1, a[1], b[0] + 1, b[1], "#2a2226")
    cv.outline("ink")
    return cv


def bush(seed=4, flowers=False, dark=False):
    cv = Canvas(20, 16)
    soft_shadow(cv, 10, 14, 9, 2)
    tones = ("lf0", "lf1", "lf2", "lf3", "lf4") if not dark else ("lf0", "lf0", "lf1", "lf2", "lf3")
    foliage(cv, 10, 8, 9, 6, seed, tones, puffs=6)
    if flowers:
        rng = np.random.default_rng(seed)
        for _ in range(5):
            x, y = rng.integers(3, 17), rng.integers(3, 11)
            if cv.opaque(x, y):
                cv.px(x, y, ["flw2", "flw1", "flw4"][rng.integers(0, 3)])
    cv.outline("ink")
    return cv


def rock(w=14, h=10, seed=5, large=False):
    cv = Canvas(w, h)
    rng = np.random.default_rng(seed)
    cv.ellipse(w / 2, h / 2 + 1, w / 2 - 1, h / 2 - 1, "st2")
    cv.ellipse(w / 2 - 1, h / 2, w / 2 - 3, h / 2 - 3, "st3")
    cv.ellipse(w / 2 - 2, h / 2 - 1, w / 4, h / 5, "st4")
    for _ in range(3 if not large else 6):
        x, y = rng.integers(2, w - 2), rng.integers(h // 2, h - 2)
        if cv.opaque(x, y):
            cv.px(x, y, "gr2")
    cv.outline("ink")
    return cv


def stump():
    cv = Canvas(14, 12)
    cv.rect(3, 4, 8, 6, "wd2")
    cv.vline(3, 4, 6, "wd3")
    cv.vline(10, 4, 6, "wd1")
    cv.ellipse(7, 4, 4, 2, "wd4")
    cv.px(7, 4, "wd2")
    cv.px(2, 9, "wd2")
    cv.px(11, 9, "wd1")
    cv.outline("ink")
    return cv


def mushrooms():
    frames = []
    for glow in (0, 1):
        cv = Canvas(12, 10)
        for (x, y, r) in ((3, 5, 2), (8, 4, 2.5), (6, 7, 1.5)):
            cv.vline(int(x), int(y), 4, "cr1")
            cv.ellipse(x + 0.5, y, r, r * 0.7, "sp2" if not glow else "sp3")
            cv.px(int(x), int(y - 1), "sp4")
        cv.outline("ink")
        frames.append(cv)
    return frames


def tall_grass(seed=6, dark=False):
    cv = Canvas(10, 9)
    rng = np.random.default_rng(seed)
    tones = ("gr1", "gr2", "gr3", "gr4") if not dark else ("gr0", "gr1", "gr2", "gr2")
    for i in range(7):
        x = 1 + i + int(rng.integers(0, 2))
        hgt = int(rng.integers(4, 8))
        for k in range(hgt):
            cv.px(x - (1 if k > hgt - 3 and i % 2 else 0), 8 - k, tones[min(3, k // 2)])
    return cv


# ============================================================ buildings ===
def house_side_gable(w, wall_h, roof_h, seed, roof="rf", windows=(), door_x=None, chimney=None,
                     lit=True, stone_base=True):
    """Generic cottage: roof seen from above (rows parallel to the eave) + timber front wall."""
    h = roof_h + wall_h + 4
    cv = Canvas(w + 4, h)
    tones = [f"{roof}0", f"{roof}1", f"{roof}2", f"{roof}3"]
    soft_shadow(cv, (w + 4) / 2, h - 2, (w + 4) / 2, 3, alpha=80)
    wall_top = roof_h
    timber_wall(cv, 2, wall_top, w, wall_h, seed=seed)
    if stone_base:
        stone_wall(cv, 2, wall_top + wall_h - 4, w, 4, tones=("st0", "st1", "st2", "st3"), bw=5, bh=4, seed=seed)
    roof_mask = cv.poly_mask([(0, roof_h + 1), (w + 4, roof_h + 1), (w + 1, 3), (3, 3)])
    shingles(cv, roof_mask, tones, seed=seed, slope=lambda x, y: (roof_h + 1) - y)
    cv.hline(3, 2, w - 2, f"{roof}3")  # ridge cap
    cv.hline(0, roof_h + 1, w + 4, f"{roof}0")
    cv.hline(1, roof_h + 2, w + 2, "ink2")  # eave shadow on the wall
    for (wx, wy) in windows:
        window(cv, 2 + wx, wall_top + wy, lit=lit)
    if door_x is not None:
        door(cv, 2 + door_x, wall_top + wall_h - 13, glow=lit)
    if chimney:
        cx, cw, ch = chimney
        stone_wall(cv, cx, 0, cw, ch, bw=4, bh=3, seed=seed + 1)
        cv.hline(cx - 1, 0, cw + 2, "st3")
        cv.rect(cx + 1, 1, cw - 2, 1, "ink")
    cv.outline("ink")
    return cv


def house_front_gable(w, wall_h, seed, roof="rf", depth=26, windows=(), door_x=None, lit=True,
                      upper_window=True, plaster=("pl1", "pl2", "pl3")):
    """Front-gable house like a tavern: two roof planes + timbered gable."""
    gable = int(w * 0.42)
    h = depth + gable + wall_h + 4
    W = w + 8
    cv = Canvas(W, h)
    soft_shadow(cv, W / 2, h - 2, W / 2, 3, alpha=80)
    x0 = 4
    eave_y = depth + gable
    apex = (x0 + w / 2, depth)
    tones = [f"{roof}0", f"{roof}1", f"{roof}2", f"{roof}3"]
    # front wall
    timber_wall(cv, x0, eave_y, w, wall_h, plaster=plaster, seed=seed)
    stone_wall(cv, x0, eave_y + wall_h - 4, w, 4, bw=5, bh=4, seed=seed)
    # gable triangle (timbered)
    tri = cv.poly_mask([(x0, eave_y + 1), (apex[0], apex[1] + 2), (x0 + w, eave_y + 1)])
    rng = np.random.default_rng(seed)
    for y in range(h):
        for x in range(W):
            if tri[y, x]:
                cv.px(x, y, plaster[1] if rng.random() < 0.85 else plaster[2])
    cv.vline(int(apex[0]), int(apex[1]) + 2, eave_y - int(apex[1]) - 1, "wd1")
    cv.line(x0 + 4, eave_y - 1, int(apex[0]) - 1, int(apex[1]) + 8, "wd2")
    cv.line(x0 + w - 4, eave_y - 1, int(apex[0]) + 1, int(apex[1]) + 8, "wd2")
    cv.hline(x0, eave_y, w, "wd1")
    if upper_window:
        window(cv, int(apex[0]) - 3, eave_y - 12, w=7, h=7, lit=lit, box=False)
    # roof planes (left/right) seen from above, rows parallel to the eaves
    lp = [(x0 - 4, eave_y + 2), (apex[0], apex[1]), (apex[0], apex[1] - depth), (x0 - 4, eave_y + 2 - depth)]
    rp = [(x0 + w + 4, eave_y + 2), (apex[0], apex[1]), (apex[0], apex[1] - depth), (x0 + w + 4, eave_y + 2 - depth)]
    lm = cv.poly_mask(lp)
    rm = cv.poly_mask(rp)
    run = apex[0] - (x0 - 4)
    rise = (eave_y + 2) - apex[1]
    shingles(cv, lm, tones, seed=seed, slope=lambda x, y: (eave_y + 2 - (x - (x0 - 4)) * rise / run) - y)
    rtones = [tones[0], tones[0], tones[1], tones[2]]
    shingles(cv, rm, rtones, seed=seed + 3, slope=lambda x, y: (eave_y + 2 - ((x0 + w + 4) - x) * rise / run) - y)
    # eave edges + ridge
    cv.line(x0 - 4, eave_y + 2, int(apex[0]), int(apex[1]), tones[0])
    cv.line(x0 + w + 4, eave_y + 2, int(apex[0]), int(apex[1]), tones[0])
    cv.vline(int(apex[0]), int(apex[1] - depth), depth + 1, tones[3])
    for (wx, wy) in windows:
        window(cv, x0 + wx, eave_y + wy, lit=lit)
    if door_x is not None:
        door(cv, x0 + door_x, eave_y + wall_h - 13, glow=lit)
    cv.outline("ink")
    return cv


def chapel_ext():
    w, wall_h = 72, 30
    cv = house_front_gable(w, wall_h, seed=31, roof="sl", depth=30, windows=(), door_x=None, lit=False,
                           upper_window=False, plaster=("st2", "st3", "st4"))
    W = cv.w
    x0 = 4
    eave_y = 30 + int(w * 0.42)
    # re-skin the wall as stone
    stone_wall(cv, x0, eave_y + 1, w, wall_h - 1, tones=("st1", "st2", "st3", "st4"), bw=8, bh=5, seed=7, moss=0.15)
    # rose window in the gable
    cx, cy = x0 + w // 2, eave_y - 11
    cv.ellipse(cx + 0.5, cy + 0.5, 7, 7, "st0")
    cv.ellipse(cx + 0.5, cy + 0.5, 6, 6, "vi2")
    for a in range(8):
        ang = a * math.pi / 4
        cv.line(cx, cy, cx + int(round(math.cos(ang) * 5)), cy + int(round(math.sin(ang) * 5)), "st0")
    for (dx, dy, c) in ((-3, -3, "rd2"), (3, -3, "bl2"), (-3, 3, "go2"), (3, 3, "te2"), (0, -5, "go3"), (0, 5, "rd2")):
        cv.px(cx + dx, cy + dy, c)
    cv.px(cx, cy, "go3")
    # arched double door
    dx, dy = x0 + w // 2 - 7, eave_y + wall_h - 18
    cv.rect(dx - 2, dy - 2, 18, 20, "st1")
    cv.rect(dx, dy, 14, 18, "wd2")
    cv.vline(dx + 7, dy, 18, "wd0")
    for yy in (dy + 4, dy + 12):
        cv.hline(dx, yy, 14, "ir2")
    cv.px(dx, dy, "st1")
    cv.px(dx + 13, dy, "st1")
    cv.px(dx + 1, dy, "st1")
    cv.px(dx + 12, dy, "st1")
    cv.px(dx + 5, dy + 9, "go2")
    cv.px(dx + 8, dy + 9, "go2")
    # lancet windows either side
    for lx in (x0 + 8, x0 + w - 14):
        cv.rect(lx - 1, eave_y + 5, 7, 15, "st0")
        cv.rect(lx, eave_y + 6, 5, 13, "vi2")
        cv.vline(lx + 2, eave_y + 6, 13, "st0")
        cv.px(lx + 1, eave_y + 8, "rd2")
        cv.px(lx + 3, eave_y + 11, "bl2")
        cv.px(lx + 1, eave_y + 14, "go2")
        cv.px(lx, eave_y + 6, "st0")
        cv.px(lx + 4, eave_y + 6, "st0")
    # empty bell-cote on the ridge
    bx = x0 + w // 2 - 5
    cv.rect(bx, 0, 11, 12, "st2")
    cv.rect(bx + 2, 3, 7, 7, "void")
    cv.hline(bx - 1, 0, 13, "sl3")
    cv.px(bx + 5, 4, "ir2")  # a hook where the chapel bell once hung
    cv.outline("ink")
    return cv


def forge_ext():
    w, wall_h, roof_h = 70, 30, 26
    cv = house_side_gable(w, wall_h, roof_h, seed=41, roof="rf", windows=((50, 9),), door_x=None,
                          chimney=(8, 9, 20), lit=True)
    wall_top = roof_h
    # lower walls in stone, timber above
    stone_wall(cv, 2, wall_top + 12, w, wall_h - 12, tones=("cb0", "cb1", "cb2", "cb3"), bw=6, bh=4, seed=9)
    # big open doorway with warm glow
    dx, dy = 20, wall_top + wall_h - 19
    cv.rect(dx - 2, dy - 2, 22, 21, "wd1")
    for yy in range(19):
        for xx in range(18):
            t = yy / 19
            c = mix("fi1", "fi3", t * 0.8)
            if dither(xx, yy, 0.3 + t * 0.5):
                c = mix(c, "fi4", 0.3)
            cv.px(dx + xx, dy + yy, c)
    cv.rect(dx, dy, 18, 3, "wd0")
    # silhouette of the anvil inside
    cv.rect(dx + 5, dy + 12, 8, 2, "ink2")
    cv.rect(dx + 7, dy + 14, 4, 4, "ink2")
    # hanging sign: anvil
    sx, sy = dx + 24, wall_top + 2
    cv.hline(sx, sy, 10, "ir2")
    cv.vline(sx + 2, sy, 3, "ir2")
    cv.vline(sx + 8, sy, 3, "ir2")
    cv.rect(sx, sy + 3, 11, 7, "wd3")
    cv.rect(sx + 2, sy + 5, 7, 2, "ir1")
    cv.rect(sx + 4, sy + 7, 3, 2, "ir1")
    # horseshoes on the wall
    for hx in (8, 13):
        cv.px(hx, wall_top + 16, "ir3")
        cv.px(hx + 2, wall_top + 16, "ir3")
        cv.hline(hx, wall_top + 18, 3, "ir3")
        cv.px(hx, wall_top + 17, "ir3")
        cv.px(hx + 2, wall_top + 17, "ir3")
    cv.outline("ink")
    return cv


def tower_distant():
    """The bell tower seen far beyond the north wall (cool, low contrast)."""
    w, h = 48, 132
    cv = Canvas(w, h)
    body = ("#2c3446", "#3a4458", "#4a5670", "#5c6a84")
    x0, top = 12, 40
    stone_wall(cv, x0, top, 24, h - top, tones=body, bw=6, bh=5, seed=12)
    # belfry with arches + the bell silhouette
    cv.rect(x0 - 2, top - 26, 28, 28, body[1])
    stone_wall(cv, x0 - 2, top - 26, 28, 28, tones=body, bw=7, bh=5, seed=13)
    for ax in (x0 + 2, x0 + 13):
        cv.rect(ax, top - 21, 7, 16, "#121826")
        cv.px(ax, top - 21, body[1])
        cv.px(ax + 6, top - 21, body[1])
    cv.ellipse(x0 + 12, top - 12, 6, 5, "#20283a")
    cv.rect(x0 + 6, top - 12, 12, 6, "#20283a")
    cv.px(x0 + 12, top - 7, "sp2")
    cv.px(x0 + 11, top - 7, "sp1")
    # spire
    cv.poly([(x0 - 4, top - 25), (x0 + 12, 0), (x0 + 28, top - 25)], "#252a3a")
    sp = cv.poly_mask([(x0 - 4, top - 25), (x0 + 12, 0), (x0 + 28, top - 25)])
    shingles(cv, sp, ("#1a1e2a", "#22283a", "#2e3650", "#3c4664"), seed=3)
    cv.hline(x0 - 5, top - 25, 34, "#3c4664")
    # tiny lit slit window
    cv.rect(x0 + 11, top + 20, 2, 4, "#5a6a88")
    cv.outline("#141824")
    return cv


def well():
    w, h = 34, 46
    cv = Canvas(w, h)
    soft_shadow(cv, 17, 42, 15, 3)
    # stone drum (3/4 view)
    cy = 30
    stone_wall(cv, 4, cy, 26, 12, tones=("st0", "st1", "st2", "st3"), bw=5, bh=4, seed=21, moss=0.2)
    for x in range(4, 30):  # round off the bottom
        t = (x - 17) / 13
        dip = int(round(2 * (1 - t * t)))
        for k in range(dip):
            cv.px(x, cy + 12 + k, cv.get(x, cy + 11 - k) if False else "st1")
    cv.ellipse(17, cy, 13, 5, "st3")
    cv.ellipse(17, cy, 11, 3.6, "st1")
    cv.ellipse(17, cy + 0.6, 10, 3, "wa1")
    cv.ellipse(15, cy, 4, 1.2, "wa3")
    # posts + little roof
    for px_ in (5, 28):
        cv.rect(px_, 8, 2, cy - 8, "wd2")
        cv.vline(px_, 8, cy - 8, "wd3")
    cv.hline(6, 14, 22, "wd1")  # crank axle
    cv.rect(16, 13, 3, 3, "wd3")
    cv.vline(17, 16, 9, "cr0")  # rope
    cv.rect(15, 24, 5, 4, "wd2")  # bucket
    cv.hline(15, 24, 5, "ir2")
    cv.px(29, 13, "ir3")
    cv.px(30, 12, "ir3")
    roof = cv.poly_mask([(1, 10), (17, 1), (33, 10)])
    shingles(cv, roof, ("rf0", "rf1", "rf2", "rf3"), seed=4, rowh=2, tab=3)
    cv.line(1, 10, 17, 1, "rf0")
    cv.line(33, 10, 17, 1, "rf0")
    # carved names on the drum (tiny marks; readable via interaction)
    cv.px(9, cy + 7, "st0")
    cv.px(10, cy + 7, "st0")
    cv.px(12, cy + 7, "st0")
    cv.px(13, cy + 6, "st0")
    cv.outline("ink")
    return cv


def lantern_post():
    frames = []
    for f in range(3):
        cv = Canvas(12, 34)
        soft_shadow(cv, 6, 32, 4, 1.5)
        cv.rect(5, 8, 2, 25, "ir2")
        cv.vline(5, 8, 25, "ir3")
        cv.rect(4, 31, 4, 2, "ir1")
        cv.hline(3, 6, 6, "ir2")
        cv.px(8, 7, "ir2")
        # lantern box hanging from the arm
        cv.rect(2, 7, 1, 2, "ir2")
        lx, ly = 0, 9
        cv.rect(lx, ly, 6, 1, "ir1")
        cv.rect(lx, ly + 7, 6, 1, "ir1")
        glow = [("fi3", "fi4"), ("fi2", "fi4"), ("fi3", "fi5")][f]
        cv.rect(lx + 1, ly + 1, 4, 6, glow[0])
        cv.rect(lx + 2, ly + 2, 2, 3 + (f % 2), glow[1])
        cv.vline(lx, ly + 1, 6, "ir2")
        cv.vline(lx + 5, ly + 1, 6, "ir1")
        cv.px(lx + 2, ly - 1, "ir2")
        cv.px(lx + 3, ly - 1, "ir2")
        cv.outline("ink")
        frames.append(cv)
    return frames


def wall_lantern():
    frames = []
    for f in range(3):
        cv = Canvas(8, 12)
        cv.rect(2, 2, 5, 1, "ir1")
        cv.rect(2, 9, 5, 1, "ir1")
        glow = [("fi3", "fi4"), ("fi2", "fi4"), ("fi3", "fi5")][f]
        cv.rect(3, 3, 3, 6, glow[0])
        cv.rect(4, 4, 1, 3, glow[1])
        cv.vline(2, 3, 6, "ir2")
        cv.vline(6, 3, 6, "ir1")
        cv.px(4, 1, "ir2")
        cv.outline("ink")
        frames.append(cv)
    return frames


def market_stall(variant=0):
    w, h = 46, 42
    cv = Canvas(w, h)
    soft_shadow(cv, 23, 39, 22, 3)
    # counter
    cv.rect(3, 26, 40, 12, "wd2")
    cv.rect(3, 26, 40, 3, "wd4")
    cv.hline(3, 29, 40, "wd1")
    for x in range(6, 42, 7):
        cv.vline(x, 30, 8, "wd1")
    # posts
    for px_ in (4, 40):
        cv.rect(px_, 8, 2, 20, "wd2")
    # goods on the counter
    goods = [("apple", "rd1"), ("cabbage", "gr2"), ("pumpkin", "fi1")] if variant == 0 else [("cr1", "cr0"), ("go2", "go1"), ("apple", "rd1")]
    for i, (c1, c2) in enumerate(goods):
        bx = 7 + i * 12
        cv.rect(bx, 22, 10, 5, "wd3")
        cv.hline(bx, 22, 10, "wd4")
        for k in range(5):
            cv.px(bx + 1 + k * 2, 21, c1)
            cv.px(bx + 2 + k * 2, 21, c2)
            cv.px(bx + 1 + k * 2, 20, c1 if k % 2 else c2)
    # striped awning
    stripes = ("rd2", "cr2") if variant == 0 else ("bl2", "cr2")
    aw = cv.poly_mask([(0, 14), (46, 14), (42, 4), (4, 4)])
    for y in range(h):
        for x in range(w):
            if aw[y, x]:
                c = stripes[(x // 5) % 2]
                if y < 6:
                    c = darken(c, 0.8)
                cv.px(x, y, c)
    for x in range(0, 46):
        if (x // 5) % 2 == 0:
            cv.px(x, 15, stripes[0])
            if x % 5 == 2:
                cv.px(x, 16, stripes[0])
    cv.hline(0, 14, 46, darken(stripes[0], 0.6))
    cv.outline("ink")
    return cv


def notice_board():
    cv = Canvas(30, 34)
    soft_shadow(cv, 15, 32, 13, 2)
    for px_ in (3, 25):
        cv.rect(px_, 6, 2, 26, "wd2")
        cv.vline(px_, 6, 26, "wd3")
    cv.rect(1, 8, 28, 16, "wd1")
    cv.rect(2, 9, 26, 14, "wd3")
    roof = cv.poly_mask([(0, 8), (15, 1), (30, 8)])
    shingles(cv, roof, ("rf0", "rf1", "rf2", "rf3"), seed=8, rowh=2, tab=3)
    papers = [(4, 10, 7, 8), (12, 11, 6, 6), (19, 10, 7, 9), (12, 18, 5, 4)]
    for (x, y, pw, ph) in papers:
        cv.rect(x, y, pw, ph, "cr2")
        cv.hline(x, y, pw, "cr3")
        for ly in range(y + 2, y + ph - 1, 2):
            cv.hline(x + 1, ly, pw - 2, "cr0")
        cv.px(x + pw // 2, y, "rd2")
    cv.outline("ink")
    return cv


def signpost():
    cv = Canvas(24, 32)
    soft_shadow(cv, 12, 30, 5, 1.5)
    cv.rect(11, 4, 2, 27, "wd2")
    cv.vline(11, 4, 27, "wd3")
    # arrows: west (forge), east (chapel), north (tower)
    cv.poly([(1, 9), (4, 6), (11, 6), (11, 12), (4, 12)], "wd3")
    cv.poly([(13, 13), (20, 13), (23, 16), (20, 19), (13, 19)], "wd3")
    cv.poly([(9, 3), (12, 0), (15, 3), (15, 5), (9, 5)], "wd4")
    for y in (8, 10):
        cv.hline(5, y, 5, "wd1")
    for y in (15, 17):
        cv.hline(14, y, 5, "wd1")
    cv.outline("ink")
    return cv


def barrel():
    cv = Canvas(14, 17)
    soft_shadow(cv, 7, 15, 6, 1.5)
    cv.rect(2, 3, 10, 11, "wd3")
    cv.vline(2, 3, 11, "wd2")
    cv.vline(11, 3, 11, "wd1")
    for x in (4, 7, 9):
        cv.vline(x, 3, 11, "wd2")
    cv.ellipse(7, 3, 5, 2, "wd2")
    cv.ellipse(7, 3, 4, 1.2, "wd1")
    for y in (5, 11):
        cv.hline(2, y, 10, "ir2")
    cv.rect(3, 14, 8, 1, "wd2")
    cv.outline("ink")
    return cv


def crate(stack=False):
    hgt = 15 if not stack else 25
    cv = Canvas(16, hgt + 2)
    soft_shadow(cv, 8, hgt, 7, 1.5)

    def box(y):
        cv.rect(1, y, 14, 4, "wd4")
        cv.hline(1, y, 14, "wd5")
        cv.rect(1, y + 4, 14, 9, "wd3")
        cv.hline(1, y + 4, 14, "wd2")
        cv.line(2, y + 12, 13, y + 5, "wd2")
        cv.vline(1, y + 4, 9, "wd2")
        cv.vline(14, y + 4, 9, "wd1")
        cv.hline(1, y + 12, 14, "wd1")

    if stack:
        box(12)
        box(2)
    else:
        box(2)
    cv.outline("ink")
    return cv


def sack():
    cv = Canvas(12, 12)
    soft_shadow(cv, 6, 10, 5, 1.5)
    cv.ellipse(6, 7, 4.5, 4, "cr1")
    cv.ellipse(5, 6, 2.5, 2.5, "cr2")
    cv.rect(5, 1, 2, 3, "cr0")
    cv.hline(4, 3, 4, "wd2")
    cv.outline("ink")
    return cv


def flower_pot(variant=0):
    cv = Canvas(12, 13)
    cv.rect(3, 7, 6, 5, "#9a4a32")
    cv.hline(2, 7, 8, "#b8644a")
    cv.vline(8, 8, 4, "#6e3022")
    cols = [("flw4", "flw3"), ("flw2", "flw1"), ("flw3", "flw4")][variant % 3]
    cv.ellipse(6, 5, 4, 2.5, "lf2")
    cv.px(3, 4, cols[0])
    cv.px(6, 3, cols[1])
    cv.px(8, 5, cols[0])
    cv.px(5, 5, cols[1])
    cv.outline("ink")
    return cv


def bench():
    cv = Canvas(26, 12)
    soft_shadow(cv, 13, 10, 12, 1.5)
    cv.rect(1, 3, 24, 4, "wd3")
    cv.hline(1, 3, 24, "wd4")
    cv.hline(1, 6, 24, "wd1")
    for x in (3, 21):
        cv.rect(x, 7, 2, 3, "wd1")
    cv.outline("ink")
    return cv


def hay_bale():
    cv = Canvas(20, 15)
    soft_shadow(cv, 10, 13, 9, 1.5)
    cv.rect(1, 3, 18, 10, "go2")
    cv.rect(1, 3, 18, 3, "go3")
    for x in range(2, 18, 3):
        cv.vline(x, 6, 7, "go1")
    cv.vline(6, 3, 10, "wd2")
    cv.vline(13, 3, 10, "wd2")
    cv.outline("ink")
    return cv


def cart():
    cv = Canvas(36, 26)
    soft_shadow(cv, 18, 23, 16, 2)
    cv.rect(2, 8, 28, 10, "wd3")
    cv.rect(2, 8, 28, 2, "wd4")
    for x in range(5, 30, 6):
        cv.vline(x, 10, 8, "wd2")
    cv.line(30, 14, 35, 12, "wd2")  # handles
    cv.line(30, 16, 35, 15, "wd2")
    for wx in (7, 23):
        cv.ellipse(wx, 19, 5, 5, "wd1")
        cv.ellipse(wx, 19, 3.5, 3.5, "wd2")
        cv.px(wx, 19, "ir2")
    cv.rect(4, 5, 8, 4, "go2")  # some hay in it
    cv.rect(14, 6, 6, 3, "apple")
    cv.outline("ink")
    return cv


def fence(broken=False, seed=0):
    cv = Canvas(16, 14)
    rng = np.random.default_rng(seed)
    for px_ in (1, 13):
        cv.rect(px_, 2, 2, 11, "wd2")
        cv.vline(px_, 2, 11, "wd3")
    for y in (4, 8):
        if broken and y == 4:
            cv.line(3, y, 9, y + 3, "wd3")
            continue
        cv.rect(0, y, 16, 2, "wd3")
        cv.hline(0, y, 16, "wd4")
    cv.outline("ink")
    return cv


def bucket():
    cv = Canvas(9, 9)
    cv.rect(1, 3, 7, 5, "wd3")
    cv.hline(1, 4, 7, "ir2")
    cv.ellipse(4.5, 3, 3.5, 1.2, "wa2")
    cv.outline("ink")
    return cv


def gate_north():
    frames = []
    for state in ("closed", "open"):
        cv = Canvas(64, 40)
        for px_ in (0, 54):
            stone_wall(cv, px_, 4, 10, 34, tones=("st0", "st1", "st2", "st3"), bw=5, bh=4, seed=px_)
            cv.rect(px_ - 1, 2, 12, 3, "st3")
            cv.hline(px_ - 1, 2, 12, "st4")
        if state == "closed":
            for gx in (10, 32):
                cv.rect(gx, 10, 22, 28, "wd2")
                for x in range(gx, gx + 22, 4):
                    cv.vline(x, 10, 28, "wd1")
                for y in (14, 30):
                    cv.hline(gx, y, 22, "ir2")
                    cv.hline(gx, y + 1, 22, "ir1")
            cv.vline(32, 10, 28, "ink")
            # chain + lock stamped with a bell
            cv.rect(30, 21, 5, 5, "ir3")
            cv.px(32, 22, "ir1")
            cv.px(31, 24, "ir1")
            cv.px(33, 24, "ir1")
            cv.line(21, 19, 30, 22, "ir3")
            cv.line(35, 22, 43, 19, "ir3")
        else:
            for gx, d in ((10, 1), (54, -1)):
                for yy in range(28):
                    cv.rect(gx if d > 0 else gx - 4, 10 + yy, 4, 1, "wd2" if yy % 6 else "ir2")
        cv.outline("ink")
        frames.append(cv)
    return frames


# ============================================================= forge ===
def furnace():
    frames = []
    for f in range(3):
        cv = Canvas(52, 54)
        stone_wall(cv, 4, 14, 44, 38, tones=("cb0", "cb1", "cb2", "cb3"), bw=6, bh=5, seed=50)
        # hood
        cv.poly([(2, 16), (50, 16), (40, 0), (12, 0)], "cb1")
        hood = cv.poly_mask([(2, 16), (50, 16), (40, 0), (12, 0)])
        stone_wall(cv, 2, 0, 48, 16, tones=("cb0", "cb1", "cb2", "cb3"), bw=5, bh=4, seed=51)
        cv.a[~hood & (np.arange(54)[:, None] < 16)] = 0
        cv.hline(2, 16, 48, "ink2")
        # glowing mouth
        mx, my, mw, mh = 13, 24, 26, 20
        cv.ellipse(mx + mw / 2, my + 3, mw / 2, 6, "ink2")
        cv.rect(mx, my + 3, mw, mh - 3, "ink2")
        flick = [0.0, 0.15, -0.1][f]
        for y in range(my + 3, my + mh):
            for x in range(mx + 2, mx + mw - 2):
                t = (y - my) / mh + flick
                c = "fi1" if t < 0.45 else ("fi2" if t < 0.7 else "fi3")
                if dither(x + f, y, max(0.0, t - 0.6) * 2):
                    c = "fi4"
                cv.px(x, y, c)
        # coals
        rng = np.random.default_rng(f)
        for _ in range(10):
            x = rng.integers(mx + 3, mx + mw - 3)
            cv.px(x, my + mh - 2, ["fi4", "fi5", "fi3"][rng.integers(0, 3)])
        cv.rect(mx - 2, my + mh, mw + 4, 3, "cb3")
        cv.outline("ink")
        frames.append(cv)
    return frames


def anvil():
    cv = Canvas(22, 18)
    soft_shadow(cv, 11, 16, 9, 2)
    cv.rect(7, 10, 8, 6, "wd2")  # stump
    cv.vline(7, 10, 6, "wd3")
    cv.ellipse(11, 10, 5, 1.5, "wd4")
    cv.rect(3, 4, 16, 3, "ir3")   # face
    cv.hline(3, 4, 16, "ir4")
    cv.poly([(1, 4), (3, 4), (3, 7)], "ir3")  # horn
    cv.rect(7, 7, 8, 3, "ir2")
    cv.rect(6, 9, 10, 1, "ir1")
    cv.outline("ink")
    return cv


def tool_rack():
    cv = Canvas(30, 20)
    cv.rect(1, 2, 28, 3, "wd3")
    cv.hline(1, 2, 28, "wd4")
    for i, x in enumerate(range(4, 28, 6)):
        cv.vline(x, 5, 9 + (i % 2) * 3, "wd2")
        if i % 2 == 0:
            cv.rect(x - 2, 13, 5, 3, "ir3")  # hammer head
        else:
            cv.line(x - 1, 16, x - 2, 18, "ir2")  # tongs
            cv.line(x + 1, 16, x + 2, 18, "ir2")
    cv.outline("ink")
    return cv


def weapon_rack():
    cv = Canvas(32, 30)
    soft_shadow(cv, 16, 28, 14, 2)
    cv.rect(2, 22, 28, 5, "wd2")
    cv.hline(2, 22, 28, "wd4")
    cv.rect(2, 8, 28, 2, "wd3")
    for x in (7, 15, 23):
        cv.vline(x, 1, 21, "ir4")
        cv.vline(x + 1, 1, 21, "ir2")
        cv.hline(x - 2, 17, 6, "go1")
        cv.rect(x, 18, 2, 4, "wd1")
        cv.px(x, 0, "ir4")
    # tiny paper tags
    for x in (5, 13, 21):
        cv.rect(x, 11, 3, 3, "cr2")
    cv.outline("ink")
    return cv


def quench_barrel():
    cv = barrel()
    cv.ellipse(7, 3, 4, 1.2, "wa2")
    cv.px(5, 3, "wa4")
    return cv


def coal_pile():
    cv = Canvas(22, 12)
    soft_shadow(cv, 11, 10, 10, 2)
    rng = np.random.default_rng(9)
    cv.ellipse(11, 7, 9, 4, "ir1")
    for _ in range(25):
        x, y = rng.integers(3, 19), rng.integers(4, 10)
        if cv.opaque(x, y):
            cv.px(x, y, ["ir0", "ir2", "ink2"][rng.integers(0, 3)])
    cv.outline("ink")
    return cv


def workbench():
    cv = Canvas(34, 22)
    soft_shadow(cv, 17, 20, 16, 2)
    cv.rect(1, 4, 32, 6, "wd4")
    cv.hline(1, 4, 32, "wd5")
    cv.rect(1, 10, 32, 3, "wd2")
    for x in (2, 29):
        cv.rect(x, 13, 3, 6, "wd1")
    cv.rect(4, 5, 6, 2, "ir2")   # file
    cv.rect(22, 3, 4, 3, "cb2")  # whetstone
    cv.rect(12, 6, 2, 3, "wd2")
    cv.outline("ink")
    return cv


def tuning_pin_item():
    cv = Canvas(14, 7)
    cv.rect(1, 3, 10, 2, "ir3")
    cv.hline(1, 3, 10, "ir4")
    cv.rect(10, 1, 3, 5, "ir2")
    cv.px(11, 2, "ir4")
    cv.px(4, 4, "go2")  # the faded marking
    cv.outline("ink")
    return cv


def cradle():
    cv = Canvas(20, 15)
    soft_shadow(cv, 10, 13, 9, 2)
    cv.rect(3, 4, 14, 7, "wd3")
    cv.rect(4, 5, 12, 4, "cr1")
    cv.hline(3, 4, 14, "wd4")
    cv.line(2, 12, 6, 10, "wd2")
    cv.line(17, 12, 13, 10, "wd2")
    cv.rect(5, 6, 4, 2, "go2")  # kindling poking out
    cv.rect(10, 6, 3, 2, "wd2")
    cv.outline("ink")
    return cv


def bellows():
    cv = Canvas(22, 13)
    soft_shadow(cv, 11, 11, 10, 2)
    cv.poly([(2, 3), (16, 5), (16, 10), (2, 11)], "wd2")
    cv.rect(4, 4, 10, 6, "#6a4a3a")
    for x in (6, 9, 12):
        cv.vline(x, 4, 6, "#4a3226")
    cv.rect(16, 6, 5, 3, "ir2")
    cv.outline("ink")
    return cv


def shelf_jar():
    cv = Canvas(22, 24)
    cv.rect(1, 2, 20, 20, "wd1")
    cv.rect(2, 3, 18, 18, "wd2")
    cv.rect(2, 11, 18, 2, "wd4")
    cv.rect(2, 19, 18, 2, "wd4")
    # the swear jar
    cv.rect(4, 5, 6, 6, "#9ab4b8")
    cv.rect(5, 8, 4, 3, "go2")
    cv.px(6, 7, "go3")
    cv.hline(4, 4, 6, "wd3")
    cv.rect(13, 6, 5, 5, "cb2")  # pots
    cv.rect(4, 14, 4, 5, "rd1")
    cv.rect(10, 15, 7, 4, "cr1")
    cv.outline("ink")
    return cv


def forge_sign_plaque():
    cv = Canvas(40, 10)
    cv.rect(1, 1, 38, 8, "wd2")
    cv.hline(1, 1, 38, "wd4")
    for i in range(7):
        cv.rect(4 + i * 5, 4, 3, 2, "go2")
    cv.outline("ink")
    return cv


# ============================================================ chapel ===
def pew():
    cv = Canvas(46, 18)
    soft_shadow(cv, 23, 16, 22, 2)
    cv.rect(1, 2, 44, 6, "wd2")      # backrest (seen from behind)
    cv.hline(1, 2, 44, "wd4")
    cv.hline(1, 3, 44, "wd3")
    cv.rect(1, 8, 44, 5, "wd3")      # seat
    cv.hline(1, 8, 44, "wd4")
    cv.rect(1, 13, 44, 2, "wd1")
    cv.rect(0, 1, 3, 15, "wd1")
    cv.rect(43, 1, 3, 15, "wd1")
    cv.outline("ink")
    return cv


def altar():
    frames = []
    for f in range(3):
        cv = Canvas(48, 34)
        soft_shadow(cv, 24, 32, 23, 2)
        cv.rect(2, 14, 44, 18, "st2")
        stone_wall(cv, 2, 18, 44, 14, tones=("st1", "st2", "st3", "st4"), bw=8, bh=5, seed=60)
        cv.rect(1, 12, 46, 6, "vi2")   # altar cloth
        cv.hline(1, 12, 46, "vi3")
        cv.rect(18, 18, 12, 10, "vi2")
        cv.rect(20, 18, 8, 10, "vi1")
        cv.hline(18, 27, 12, "go2")
        # a small bell-shaped emblem on the cloth
        cv.ellipse(24, 21, 2.5, 2.5, "go2")
        cv.rect(22, 22, 5, 2, "go2")
        cv.px(24, 24, "go3")
        for i, cx in enumerate((6, 14, 34, 42)):
            hh = 6 if i in (0, 3) else 8
            cv.rect(cx, 12 - hh, 2, hh, "cr2")
            fl = [(0, -1), (0, -2), (1, -1)][(f + i) % 3]
            cv.px(cx, 12 - hh - 1, "fi3")
            cv.px(cx + fl[0], 12 - hh + fl[1] - 1, "fi4")
        cv.outline("ink")
        frames.append(cv)
    return frames


def candle_stand():
    frames = []
    for f in range(3):
        cv = Canvas(10, 26)
        soft_shadow(cv, 5, 24, 4, 1.5)
        cv.rect(4, 8, 2, 15, "ir2")
        cv.rect(2, 22, 6, 2, "ir1")
        cv.rect(2, 7, 6, 2, "ir2")
        cv.rect(4, 2, 2, 5, "cr2")
        cv.px(4, 2, "cr3")
        flame = [((4, 0), (4, 1)), ((5, 0), (4, 1)), ((4, 0), (5, 1))][f]
        cv.px(*flame[0], "fi4")
        cv.px(*flame[1], "fi3")
        cv.outline("ink")
        frames.append(cv)
    return frames


def bookshelf(seed=0):
    cv = Canvas(34, 40)
    rng = np.random.default_rng(seed)
    cv.rect(1, 1, 32, 38, "wd1")
    cv.rect(2, 2, 30, 36, "wd0")
    for shelf_y in (2, 14, 26):
        x = 3
        while x < 31:
            bw = int(rng.integers(2, 4))
            bh = int(rng.integers(8, 11))
            col = ["rd1", "bl1", "go1", "te1", "vi2", "wd3", "rd2", "cr0"][rng.integers(0, 8)]
            if rng.random() < 0.12:
                x += bw  # gap
                continue
            cv.rect(x, shelf_y + 11 - bh, bw, bh, col)
            cv.vline(x, shelf_y + 11 - bh, bh, lighten(col, 0.25))
            cv.px(x + bw - 1, shelf_y + 11 - bh + 2, "go3" if rng.random() < 0.3 else col)
            x += bw
        cv.rect(2, shelf_y + 11, 30, 1, "wd3")
    cv.hline(1, 1, 32, "wd3")
    cv.outline("ink")
    return cv


def stained_window():
    cv = Canvas(16, 42)
    cv.rect(1, 4, 14, 37, "st1")
    cv.ellipse(8, 6, 7, 6, "st1")
    cv.rect(3, 7, 10, 32, "vi1")
    cv.ellipse(8, 8, 5, 5, "vi1")
    cols = ["rd2", "bl2", "go2", "vi3", "te2", "go3", "bl3"]
    rng = np.random.default_rng(3)
    for y in range(4, 39):
        for x in range(3, 13):
            if cv.get(x, y) == C("vi1"):
                cell = ((x - 3) // 3) + ((y - 4) // 4) * 4
                c = cols[(cell * 5 + 3) % len(cols)]
                if (x - 3) % 3 == 0 or (y - 4) % 4 == 0:
                    c = "ink2"
                cv.px(x, y, c)
    cv.outline("ink")
    return cv


def statue_broken():
    cv = Canvas(22, 38)
    soft_shadow(cv, 11, 36, 10, 2)
    cv.rect(3, 28, 16, 8, "st2")
    cv.hline(3, 28, 16, "st4")
    cv.hline(3, 35, 16, "st1")
    # robed figure missing its head, hands holding a little bell
    cv.poly([(6, 28), (16, 28), (14, 10), (8, 10)], "st3")
    cv.vline(8, 10, 18, "st4")
    cv.vline(14, 12, 16, "st1")
    cv.rect(8, 8, 6, 3, "st3")
    cv.line(9, 8, 13, 9, "st1")  # broken neck
    cv.rect(9, 16, 4, 4, "st4")
    cv.px(11, 19, "st2")
    # head on the ground
    cv.ellipse(19, 34, 2.5, 2, "st3")
    cv.outline("ink")
    return cv


def archive_door():
    frames = []
    for state in ("closed", "open"):
        cv = Canvas(36, 44)
        stone_wall(cv, 0, 0, 36, 44, tones=("#2e2a3a", "#433d54", "#5a536e", "#746c8a"), bw=8, bh=5, seed=70)
        cv.ellipse(18, 12, 13, 10, "#2e2a3a")
        cv.rect(5, 12, 26, 32, "#2e2a3a")
        if state == "closed":
            cv.ellipse(18, 13, 11, 9, "#5a536e")
            cv.rect(7, 13, 22, 31, "#5a536e")
            for y in range(14, 44, 6):
                cv.hline(7, y, 22, "#433d54")
            cv.vline(18, 6, 38, "#2e2a3a")
            # empty sockets where the seals' light travels
            for sx in (10, 18, 26):
                cv.px(sx, 30, "#2e2a3a")
        else:
            cv.ellipse(18, 13, 11, 9, "void")
            cv.rect(7, 13, 22, 31, "void")
            for y in range(36, 44, 3):  # steps going into the archive
                cv.hline(9, y, 18, "#2e2a3a")
            cv.rect(5, 16, 2, 28, "#433d54")
            cv.rect(29, 16, 2, 28, "#433d54")
        cv.outline("ink")
        frames.append(cv)
    return frames


def seal(symbol):
    """3 frames: dormant / glowing / solved. 18x18 stone medallion."""
    frames = []
    for state in range(3):
        cv = Canvas(18, 18)
        rim = ("st1", "st3") if state == 0 else (("sp1", "sp3") if state == 1 else ("go1", "go3"))
        cv.ellipse(9, 9, 8, 8, rim[0])
        cv.ellipse(9, 9, 7, 7, "st2" if state == 0 else ("sp0" if state == 1 else "go0"))
        cv.ellipse(8, 8, 6, 6, "st3" if state == 0 else ("sp1" if state == 1 else "go1"))
        mark = "st0" if state == 0 else ("sp4" if state == 1 else "go4")
        if symbol == "flame":
            cv.poly([(9, 3), (13, 9), (12, 13), (6, 13), (5, 9)], mark)
            cv.poly([(9, 7), (11, 11), (7, 11)], cv.get(8, 8) if state == 0 else rim[0])
        elif symbol == "moon":
            cv.ellipse(9, 9, 5, 5, mark)
            cv.ellipse(11, 8, 4, 4.5, "st3" if state == 0 else ("sp1" if state == 1 else "go1"))
        elif symbol == "crown":
            cv.poly([(4, 13), (4, 6), (6.5, 9), (9, 4), (11.5, 9), (14, 6), (14, 13)], mark)
            cv.hline(5, 12, 9, rim[0])
        cv.outline("ink")
        frames.append(cv)
    return frames


def inscription_plaque():
    cv = Canvas(30, 18)
    cv.rect(1, 1, 28, 16, "#433d54")
    cv.rect(2, 2, 26, 14, "#5a536e")
    rng = np.random.default_rng(5)
    for y in (4, 7, 10, 13):
        x = 4
        while x < 26:
            ln = int(rng.integers(1, 4))
            if rng.random() < 0.7:
                cv.hline(x, y, ln, "#2e2a3a")
            x += ln + 1
    cv.outline("ink")
    return cv


def lectern(open_book=True):
    cv = Canvas(18, 26)
    soft_shadow(cv, 9, 24, 7, 1.5)
    cv.rect(7, 10, 4, 13, "wd2")
    cv.vline(7, 10, 13, "wd3")
    cv.rect(4, 22, 10, 2, "wd1")
    cv.poly([(1, 10), (17, 10), (15, 4), (3, 4)], "wd3")
    if open_book:
        cv.rect(3, 4, 6, 5, "cr2")
        cv.rect(9, 4, 6, 5, "cr1")
        cv.vline(9, 4, 5, "wd1")
        for y in (5, 7):
            cv.hline(4, y, 4, "cr0")
            cv.hline(10, y, 4, "cr0")
        cv.px(11, 6, "rd2")
    cv.outline("ink")
    return cv


def donation_box():
    cv = Canvas(12, 14)
    soft_shadow(cv, 6, 12, 5, 1.5)
    cv.rect(2, 3, 8, 9, "wd2")
    cv.rect(2, 3, 8, 2, "wd4")
    cv.hline(4, 4, 4, "ink")
    cv.px(6, 8, "go2")
    cv.outline("ink")
    return cv


def banner_torn():
    cv = Canvas(14, 32)
    cv.hline(1, 1, 12, "wd2")
    cv.rect(2, 2, 10, 24, "vi2")
    cv.vline(2, 2, 24, "vi3")
    cv.vline(11, 2, 24, "vi1")
    for x in range(2, 12):
        cut = 26 + (x * 7 % 5)
        for y in range(26, cut):
            cv.px(x, y, "vi2")
    cv.ellipse(7, 11, 2.5, 2.5, "go2")
    cv.rect(5, 12, 5, 2, "go2")
    cv.outline("ink")
    return cv


def papers():
    cv = Canvas(18, 10)
    for (x, y, a) in ((1, 3, 0), (7, 1, 1), (10, 5, 0)):
        cv.rect(x, y, 6, 4, "cr2" if a else "cr1")
        cv.hline(x + 1, y + 1, 4, "cr0")
    return cv


# ========================================================== mist path ===
def shrine():
    cv = Canvas(26, 32)
    soft_shadow(cv, 13, 30, 11, 2)
    stone_wall(cv, 4, 10, 18, 20, tones=("st0", "st1", "st2", "st3"), bw=6, bh=4, seed=80, moss=0.3)
    cv.poly([(2, 11), (13, 2), (24, 11)], "st2")
    cv.line(2, 11, 13, 2, "st3")
    cv.rect(9, 14, 8, 9, "ink2")
    cv.ellipse(13, 14, 4, 3, "ink2")
    cv.rect(11, 19, 4, 3, "st1")  # worn offering stone
    cv.rect(7, 25, 12, 2, "st1")  # chiselled-off name
    for x in range(8, 18, 2):
        cv.px(x, 25, "st3")
    cv.outline("ink")
    return cv


def silhouette(seed=0):
    cv = Canvas(16, 30)
    rng = np.random.default_rng(seed)
    body = (20, 26, 34, 200)
    cv.ellipse(8, 5, 3.5, 4, body)
    cv.poly([(3, 28), (13, 28), (11, 9), (5, 9)], body)
    for y in range(28, 30):
        for x in range(4, 12):
            if rng.random() < 0.5:
                cv.px(x, y, (20, 26, 34, 120))
    return cv


def tower_base():
    """Lower part of the bell tower at the top of the Mistbound Path."""
    w, h = 112, 150
    cv = Canvas(w, h)
    soft_shadow(cv, 56, 146, 50, 4)
    body = ("#262c3a", "#363e52", "#47516a", "#5c6884")
    x0 = 20
    stone_wall(cv, x0, 0, 72, 140, tones=body, bw=8, bh=6, seed=90, moss=0.1)
    # buttresses
    for bx in (x0 - 8, x0 + 72):
        stone_wall(cv, bx, 60, 8, 80, tones=body, bw=4, bh=6, seed=bx)
    # slit windows with faint spectral light
    for (sx, sy) in ((x0 + 34, 20), (x0 + 34, 56)):
        cv.rect(sx, sy, 4, 12, "#0e1220")
        cv.vline(sx + 1, sy + 2, 8, "sp1")
    # great door
    dx, dy = x0 + 22, 104
    cv.rect(dx - 3, dy - 3, 34, 40, body[0])
    cv.ellipse(dx + 14, dy + 4, 15, 9, body[0])
    cv.rect(dx, dy, 28, 36, "wd1")
    cv.ellipse(dx + 14, dy + 4, 13, 7, "wd1")
    for x in range(dx, dx + 28, 4):
        cv.vline(x, dy - 2, 38, "wd0")
    for y in (dy + 8, dy + 26):
        cv.hline(dx, y, 28, "ir2")
    cv.rect(dx + 12, dy + 16, 4, 4, "ir3")
    # steps
    for i, sy in enumerate(range(140, 150, 3)):
        cv.rect(dx - 6 - i * 2, sy, 40 + i * 4, 3, "st2" if i % 2 == 0 else "st1")
        cv.hline(dx - 6 - i * 2, sy, 40 + i * 4, "st3")
    cv.outline("ink")
    return cv


# ============================================================== tower ===
def bell(cracked=True):
    """The great bell. Frames: dim, pulse, warm (chorus ending)."""
    frames = []
    for state in ("dim", "pulse", "warm"):
        w, h = 74, 66
        cv = Canvas(w, h)
        body = ("#3a2a1e", "#5e4426", "#8a6632", "#b48a48", "#d8b46a")
        if state == "warm":
            body = ("#5a3a14", "#8c6826", "#c49a3e", "#e8c86e", "#f8e8aa")
        cx = w / 2
        # bell profile: shoulder -> waist -> flared lip
        prof = []
        for y in range(6, 60):
            t = (y - 6) / 54
            r = 13 + 10 * (t ** 1.6) + (12 * max(0, t - 0.78) ** 1.2 * 6 if t > 0.78 else 0)
            prof.append((y, min(r, 34)))
        for (y, r) in prof:
            for x in range(int(cx - r), int(cx + r) + 1):
                u = (x - (cx - r)) / max(1, 2 * r)
                c = body[1] if u < 0.18 else (body[3] if u < 0.42 else (body[2] if u < 0.75 else body[1]))
                if u > 0.9:
                    c = body[0]
                cv.px(x, y, c)
        cv.ellipse(cx, 6, 13, 3, body[2])  # crown
        cv.rect(cx - 4, 0, 8, 6, body[1])  # canons
        cv.rect(cx - 2, 0, 4, 5, body[2])
        # decorative bands + the thirteen marks
        for by in (16, 46):
            r = [r for (y, r) in prof if y == by][0]
            cv.hline(int(cx - r), by, int(2 * r), body[0])
            cv.hline(int(cx - r), by + 1, int(2 * r), body[4])
        for i in range(13):
            ang = -0.9 + i * (1.8 / 12)
            mx = int(cx + math.sin(ang) * 18)
            cv.px(mx, 30 + int(abs(ang) * 3), body[4] if i < 12 else "sp4")
        # mouth: dark interior with spectral light
        cv.ellipse(cx, 59, 33, 5, "ink2")
        glow = {"dim": "sp1", "pulse": "sp3", "warm": "fi4"}[state]
        cv.ellipse(cx, 59, 27, 3, glow)
        cv.ellipse(cx, 59, 17, 2, lighten(C(glow), 0.4))
        if cracked and state != "warm":
            pts = [(cx + 6, 20), (cx + 8, 26), (cx + 5, 31), (cx + 9, 38), (cx + 7, 44), (cx + 11, 52)]
            for a, b in zip(pts, pts[1:]):
                cv.line(int(a[0]), a[1], int(b[0]), b[1], "ink")
            if state == "pulse":
                for a, b in zip(pts, pts[1:]):
                    cv.line(int(a[0]) + 1, a[1], int(b[0]) + 1, b[1], "sp3")
        cv.outline("ink")
        frames.append(cv)
    return frames


def bell_yoke():
    cv = Canvas(110, 18)
    cv.rect(0, 4, 110, 9, "wd2")
    cv.hline(0, 4, 110, "wd4")
    cv.hline(0, 12, 110, "wd0")
    for x in range(6, 110, 18):
        cv.rect(x, 6, 2, 2, "ir2")
    cv.rect(46, 12, 18, 6, "ir1")
    cv.rect(48, 13, 14, 4, "ir2")
    cv.outline("ink")
    return cv


def mechanism():
    frames = []
    for state in ("broken", "fixed"):
        cv = Canvas(44, 48)
        soft_shadow(cv, 22, 46, 20, 2)
        cv.rect(4, 30, 36, 14, "wd2")      # frame
        cv.hline(4, 30, 36, "wd4")
        cv.rect(6, 4, 3, 28, "wd2")
        cv.rect(35, 4, 3, 28, "wd2")
        cx, cy, r = 22, 18, 12
        teeth = 14
        for i in range(teeth):
            a = i * math.tau / teeth + (0.0 if state == "fixed" else 0.15)
            if state == "broken" and i in (3, 4):
                continue
            tx, ty = cx + math.cos(a) * (r + 1.5), cy + math.sin(a) * (r + 1.5)
            cv.rect(int(tx) - 1, int(ty) - 1, 3, 3, "ir2")
        cv.ellipse(cx, cy, r, r, "ir2")
        cv.ellipse(cx, cy, r - 2, r - 2, "ir1")
        cv.ellipse(cx - 1, cy - 1, r - 4, r - 4, "ir2")
        for k in range(4):
            a = k * math.pi / 2 + 0.4
            cv.line(cx, cy, int(cx + math.cos(a) * (r - 3)), int(cy + math.sin(a) * (r - 3)), "ir3")
        cv.ellipse(cx, cy, 3, 3, "ir3")
        # the slot for the tuning pin
        if state == "broken":
            cv.rect(cx - 1, cy - 1, 3, 3, "ink")
            cv.line(cx + 4, cy + 3, cx + 9, cy + 9, "ink")  # crack
        else:
            cv.rect(cx - 6, cy - 1, 12, 3, "ir4")
            cv.px(cx + 5, cy, "go3")
        # lever
        cv.line(36, 32, 42, 24, "wd3")
        cv.rect(40, 22, 3, 3, "ir3")
        cv.outline("ink")
        frames.append(cv)
    return frames


def chains(length=40):
    cv = Canvas(5, length)
    for y in range(0, length, 3):
        if (y // 3) % 2 == 0:
            cv.rect(1, y, 3, 3, "ir2")
            cv.px(2, y + 1, "ink")
        else:
            cv.rect(2, y, 1, 3, "ir3")
    return cv


def pillar():
    cv = Canvas(12, 60)
    soft_shadow(cv, 6, 58, 6, 1.5)
    cv.rect(2, 0, 8, 58, "wd2")
    cv.vline(2, 0, 58, "wd3")
    cv.vline(9, 0, 58, "wd1")
    for y in range(6, 58, 13):
        cv.hline(2, y, 8, "wd1")
    cv.rect(1, 54, 10, 4, "wd1")
    cv.outline("ink")
    return cv


def window_arch():
    cv = Canvas(30, 46)
    stone_wall(cv, 0, 0, 30, 46, tones=("sl0", "sl1", "sl2", "sl3"), bw=8, bh=6, seed=95)
    cv.ellipse(15, 12, 11, 10, "#0a0e1c")
    cv.rect(4, 12, 22, 32, "#0a0e1c")
    rng = np.random.default_rng(4)
    for _ in range(14):
        x, y = rng.integers(5, 25), rng.integers(4, 40)
        if cv.get(x, y) == C("#0a0e1c"):
            cv.px(x, y, "st5" if rng.random() < 0.3 else "st3")
    cv.ellipse(20, 10, 3, 3, "cr2")  # moon
    cv.ellipse(21, 9, 2.5, 2.5, "#0a0e1c")
    cv.rect(2, 42, 26, 4, "sl2")
    cv.hline(2, 42, 26, "sl3")
    cv.outline("ink")
    return cv


def desk():
    cv = Canvas(34, 24)
    soft_shadow(cv, 17, 22, 16, 2)
    cv.rect(1, 6, 32, 6, "wd3")
    cv.hline(1, 6, 32, "wd4")
    cv.rect(1, 12, 32, 3, "wd1")
    for x in (2, 29):
        cv.rect(x, 15, 3, 6, "wd1")
    cv.rect(5, 3, 8, 5, "cr1")   # papers
    cv.rect(7, 4, 8, 4, "cr2")
    cv.rect(24, 2, 2, 5, "cr2")  # candle stub
    cv.px(24, 1, "fi3")
    cv.rect(17, 5, 4, 2, "wd1")  # quill box
    cv.outline("ink")
    return cv


def chair():
    cv = Canvas(14, 20)
    soft_shadow(cv, 7, 18, 6, 1.5)
    cv.rect(2, 1, 10, 9, "wd2")
    cv.rect(3, 2, 8, 7, "rd1")   # cushion with his shape
    cv.rect(2, 10, 10, 4, "wd3")
    cv.hline(2, 10, 10, "wd4")
    for x in (2, 10):
        cv.rect(x, 14, 2, 4, "wd1")
    cv.outline("ink")
    return cv


def stairs_down():
    cv = Canvas(34, 26)
    cv.rect(0, 0, 34, 26, "sl1")
    cv.rect(2, 2, 30, 22, "void")
    for i, y in enumerate(range(4, 24, 4)):
        cv.rect(4 + i, y, 26 - i * 2, 2, mix("sl2", "void", i / 5))
    cv.outline("ink")
    return cv


# ============================================================ build all ===
def build_all():
    # nature
    register("tree_oak", tree_oak(1), (22, 52), collide=(-4, -4, 8, 5))
    register("tree_oak_b", tree_oak(7), (22, 52), collide=(-4, -4, 8, 5))
    register("tree_pine", tree_pine(2), (15, 48), collide=(-3, -4, 6, 5))
    register("tree_pine_dark", tree_pine(5, dark=True), (15, 48), collide=(-3, -4, 6, 5))
    register("tree_dead", tree_dead(3), (18, 49), collide=(-3, -4, 6, 5))
    register("bush", bush(4), (10, 14), collide=(-7, -5, 14, 5))
    register("bush_flowers", bush(9, flowers=True), (10, 14), collide=(-7, -5, 14, 5))
    register("bush_dark", bush(11, dark=True), (10, 14), collide=(-7, -5, 14, 5))
    register("rock", rock(14, 10, 5), (7, 9), collide=(-6, -5, 12, 5))
    register("rock_large", rock(26, 20, 6, large=True), (13, 18), collide=(-11, -9, 22, 9))
    register("stump", stump(), (7, 10), collide=(-4, -4, 8, 4))
    register("mushrooms", mushrooms(), (6, 9), fps=1.5,
             light={"color": [0.5, 0.85, 1.0], "energy": 0.45, "scale": 0.35, "offset": [0, -4]}, ysort=True)
    register("tall_grass", tall_grass(6), (5, 8), ysort=True)
    register("tall_grass_dark", tall_grass(8, dark=True), (5, 8), ysort=True)
    # village
    register("house_cottage", house_side_gable(52, 26, 24, seed=11, windows=((8, 7), (36, 7)), door_x=22,
                                               chimney=(40, 8, 16)), (28, 54), collide=(-27, -40, 54, 40))
    register("house_cottage_b", house_side_gable(44, 24, 22, seed=12, roof="sl", windows=((30, 6),), door_x=8,
                                                 chimney=(8, 7, 14), lit=False), (24, 50), collide=(-23, -36, 46, 36))
    register("house_tavern", house_front_gable(72, 32, seed=13, windows=((8, 8), (52, 8)), door_x=31),
             (40, 92), collide=(-37, -76, 74, 76))
    register("house_narrow", house_front_gable(40, 28, seed=14, roof="sl", depth=18, windows=((6, 7),), door_x=22,
                                                lit=False), (24, 66), collide=(-21, -52, 42, 52))
    register("forge_ext", forge_ext(), (37, 60), collide=(-36, -46, 72, 46))
    register("chapel_ext", chapel_ext(), (40, 94), collide=(-37, -78, 74, 78))
    register("tower_distant", tower_distant(), (24, 131), ysort=False)
    register("well", well(), (17, 43), collide=(-13, -10, 26, 10))
    register("lantern_post", lantern_post(), (6, 32), collide=(-2, -2, 4, 3), fps=6.0,
             light={"color": [1.0, 0.72, 0.42], "energy": 0.95, "scale": 0.9, "offset": [-3, -20]})
    register("wall_lantern", wall_lantern(), (4, 11), fps=6.0,
             light={"color": [1.0, 0.72, 0.42], "energy": 0.8, "scale": 0.7, "offset": [0, -5]}, ysort=False)
    register("market_stall", market_stall(0), (23, 39), collide=(-21, -12, 42, 12))
    register("market_stall_b", market_stall(1), (23, 39), collide=(-21, -12, 42, 12))
    register("notice_board", notice_board(), (15, 32), collide=(-12, -3, 24, 3))
    register("signpost", signpost(), (12, 30), collide=(-2, -2, 4, 3))
    register("barrel", barrel(), (7, 15), collide=(-5, -4, 10, 4))
    register("crate", crate(), (8, 16), collide=(-7, -5, 14, 5))
    register("crate_stack", crate(True), (8, 26), collide=(-7, -5, 14, 5))
    register("sack", sack(), (6, 11), collide=(-4, -3, 8, 3))
    for i in range(3):
        register(f"flower_pot_{i}", flower_pot(i), (6, 12), collide=(-3, -2, 6, 2))
    register("bench", bench(), (13, 10), collide=(-12, -4, 24, 4))
    register("hay_bale", hay_bale(), (10, 13), collide=(-9, -5, 18, 5))
    register("cart", cart(), (18, 23), collide=(-15, -6, 30, 6))
    register("fence", fence(), (8, 13), collide=(-8, -3, 16, 3))
    register("fence_broken", fence(True), (8, 13), collide=(-8, -3, 16, 3))
    register("bucket", bucket(), (4, 8), collide=(-3, -2, 6, 2))
    register("gate_north", gate_north(), (32, 38), collide=(-32, -8, 64, 8))
    # forge interior
    register("furnace", furnace(), (26, 52), collide=(-22, -18, 44, 18), fps=5.0,
             light={"color": [1.0, 0.55, 0.25], "energy": 1.3, "scale": 1.6, "offset": [0, -16]})
    register("anvil", anvil(), (11, 16), collide=(-8, -5, 16, 5))
    register("tool_rack", tool_rack(), (15, 19), ysort=False)
    register("weapon_rack", weapon_rack(), (16, 28), collide=(-14, -5, 28, 5))
    register("quench_barrel", quench_barrel(), (7, 15), collide=(-5, -4, 10, 4))
    register("coal_pile", coal_pile(), (11, 10), collide=(-9, -4, 18, 4))
    register("workbench", workbench(), (17, 20), collide=(-16, -9, 32, 9))
    register("tuning_pin_item", tuning_pin_item(), (7, 4), ysort=True)
    register("cradle", cradle(), (10, 13), collide=(-8, -4, 16, 4))
    register("bellows", bellows(), (11, 11), collide=(-9, -4, 18, 4))
    register("shelf_jar", shelf_jar(), (11, 23), collide=(-10, -4, 20, 4))
    register("forge_plaque", forge_sign_plaque(), (20, 9), ysort=False)
    # chapel interior
    register("pew", pew(), (23, 16), collide=(-23, -9, 46, 9))
    register("altar", altar(), (24, 32), collide=(-23, -14, 46, 14), fps=4.0,
             light={"color": [1.0, 0.78, 0.5], "energy": 0.9, "scale": 1.1, "offset": [0, -24]})
    register("candle_stand", candle_stand(), (5, 24), collide=(-3, -2, 6, 2), fps=5.0,
             light={"color": [1.0, 0.75, 0.45], "energy": 0.75, "scale": 0.6, "offset": [0, -23]})
    register("bookshelf", bookshelf(0), (17, 39), collide=(-16, -6, 32, 6))
    register("bookshelf_b", bookshelf(4), (17, 39), collide=(-16, -6, 32, 6))
    register("stained_window", stained_window(), (8, 41), ysort=False)
    register("statue_broken", statue_broken(), (11, 36), collide=(-8, -6, 16, 6))
    register("archive_door", archive_door(), (18, 43), collide=(-14, -6, 28, 6), ysort=False)
    for sym in ("flame", "moon", "crown"):
        register(f"seal_{sym}", seal(sym), (9, 17), ysort=False)
    register("inscription_plaque", inscription_plaque(), (15, 17), ysort=False)
    register("lectern", lectern(), (9, 24), collide=(-6, -4, 12, 4))
    register("donation_box", donation_box(), (6, 12), collide=(-4, -3, 8, 3))
    register("banner_torn", banner_torn(), (7, 31), ysort=False)
    register("papers", papers(), (9, 8), ysort=False)
    # mist path
    register("shrine", shrine(), (13, 30), collide=(-9, -6, 18, 6))
    register("silhouette", silhouette(0), (8, 29), ysort=True)
    register("tower_base", tower_base(), (56, 140), collide=(-46, -118, 92, 118))
    # tower
    register("bell", bell(), (37, 64), collide=(-30, -10, 60, 10), fps=0.0)
    register("bell_yoke", bell_yoke(), (55, 17), ysort=False)
    register("mechanism", mechanism(), (22, 46), collide=(-18, -10, 36, 10))
    register("chains", chains(), (2, 39), ysort=False)
    register("pillar", pillar(), (6, 58), collide=(-5, -4, 10, 4))
    register("window_arch", window_arch(), (15, 45), ysort=False)
    register("desk", desk(), (17, 22), collide=(-16, -8, 32, 8))
    register("chair", chair(), (7, 18), collide=(-5, -3, 10, 3))
    register("stairs_down", stairs_down(), (17, 25), ysort=False)
    path = os.path.join(ROOT, "tools", "build", "props_manifest.json")
    with open(path, "w") as f:
        json.dump(MANIFEST, f, indent=1)
    return MANIFEST


if __name__ == "__main__":
    m = build_all()
    print("props:", len(m))
