#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""像素战斗资源生成器（参考图 -> 24 色像素 sprite）。

流程（严格按项目要求实现）：
    读参考图 -> 取正面视图 -> 中心裁剪主体 -> 降采样到目标尺寸
    -> 中位切分量化到 24 色调色板 -> 按 alpha 做 1px 描边 -> 输出 PNG

生成后还会执行一次 manual_fix 手动修正 pass：
    - 眼睛颜色按参考图采样色重绘（标志性特征 1）
    - 发型主色按参考图色相重新锚定（标志性特征 2）
    - 服装主色按参考图色相重新锚定（标志性特征 3）
    - 轮廓可读性：清理孤立像素、统一 1px 描边

用法：
    python tools/make_pixel_sprites.py
输出：
    assets/sprites/<角色>/{idle,walk,attack,roll}.png
    assets/sprites/<角色>/portrait_icon.png
    assets/sprites/<角色>/palette.gpl
    assets/portraits/<角色>_pixel.png        96x128 像素立绘
    assets/portraits/<角色>_pixel_avatar.png 32x32 像素头像
    tools/_preview_sprites.png（自检用接触表）
    tools/_preview_portraits.png（立绘接触表）
"""

import colorsys
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF_DIR = os.path.join(ROOT, "assets", "reference")
SPRITE_DIR = os.path.join(ROOT, "assets", "sprites")
PORTRAIT_DIR = os.path.join(ROOT, "assets", "portraits")

FRAME = 64          # 单帧画布尺寸
BODY_H = 52         # 角色在画布内的高度（保证 64x64 画布里有留白，便于特效）
FEET_Y = 61         # 脚底基准线
PALETTE_SIZE = 20   # 每角色独立 24 色
PORTRAIT_W = 96     # 像素立绘画布（UI 里按最近邻放大）
PORTRAIT_H = 128
AVATAR_SIZE = 32    # HUD 头像

# 每个角色的手工修正锚点（归一化坐标，基于 sprite 主体包围盒）
# view: 三视图中第几格（0=正面 1=侧面 2=背面）；优先用正面，辨识度最高
CHARACTERS = {
    "deepseek": {
        "ref": "dafeiyu_chibi_3view.png",
        "view": 0,
        "hair_region": (0.0, 0.0, 1.0, 0.55),
        "cloth_region": (0.0, 0.5, 1.0, 1.0),
        # 描边用主色的深色版，而不是近黑：避免出现"贴纸黑框"
        "outline": (16, 20, 48),
        "lift": 40,
    },
    "gpt": {
        "ref": "gpt_chibi_3view_hd.png",
        "view": 0,
        "hair_region": (0.0, 0.0, 1.0, 0.5),
        "cloth_region": (0.0, 0.48, 1.0, 1.0),
        "outline": (44, 38, 72),
        "lift": 10,
        "contrast": 1.52,
        "shade": (150, 148, 178),
        "bottom_tint": (0.66, 0.69, 0.88),
        # 全白角色在 96px 上会被线稿噪点弄脏脸，立绘单独做一遍脸部清理 + 补虹膜
        "portrait": {
            "face_clean": (0.244, 0.317, 0.756, 0.483),
            "eye_xy": (0.344, 0.383),
            "eye_xy2": (0.566, 0.383),
            "eye_frac": (0.078, 0.033),
            "eye_color": (96, 78, 152),
        },
    },
    "claude": {
        # 2026-10-25 新三视图第 0 格是完整正面，改回正面朝向（旧图只有侧面可用）
        "ref": "claude_chibi_3view_v2.png",
        "view": 0,
        "eye_xy": (0.37, 0.44),
        "eye_xy2": (0.57, 0.44),
        "eye_frac": (0.07, 0.05),
        "eye_color": (198, 92, 36),
        "hair_region": (0.0, 0.0, 1.0, 0.55),
        "cloth_region": (0.0, 0.5, 1.0, 1.0),
        "outline": (74, 38, 24),
        "lift": 14,
        "portrait": {
            "eye_xy": (0.37, 0.44),
            "eye_xy2": (0.57, 0.44),
            "eye_frac": (0.07, 0.035),
            "eye_color": (198, 92, 36),
        },
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
    """在区域内采样主色（忽略透明、近白与线稿近黑像素）。

    三视图的线稿通常是纯黑，如果不过滤，白毛角色（GPT）会把"发色"采样成黑色，
    后续的色相锚定就会把整片白发去饱和洗白。
    """
    x0, y0, x1, y1 = [int(v) for v in box]
    region = im.crop((max(0, x0), max(0, y0), max(1, x1), max(1, y1)))
    arr = np.array(region.convert("RGBA")).reshape(-1, 4)
    keep = arr[(arr[:, 3] > 200) & (arr[:, :3].min(axis=1) < 235)
               & (arr[:, :3].max(axis=1) > 60)]
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
    """读参考图 -> 去背 -> 取 cfg["view"] 指定的视图 -> 裁掉空白 -> 主体。"""
    path = os.path.join(REF_DIR, cfg["ref"])
    im = strip_bg(Image.open(path).convert("RGBA"))
    views = split_views(im)
    idx = int(cfg.get("view", 0))
    if idx >= len(views):
        idx = len(views) - 1
    subject = trim(views[idx])
    return subject


# ---------------------------------------------------------------- 降采样与量化
def to_pixel(subject, body_h=BODY_H, contrast=1.18):
    """等比缩放主体到 body_h 高度，返回 RGBA（未量化）。"""
    w, h = subject.size
    scale = body_h / float(h)
    nw = max(8, int(round(w * scale)))
    return _resample(subject, (nw, body_h), contrast)


def fit_into(subject, max_w, max_h, contrast=1.18):
    """等比缩放主体到 max_w x max_h 框内（宽高同时约束，长条图不会被裁）。"""
    w, h = subject.size
    scale = min(max_w / float(w), max_h / float(h))
    nw = max(8, int(round(w * scale)))
    nh = max(8, int(round(h * scale)))
    return _resample(subject, (nw, nh), contrast)


def _resample(subject, size, contrast):
    """降采样 + 轻微对比/饱和/锐化：小尺寸下细节会糊，提一下量化后轮廓更清楚。"""
    small = subject.resize(size, Image.LANCZOS)
    small = ImageEnhance.Contrast(small).enhance(contrast)
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
def add_outline(im, color, size=1):
    """1px 外描边。像素角色只需要 1 圈，2px 会变成"贴纸黑框"。

    主体通常已经被裁到 alpha 包围盒，四周没有留白；先补 size 圈透明边再膨胀，
    否则贴边那一圈长不出描边，轮廓会缺一块（看起来像没抠干净的缺口）。
    """
    pad = size
    canvas = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(im, (pad, pad))
    a = canvas.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(size * 2 + 1))
    base = Image.new("RGBA", canvas.size, (color[0], color[1], color[2], 255))
    base.putalpha(grown)
    base.alpha_composite(canvas)
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

    bt = cfg.get("bottom_tint", None)
    if bt is not None:
        # 下半身整体压暗并偏冷，让白裙和白发之间有明确分界
        for y in range(h):
            k = 0.0
            if y > int(h * 0.42):
                k = min(1.0, (y - h * 0.42) / (h * 0.40))
            if k <= 0.0:
                continue
            for i in range(3):
                factor = 1.0 - (1.0 - bt[i]) * k
                rgb[y, :, i] = np.where(body[y, :], rgb[y, :, i] * factor, rgb[y, :, i])
        log.append("bottom_tint")

    shade = cfg.get("shade", None)
    if shade is not None:
        lum2 = rgb.mean(axis=2)
        # 只给中间调上阴影色：最暗的那批像素是眼睛和线稿，一起染会把五官洗掉
        dark = body & (lum2 < 150.0) & (lum2 > 60.0)
        t = np.clip((150.0 - lum2) / 150.0, 0.0, 1.0) * 0.55
        for i in range(3):
            rgb[:, :, i] = np.where(dark, rgb[:, :, i] * (1.0 - t) + shade[i] * t, rgb[:, :, i])
        log.append("shade_tint")

    out = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    fixed = Image.fromarray(out, "RGBA")

    # 4) 去孤立像素
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


def paint_eyes(im, cfg, eye_rgb):
    """量化之后重绘双眼：3 色块（虹膜 / 下眼睑暗部 / 高光）。

    眼睛必须在最终量化之后画，否则瞳孔色会被并入浅色簇洗成灰（白毛角色尤其明显）。
    """
    if "eye_xy" not in cfg and "eye_xy2" not in cfg:
        return im
    ew = max(2, int(round(im.width * float(cfg.get("eye_frac", (0.05, 0.03))[0]))))
    eh = max(2, int(round(im.height * float(cfg.get("eye_frac", (0.05, 0.03))[1]))))
    dark = tuple(max(0, int(c * 0.55)) for c in eye_rgb)
    px = im.load()
    for key in ("eye_xy", "eye_xy2"):
        if key not in cfg:
            continue
        ex = int(cfg[key][0] * im.width)
        ey = int(cfg[key][1] * im.height)
        for dx in range(ew):
            for dy in range(eh):
                x, y = ex + dx, ey + dy
                if not (0 <= x < im.width and 0 <= y < im.height):
                    continue
                if px[x, y][3] == 0:
                    continue
                # 上下各 1px 深色眼睑，中间填虹膜，才不会读成"眼影色条"
                c = dark if dy == 0 or dy == eh - 1 else eye_rgb
                px[x, y] = (c[0], c[1], c[2], 255)
        # 左上 2px 高光
        for dx in range(1, min(3, ew - 1)):
            x, y = ex + dx, ey + 1
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] > 0:
                px[x, y] = (250, 252, 255, 255)
    return im


# ---------------------------------------------------------------- 立绘 / 头像
def clean_face(im, box):
    """脸部清理：把脸范围内的高亮噪点压回主肤色。

    参考图的睫毛/腮红是 1~2px 细线，缩到 96px 后变成零散灰点，看起来像脸上脏了一块。
    全白角色（GPT）最明显，所以只对配了 face_clean 的角色启用。
    """
    w, h = im.size
    x0, y0, x1, y1 = [int(round(v)) for v in
                      (box[0] * w, box[1] * h, box[2] * w, box[3] * h)]
    if x1 <= x0 or y1 <= y0:
        return im
    region = im.crop((x0, y0, x1, y1))
    arr = np.array(region).astype(np.int32)
    lum = arr[:, :, :3].mean(axis=2)
    bright = (arr[:, :, 3] > 0) & (lum > 196)
    px = arr[bright][:, :3]
    if len(px) == 0:
        return im
    q = px // 8 * 8
    keys, counts = np.unique(q, axis=0, return_counts=True)
    skin = keys[counts.argmax()]
    arr[:, :, :3] = np.where(bright[:, :, None], skin, arr[:, :, :3])
    im.paste(Image.fromarray(arr.astype(np.uint8), "RGBA"), (x0, y0))
    return im


def build_portrait(subject, cfg, hair_rgb, cloth_rgb, eye_rgb):
    """96x128 像素立绘：和 sprite 走同一套量化/描边，只是分辨率更高、带主题色描边。

    立绘是 UI 里最大的角色展示面，所以保留完整身体（不是面部特写），
    这样卡片、开场对话、结算三处可以共用同一张图。
    """
    # 立绘专用修正（脸部清理 / 眼睛锚点）不参与 64px 战斗帧，避免小尺寸下五官被糊死
    pcfg = dict(cfg)
    pcfg.update(cfg.get("portrait", {}))
    pcfg.pop("portrait", None)
    small = fit_into(subject, PORTRAIT_W - 6, PORTRAIT_H - 8,
                     float(pcfg.get("contrast", 1.18)))
    quant = quantize24(small)
    fixed, _log = manual_fix(quant, pcfg, hair_rgb, cloth_rgb,
                             pcfg.get("eye_color", eye_rgb))
    fixed = quantize24(fixed)
    if "face_clean" in pcfg:
        fixed = clean_face(fixed, pcfg["face_clean"])
    fixed = paint_eyes(fixed, pcfg, pcfg.get("eye_color", eye_rgb))
    fixed = add_outline(fixed, cfg["outline"], size=1)
    canvas = Image.new("RGBA", (PORTRAIT_W, PORTRAIT_H), (0, 0, 0, 0))
    canvas.alpha_composite(fixed, ((PORTRAIT_W - fixed.width) // 2,
                                   PORTRAIT_H - 6 - fixed.height))
    return canvas


def build_avatar(portrait, outline, size=AVATAR_SIZE):
    """从立绘上裁头部做 32x32 头像：HUD 里 30px 的位置放全身会糊成一团。"""
    head = portrait.crop((0, 0, PORTRAIT_W, int(PORTRAIT_H * 0.55)))
    box = head.getbbox()
    if box:
        head = head.crop(box)
    w, h = head.size
    k = min((size - 4) / float(w), (size - 4) / float(h))
    small = head.resize((max(1, int(round(w * k))), max(1, int(round(h * k)))),
                        Image.LANCZOS)
    small = quantize24(small)
    small = add_outline(small, outline, size=1)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((size - small.width) // 2,
                                   (size - small.height) // 2))
    return canvas


# ---------------------------------------------------------------- 帧生成
def paste_frame(sprite, ox=0, oy=0):
    """把主体贴到 64x64 画布，脚底对齐 FEET_Y。"""
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - sprite.width) // 2 + ox
    y = FEET_Y - sprite.height + oy
    canvas.alpha_composite(sprite, (x, y))
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


def squash(sprite, h_scale=1.0, w_scale=1.0):
    """整数像素级压扁/拉宽（NEAREST，不产生半透明过渡像素）。"""
    if h_scale == 1.0 and w_scale == 1.0:
        return sprite
    nw = max(2, int(round(sprite.width * w_scale)))
    nh = max(2, int(round(sprite.height * h_scale)))
    return sprite.resize((nw, nh), Image.NEAREST)


def build_frames(sprite, outline):
    """idle 4 / walk 6 / attack 3 / roll 4

    像素动画规约：
    - 只用整数位移和整数像素的压扁/拉宽，禁用非整数缩放（会产生糊边和重影）
    - 不做整体旋转：64px 的 Q 版角色转 90 度会变成"躺倒的人"，观感极差
    - 描边在每一帧变换完成后再加：先描边再缩放会把 1px 环缩没（NEAREST 降采样会丢掉边缘行）
    """
    def finish(part, ox=0, oy=0):
        return paste_frame(add_outline(part, outline, size=1), ox, oy)

    frames = {}
    # idle：只做上下压扁，脚底始终贴地（不整体平移，避免站着也"飘"起来）
    frames["idle"] = [finish(squash(sprite, h)) for h in (1.0, 0.97, 1.0, 0.98)]

    # walk：左右 1px 换步 + 最多 1px 起伏 + 轻微压扁，读起来像小跑
    walk = [(0, 0, 1.00), (-1, -1, 0.98), (0, -1, 0.96),
            (1, -1, 0.98), (0, 0, 1.00), (1, 0, 0.99)]
    frames["walk"] = [finish(squash(sprite, h), ox, oy) for ox, oy, h in walk]

    # attack：上半身前倾（错切），帧间只做整数位移，不再缩放
    frames["attack"] = [
        finish(shear_top(sprite, 3), 0, 0),
        finish(shear_top(sprite, 5), 1, -1),
        finish(shear_top(sprite, 4), 0, 0),
    ]

    # roll：团身 -> 压扁 -> 更扁 -> 起身，脚底始终贴地
    frames["roll"] = [finish(squash(sprite, h, w))
                      for h, w in ((0.88, 1.06), (0.70, 1.18), (0.56, 1.28), (0.90, 1.04))]
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
    os.makedirs(PORTRAIT_DIR, exist_ok=True)
    preview_rows = []
    portrait_rows = []
    report = []

    for name, cfg in CHARACTERS.items():
        subject = load_subject(name, cfg)
        # 采样参考图的三处标志性颜色（用于手动修正）
        bw, bh = subject.size
        hair_rgb = sample_color(subject, (0, 0, bw, int(bh * 0.45)))
        cloth_rgb = sample_color(subject, (0, int(bh * 0.55), bw, bh))
        eye_rgb = sample_eye_color(subject)

        small = to_pixel(subject, BODY_H, float(cfg.get("contrast", 1.18)))
        quant = quantize24(small)
        fixed, log = manual_fix(quant, cfg, hair_rgb, cloth_rgb, eye_rgb)
        # manual_fix 里的 tint/rim light 会产生大量中间色（GPT 能到 300+ 色），
        # 再量化一次压回真正的像素调色板，这是"像素风"和"插画缩小"的分界线
        fixed = quantize24(fixed)
        # 虹膜要画在最终量化之后，否则会被并进浅色簇
        fixed = paint_eyes(fixed, cfg, eye_rgb)
        # 描边不在主体上预加：每帧变换后再描，避免缩放丢掉 1px 环
        frames = build_frames(fixed, cfg["outline"])
        out_dir = os.path.join(SPRITE_DIR, name)
        os.makedirs(out_dir, exist_ok=True)
        for anim, fl in frames.items():
            sheet(fl).save(os.path.join(out_dir, anim + ".png"))

        # portrait_icon 32x32：等比缩到 30px 内再居中，避免压扁变胖
        iw, ih = fixed.size
        k = 30.0 / max(iw, ih)
        icon = fixed.resize((max(1, int(round(iw * k))), max(1, int(round(ih * k)))),
                            Image.LANCZOS)
        icon = quantize24(icon)
        icon = add_outline(icon, cfg["outline"], size=1)
        canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        canvas.alpha_composite(icon, ((32 - icon.width) // 2, (32 - icon.height) // 2))
        canvas.save(os.path.join(out_dir, "portrait_icon.png"))

        # 每角色独立调色板（禁止混用）：主体色 + 描边色
        pal = used_palette(fixed)[:PALETTE_SIZE]
        pal.append(tuple(cfg["outline"]))
        write_gpl(os.path.join(out_dir, "palette.gpl"), pal)

        # 96x128 像素立绘 + 32x32 头像（UI 用，NEAREST 放大）
        portrait = build_portrait(subject, cfg, hair_rgb, cloth_rgb, eye_rgb)
        portrait.save(os.path.join(PORTRAIT_DIR, name + "_pixel.png"))
        avatar = build_avatar(portrait, cfg["outline"])
        avatar.save(os.path.join(PORTRAIT_DIR, name + "_pixel_avatar.png"))
        portrait_rows.append((name, portrait, avatar))

        report.append("%-9s 主体%dx%d -> %dpx 高 | 立绘%dx%d | 主色 发%s 衣%s 瞳%s | 修正:%s | 调色板 %d 色"
                      % (name, bw, bh, BODY_H, PORTRAIT_W, PORTRAIT_H,
                         hair_rgb, cloth_rgb, eye_rgb, ",".join(log), len(pal)))
        preview_rows.append((name, sheet(frames["idle"]), sheet(frames["walk"]),
                             sheet(frames["attack"]), sheet(frames["roll"])))

    # 接触表：方便肉眼检查（不参与游戏运行）
    pw = FRAME * sum(len(frames[a]) for a in ("idle", "walk", "attack", "roll")) + 8
    sheet_img = Image.new("RGBA", (pw + 12, (FRAME + 6) * len(preview_rows) + 6),
                          (24, 26, 34, 255))
    for i, (name, idle, walk, attack, roll) in enumerate(preview_rows):
        y = 6 + i * (FRAME + 6)
        x = 6
        for s in (idle, walk, attack, roll):
            sheet_img.alpha_composite(s, (x, y))
            x += s.width + 2
    sheet_img.save(os.path.join(ROOT, "tools", "_preview_sprites.png"))

    # 立绘接触表：96x128 原大 + 2x 放大，检查缩到 UI 尺寸后是否还认得出角色
    scale = 2
    cell_w = PORTRAIT_W * scale + AVATAR_SIZE * scale + 18
    portrait_img = Image.new("RGBA", (cell_w + 12, (PORTRAIT_H * scale + 8) * len(portrait_rows) + 6),
                             (24, 26, 34, 255))
    for i, (_name, portrait, avatar) in enumerate(portrait_rows):
        y = 6 + i * (PORTRAIT_H * scale + 8)
        big = portrait.resize((PORTRAIT_W * scale, PORTRAIT_H * scale), Image.NEAREST)
        portrait_img.alpha_composite(big, (6, y))
        av = avatar.resize((AVATAR_SIZE * scale, AVATAR_SIZE * scale), Image.NEAREST)
        portrait_img.alpha_composite(av, (6 + PORTRAIT_W * scale + 8, y))
    portrait_img.save(os.path.join(ROOT, "tools", "_preview_portraits.png"))

    for line in report:
        print(line)


if __name__ == "__main__":
    sys.exit(main())
