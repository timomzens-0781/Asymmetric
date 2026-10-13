#!/usr/bin/env python3
"""Erzeugt alle Soundeffekte und die Musik fuer Asymmetric prozedural (numpy, keine externen Samples).

Aufruf:  python3 tools/gen_audio.py
Ausgabe: assets/audio/*.wav (SFX) und assets/audio/music_*.ogg (Musik, benoetigt ffmpeg; sonst WAV)
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(n, decay):
    return np.exp(-np.arange(n) / (decay * SR))


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    # Ein-Pol-Tiefpass
    a = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def lowpass_var(x, c0, c1):
    n = len(x)
    cut = np.linspace(c0, c1, n)
    a = 1.0 - np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(n):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def fade(x, a=0.004, b=0.01):
    n = len(x)
    ia = max(1, int(a * SR))
    ib = max(1, int(b * SR))
    x = x.copy()
    x[:ia] *= np.linspace(0, 1, ia)
    x[-ib:] *= np.linspace(1, 0, ib)
    return x


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def save_wav(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  ", name, "%.2fs" % (len(x) / SR))


def sine(f, dur, phase=0.0):
    t = t_axis(dur)
    return np.sin(2 * np.pi * f * t + phase)


def sweep(f0, f1, dur):
    t = t_axis(dur)
    f = np.linspace(f0, f1, len(t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


# ------------------------------------------------------------------ Effekte
def explosion(dur, low, crackle=0.5, thump=60):
    n = int(dur * SR)
    nz = noise(n)
    body = lowpass_var(nz, 2500, 140) * env_exp(n, dur * 0.28)
    crack = highpass(nz, 1200) * env_exp(n, 0.05) * crackle
    sub = sweep(thump * 1.6, thump * 0.45, dur) * env_exp(n, dur * 0.25) * low
    tail = lowpass(noise(n), 300) * env_exp(n, dur * 0.5) * 0.35
    # Truemmer-Knistern
    deb = np.zeros(n)
    for _ in range(int(dur * 22)):
        p = int(rng.uniform(0.12, 0.95) * n)
        l = int(rng.uniform(0.003, 0.012) * SR)
        if p + l < n:
            deb[p:p + l] += rng.uniform(-1, 1, l) * rng.uniform(0.05, 0.2)
    x = body + crack + sub + tail + deb * env_exp(n, dur * 0.4)
    return fade(norm(x), 0.002, 0.05)


def gen_sfx():
    print("SFX:")
    save_wav("explosion_s", explosion(0.9, 0.7, 0.6, 90))
    save_wav("explosion_m", explosion(1.6, 0.9, 0.5, 70))
    save_wav("explosion_l", explosion(2.6, 1.1, 0.4, 52))
    # Einsturz
    n = int(3.0 * SR)
    rum = lowpass(noise(n), 220) * (0.55 + 0.45 * np.sin(2 * np.pi * 7 * t_axis(3.0)) ** 2)
    rum *= np.minimum(1, np.arange(n) / (0.15 * SR)) * env_exp(n, 1.3)
    clat = np.zeros(n)
    for _ in range(90):
        p = int(rng.uniform(0.02, 0.9) * n)
        l = int(rng.uniform(0.004, 0.02) * SR)
        if p + l < n:
            clat[p:p + l] += highpass(rng.uniform(-1, 1, l), 600) * rng.uniform(0.1, 0.5) * (1 - p / n)
    save_wav("collapse", fade(norm(rum * 1.3 + clat * 0.6 + sweep(55, 28, 3.0) * env_exp(n, 0.9) * 0.6), 0.01, 0.2))
    # Gewehr
    n = int(0.3 * SR)
    x = highpass(noise(n), 700) * env_exp(n, 0.018) + lowpass(noise(n), 400) * env_exp(n, 0.05) * 0.6 + sweep(220, 70, 0.3) * env_exp(n, 0.03) * 0.6
    x += np.roll(x, int(0.045 * SR)) * 0.25 * env_exp(n, 0.12)
    save_wav("shot_rifle", fade(norm(x), 0.001, 0.05))
    n = int(0.16 * SR)
    x = highpass(noise(n), 900) * env_exp(n, 0.012) + sweep(260, 90, 0.16) * env_exp(n, 0.025) * 0.5
    save_wav("shot_mg", fade(norm(x), 0.001, 0.03))
    # Kanone
    n = int(1.2 * SR)
    x = sweep(120, 38, 1.2) * env_exp(n, 0.16) * 1.0 + lowpass(noise(n), 1800) * env_exp(n, 0.1) * 0.9 + highpass(noise(n), 1500) * env_exp(n, 0.02) * 0.6
    x += lowpass(noise(n), 250) * env_exp(n, 0.45) * 0.5
    save_wav("cannon", fade(norm(x), 0.001, 0.1))
    # Artillerie (tiefer, laenger)
    n = int(1.6 * SR)
    x = sweep(90, 28, 1.6) * env_exp(n, 0.28) + lowpass(noise(n), 900) * env_exp(n, 0.2) * 0.8 + lowpass(noise(n), 200) * env_exp(n, 0.7) * 0.5
    save_wav("arty", fade(norm(x), 0.002, 0.15))
    n = int(1.2 * SR)
    x = lowpass(noise(n), 700) * env_exp(n, 0.35) * 0.6 + sweep(70, 30, 1.2) * env_exp(n, 0.3) * 0.5
    x *= np.minimum(1, np.arange(n) / (0.1 * SR))
    save_wav("arty_far", fade(norm(x, 0.7), 0.05, 0.2))
    # Rakete
    n = int(1.4 * SR)
    sh = lowpass_var(noise(n), 400, 5000) * np.minimum(1, np.arange(n) / (0.35 * SR)) * env_exp(n, 0.8)
    sh += highpass(noise(n), 2500) * 0.25 * env_exp(n, 0.5)
    sh += sweep(200, 90, 1.4) * 0.25 * env_exp(n, 0.5)
    save_wav("rocket", fade(norm(sh, 0.85), 0.002, 0.15))
    # Jet
    n = int(4.0 * SR)
    t = t_axis(4.0)
    env = np.sin(np.pi * np.clip(t / 4.0, 0, 1)) ** 1.5
    jet = lowpass_var(noise(n), 500, 3200) * env
    jet += sweep(120, 80, 4.0) * 0.25 * env
    save_wav("jet", fade(norm(jet, 0.8), 0.2, 0.4))
    # fallende Bombe
    n = int(2.0 * SR)
    t = t_axis(2.0)
    f = 2200 * np.exp(-t * 1.0) + 300
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = np.sin(ph) * (0.15 + 0.85 * np.clip(t / 2.0, 0, 1) ** 2) + lowpass_var(noise(n), 6000, 1500) * 0.15
    save_wav("bomb_fall", fade(norm(w, 0.6), 0.02, 0.2))
    # UI
    t = t_axis(0.18)
    beep = (np.sin(2 * np.pi * 1300 * t) + 0.5 * np.sin(2 * np.pi * 2600 * t)) * env_exp(len(t), 0.05)
    x = np.concatenate([beep, np.zeros(int(0.08 * SR)), beep])
    save_wav("lock", fade(norm(x, 0.6)))
    x = sweep(300, 2200, 1.0) * np.sin(np.pi * np.clip(t_axis(1.0), 0, 1)) * 0.6
    x += sweep(310, 2300, 1.0) * np.sin(np.pi * np.clip(t_axis(1.0), 0, 1)) * 0.3
    save_wav("scan", fade(norm(x, 0.6), 0.02, 0.05))
    t = t_axis(0.5)
    x = (np.sin(2 * np.pi * 660 * t) * env_exp(len(t), 0.15) + np.sin(2 * np.pi * 880 * np.clip(t - 0.12, 0, 9)) * (t > 0.12) * env_exp(len(t), 0.2)) * 0.6
    save_wav("ready", fade(norm(x, 0.5)))
    t = t_axis(0.05)
    save_wav("click", fade(norm(np.sin(2 * np.pi * 1100 * t) * env_exp(len(t), 0.012) + highpass(noise(len(t)), 3000) * 0.2, 0.45), 0.001, 0.01))
    # Alarm
    t = t_axis(0.8)
    f = np.where(np.sin(2 * np.pi * 2.5 * t) > 0, 880, 660)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(ph)) * 0.25 + np.sin(ph) * 0.4
    save_wav("alert", fade(norm(x, 0.5), 0.01, 0.1))
    # Nachrichten-Jingle
    parts = []
    for f0, d in [(523, 0.12), (659, 0.12), (784, 0.28)]:
        tt = t_axis(d)
        parts.append((np.sin(2 * np.pi * f0 * tt) + 0.3 * np.sin(4 * np.pi * f0 * tt)) * env_exp(len(tt), d * 0.6))
    save_wav("news", fade(norm(np.concatenate(parts), 0.5), 0.003, 0.05))
    # Eskalation (dunkler Akkord)
    n = int(2.2 * SR)
    t = t_axis(2.2)
    x = sum(np.sin(2 * np.pi * f * t) for f in [65.4, 77.8, 92.5, 138.6]) * env_exp(n, 0.9) * 0.4
    x += lowpass(noise(n), 400) * env_exp(n, 0.3) * 0.3
    save_wav("level_up", fade(norm(x, 0.8), 0.01, 0.3))
    # Warnhorn
    t = t_axis(1.0)
    x = (np.sign(np.sin(2 * np.pi * 220 * t)) * 0.3 + np.sin(2 * np.pi * 220 * t)) * np.sin(np.pi * np.clip(t, 0, 1)) ** 0.5
    save_wav("horn", fade(norm(x, 0.5), 0.02, 0.15))
    # Upload
    t = t_axis(0.6)
    x = sweep(400, 1600, 0.6) * np.sin(np.pi * np.clip(t / 0.6, 0, 1)) * 0.5 + np.sin(2 * np.pi * 1800 * t) * (t > 0.4) * env_exp(len(t), 0.1) * 0.4
    save_wav("upload", fade(norm(x, 0.5)))
    t = t_axis(0.25)
    save_wav("error", fade(norm(np.sin(2 * np.pi * 180 * t) * np.sign(np.sin(2 * np.pi * 180 * t) + 0.2) * env_exp(len(t), 0.12), 0.45), 0.003, 0.03))
    t = t_axis(0.9)
    x = np.sin(2 * np.pi * 440 * t) * (np.sin(2 * np.pi * 3 * t) > 0) * 0.5
    save_wav("launch_warn", fade(norm(x, 0.5), 0.01, 0.1))


# ------------------------------------------------------------------ Musik
def karplus(freq, dur, decay=0.996, bright=0.5):
    n = int(dur * SR)
    N = max(2, int(SR / freq))
    buf = (rng.uniform(-1, 1, N) * bright) + (sine(freq, N / SR)[:N] * (1 - bright))
    out = np.zeros(n)
    pos = 0
    while pos < n:
        chunk = min(N, n - pos)
        out[pos:pos + chunk] = buf[:chunk]
        nb = 0.5 * (buf + np.roll(buf, 1)) * decay
        buf = nb
        pos += N
    return out


def place(track, x, start):
    s = int(start * SR)
    e = min(len(track), s + len(x))
    if s < len(track):
        track[s:e] += x[:e - s]


def drum_hit(kind):
    if kind == "dum":
        n = int(0.35 * SR)
        return sweep(140, 55, 0.35) * env_exp(n, 0.1) * 0.9 + lowpass(noise(n), 500) * env_exp(n, 0.03) * 0.5
    if kind == "tek":
        n = int(0.18 * SR)
        return highpass(noise(n), 2000) * env_exp(n, 0.025) * 0.5 + sine(900, 0.18) * env_exp(n, 0.03) * 0.15
    n = int(0.12 * SR)
    return highpass(noise(n), 3500) * env_exp(n, 0.015) * 0.3


def hijaz_scale(root_hz):
    # D Hijaz: D Eb F# G A Bb C (Halbtoene: 0,1,4,5,7,8,10)
    return [root_hz * 2 ** (s / 12) for s in [0, 1, 4, 5, 7, 8, 10, 12]]


def gen_music():
    print("Musik:")
    for name, bpm, bars, energy in [("music_calm", 74, 16, 0.0), ("music_combat", 108, 24, 1.0)]:
        beat = 60.0 / bpm
        bar_len = beat * 4
        total = bar_len * bars
        n = int(total * SR)
        track = np.zeros(n)
        root = 73.42  # D2
        sc = hijaz_scale(root * 2)  # ab D3
        # Drone / Pad
        t = t_axis(total)
        drone = (np.sin(2 * np.pi * root * t) * 0.35 + np.sin(2 * np.pi * root * 1.5 * t) * 0.18 + np.sin(2 * np.pi * root * 2.0 * t + 0.4) * 0.1)
        lfo = 0.75 + 0.25 * np.sin(2 * np.pi * (1.0 / (bar_len * 4)) * t)
        track += drone * lfo * (0.55 if energy < 0.5 else 0.4)
        # Rhythmus (Maqsum: dum tek _ tek dum _ tek _)
        pattern = [("dum", 0), ("tek", 1), ("tek", 3), ("dum", 4), ("tek", 6)]
        for b in range(bars):
            if energy < 0.5 and b < 4:
                continue
            for kind, step in pattern:
                place(track, drum_hit(kind) * (0.5 if energy < 0.5 else 0.9), b * bar_len + step * beat / 2)
            if energy >= 0.5:
                for step in range(8):
                    place(track, drum_hit("ka") * 0.6, b * bar_len + step * beat / 2 + beat / 4)
        # Melodie (Zupfinstrument) – Phrasen aus der Skala
        mel_rng = np.random.default_rng(11 if energy < 0.5 else 12)
        idx = 4
        for b in range(bars):
            steps = 8
            for s in range(steps):
                if energy < 0.5:
                    if mel_rng.random() > 0.38:
                        continue
                else:
                    if mel_rng.random() > 0.62:
                        continue
                idx = int(np.clip(idx + mel_rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(sc) - 1))
                f = sc[idx] * (2 if energy > 0.5 and mel_rng.random() < 0.3 else 1)
                note = karplus(f, 1.4 if energy < 0.5 else 0.8, 0.9965 if energy < 0.5 else 0.992)
                place(track, note * (0.55 if energy < 0.5 else 0.5), b * bar_len + s * beat / 2)
        # Bass-Ostinato im Kampfstueck
        if energy >= 0.5:
            for b in range(bars):
                for s in range(8):
                    f = root * (2 if s % 4 == 3 else 1) * (1.0 if (b // 4) % 2 == 0 else 1.0595)
                    place(track, karplus(f * 2, 0.4, 0.99, 0.3) * 0.7, b * bar_len + s * beat / 2)
            # Spannungs-Streicher (hoher Hijaz-Ton)
            tt = t_axis(total)
            trem = 0.5 + 0.5 * np.sin(2 * np.pi * 6 * tt)
            track += (np.sin(2 * np.pi * sc[4] * 2 * tt) + 0.5 * np.sin(2 * np.pi * sc[5] * 2 * tt)) * 0.05 * (0.4 + 0.6 * trem) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / (bar_len * 4)))
        # weicher Hall (einfaches Echo)
        delay = int(0.31 * SR)
        echo = np.zeros_like(track)
        echo[delay:] = track[:-delay] * 0.28
        echo2 = np.zeros_like(track)
        echo2[delay * 2:] = track[:-delay * 2] * 0.14
        track = track + echo + echo2
        # Schleife nahtlos: Ende ueber den Anfang legen
        tail = int(1.5 * SR)
        tr = track[-tail:].copy()
        track = track[:-tail]
        track[:tail] += tr * np.linspace(1, 0.0, tail)[::-1] * 0 + tr * np.linspace(0, 1, tail) * 0
        track[:tail] += tr * np.linspace(1, 0, tail)
        track = track * np.concatenate([np.linspace(0, 1, int(0.02 * SR)), np.ones(len(track) - int(0.02 * SR))])
        track = norm(track, 0.8)
        wav_path = os.path.join(OUT, name + ".wav")
        data = (track * 32767).astype(np.int16)
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        ogg_path = os.path.join(OUT, name + ".ogg")
        try:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3", ogg_path], check=True)
            os.remove(wav_path)
            print("  ", name, "%.1fs -> ogg" % (len(track) / SR))
        except Exception as e:  # noqa
            print("  ffmpeg nicht verfuegbar, behalte WAV:", e)


if __name__ == "__main__":
    gen_sfx()
    gen_music()
    print("fertig.")
