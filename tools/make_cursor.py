"""像素光标贴图：16x16 箭头（菜单）+ 十字准星（战斗），各含金色悬停版。

输出：assets/ui/cursor_arrow.png / cursor_arrow_hot.png / cursor_cross.png / cursor_cross_hot.png
约定：alpha 只有 0/255，1px 深色描边，热点见 ba_cursor.gd。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "ui"
OUT_DIR.mkdir(parents=True, exist_ok=True)

EDGE = (10, 14, 24, 255)
COLD = (220, 231, 255, 255)
HOT = (255, 209, 102, 255)
CYAN = (127, 227, 255, 255)
WHITE = (255, 255, 255, 255)

# 经典左箭头 10x16：X=描边 #=填充
ARROW = [
    "X         ",
    "XX        ",
    "X#X       ",
    "X##X      ",
    "X###X     ",
    "X####X    ",
    "X#####X   ",
    "X######X  ",
    "X#######X ",
    "X########X",
    "X#####XXXX",
    "X####X    ",
    "X###X     ",
    "X##X      ",
    "X#X       ",
    "XX        ",
]


def new():
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def put(im, x, y, c):
    if 0 <= x < 16 and 0 <= y < 16:
        im.putpixel((x, y), c)


def arrow(fill):
    im = new()
    for y, row in enumerate(ARROW):
        for x, ch in enumerate(row):
            if ch == "X":
                put(im, x + 1, y, EDGE)
            elif ch == "#":
                put(im, x + 1, y, fill)
    return im


def cross(col):
    im = new()
    body = set()
    for i in range(2, 6):
        body.add((8 - i, 8))
        body.add((8 + i, 8))
        body.add((8, 8 - i))
        body.add((8, 8 + i))
    body.add((8, 8))
    # 四角括号（L 形，向中心折）
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = 8 + sx * 6, 8 + sy * 6
            for i in range(3):
                body.add((cx - sx * i, cy))
                body.add((cx, cy - sy * i))
    for x, y in body:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in body:
                    put(im, x + dx, y + dy, EDGE)
    for x, y in body:
        put(im, x, y, WHITE if (x, y) == (8, 8) else col)
    return im


if __name__ == "__main__":
    arrow(COLD).save(OUT_DIR / "cursor_arrow.png")
    arrow(HOT).save(OUT_DIR / "cursor_arrow_hot.png")
    cross(CYAN).save(OUT_DIR / "cursor_cross.png")
    cross(HOT).save(OUT_DIR / "cursor_cross_hot.png")
    print("saved 4 cursors ->", OUT_DIR)
