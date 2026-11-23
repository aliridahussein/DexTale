"""Character sprite sheets (16x24 frames) built from ASCII templates.

A character = head template (rows 0-11) + body template (rows 12-23) + palette.
Sheet layout (4 columns): rows are animations in this order:
  idle_down, idle_up, idle_left, idle_right, walk_down, walk_up, walk_left, walk_right
idle rows use 2 frames, walk rows use 4 frames. Left = mirrored right.
"""
from __future__ import annotations

import json
import os

from px import Canvas, C, from_ascii, ROOT

FW, FH = 16, 24
ANIMS = ["idle_down", "idle_up", "idle_left", "idle_right", "walk_down", "walk_up", "walk_left", "walk_right"]

# ----------------------------------------------------------------- heads ---
# keys: o outline, h hair, H hair light, d hair dark, s skin, S skin shade, e eye, l skin light
HEADS = {
    "short": {
        "down": [
            "................",
            ".....oooooo.....",
            "....ohhHHhho....",
            "...ohhHHHhhho...",
            "..ohhhHHhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhsshhhshdo..",
            "..ohssssssssdo..",
            "..ohssessessdo..",
            "..ohssessessdo..",
            "..odsssSSsssdo..",
            "...oSssssssSo...",
        ],
        "up": [
            "................",
            ".....oooooo.....",
            "....ohhHHhho....",
            "...ohhHHHhhho...",
            "..ohhhHHhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohdhhhhhhddo..",
            "..odhdhhhhdhdo..",
            "...oddddddddo...",
        ],
        "side": [
            "................",
            ".....oooooo.....",
            "....ohhhhHHo....",
            "...ohhhhhHHHo...",
            "..ohhhhhhhHHho..",
            "..ohhhhhhhhhho..",
            "..odhhhhhhsshho.",
            "..odhhhhssssso..",
            "..odhhhsssseso..",
            "..oddhSsssseso..",
            "..oddhSssssso...",
            "...odSssssSo....",
        ],
    },
    # Pip: straw mop of hair with a cowlick
    "mop": {
        "down": [
            "......o.........",
            ".....oHoooo.....",
            "....ohHHhhho....",
            "...ohHHhhhhho...",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhhdo.",
            ".ohhshhshhshhdo.",
            "..ohssssssssdo..",
            "..ohseessseedo..",
            "..ohslsssslsdo..",
            "..odsssSSsssdo..",
            "...oSssssssSo...",
        ],
        "up": [
            "......o.........",
            ".....oHoooo.....",
            "....ohHHhhho....",
            "...ohHHhhhhho...",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhhdo.",
            ".ohhhhhhhhhhhdo.",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhdhhhhdhdo..",
            "..odhdhddhdddo..",
            "...oddddddddo...",
        ],
        "side": [
            "........o.......",
            ".....oooHo......",
            "....ohhhHHoo....",
            "...ohhhhhHHHo...",
            "..ohhhhhhhhhHo..",
            "..ohhhhhhhhhhho.",
            ".odhhhhhhshhsho.",
            "..odhhhhssssso..",
            "..odhhhsssseso..",
            "..oddhSssslsso..",
            "..oddhSssssso...",
            "...odSssssSo....",
        ],
    },
    # Mara: dark hair pulled into a bun, headband
    "bun": {
        "down": [
            "......oooo......",
            ".....ohhhdo.....",
            "....oohhddoo....",
            "...ohhhHHhhho...",
            "..ohhhHHhhhhdo..",
            "..obbbbbbbbbbo..",
            "..ohsshhhhsshdo.",
            "..ohssssssssdo..",
            "..ohseessseedo..",
            "..ohssssssssdo..",
            "..odsssSSsssdo..",
            "...oSssssssSo...",
        ],
        "up": [
            "......oooo......",
            ".....ohhhdo.....",
            "....ohhHHddo....",
            "...ohhhHHhhho...",
            "..ohhhhhhhhhdo..",
            "..obbbbbbbbbbo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..odhhhhhhhhdo..",
            "...oSddddddSo...",
        ],
        "side": [
            "..oooo..........",
            ".ohhhdooooo.....",
            ".ohhddhhhHHo....",
            "..oohhhhhHHHo...",
            "..ohhhhhhhhHho..",
            "..obbbbbbbbbbo..",
            "..odhhhhhsssho..",
            "..odhhhhssssso..",
            "..odhhhsssseso..",
            "..oddhSssssssso.",
            "..oddhSssssso...",
            "...odSssssSo....",
        ],
    },
    # Alden: monk's hood (cloth colours h/H/d come from the robe palette)
    "hood": {
        "down": [
            "................",
            ".....oooooo.....",
            "....ohHHhhho....",
            "...ohHHhhhhdo...",
            "..ohHhhhhhhhdo..",
            "..ohhkkkkkkhdo..",
            "..ohkgggggggkdo.",
            "..ohksssssskdo..",
            "..ohkseSSeskdo..",
            "..ohksssssskdo..",
            "..ohhkSSSSkhdo..",
            "..ohhhkkkkhhdo..",
        ],
        "up": [
            "................",
            ".....oooooo.....",
            "....ohHHhhho....",
            "...ohHHhhhhdo...",
            "..ohHhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..odhhhhhhhhdo..",
        ],
        "side": [
            "................",
            ".....oooooo.....",
            "....ohHHHhho....",
            "...ohhHHhhhho...",
            "..ohhhhhhhhkho..",
            "..ohhhhhhkgggo..",
            "..ohhhhhhksssso.",
            "..ohhhhhhkssseo.",
            "..ohhhhhhksssss.",
            "..ohhhhhhkSsso..",
            "..odhhhhhkkSso..",
            "..odhhhhhhkko...",
        ],
    },
    # Orin: receding white hair and a long beard (beard continues in body)
    "elder": {
        "down": [
            "................",
            "................",
            ".....oooooo.....",
            "....ollllllo....",
            "...ohllllllho...",
            "..ohhssssssshho.",
            "..ohsssssssshdo.",
            "..ohseesseesdo..",
            "..ohsSssssSshdo.",
            "..ohhHHHHHHhhdo.",
            "..ohHHHHHHHHhdo.",
            "...ohHHHHHHho...",
        ],
        "up": [
            "................",
            "................",
            ".....oooooo.....",
            "....ollllllo....",
            "...ohllllllho...",
            "..ohhhllllhhho..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..ohhhhhhhhhdo..",
            "..odhhhhhhhhdo..",
            "...odhhhhhhdo...",
        ],
        "side": [
            "................",
            "................",
            ".....oooooo.....",
            "....ohlllllo....",
            "...ohhllllsso...",
            "..ohhhhssssso...",
            "..ohhhhsssssso..",
            "..ohhhhssssseso.",
            "..ohhhhsssssSso.",
            "..ohhhhhHHHHHo..",
            "..odhhhhHHHHHo..",
            "...odhhhHHHHo...",
        ],
    },
    # Tobin: wide-brimmed lamplighter's hat
    "hat": {
        "down": [
            "................",
            "......oooo......",
            ".....oHHhho.....",
            "....oHHhhhdo....",
            "....ohhhhhdo....",
            "..oobbbbbbbboo..",
            ".oHHhhhhhhhhhdo.",
            "..oossssssssoo..",
            "..odseessseesdo.",
            "..odssssssssdo..",
            "..odsssSSsssdo..",
            "...oSsHHHHsSo...",
        ],
        "up": [
            "................",
            "......oooo......",
            ".....oHHhho.....",
            "....oHHhhhdo....",
            "....ohhhhhdo....",
            "..oobbbbbbbboo..",
            ".oHHhhhhhhhhhdo.",
            "..oodddddddooo..",
            "..odddddddddo...",
            "..odddddddddo...",
            "..oddddddddddo..",
            "...oSddddddSo...",
        ],
        "side": [
            "................",
            ".......oooo.....",
            "......oHHhho....",
            ".....oHHhhhdo...",
            ".....ohhhhhdo...",
            "...oobbbbbbbboo.",
            "..oHHhhhhhhhhhdo",
            "...oddddsssssoo.",
            "...oddddsssseso.",
            "...oddddSssssss.",
            "...oddddSsHHHo..",
            "....oddSssHHo...",
        ],
    },
}

# ----------------------------------------------------------------- bodies ---
# keys: o outline, C/c/k garment light/mid/dark, t/T under-tunic, b belt/strap,
#       B/n bag, s/S skin, P/p/q trousers, F/f boots, a/A apron, r rope
BODIES = {
    "cloak": {
        "down": [
            "..oCccSSSSccko..",
            "..oCcbttttTcko..",
            "..oCctbtttTcko..",
            "..oCcttbttTcko..",
            "..oCcbbbbbbcko..",
            ".osCcttttBBBnso.",
            "..oCcTTTTnnnko..",
            "...okPppPppko...",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....oFffFffo....",
            "....oooooooo....",
        ],
        "up": [
            "..oCccccccccko..",
            "..oCcccccccbko..",
            "..oCccccccbcko..",
            "..oCcccccbccko..",
            "..oCcbbbbbbcko..",
            ".osBBBnccccckso.",
            "..onnnccccccko..",
            "...okPppPppko...",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....oFffFffo....",
            "....oooooooo....",
        ],
        "side": [
            "....oCcSSccko...",
            "....oCcttbcko...",
            "....oCctbtcko...",
            "....oCcbttcko...",
            "....oCbbbbbko...",
            "...oCcsBBBnko...",
            "...oCcknnnkko...",
            "....okPpppko....",
            ".....oPppqo.....",
            ".....oPppqo.....",
            ".....oFfffo.....",
            ".....ooooooo....",
        ],
    },
    "child": {  # Pip: patched tunic, shorter
        "down": [
            "...oCcSSSScko...",
            "..oCcccacccko...",
            ".osCccccccckso..",
            "..oCbbbbbbbko...",
            "..oCccccaccko...",
            "...oTTTTTTTo....",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....osSoSsSo....",
            "....oFfoFffo....",
            "....oooooooo....",
            "................",
        ],
        "up": [
            "...oCcccccko....",
            "..oCcccccccko...",
            ".osCccccccckso..",
            "..oCbbbbbbbko...",
            "..oCcccccccko...",
            "...oTTTTTTTo....",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....osSoSsSo....",
            "....oFfoFffo....",
            "....oooooooo....",
            "................",
        ],
        "side": [
            ".....oCSSco.....",
            "....oCccccko....",
            "....oCcsccko....",
            "....oCbbbbko....",
            "....oCcccako....",
            ".....oTTTTo.....",
            ".....oPpqo......",
            ".....oPpqo......",
            ".....osSSo......",
            ".....oFffoo.....",
            ".....oooooo.....",
            "................",
        ],
    },
    "apron": {  # Mara: rolled sleeves, leather apron
        "down": [
            ".ooCcSSSSScko...",
            "osCcaAAAAAcCso..",
            "osSoaAaaaAaoSso.",
            "oSsoaAaaaAaosSo.",
            ".oooaAaaaAaooo..",
            "..ocaAaaaAacko..",
            "..ocaAaaaAacko..",
            "...oaAaaaAao....",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....oFffFffo....",
            "....oooooooo....",
        ],
        "up": [
            ".ooCcccccccko...",
            "osCcccacccccso..",
            "osSoCccacccoSso.",
            "oSsoCcccacckosSo",
            ".oooCcbbbbckooo.",
            "..oCcccccccko...",
            "..oCcccccccko...",
            "...oCcccccko....",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....oFffFffo....",
            "....oooooooo....",
        ],
        "side": [
            "....oCcSSSko....",
            "...oCccaAAAo....",
            "...oSsoaAaAo....",
            "...osSoaAaAo....",
            "....ooaAaaAo....",
            "....ocaAaaAo....",
            "....ocaAaaAo....",
            ".....oaAaAo.....",
            ".....oPppqo.....",
            ".....oPppqo.....",
            ".....oFfffo.....",
            ".....ooooooo....",
        ],
    },
    "robe": {  # Alden / Orin: long robe, rope belt, sleeves
        "down": [
            "..oCccSSSSccko..",
            ".oCCcccccccckko.",
            ".oCcccccccccckko",
            "oCcSscrrrrcsSkko",
            "oCcSsrcccccrSkko",
            ".oCcccccccccko..",
            ".oCccccccccckko.",
            ".oCccccccccccko.",
            ".oCcccccccccckko",
            "oCCccccccccccko.",
            "okkkkkkkkkkkkko.",
            ".ooooooooooooo..",
        ],
        "up": [
            "..oCccccccccko..",
            ".oCCcccccccckko.",
            ".oCcccccccccckko",
            "oCcSsccccccsSkko",
            "oCcSscrrrrcsSkko",
            ".oCcccccccccko..",
            ".oCccccccccckko.",
            ".oCccccccccccko.",
            ".oCcccccccccckko",
            "oCCccccccccccko.",
            "okkkkkkkkkkkkko.",
            ".ooooooooooooo..",
        ],
        "side": [
            "....oCcSScko....",
            "...oCcccccko....",
            "...oCccccckko...",
            "...oCcSScckko...",
            "...oCcSsrrkko...",
            "...oCcccccckko..",
            "...oCccccccko...",
            "...oCcccccccko..",
            "..oCcccccccckko.",
            "..oCcccccccccko.",
            "..okkkkkkkkkkko.",
            "...ooooooooooo..",
        ],
    },
    "coat": {  # Tobin: long coat over trousers
        "down": [
            "..oCccSSSSccko..",
            "..oCcctttTccko..",
            ".osCcctttTcckso.",
            ".oSCcbbbbbbckSo.",
            "..oCcctttTccko..",
            "..oCcco..occko..",
            "..okkko..okkko..",
            "...oPpqo.oPpqo..",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....oFffFffo....",
            "....oooooooo....",
        ],
        "up": [
            "..oCccccccccko..",
            "..oCccccccccko..",
            ".osCccccccccckso",
            ".oSCcbbbbbbckSo.",
            "..oCcccccccccko.",
            "..oCcccccccccko.",
            "..okkkkkkkkkkko.",
            "...oPppqPppqo...",
            "....oPpqPpqo....",
            "....oPpqPpqo....",
            "....oFffFffo....",
            "....oooooooo....",
        ],
        "side": [
            "....oCcSSccko...",
            "....oCcctTcko...",
            "....oCcsstcko...",
            "....oCbbbbbko...",
            "....oCccctcko...",
            "....oCccccccko..",
            "....okkkkkkkko..",
            ".....oPpppo.....",
            ".....oPppqo.....",
            ".....oPppqo.....",
            ".....oFfffo.....",
            ".....ooooooo....",
        ],
    },
}

# side-view stride legs (last 5 rows of the body) for walking characters
SIDE_STRIDE = {
    "cloak": [
        ["...okPpppPko....", "...oPpo.oPpo....", "..oPpo...oPpo...", "..oFfo...oFffo..", "..ooo.....oooo.."],
        ["....okPpppko....", ".....oPpPpo.....", ".....oPppqo.....", "....oFffFffo....", "....ooooooooo..."],
    ],
    "coat": [
        ["...okkPpPkko....", "...oPpo.oPpo....", "..oPpo...oPpo...", "..oFfo...oFffo..", "..ooo.....oooo.."],
        ["....okPpppko....", ".....oPpPpo.....", ".....oPppqo.....", "....oFffFffo....", "....ooooooooo..."],
    ],
    "child": [
        [".....oPpqo......", "....oPo.oPo.....", "...oPo...oPo....", "...oFo...oFfo...", "...oo.....ooo..."],
        [".....oPpqo......", ".....oPpPo......", ".....osSSo......", "....oFfoFffo....", "....oooooooo...."],
    ],
}

PALETTES = {
    "rowan": dict(h="hb2", H="hb3", d="hb1", s="sk2", S="sk1", l="sk3", e="ink",
                  C="te2", c="te1", k="te0", t="cr1", T="cr0", b="wd2", B="wd3", n="wd1",
                  P="#4e3c3a", p="#3c2e2e", q="#2a2022", F="wd1", f="wd0"),
    "pip": dict(h="hy2", H="hy3", d="hy1", s="sk2", S="sk1", l="#e8888a", e="ink",
                C="#7a8c5a", c="#5e7044", k="#465430", a="#a07a4a", t="cr1", T="#6a5a3e", b="wd2",
                P="#6a5440", p="#55402f", q="#3e2e22", F="wd2", f="wd1"),
    "mara": dict(h="hd2", H="hd3", d="hd1", s="dk2", S="dk1", l="dk3", e="ink", b="rd1",
                 C="#8a5a4a", c="#6e4436", k="#4e2e26", a="wd3", A="wd2", t="cr1",
                 P="#3e3438", p="#2e262a", q="#1e181c", F="wd1", f="wd0"),
    "alden": dict(h="#5e5468", H="#7a7088", d="#443c50", k="#2e2838", g="#3a3244",
                  s="sk2", S="sk1", e="ink", C="#6e6480", c="#564c68", r="go1"),
    "orin": dict(l="hg2", h="hg1", H="hg3", d="hg0", s="sk2", S="sk1", e="ink",
                 C="#4c5a7a", c="#38445e", k="#262e44", r="go2"),
    "tobin": dict(h="#4a3a30", H="#6a5444", d="hb1", b="rd1", s="sk2", S="sk1", e="ink",
                  C="#5a6a7a", c="#46525e", k="#323a44", t="cr1", T="cr0",
                  P="#4a3e36", p="#3a2e28", q="#281e1a", F="wd1", f="wd0"),
}

CHARACTERS = {
    # id: (head, body, palette, walks)
    "rowan": ("short", "cloak", "rowan", True),
    "pip": ("mop", "child", "pip", True),
    "mara": ("bun", "apron", "mara", False),
    "alden": ("hood", "robe", "alden", False),
    "orin": ("elder", "robe", "orin", False),
    "tobin": ("hat", "coat", "tobin", True),
}


def _clean(rows):
    # tolerate accidental spaces / non-ascii lookalikes by normalising them
    out = []
    for r in rows:
        if len(r) != FW or " " in r:
            print("  [template warning] row len", len(r), ascii(r))
        r = r.replace(" ", ".").replace("о", "o")
        r = (r + "." * FW)[:FW]
        out.append(r)
    return out


def compose(head_rows, body_rows, key) -> Canvas:
    rows = _clean(head_rows) + _clean(body_rows)
    assert len(rows) == FH, len(rows)
    full_key = {"o": "ink"}
    full_key.update(key)
    # unknown template chars (e.g. 'g' when a palette lacks it) fall back to outline
    for r in rows:
        for ch in r:
            if ch not in ". " and ch not in full_key:
                full_key[ch] = "ink"
    return from_ascii(rows, full_key)


def shift_rows(cv: Canvas, y0: int, y1: int, dy: int) -> Canvas:
    """Move rows [y0, y1) down by dy, leaving the vacated rows transparent."""
    out = cv.copy()
    block = cv.a[y0:y1].copy()
    out.a[y0:y1] = 0
    ny0 = max(0, y0 + dy)
    ny1 = min(cv.h, y1 + dy)
    src0 = ny0 - (y0 + dy)
    out.a[ny0:ny1] = block[src0:src0 + (ny1 - ny0)]
    # keep anything previously below that we did not overwrite
    if dy > 0:
        for y in range(ny1, min(cv.h, y1 + dy)):
            pass
    return out


def overlay_rows(base: Canvas, top: Canvas, y0: int, y1: int, dy: int) -> Canvas:
    """Copy rows [y0,y1) of `top` onto base shifted by dy, only opaque pixels."""
    out = base.copy()
    for y in range(y0, y1):
        ty = y + dy
        if 0 <= ty < out.h:
            m = top.a[y, :, 3] > 0
            out.a[ty, m] = top.a[y, m]
    return out


def lift_leg(cv: Canvas, cols: range, leg_top: int = 19) -> Canvas:
    """Raise one leg by 1px (front/back walk cycle)."""
    out = cv.copy()
    for x in cols:
        col = cv.a[leg_top:FH, x].copy()
        # drop one interior pants row, pull boots up, clear the last row
        new = list(col)
        if len(new) >= 4:
            del new[2]
            new.append((0, 0, 0, 0))
        for i, v in enumerate(new):
            out.a[leg_top + i, x] = v
    return out


def hem_sway(cv: Canvas, direction: int) -> Canvas:
    out = cv.copy()
    for y in (FH - 3, FH - 2, FH - 1):
        out.a[y] = 0
        row = cv.a[y]
        if direction > 0:
            out.a[y, 1:] = row[:-1]
        else:
            out.a[y, :-1] = row[1:]
    return out


def build_character(cid: str) -> dict:
    head, body, pal, walks = CHARACTERS[cid]
    key = PALETTES[pal]
    views = {}
    for d in ("down", "up", "side"):
        views[d] = compose(HEADS[head][d], BODIES[body][d], key)
    frames = {}
    for d, src in (("down", "down"), ("up", "up"), ("right", "side")):
        base = views[src]
        bob = overlay_rows(base.copy(), base, 0, 12, 1)
        # rebuild bob cleanly: blank head rows then draw head shifted 1px down
        bob = base.copy()
        bob.a[0:12] = 0
        bob = overlay_rows(bob, base, 12, FH, 0)
        bob = overlay_rows(bob, base, 0, 12, 1)
        frames[f"idle_{d}"] = [base, bob]
        if body == "robe":
            walk = [base, hem_sway(base, 1), base, hem_sway(base, -1)]
        elif d == "right" and body in SIDE_STRIDE:
            strides = []
            for legs in SIDE_STRIDE[body]:
                f = base.copy()
                f.a[FH - 5:FH] = 0
                legcv = from_ascii(_clean(legs), {**{"o": "ink"}, **key, **{ch: "ink" for ch in "".join(legs) if ch not in key and ch not in ". o"}})
                f.blit(legcv, 0, FH - 5)
                strides.append(f)
            low0 = overlay_rows(strides[0].copy(), strides[0], 0, FH - 5, 0)
            walk = [base, _bob_down(strides[0]), base, _bob_down(strides[1])]
        else:
            left = lift_leg(base, range(4, 8) if d != "up" else range(8, 12))
            right = lift_leg(base, range(8, 12) if d != "up" else range(4, 8))
            walk = [base, _bob_down(left), base, _bob_down(right)]
        frames[f"walk_{d}"] = walk
    frames["idle_left"] = [f.flipped() for f in frames["idle_right"]]
    frames["walk_left"] = [f.flipped() for f in frames["walk_right"]]
    return frames


def _bob_down(cv: Canvas) -> Canvas:
    """Upper body dips 1px on stride frames."""
    out = cv.copy()
    out.a[0:FH - 5] = 0
    out = overlay_rows(out, cv, 0, FH - 5, 1)
    out = overlay_rows(out, cv, FH - 5, FH, 0)
    return out


def save_character(cid: str, frames: dict):
    cols = 4
    sheet = Canvas(FW * cols, FH * len(ANIMS))
    for r, anim in enumerate(ANIMS):
        for c, f in enumerate(frames[anim]):
            sheet.blit(f, c * FW, r * FH)
    sheet.save(f"assets/sprites/characters/{cid}.png")
    return {"frame": [FW, FH], "anims": {a: len(frames[a]) for a in ANIMS}}


# ----------------------------------------------------- special characters ---
SENTINEL = {
    # 24x32 spectral knight (drawn in normal colours; tinted in-engine)
    "down": [
        "........................",
        "..........oooo..........",
        ".........oHHhho.........",
        "........oHHhhhho........",
        ".......oHhhhhhhdo.......",
        ".......ohhhhhhhdo.......",
        ".......okkkkkkkko.......",
        ".......oheeeeeedo.......",
        ".......ohkkkkkkdo.......",
        "......ooohhhhhdooo......",
        ".....oHHhoohhoohddo.....",
        "....oHhhhhhhhhhhhhdo....",
        "...oHhhohhhhhhhhohhdo...",
        "...ohhoochhhhhhcoohdo...",
        "...ohoo.ochhhhco.oodo...",
        "...oo...occcccco...oo...",
        "...oHo..obbbbbbo..ohdo..",
        "...ohdo.occcccco..ohdo..",
        "....oo..occcccco...oo...",
        "........occcccco........",
        ".......occcccccco.......",
        ".......occcocccco.......",
        ".......ohhho.ohhho......",
        ".......ohhho.ohhho......",
        ".......ohhdo.ohhdo......",
        ".......ohhdo.ohhdo......",
        ".......ohhdo.ohhdo......",
        "......oHhhdo.oHhhdo.....",
        "......ohhhdo.ohhhdo.....",
        "......oooooo.oooooo.....",
        "........................",
        "........................",
    ],
}


def build_sentinel():
    key = {"o": "ink", "H": "st5", "h": "st3", "d": "st1", "k": "ink2", "e": "sp4",
           "c": "#4a3f5a", "b": "go1"}
    base = from_ascii(SENTINEL["down"], key)
    # spear: a long shaft on the right side with a pale blade
    spear = Canvas(24, 32)
    spear.vline(21, 2, 28, "wd2")
    spear.vline(22, 2, 28, "wd1")
    spear.px(21, 0, "st5")
    spear.px(21, 1, "st4")
    spear.px(22, 1, "st3")
    spear.px(20, 2, "st3")
    spear.px(23, 2, "st2")
    full = Canvas(24, 32)
    full.blit(base, 0, 0)
    full.blit(spear, 0, 0)
    bob = Canvas(24, 32)
    bob.a[1:] = full.a[:-1]
    bob.a[28:] = full.a[28:]
    frames = [full, bob]
    sheet = Canvas(48, 32)
    sheet.blit(frames[0], 0, 0)
    sheet.blit(frames[1], 24, 0)
    sheet.save("assets/sprites/characters/sentinel.png")


# V2.2: the Watchman's Shadow, a spectral guard at the crossing (tinted in-engine)
WATCHMAN_SIDE = [
    "........................",
    "..........oooo..........",
    ".........oHHhhoo........",
    "........oHHhhhhdo.......",
    "........oHhhhhhdo.......",
    "........ohhhhhhdo.......",
    "........ohhhhkkko.......",
    "........ohhhhkeeo.......",
    "........ohhhhkkko.......",
    ".........ohhhhdo........",
    "........oohhhhdoo.......",
    ".......oHhhhhhhhdo......",
    ".......oHhhhhhhhdo......",
    ".......ohhhhhhhhdo......",
    ".......occcchhhhdo......",
    ".......occcchhhdo.......",
    ".......obbbbbbbo........",
    ".......occcccco.........",
    ".......occcccco.........",
    ".......occcccco.........",
    "......occcccccco........",
    "......occcccccco........",
    ".......ohhhoohhho.......",
    ".......ohhho.ohho.......",
    ".......ohhdo.ohdo.......",
    ".......ohhdo.ohdo.......",
    ".......ohhdo.ohdo.......",
    "......oHhhhdooHhhdo.....",
    "......ohhhhdoohhhdo.....",
    "......ooooooo.ooooo.....",
    "........................",
    "........................",
]


def build_watchman():
    key = {"o": "ink", "H": "st5", "h": "st3", "d": "st1", "k": "ink2", "e": "sp4",
           "c": "#3a4256", "b": "go1"}

    def lantern(cv, x, y):
        cv.rect(x, y, 4, 1, "ir2")
        cv.rect(x, y + 1, 4, 4, "sp3")
        cv.rect(x + 1, y + 2, 2, 2, "sp4")
        cv.rect(x, y + 5, 4, 1, "ir2")
        cv.px(x + 1, y - 1, "ir2")

    def spear(cv, x, y0=2, y1=30):
        cv.vline(x, y0, y1 - y0, "wd2")
        cv.vline(x + 1, y0, y1 - y0, "wd1")
        cv.px(x, y0 - 2, "st5")
        cv.px(x, y0 - 1, "st4")
        cv.px(x - 1, y0, "st3")
        cv.px(x + 2, y0, "st2")

    def bob(cv):
        b = Canvas(24, 32)
        b.a[1:] = cv.a[:-1]
        b.a[28:] = cv.a[28:]
        return b

    front = from_ascii(SENTINEL["down"], key)
    down = Canvas(24, 32)
    down.blit(front, 0, 0)
    spear(down, 21)
    lantern(down, 2, 18)
    back_rows = list(SENTINEL["down"])
    for r in (6, 7, 8):
        back_rows[r] = back_rows[r].replace("k", "h").replace("e", "h")
    up = Canvas(24, 32)
    up.blit(from_ascii(back_rows, key), 0, 0)
    spear(up, 21)
    lantern(up, 2, 18)
    up = up.flipped()
    side = Canvas(24, 32)
    side.blit(from_ascii(WATCHMAN_SIDE, key), 0, 0)
    lantern(side, 16, 16)
    spear(side, 20)
    lowered = Canvas(24, 32)
    lowered.blit(front, 0, 0)
    lowered.line(14, 29, 23, 13, "wd2")       # the spear lowered, tip to the ground
    lowered.line(15, 29, 23, 14, "wd1")
    lowered.px(13, 30, "st4")
    lantern(lowered, 2, 18)
    rows = [[down, bob(down)], [up, bob(up)], [side, bob(side)], [side.flipped(), bob(side.flipped())],
            [lowered]]
    sheet = Canvas(48, 32 * len(rows))
    for r, frames in enumerate(rows):
        for c, f in enumerate(frames):
            sheet.blit(f, c * 24, r * 32)
    sheet.save("assets/sprites/characters/watchman.png")


CAT = {
    "side": [
        "................",
        "................",
        "................",
        "................",
        "............o.o.",
        "...........oKoKo",
        "o.........oKkkko",
        "Ko........okekeo",
        ".Ko......okkkkko",
        ".oKoooooookkkkko",
        "..oKkkkkkkkkkko.",
        "..oKkkkkkkkkko..",
        "..okkoookkookko.",
        "..oko...oko.oko.",
        "..oo....oo...oo.",
        "................",
    ],
}


def build_cat():
    key = {"o": "ink", "K": "#5a5060", "k": "#3e3644", "e": "go3"}
    side = from_ascii(CAT["side"], key)
    # walk: alternate legs by nudging the bottom two rows
    walk2 = side.copy()
    walk2.a[13:15] = 0
    for y in (13, 14):
        row = side.a[y]
        walk2.a[y, 1:] = row[:-1]
    sit = side.copy()
    frames = [side, walk2, sit, side]
    sheet = Canvas(16 * 4, 16 * 2)
    for i, f in enumerate(frames):
        sheet.blit(f, i * 16, 0)
        sheet.blit(f.flipped(), i * 16, 16)
    sheet.save("assets/sprites/characters/cat.png")


def build_all():
    meta = {}
    for cid in CHARACTERS:
        frames = build_character(cid)
        meta[cid] = save_character(cid, frames)
    build_sentinel()
    meta["sentinel"] = {"frame": [24, 32], "anims": {"idle_down": 2}}
    build_cat()
    meta["cat"] = {"frame": [16, 16], "anims": {"walk_right": 2, "walk_left": 2}}
    build_watchman()
    meta["watchman"] = {"frame": [24, 32], "anims": {"walk_down": 2, "walk_up": 2, "walk_right": 2,
                                                     "walk_left": 2, "lowered": 1}}
    path = os.path.join(ROOT, "tools", "build", "characters_manifest.json")
    with open(path, "w") as f:
        json.dump(meta, f, indent=1)
    return meta


if __name__ == "__main__":
    print(build_all())
