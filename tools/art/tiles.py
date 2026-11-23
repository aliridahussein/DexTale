"""Generates assets/tilesets/world_tiles.png (16x16 tiles) + a manifest.

Tiles are registered by name; the level builder looks them up by name.
Autotile families use a 4-bit mask: N=1, E=2, S=4, W=8.
"""
from __future__ import annotations

import json
import os
import numpy as np

from px import Canvas, C, PAL, mix, darken, lighten, dither, smooth_noise, ROOT

T = 16
COLS = 16
N, E, S, W = 1, 2, 4, 8


class Atlas:
    def __init__(self):
        self.tiles: list[tuple[str, Canvas, bool]] = []
        self.index: dict[str, tuple[int, int]] = {}

    def add(self, name: str, cv: Canvas, solid: bool = False):
        assert name not in self.index, name
        i = len(self.tiles)
        self.index[name] = (i % COLS, i // COLS)
        self.tiles.append((name, cv, solid))

    def save(self):
        rows = (len(self.tiles) + COLS - 1) // COLS
        sheet = Canvas(COLS * T, rows * T)
        for i, (_, cv, _) in enumerate(self.tiles):
            sheet.blit(cv, (i % COLS) * T, (i // COLS) * T)
        sheet.save("assets/tilesets/world_tiles.png")
        manifest = {
            "tile_size": T,
            "columns": COLS,
            "tiles": {n: {"atlas": list(self.index[n]), "solid": s} for n, _, s in self.tiles},
        }
        path = os.path.join(ROOT, "tools", "build", "tiles_manifest.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(manifest, f, indent=1)
        return sheet


def tone_fill(cv: Canvas, n: np.ndarray, tones: list):
    """Fill a tile from a 0..1 noise map using ordered-dithered tone bands."""
    k = len(tones) - 1
    for y in range(cv.h):
        for x in range(cv.w):
            v = n[y, x] * k
            i = int(min(k - 1, max(0, np.floor(v))))
            frac = v - i
            cv.px(x, y, tones[i + 1] if dither(x, y, frac) else tones[i])


# ------------------------------------------------------------------ ground ---
def grass(seed, flowers=0, dark=False, blades=9):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    tones = ["gr0", "gr1", "gr2"] if dark else ["gr1", "gr2", "gr3"]
    n = smooth_noise(T, T, rng, 2)
    n = np.clip(n * 0.8 + 0.15, 0, 1)
    tone_fill(cv, n, tones)
    hi = "gr2" if dark else "gr4"
    lo = "gr0" if dark else "gr1"
    for _ in range(blades):
        x, y = rng.integers(0, T), rng.integers(0, T)
        cv.px(x, y, hi)
        cv.px(x, (y + 1) % T, lo)
    fcols = ["flw1", "flw2", "flw3", "flw4"]
    for _ in range(flowers):
        x, y = rng.integers(1, T - 1), rng.integers(1, T - 2)
        col = fcols[rng.integers(0, len(fcols))]
        cv.px(x, y, col)
        cv.px(x, y + 1, "gr1")
        if rng.random() < 0.5:
            cv.px(x + 1, y, darken(col, 0.8))
    return cv


def cobble(seed, npts=7, moss=False, dark=False):
    rng = np.random.default_rng(seed)
    pts = rng.random((npts, 2)) * T
    base_choices = ["cb2", "cb2", "cb3", "cb1", "cb2"]
    stone_col = [base_choices[rng.integers(0, len(base_choices))] for _ in range(npts)]
    owner = np.zeros((T, T), dtype=int)
    edge = np.zeros((T, T))
    for y in range(T):
        for x in range(T):
            ds = []
            for (px_, py_) in pts:
                dx = abs(x + 0.5 - px_)
                dy = abs(y + 0.5 - py_)
                dx = min(dx, T - dx)
                dy = min(dy, T - dy)
                ds.append(np.hypot(dx, dy * 1.15))
            order = np.argsort(ds)
            owner[y, x] = order[0]
            edge[y, x] = ds[order[1]] - ds[order[0]]
    mortar = edge < 1.05
    cv = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            if mortar[y, x]:
                c = "cb0"
                if moss and rng.random() < 0.35:
                    c = "gr1" if rng.random() < 0.6 else "gr2"
                cv.px(x, y, c)
            else:
                cv.px(x, y, stone_col[owner[y, x]])
    # rounded stones: highlight top-left rims, shade bottom-right rims
    res = cv.a.copy()
    for y in range(T):
        for x in range(T):
            if mortar[y, x]:
                continue
            up = mortar[(y - 1) % T, x]
            lf = mortar[y, (x - 1) % T]
            dn = mortar[(y + 1) % T, x]
            rt = mortar[y, (x + 1) % T]
            base = tuple(int(v) for v in cv.a[y, x])
            if dn or rt:
                res[y, x] = C("cb1") if base != C("cb1") else C("cb0")
            elif up or lf:
                res[y, x] = C("cb3")
    cv.a = res
    if dark:
        cv.a[:, :, :3] = (cv.a[:, :, :3] * 0.78).astype(np.uint8)
    return cv


def dirt(seed, pebbles=3):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    n = smooth_noise(T, T, rng, 2)
    tone_fill(cv, np.clip(n * 0.9 + 0.05, 0, 1), ["dt1", "dt2", "dt3"])
    for _ in range(pebbles):
        x, y = rng.integers(0, T - 1), rng.integers(0, T - 1)
        cv.px(x, y, "cb3")
        cv.px(x + 1, y, "cb2")
        cv.px(x, y + 1, "dt0")
        cv.px(x + 1, y + 1, "dt0")
    for _ in range(6):
        x, y = rng.integers(0, T), rng.integers(0, T)
        cv.px(x, y, "dt0")
    return cv


def forest_floor(seed):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    n = smooth_noise(T, T, rng, 2)
    tone_fill(cv, n, ["lf0", "gr0", "lf1"])
    for _ in range(7):  # needles / twigs
        x, y = rng.integers(0, T - 2), rng.integers(0, T - 1)
        c = "dt1" if rng.random() < 0.6 else "wd1"
        cv.px(x, y, c)
        cv.px(x + 1, y + (1 if rng.random() < 0.5 else 0), c)
    for _ in range(3):  # dead leaves
        x, y = rng.integers(0, T - 1), rng.integers(0, T - 1)
        cv.px(x, y, "dt2")
        cv.px(x + 1, y, "dt1")
    return cv


def flagstones(seed, tones, mortar, crack=False, soot=False, rows=((7, 9), (10, 6))):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    n = smooth_noise(T, T, rng, 1)
    for ri, widths in enumerate(rows):
        y0 = ri * 8
        x = (rng.integers(0, 4) if ri else 0)
        xs = []
        acc = 0
        for wdt in widths:
            xs.append(acc)
            acc += wdt
        for k, sx in enumerate(xs):
            wdt = widths[k]
            tone_shift = rng.random() * 0.3
            for yy in range(8):
                for xx in range(wdt):
                    px_ = (sx + xx + x) % T
                    py_ = y0 + yy
                    if yy == 7 or xx == wdt - 1:
                        cv.px(px_, py_, mortar)
                        continue
                    v = np.clip(n[py_, px_] * 0.7 + tone_shift, 0, 0.999)
                    c = tones[1] if v < 0.55 else tones[2]
                    if yy == 0 or xx == 0:
                        c = tones[3]
                    elif yy == 6 or xx == wdt - 2:
                        c = tones[0]
                    cv.px(px_, py_, c)
    if crack:
        x, y = rng.integers(3, 12), rng.integers(1, 5)
        for _ in range(9):
            cv.px(x, y, mortar)
            x += rng.integers(-1, 2)
            y += 1
            if y >= T:
                break
    if soot:
        for _ in range(10):
            x, y = rng.integers(0, T), rng.integers(0, T)
            cv.px(x, y, darken(tuple(cv.a[y, x]), 0.7))
    return cv


def slabs(seed, tones, mortar, crack=False, soot=False, moss=False):
    """Large, low-contrast floor slabs: calm enough to read as ground, not wall."""
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    n = smooth_noise(T, T, rng, 2)
    layout = int(rng.integers(0, 3))
    for y in range(T):
        for x in range(T):
            v = n[y, x]
            c = tones[1] if dither(x, y, v * 0.9) else tones[0]
            if v > 0.78:
                c = tones[2]
            cv.px(x, y, c)
    # seams: right/bottom edges always (so tiles join into a grid of slabs),
    # plus one interior seam depending on the layout
    cv.hline(0, T - 1, T, mortar)
    cv.vline(T - 1, 0, T, mortar)
    if layout == 1:
        cv.vline(7 + int(rng.integers(0, 3)), 0, T - 1, mortar)
    elif layout == 2:
        cv.hline(0, 7 + int(rng.integers(0, 3)), T - 1, mortar)
    # a faint lit lip along the top edge of each slab
    for x in range(T - 1):
        if rng.random() < 0.7:
            cv.px(x, 0, mix(tones[1], tones[2], 0.6))
    if crack:
        x, y = int(rng.integers(3, 12)), int(rng.integers(1, 5))
        for _ in range(8):
            cv.px(x, y, mortar)
            x += int(rng.integers(-1, 2))
            y += 1
            if y >= T - 1:
                break
    if soot:
        for _ in range(8):
            x, y = int(rng.integers(0, T - 1)), int(rng.integers(0, T - 1))
            cv.px(x, y, darken(tuple(cv.a[y, x]), 0.75))
    if moss:
        for _ in range(4):
            x, y = int(rng.integers(0, T - 1)), int(rng.integers(0, T - 1))
            cv.px(x, y, "gr1")
    return cv


def planks(seed, tones=("wd1", "wd2", "wd3", "#8f6440")):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    for p in range(4):
        y0 = p * 4
        seam = int(rng.integers(2, 14))
        for yy in range(4):
            for x in range(T):
                c = tones[2]
                if yy == 0:
                    c = tones[3]
                if yy == 3:
                    c = tones[0]
                elif rng.random() < 0.12:
                    c = tones[1]
                cv.px(x, y0 + yy, c)
        cv.vline(seam, y0, 4, tones[0])
        cv.px(seam + 1, y0 + 1, "ir3")
        cv.px(seam - 2, y0 + 2, "ir2")
    return cv


def carpet(part):
    cv = Canvas(T, T)
    cv.rect(0, 0, T, T, "rd1")
    for y in range(T):
        for x in range(T):
            # quiet diamond motif every 8px
            dx, dy = abs((x % 8) - 4), abs((y % 8) - 4)
            if dx + dy == 3:
                cv.px(x, y, "rd2")
            elif dx + dy == 0:
                cv.px(x, y, "go1")
    if part == "l":
        cv.vline(0, 0, T, "rd0")
        cv.vline(1, 0, T, "go1")
        cv.vline(2, 0, T, "go2")
        cv.vline(3, 0, T, "rd0")
    if part == "r":
        cv.vline(T - 1, 0, T, "rd0")
        cv.vline(T - 2, 0, T, "go1")
        cv.vline(T - 3, 0, T, "go2")
        cv.vline(T - 4, 0, T, "rd0")
    return cv


def steps(seed, mossy=True):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    for s in range(2):
        y0 = s * 8
        cv.rect(0, y0, T, 3, "st3")
        cv.hline(0, y0, T, "st4")
        cv.rect(0, y0 + 3, T, 5, "st1")
        cv.hline(0, y0 + 7, T, "st0")
        cut = int(rng.integers(4, 12))
        cv.vline(cut, y0, 8, "st0")
        if mossy:
            for _ in range(4):
                x = rng.integers(0, T)
                cv.px(x, y0 + 3, "gr1")
                cv.px(x, y0 + 4, "gr0")
    return cv


# --------------------------------------------------------- autotile: canopy ---
def canopy_base(seed):
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T, "lf1")
    puffs = [(rng.random() * T, rng.random() * T, 3.2 + rng.random() * 1.6) for _ in range(7)]
    for (cx, cy, r) in puffs:
        for ox in (-T, 0, T):
            for oy in (-T, 0, T):
                m = cv.ellipse_mask(cx + ox, cy + oy, r, r * 0.9)
                cv.a[m] = C("lf2")
                hl = cv.ellipse_mask(cx + ox - 0.8, cy + oy - 1.0, r * 0.62, r * 0.5)
                cv.a[hl & m] = C("lf3")
                tip = cv.ellipse_mask(cx + ox - 1.3, cy + oy - 1.6, r * 0.25, r * 0.2)
                cv.a[tip & m] = C("lf4")
                rim = m & ~cv.ellipse_mask(cx + ox + 0.6, cy + oy + 0.7, r * 0.95, r * 0.85)
                cv.a[rim] = C("lf0")
    return cv


def canopy(mask, seed):
    rng = np.random.default_rng(seed * 31 + mask)
    cv = canopy_base(seed)
    keep = np.ones((T, T), dtype=bool)
    prof = lambda: [int(v) for v in rng.integers(1, 4, size=T)]
    if mask & N:
        p = prof()
        for x in range(T):
            keep[: p[x], x] = False
    if mask & W:
        p = prof()
        for y in range(T):
            keep[y, : p[y]] = False
    if mask & E:
        p = prof()
        for y in range(T):
            keep[y, T - p[y]:] = False
    trunks = []
    if mask & S:
        p = [int(v) for v in rng.integers(5, 8, size=T)]
        for x in range(T):
            keep[T - p[x]:, x] = False
        trunks = [3 + int(rng.integers(0, 2)), 10 + int(rng.integers(0, 3))]
    cv.a[~keep] = (0, 0, 0, 0)
    # rim shading on carved edges
    res = cv.a.copy()
    for y in range(T):
        for x in range(T):
            if not keep[y, x]:
                continue
            if y + 1 < T and not keep[y + 1, x]:
                res[y, x] = C("lf0")
            elif y > 0 and not keep[y - 1, x]:
                res[y, x] = C("lf4") if (x + y) % 3 else C("lf3")
            elif x > 0 and not keep[y, x - 1]:
                res[y, x] = C("lf3")
            elif x + 1 < T and not keep[y, x + 1]:
                res[y, x] = C("lf0")
    cv.a = res
    if mask & S:
        for tx in trunks:
            for y in range(9, T - 1):
                if not keep[y, tx]:
                    cv.px(tx, y, "wd1")
                    cv.px(tx + 1, y, "wd0")
            cv.px(tx - 1, T - 2, "wd1")
            cv.px(tx + 2, T - 2, "wd0")
        # soft ground shadow under the canopy
        for x in range(T):
            for y in range(T - 3, T):
                if cv.a[y, x, 3] == 0:
                    cv.a[y, x] = (10, 14, 18, 110 if y < T - 1 else 60)
    return cv


# ------------------------------------------------- autotile: wall caps ---
WALL_STYLES = {
    "forge": dict(cap="#2a2224", cap_hi="#5a4a44", cap_lo="#140f12", face=("cb0", "cb1", "cb2", "cb3"), trim="wd1"),
    "chapel": dict(cap="#262234", cap_hi="#5c5478", cap_lo="#120f1a", face=("#3a3548", "#4f4862", "#655d7c", "#827a98"), trim="go1"),
    "tower": dict(cap="#1e2230", cap_hi="#4a5670", cap_lo="#0c0e16", face=("sl0", "sl1", "sl2", "sl3"), trim="wd1"),
    "village": dict(cap="#3e3a3a", cap_hi="#8a847a", cap_lo="#1e1a1c", face=("cb0", "cb1", "cb2", "cb3"), trim="gr1"),
}


def cap(style, mask, seed):
    st = WALL_STYLES[style]
    rng = np.random.default_rng(seed + mask)
    cv = Canvas(T, T, st["cap"])
    n = smooth_noise(T, T, rng, 1)
    for y in range(T):
        for x in range(T):
            if n[y, x] > 0.72:
                cv.px(x, y, mix(st["cap"], st["cap_hi"], 0.25))
            elif n[y, x] < 0.2:
                cv.px(x, y, mix(st["cap"], st["cap_lo"], 0.5))
    if style == "village":
        # top of a low stone wall: individual capstones
        for x in range(0, T, 8):
            cv.vline(x, 0, T, st["cap_lo"])
        for _ in range(5):
            cv.px(rng.integers(0, T), rng.integers(0, T), "gr2")
    if mask & S:
        cv.hline(0, T - 1, T, st["cap_hi"])
        cv.hline(0, T - 2, T, mix(st["cap"], st["cap_hi"], 0.45))
    if mask & N:
        cv.hline(0, 0, T, st["cap_lo"])
    if mask & W:
        cv.vline(0, 0, T, mix(st["cap"], st["cap_hi"], 0.35))
    if mask & E:
        cv.vline(T - 1, 0, T, st["cap_lo"])
    return cv


def face(style, part, seed):
    """Vertical wall surface below a cap. part: upper | lower."""
    st = WALL_STYLES[style]
    rng = np.random.default_rng(seed)
    f0, f1, f2, f3 = st["face"]
    cv = Canvas(T, T, f1)
    if style == "tower":
        bh, bw = 8, 8
    elif style == "chapel":
        bh, bw = 4, 8
    else:
        bh, bw = 5, 7
    for row in range(0, T, bh):
        off = (row // bh) % 2 * (bw // 2) + int(rng.integers(0, 2))
        for x0 in range(-bw, T + bw, bw):
            x0 += off
            v = rng.random()
            col = f2 if v < 0.55 else (f1 if v < 0.85 else f3)
            cv.rect(x0, row, bw - 1, bh - 1, col)
            cv.hline(x0, row, bw - 1, lighten(col, 0.12))
            cv.rect(x0, row + bh - 1, bw, 1, f0)
            cv.rect(x0 + bw - 1, row, 1, bh, f0)
    if style == "forge":
        for _ in range(12):  # soot
            x, y = rng.integers(0, T), rng.integers(0, T // 2 if part == "upper" else T)
            cv.px(x, y, darken(tuple(cv.a[y, x]), 0.6))
    if style == "village":
        for _ in range(6):
            x, y = rng.integers(0, T), rng.integers(0, T)
            cv.px(x, y, "gr1")
    if part == "upper":
        # shadow under the overhanging cap
        for x in range(T):
            cv.px(x, 0, darken(tuple(cv.a[0, x]), 0.45))
            cv.px(x, 1, darken(tuple(cv.a[1, x]), 0.7))
    if part == "lower":
        cv.rect(0, T - 3, T, 2, st["trim"])
        cv.hline(0, T - 3, T, lighten(C(st["trim"]), 0.2))
        cv.hline(0, T - 1, T, f0)
    return cv


# -------------------------------------------- autotile: grass fringe overlay ---
def fringe(mask, seed, dark=False):
    """Grass blades hanging over a path tile from grassy neighbours."""
    rng = np.random.default_rng(seed + mask * 7)
    cv = Canvas(T, T)
    g_lo, g_mid, g_hi = ("gr0", "gr1", "gr2") if dark else ("gr1", "gr2", "gr3")
    shadow = (12, 16, 18, 90)

    def depth():
        d = []
        prev = 2
        for _ in range(T):
            prev = int(np.clip(prev + rng.integers(-1, 2), 1, 3))
            d.append(prev)
        return d

    if mask & N:
        d = depth()
        for x in range(T):
            for y in range(d[x]):
                cv.px(x, y, g_mid if y < d[x] - 1 else (g_hi if x % 2 else g_lo))
            if cv.a[d[x], x, 3] == 0:
                cv.a[d[x], x] = shadow
    if mask & S:
        d = depth()
        for x in range(T):
            for y in range(d[x]):
                cv.px(x, T - 1 - y, g_mid if y < d[x] - 1 else (g_hi if x % 2 else g_mid))
    if mask & W:
        d = depth()
        for y in range(T):
            for x in range(d[y]):
                cv.px(x, y, g_mid if x < d[y] - 1 else (g_hi if y % 2 else g_lo))
            if cv.a[y, d[y], 3] == 0:
                cv.a[y, d[y]] = shadow
    if mask & E:
        d = depth()
        for y in range(T):
            for x in range(d[y]):
                cv.px(T - 1 - x, y, g_mid if x < d[y] - 1 else (g_hi if y % 2 else g_lo))
    return cv


# ------------------------------------------------- V2.2: the crossing ravine ---
# Not solid: collision over the ravine is handled by the crossing scene, so the
# lowered bridge can open a walkable lane across it.
def chasm_face(seed):
    """The far wall of the ravine, seen face-on, fading into the depths."""
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    n = smooth_noise(T, T, rng, 3)
    for y in range(T):
        for x in range(T):
            depth = y / T
            v = n[y, x] * (1.0 - depth * 0.8)
            col = "st2" if v > 0.55 else ("st1" if v > 0.3 else ("sl0" if v > 0.14 else "void"))
            cv.px(x, y, col)
    for _ in range(2):
        x = int(rng.integers(2, T - 2))
        for y in range(int(rng.integers(0, 6)), T - 3):
            cv.px(x + (1 if rng.random() < 0.25 else 0), y, "ink")
    cv.hline(0, 0, T, "st3")
    return cv


def chasm_deep(seed):
    """The ravine's depths: near-black with cold blue mist drifting through."""
    rng = np.random.default_rng(seed)
    cv = Canvas(T, T)
    n = smooth_noise(T, T, rng, 2)
    tone_fill(cv, np.clip(n * 0.9, 0, 1), ["void", "#0f1426", "bl0"])
    for _ in range(4):
        cv.px(int(rng.integers(0, T)), int(rng.integers(0, T)), "bl2")
    return cv


def chasm_lip(seed):
    """The near edge of the ravine: ground ending in a ragged stone lip."""
    rng = np.random.default_rng(seed)
    cv = grass(seed, dark=True)
    edge = [int(3 + rng.integers(0, 3)) for _ in range(T)]
    for x in range(T):
        for y in range(edge[x]):
            cv.px(x, y, "void" if y < edge[x] - 2 else ("st1" if (x + y) % 3 else "st2"))
        cv.px(x, edge[x], "gr0")
    return cv


def build():
    at = Atlas()
    # --- ground: village
    for i in range(4):
        at.add(f"grass_{i}", grass(100 + i))
    for i in range(2):
        at.add(f"grass_flowers_{i}", grass(120 + i, flowers=3))
    for i in range(3):
        at.add(f"grass_dark_{i}", grass(140 + i, dark=True, blades=6))
    for i in range(4):
        at.add(f"cobble_{i}", cobble(200 + i))
    for i in range(2):
        at.add(f"cobble_moss_{i}", cobble(220 + i, moss=True))
    for i in range(2):
        at.add(f"cobble_dark_{i}", cobble(240 + i, dark=True))
    for i in range(3):
        at.add(f"dirt_{i}", dirt(300 + i))
    for i in range(3):
        at.add(f"forest_{i}", forest_floor(400 + i))
    # --- interiors
    chapel_tones = ["#2c2838", "#353043", "#423c52"]
    for i in range(3):
        at.add(f"flag_{i}", slabs(500 + i, chapel_tones, "#211d2b"))
    at.add("flag_crack", slabs(510, chapel_tones, "#211d2b", crack=True))
    forge_tones = ["#2b2523", "#342d2a", "#3f3632"]
    for i in range(3):
        at.add(f"forgefloor_{i}", slabs(520 + i, forge_tones, "#1e1918", soot=True))
    for i in range(3):
        at.add(f"plank_{i}", planks(600 + i))
    for p in ("l", "m", "r"):
        at.add(f"carpet_{p}", carpet(p))
    at.add("steps_0", steps(700))
    at.add("steps_1", steps(701))
    at.add("void", Canvas(T, T, "void"), solid=True)
    # --- walls
    for style in WALL_STYLES:
        for part in ("upper", "lower"):
            for v in range(2):
                at.add(f"face_{style}_{part}_{v}", face(style, part, 800 + v * 13 + len(style)), solid=True)
    # --- autotiles
    for m in range(16):
        at.add(f"canopy_{m}", canopy(m, 900), solid=True)
    for v, seed in (("b", 931), ("c", 977)):
        at.add(f"canopy_0{v}", canopy(0, seed), solid=True)
        at.add(f"canopy_4{v}", canopy(4, seed), solid=True)
    for style in WALL_STYLES:
        for m in range(16):
            at.add(f"cap_{style}_{m}", cap(style, m, 1000), solid=True)
    for m in range(1, 16):
        at.add(f"fringe_{m}", fringe(m, 1100))
    for m in range(1, 16):
        at.add(f"fringe_dark_{m}", fringe(m, 1200, dark=True))
    # V2.2 (appended last so every existing tile keeps its atlas position)
    for i in range(2):
        at.add(f"chasm_face_{i}", chasm_face(1300 + i))
    for i in range(3):
        at.add(f"chasm_{i}", chasm_deep(1310 + i))
    for i in range(2):
        at.add(f"chasm_lip_{i}", chasm_lip(1320 + i))
    sheet = at.save()
    return at, sheet


if __name__ == "__main__":
    at, sheet = build()
    print("tiles:", len(at.tiles), "sheet:", sheet.w, "x", sheet.h)
