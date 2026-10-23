"""生成角色选择界面用的正视图立绘裁切（面部居中 + 底部渐隐）。

输入：assets/portraits/<id>_full.png（1024x1024 全身立绘）
输出：assets/portraits/<id>_face.png（512x768，2:3，底部 20% alpha 渐隐）

规则：
- 裁切以面部为中心，保留发际线到胸口的范围，双眼可见。
- 保留标志性配饰：DeepSeek 蓝色发带蝴蝶结 / GPT 龙角 / Claude 向日葵。
- Claude 原始立绘为侧面，按需求取最接近正面的角度并水平翻转，使面部朝向画面内侧。

运行：python tools/make_face_portraits.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_W, OUT_H = 512, 768
FADE_FROM = 0.80

# id: (面部中心 x, 面部中心 y, 裁切宽度, 是否水平翻转)
CROPS = {
    "deepseek": (505, 368, 520, False),
    "gpt": (512, 352, 520, False),
    "claude": (655, 315, 520, True),
}


def build(char_id: str) -> Path:
    cx, cy, w, flip = CROPS[char_id]
    src = Image.open(ROOT / "assets" / "portraits" / f"{char_id}_full.png").convert("RGBA")
    h = int(w * 1.5)
    left = int(cx - w / 2)
    top = int(cy - h * 0.40)
    left = max(0, min(left, src.width - w))
    top = max(0, min(top, src.height - h))
    crop = src.crop((left, top, left + w, top + h)).resize((OUT_W, OUT_H), Image.LANCZOS)
    if flip:
        crop = crop.transpose(Image.FLIP_LEFT_RIGHT)

    arr = np.array(crop).astype(np.float32)
    fade0 = int(OUT_H * FADE_FROM)
    for y in range(fade0, OUT_H):
        k = 1.0 - (y - fade0) / float(OUT_H - fade0)
        arr[y, :, 3] *= max(0.0, k)

    out = ROOT / "assets" / "portraits" / f"{char_id}_face.png"
    Image.fromarray(arr.clip(0, 255).astype(np.uint8)).save(out)
    return out


def main() -> None:
    for cid in CROPS:
        print("wrote", build(cid))


if __name__ == "__main__":
    main()
