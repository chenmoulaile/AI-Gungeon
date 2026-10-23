#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""藏品图标与音效生成（全部程序化生成，不使用任何外部素材）。

图标：assets/icons/<id>.png  32x32
音效：assets/audio/<name>.wav  22050Hz 单声道 16bit
"""

import math
import os
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "assets", "icons")
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")

# id -> (主色, 形状)
ICONS = {
    "sharp_round": ((236, 108, 108), "arrow"),
    "rapid_cycle": ((120, 208, 232), "ring"),
    "feather_boots": ((150, 226, 160), "wing"),
    "extra_heart": ((240, 96, 128), "heart"),
    "magnet_coil": ((220, 196, 108), "coil"),
    "crit_lens": ((250, 210, 120), "lens"),
    "piercing_nail": ((200, 200, 216), "nail"),
    "vampire_chip": ((212, 88, 152), "drop"),
    "roll_core": ((140, 168, 246), "gear"),
    "cool_module": ((120, 220, 210), "square"),
    "split_prism": ((176, 148, 244), "prism"),
    "scholar_page": ((232, 214, 176), "page"),
    "ds_homing_split": ((120, 176, 246), "arrow"),
    "ds_burn_zone": ((244, 150, 84), "drop"),
    "gpt_echo_clone": ((186, 160, 244), "square"),
    "gpt_voice_haste": ((208, 186, 250), "wing"),
    "cl_break_burst": ((246, 170, 96), "gear"),
    "cl_overload": ((250, 120, 96), "ring"),
}


def icon(shape, color):
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (color[0], color[1], color[2], 255)
    dark = (color[0] // 3, color[1] // 3, color[2] // 3, 255)
    d.rounded_rectangle([0, 0, 31, 31], radius=6, fill=(18, 20, 28, 235), outline=dark, width=2)
    if shape == "arrow":
        d.polygon([(6, 26), (16, 6), (26, 26), (16, 20)], fill=c)
    elif shape == "ring":
        d.ellipse([6, 6, 26, 26], outline=c, width=3)
        d.line([16, 3, 16, 10], fill=c, width=2)
    elif shape == "wing":
        d.polygon([(5, 22), (12, 8), (27, 10), (18, 24)], fill=c)
    elif shape == "heart":
        d.ellipse([7, 8, 17, 18], fill=c)
        d.ellipse([15, 8, 25, 18], fill=c)
        d.polygon([(7, 14), (25, 14), (16, 27)], fill=c)
    elif shape == "coil":
        for i in range(3):
            d.arc([6, 6 + i * 6, 26, 20 + i * 6], 200, 340, fill=c, width=2)
    elif shape == "lens":
        d.ellipse([7, 7, 25, 25], outline=c, width=3)
        d.line([20, 20, 27, 27], fill=c, width=3)
    elif shape == "nail":
        d.polygon([(16, 4), (21, 16), (16, 28), (11, 16)], fill=c)
        d.line([16, 6, 16, 26], fill=dark, width=1)
    elif shape == "drop":
        d.ellipse([9, 13, 23, 27], fill=c)
        d.polygon([(16, 4), (23, 16), (9, 16)], fill=c)
    elif shape == "gear":
        d.ellipse([9, 9, 23, 23], outline=c, width=3)
        for i in range(6):
            a = math.pi / 3 * i
            x, y = 16 + math.cos(a) * 11, 16 + math.sin(a) * 11
            d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=c)
    elif shape == "square":
        d.rectangle([8, 8, 24, 24], outline=c, width=3)
        d.line([12, 16, 20, 16], fill=c, width=2)
    elif shape == "prism":
        d.polygon([(16, 5), (27, 24), (5, 24)], outline=c, width=2)
        d.line([16, 5, 16, 24], fill=c, width=1)
    elif shape == "page":
        d.polygon([(9, 6), (23, 6), (23, 26), (9, 26)], fill=(236, 232, 220, 255))
        for i in range(4):
            d.line([12, 11 + i * 4, 20, 11 + i * 4], fill=(90, 80, 70, 255), width=1)
    return im


def tone(freq, dur, vol=0.35, decay=6.0, kind="sine", slide=0.0):
    sr = 22050
    n = int(sr * dur)
    t = np.linspace(0, dur, n, endpoint=False)
    f = freq * (1.0 + slide * t / max(dur, 1e-6))
    phase = 2 * np.pi * np.cumsum(f) / sr
    if kind == "square":
        wave_arr = np.sign(np.sin(phase))
    elif kind == "noise":
        wave_arr = np.random.RandomState(int(freq)).uniform(-1, 1, n)
    else:
        wave_arr = np.sin(phase)
    env = np.exp(-decay * t / max(dur, 1e-6))
    data = (wave_arr * env * vol * 32767).astype(np.int16)
    return data


def write_wav(path, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(22050)
        w.writeframes(data.tobytes())


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = np.zeros(n, dtype=np.int32)
    for t in tracks:
        out[:len(t)] += t.astype(np.int32)
    return np.clip(out, -32768, 32767).astype(np.int16)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(AUDIO_DIR, exist_ok=True)
    for uid, (color, shape) in ICONS.items():
        icon(shape, color).save(os.path.join(ICON_DIR, uid + ".png"))

    write_wav(os.path.join(AUDIO_DIR, "shoot.wav"),
              mix(tone(880, 0.07, 0.22, 14, "square", -0.3),
                  tone(1320, 0.05, 0.12, 18)))
    write_wav(os.path.join(AUDIO_DIR, "hit.wav"), tone(300, 0.06, 0.25, 16, "noise"))
    write_wav(os.path.join(AUDIO_DIR, "hurt.wav"),
              mix(tone(180, 0.22, 0.32, 8, "square", -0.5), tone(90, 0.22, 0.2, 6)))
    write_wav(os.path.join(AUDIO_DIR, "roll.wav"), tone(520, 0.16, 0.18, 9, "sine", -0.6))
    write_wav(os.path.join(AUDIO_DIR, "coin.wav"),
              mix(tone(1180, 0.09, 0.18, 12), tone(1560, 0.12, 0.14, 9)))
    write_wav(os.path.join(AUDIO_DIR, "skill.wav"),
              mix(tone(420, 0.30, 0.22, 5, "sine", 1.4), tone(210, 0.30, 0.14, 5)))
    write_wav(os.path.join(AUDIO_DIR, "boss.wav"),
              mix(tone(110, 0.8, 0.3, 3, "square", 0.2), tone(55, 0.8, 0.2, 3)))
    write_wav(os.path.join(AUDIO_DIR, "ui.wav"), tone(660, 0.05, 0.15, 20, "square"))
    write_wav(os.path.join(AUDIO_DIR, "die.wav"),
              mix(tone(240, 0.5, 0.3, 4, "square", -0.7), tone(120, 0.5, 0.2, 3)))
    print("icons:", len(ICONS), "audio: 9")


if __name__ == "__main__":
    main()
