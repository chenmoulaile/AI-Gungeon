"""像素帧表验收：alpha 二值 / 帧尺寸 / 脚底基准 / 调色板数量 / 描边粗细。

用法：
    <python> tools/validate_sprites.py

任何一项不达标会打印 FAIL 并以非 0 退出，方便在提交前当门禁用。
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_pixel_sprites import (CHARACTERS, FEET_Y, FRAME, SPRITE_DIR,  # noqa: E402
                                PORTRAIT_DIR, PORTRAIT_W, PORTRAIT_H, AVATAR_SIZE)

EXPECTED = {"idle": 4, "walk": 6, "attack": 3, "roll": 4}
MAX_PALETTE = 22          # 20 色量化 + 描边色，留 1 色余量
MAX_PALETTE_STILL = 26    # 立绘/头像多出 3 色重绘眼睛（虹膜/眼睑/高光）
OUTLINE_TOLERANCE = 12    # 允许的异常描边像素数（手指/发梢等细节）
BOUNDARY_MISS_MAX = 0.04  # 边界像素不是描边色的比例上限


def _fail(msg):
    print("  FAIL " + msg)
    return 1


def check_frame(img, outline):
    fails = 0
    arr = np.array(img.convert("RGBA"))
    a = arr[:, :, 3]

    if not np.isin(a, (0, 255)).all():
        fails += _fail("存在半透明像素（alpha 必须是二值）")

    ys, xs = np.where(a > 0)
    if len(xs) == 0:
        return _fail("空帧"), 0, 0
    if ys.max() > FEET_Y + 1:
        fails += _fail("脚底超出基准线 y=%d（实际 %d）" % (FEET_Y + 1, ys.max()))
    if xs.min() == 0 or xs.max() == FRAME - 1:
        fails += _fail("主体贴到画布左右边缘，描边会被裁掉")

    colors = arr[a > 0][:, :3].astype(np.uint8)
    uniq = np.unique(colors, axis=0)
    if len(uniq) > MAX_PALETTE:
        fails += _fail("调色板 %d 色 > %d" % (len(uniq), MAX_PALETTE))

    # 边界像素应当就是描边色
    mask = a > 0
    padded = np.pad(mask, 1, constant_values=False)
    boundary = mask & ~(padded[:-2, 1:-1] & padded[2:, 1:-1]
                        & padded[1:-1, :-2] & padded[1:-1, 2:])
    oc = np.array(outline[:3], dtype=np.uint8)
    mism = (boundary & ~np.all(arr[:, :, :3] == oc, axis=2)).sum()
    total = max(1, boundary.sum())
    if mism / total > BOUNDARY_MISS_MAX:
        fails += _fail("边界像素只有 %.0f%% 是描边色" % (100.0 * (1 - mism / total)))

    # 描边厚度：描边色像素不应四邻全是描边色（那就是 >=2px）
    is_oc = np.all(arr[:, :, :3] == oc, axis=2) & mask
    p = np.pad(is_oc, 1, constant_values=False)
    interior = is_oc & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    if interior.sum() > OUTLINE_TOLERANCE:
        fails += _fail("描边过厚（%d 个描边色像素被描边色四面包围）" % interior.sum())

    return fails, xs.max() - xs.min() + 1, ys.max()


def check_still(img, outline, label):
    """静态像素图（立绘 / 头像）的通用检查：二值 alpha / 调色板 / 边界描边 / 不被裁切。"""
    fails = 0
    arr = np.array(img.convert("RGBA"))
    a = arr[:, :, 3]
    if not np.isin(a, (0, 255)).all():
        fails += _fail("%s 存在半透明像素" % label)

    ys, xs = np.where(a > 0)
    if len(xs) == 0:
        return _fail("%s 空图" % label)
    if xs.min() == 0 or xs.max() == img.width - 1 or ys.max() == img.height - 1:
        fails += _fail("%s 主体贴边，描边被裁" % label)

    uniq = np.unique(arr[a > 0][:, :3].astype(np.uint8), axis=0)
    if len(uniq) > MAX_PALETTE_STILL:
        fails += _fail("%s 调色板 %d 色 > %d" % (label, len(uniq), MAX_PALETTE_STILL))

    mask = a > 0
    padded = np.pad(mask, 1, constant_values=False)
    boundary = mask & ~(padded[:-2, 1:-1] & padded[2:, 1:-1]
                        & padded[1:-1, :-2] & padded[1:-1, 2:])
    oc = np.array(outline[:3], dtype=np.uint8)
    mism = (boundary & ~np.all(arr[:, :, :3] == oc, axis=2)).sum()
    total = max(1, boundary.sum())
    if mism / total > BOUNDARY_MISS_MAX:
        fails += _fail("%s 边界只有 %.0f%% 是描边色" % (label, 100.0 * (1 - mism / total)))
    return fails


def main():
    print("=" * 56)
    total_fails = 0
    for name, cfg in CHARACTERS.items():
        print("%s" % name)
        outline = cfg["outline"]
        for anim, count in EXPECTED.items():
            path = os.path.join(SPRITE_DIR, name, anim + ".png")
            if not os.path.exists(path):
                total_fails += _fail("%s 缺失" % anim)
                continue
            img = Image.open(path).convert("RGBA")
            if img.height != FRAME or img.width != FRAME * count:
                total_fails += _fail("%s 尺寸 %dx%d，期望 %dx%d"
                                     % (anim, img.width, img.height, FRAME * count, FRAME))
                continue

            baselines = []
            for i in range(count):
                f = img.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
                fails, w, ymax = check_frame(f, outline)
                total_fails += fails
                baselines.append(ymax)
            if max(baselines) - min(baselines) > 1:
                total_fails += _fail("%s 脚底基准不一致（%s）" % (anim, baselines))

            print("  OK   %-6s %d 帧  主体宽 %d  脚底 %s"
                  % (anim, count, w, sorted(set(baselines))))

        icon_path = os.path.join(SPRITE_DIR, name, "portrait_icon.png")
        if os.path.exists(icon_path):
            icon = Image.open(icon_path).convert("RGBA")
            a = np.array(icon)[:, :, 3]
            if icon.size != (32, 32):
                total_fails += _fail("portrait_icon 尺寸 %s != (32,32)" % (icon.size,))
            elif not np.isin(a, (0, 255)).all():
                total_fails += _fail("portrait_icon 有半透明像素")
            else:
                print("  OK   icon  32x32")

        # 96x128 像素立绘 + 32x32 头像
        for suffix, size in ((("_pixel"), (PORTRAIT_W, PORTRAIT_H)),
                             ("_pixel_avatar", (AVATAR_SIZE, AVATAR_SIZE))):
            ppath = os.path.join(PORTRAIT_DIR, name + suffix + ".png")
            if not os.path.exists(ppath):
                total_fails += _fail("%s 立绘缺失（%s）" % (suffix, ppath))
                continue
            pimg = Image.open(ppath).convert("RGBA")
            if pimg.size != size:
                total_fails += _fail("%s 尺寸 %s != %s" % (suffix, pimg.size, size))
                continue
            fails = check_still(pimg, outline, suffix.strip("_"))
            total_fails += fails
            if fails == 0:
                print("  OK   %-13s %dx%d" % (suffix.strip("_"), size[0], size[1]))

    print("=" * 56)
    print("失败项: %d" % total_fails)
    return 1 if total_fails else 0


if __name__ == "__main__":
    sys.exit(main())
