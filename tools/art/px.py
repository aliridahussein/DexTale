"""Tiny pixel-art toolkit used by the asset generators.

Everything is drawn at 1:1 pixel scale into numpy RGBA arrays and saved as PNG.
Keep all colours in PAL so the whole game shares one cohesive palette.
"""
from __future__ import annotations

import os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def hexc(h: str, a: int = 255) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ---------------------------------------------------------------- palette ---
PAL = {k: hexc(v) for k, v in {
    # outlines / near blacks (purple-tinted)
    "ink": "#1b1420", "ink2": "#2b2130", "void": "#0b0910",
    # cool stone
    "st0": "#2a2f3b", "st1": "#3f4757", "st2": "#586373", "st3": "#76828f", "st4": "#9aa5b0", "st5": "#c3cbd2",
    # warm cobble
    "cb0": "#332e31", "cb1": "#4f4a4a", "cb2": "#6b6661", "cb3": "#8a847a", "cb4": "#aaa392",
    # grass
    "gr0": "#1a332d", "gr1": "#264a3c", "gr2": "#356349", "gr3": "#4a7d55", "gr4": "#6c9c62", "gr5": "#93b878",
    # foliage (deeper, cooler)
    "lf0": "#0f2224", "lf1": "#183836", "lf2": "#245044", "lf3": "#346a52", "lf4": "#4f8860", "lf5": "#76a872",
    # wood
    "wd0": "#24160f", "wd1": "#3f281c", "wd2": "#5e3c28", "wd3": "#7e5434", "wd4": "#a27146", "wd5": "#c4955e",
    # plaster
    "pl0": "#7b6e5f", "pl1": "#a3967f", "pl2": "#c6b898", "pl3": "#e0d3b2",
    # shingle roof (warm brown-red)
    "rf0": "#2e1a1a", "rf1": "#4b2924", "rf2": "#6a3a2e", "rf3": "#8a5038", "rf4": "#a86a46",
    # slate roof (blue grey)
    "sl0": "#1f2330", "sl1": "#2f3546", "sl2": "#424a5f", "sl3": "#5b6479", "sl4": "#7a8397",
    # dirt
    "dt0": "#33251d", "dt1": "#4c3829", "dt2": "#6a5039", "dt3": "#8a6a4c", "dt4": "#a98a66",
    # fire / warm light
    "fi0": "#5c1e12", "fi1": "#a63e18", "fi2": "#e0762a", "fi3": "#ffb54a", "fi4": "#ffe38a", "fi5": "#fff8d8",
    # cloth
    "rd0": "#3d1520", "rd1": "#65222e", "rd2": "#8e3640", "rd3": "#b4545a",
    "bl0": "#18213a", "bl1": "#263a62", "bl2": "#3c5a8c", "bl3": "#6286b6",
    "vi0": "#22192f", "vi1": "#3a2b4f", "vi2": "#584276", "vi3": "#7e66a0", "vi4": "#a892c4",
    "go0": "#5a3e16", "go1": "#8c6826", "go2": "#c49a3e", "go3": "#e8c86e", "go4": "#f8e8aa",
    "te0": "#1e3836", "te1": "#2c5048", "te2": "#3f6a5c", "te3": "#5a8a74",
    "cr0": "#9a8c72", "cr1": "#c4b594", "cr2": "#e4d8bc", "cr3": "#f6eedc",
    # skin
    "sk0": "#7a4632", "sk1": "#b06a4a", "sk2": "#d89870", "sk3": "#f0c098",
    "dk0": "#4a2a1c", "dk1": "#74432c", "dk2": "#9c623e", "dk3": "#bd825a",
    # hair
    "hb0": "#24160f", "hb1": "#3e2618", "hb2": "#5c3a22", "hb3": "#7c5232",  # brown
    "hy0": "#5a3a14", "hy1": "#9a6a24", "hy2": "#cc9a3a", "hy3": "#ecc670",  # straw
    "hg0": "#4a4a52", "hg1": "#7a7a84", "hg2": "#aeaeb6", "hg3": "#dcdce2",  # grey/white
    "hd0": "#140f14", "hd1": "#241a22", "hd2": "#3a2a34", "hd3": "#54404a",  # near black
    # iron
    "ir0": "#1c1d24", "ir1": "#30323c", "ir2": "#4a4d5a", "ir3": "#6c7080", "ir4": "#9a9eae",
    # spectral
    "sp0": "#12263f", "sp1": "#24507a", "sp2": "#4a8cb8", "sp3": "#86c6e2", "sp4": "#c6f0ff",
    # water
    "wa0": "#0f1e2c", "wa1": "#183248", "wa2": "#24506c", "wa3": "#3c7894", "wa4": "#78b0c8",
    # misc
    "white": "#ffffff", "black": "#000000",
    "apple": "#b8383a", "cabbage": "#7aa85a", "pumpkin": "#d07a2a",
    "flw1": "#e8d8f0", "flw2": "#c88ad8", "flw3": "#f0d060", "flw4": "#e87a7a",
}.items()}

CLEAR = (0, 0, 0, 0)


def C(name_or_tuple, a: int | None = None) -> tuple:
    if isinstance(name_or_tuple, str):
        c = hexc(name_or_tuple) if name_or_tuple.startswith("#") else PAL[name_or_tuple]
    else:
        c = tuple(int(v) for v in name_or_tuple)
    if len(c) == 3:
        c = (*c, 255)
    if a is not None:
        c = (c[0], c[1], c[2], a)
    return c


def mix(c1, c2, t: float) -> tuple:
    c1, c2 = C(c1), C(c2)
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def darken(c, f: float = 0.6) -> tuple:
    c = C(c)
    # shift shadows slightly toward purple for a painterly look
    return (int(c[0] * f * 0.98 + 6 * (1 - f)), int(c[1] * f * 0.94), int(c[2] * f + 14 * (1 - f)), c[3])


def lighten(c, f: float = 0.25) -> tuple:
    c = C(c)
    return tuple(min(255, int(c[i] + (255 - c[i]) * f)) for i in range(3)) + (c[3],)


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def dither(x: int, y: int, t: float) -> bool:
    """True when an ordered-dither threshold says to use the 'second' colour."""
    return t > BAYER4[y % 4, x % 4]


class Canvas:
    def __init__(self, w: int, h: int, fill=CLEAR):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)
        if fill != CLEAR:
            self.a[:, :] = C(fill)

    # -- basic access -----------------------------------------------------
    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def px(self, x, y, c):
        x, y = int(x), int(y)
        if self.inb(x, y):
            self.a[y, x] = C(c)

    def get(self, x, y):
        if self.inb(x, y):
            return tuple(int(v) for v in self.a[y, x])
        return CLEAR

    def opaque(self, x, y):
        return self.inb(x, y) and self.a[y, x, 3] > 0

    # -- shapes -------------------------------------------------------------
    def rect(self, x, y, w, h, c):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = C(c)

    def hline(self, x, y, w, c):
        self.rect(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.rect(x, y, 1, h, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx, cy, rx, ry, c):
        """Filled ellipse centred on (cx, cy) in pixel-centre coordinates."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx = (x + 0.5 - cx) / max(rx, 0.01)
                dy = (y + 0.5 - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.0:
                    self.px(x, y, c)

    def ellipse_mask(self, cx, cy, rx, ry):
        m = np.zeros((self.h, self.w), dtype=bool)
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        dx = (xs + 0.5 - cx) / max(rx, 0.01)
        dy = (ys + 0.5 - cy) / max(ry, 0.01)
        m[(dx * dx + dy * dy) <= 1.0] = True
        return m

    def poly(self, pts, c):
        img = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(img).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        m = np.array(img) > 127
        self.a[m] = C(c)

    def poly_mask(self, pts):
        img = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(img).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        return np.array(img) > 127

    def fill_mask(self, mask, c):
        self.a[mask] = C(c)

    # -- compositing ----------------------------------------------------------
    def blit(self, other: "Canvas", x: int, y: int, flip: bool = False):
        src = other.a[:, ::-1] if flip else other.a
        for yy in range(other.h):
            ty = y + yy
            if not 0 <= ty < self.h:
                continue
            for xx in range(other.w):
                tx = x + xx
                if not 0 <= tx < self.w:
                    continue
                s = src[yy, xx]
                if s[3] == 0:
                    continue
                if s[3] == 255:
                    self.a[ty, tx] = s
                else:
                    d = self.a[ty, tx].astype(float)
                    sa = s[3] / 255.0
                    da = d[3] / 255.0
                    oa = sa + da * (1 - sa)
                    rgb = (s[:3] * sa + d[:3] * da * (1 - sa)) / max(oa, 1e-6)
                    self.a[ty, tx] = (*[int(v) for v in rgb], int(oa * 255))

    def copy(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        c.a = self.a.copy()
        return c

    def flipped(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        c.a = self.a[:, ::-1].copy()
        return c

    def mask(self):
        return self.a[:, :, 3] > 0

    # -- finishing passes -----------------------------------------------------
    def outline(self, color="ink", sides=4, only_below_alpha=1):
        """Draw a 1px outline around opaque pixels (into transparent pixels)."""
        m = self.a[:, :, 3] >= only_below_alpha
        out = np.zeros_like(m)
        out[1:, :] |= m[:-1, :]
        out[:-1, :] |= m[1:, :]
        out[:, 1:] |= m[:, :-1]
        out[:, :-1] |= m[:, 1:]
        if sides == 8:
            out[1:, 1:] |= m[:-1, :-1]
            out[1:, :-1] |= m[:-1, 1:]
            out[:-1, 1:] |= m[1:, :-1]
            out[:-1, :-1] |= m[1:, 1:]
        out &= ~m
        self.a[out] = C(color)

    def shade_edges(self, light=None, dark=None, region=None):
        """Light pixels whose top/left neighbour is empty, darken bottom/right."""
        m = self.mask() if region is None else region
        h, w = m.shape
        res = self.a.copy()
        for y in range(h):
            for x in range(w):
                if not m[y, x]:
                    continue
                up = y > 0 and m[y - 1, x]
                lf = x > 0 and m[y, x - 1]
                dn = y < h - 1 and m[y + 1, x]
                rt = x < w - 1 and m[y, x + 1]
                if dark is not None and (not dn or not rt):
                    res[y, x] = C(dark) if not isinstance(dark, float) else darken(tuple(self.a[y, x]), dark)
                elif light is not None and (not up or not lf):
                    res[y, x] = C(light) if not isinstance(light, float) else lighten(tuple(self.a[y, x]), light)
        self.a = res

    def save(self, rel_path: str):
        path = os.path.join(ROOT, rel_path)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(self.a, "RGBA").save(path)
        return path

    def scaled_preview(self, path: str, s: int = 6, bg=(40, 40, 48, 255)):
        img = Image.fromarray(self.a, "RGBA")
        base = Image.new("RGBA", img.size, bg)
        base.alpha_composite(img)
        base.resize((self.w * s, self.h * s), Image.NEAREST).save(path)


# ------------------------------------------------------------ templates ---
def from_ascii(rows: list[str], key: dict) -> Canvas:
    """Build a canvas from ASCII art. '.' and ' ' are transparent."""
    h = len(rows)
    w = max(len(r) for r in rows)
    for r in rows:
        assert len(r) == w, f"ragged template row ({len(r)} != {w}): {r!r}"
    cv = Canvas(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            if ch not in key:
                raise KeyError(f"template char {ch!r} has no colour")
            cv.px(x, y, key[ch])
    return cv


# ---------------------------------------------------------------- noise ---
def wrap_blur(arr: np.ndarray, passes: int = 1) -> np.ndarray:
    a = arr.astype(float)
    for _ in range(passes):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


def smooth_noise(w, h, rng, passes=2):
    n = wrap_blur(rng.random((h, w)), passes)
    n = (n - n.min()) / max(n.max() - n.min(), 1e-6)
    return n


def value_noise(w, h, cell, rng, wrap=True):
    """Smooth value noise with a grid of `cell` pixels (tileable when wrap)."""
    gw, gh = max(1, w // cell), max(1, h // cell)
    grid = rng.random((gh + 1, gw + 1))
    if wrap:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    out = np.zeros((h, w))
    for y in range(h):
        for x in range(w):
            gx, gy = x / cell, y / cell
            x0, y0 = int(gx) % gw, int(gy) % gh
            tx, ty = gx - int(gx), gy - int(gy)
            tx = tx * tx * (3 - 2 * tx)
            ty = ty * ty * (3 - 2 * ty)
            a = grid[y0, x0] * (1 - tx) + grid[y0, x0 + 1] * tx
            b = grid[y0 + 1, x0] * (1 - tx) + grid[y0 + 1, x0 + 1] * tx
            out[y, x] = a * (1 - ty) + b * ty
    return out


def save_sheet(frames: list[Canvas], cols: int, rel_path: str) -> tuple[int, int]:
    fw, fh = frames[0].w, frames[0].h
    rows = (len(frames) + cols - 1) // cols
    sheet = Canvas(fw * cols, fh * rows)
    for i, f in enumerate(frames):
        sheet.blit(f, (i % cols) * fw, (i // cols) * fh)
    sheet.save(rel_path)
    return fw, fh
