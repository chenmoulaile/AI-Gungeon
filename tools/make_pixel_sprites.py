#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""像素战斗资源生成器（参考图 -> 24 色像素 sprite）。

流程（严格按项目要求实现）：
    读参考图 -> 取正面视图 -> 中心裁剪主体 -> 降采样到目标尺寸
    -> 中位切分量化到 24 色调色板 -> 按 alpha 做 2px 描边 -> 输出 PNG

生成后还会执行一次 manual_fix 手动修正 pass：
    - 眼睛颜色按参考图采样色重绘（标志性特征 1）
    - 发型主色按参考图色相重新锚定（标志性特征 2）
    - 服装主色按参考图色相重新锚定（标志性特征 3）
    - 轮廓可读性：清理孤立像素、统一 2px 描边

用法：
    python tools/make_pixel_sprites.py
输出：
    assets/sprites/<角色>/{idle,walk,attack,roll}.png
    assets/sprites/<角色>/portrait_icon.png
    assets/sprites/<角色>/palette.gpl
    tools/_preview_sprites.png（自检用接触表）
"""

import colorsys
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF_DIR = os.path.join(ROOT, "assets", "reference")
SPRITE_DIR = os.path.join(ROOT, "assets", "sprites")

FRAME = 64          # 单帧画布尺寸
BODY_H = 52         # 角色在画布内的高度（保证 64x64 画布里有留白，便于特效）
FEET_Y = 61         # 脚底基准线
PALETTE_SIZE = 24   # 每角色独立 24 色

# 每个角色的手工修正锚点（归一化坐标，基于 sprite 主体包围盒）
CHARACTERS = {
    "deepseek": {
        "ref": "deepseek_chibi.png",
        "eye_xy": (0.32, 0.44),
        "eye_xy2": (0.40, 0.44),
        "hair_region": (0.0, 0.0, 1.0, 0.55),
        "cloth_region": (0.0, 0.5, 1.0, 1.0),
        "outline": (20, 26, 64),
        "lift": 40,
    },
    "gpt": {
        "ref": "gpt_chibi.png",
        "eye_xy": (0.30, 0.45),
        "eye_xy2": (0.38, 0.45),
        "hair_region": (0.0, 0.0, 1.0, 0.5),
        "cloth_region": (0.0, 0.48, 1.0, 1.0),
        "outline": (48, 42, 70),
        "lift": 22,
    },
    "claude": {
        "ref": "claude_chibi.png",
        "eye_xy": (0.30, 0.46),
        "eye_xy2": (0.38, 0.46),
        "hair_region": (0.0, 0.0, 1.0, 0.55),
        "cloth_region": (0.0, 0.5, 1.0, 1.0),
        "outline": (62, 32, 18),
        "lift": 14,
    },
}


# ---------------------------------------------------------------- 参考图处理
def strip_bg(im):
    """从四边泛洪填充去除背景，保留服装内部白色。"""
    im = im.convert("RGBA")
    w, h = im.size
    sentinel = (255, 0, 255, 255)
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for s in seeds:
        if im.getpixel(s) != sentinel:
            ImageDraw.floodfill(im, s, sentinel, thresh=60)
    arr = np.array(im)
    key = (arr[:, :, 0] == 255) & (arr[:, :, 1] == 0) & (arr[:, :, 2] == 255)
    arr[:, :, 3] = np.where(key, 0, arr[:, :, 3])
    return Image.fromarray(arr)


def _label_components(mask):
    """简易 8 连通域标记（纯 numpy + 栈，避免额外依赖）。返回 [(bbox, area)]。"""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    boxes = []
    for sy in range(h):
        for sx in range(w):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            stack = [(sy, sx)]
            seen[sy, sx] = True
            x0 = x1 = sx
            y0 = y1 = sy
            area = 0
            while stack:
                y, x = stack.pop()
                area += 1
                if x < x0:
                    x0 = x
                if x > x1:
                    x1 = x
                if y < y0:
                    y0 = y
                if y > y1:
                    y1 = y
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            boxes.append(((x0, y0, x1 + 1, y1 + 1), area))
    return boxes


def split_views(im):
    """把三视图切成 3 个主体。

    三视图是等间距排列的，所以在 1/3、2/3 位置附近搜索"内容最少"的列作为切分线，
    比连通域聚类稳（相邻视图的翅膀/尾巴会连成一片）。
    """
    w, h = im.size
    cols = (np.array(im.getchannel("A")) > 20).sum(axis=0)
    cuts = [0]
    for k in (1, 2):
        center = w * k / 3.0
        lo = max(1, int(center - w * 0.13))
        hi = min(w - 1, int(center + w * 0.13))
        idx = lo + int(np.argmin(cols[lo:hi]))
        cuts.append(idx)
    cuts.append(w)
    views = []
    for i in range(3):
        x0, x1 = cuts[i], cuts[i + 1]
        if x1 - x0 < 8:
            continue
        views.append(im.crop((x0, 0, x1, h)))
    return views


def trim(im):
    box = im.getbbox()
    return im.crop(box) if box else im


def sample_color(im, box, pick="dominant"):
    """在区域内采样主色（忽略透明与近白像素）。"""
    x0, y0, x1, y1 = [int(v) for v in box]
    region = im.crop((max(0, x0), max(0, y0), max(1, x1), max(1, y1)))
    arr = np.array(region.convert("RGBA")).reshape(-1, 4)
    keep = arr[(arr[:, 3] > 200) & (arr[:, :3].min(axis=1) < 235)]
    if len(keep) == 0:
        return (128, 128, 128)
    q = (keep[:, :3] // 16 * 16).astype(np.int32)
    keys, counts = np.unique(q, axis=0, return_counts=True)
    top = keys[counts.argmax()]
    return tuple(int(min(255, c + 8)) for c in top)


def sample_eye_color(subject):
    """取面部小块区域里出现最多的"中间调彩色"作为眼瞳色。

    直接用最饱和像素会被黑色描边带偏，因此改为：亮度 40~180 的像素按 24 级分桶，
    取出现次数最多的桶。侧视图里眼瞳面积足够大，能稳定命中。
    """
    bw, bh = subject.size
    box = (int(bw * 0.08), int(bh * 0.34), int(bw * 0.38), int(bh * 0.50))
    region = subject.crop(box).convert("RGBA")
    arr = np.array(region).reshape(-1, 4).astype(np.int32)
    lum = arr[:, :3].mean(axis=1)
    keep = arr[(arr[:, 3] > 200) & (lum > 40) & (lum < 180)]
    if len(keep) == 0:
        return (90, 110, 180)
    q = (keep[:, :3] // 24 * 24)
    keys, counts = np.unique(q, axis=0, return_counts=True)
    best = keys[counts.argmax()]
    # 饱和度过低时视为无效，退回深色
    mx, mn = int(best.max()), int(best.min())
    if mx - mn < 20:
        best = np.array([70, 80, 120])
    return (int(min(255, best[0] + 12)), int(min(255, best[1] + 12)), int(min(255, best[2] + 12)))


def load_subject(name, cfg):
    """读参考图 -> 去背 -> 取正面视图 -> 裁掉空白 -> 主体。"""
    path = os.path.join(REF_DIR, cfg["ref"])
    im = strip_bg(Image.open(path).convert("RGBA"))
    views = split_views(im)
    # 说明：上传的三视图截图中，左起第一个视图被裁掉了约三分之一，
    # 中间的侧视视图是唯一完整的主体，因此统一取 index=1，保证三个角色一致。
    idx = 1 if len(views) > 1 else 0
    subject = trim(views[idx])
    return subject


# ---------------------------------------------------------------- 降采样与量化
def to_pixel(subject, body_h=BODY_H):
    """等比缩放主体到 body_h 高度，返回 RGBA（未量化）。"""
    w, h = subject.size
    scale = body_h / float(h)
    nw = max(8, int(round(w * scale)))
    small = subject.resize((nw, body_h), Image.LANCZOS)
    # 小尺寸下细节会糊，先提一点对比度和饱和度，量化后轮廓更清楚
    small = ImageEnhance.Contrast(small).enhance(1.18)
    small = ImageEnhance.Color(small).enhance(1.12)
    small = ImageEnhance.Sharpness(small).enhance(1.4)
    return small


def quantize24(im, n=PALETTE_SIZE):
    """中位切分量化到 n 色，并重建 alpha（阈值抗锯齿）。"""
    alpha = im.getchannel("A")
    rgb = im.convert("RGB")
    q = rgb.quantize(colors=n, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.NONE)
    out = q.convert("RGB").convert("RGBA")
    mask = alpha.point(lambda v: 255 if v > 110 else 0)
    out.putalpha(mask)
    return out


def used_palette(im):
    arr = np.array(im.convert("RGBA")).reshape(-1, 4)
    keep = arr[arr[:, 3] > 0][:, :3]
    if len(keep) == 0:
        return []
    keys, counts = np.unique(keep, axis=0, return_counts=True)
    order = counts.argsort()[::-1]
    return [tuple(int(c) for c in keys[i]) for i in order]


# ---------------------------------------------------------------- 描边
def add_outline(im, color, size=2):
    a = im.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(size * 2 + 1))
    base = Image.new("RGBA", im.size, (color[0], color[1], color[2], 255))
    base.putalpha(grown)
    base.alpha_composite(im)
    return base


# ---------------------------------------------------------------- 手动修正
def _shift_hue_to(rgb, target):
    """把 rgb 的色相拉向 target 的色相，保留明暗关系。"""
    r, g, b = [v / 255.0 for v in rgb]
    tr, tg, tb = [v / 255.0 for v in target]
    h1, l1, s1 = colorsys.rgb_to_hls(r, g, b)
    h2, l2, s2 = colorsys.rgb_to_hls(tr, tg, tb)
    if s1 < 0.08:  # 近灰白像素不动，避免裙子被染色
        return rgb
    dh = ((h2 - h1 + 0.5) % 1.0) - 0.5
    h = (h1 + dh * 0.75) % 1.0
    s = min(1.0, s1 * 0.85 + s2 * 0.35)
    l = min(1.0, max(0.0, l1 * 0.9 + l2 * 0.15))
    nr, ng, nb = colorsys.hls_to_rgb(h, l, s)
    return (int(nr * 255), int(ng * 255), int(nb * 255))


def _hue_diff(a, b):
    h1 = colorsys.rgb_to_hls(a[0] / 255.0, a[1] / 255.0, a[2] / 255.0)[0]
    h2 = colorsys.rgb_to_hls(b[0] / 255.0, b[1] / 255.0, b[2] / 255.0)[0]
    d = abs(h1 - h2)
    return min(d, 1.0 - d)


def manual_fix(sprite, cfg, hair_rgb, cloth_rgb, eye_rgb):
    """手动修正 pass（在量化之后、描边之前执行）。

    1. 色相锚定：只有与参考图主色色相偏差 > 0.12 的像素才拉回 40%，避免整体染色
    2. 亮度分层：把最暗的像素抬亮，保证主体明显亮于 2px 描边（轮廓可读性）
    3. 顶部边缘提亮（rim light），让头顶从背景里跳出来
    4. 眼睛按参考图眼瞳色重绘 + 1px 高光（标志性特征）
    5. 清理孤立像素
    """
    log = []
    arr = np.array(sprite.convert("RGBA")).astype(np.int32)
    h, w = arr.shape[:2]
    alpha = arr[:, :, 3]
    rgb = arr[:, :, :3]

    # 1) 轻量色相锚定
    y_split = int(h * 0.55)
    fixed_cnt = 0
    for y in range(h):
        target = hair_rgb if y < y_split else cloth_rgb
        for x in range(w):
            if alpha[y, x] == 0:
                continue
            cur = tuple(int(v) for v in rgb[y, x])
            if _hue_diff(cur, target) > 0.12:
                new_c = _shift_hue_to(cur, target)
                rgb[y, x] = [int(cur[i] * 0.6 + new_c[i] * 0.4) for i in range(3)]
                fixed_cnt += 1
    log.append("hue_anchor(%d px)" % fixed_cnt)

    # 2) 亮度分层：按亮度加权抬亮暗部，保证主体明显亮于 2px 描边
    lum = rgb.mean(axis=2)
    body = alpha > 0
    lift = float(cfg.get("lift", 20))
    weight = np.clip(1.0 - lum / 190.0, 0.0, 1.0) ** 1.4
    add = (lift * weight)[:, :, None]
    rgb = np.where(body[:, :, None], np.clip(rgb + add, 0, 255), rgb)
    log.append("shadow_lift(%d)" % int(lift))

    # 3) 顶部 rim light
    rim = np.zeros_like(body)
    rim[2:, :] = body[2:, :] & (~body[:-2, :])
    rgb[rim] = np.clip(rgb[rim] + 26, 0, 255)
    log.append("rim_light")

    out = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    fixed = Image.fromarray(out, "RGBA")

    # 4) 眼睛重绘
    for key in ("eye_xy", "eye_xy2"):
        ex = int(cfg[key][0] * w)
        ey = int(cfg[key][1] * h)
        for dx in (0, 1):
            for dy in (0, 1):
                px, py = ex + dx, ey + dy
                if 0 <= px < w and 0 <= py < h and fixed.getpixel((px, py))[3] > 0:
                    fixed.putpixel((px, py), (eye_rgb[0], eye_rgb[1], eye_rgb[2], 255))
        hx, hy = ex + 1, ey - 1
        if 0 <= hx < w and 0 <= hy < h and fixed.getpixel((hx, hy))[3] > 0:
            fixed.putpixel((hx, hy), (250, 252, 255, 255))
    log.append("eyes_repaint")

    # 5) 去孤立像素
    a = np.array(fixed.getchannel("A"))
    solid = a > 0
    nb = np.zeros_like(a, dtype=np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            nb += np.roll(np.roll(solid, dy, axis=0), dx, axis=1).astype(np.int32)
    a[solid & (nb <= 1)] = 0
    fixed.putalpha(Image.fromarray(a))
    log.append("despeckle")
    return fixed, log


# ---------------------------------------------------------------- 帧生成
def paste_frame(sprite, ox=0, oy=0, scale=1.0, rot=0.0):
    """把主体贴到 64x64 画布，脚底对齐 FEET_Y。"""
    s = sprite
    if scale != 1.0:
        nw = max(2, int(round(s.width * scale)))
        nh = max(2, int(round(s.height * scale)))
        s = s.resize((nw, nh), Image.NEAREST)
    if rot:
        s = s.rotate(rot, resample=Image.NEAREST, expand=False)
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - s.width) // 2 + ox
    y = FEET_Y - s.height + oy
    canvas.alpha_composite(s, (x, y))
    return canvas


def shear_top(sprite, amount):
    """上半身水平错切，用于 attack 前倾。"""
    s = sprite.copy()
    w, h = s.size
    out = Image.new("RGBA", (w + abs(amount), h), (0, 0, 0, 0))
    for y in range(h):
        k = int(amount * (1.0 - y / float(h)))
        out.alpha_composite(s.crop((0, y, w, y + 1)), (max(0, k), y))
    return out


def build_frames(sprite):
    """idle 4 / walk 6 / attack 3 / roll 4。"""
    frames = {}
    bob = [0, -1, 0, 1]
    frames["idle"] = [paste_frame(sprite, 0, oy) for oy in bob]

    walk = [(0, 0), (-1, -1), (0, -2), (1, -1), (0, 0), (-1, 1)]
    frames["walk"] = [paste_frame(sprite, ox, oy) for ox, oy in walk]

    lean = shear_top(sprite, 3)
    frames["attack"] = [
        paste_frame(lean, 0, 0, 1.0),
        paste_frame(lean, 2, -1, 1.04),
        paste_frame(lean, 3, 0, 1.02),
    ]

    frames["roll"] = [
        paste_frame(sprite, 0, 0),
        paste_frame(sprite, 0, 2, 0.92, 90),
        paste_frame(sprite, 0, 2, 0.92, 180),
        paste_frame(sprite, 0, 0, 0.98, 270),
    ]
    return frames


def sheet(frames):
    out = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * FRAME, 0))
    return out


def write_gpl(path, colors):
    lines = ["GIMP Palette", "Name: %s" % os.path.basename(os.path.dirname(path)),
             "Columns: 8", "#"]
    for c in colors:
        lines.append("%3d %3d %3d\t%s" % (c[0], c[1], c[2], "#%02X%02X%02X" % c))
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    os.makedirs(SPRITE_DIR, exist_ok=True)
    preview_rows = []
    report = []

    for name, cfg in CHARACTERS.items():
        subject = load_subject(name, cfg)
        # 采样参考图的三处标志性颜色（用于手动修正）
        bw, bh = subject.size
        hair_rgb = sample_color(subject, (0, 0, bw, int(bh * 0.45)))
        cloth_rgb = sample_color(subject, (0, int(bh * 0.55), bw, bh))
        eye_rgb = sample_eye_color(subject)

        small = to_pixel(subject, BODY_H)
        quant = quantize24(small)
        fixed, log = manual_fix(quant, cfg, hair_rgb, cloth_rgb, eye_rgb)
        fixed = add_outline(fixed, cfg["outline"], size=2)

        frames = build_frames(fixed)
        out_dir = os.path.join(SPRITE_DIR, name)
        os.makedirs(out_dir, exist_ok=True)
        for anim, fl in frames.items():
            sheet(fl).save(os.path.join(out_dir, anim + ".png"))

        # portrait_icon 32x32
        icon = fixed.resize((30, 30), Image.LANCZOS)
        icon = quantize24(icon)
        icon = add_outline(icon, cfg["outline"], size=1)
        canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        canvas.alpha_composite(icon, (1, 1))
        canvas.save(os.path.join(out_dir, "portrait_icon.png"))

        # 每角色独立调色板（禁止混用）
        pal = used_palette(fixed)
        pal = pal[:PALETTE_SIZE]
        write_gpl(os.path.join(out_dir, "palette.gpl"), pal)

        report.append("%-9s 主体%dx%d -> %dpx 高 | 主色 发%s 衣%s 瞳%s | 修正:%s | 调色板 %d 色"
                      % (name, bw, bh, BODY_H, hair_rgb, cloth_rgb, eye_rgb, ",".join(log), len(pal)))
        preview_rows.append((name, sheet(frames["idle"]), sheet(frames["walk"]),
                             sheet(frames["attack"]), sheet(frames["roll"])))

    # 接触表：方便肉眼检查（不参与游戏运行）
    pw = FRAME * 6
    sheet_img = Image.new("RGBA", (pw + 12, (FRAME + 6) * len(preview_rows) + 6),
                          (24, 26, 34, 255))
    for i, (name, idle, walk, attack, roll) in enumerate(preview_rows):
        y = 6 + i * (FRAME + 6)
        x = 6
        for s in (idle, walk, attack, roll):
            sheet_img.alpha_composite(s, (x, y))
            x += s.width + 2
    sheet_img.save(os.path.join(ROOT, "tools", "_preview_sprites.png"))

    for line in report:
        print(line)


if __name__ == "__main__":
    sys.exit(main())
