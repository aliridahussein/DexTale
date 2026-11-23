"""Procedural audio for THE THIRTEENTH BELL (all original, generated from code).

Writes 16-bit mono WAV files into assets/audio/{music,ambience,sfx}.
Music and ambience carry a RIFF 'smpl' loop chunk, which Godot's WAV importer
detects (edit/loop_mode = "Detect From WAV") so they loop seamlessly.

Run:  python generate_audio.py            (everything)
      python generate_audio.py sfx        (one category: sfx | music | ambience)
"""
from __future__ import annotations

import math
import os
import struct
import sys

import numpy as np
from scipy import signal

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RNG = np.random.default_rng(13)

# ================================================================ basics ===
NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(note: str) -> float:
    name, octave = (note[:-1], int(note[-1]))
    midi = 12 * (octave + 1) + NOTE_INDEX[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


def tline(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def env(n: int, attack: float, release: float, curve: float = 1.0) -> np.ndarray:
    e = np.ones(n)
    a = min(n, max(1, int(attack * SR)))
    r = min(n - a, max(1, int(release * SR)))
    e[:a] = np.linspace(0, 1, a) ** curve
    if r > 0:
        e[n - r:] *= np.linspace(1, 0, r) ** curve
    return e


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, min(cutoff, SR * 0.45), "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def noise(dur: float) -> np.ndarray:
    return RNG.standard_normal(int(dur * SR))


def reverb(x: np.ndarray, seconds: float = 2.2, wet: float = 0.3, tone: float = 4500.0, pre: float = 0.012) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = RNG.standard_normal(n) * np.exp(-t * (6.9 / seconds))
    ir = lowpass(ir, tone)
    ir[: int(pre * SR)] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    w = signal.fftconvolve(x, ir)
    out = np.zeros(len(x) + n)
    out[: len(x)] += x * (1.0 - wet * 0.5)
    out[: len(w)] += w * wet
    return out


def place(buf: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sound))
    buf[i:j] += sound[: j - i] * gain


def fold_loop(y: np.ndarray, length: float) -> np.ndarray:
    """Add everything past `length` back onto the start (seamless loop)."""
    n = int(length * SR)
    out = y[:n].copy()
    tail = y[n:]
    k = 0
    while len(tail) > 0:
        m = min(n, len(tail))
        out[:m] += tail[:m]
        tail = tail[m:]
        k += 1
    return out


def normalize(x: np.ndarray, peak_db: float) -> np.ndarray:
    p = np.max(np.abs(x)) + 1e-9
    return x / p * (10 ** (peak_db / 20))


def write_wav(rel: str, x: np.ndarray, loop: bool = False):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(x, -1.0, 1.0)
    data = (pcm * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if loop:
        # manufacturer, product, period, unity note, pitch frac, smpte fmt, smpte off, n loops, sampler data
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, len(pcm), 0, 0)  # cue id, type forward, start, end, frac, count
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    riff = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    with open(path, "wb") as f:
        f.write(riff)
    rms = 20 * math.log10(np.sqrt(np.mean(pcm ** 2)) + 1e-9)
    print(f"  {rel:46s} {len(pcm) / SR:6.2f}s  rms {rms:6.1f} dB{'  (loop)' if loop else ''}")


# =========================================================== instruments ===
def pluck(f: float, dur: float = 1.6, bright: float = 1.0) -> np.ndarray:
    """Lute-like plucked string (additive, higher partials die faster)."""
    t = tline(dur)
    y = np.zeros_like(t)
    for k in range(1, 14):
        fk = f * k * (1 + 0.0007 * k * k)
        if fk > SR * 0.45:
            break
        amp = (1.0 / k ** 1.15) * (bright if k > 3 else 1.0)
        y += amp * np.sin(2 * np.pi * fk * t + RNG.random() * 0.3) * np.exp(-t * (1.8 + 0.85 * k))
    y *= env(len(t), 0.003, 0.05)
    return y


def flute(f: float, dur: float, vib: float = 0.004) -> np.ndarray:
    t = tline(dur)
    v = 1 + vib * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.4, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(v) / SR
    y = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph) + 0.03 * np.sin(4 * ph)
    breath = lowpass(highpass(noise(dur), 1200), 4000) * 0.035
    y = (y + breath) * env(len(t), 0.07, min(0.2, dur * 0.4), 1.2)
    return y


def voice_hum(f: float, dur: float, glide_from: float | None = None) -> np.ndarray:
    """Closed-mouth hum: warm, low-passed, gentle vibrato, optional glide."""
    t = tline(dur)
    freq = np.full_like(t, f)
    if glide_from:
        g = np.clip(t / 0.07, 0, 1)
        freq = glide_from + (f - glide_from) * g
    freq *= 1 + 0.006 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    y = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph) + 0.08 * np.sin(4 * ph)
    y = lowpass(y, 1400)
    return y * env(len(t), 0.06, min(0.12, dur * 0.3))


def pad(freqs, dur: float, cutoff: float = 1600, attack: float = 1.2, release: float = 1.6, detune: float = 0.004):
    t = tline(dur)
    y = np.zeros_like(t)
    for f in freqs:
        for d in (-detune, 0.0, detune):
            fd = f * (1 + d)
            for k in range(1, 9):
                if fd * k > SR * 0.45:
                    break
                y += (0.6 / k) * np.sin(2 * np.pi * fd * k * t + RNG.random() * 6.28)
    y = lowpass(y, cutoff, 2)
    trem = 1 + 0.06 * np.sin(2 * np.pi * 0.23 * t + RNG.random() * 6)
    return y * trem * env(len(t), attack, release, 1.4) / (len(freqs) * 3)


def organ(freqs, dur: float, attack: float = 0.4, release: float = 1.2):
    t = tline(dur)
    y = np.zeros_like(t)
    for f in freqs:
        for mult, amp in ((0.5, 0.5), (1, 1.0), (2, 0.5), (3, 0.18), (4, 0.25), (6, 0.08)):
            y += amp * np.sin(2 * np.pi * f * mult * t)
    y = lowpass(y, 2400)
    return y * env(len(t), attack, release, 1.3) / (len(freqs) * 2.5)


FORMANTS_A = ((730, 90, 1.0), (1090, 110, 0.5), (2440, 160, 0.25))
FORMANTS_O = ((450, 80, 1.0), (800, 90, 0.45), (2830, 160, 0.1))


def choir(f: float, dur: float, formants=FORMANTS_A, voices: int = 4) -> np.ndarray:
    t = tline(dur)
    y = np.zeros_like(t)
    for v in range(voices):
        det = 1 + (v - voices / 2) * 0.0035
        rate = 4.6 + v * 0.37
        freq = f * det * (1 + 0.007 * np.sin(2 * np.pi * rate * t + v))
        ph = 2 * np.pi * np.cumsum(freq) / SR
        k = 1
        while f * k < 4200:
            fk = f * k
            amp = sum(a * math.exp(-((fk - fc) / bw) ** 2 * 0.5) for fc, bw, a in formants) + 0.02 / k
            y += amp * np.sin(k * ph)
            k += 1
    y += lowpass(bandpass(noise(dur), 500, 3000), 3000) * 0.015
    return y * env(len(t), 0.35, min(0.6, dur * 0.4), 1.3) / voices


def glass(f: float, dur: float = 3.0) -> np.ndarray:
    t = tline(dur)
    y = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.01 * t) * np.exp(-t * 2)
    return y * np.exp(-t * 1.1) * env(len(t), 0.02, 0.3)


BELL_MINOR = ((0.5, 1.0, 9.0), (1.0, 0.75, 6.5), (1.19, 0.55, 4.5), (1.5, 0.32, 3.4), (2.0, 0.7, 3.0),
              (2.5, 0.22, 2.0), (2.67, 0.18, 1.7), (3.0, 0.22, 1.4), (4.0, 0.14, 0.9), (5.34, 0.07, 0.55))
BELL_MAJOR = ((0.5, 1.0, 11.0), (1.0, 0.8, 8.0), (1.25, 0.6, 6.0), (1.5, 0.38, 5.0), (2.0, 0.6, 4.0),
              (2.5, 0.25, 3.0), (3.0, 0.2, 2.2), (4.0, 0.1, 1.2))


def bell(f: float, dur: float, partials=BELL_MINOR, strike: float = 1.0, beat: float = 0.45,
         decay_scale: float = 1.0) -> np.ndarray:
    t = tline(dur)
    y = np.zeros_like(t)
    for ratio, amp, dec in partials:
        fr = f * ratio
        if fr > SR * 0.45:
            continue
        for b in (-beat, beat):
            y += 0.5 * amp * np.sin(2 * np.pi * (fr + b) * t + RNG.random()) * np.exp(-t / (dec * decay_scale))
    if strike > 0:
        hit = bandpass(noise(0.06), 1500, 6000) * np.exp(-np.arange(int(0.06 * SR)) / SR * 70)
        y[: len(hit)] += hit * 0.6 * strike
    return y * env(len(t), 0.002, 0.3)


# ================================================= the gathering song ===
# Pitch steps must match the thirteen marks drawn in the ledger (ui_art.SONG_NOTES).
SONG_STEPS = [2, 3, 4, 3, 5, 4, 2, 1, 2, 4, 3, 1, 0]
SONG_SCALE = ["D4", "F4", "G4", "A4", "C5", "D5"]
SONG_BEATS = [1, 1, 1.5, 0.5, 2, 1, 1, 2, 1, 1, 1.5, 0.5, 3]
SONG_RESTS = {7: 1.0}  # a breath after the eighth note ("a rest, and home")


def song_events(start: float, beat: float, octave_shift: int = 0, scale: list[str] | None = None):
    sc = scale or SONG_SCALE
    out = []
    t = start
    for i, (step, b) in enumerate(zip(SONG_STEPS, SONG_BEATS)):
        f = hz(sc[step]) * (2 ** octave_shift)
        out.append((t, f, b * beat))
        t += b * beat + SONG_RESTS.get(i, 0) * beat
    return out, t


# =================================================================== sfx ===
def sfx_all():
    out = {}
    # footsteps
    def step(lo, hi, dur, thud=0.0, click=0.0, decay=60.0):
        n = int(dur * SR)
        e = np.exp(-np.arange(n) / SR * decay)
        y = bandpass(noise(dur), lo, hi) * e
        if thud:
            y += np.sin(2 * np.pi * 90 * tline(dur)) * np.exp(-np.arange(n) / SR * 40) * thud
        if click:
            y[: int(0.004 * SR)] += RNG.standard_normal(int(0.004 * SR)) * click
        return y
    out["step_grass"] = step(500, 3800, 0.09, decay=45)
    out["step_stone"] = step(1200, 5000, 0.06, thud=0.5, click=0.6, decay=90)
    out["step_dirt"] = step(200, 1600, 0.08, thud=0.4, decay=55)
    out["step_cloth"] = step(150, 900, 0.07, decay=50)
    t = tline(0.1)
    out["step_wood"] = (np.sin(2 * np.pi * 190 * t) * np.exp(-t * 45) + bandpass(noise(0.1), 300, 2000) * np.exp(-t * 70) * 0.6)
    # ui
    t = tline(0.05)
    out["blip"] = (np.sin(2 * np.pi * 620 * t) + 0.3 * np.sin(2 * np.pi * 1240 * t)) * np.exp(-t * 70)
    t = tline(0.04)
    out["ui_move"] = np.sin(2 * np.pi * 1320 * t) * np.exp(-t * 110)
    def chime(notes, gap, dur=0.5, partials=((1, 1.0), (2.0, 0.3), (3.0, 0.12))):
        y = np.zeros(int((gap * len(notes) + dur) * SR))
        for i, n in enumerate(notes):
            tt = tline(dur)
            s = sum(a * np.sin(2 * np.pi * hz(n) * m * tt) for m, a in partials) * np.exp(-tt * 7)
            place(y, s * env(len(tt), 0.004, 0.05), i * gap)
        return y
    out["ui_confirm"] = chime(["E5", "A5"], 0.07, 0.35)
    out["ui_back"] = chime(["A5", "E5"], 0.07, 0.3)
    out["ui_open"] = reverb(chime(["D5", "A5", "D6"], 0.05, 0.4), 0.8, 0.25)
    out["item"] = reverb(chime(["A5", "D6", "F6"], 0.06, 0.5), 1.2, 0.3)
    out["item_get"] = reverb(chime(["D5", "F5", "A5", "D6"], 0.09, 0.9, BELL_PARTIALS_SOFT), 1.6, 0.35)
    out["success"] = reverb(chime(["D5", "A5", "F6", "A6"], 0.11, 1.0, BELL_PARTIALS_SOFT), 1.8, 0.35)
    # paper
    d = 0.32
    y = highpass(noise(d), 1800) * 0.5
    bumps = np.zeros(int(d * SR))
    for at in (0.0, 0.07, 0.15, 0.22):
        place(bumps, np.hanning(int(0.07 * SR)), at)
    out["page"] = lowpass(y * bumps, 7000)
    # echo listen: rising shimmer then a soft ping
    d = 1.4
    y = np.zeros(int(d * SR))
    tt = tline(0.9)
    for f in (880, 1174, 1568, 1975, 2637):
        sw = np.sin(2 * np.pi * f * (1 + 0.04 * tt) * tt) * (tt / 0.9) ** 2.2
        place(y, sw * 0.25, 0.0)
    place(y, lowpass(highpass(noise(0.9), 2500), 7000) * (tt / 0.9) ** 3 * 0.25, 0.0)
    place(y, bell(hz("A5"), 0.5, BELL_PARTIALS_SOFT_T, strike=0.0) * 0.6, 0.9)
    out["echo_listen"] = reverb(y, 2.0, 0.45)
    # whisper: formant-filtered breath in syllable bursts
    d = 1.6
    y = np.zeros(int(d * SR))
    for i, at in enumerate((0.0, 0.25, 0.42, 0.7, 0.95, 1.15)):
        ln = RNG.uniform(0.12, 0.22)
        b = noise(ln)
        lo, hi = RNG.choice([(500, 1400), (900, 2600), (1600, 3800)])
        place(y, bandpass(b, lo, hi) * np.hanning(len(b)) * 0.5, at)
    out["echo_whisper"] = reverb(lowpass(y, 4000), 2.4, 0.55)
    # doors / gate / stone
    tt = tline(0.6)
    out["door"] = lowpass(np.sin(2 * np.pi * 70 * tt) * np.exp(-tt * 12) + bandpass(noise(0.6), 200, 1200) * np.exp(-tt * 18) * 0.7, 2500)
    d = 1.3
    y = np.zeros(int(d * SR))
    for k in range(14):
        place(y, bandpass(noise(0.03), 2500, 7000) * np.exp(-np.arange(int(0.03 * SR)) / SR * 120), RNG.uniform(0, 0.6), 0.5)
    tt = tline(0.9)
    creak = np.sin(2 * np.pi * (180 + 60 * np.sin(2 * np.pi * 1.3 * tt)) * tt) * env(len(tt), 0.1, 0.3) * 0.3
    place(y, bandpass(creak + 0.2 * noise(0.9), 150, 1200), 0.4)
    out["gate"] = reverb(y, 1.0, 0.2)
    d = 2.2
    tt = tline(d)
    grind = lowpass(noise(d), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * tt)) * env(len(tt), 0.2, 0.6)
    out["door_stone"] = reverb(grind + np.sin(2 * np.pi * 45 * tt) * env(len(tt), 0.3, 0.8) * 0.4, 1.6, 0.4)
    # Pip's humming (the Gathering Song)
    out["hum"] = reverb(hum_phrase(0.42, 6), 1.2, 0.2)
    out["hum_slow"] = reverb(hum_phrase(0.55, 13), 1.4, 0.25)
    # forge
    tt = tline(1.0)
    clang = sum(a * np.sin(2 * np.pi * 690 * r * tt) * np.exp(-tt / dcy) for r, a, dcy in
                ((1.0, 1.0, 0.45), (2.76, 0.6, 0.25), (5.40, 0.35, 0.12), (8.93, 0.2, 0.07)))
    clang[: int(0.01 * SR)] += RNG.standard_normal(int(0.01 * SR)) * 0.8
    out["anvil"] = reverb(clang, 0.9, 0.15)
    tt = tline(0.7)
    out["clank"] = reverb(sum(a * np.sin(2 * np.pi * 220 * r * tt) * np.exp(-tt / dcy) for r, a, dcy in
                              ((1.0, 1.0, 0.25), (2.3, 0.5, 0.15), (4.1, 0.3, 0.08))) +
                          lowpass(noise(0.7), 800) * np.exp(-tt * 14) * 0.7, 1.2, 0.3)
    # seals
    tt = tline(0.6)
    out["seal_press"] = reverb(lowpass(noise(0.6), 400) * np.exp(-tt * 9) * 0.8 +
                               bell(hz("D5"), 0.6, BELL_PARTIALS_SOFT_T, strike=0.3) * 0.5, 1.4, 0.35)
    tt = tline(0.8)
    out["seal_wrong"] = reverb(np.sin(2 * np.pi * (110 - 30 * tt) * tt) * np.exp(-tt * 4) +
                               lowpass(noise(0.8), 300) * np.exp(-tt * 8) * 0.6, 1.2, 0.3)
    d = 2.2
    y = np.zeros(int(d * SR))
    for i, n in enumerate(["D4", "F#4", "A4", "D5"]):
        place(y, bell(hz(n), 1.8, BELL_MAJOR, strike=0.3) * 0.4, i * 0.12)
    tt = tline(d)
    y += lowpass(noise(d), 200) * env(len(tt), 0.3, 1.0) * 0.4
    out["seal_solved"] = reverb(y, 2.4, 0.4)
    # mist / sentinel
    tt = tline(1.0)
    out["mist_warn"] = bandpass(noise(1.0), 1500, 5000) * (tt ** 2) * 0.6
    tt = tline(0.9)
    out["mist_pulse"] = reverb(lowpass(noise(0.9), 1800) * np.exp(-((tt - 0.12) / 0.18) ** 2) +
                               bandpass(noise(0.9), 600, 2400) * np.exp(-tt * 5) * 0.4, 1.4, 0.35)
    tt = tline(0.8)
    hit = np.sin(2 * np.pi * 60 * tt) * np.exp(-tt * 9) + lowpass(noise(0.8), 700) * np.exp(-tt * 10) * 0.8
    out["mist_hit"] = reverb(hit, 1.6, 0.45)
    tt = tline(1.4)
    groan = np.sin(2 * np.pi * (62 + 6 * np.sin(2 * np.pi * 0.8 * tt)) * tt) * env(len(tt), 0.3, 0.6)
    groan += bandpass(noise(1.4), 200, 700) * env(len(tt), 0.2, 0.8) * 0.5
    out["sentinel"] = reverb(groan, 2.2, 0.5)
    tt = tline(2.2)
    shimmer = sum(np.sin(2 * np.pi * f * tt) * 0.25 for f in (1318, 1760, 2349)) * (1 - tt / 2.2) * (tt / 2.2) * 4
    out["sentinel_fade"] = reverb(shimmer + highpass(noise(2.2), 3000) * (1 - tt / 2.2) * 0.1, 2.6, 0.55)
    tt = tline(2.2)
    gust = bandpass(noise(2.2), 300, 1600) * np.sin(np.pi * tt / 2.2) ** 2
    out["wind_gust"] = gust
    tt = tline(0.45)
    out["lantern"] = lowpass(noise(0.45), 900) * np.exp(-((tt - 0.06) / 0.08) ** 2) + \
        np.sin(2 * np.pi * 330 * tt) * np.exp(-tt * 12) * 0.15
    # bells
    out["bell_toll"] = reverb(bell(hz("D3"), 7.0, BELL_MINOR, strike=1.0, decay_scale=1.3), 3.0, 0.4)
    far = bell(hz("D3"), 4.5, BELL_MINOR, strike=0.6, decay_scale=0.9)
    out["bell_toll_far"] = reverb(lowpass(far, 1400), 3.2, 0.6)
    hum_b = bell(hz("D3"), 3.4, BELL_MINOR, strike=0.0, beat=2.6, decay_scale=0.8) * env(int(3.4 * SR), 0.4, 0.6)
    out["bell_hum"] = reverb(hum_b, 2.5, 0.45)
    crack = bell(hz("D3"), 5.0, BELL_MINOR, strike=1.4, beat=6.0, decay_scale=0.45)
    tt = tline(5.0)
    crack += highpass(noise(5.0), 1200) * np.exp(-tt * 9) * 0.9
    for k in range(12):
        place(crack, bandpass(noise(0.03), 2000, 8000) * np.exp(-np.arange(int(0.03 * SR)) / SR * 90),
              0.4 + RNG.uniform(0, 1.8), 0.4)
    out["bell_crack"] = reverb(crack, 2.6, 0.4)
    warm = bell(hz("D3"), 8.0, BELL_MAJOR, strike=0.4, decay_scale=1.4)
    place(warm, choir(hz("D4"), 6.0, FORMANTS_O), 0.3, 0.35)
    place(warm, choir(hz("F#4"), 6.0, FORMANTS_O), 0.3, 0.25)
    out["bell_warm"] = reverb(warm, 3.4, 0.45)
    # ethereal
    d = 3.0
    y = np.zeros(int(d * SR))
    for n in ("D4", "F4", "A4", "E5"):
        place(y, choir(hz(n), 2.8, FORMANTS_O, 3) * 0.5, 0.0)
    tt = tline(d)
    y += sum(np.sin(2 * np.pi * f * tt) * 0.06 for f in (2349, 2794)) * env(len(tt), 1.2, 1.0)
    out["orin_appear"] = reverb(y, 3.0, 0.5)
    d = 2.6
    y = np.zeros(int(d * SR))
    for i, f in enumerate((2637, 2349, 1976, 1760, 1318, 1175)):
        place(y, glass(f, 1.4) * 0.3, i * 0.18)
    out["memory_fade"] = reverb(y, 2.8, 0.55)
    out.update(sfx_v2())
    return out


def sfx_v2():
    """Sounds added in Prototype V2. The shared RNG state is saved and restored
    so every V1 sound and track still regenerates bit-identically."""
    state = RNG.bit_generator.state
    out = {}
    # the Chorus ritual: one sung bell tone, pitched in game to each note of the
    # Gathering Song (D4 is the song's lowest step), and a sour clash for a wrong note
    note = bell(hz("D4"), 2.4, BELL_MAJOR, strike=0.5, beat=0.3, decay_scale=0.55)
    place(note, choir(hz("D4"), 1.8, FORMANTS_O, 3) * 0.35, 0.02)
    out["ritual_note"] = reverb(note, 2.2, 0.35)
    sour = bell(hz("D4"), 1.6, BELL_MINOR, strike=0.8, beat=7.0, decay_scale=0.35)
    sour += bell(hz("D#4"), 1.6, BELL_MINOR, strike=0.0, beat=5.0, decay_scale=0.3) * 0.7
    out["ritual_sour"] = reverb(lowpass(sour, 2600), 1.8, 0.3)
    # the reconstructed memory at the well: a warm, low swell
    d = 2.8
    y = np.zeros(int(d * SR))
    for i, n in enumerate(("D4", "A4", "F#4")):
        place(y, choir(hz(n), 2.4, FORMANTS_O, 3) * 0.45, i * 0.22)
    place(y, glass(hz("D6"), 2.0) * 0.12, 0.6)
    out["memory_warm"] = reverb(y, 3.0, 0.5)
    # ---- V2.2: the Watchman's Crossing (appended after V2's sounds so those stay identical)
    d = 0.7                                        # a rotten plank giving under a boot
    tt = tline(d)
    f = 170 - 60 * tt / d
    creak = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * tt))
    creak = creak * np.exp(-tt * 3.5) * 0.6 + bandpass(noise(d), 300, 1400) * np.exp(-tt * 6) * 0.5
    out["creak"] = reverb(creak, 0.8, 0.2)
    d = 0.9                                        # chain links rattling over iron
    y = np.zeros(int(d * SR))
    for k in range(14):
        clink = bandpass(noise(0.05), 2200, 7000) * np.exp(-np.arange(int(0.05 * SR)) / SR * 80)
        place(y, clink, k * 0.055 + RNG.uniform(0, 0.02), 0.6 + RNG.uniform(0, 0.4))
    out["chain_rattle"] = reverb(y, 1.0, 0.25)
    d = 0.09                                       # one tooth of the winch's ratchet
    tt = tline(d)
    out["winch_click"] = bandpass(noise(d), 1200, 5000) * np.exp(-tt * 70) + \
        np.sin(2 * np.pi * 880 * tt) * np.exp(-tt * 60) * 0.3
    d = 1.4                                        # the Shadow notices: a thin rising tone
    tt = tline(d)
    f = 330 + 180 * tt / d
    tone = sum(np.sin(2 * np.pi * np.cumsum(f * r) / SR) * a for r, a in ((1.0, 0.5), (1.007, 0.4), (2.01, 0.12)))
    out["shadow_alert"] = reverb(tone * env(len(tt), 0.25, 0.6), 2.4, 0.5)
    d = 1.6                                        # the drawbridge landing on the far bank
    tt = tline(d)
    thud = np.sin(2 * np.pi * 52 * tt) * np.exp(-tt * 5) + lowpass(noise(d), 500) * np.exp(-tt * 9) * 0.8
    for k in range(5):
        place(thud, bandpass(noise(0.06), 600, 2400) * np.exp(-np.arange(int(0.06 * SR)) / SR * 50),
              0.12 + k * 0.09, 0.5)
    out["bridge_thud"] = reverb(thud, 1.8, 0.3)
    RNG.bit_generator.state = state
    return out


BELL_PARTIALS_SOFT = ((1, 1.0), (2.0, 0.35), (2.76, 0.12), (4.0, 0.06))
BELL_PARTIALS_SOFT_T = ((1.0, 1.0, 0.7), (2.0, 0.35, 0.45), (3.0, 0.12, 0.25), (4.2, 0.06, 0.15))


def hum_phrase(beat: float, count: int) -> np.ndarray:
    evts, end = song_events(0.0, beat)
    evts = evts[:count]
    total = (evts[-1][0] + evts[-1][2]) + 0.4
    y = np.zeros(int(total * SR))
    prev = None
    for (at, f, d) in evts:
        f = f / 2 * 2  # Pip's register
        place(y, voice_hum(f, d + 0.05, glide_from=prev), at)
        prev = f
    return y


# ================================================================= music ===
def render(length: float, events, tail: float = 4.0, rev=(2.6, 0.32, 4000)) -> np.ndarray:
    buf = np.zeros(int((length + tail) * SR))
    for (at, sound, gain) in events:
        place(buf, sound, at, gain)
    wet = reverb(buf, *rev)
    return fold_loop(wet, length)


CHORDS = {
    "Dm": ["D3", "A3", "D4", "F4"], "Bb": ["Bb2", "F3", "Bb3", "D4"], "F": ["F2", "C3", "F3", "A3"],
    "C": ["C3", "G3", "C4", "E4"], "Gm": ["G2", "D3", "G3", "Bb3"], "A": ["A2", "E3", "A3", "C#4"],
    "Am": ["A2", "E3", "A3", "C4"], "G": ["G2", "D3", "G3", "B3"], "D": ["D3", "A3", "D4", "F#4"],
    "Dsus": ["D3", "A3", "D4", "G4"],
}


def arpeggio(chord: str, start: float, bar: float, pattern=(0, 1, 2, 3, 2, 1), gain=0.32, bright=0.8):
    notes = CHORDS[chord]
    ev = []
    step = bar / len(pattern)
    for i, p in enumerate(pattern):
        ev.append((start + i * step, pluck(hz(notes[p]) * 2, 2.2, bright), gain * (1.0 if i == 0 else 0.8)))
    return ev


def music_title():
    bpm, bars = 60.0, ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"]
    bar = 4 * 60 / bpm
    L = bar * len(bars)
    ev = []
    for i, c in enumerate(bars):
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c]], bar + 1.6, 1400, 1.5, 1.8), 0.9))
    song, _ = song_events(bar * 1.0, 60 / bpm * 1.0, 0)
    for (at, f, d) in song:
        ev.append((at, flute(f, d * 1.05), 0.33))
    for at in (0.0, bar * 4):
        ev.append((at, lowpass(bell(hz("D3"), 5.0, BELL_MINOR, 0.4), 1600), 0.22))
    return render(L, ev, 5.0, (3.2, 0.42, 3800))


def music_village():
    bpm = 84.0
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Dm", "C", "Bb", "C", "Dm", "C", "Bb", "A"] * 2
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev += arpeggio(c, i * bar, bar, (0, 1, 2, 3, 2, 1, 2, 3), 0.26)
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c][:3]], bar + 1.2, 1100, 0.8, 1.4), 0.5))
    # the melody's opening, half-remembered, once per cycle
    song, _ = song_events(bar * 8, beat, 1, None)
    for (at, f, d) in song[:7]:
        ev.append((at, flute(f / 2, d * 1.02, 0.005), 0.26))
    return render(L, ev, 4.0, (2.2, 0.3, 4200))


def music_chapel():
    prog = ["Dm", "Gm", "Bb", "A", "Dm", "Bb", "Gm", "A"]
    bar = 5.0
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev.append((i * bar, organ([hz(n) for n in CHORDS[c]], bar + 1.0, 0.8, 1.5), 0.85))
    for i in (1, 3, 5, 7):
        ev.append((i * bar + 2.5, choir(hz(CHORDS[prog[i]][2]) , 2.6, FORMANTS_O, 3), 0.12))
    return render(L, ev, 6.0, (4.5, 0.55, 3000))


def music_mist():
    L = 40.0
    ev = []
    t = tline(L + 2)
    drone = (np.sin(2 * np.pi * hz("D2") * t) + 0.5 * np.sin(2 * np.pi * hz("Ab2") * t * 1.0007)) * \
        (0.6 + 0.4 * np.sin(2 * np.pi * t / L * 2))
    ev.append((0.0, lowpass(drone, 400) * 0.6, 1.0))
    sw = lowpass(noise(L + 2), 700) * (0.5 + 0.5 * np.sin(2 * np.pi * t / L * 3 + 1)) ** 2
    ev.append((0.0, sw * 0.25, 1.0))
    whole = ["E5", "F#5", "G#5", "A#5", "C6", "D6"]
    for i in range(9):
        ev.append((RNG.uniform(0, L - 3), glass(hz(RNG.choice(whole)), 3.5), 0.12))
    return render(L, ev, 6.0, (4.0, 0.5, 3000))


def music_tower():
    bar = 5.5
    prog = ["Dm", "Bb", "Dm", "Gm", "Dm", "Bb", "Gm", "A"]
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c]], bar + 2.0, 900, 2.0, 2.0), 0.85))
        for k, n in enumerate(CHORDS[c][1:]):
            ev.append((i * bar + 0.8 + k * 1.3, glass(hz(n) * 4, 3.0), 0.07))
    t = tline(L + 2)
    ev.append((0.0, np.sin(2 * np.pi * 55.0 * t) * 0.12 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t)), 1.0))
    return render(L, ev, 6.0, (4.5, 0.5, 3200))


def music_orin():
    bpm = 66.0
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Dm", "Bb", "F", "A", "Dm", "Bb", "Gm", "A", "Dm", "Bb", "F", "C"]
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev += arpeggio(c, i * bar, bar, (0, 2, 3, 2), 0.22, 0.6)
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c]], bar + 1.5, 1000, 1.0, 1.6), 0.55))
    song, _ = song_events(bar * 2, beat * 1.15, 0)
    for (at, f, d) in song:
        ev.append((at, flute(f / 2 * 1.0, d * 1.05, 0.005), 0.25))
    return render(L, ev, 5.0, (3.4, 0.4, 3600))


def music_ending_keeper():
    bpm = 56.0
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "Gm", "Dm"]
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c]], bar + 1.8, 1000, 1.4, 1.8), 0.8))
    song, _ = song_events(bar * 1, beat, 0)
    for (at, f, d) in song[:12]:
        ev.append((at, flute(f, d * 1.05, 0.003), 0.28))
    ev.append((bar * 6.5, lowpass(bell(hz("D3"), 5.0, BELL_MINOR, 0.3), 1400), 0.2))
    return render(L, ev, 5.0, (3.4, 0.45, 3400))


def music_ending_promise():
    bpm = 72.0
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Dm", "F", "C", "G", "Dm", "F", "C", "Dsus", "D", "F", "C", "G"]
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev += arpeggio(c, i * bar, bar, (0, 1, 2, 3, 2, 1), 0.24, 0.9)
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c]], bar + 1.2, 1300, 1.0, 1.4), 0.5))
    t = tline(L + 2)
    ev.append((0.0, np.sin(2 * np.pi * hz("D2") * t) * 0.15, 1.0))
    return render(L, ev, 4.0, (2.8, 0.35, 4200))


def music_ending_chorus():
    bpm = 70.0
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "C", "D"] * 2
    L = bar * len(prog)
    ev = []
    for i, c in enumerate(prog):
        ev.append((i * bar, pad([hz(n) for n in CHORDS[c]], bar + 1.4, 1500, 1.0, 1.4), 0.55))
        if i >= 2:
            ev += arpeggio(c, i * bar, bar, (0, 1, 2, 3), 0.16, 0.7)
    # the Gathering Song, sung by everyone (melody + a third below), then on the flute
    song, end = song_events(bar * 1, beat, -1)
    harmony = {hz("D4") / 2: hz("A3") / 2}
    for (at, f, d) in song:
        ev.append((at, choir(f * 2, d + 0.25, FORMANTS_A, 5), 0.42))
        ev.append((at, choir(f * 2 * 0.8409, d + 0.25, FORMANTS_O, 3), 0.18))
    song2, _ = song_events(bar * 9, beat, 0)
    for (at, f, d) in song2:
        ev.append((at, flute(f, d * 1.05, 0.004), 0.25))
        ev.append((at, choir(f / 2, d + 0.25, FORMANTS_O, 4), 0.22))
    ev.append((bar * 8 - 0.2, bell(hz("D3"), 6.0, BELL_MAJOR, 0.3, decay_scale=1.2), 0.3))
    return render(L, ev, 6.0, (3.6, 0.45, 4000))


# ============================================================== ambience ===
def amb_wind(L, lo=200, hi=900, depth=0.6, speed=0.11):
    t = tline(L)
    w = bandpass(noise(L), lo, hi)
    mod = (1 - depth) + depth * (0.5 + 0.5 * np.sin(2 * np.pi * speed * t + RNG.random() * 6)) * \
        (0.6 + 0.4 * np.sin(2 * np.pi * speed * 2.7 * t))
    return w * mod


def cricket(dur=0.35):
    t = tline(dur)
    chirp = np.sin(2 * np.pi * 4300 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 32 * t)))
    return chirp * env(len(t), 0.01, 0.05) * 0.5


def amb_render(L, layers, events, tail=3.0, rev=(1.6, 0.25, 5000)):
    buf = np.zeros(int((L + tail) * SR))
    for x in layers:
        place(buf, x, 0.0)
    for (at, s, g) in events:
        place(buf, s, at % L, g)
    y = reverb(buf, *rev)
    return fold_loop(y, L)


def ambience_village(night=False):
    L = 26.0
    layers = [amb_wind(L + 3, 250, 1100, 0.6, 0.09) * 0.25]
    ev = []
    for _ in range(40 if night else 18):
        ev.append((RNG.uniform(0, L), cricket(RNG.uniform(0.2, 0.45)), RNG.uniform(0.05, 0.12)))
    if not night:
        for _ in range(3):
            tt = tline(0.6)
            bird = np.sin(2 * np.pi * (2800 - 1200 * tt) * tt) * env(len(tt), 0.02, 0.2) * 0.15
            ev.append((RNG.uniform(0, L), bird, 1.0))
    else:
        for at in (6.0, 19.0):
            tt = tline(0.5)
            hoot = np.sin(2 * np.pi * 410 * tt) * env(len(tt), 0.08, 0.2)
            ev.append((at, hoot * 0.2, 1.0))
            ev.append((at + 0.6, hoot * 0.15, 1.0))
    return amb_render(L, layers, ev)


def ambience_forge():
    L = 20.0
    t = tline(L + 3)
    roar = lowpass(noise(L + 3), 350) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.3 * t))
    layers = [roar * 0.5]
    ev = []
    for _ in range(140):
        ln = RNG.uniform(0.004, 0.02)
        ev.append((RNG.uniform(0, L), highpass(noise(ln), 1500) * np.exp(-np.arange(int(ln * SR)) / SR * 300),
                   RNG.uniform(0.15, 0.5)))
    for at in (4.0, 13.0):
        tt = tline(2.0)
        ev.append((at, lowpass(noise(2.0), 600) * np.sin(np.pi * tt / 2.0) ** 2 * 0.5, 1.0))
    return amb_render(L, layers, ev, rev=(0.8, 0.15, 5000))


def ambience_chapel():
    L = 26.0
    layers = [lowpass(noise(L + 3), 220) * 0.18, amb_wind(L + 3, 900, 1400, 0.8, 0.05) * 0.04]
    ev = []
    for _ in range(5):
        tt = tline(0.25)
        drip = np.sin(2 * np.pi * (1400 + 500 * tt) * tt) * np.exp(-tt * 35)
        ev.append((RNG.uniform(0, L), drip * 0.12, 1.0))
    return amb_render(L, layers, ev, rev=(3.5, 0.6, 3000))


def ambience_mist():
    L = 28.0
    t = tline(L + 3)
    layers = [amb_wind(L + 3, 200, 800, 0.7, 0.07) * 0.35,
              lowpass(noise(L + 3), 120) * 0.25 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.05 * t))]
    ev = []
    for _ in range(5):
        tt = tline(0.8)
        creak = bandpass(np.sin(2 * np.pi * (300 + 140 * np.sin(2 * np.pi * 2.0 * tt)) * tt) + 0.3 * noise(0.8),
                         200, 1500) * env(len(tt), 0.1, 0.3)
        ev.append((RNG.uniform(0, L), creak * 0.2, 1.0))
    for _ in range(4):
        ln = RNG.uniform(0.8, 1.4)
        w = bandpass(noise(ln), 900, 2600) * np.hanning(int(ln * SR)) * 0.12
        ev.append((RNG.uniform(0, L), w, 1.0))
    return amb_render(L, layers, ev, rev=(3.0, 0.5, 3000))


def ambience_tower():
    L = 26.0
    t = tline(L + 3)
    howl_c = 500 + 250 * np.sin(2 * np.pi * 0.06 * t)
    w = noise(L + 3)
    howl = np.zeros_like(w)
    # cheap moving band-pass: blend two fixed bands with a moving weight
    a = bandpass(w, 300, 600)
    b = bandpass(w, 600, 1100)
    k = (howl_c - 250) / 500
    howl = a * (1 - k) + b * k
    layers = [howl * 0.32 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.09 * t)) ** 2,
              np.sin(2 * np.pi * 55 * t) * 0.05 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.5 * t))]
    ev = []
    for _ in range(4):
        tt = tline(0.6)
        creak = bandpass(np.sin(2 * np.pi * (220 + 80 * np.sin(2 * np.pi * 3 * tt)) * tt) + 0.2 * noise(0.6),
                         150, 1200) * env(len(tt), 0.08, 0.25)
        ev.append((RNG.uniform(0, L), creak * 0.25, 1.0))
    return amb_render(L, layers, ev, rev=(3.0, 0.45, 3200))


# ================================================================== main ===
def main(which=("sfx", "music", "ambience")):
    if "sfx" in which:
        print("sfx:")
        quiet = {"step_grass", "step_stone", "step_dirt", "step_wood", "step_cloth", "blip", "ui_move", "page", "hum", "hum_slow"}
        for name, x in sorted(sfx_all().items()):
            write_wav(f"assets/audio/sfx/{name}.wav", normalize(x, -6.0 if name in quiet else -2.0))
    if "music" in which:
        print("music:")
        for name, fn in (("title", music_title), ("village_dusk", music_village), ("chapel", music_chapel),
                         ("mist", music_mist), ("tower", music_tower), ("orin", music_orin),
                         ("ending_keeper", music_ending_keeper), ("ending_promise", music_ending_promise),
                         ("ending_chorus", music_ending_chorus)):
            write_wav(f"assets/audio/music/{name}.wav", normalize(fn(), -5.0), loop=True)
    if "ambience" in which:
        print("ambience:")
        for name, fn in (("village_evening", lambda: ambience_village(False)), ("village_night", lambda: ambience_village(True)),
                         ("forge", ambience_forge), ("chapel", ambience_chapel), ("mist_forest", ambience_mist),
                         ("tower_wind", ambience_tower)):
            write_wav(f"assets/audio/ambience/{name}.wav", normalize(fn(), -6.0 if name == "forge" else -12.0), loop=True)


if __name__ == "__main__":
    main(tuple(sys.argv[1:]) or ("sfx", "music", "ambience"))
