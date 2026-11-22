"""UI art: panels, portraits, icons, logo, backgrounds, fx textures."""
from __future__ import annotations

import math
import os
import numpy as np
from PIL import Image

from px import Canvas, C, PAL, mix, darken, lighten, dither, smooth_noise, wrap_blur, ROOT, BAYER4
import font as fontmod


# ------------------------------------------------------------- panels ---
def panel_dark():
    cv = Canvas(24, 24)
    cv.rect(0, 0, 24, 24, (14, 11, 20, 236))
    cv.rect(1, 1, 22, 22, (22, 18, 31, 238))
    # outer edge + inner gilt line
    for i in range(24):
        cv.px(i, 0, "ink")
        cv.px(i, 23, "ink")
        cv.px(0, i, "ink")
        cv.px(23, i, "ink")
    for i in range(3, 21):
        cv.px(i, 2, "go1")
        cv.px(i, 21, "go0")
        cv.px(2, i, "go1")
        cv.px(21, i, "go0")
    for (x, y) in ((2, 2), (21, 2), (2, 21), (21, 21)):
        cv.px(x, y, "go3")
        for d in (-1, 1):
            cv.px(x + d, y, "go2")
            cv.px(x, y + d, "go2")
    return cv


def panel_parchment():
    """48x48 parchment; the centre tiles (8px margins), so keep its noise subtle."""
    cv = Canvas(48, 48)
    rng = np.random.default_rng(3)
    for y in range(48):
        for x in range(48):
            v = rng.random()
            c = "cr2" if v < 0.86 else ("#d8ccb0" if v < 0.97 else "cr3")
            cv.px(x, y, c)
    for i in range(48):
        for (x, y) in ((i, 0), (i, 47), (0, i), (47, i)):
            cv.px(x, y, "wd1")
        for (x, y) in ((i, 1), (i, 46), (1, i), (46, i)):
            cv.px(x, y, "cr0")
        for (x, y) in ((i, 2), (i, 45), (2, i), (45, i)):
            if rng.random() < 0.5:
                cv.px(x, y, "cr1")
    for (x, y) in ((0, 0), (47, 0), (0, 47), (47, 47)):
        cv.px(x, y, (0, 0, 0, 0))
    return cv


def panel_small():
    cv = Canvas(12, 12)
    cv.rect(0, 0, 12, 12, (14, 11, 20, 230))
    for i in range(12):
        cv.px(i, 0, "go0")
        cv.px(i, 11, "go0")
        cv.px(0, i, "go0")
        cv.px(11, i, "go0")
    cv.px(0, 0, (0, 0, 0, 0))
    cv.px(11, 0, (0, 0, 0, 0))
    cv.px(0, 11, (0, 0, 0, 0))
    cv.px(11, 11, (0, 0, 0, 0))
    return cv


def portrait_frame():
    cv = Canvas(38, 38)
    cv.rect(0, 0, 38, 38, "ink")
    cv.rect(1, 1, 36, 36, "go1")
    cv.rect(2, 2, 34, 34, "go0")
    cv.rect(3, 3, 32, 32, (0, 0, 0, 0))
    for (x, y) in ((1, 1), (36, 1), (1, 36), (36, 36)):
        cv.px(x, y, "go3")
    return cv


# ---------------------------------------------------------- portraits ---
def _shade_ellipse(cv, cx, cy, rx, ry, base, shade, light=None):
    cv.ellipse(cx, cy, rx, ry, base)
    m = cv.ellipse_mask(cx, cy, rx, ry)
    inner = cv.ellipse_mask(cx - 1.2, cy - 0.8, rx - 0.6, ry - 0.4)
    cv.a[m & ~inner] = C(shade)
    if light:
        hl = cv.ellipse_mask(cx - rx * 0.35, cy - ry * 0.4, rx * 0.35, ry * 0.3)
        cv.a[hl & m] = C(light)


def portrait(pid: str) -> Canvas:
    P = {
        "rowan": dict(bg=("te0", "bl0"), skin=("sk1", "sk2", "sk3"), hair=("hb1", "hb2", "hb3"), cloth=("te0", "te1", "te2"), eyes="hb0"),
        "pip": dict(bg=("go0", "rd0"), skin=("sk1", "sk2", "sk3"), hair=("hy1", "hy2", "hy3"), cloth=("#465430", "#5e7044", "#7a8c5a"), eyes="bl1"),
        "mara": dict(bg=("rd0", "fi0"), skin=("dk1", "dk2", "dk3"), hair=("hd1", "hd2", "hd3"), cloth=("#4e2e26", "#6e4436", "#8a5a4a"), eyes="ink"),
        "alden": dict(bg=("vi0", "vi1"), skin=("sk1", "sk2", "sk3"), hair=("#443c50", "#5e5468", "#7a7088"), cloth=("#443c50", "#564c68", "#6e6480"), eyes="ink2"),
        "orin": dict(bg=("sp0", "bl0"), skin=("sk1", "sk2", "sk3"), hair=("hg1", "hg2", "hg3"), cloth=("#262e44", "#38445e", "#4c5a7a"), eyes="ink2"),
        "tobin": dict(bg=("bl0", "wd0"), skin=("sk1", "sk2", "sk3"), hair=("#3a2e26", "#4a3a30", "#6a5444"), cloth=("#323a44", "#46525e", "#5a6a7a"), eyes="ink"),
        "sentinel": dict(bg=("sp0", "ink"), skin=("st1", "st3", "st4"), hair=("st1", "st3", "st5"), cloth=("#2e2840", "#4a3f5a", "#5c4f70"), eyes="sp4"),
    }[pid]
    cv = Canvas(32, 32)
    # background gradient (dithered)
    for y in range(32):
        for x in range(32):
            t = y / 31
            cv.px(x, y, P["bg"][1] if dither(x, y, t) else P["bg"][0])
    fig = Canvas(32, 32)
    sk0, sk1, sk2 = P["skin"]
    h0, h1, h2 = P["hair"]
    c0, c1, c2 = P["cloth"]
    # shoulders
    fig.poly([(2, 32), (5, 25), (11, 22), (21, 22), (27, 25), (30, 32)], c1)
    fig.poly([(2, 32), (5, 25), (9, 23), (8, 32)], c2)
    fig.poly([(24, 32), (24, 23), (27, 25), (30, 32)], c0)
    # neck
    fig.rect(13, 19, 6, 5, sk0)
    fig.rect(13, 19, 4, 4, sk1)
    # head
    hx, hy = 16, 13
    if pid == "pip":
        hy = 14
    if pid != "sentinel":
        _shade_ellipse(fig, hx, hy, 7, 8, sk1, sk0, sk2)
        fig.ellipse(hx - 7.2, hy + 1, 1.5, 2, sk1)  # ears
        fig.ellipse(hx + 7.2, hy + 1, 1.5, 2, sk0)
        # eyes
        ey = hy + 1
        for ex in (hx - 3, hx + 2):
            fig.rect(ex, ey, 2, 2, P["eyes"])
            fig.px(ex, ey, "white" if pid != "orin" else "sp3")
        if pid == "pip":
            fig.rect(hx - 4, ey - 1, 3, 3, P["eyes"])
            fig.rect(hx + 2, ey - 1, 3, 3, P["eyes"])
            fig.px(hx - 4, ey - 1, "white")
            fig.px(hx + 2, ey - 1, "white")
            fig.px(hx - 5, ey + 3, "#e8888a")
            fig.px(hx + 5, ey + 3, "#e8888a")
        # brows
        fig.hline(hx - 4, ey - 2, 3, h0)
        fig.hline(hx + 2, ey - 2, 3, h0)
        if pid in ("alden", "mara"):
            fig.px(hx - 4, ey - 3, h0)   # a slightly worried / stern brow
            fig.px(hx + 4, ey - 3, h0)
        # nose + mouth
        fig.px(hx, hy + 3, sk0)
        fig.px(hx, hy + 4, sk0)
        mouth = {"rowan": [(-1, 6), (0, 6), (1, 6), (2, 5)], "pip": [(-2, 6), (-1, 7), (0, 7), (1, 7), (2, 6)],
                 "mara": [(-2, 6), (-1, 6), (0, 6), (1, 6)], "alden": [(-1, 6), (0, 6), (1, 6)],
                 "orin": [(-1, 6), (0, 6), (1, 6)], "tobin": [(-2, 5), (-1, 6), (0, 6), (1, 6)]}[pid]
        for (dx, dy) in mouth:
            fig.px(hx + dx, hy + dy, "rd1" if pid != "orin" else sk0)
    # hair / headgear
    if pid == "rowan":
        fig.ellipse(hx, hy - 4, 8, 5, h1)
        fig.ellipse(hx - 1, hy - 5, 6, 3, h2)
        for (x, y) in ((hx - 7, hy - 2), (hx - 6, hy), (hx - 4, hy - 2), (hx + 1, hy - 2), (hx + 3, hy - 1), (hx + 6, hy - 1), (hx + 7, hy + 2)):
            fig.rect(x, y, 2, 3, h1)
        fig.rect(hx - 8, hy - 2, 2, 8, h0)
        fig.rect(hx + 7, hy - 2, 2, 8, h0)
        # cloak clasp
        fig.rect(10, 24, 2, 2, "go2")
        fig.line(11, 26, 18, 32, "wd2")  # satchel strap
    elif pid == "pip":
        fig.ellipse(hx, hy - 4, 9, 6, h1)
        fig.ellipse(hx - 2, hy - 6, 6, 3, h2)
        for x in range(hx - 9, hx + 9, 2):
            fig.rect(x, hy - 3 + (x % 3), 2, 3, h1)
        fig.line(hx + 1, hy - 10, hx + 3, hy - 13, h2)  # cowlick
        fig.px(hx + 4, hy - 13, h2)
        fig.rect(13, 26, 6, 2, "#a07a4a")  # patch
    elif pid == "mara":
        fig.ellipse(hx, hy - 4, 8, 5, h1)
        fig.ellipse(hx + 1, hy - 11, 4, 3, h1)  # bun
        fig.ellipse(hx, hy - 11, 2, 1.5, h2)
        fig.hline(hx - 8, hy - 2, 17, "rd1")  # headband
        fig.hline(hx - 8, hy - 1, 17, "rd0")
        fig.rect(hx - 8, hy - 1, 2, 6, h0)
        fig.rect(hx + 7, hy - 1, 2, 6, h0)
        # apron straps + soot smudge
        fig.rect(9, 23, 3, 9, "wd2")
        fig.rect(20, 23, 3, 9, "wd2")
        fig.px(hx + 4, hy + 4, sk0)
        fig.px(hx + 5, hy + 4, darken(C(sk0), 0.7))
    elif pid == "alden":
        hood = Canvas(32, 32)
        hood.ellipse(hx, hy - 1, 10, 11, h1)
        hood.ellipse(hx - 2, hy - 4, 6, 6, h2)
        hood.poly([(4, 32), (6, 20), (26, 20), (28, 32)], h1)
        fig2 = Canvas(32, 32)
        fig2.blit(hood, 0, 0)
        face = fig.copy()
        face_mask = face.ellipse_mask(hx, hy + 1, 6.5, 7.5)
        fig2.a[face_mask] = face.a[face_mask]
        fig2.a[22:, 12:21] = face.a[22:, 12:21]
        fig = fig2
        fig.hline(hx - 5, hy - 6, 11, h0)  # hood shadow over brow
        fig.hline(hx - 4, hy - 5, 9, darken(C(sk0), 0.8))
        fig.rect(14, 26, 4, 6, "go1")  # rope
    elif pid == "orin":
        fig.ellipse(hx - 7, hy - 1, 2, 4, h1)
        fig.ellipse(hx + 7, hy - 1, 2, 4, h1)
        fig.ellipse(hx, hy + 7, 6, 6, h2)  # beard
        fig.ellipse(hx, hy + 9, 4.5, 5, h1)
        fig.hline(hx - 3, hy + 4, 7, h2)   # moustache
        fig.px(hx, hy + 5, h1)
        fig.hline(hx - 4, hy - 7, 9, sk2)  # bald crown shine
    elif pid == "tobin":
        fig.rect(hx - 7, hy - 3, 2, 6, h0)
        fig.rect(hx + 6, hy - 3, 2, 6, h0)
        fig.ellipse(hx, hy - 6, 7, 4, h1)   # hat crown
        fig.rect(hx - 6, hy - 9, 12, 5, h1)
        fig.hline(hx - 6, hy - 9, 12, h2)
        fig.rect(hx - 6, hy - 5, 12, 1, "rd1")  # band
        fig.hline(hx - 11, hy - 4, 23, h2)  # brim
        fig.hline(hx - 10, hy - 3, 21, h0)
        fig.ellipse(hx, hy + 6, 5, 2, h1)   # stubble/beard
        fig.hline(hx - 1, hy + 6, 3, "rd1")
    elif pid == "sentinel":
        fig.ellipse(hx, hy, 8, 10, "st3")
        fig.ellipse(hx - 2, hy - 3, 4, 5, "st5")
        fig.rect(hx - 8, hy - 1, 17, 3, "ink2")  # visor slit
        fig.rect(hx - 6, hy, 3, 1, "sp4")
        fig.rect(hx + 3, hy, 3, 1, "sp4")
        fig.vline(hx, hy - 10, 8, "st1")
        fig.poly([(3, 32), (6, 24), (26, 24), (29, 32)], "st3")
        fig.poly([(3, 32), (6, 24), (11, 24), (9, 32)], "st5")
    fig.outline("ink")
    cv.blit(fig, 0, 0)
    if pid in ("orin", "sentinel"):
        # spectral: cool tint + scanline shimmer
        for y in range(32):
            for x in range(32):
                r, g_, b, a = cv.a[y, x]
                lum = (int(r) + int(g_) + int(b)) / 3
                cv.a[y, x] = (int(lum * 0.55), int(lum * 0.85 + 20), int(min(255, lum * 1.1 + 40)), a)
        for y in range(0, 32, 3):
            for x in range(32):
                cv.a[y, x, :3] = np.minimum(255, cv.a[y, x, :3].astype(int) + 18)
    return cv


# -------------------------------------------------------------- icons ---
def keycap(label: str) -> Canvas:
    w = 11 if len(label) == 1 else 7 + 6 * len(label)
    cv = Canvas(w, 12)
    cv.rect(0, 0, w, 11, "ink")
    cv.rect(1, 0, w - 2, 10, "cr1")
    cv.rect(1, 0, w - 2, 1, "cr3")
    cv.rect(1, 9, w - 2, 1, "cr0")
    cv.rect(0, 11, w, 1, (0, 0, 0, 90))
    x = 3
    for ch in label:
        top, rows = fontmod.G[ch]
        for ry, r in enumerate(rows):
            for rx, c in enumerate(r):
                if c == "#":
                    cv.px(x + rx, 1 + top + ry, "ink2")
        x += len(rows[0]) + 1
    return cv


def icon(name: str) -> Canvas:
    cv = Canvas(16, 16)
    if name == "bell":
        cv.ellipse(8, 6, 4, 4, "go2")
        cv.poly([(3, 12), (4, 6), (12, 6), (13, 12)], "go2")
        cv.rect(2, 12, 12, 2, "go1")
        cv.vline(6, 5, 6, "go3")
        cv.rect(7, 14, 2, 1, "go1")
        cv.rect(7, 1, 2, 2, "go1")
    elif name == "pin":
        cv.line(3, 12, 11, 4, "ir3")
        cv.line(4, 12, 12, 4, "ir2")
        cv.rect(11, 2, 3, 3, "ir2")
        cv.px(12, 3, "ir4")
        cv.px(6, 9, "go3")
    elif name == "key":
        cv.ellipse(5, 5, 3, 3, "go2")
        cv.px(5, 5, (0, 0, 0, 0))
        cv.line(7, 7, 13, 13, "go2")
        cv.px(11, 13, "go2")
        cv.px(13, 11, "go2")
    elif name == "ledger":
        cv.rect(3, 2, 10, 12, "rd1")
        cv.rect(4, 3, 8, 10, "rd2")
        cv.vline(3, 2, 12, "rd0")
        cv.rect(5, 5, 6, 1, "go2")
        cv.rect(5, 7, 4, 1, "go1")
        cv.rect(13, 3, 1, 10, "cr1")
    elif name == "song":
        cv.vline(6, 3, 8, "sp3")
        cv.vline(11, 2, 8, "sp3")
        cv.line(6, 3, 11, 2, "sp3")
        cv.line(6, 4, 11, 3, "sp3")
        cv.ellipse(5, 11, 2, 1.5, "sp3")
        cv.ellipse(10, 10, 2, 1.5, "sp3")
    elif name == "quill":
        cv.line(3, 13, 12, 3, "cr3")
        cv.line(5, 12, 13, 4, "cr1")
        cv.line(4, 11, 11, 3, "cr2")
        cv.px(2, 14, "ink2")
    elif name == "eye":
        cv.ellipse(8, 8, 6, 3.5, "sp3")
        cv.ellipse(8, 8, 2.5, 2.5, "sp1")
        cv.px(8, 8, "sp4")
    elif name == "lantern":  # V2: Tobin's lantern
        cv.rect(7, 1, 2, 2, "ir2")
        cv.rect(5, 3, 6, 2, "ir2")
        cv.rect(5, 5, 6, 7, "fi3")
        cv.rect(6, 6, 4, 5, "fi4")
        cv.vline(5, 5, 7, "ir3")
        cv.vline(10, 5, 7, "ir3")
        cv.rect(4, 12, 8, 2, "ir2")
    cv.outline("ink")
    return cv


def symbol_bell13() -> Canvas:
    """The faded family marking: a bell ringed by thirteen marks."""
    cv = Canvas(40, 40)
    col = "sp4"
    cv.ellipse(20, 17, 5, 5, col)
    cv.poly([(13, 26), (15, 17), (25, 17), (27, 26)], col)
    cv.rect(12, 26, 16, 2, col)
    cv.rect(19, 28, 3, 2, col)
    cv.ellipse(20, 18, 3, 3, (0, 0, 0, 0))
    cv.poly([(16, 25), (17, 19), (23, 19), (24, 25)], (0, 0, 0, 0))
    for i in range(13):
        a = -math.pi / 2 + i * math.tau / 13
        x = 20 + math.cos(a) * 16
        y = 20 + math.sin(a) * 16
        cv.rect(int(x) - 1, int(y) - 1, 2, 3 if i < 12 else 4, col if i < 12 else "go3")
    return cv


SONG_NOTES = [2, 3, 4, 3, 5, 4, 2, 1, 2, 4, 3, 1, 0]  # 13 rising/falling marks (pitch steps)


def song_marks(color="ink2", w=132, h=26) -> Canvas:
    cv = Canvas(w, h)
    step = (w - 12) // 12
    pts = []
    for i, n in enumerate(SONG_NOTES):
        x = 6 + i * step
        y = h - 6 - n * 3
        pts.append((x, y))
    for a, b in zip(pts, pts[1:]):
        cv.line(a[0], a[1], b[0], b[1], (*C(color)[:3], 90))
    for i, (x, y) in enumerate(pts):
        cv.rect(x - 1, y - 1, 3, 3, color)
        if i == 12:
            cv.rect(x - 2, y - 2, 5, 5, color)
            cv.px(x, y, (0, 0, 0, 0))
    return cv


def logo() -> Canvas:
    """Title logo rendered with the Dawnmere font at 2x/3x with a gilt ramp."""
    def text_canvas(txt, scale):
        w = 0
        for ch in txt:
            if ch == " ":
                w += 3 * scale
                continue
            top, rows = fontmod.G[ch]
            w += (len(rows[0]) + 1) * scale
        cv = Canvas(w, 9 * scale)
        x = 0
        for ch in txt:
            if ch == " ":
                x += 3 * scale
                continue
            top, rows = fontmod.G[ch]
            for ry, r in enumerate(rows):
                for rx, c in enumerate(r):
                    if c == "#":
                        cv.rect(x + rx * scale, (top + ry) * scale, scale, scale, "white")
            x += (len(rows[0]) + 1) * scale
        return cv

    big = text_canvas("THIRTEENTH BELL", 3)
    small = text_canvas("THE", 2)
    W, Hh = big.w + 16, big.h + small.h + 23
    cv = Canvas(W, Hh)
    ramp = ["go4", "go3", "go3", "go2", "go2", "go1", "go1", "go0"]

    def paint(src, ox, oy):
        for y in range(src.h):
            for x in range(src.w):
                if src.a[y, x, 3]:
                    t = y / max(1, src.h - 1)
                    c = ramp[min(len(ramp) - 1, int(t * len(ramp)))]
                    cv.px(ox + x, oy + y, c)

    paint(small, (W - small.w) // 2, 2)
    paint(big, 8, small.h + 13)
    # thin rule with a bell in the middle
    ry = small.h + 5
    for x in range(20, W - 20):
        if abs(x - W // 2) > 7:
            cv.px(x, ry, "go1")
    bx = W // 2
    cv.ellipse(bx, ry - 1, 2.5, 2.5, "go3")
    cv.rect(bx - 3, ry, 7, 2, "go3")
    cv.outline("ink", sides=8)
    # drop shadow
    sh = Canvas(W, Hh)
    m = cv.mask()
    sh.a[2:, 2:][m[:-2, :-2]] = (0, 0, 0, 150)
    sh.blit(cv, 0, 0)
    return sh


# ------------------------------------------------------- backgrounds ---
def sky(cv, top, mid, low, horizon_y):
    for y in range(horizon_y):
        t = y / max(1, horizon_y - 1)
        if t < 0.55:
            a, b, k = top, mid, t / 0.55
        else:
            a, b, k = mid, low, (t - 0.55) / 0.45
        for x in range(cv.w):
            cv.px(x, y, b if dither(x, y, k) else a)


def ridge(cv, base_y, amp, color, seed, freq=0.02, jag=0):
    rng = np.random.default_rng(seed)
    ph = rng.random() * 10
    for x in range(cv.w):
        y = base_y + amp * (math.sin(x * freq + ph) * 0.6 + math.sin(x * freq * 2.3 + ph * 2) * 0.4)
        if jag:
            y -= abs(math.sin(x * 0.5 + ph)) * jag * (rng.random() * 0.5 + 0.5)
        cv.rect(x, int(y), 1, cv.h - int(y), color)


def pines(cv, base_y, color, seed, density=0.18, hmin=8, hmax=20):
    rng = np.random.default_rng(seed)
    x = -4
    while x < cv.w + 4:
        hgt = int(rng.integers(hmin, hmax))
        half = max(2, hgt // 3)
        for k in range(hgt):
            span = int(half * k / hgt)
            cv.rect(x - span, base_y - hgt + k, span * 2 + 1, 1, color)
        x += int(rng.integers(3, 8))
    cv.rect(0, base_y, cv.w, cv.h - base_y, color)


def vista(variant="dusk") -> Canvas:
    W, H = 480, 270
    cv = Canvas(W, H)
    if variant == "dusk":
        sky(cv, "#141228", "#3a2850", "#b8604a", 175)
    else:
        sky(cv, "#070914", "#121a34", "#2a3456", 175)
    rng = np.random.default_rng(11)
    for _ in range(140):
        x, y = rng.integers(0, W), rng.integers(0, 110)
        cv.px(x, y, "st5" if rng.random() < 0.25 else ("st3" if rng.random() < 0.5 else "st2"))
    # moon
    cv.ellipse(86, 46, 9, 9, "cr2")
    cv.ellipse(91, 42, 8, 8, cv.get(91, 30))
    ridge(cv, 150, 9, "#2a2440" if variant == "dusk" else "#141a30", 1, 0.012)
    ridge(cv, 168, 6, "#1e1a32" if variant == "dusk" else "#10142a", 2, 0.02)
    # hill with the tower, right side
    cv.ellipse(390, 196, 110, 40, "#18162a" if variant == "dusk" else "#0c1022")
    tx = 392
    tcol = "#141224" if variant == "dusk" else "#0a0c1a"
    cv.rect(tx - 9, 92, 18, 70, tcol)
    cv.rect(tx - 11, 80, 22, 16, tcol)
    cv.poly([(tx - 13, 81), (tx, 52), (tx + 13, 81)], tcol)
    cv.rect(tx - 6, 84, 4, 9, "sp1")
    cv.rect(tx + 2, 84, 4, 9, "sp1")
    cv.px(tx - 5, 88, "sp3")
    cv.px(tx + 3, 88, "sp3")
    pines(cv, 196, "#122024" if variant == "dusk" else "#0a1418", 4, hmin=10, hmax=26)
    # village rooftops
    roof = "#1a1420" if variant == "dusk" else "#0e0c16"
    rng = np.random.default_rng(5)
    x = 40
    lit = []
    while x < 330:
        w = int(rng.integers(22, 40))
        base = 226 + int(rng.integers(-4, 5))
        hh = int(rng.integers(14, 24))
        cv.rect(x, base - hh, w, 60, roof)
        cv.poly([(x - 3, base - hh + 1), (x + w // 2, base - hh - 14), (x + w + 3, base - hh + 1)], roof)
        if rng.random() < 0.6:
            cv.rect(x + w - 8, base - hh - 12, 4, 10, roof)
        for k in range(int(rng.integers(1, 3))):
            wx = x + 4 + int(rng.integers(0, max(1, w - 8)))
            wy = base - hh + 4 + int(rng.integers(0, 8))
            cv.rect(wx, wy, 2, 3, "fi3")
            lit.append((wx, wy))
        x += w + int(rng.integers(2, 10))
    # foreground hill
    ridge(cv, 246, 5, "#0c0a12", 7, 0.03)
    return cv


def mist_band(w, h, seed, alpha=110, color=(170, 190, 205)) -> Canvas:
    rng = np.random.default_rng(seed)
    n = np.zeros((h, w))
    for octave, amp in ((16, 1.0), (8, 0.5), (4, 0.25)):
        g = wrap_blur(rng.random((h // octave + 2, w // octave + 2)), 1)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        n += np.array(img) / 255.0 * amp
    n /= 1.75
    cv = Canvas(w, h)
    for y in range(h):
        fade = math.sin(math.pi * y / (h - 1))
        for x in range(w):
            a = max(0.0, n[y, x] - 0.38) * 2.2 * fade
            cv.a[y, x] = (*color, int(min(1.0, a) * alpha))
    return cv


def noise_tile(size=128, seed=21) -> Canvas:
    """Seamless greyscale noise for the mist shader."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size))
    for cell, amp in ((32, 1.0), (16, 0.5), (8, 0.25), (4, 0.12)):
        g = rng.random((size // cell, size // cell))
        g = np.tile(g, (3, 3))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
        a = np.array(img).astype(float) / 255.0
        acc += a[size:2 * size, size:2 * size] * amp
    acc = (acc - acc.min()) / (acc.max() - acc.min())
    cv = Canvas(size, size)
    v = (acc * 255).astype(np.uint8)
    cv.a[:, :, 0] = v
    cv.a[:, :, 1] = v
    cv.a[:, :, 2] = v
    cv.a[:, :, 3] = 255
    return cv


def radial_light(size=128) -> Canvas:
    cv = Canvas(size, size)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = max(0.0, 1.0 - d) ** 1.6
            cv.a[y, x] = (255, 255, 255, int(a * 255))
    return cv


def light_shaft(w=32, h=128) -> Canvas:
    cv = Canvas(w, h)
    for y in range(h):
        fall = (1.0 - y / h) ** 0.8
        for x in range(w):
            edge = math.sin(math.pi * x / (w - 1)) ** 1.5
            cv.a[y, x] = (255, 255, 255, int(255 * fall * edge))
    return cv


def vignette(w=480, h=270) -> Canvas:
    cv = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2) / (w / 2)
            dy = (y - h / 2) / (h / 2)
            d = math.sqrt(dx * dx * 0.8 + dy * dy)
            a = max(0.0, d - 0.55) / 0.6
            cv.a[y, x] = (4, 2, 8, int(min(1.0, a) ** 1.5 * 255))
    return cv


def particle_textures():
    out = {}
    p1 = Canvas(1, 1, "white")
    p2 = Canvas(2, 2, "white")
    spark = Canvas(3, 3)
    spark.px(1, 0, "white")
    spark.px(0, 1, "white")
    spark.px(1, 1, "white")
    spark.px(2, 1, "white")
    spark.px(1, 2, "white")
    mote = Canvas(3, 3)
    mote.px(1, 1, "white")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        mote.px(x, y, (255, 255, 255, 120))
    note = Canvas(6, 8)
    top, rows = fontmod.G["♪"]
    for ry, r in enumerate(rows):
        for rx, c in enumerate(r):
            if c == "#":
                note.px(rx, ry, "white")
    ring = Canvas(48, 48)
    for y in range(48):
        for x in range(48):
            d = math.hypot(x - 23.5, y - 23.5)
            if 21 <= d <= 23:
                ring.px(x, y, "white")
            elif 19.5 <= d < 21:
                ring.px(x, y, (255, 255, 255, 110))
    leaf = Canvas(3, 2)
    leaf.px(0, 0, "white")
    leaf.px(1, 0, "white")
    leaf.px(1, 1, "white")
    leaf.px(2, 1, "white")
    out.update(px1=p1, px2=p2, spark=spark, mote=mote, note=note, ring=ring, leaf=leaf)
    return out


def memory_scene() -> Canvas:
    """Ending A vignette: young Rowan with Orin by the well, in warm sepia."""
    W, H = 168, 104
    cv = Canvas(W, H)
    tiles = Image.open(os.path.join(ROOT, "assets/tilesets/world_tiles.png")).convert("RGBA")
    import json
    man = json.load(open(os.path.join(ROOT, "tools/build/tiles_manifest.json")))["tiles"]
    names = ["cobble_0", "cobble_1", "cobble_2", "cobble_3"]
    for ty in range(0, H, 16):
        for tx in range(0, W, 16):
            n = names[(tx // 16 + ty // 16 * 3) % 4]
            ax, ay = man[n]["atlas"]
            tile = tiles.crop((ax * 16, ay * 16, ax * 16 + 16, ay * 16 + 16))
            cv.a[ty:ty + 16, tx:tx + 16] = np.array(tile)[: min(16, H - ty), : min(16, W - tx)]
    def sprite(path, fx, fy, fw, fh, x, y):
        im = Image.open(os.path.join(ROOT, path)).convert("RGBA").crop((fx, fy, fx + fw, fy + fh))
        c = Canvas(fw, fh)
        c.a = np.array(im)
        cv.blit(c, x, y)
    sprite("assets/sprites/props/well.png", 0, 0, 34, 46, 24, 26)
    sprite("assets/sprites/characters/orin.png", 0, 3 * 24, 16, 24, 84, 50)   # Orin facing right? use idle_right row
    # child Rowan: Pip's small body, Rowan's colours approximated by recolouring Pip
    im = Image.open(os.path.join(ROOT, "assets/sprites/characters/pip.png")).convert("RGBA").crop((0, 2 * 24, 16, 3 * 24))
    arr = np.array(im)
    hair_from = [C("hy1")[:3], C("hy2")[:3], C("hy3")[:3]]
    hair_to = [C("hb1")[:3], C("hb2")[:3], C("hb3")[:3]]
    for f, t in zip(hair_from, hair_to):
        m = (arr[:, :, 0] == f[0]) & (arr[:, :, 1] == f[1]) & (arr[:, :, 2] == f[2])
        arr[m, :3] = t
    child = Canvas(16, 24)
    child.a = arr
    cv.blit(child, 104, 52)
    # sepia + soft vignette
    for y in range(H):
        for x in range(W):
            r, g_, b, a = [int(v) for v in cv.a[y, x]]
            lum = 0.3 * r + 0.59 * g_ + 0.11 * b
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            v = max(0.0, 1.0 - (dx * dx + dy * dy) * 0.55)
            cv.a[y, x] = (int(min(255, lum * 1.15 + 30) * v), int(min(255, lum * 0.95 + 14) * v), int(lum * 0.7 * v), 255)
    return cv


# ------------------------------------------------------------ echo images ---
def _text_canvas(lines, color, scale=1, line_gap=3):
    widths = []
    for ln in lines:
        w = 0
        for ch in ln:
            if ch == " ":
                w += 3
            else:
                w += len(fontmod.G[ch][1][0]) + 1
        widths.append(w)
    W = max(widths) * scale + 4
    H = (len(lines) * (9 + line_gap)) * scale + 2
    cv = Canvas(W, H)
    for i, ln in enumerate(lines):
        x = (W - widths[i] * scale) // 2
        y0 = 1 + i * (9 + line_gap) * scale
        for ch in ln:
            if ch == " ":
                x += 3 * scale
                continue
            top, rows = fontmod.G[ch]
            for ry, r in enumerate(rows):
                for rx, c in enumerate(r):
                    if c == "#":
                        cv.rect(x + rx * scale, y0 + (top + ry) * scale, scale, scale, color)
            x += (len(rows[0]) + 1) * scale
    return cv


def _glow(cv, color):
    """Soft 1px halo behind text-like images (for additive echo reveals)."""
    out = Canvas(cv.w + 2, cv.h + 2)
    halo = (*C(color)[:3], 90)
    m = cv.mask()
    for y in range(cv.h):
        for x in range(cv.w):
            if m[y, x]:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        out.px(x + 1 + dx, y + 1 + dy, halo)
    out.blit(cv, 1, 1)
    return out


def _sheet_frame(name, col, row, fw=16, fh=24):
    im = Image.open(os.path.join(ROOT, f"assets/sprites/characters/{name}.png")).convert("RGBA")
    c = Canvas(fw, fh)
    c.a = np.array(im.crop((col * fw, row * fh, col * fw + fw, row * fh + fh)))
    return c


def echo_images():
    names = _glow(_text_canvas(["TOBIN  +  ELSIE"], "sp4"), "sp3")
    names.save("assets/sprites/fx/echo_names.png")
    ins = _glow(_text_canvas(["BEFORE THE CROWN, THE FIRE WAS BORN.",
                              "BEFORE THE FIRE, THE MOON WATCHED ALONE."], "sp4"), "sp3")
    ins.save("assets/sprites/fx/echo_inscription.png")
    sil = silhouette_canvas()
    chorus = Canvas(100, 32)
    for i, x in enumerate((0, 14, 28, 42, 56, 70, 84)):
        chorus.blit(sil, x, 1 + (i % 2) * 2)
    for y in range(chorus.h):
        for x in range(chorus.w):
            if chorus.a[y, x, 3]:
                chorus.a[y, x] = (150, 200, 240, 210)
    chorus.save("assets/sprites/fx/echo_chorus.png")
    fig = Canvas(16, 30)
    fig.blit(sil, 0, 0)
    for y in range(fig.h):
        for x in range(fig.w):
            if fig.a[y, x, 3]:
                fig.a[y, x] = (160, 210, 240, 220)
    fig.save("assets/sprites/fx/echo_figure.png")
    crowd = Canvas(100, 26)
    for i, (nm, col, row) in enumerate((("mara", 0, 0), ("alden", 0, 0), ("tobin", 0, 0), ("pip", 0, 0),
                                        ("orin", 0, 0), ("rowan", 0, 0))):
        f = _sheet_frame(nm, col, row)
        crowd.blit(f, 2 + i * 16, 1)
    crowd.save("assets/sprites/fx/echo_crowd.png")


def silhouette_canvas():
    cv = Canvas(16, 30)
    body = (40, 52, 66, 255)
    cv.ellipse(8, 5, 3.5, 4, body)
    cv.poly([(3, 28), (13, 28), (11, 9), (5, 9)], body)
    return cv


def village_backdrop():
    """Painted horizon at the top of the village map: hills and the far tower."""
    W, H = 768, 92
    cv = Canvas(W, H)
    sky(cv, "#3a3058", "#8a5a72", "#e89a68", 70)
    rng = np.random.default_rng(31)
    for _ in range(60):
        x, y = rng.integers(0, W), rng.integers(0, 30)
        cv.px(x, y, "st4" if rng.random() < 0.3 else "st3")
    ridge(cv, 58, 6, "#3a3052", 3, 0.011)
    ridge(cv, 66, 5, "#2c2642", 4, 0.019)
    tx = 400
    tcol = "#2a2440"
    cv.ellipse(tx, 30, 26, 34, mix("#e89a68", "#8a5a72", 0.4))
    cv.ellipse(tx, 78, 70, 14, "#262038")
    cv.rect(tx - 7, 22, 14, 52, tcol)
    cv.rect(tx - 9, 14, 18, 12, tcol)
    cv.poly([(tx - 11, 15), (tx, -6), (tx + 11, 15)], tcol)
    cv.vline(tx - 7, 22, 52, "#4a4068")
    cv.vline(tx - 9, 14, 12, "#4a4068")
    cv.rect(tx - 5, 17, 3, 7, "sp2")
    cv.rect(tx + 2, 17, 3, 7, "sp2")
    cv.px(tx - 4, 20, "sp3")
    cv.px(tx + 3, 20, "sp3")
    cv.rect(0, 74, W, H - 74, "#1c2a2a")
    pines(cv, 82, "#16262a", 9, hmin=8, hmax=20)
    mb = mist_band(W, 22, 8, alpha=80, color=(196, 186, 210))
    cv.blit(mb, 0, 60)
    cv.save("assets/backgrounds/village_backdrop.png")


def build_all():
    out = "assets/sprites/ui/"
    panel_dark().save(out + "panel_dark.png")
    panel_parchment().save(out + "panel_parchment.png")
    panel_small().save(out + "panel_small.png")
    portrait_frame().save(out + "portrait_frame.png")
    for pid in ("rowan", "pip", "mara", "alden", "orin", "tobin", "sentinel"):
        portrait(pid).save(f"assets/portraits/{pid}.png")
    for k in ("E", "F", "J"):
        keycap(k).save(out + f"key_{k.lower()}.png")
    keycap("ESC").save(out + "key_esc.png")
    for n in ("bell", "pin", "key", "ledger", "song", "quill", "eye", "lantern"):
        icon(n).save(out + f"icon_{n}.png")
    ic = Canvas(64, 64)
    big = icon("bell")
    for y in range(16):
        for x in range(16):
            if big.a[y, x, 3]:
                ic.rect(x * 4, y * 4, 4, 4, tuple(int(v) for v in big.a[y, x]))
    ic.save(out + "icon.png")
    symbol_bell13().save("assets/sprites/fx/symbol_bell13.png")
    song_marks("ink2").save("assets/sprites/fx/song_marks_ink.png")
    song_marks("sp3").save("assets/sprites/fx/song_marks_glow.png")
    logo().save(out + "logo.png")
    vista("dusk").save("assets/backgrounds/vista_dusk.png")
    vista("night").save("assets/backgrounds/vista_night.png")
    mist_band(480, 60, 1).save("assets/backgrounds/mist_band_a.png")
    mist_band(480, 50, 2, alpha=80).save("assets/backgrounds/mist_band_b.png")
    noise_tile().save("assets/sprites/fx/noise.png")
    radial_light().save("assets/sprites/fx/light_radial.png")
    light_shaft().save("assets/sprites/fx/light_shaft.png")
    vignette().save("assets/sprites/fx/vignette.png")
    for name, cv in particle_textures().items():
        cv.save(f"assets/sprites/fx/{name}.png")
    memory_scene().save("assets/backgrounds/memory_orin.png")
    echo_images()
    village_backdrop()


if __name__ == "__main__":
    fontmod.build(1, "dawnmere")
    build_all()
    print("ui art ok")
