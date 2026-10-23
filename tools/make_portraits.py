#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""立绘生成：参考图 -> 正面视角 -> 透明底立绘（全身 / 半身）。

M0 变更：
- 不再统一取中间侧视图，改为“正面优先”：
  DeepSeek 用左起第一张完整正面图；
  GPT 正面图被原图裁掉了左半边，用镜像补全（对称性足够，补完自然）；
  Claude 正面图只剩一条窄边无法补全，退回中间 3/4 视角并水平翻转，让面部朝向镜头。
- 背景改为透明，交给 UI 自己铺底板；底部渐隐，避免硬切。
- 额外输出 *_bust.png（半身，用于结算/对话）。

用法：python tools/make_portraits.py
输出：assets/portraits/<id>_full.png  assets/portraits/<id>_bust.png
"""

import os
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_pixel_sprites as M  # noqa: E402  复用抠图/切视图逻辑

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "portraits")
SIZE = 1024
BUST = 640

# view: 取第几个视图；mirror: 是否以左边缘为轴镜像补全；flip: 是否整体水平翻转
SOURCES = {
    "deepseek": {"ref": "deepseek_chibi.png", "view": 0, "mirror": False, "flip": False,
                 "face_dx": 0.0},
    "gpt": {"ref": "gpt_chibi.png", "view": 0, "mirror": True, "flip": False,
            "face_dx": 0.0},
    "claude": {"ref": "claude_chibi.png", "view": 1, "mirror": False, "flip": True,
               "face_dx": 0.20},
}


def is_clipped(view, thresh=6):
    """视图左边缘是否被原图裁掉（一列全是实体）。"""
    cols = (np.array(view.getchannel("A")) > 20).sum(axis=0)
    return int(cols[0]) > thresh


def mirror_complete(view):
    """以左边缘为轴镜像，补回被裁掉的左半边（正面图近似左右对称）。"""
    mir = ImageOps.mirror(view)
    canvas = Image.new("RGBA", (view.width * 2, view.height), (0, 0, 0, 0))
    canvas.alpha_composite(mir, (0, 0))
    canvas.alpha_composite(view, (view.width, 0))
    return canvas


def build_subject(cfg):
    src = M.strip_bg(Image.open(os.path.join(M.REF_DIR, cfg["ref"])).convert("RGBA"))
    views = M.split_views(src)
    idx = min(cfg["view"], len(views) - 1)
    view = views[idx]
    if cfg["mirror"] and is_clipped(view):
        view = mirror_complete(view)
    if cfg["flip"]:
        view = ImageOps.mirror(view)
    return M.trim(view)


def bottom_fade(canvas, height=90):
    """底部渐隐，让立绘与卡片底板自然融合。"""
    w, h = canvas.size
    alpha = canvas.getchannel("A").copy()
    px = alpha.load()
    for y in range(h - height, h):
        k = (y - (h - height)) / float(height)
        for x in range(w):
            px[x, y] = int(px[x, y] * (1.0 - k * k))
    canvas.putalpha(alpha)
    return canvas


def make_portrait(name, cfg):
    subject = build_subject(cfg)
    target_h = int(SIZE * 0.97)
    scale = target_h / float(subject.height)
    nw = max(1, int(subject.width * scale))
    art = subject.resize((nw, target_h), Image.LANCZOS)
    art = art.filter(ImageFilter.UnsharpMask(radius=2, percent=90, threshold=2))

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    x = (SIZE - nw) // 2
    y = SIZE - target_h
    canvas.alpha_composite(art, (x, y))
    canvas = bottom_fade(canvas, 90)
    canvas.save(os.path.join(OUT, "%s_full.png" % name))

    # 半身：以面部为中心裁一个正方形
    face_cx = x + nw * (0.5 + cfg["face_dx"])
    face_cy = y + target_h * 0.30
    half = int(target_h * 0.34)
    box = (max(0, int(face_cx - half)), max(0, int(face_cy - half)),
           min(SIZE, int(face_cx + half)), min(SIZE, int(face_cy + half)))
    bust = canvas.crop(box).resize((BUST, BUST), Image.LANCZOS)
    bust.save(os.path.join(OUT, "%s_bust.png" % name))
    return canvas.size, bust.size, subject.size


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, cfg in SOURCES.items():
        full, bust, subj = make_portrait(name, cfg)
        print("%-9s 主体%dx%d -> full%s bust%s" % (name, subj[0], subj[1], full, bust))


if __name__ == "__main__":
    main()
