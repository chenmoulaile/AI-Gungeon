#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""程序化生成三段无缝循环 BGM（只用标准库：wave / struct / math）。

A 小调，Am - F - C - G 四小节循环：
  explore 80 BPM  稀疏琶音 + 低频铺底
  combat 128 BPM  加打击乐与更密琶音
  boss   140 BPM  低音加重 + 三全音制造紧张

无缝做法：渲染 loop_len + tail，再把超出 loop_len 的尾巴叠加回开头，然后裁到 loop_len。
"""

import math
import os
import random
import struct
import wave

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio")

# 音高（MIDI）
A2, C3, D3, E3, F3, G3 = 45, 48, 50, 52, 53, 55
A3, C4, D4, E4, F4, G4 = 57, 60, 62, 64, 65, 67
A4, C5, E5, F5, G5 = 69, 72, 76, 77, 79

CHORDS = [
    # (根音, 三音, 五音, 琶音四音)
    (A3, C4, E4, [A3, C4, E4, A4]),
    (F3, A3, C4, [F3, A3, C4, F4]),
    (C4, E4, G4, [C4, E4, G4, C5]),
    (G3, 59, D4, [G3, 59, D4, G4]),
]


def midi_hz(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def env(i, n, attack=0.01, decay=0.9, release=0.2):
    t = i / float(n)
    a = min(1.0, t / max(attack, 1e-4))
    d = math.exp(-3.0 * t / max(decay, 1e-4))
    r = 1.0 if t < 0.8 else max(0.0, (1.0 - t) / 0.2)
    return a * d * r


def osc(kind, phase):
    if kind == "sine":
        return math.sin(phase)
    if kind == "tri":
        return 2.0 / math.pi * math.asin(math.sin(phase))
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0.0 else -1.0
    if kind == "saw":
        return 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
    return math.sin(phase)


def add_note(buf, start_s, dur_s, freq, amp, kind="sine", detune=0.0):
    n0 = int(start_s * SR)
    n = int(dur_s * SR)
    if n <= 0:
        return
    ph = 0.0
    for i in range(n):
        idx = n0 + i
        if idx >= len(buf):
            break
        f = freq * (1.0 + detune)
        ph += 2.0 * math.pi * f / SR
        buf[idx] += osc(kind, ph) * amp * env(i, n)


def add_kick(buf, start_s, amp=0.55):
    n0 = int(start_s * SR)
    n = int(0.18 * SR)
    ph = 0.0
    for i in range(n):
        idx = n0 + i
        if idx >= len(buf):
            break
        t = i / float(n)
        f = 110.0 * math.exp(-8.0 * t) + 42.0
        ph += 2.0 * math.pi * f / SR
        buf[idx] += math.sin(ph) * amp * math.exp(-7.0 * t)


def add_hat(buf, start_s, amp=0.12, rng=None):
    rng = rng or random.Random(7)
    n0 = int(start_s * SR)
    n = int(0.05 * SR)
    for i in range(n):
        idx = n0 + i
        if idx >= len(buf):
            break
        t = i / float(n)
        buf[idx] += rng.uniform(-1.0, 1.0) * amp * math.exp(-22.0 * t)


def render(bpm, bars, style):
    beat = 60.0 / bpm
    loop_s = bars * 4 * beat
    tail_s = 2.0
    buf = [0.0] * int((loop_s + tail_s) * SR)

    for b in range(bars):
        root, third, fifth, arp = CHORDS[b % len(CHORDS)]
        bar_t = b * 4 * beat
        # 铺底：整小节长音
        add_note(buf, bar_t, 4 * beat * 1.05, midi_hz(root - 12), 0.10, "sine")
        add_note(buf, bar_t, 4 * beat * 1.05, midi_hz(fifth - 12), 0.06, "sine", 0.002)
        if style == "boss":
            # 三全音，制造不和谐
            add_note(buf, bar_t, 4 * beat, midi_hz(root - 6), 0.05, "saw", -0.003)
            add_note(buf, bar_t, 4 * beat, midi_hz(root - 24), 0.10, "square")
        # 和弦（每两拍换一次）
        for half in range(2):
            t0 = bar_t + half * 2 * beat
            add_note(buf, t0, 2 * beat * 0.95, midi_hz(root), 0.05, "tri")
            add_note(buf, t0, 2 * beat * 0.95, midi_hz(third), 0.04, "tri")
            add_note(buf, t0, 2 * beat * 0.95, midi_hz(fifth), 0.035, "tri")
        # 琶音
        step = 0.5 if style != "explore" else 1.0
        count = int(4 / step)
        for i in range(count):
            note = arp[i % len(arp)]
            t0 = bar_t + i * step * beat
            amp = 0.075 if style == "explore" else 0.06
            add_note(buf, t0, step * beat * 0.9, midi_hz(note + 12), amp, "tri")
        # 打击
        if style in ("combat", "boss"):
            for k in (0, 2):
                add_kick(buf, bar_t + k * beat, 0.5 if style == "boss" else 0.4)
            for h in range(8):
                add_hat(buf, bar_t + h * 0.5 * beat, 0.05 if style == "explore" else 0.09)
        if style == "boss":
            for k in (1, 3):
                add_kick(buf, bar_t + k * beat + 0.5 * beat, 0.3)
        # 低音线
        for i in range(4):
            add_note(buf, bar_t + i * beat, beat * 0.7, midi_hz(root - 12), 0.09, "saw")

    # 无缝：把尾巴叠回开头
    loop_n = int(loop_s * SR)
    for i in range(len(buf) - loop_n):
        buf[i] += buf[loop_n + i]
    buf = buf[:loop_n]

    # 归一化到 -6 dBFS
    peak = max(abs(v) for v in buf) or 1.0
    target = 10 ** (-6.0 / 20.0)
    gain = target / peak
    # 首尾 30ms 微淡入淡出，彻底消除接缝爆音
    fade = int(0.03 * SR)
    for i in range(fade):
        k = i / float(fade)
        buf[i] *= k
        buf[-1 - i] *= k
    return [int(max(-32767, min(32767, v * gain * 32767))) for v in buf]


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(struct.pack("<%dh" % len(samples), *samples))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    specs = [
        ("bgm_explore.wav", 80, 8, "explore"),
        ("bgm_combat.wav", 128, 10, "combat"),
        ("bgm_boss.wav", 140, 10, "boss"),
    ]
    for name, bpm, bars, style in specs:
        data = render(bpm, bars, style)
        path = os.path.join(OUT_DIR, name)
        write_wav(path, data)
        print("%-16s %5.1fs  %d samples" % (name, len(data) / SR, len(data)))


if __name__ == "__main__":
    main()
