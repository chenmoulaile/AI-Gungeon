"""P3 武器贴图管线：7 把武器 32x32x3 帧手持图 + 24x24 图标 + 8x8 弹丸。

生成：
  assets/weapons/{deepseek_starter,gpt_starter,claude_starter}.png
  assets/weapons/{excl_harness,excl_codex,excl_hammer,basin}.png
  assets/icons/weapons/{deepseek,gpt,claude,excl_harness,excl_codex,excl_hammer,dafeiyu}.png
  assets/weapons/proj/{rice,cloud,codex,page,iron}.png  (16x8, 2 帧)

约定：全部朝 +X（向右），1px 深色外描边，alpha 只有 0/255，整数坐标。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WPN = ROOT / "assets" / "weapons"
ICO = ROOT / "assets" / "icons" / "weapons"
PROJ = WPN / "proj"

OUT = (10, 13, 22, 255)
WHITE = (242, 242, 242, 255)
CREAM = (255, 243, 214, 255)
CYAN = (127, 227, 255, 255)
BLUE = (44, 74, 138, 255)
BLUE_L = (83, 118, 190, 255)
GOLD = (255, 209, 102, 255)
GOLD_D = (198, 146, 54, 255)
ORANGE = (255, 138, 77, 255)
ORANGE_D = (190, 90, 44, 255)
PURPLE = (176, 107, 255, 255)
PURPLE_D = (108, 62, 166, 255)
LILAC = (222, 205, 255, 255)
BROWN = (138, 90, 52, 255)
BROWN_D = (92, 58, 34, 255)
CLAY = (201, 139, 98, 255)
CLAY_L = (232, 176, 132, 255)
IRON = (138, 150, 170, 255)
IRON_D = (88, 100, 122, 255)
STEEL = (104, 136, 186, 255)
NAVY = (22, 30, 50, 255)
BLACK = (14, 18, 30, 255)


def new(w=32, h=32):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def mask_of(spans):
    m = set()
    for y, rs in spans.items():
        for x0, x1 in rs:
            for x in range(x0, x1 + 1):
                m.add((x, y))
    return m


def expand(m):
    o = set()
    for x, y in m:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in m:
                    o.add(p)
    return o


def paint(img, spans, colorfn, ol=OUT, clip=True):
    m = mask_of(spans)
    for x, y in expand(m):
        if 0 <= x < img.width and 0 <= y < img.height:
            img.putpixel((x, y), ol)
    for x, y in m:
        if 0 <= x < img.width and 0 <= y < img.height:
            c = colorfn(x, y)
            if c:
                img.putpixel((x, y), c)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def box(img, x0, y0, x1, y1, c, ol=None):
    if ol is not None:
        for x in range(x0 - 1, x1 + 2):
            put(img, x, y0 - 1, ol)
            put(img, x, y1 + 1, ol)
        for y in range(y0 - 1, y1 + 2):
            put(img, x0 - 1, y, ol)
            put(img, x1 + 1, y, ol)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def line(img, x0, y0, x1, y1, c):
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        put(img, x0, y0, c)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def ring(img, cx, cy, r, col, block=2):
    pts = set()
    for i in range(8):
        import math
        a = math.tau * i / 8.0
        pts.add((round(cx + math.cos(a) * r), round(cy + math.sin(a) * r)))
    for x, y in pts:
        for dx in range(block):
            for dy in range(block):
                put(img, x + dx, y + dy, col)


# ---------------------------------------------------------------- 饭盆
def bowl(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -2) if frame == 1 else (-2, 1))
    # Token 斜插（先画，碗沿压住底部）
    tw = {5 + oy: [(23 + ox, 24 + ox)], 6 + oy: [(22 + ox, 25 + ox)],
          7 + oy: [(21 + ox, 26 + ox)], 8 + oy: [(21 + ox, 26 + ox)],
          9 + oy: [(22 + ox, 25 + ox)], 10 + oy: [(23 + ox, 24 + ox)]}
    paint(img, tw, lambda x, y: CYAN if (x + y) % 5 else WHITE)
    for y in range(9 + oy, 15 + oy):
        box(img, 21 + ox, y, 22 + ox, y, BLUE)
    for i in range(3):  # 白色高光
        put(img, 22 + ox + i, 7 + oy, WHITE)
        put(img, 23 + ox, 8 + oy + i, WHITE)
    # 碗体
    spans = {
        14 + oy: [(18 + ox, 30 + ox)],
        15 + oy: [(14 + ox, 31 + ox)],
        16 + oy: [(12 + ox, 31 + ox)],
        17 + oy: [(11 + ox, 31 + ox)],
        18 + oy: [(11 + ox, 31 + ox)],
        19 + oy: [(12 + ox, 31 + ox)],
        20 + oy: [(13 + ox, 30 + ox)],
        21 + oy: [(14 + ox, 29 + ox)],
        22 + oy: [(15 + ox, 28 + ox)],
        23 + oy: [(16 + ox, 27 + ox)],
        24 + oy: [(18 + ox, 25 + ox)],
        25 + oy: [(20 + ox, 23 + ox)],
        26 + oy: [(21 + ox, 22 + ox)],
    }

    def body(x, y):
        yy = y - oy
        if yy <= 15:
            return CREAM
        if yy <= 17:
            return BLUE if (x + yy) % 3 == 0 else WHITE
        if yy in (18, 19):
            return BLUE
        if (x * 3 + yy) % 7 == 0:
            return BLUE_L
        if yy >= 23:
            return (201, 214, 234, 255)
        return WHITE

    paint(img, spans, body)
    # 碗内米饭
    inner = {14 + oy: [(17 + ox, 29 + ox)], 15 + oy: [(15 + ox, 30 + ox)],
             16 + oy: [(15 + ox, 29 + ox)]}
    paint(img, inner, lambda x, y: CREAM if (x + y) % 4 else WHITE)
    if frame == 1:
        for p in [(30, 12), (31, 13), (29, 14), (31, 15)]:
            put(img, p[0], p[1], WHITE)
    if frame == 2:
        for y in (16, 20, 24):
            line(img, 3, y, 5, y, (74, 128, 150, 255))


# ---------------------------------------------------------------- 云端龙息杖
def staff(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -1) if frame == 1 else (-2, 1))
    # 骨杖（两段弯曲）
    shaft = {
        23 + oy: [(7 + ox, 14 + ox)],
        22 + oy: [(8 + ox, 16 + ox)],
        21 + oy: [(10 + ox, 18 + ox)],
        20 + oy: [(12 + ox, 20 + ox)],
        19 + oy: [(15 + ox, 22 + ox)],
        18 + oy: [(18 + ox, 23 + ox)],
        17 + oy: [(21 + ox, 24 + ox)],
        16 + oy: [(22 + ox, 25 + ox)],
        15 + oy: [(24 + ox, 25 + ox)],
        14 + oy: [(24 + ox, 25 + ox)],
        13 + oy: [(25 + ox, 26 + ox)],
    }
    paint(img, shaft, lambda x, y: WHITE if y - oy <= 20 else (205, 216, 236, 255))
    # 紫色穗子
    for i, x in enumerate((7, 9, 11)):
        for y in range(24 + oy, 31 + oy):
            put(img, x + ox, y, PURPLE if (y + i) % 3 else PURPLE_D)
    # 云球
    grow = 1 if frame == 1 else 0
    cloud = {
        5 - grow + oy: [(24 + ox, 28 + ox)],
        6 - grow + oy: [(22 + ox, 30 + ox)],
        7 - grow + oy: [(21 + ox, 31 + ox)],
        8 - grow + oy: [(21 + ox, 31 + ox)],
        9 + oy: [(21 + ox, 31 + ox)],
        10 + oy: [(21 + ox, 30 + ox)],
        11 + oy: [(22 + ox, 29 + ox)],
        12 + oy: [(24 + ox, 27 + ox)],
    }

    def cloud_c(x, y):
        yy = y - oy
        if yy >= 9:
            return LILAC
        if (x + yy) % 4 == 0:
            return WHITE
        return (236, 228, 255, 255)

    paint(img, cloud, cloud_c)
    # 三爪
    for (x0, y0, x1, y1) in [(22, 15, 23, 12), (25, 15, 25, 12), (28, 16, 27, 13)]:
        line(img, x0 + ox, y0 + oy, x1 + ox, y1 + oy, PURPLE)
        put(img, x1 + ox, y1 + oy, PURPLE_D)
    if frame == 1:
        for p in [(26, 2), (32, 8), (18, 6)]:
            put(img, p[0], p[1], WHITE)


# ---------------------------------------------------------------- Claude 法典
def claude_book(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -1) if frame == 1 else (-2, 1))
    if frame == 1:
        # 开书：左右两页
        left = {13 + oy: [(13 + ox, 16 + ox)], 14 + oy: [(10 + ox, 16 + ox)],
                15 + oy: [(8 + ox, 16 + ox)], 16 + oy: [(7 + ox, 16 + ox)]}
        for y in range(17 + oy, 27 + oy):
            left[y] = [(7 + ox, 16 + ox)]
        paint(img, left, lambda x, y: CREAM if (x + y) % 5 else WHITE)
        right = {11 + oy: [(17 + ox, 20 + ox)], 12 + oy: [(17 + ox, 23 + ox)],
                 13 + oy: [(17 + ox, 26 + ox)]}
        for y in range(14 + oy, 27 + oy):
            right[y] = [(17 + ox, 28 + ox)]
        paint(img, right, lambda x, y: CREAM if (x + y) % 4 else WHITE)
        for y in range(15 + oy, 27 + oy, 3):
            line(img, 18 + ox, y, 27 + ox, y, BROWN)
        box(img, 16 + ox, 12 + oy, 17 + ox, 27 + oy, BROWN, OUT)
        return
    spans = {
        9 + oy: [(16 + ox, 27 + ox)],
        10 + oy: [(14 + ox, 30 + ox)],
        11 + oy: [(13 + ox, 31 + ox)],
        12 + oy: [(13 + ox, 31 + ox)],
        13 + oy: [(13 + ox, 31 + ox)],
        14 + oy: [(13 + ox, 31 + ox)],
        15 + oy: [(13 + ox, 31 + ox)],
        16 + oy: [(13 + ox, 31 + ox)],
        17 + oy: [(13 + ox, 31 + ox)],
        18 + oy: [(13 + ox, 31 + ox)],
        19 + oy: [(13 + ox, 31 + ox)],
        20 + oy: [(13 + ox, 31 + ox)],
        21 + oy: [(13 + ox, 31 + ox)],
        22 + oy: [(13 + ox, 31 + ox)],
        23 + oy: [(13 + ox, 31 + ox)],
        24 + oy: [(13 + ox, 31 + ox)],
        25 + oy: [(14 + ox, 30 + ox)],
        26 + oy: [(16 + ox, 28 + ox)],
    }

    def cover(x, y):
        yy = y - oy
        if x - ox <= 16:
            return BROWN
        if yy <= 11:
            return (255, 250, 232, 255)
        if yy == 25:
            return (222, 196, 156, 255)
        return CREAM

    paint(img, spans, cover)
    box(img, 14 + ox, 10 + oy, 16 + ox, 26 + oy, BROWN, OUT)
    # 金色包角
    for (x0, y0) in [(17, 10), (29, 10), (17, 24), (29, 24)]:
        box(img, x0 + ox, y0 + oy, x0 + 2 + ox, y0 + 2 + oy, GOLD, GOLD_D)
    # 葵花搭扣
    cx, cy = 25 + ox, 17 + oy
    for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]:
        put(img, cx + dx, cy + dy, GOLD)
    box(img, cx - 1, cy - 1, cx + 1, cy + 1, GOLD_D, OUT)
    # 橙色书签
    box(img, 22 + ox, 27 + oy, 24 + ox, 31 + oy, ORANGE, OUT)
    put(img, 23 + ox, 31 + oy, (0, 0, 0, 0))
    if frame == 2:
        line(img, 3, 18, 5, 18, ORANGE_D)


# ---------------------------------------------------------------- Codex 万律法典
def codex(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -1) if frame == 1 else (-2, 1))
    # 左页
    left = {}
    for y in range(10 + oy, 27 + oy):
        k = y - oy
        left[y] = [(8 + ox - (k < 14), 16 + ox)]
    paint(img, left, lambda x, y: CREAM if (x + y) % 5 else WHITE)
    # 右页
    right = {}
    for y in range(8 + oy, 27 + oy):
        k = y - oy
        right[y] = [(16 + ox, 30 + ox + (k >= 12))]
    paint(img, right, lambda x, y: CREAM if (x + y) % 4 else WHITE)
    # 金色书脊
    box(img, 15 + ox, 9 + oy, 17 + ox, 26 + oy, GOLD, GOLD_D)
    # 紫色封底
    box(img, 7 + ox, 26 + oy, 16 + ox, 28 + oy, PURPLE_D, OUT)
    box(img, 17 + ox, 26 + oy, 31 + ox, 28 + oy, PURPLE_D, OUT)
    # 页面文字线
    for y in range(12 + oy, 25 + oy, 3):
        line(img, 9 + ox, y, 14 + ox, y, GOLD_D)
    for y in range(11 + oy, 25 + oy, 3):
        line(img, 19 + ox, y, 28 + ox, y, GOLD_D)
    # 五页扇开
    for i, x in enumerate((20, 23, 26, 29)):
        box(img, x + ox, 6 + oy - i % 2, x + 1 + ox, 8 + oy - i % 2, WHITE, OUT)
    # 金色书签
    box(img, 27 + ox, 29 + oy, 29 + ox, 31 + oy, GOLD, OUT)
    # 悬浮符文
    for p in [(31, 6), (6, 8), (31, 24), (5, 23)]:
        put(img, p[0], p[1] + oy, GOLD)
    if frame == 1:
        for p in [(30, 12), (32, 15), (28, 20)]:
            put(img, p[0], p[1], WHITE)


# ---------------------------------------------------------------- Harness 虎鲸协议
def harness(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -1) if frame == 1 else (-2, 1))
    # 断缆
    for i in range(4):
        box(img, 4 + i * 2 + ox, 19 + oy + i % 2, 5 + i * 2 + ox, 20 + oy + i % 2, STEEL)
    # 虎鲸头
    head = {
        9 + oy: [(13 + ox, 20 + ox)],
        10 + oy: [(11 + ox, 22 + ox)],
        11 + oy: [(10 + ox, 23 + ox)],
        12 + oy: [(10 + ox, 24 + ox)],
        13 + oy: [(10 + ox, 25 + ox)],
        14 + oy: [(10 + ox, 26 + ox)],
        15 + oy: [(10 + ox, 28 + ox)],
        16 + oy: [(10 + ox, 30 + ox)],
        17 + oy: [(10 + ox, 30 + ox)],
        18 + oy: [(10 + ox, 30 + ox)],
        19 + oy: [(11 + ox, 30 + ox)],
        20 + oy: [(11 + ox, 29 + ox)],
        21 + oy: [(12 + ox, 27 + ox)],
        22 + oy: [(14 + ox, 25 + ox)],
        23 + oy: [(16 + ox, 23 + ox)],
    }

    def head_c(x, y):
        yy = y - oy
        if yy >= 19:
            return WHITE
        if yy <= 12:
            return BLACK
        if y - oy >= 17 and x - ox >= 24:
            return WHITE
        return NAVY

    paint(img, head, head_c)
    # 背鳍
    paint(img, {6 + oy: [(13 + ox, 14 + ox)], 7 + oy: [(12 + ox, 15 + ox)],
                8 + oy: [(11 + ox, 16 + ox)], 9 + oy: [(11 + ox, 17 + ox)]},
          lambda x, y: BLACK)
    # 白色眼斑 + 青色瞳孔
    box(img, 22 + ox, 14 + oy, 25 + ox, 16 + oy, WHITE)
    box(img, 24 + ox, 15 + oy, 25 + ox, 16 + oy, CYAN, OUT)
    # 上颚鱼叉
    box(img, 20 + ox, 12 + oy, 31 + ox, 13 + oy, STEEL, OUT)
    for x in (29, 31):
        put(img, x + ox, 10 + oy, STEEL)
        put(img, x + ox, 11 + oy, STEEL)
    put(img, 30 + ox, 14 + oy, CYAN)
    # 嘴
    if frame == 1:
        box(img, 26 + ox, 21 + oy, 30 + ox, 22 + oy, BLACK)
        put(img, 30 + ox, 21 + oy, WHITE)
    else:
        line(img, 26 + ox, 21 + oy, 30 + ox, 21 + oy, BLACK)
    if frame == 2:
        for y in (13, 17, 21):
            line(img, 2, y, 4, y, (54, 108, 136, 255))


# ---------------------------------------------------------------- 圣女法槌
def hammer(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -2) if frame == 1 else (0, 1))
    # 木柄
    box(img, 6 + ox, 18 + oy, 22 + ox, 21 + oy, BROWN, OUT)
    box(img, 6 + ox, 18 + oy, 21 + ox, 18 + oy, (166, 112, 68, 255))
    # 缎带
    box(img, 6 + ox, 22 + oy, 8 + ox, 27 + oy, ORANGE, OUT)
    for y in range(22 + oy, 28 + oy, 2):
        put(img, 7 + ox, y, ORANGE_D)
    # 槌头
    box(img, 22 + ox, 9 + oy, 31 + ox, 28 + oy, CLAY, OUT)
    box(img, 22 + ox, 9 + oy, 31 + ox, 10 + oy, GOLD, GOLD_D)
    box(img, 22 + ox, 27 + oy, 31 + ox, 28 + oy, GOLD, GOLD_D)
    box(img, 22 + ox, 11 + oy, 23 + ox, 26 + oy, CLAY_L)
    # 葵花
    cx, cy = 27 + ox, 19 + oy
    for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]:
        put(img, cx + dx, cy + dy, GOLD)
    box(img, cx - 1, cy - 1, cx + 1, cy + 1, ORANGE_D, OUT)
    if frame == 1:
        for y in (12, 16, 20):
            line(img, 3, y, 6, y - 1, GOLD_D)
    if frame == 2:
        for p in [(30, 30), (29, 31), (31, 31)]:
            put(img, p[0], p[1], GOLD)


# ---------------------------------------------------------------- 大肥鱼炼丹铁盆
def basin(img, frame=0):
    ox, oy = (0, 0) if frame == 0 else ((0, -1) if frame == 1 else (-2, 1))
    # 炼丹环
    r = 6 if frame == 0 else (8 if frame == 1 else 7)
    ring(img, 21 + ox, 8 + oy, r, PURPLE, 2)
    # 提手
    box(img, 6 + ox, 15 + oy, 11 + ox, 18 + oy, IRON, OUT)
    box(img, 31 + ox, 15 + oy, 31 + ox, 18 + oy, IRON_D)
    # 盆体
    spans = {
        14 + oy: [(12 + ox, 30 + ox)],
        15 + oy: [(11 + ox, 31 + ox)],
        16 + oy: [(11 + ox, 31 + ox)],
        17 + oy: [(12 + ox, 31 + ox)],
        18 + oy: [(12 + ox, 30 + ox)],
        19 + oy: [(13 + ox, 29 + ox)],
        20 + oy: [(14 + ox, 28 + ox)],
        21 + oy: [(15 + ox, 27 + ox)],
        22 + oy: [(16 + ox, 26 + ox)],
        23 + oy: [(17 + ox, 25 + ox)],
        24 + oy: [(18 + ox, 24 + ox)],
        25 + oy: [(19 + ox, 23 + ox)],
    }

    def iron_c(x, y):
        yy = y - oy
        if yy <= 15:
            return IRON if (x + yy) % 4 else STEEL
        if yy >= 22:
            return IRON_D
        return IRON

    paint(img, spans, iron_c)
    # 紫色丹液
    paint(img, {14 + oy: [(14 + ox, 29 + ox)], 15 + oy: [(13 + ox, 30 + ox)],
                16 + oy: [(15 + ox, 29 + ox)]},
          lambda x, y: PURPLE if (x + y) % 3 else LILAC)
    # 铆钉
    for x in (14, 18, 22, 26, 30):
        put(img, x + ox, 17 + oy, STEEL)
    if frame == 1:
        for p in [(21, 0), (13, 3), (30, 3), (12, 12), (31, 12)]:
            put(img, p[0], p[1], PURPLE)
    if frame == 2:
        for p in [(21, 2), (19, 5), (24, 5)]:
            put(img, p[0], p[1], PURPLE)
        line(img, 2, 20, 5, 22, PURPLE_D)


# ---------------------------------------------------------------- 24x24 图标
def icon_base():
    return new(24, 24)


def icon_bowl(img):
    spans = {9: [(11, 22)], 10: [(9, 23)], 11: [(8, 23)], 12: [(9, 23)], 13: [(10, 22)],
             14: [(12, 21)], 15: [(15, 18)]}

    def c(x, y):
        if y <= 10:
            return CREAM
        if y == 11:
            return BLUE if x % 3 == 0 else WHITE
        return WHITE if y < 13 else (201, 214, 234, 255)

    paint(img, spans, c)
    paint(img, {6: [(17, 18)], 7: [(16, 19)], 8: [(16, 19)], 9: [(17, 18)]},
          lambda x, y: CYAN if (x + y) % 4 else WHITE)
    box(img, 16, 8, 17, 10, BLUE)


def icon_staff(img):
    # 杖身：2px 宽 + 两侧描边，顶端接住云球，24px 下也能看清
    for y in range(9, 20):
        x = 23 - y
        put(img, x, y, WHITE)
        put(img, x + 1, y, (205, 216, 236, 255))
        put(img, x - 1, y, OUT)
        put(img, x + 2, y, OUT)
    paint(img, {4: [(17, 19)], 5: [(15, 21)], 6: [(14, 22)], 7: [(14, 22)],
                8: [(15, 21)], 9: [(17, 20)]}, lambda x, y: LILAC if y < 7 else PURPLE)
    for x in (5, 7):
        for y in range(20, 24):
            put(img, x, y, PURPLE)
    for x, y in [(14, 6), (16, 9), (20, 6)]:
        put(img, x, y, WHITE)


def icon_book(img):
    paint(img, {5: [(9, 18)], 6: [(7, 20)], 7: [(6, 21)]}, lambda x, y: CREAM)
    for y in range(8, 20):
        for x in range(5, 21):
            if y < 19:
                put(img, x, y, CREAM if (x + y) % 5 else WHITE)
    box(img, 5, 5, 8, 20, BROWN, OUT)
    for x0, y0 in [(9, 5), (17, 5), (9, 17), (17, 17)]:
        box(img, x0, y0, x0 + 1, y0 + 1, GOLD)
    box(img, 15, 11, 17, 13, GOLD, GOLD_D)
    box(img, 12, 19, 14, 22, ORANGE, OUT)


def icon_codex(img):
    for y in range(6, 19):
        for x in range(4, 11):
            put(img, x, y, CREAM if (x + y) % 5 else WHITE)
    for y in range(5, 19):
        for x in range(12, 21):
            if y >= 5:
                put(img, x, y, CREAM if (x + y) % 4 else WHITE)
    box(img, 10, 5, 12, 19, GOLD, GOLD_D)
    box(img, 3, 18, 10, 20, PURPLE_D, OUT)
    box(img, 12, 18, 21, 20, PURPLE_D, OUT)
    for y in (8, 12, 16):
        line(img, 5, y, 9, y, GOLD_D)
        line(img, 13, y, 19, y, GOLD_D)


def icon_harness(img):
    paint(img, {6: [(9, 17)], 7: [(8, 19)], 8: [(7, 20)], 9: [(7, 21)], 10: [(7, 21)],
                11: [(7, 21)], 12: [(7, 20)], 13: [(8, 19)], 14: [(9, 17)]},
          lambda x, y: WHITE if y >= 12 else BLACK)
    paint(img, {3: [(10, 11)], 4: [(9, 12)], 5: [(9, 13)]}, lambda x, y: BLACK)
    box(img, 15, 6, 16, 13, STEEL, OUT)
    for x in (14, 16):
        put(img, x, 5, STEEL)
    box(img, 16, 9, 18, 10, WHITE)
    put(img, 18, 10, CYAN)
    box(img, 3, 14, 8, 15, STEEL)


def icon_hammer(img):
    box(img, 3, 13, 14, 15, BROWN, OUT)
    box(img, 12, 5, 20, 21, CLAY, OUT)
    box(img, 12, 5, 20, 6, GOLD, GOLD_D)
    box(img, 12, 20, 20, 21, GOLD, GOLD_D)
    for dx, dy in [(-2, 12), (2, 12), (0, 10), (0, 14)]:
        put(img, 16 + dx, 12 + dy, GOLD)
    box(img, 15, 11, 17, 13, ORANGE_D, OUT)
    box(img, 3, 16, 5, 20, ORANGE, OUT)


def icon_basin(img):
    spans = {7: [(5, 18)], 8: [(4, 19)], 9: [(4, 19)], 10: [(5, 19)], 11: [(6, 18)],
             12: [(7, 17)], 13: [(8, 16)], 14: [(10, 14)]}
    paint(img, spans, lambda x, y: IRON if y < 10 else IRON_D)
    paint(img, {7: [(6, 17)], 8: [(5, 18)]}, lambda x, y: PURPLE)
    ring(img, 12, 4, 4, PURPLE, 1)
    box(img, 2, 7, 4, 9, IRON, OUT)


# ---------------------------------------------------------------- 弹丸
def projectile(img, kind, frame):
    if kind == "rice":
        for y in range(1, 7):
            for x in range(1, 7):
                put(img, x, y + frame, CREAM if (x + y) % 3 else WHITE)
        box(img, 2, 2 + frame, 5, 5 + frame, CREAM, OUT)
        put(img, 3, 3 + frame, BLUE)
    elif kind == "cloud":
        paint(img, {1 + frame: [(2, 5)], 2: [(1, 6)], 3: [(1, 6)], 4: [(2, 5)]},
              lambda x, y: LILAC if x < 5 else WHITE)
    elif kind == "codex":
        box(img, 1, 3 + frame, 6, 4 + frame, GOLD, OUT)
        put(img, 7, 3 + frame, GOLD)
    elif kind == "page":
        box(img, 2, 1, 5, 6, CREAM, OUT)
        line(img, 3, 2, 3, 5, ORANGE_D)
        put(img, 4, 3, GOLD)
    elif kind == "iron":
        ring(img, 3, 3, 2, PURPLE, 1)
        put(img, 3, 3, LILAC)


# ---------------------------------------------------------------- 组装
def fit_margin(im, margin=1):
    bbox = im.split()[3].getbbox()
    if bbox is None:
        return im
    x0, y0, x1, y1 = bbox
    dx = 0
    dy = 0
    if x0 < margin:
        dx = margin - x0
    elif x1 > im.width - margin:
        dx = (im.width - margin) - x1
    if y0 < margin:
        dy = margin - y0
    elif y1 > im.height - margin:
        dy = (im.height - margin) - y1
    if dx == 0 and dy == 0:
        return im
    out = new(im.width, im.height)
    out.paste(im, (dx, dy))
    return out


def center(im):
    """把图标内容居中到画布中心，避免 HUD/商店槽里偏右偏上。"""
    bbox = im.split()[3].getbbox()
    if bbox is None:
        return im
    x0, y0, x1, y1 = bbox
    dx = (im.width - (x1 - x0)) // 2 - x0
    dy = (im.height - (y1 - y0)) // 2 - y0
    if dx == 0 and dy == 0:
        return im
    out = new(im.width, im.height)
    out.paste(im, (dx, dy))
    return out


def sheet(drawfn, path):
    frames = []
    for f in range(3):
        im = new()
        drawfn(im, f)
        frames.append(fit_margin(im))
    out = Image.new("RGBA", (96, 32), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        out.paste(im, (i * 32, 0))
    out.save(path)
    return out


def contact(items, path):
    scale = 6
    pad = 8
    w = max(i.width for i in items) * scale
    h = sum(i.height * scale + pad for i in items)
    canvas = Image.new("RGBA", (w, h), (26, 34, 56, 255))
    y = 0
    for im in items:
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        canvas.paste(big, (0, y), big)
        y += big.height + pad
    canvas.save(path)


def main():
    WPN.mkdir(parents=True, exist_ok=True)
    ICO.mkdir(parents=True, exist_ok=True)
    PROJ.mkdir(parents=True, exist_ok=True)

    sheets = {
        "deepseek_starter": bowl,
        "gpt_starter": staff,
        "claude_starter": claude_book,
        "excl_harness": harness,
        "excl_codex": codex,
        "excl_hammer": hammer,
        "basin": basin,
    }
    for name, fn in sheets.items():
        sheet(fn, WPN / f"{name}.png")

    icons = {
        "deepseek": icon_bowl,
        "gpt": icon_staff,
        "claude": icon_book,
        "excl_harness": icon_harness,
        "excl_codex": icon_codex,
        "excl_hammer": icon_hammer,
        "dafeiyu": icon_basin,
    }
    for name, fn in icons.items():
        im = icon_base()
        fn(im)
        center(fit_margin(im)).save(ICO / f"{name}.png")

    proj_icons = {}
    for kind in ("rice", "cloud", "codex", "page", "iron"):
        out = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
        for f in range(2):
            im = new(8, 8)
            projectile(im, kind, f)
            out.paste(im, (f * 8, 0))
        out.save(PROJ / f"{kind}.png")

    preview = [Image.open(WPN / f"{n}.png") for n in sheets]
    contact(preview, ROOT / "tools" / "_weapons_preview.png")
    print("weapons ok:", len(sheets), "icons:", len(icons))


if __name__ == "__main__":
    main()
