#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""高分辨率立绘生成：参考图 -> 1024x1024 统一裁切 + 统一底板。

只用于界面层（角色选择 / Boss 登场 / 结算 / 对话），不进入战斗场景。
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_pixel_sprites as M  # noqa: E402  复用抠图/切视图逻辑

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "portraits")
SIZE = 1024

# 立绘来源：优先全身图；Claude 只有 Q 版三视图，只能用 Q 版放大
SOURCES = {
    "deepseek": {"ref": "deepseek_full.png", "tint": (30, 48, 110), "accent": (96, 132, 232)},
    "gpt": {"ref": "gpt_full.png", "tint": (58, 50, 92), "accent": (168, 150, 232)},
    "claude": {"ref": "claude_chibi.png", "tint": (110, 54, 26), "accent": (238, 150, 92)},
}


def vertical_gradient(size, top, bottom):
    w, h = size
    grad = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        t = y / float(h - 1)
        grad[y, :, :] = [int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)]
    return Image.fromarray(grad, "RGB").convert("RGBA")


def make_portrait(name, cfg):
    src = M.strip_bg(Image.open(os.path.join(M.REF_DIR, cfg["ref"])).convert("RGBA"))
    views = M.split_views(src)
    idx = 1 if len(views) > 1 else 0
    subject = M.trim(views[idx])

    # 等比缩放：高度占画布 92%，水平居中
    target_h = int(SIZE * 0.92)
    scale = target_h / float(subject.height)
    nw = max(1, int(subject.width * scale))
    art = subject.resize((nw, target_h), Image.LANCZOS)
    # 轻度锐化，避免放大后发糊
    art = art.filter(ImageFilter.UnsharpMask(radius=2, percent=90, threshold=2))

    bg = vertical_gradient((SIZE, SIZE), cfg["tint"], (12, 14, 20))

    # 柔和光晕，避免纯色板过于单调
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([SIZE * 0.08, SIZE * 0.05, SIZE * 0.92, SIZE * 0.85],
               fill=(cfg["accent"][0], cfg["accent"][1], cfg["accent"][2], 46))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    bg.alpha_composite(glow)

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(bg)
    x = (SIZE - nw) // 2
    y = SIZE - target_h - 12
    canvas.alpha_composite(art, (x, y))

    # 底部渐隐，让人物与底板融合（不保留杂乱背景）
    fade = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fade)
    for i in range(120):
        a = int(200 * (i / 120.0) ** 2)
        fd.rectangle([0, SIZE - 120 + i, SIZE, SIZE - 120 + i + 1], fill=(12, 14, 20, a))
    canvas.alpha_composite(fade)

    # 内描边
    d = ImageDraw.Draw(canvas)
    d.rectangle([6, 6, SIZE - 7, SIZE - 7], outline=(cfg["accent"][0], cfg["accent"][1],
                                                     cfg["accent"][2], 130), width=3)

    out = os.path.join(OUT, "%s_full.png" % name)
    canvas.convert("RGB").save(out, quality=95)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, cfg in SOURCES.items():
        p = make_portrait(name, cfg)
        im = Image.open(p)
        print("%-9s -> %s %s" % (name, os.path.relpath(p, ROOT), im.size))


if __name__ == "__main__":
    main()
