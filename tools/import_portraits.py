"""导入新立绘：去白底 -> 全身透明 PNG / 正视图面部裁切 / 半身像。

输入（用户提供的原始图，白底 JPG）：
  claude  : clipboard ...-a7ffe09d.jpg  正面全身
  gpt     : clipboard ...-5cf36177.jpg  正面全身
  deepseek: clipboard ...-4504db87.jpg  正面全身

输出：
  assets/portraits/<id>_full.png   全身（透明底，高 1024）
  assets/portraits/<id>_face.png   2:3 面部裁切 + 底部渐隐（角色卡片用）
  assets/portraits/<id>_bust.png   1:1 半身（结算界面用）

运行：python tools/import_portraits.py <源目录>
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# id -> (源文件名, 面部中心 x 比例, 面部中心 y 比例, 面部裁切宽度比例)
SOURCES = {
    "claude": ("clipboard-2026-10-23T14-10-14-845Z-a7ffe09d.jpg", 0.50, 0.075, 0.46),
    "gpt": ("clipboard-2026-10-23T14-10-14-846Z-5cf36177.jpg", 0.50, 0.085, 0.42),
    "deepseek": ("clipboard-2026-10-23T14-10-14-851Z-4504db87.jpg", 0.50, 0.085, 0.44),
}


def cut_background(src: Image.Image) -> Image.Image:
    """从四角泛洪去掉近白背景，边缘做一次去白边处理。"""
    img = src.convert("RGB")
    marked = img.copy()
    w, h = marked.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(marked, corner, (255, 0, 255), thresh=26)
    arr = np.array(marked).astype(np.int16)
    bg = (arr[:, :, 0] > 240) & (arr[:, :, 1] < 40) & (arr[:, :, 2] > 240)
    alpha = np.where(bg, 0, 255).astype(np.uint8)

    # 边缘去白：靠近透明区的浅色像素按亮度给半透明，避免白边
    src_arr = np.array(img).astype(np.float32)
    lum = src_arr.min(axis=2)
    edge = (~bg) & (lum > 232)
    if edge.any():
        # 只处理距离透明区 2px 内的浅色像素
        near = np.zeros_like(bg)
        near[1:, :] |= bg[:-1, :]
        near[:-1, :] |= bg[1:, :]
        near[:, 1:] |= bg[:, :-1]
        near[:, :-1] |= bg[:, 1:]
        near[2:, :] |= bg[:-2, :]
        near[:-2, :] |= bg[2:, :]
        near[:, 2:] |= bg[:, :-2]
        near[:, :-2] |= bg[:, 2:]
        fringe = edge & near
        alpha[fringe] = (np.clip((255.0 - lum[fringe]) / 22.0, 0.0, 1.0) * 255).astype(np.uint8)

    out = np.dstack([src_arr.astype(np.uint8), alpha])
    res = Image.fromarray(out, "RGBA")
    bbox = res.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    return res.crop(bbox) if bbox else res


def save_full(img: Image.Image, char_id: str) -> None:
    scale = 1024.0 / img.height
    out = img.resize((max(1, int(img.width * scale)), 1024), Image.LANCZOS)
    out.save(ROOT / "assets" / "portraits" / f"{char_id}_full.png")


def save_face(img: Image.Image, char_id: str, fx: float, fy: float, fw: float) -> None:
    w = img.width
    crop_w = int(w * fw)
    crop_h = int(crop_w * 1.5)
    cx = int(w * fx)
    cy = int(img.height * fy)
    left = max(0, min(cx - crop_w // 2, w - crop_w))
    top = max(0, min(cy - int(crop_h * 0.34), img.height - crop_h))
    crop = img.crop((left, top, left + crop_w, top + crop_h)).resize((512, 768), Image.LANCZOS)
    arr = np.array(crop).astype(np.float32)
    fade0 = int(768 * 0.80)
    for y in range(fade0, 768):
        k = 1.0 - (y - fade0) / float(768 - fade0)
        arr[y, :, 3] *= max(0.0, k)
    Image.fromarray(arr.clip(0, 255).astype(np.uint8)).save(
        ROOT / "assets" / "portraits" / f"{char_id}_face.png")


def save_bust(img: Image.Image, char_id: str, fx: float, fy: float) -> None:
    side = int(img.width * 0.92)
    cx = int(img.width * fx)
    cy = int(img.height * fy) + int(side * 0.18)
    left = max(0, min(cx - side // 2, img.width - side))
    top = max(0, min(cy - side // 2, img.height - side))
    crop = img.crop((left, top, left + side, top + side)).resize((512, 512), Image.LANCZOS)
    crop.save(ROOT / "assets" / "portraits" / f"{char_id}_bust.png")


def main() -> None:
    src_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "C:/Users/chenk/.workbuddy-ai/clipboard-images")
    for cid, (name, fx, fy, fw) in SOURCES.items():
        path = src_dir / name
        if not path.exists():
            print("missing", path)
            continue
        cut = cut_background(Image.open(path))
        save_full(cut, cid)
        save_face(cut, cid, fx, fy, fw)
        save_bust(cut, cid, fx, fy)
        print("ok", cid, cut.size)


if __name__ == "__main__":
    main()
