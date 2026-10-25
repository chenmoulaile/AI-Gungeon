"""武器贴图管线 v2：三把主武器 + 三把专武。

生成：
  assets/weapons/{deepseek_starter,gpt_starter,claude_starter}.png   96x32 三帧
  assets/weapons/{excl_harness,excl_codex,excl_claude_code}.png
  assets/icons/weapons/{deepseek,gpt,claude,excl_harness,excl_codex,claude_code}.png  24x24

约定：全部朝 +X（向右），1px 深色外描边，alpha 只有 0/255，整数坐标。
禁止 1px 棋盘抖动（旧版噪点来源）：只用整块色阶 + 单像素高光。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WPN = ROOT / "assets" / "weapons"
ICO = ROOT / "assets" / "icons" / "weapons"

EDGE = (10, 14, 24, 255)
WHITE = (242, 242, 242, 255)
CREAM = (255, 243, 214, 255)
CREAM_D = (222, 196, 156, 255)
CYAN = (127, 227, 255, 255)
CYAN_D = (74, 150, 190, 255)
BLUE = (44, 74, 138, 255)
BLUE_D = (26, 42, 80, 255)
BLUE_L = (83, 118, 190, 255)
GOLD = (255, 209, 102, 255)
GOLD_D = (198, 146, 54, 255)
ORANGE = (255, 138, 77, 255)
ORANGE_D = (190, 90, 44, 255)
PURPLE = (176, 107, 255, 255)
PURPLE_D = (108, 62, 166, 255)
BROWN = (110, 68, 38, 255)
BROWN_D = (74, 44, 24, 255)
BROWN_L = (150, 96, 52, 255)
SILVER = (201, 210, 228, 255)
SILVER_D = (140, 150, 172, 255)
SILVER_L = (238, 242, 250, 255)
NAVY = (26, 34, 56, 255)
STEEL = (52, 66, 96, 255)
TERM = (16, 22, 40, 255)


def new(w=32, h=32):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def box(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c)


def spans_mask(spans, dx=0, dy=0):
    m = set()
    for y, rs in spans.items():
        for x0, x1 in rs:
            for x in range(x0, x1 + 1):
                m.add((x + dx, y + dy))
    return m


def outline(im, mask, col=EDGE):
    for x, y in mask:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in mask:
                    put(im, x + dx, y + dy, col)


def paint(im, spans, colfn, dx=0, dy=0):
    m = spans_mask(spans, dx, dy)
    outline(im, m)
    for x, y in m:
        c = colfn(x - dx, y - dy)
        if c:
            put(im, x, y, c)
    return m


def frame_of(f):
    return (0, 0) if f == 0 else ((0, -2) if f == 1 else (-2, 1))


# ---------------------------------------------------------------- 饭盆
def draw_bowl(im, f):
    dx, dy = frame_of(f)
    spans = {
        8: [(12, 20)], 9: [(10, 22)], 10: [(9, 23)], 11: [(8, 24)], 12: [(8, 24)],
        13: [(6, 25)],
        14: [(7, 25)], 15: [(6, 26)], 16: [(6, 26)], 17: [(7, 26)], 18: [(7, 26)],
        19: [(8, 25)], 20: [(8, 25)], 21: [(9, 24)], 22: [(10, 23)], 23: [(10, 22)],
        24: [(12, 21)], 25: [(12, 20)], 26: [(13, 19)],
    }

    def col(x, y):
        if y <= 12:
            return CREAM
        if y == 13:
            return GOLD if x % 3 else GOLD_D
        if y >= 24:
            return BLUE_D
        if x <= 8:
            return BLUE_L
        return BLUE

    paint(im, spans, col, dx, dy)
    # 米粒间的青色 Token
    for tx, ty in [(11, 11), (14, 10), (18, 10), (21, 11), (12, 12), (17, 12), (20, 12), (15, 9)]:
        put(im, tx + dx, ty + dy, CYAN)
    # 碗身鲸鱼纹章
    whale = [(13, 19), (14, 19), (15, 19), (16, 18), (17, 18), (14, 20), (15, 20),
             (16, 20), (17, 20), (18, 20), (19, 20), (20, 19), (21, 18),
             (15, 21), (16, 21), (17, 21), (18, 21), (16, 22)]
    for wx, wy in whale:
        put(im, wx + dx, wy + dy, CREAM)
    # 碗沿高光
    for hx in range(8 + dx, 24 + dx, 2):
        put(im, hx, 13 + dy, GOLD)


def icon_bowl(im):
    spans = {5: [(5, 17)], 6: [(4, 18)], 7: [(4, 18)], 8: [(2, 20)],
             9: [(3, 20)], 10: [(4, 19)], 11: [(5, 18)], 12: [(6, 17)],
             13: [(7, 16)], 14: [(8, 15)], 15: [(9, 14)]}

    def col(x, y):
        if y <= 7:
            return CREAM
        if y == 8:
            return GOLD
        return BLUE_L if x <= 5 else BLUE

    paint(im, spans, col)
    for tx, ty in [(6, 6), (10, 5), (14, 6), (9, 7), (13, 7)]:
        put(im, tx, ty, CYAN)
    for wx, wy in [(8, 11), (9, 11), (10, 11), (11, 10), (12, 10),
                   (9, 12), (10, 12), (11, 12), (12, 12), (13, 11)]:
        put(im, wx, wy, CREAM)


# ---------------------------------------------------------------- 云端龙息杖
def draw_staff(im, f):
    dx, dy = frame_of(f)
    # 杖身：3px 宽银色斜杆（右下握把 -> 左上杖头）
    for i in range(0, 17):
        x = 6 + i
        y = 28 - i
        put(im, x + dx, y + dy, SILVER_L)
        put(im, x + 1 + dx, y + dy, SILVER)
        put(im, x + 2 + dx, y + dy, SILVER_D)
    # 金色卷草纹
    for cxp, cyp in [(11, 22), (12, 22), (13, 21), (13, 20), (12, 19), (11, 20)]:
        put(im, cxp + dx, cyp + dy, GOLD)
    # 杖尾紫穗
    for i, sx in enumerate((4, 6)):
        for y in range(27, 31):
            put(im, sx + dx, y + dy, PURPLE if (y + i) % 2 else PURPLE_D)
    # 银色三指爪托住云球
    for (x0, y0, x1, y1) in [(20, 14, 17, 9), (21, 13, 23, 7), (21, 14, 27, 10)]:
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for s in range(steps + 1):
            x = x0 + (x1 - x0) * s // max(1, steps)
            y = y0 + (y1 - y0) * s // max(1, steps)
            put(im, x + dx, y + dy, SILVER)
            put(im, x + 1 + dx, y + dy, SILVER_D)
    # 云球（三瓣蓬松）
    grow = 1 if f == 1 else 0
    cloud = {4 - grow: [(24, 27)], 5 - grow: [(21, 29)],
             6 - grow: [(19, 30)], 7 - grow: [(19, 31)],
             8: [(19, 30)], 9: [(20, 29)], 10: [(22, 27)]}
    paint(im, cloud, lambda x, y: WHITE if y <= 7 else SILVER_L, dx, dy)
    # 云眼（2x2）
    for ex in (22, 27):
        for ey in (6, 7):
            put(im, ex + dx, ey + dy, BLUE_D)
    # 紫宝石吊坠
    for gx, gy in [(24, 13), (23, 14), (25, 14), (24, 15)]:
        put(im, gx + dx, gy + dy, PURPLE)
    # 尾部两束穗
    for i, sx in enumerate((23, 26)):
        for y in range(16, 24):
            put(im, sx + dx, y + dy, PURPLE if (y + i) % 2 else PURPLE_D)
    if f == 1:
        for px, py in [(30, 3), (31, 5), (29, 12)]:
            put(im, px, py, WHITE)


def icon_staff(im):
    for i in range(0, 12):
        x = 4 + i
        y = 19 - i
        put(im, x, y, SILVER)
        put(im, x, y + 1, SILVER_D)
    paint(im, {3: [(16, 18)], 4: [(14, 20)], 5: [(13, 21)], 6: [(13, 21)],
               7: [(13, 20)], 8: [(14, 19)]},
          lambda x, y: WHITE if y <= 6 else SILVER_L)
    for ex in (15, 18):
        for ey in (5, 6):
            put(im, ex, ey, BLUE_D)
    for gx, gy in [(17, 9), (16, 10), (18, 10), (17, 11)]:
        put(im, gx, gy, PURPLE)
    for y in range(11, 17):
        put(im, 17, y, PURPLE if y % 2 else PURPLE_D)
        put(im, 19, y, PURPLE_D if y % 2 else PURPLE)


# ---------------------------------------------------------------- Claude 法典（大人版手里的书）
def draw_claude_book(im, f):
    dx, dy = frame_of(f)
    if f == 1:
        open_w = 3
    else:
        open_w = 0
    spans = {6: [(10, 23 + open_w)], 7: [(9, 23 + open_w)], 8: [(9, 23 + open_w)],
             9: [(9, 23 + open_w)], 10: [(9, 23 + open_w)], 11: [(9, 23 + open_w)],
             12: [(9, 23 + open_w)], 13: [(9, 23 + open_w)], 14: [(9, 23 + open_w)],
             15: [(9, 23 + open_w)], 16: [(9, 23 + open_w)], 17: [(9, 23 + open_w)],
             18: [(9, 23 + open_w)], 19: [(9, 23 + open_w)], 20: [(9, 23 + open_w)],
             21: [(9, 23 + open_w)], 22: [(9, 23 + open_w)], 23: [(9, 23 + open_w)],
             24: [(9, 23 + open_w)], 25: [(10, 22 + open_w)], 26: [(12, 20 + open_w)]}

    def col(x, y):
        if x <= 10:
            return BROWN_D
        if y <= 7 or y >= 25:
            return BROWN_L
        if x >= 21 + open_w:
            return BROWN_L if f != 1 else CREAM
        return BROWN

    paint(im, spans, col, dx, dy)
    # 金色包角
    for cy in (6, 24):
        for cx in (11, 22 + open_w):
            box(im, cx + dx, cy + dy, cx + 1 + dx, cy + 1 + dy, GOLD)
    # 横向书带
    for y in (11, 20):
        for x in range(12, 22 + open_w):
            put(im, x + dx, y + dy, BROWN_D)
    # 葵花
    cx, cy = 17 + dx, 15 + dy
    for px, py in [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]:
        put(im, cx + px, cy + py, ORANGE)
    box(im, cx - 1, cy - 1, cx + 1, cy + 1, GOLD)
    put(im, cx, cy, ORANGE_D)
    # 书页露出（开火帧）
    if f == 1:
        for y in range(9, 24):
            put(im, 25 + dx, y + dy, CREAM)
            put(im, 26 + dx, y + dy, CREAM_D)
    # 底部书扣
    for y in (27, 28):
        put(im, 16 + dx, y + dy, GOLD)
        put(im, 18 + dx, y + dy, GOLD_D)


def icon_book(im):
    paint(im, {4: [(5, 18)], 5: [(4, 19)], 6: [(4, 19)], 7: [(4, 19)], 8: [(4, 19)],
               9: [(4, 19)], 10: [(4, 19)], 11: [(4, 19)], 12: [(4, 19)],
               13: [(4, 19)], 14: [(4, 19)], 15: [(4, 19)], 16: [(4, 19)],
               17: [(4, 19)], 18: [(4, 19)], 19: [(5, 18)]},
          lambda x, y: BROWN_D if x <= 5 else BROWN)
    for cx in (5, 18):
        for cy in (4, 18):
            box(im, cx, cy, cx + 1, cy + 1, GOLD)
    for y in (8, 15):
        for x in range(7, 18):
            put(im, x, y, BROWN_D)
    cx, cy = 12, 11
    for px, py in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)]:
        put(im, cx + px, cy + py, ORANGE)
    box(im, cx, cy, cx, cy, GOLD)


# ---------------------------------------------------------------- Harness 外骨骼
def draw_harness(im, f):
    """背挂式动力外骨骼：厚背梁 + 肩甲 + 上下双机械臂夹爪 + 尾部双喷口 + 青色管线。"""
    dx, dy = frame_of(f)
    reach = 2 if f == 1 else 0
    lit = f == 1

    # 背架主梁（4px 宽，左亮右暗）
    for y in range(5, 28):
        for x in range(9, 14):
            put(im, x + dx, y + dy, SILVER_D if x == 9 else (NAVY if x == 13 else STEEL))
    for y in (9, 14, 19, 24):
        put(im, 11 + dx, y + dy, WHITE if lit else CYAN)
        put(im, 12 + dx, y + dy, CYAN)

    # 肩甲
    for y, (x0, x1) in {4: (8, 16), 5: (6, 17), 6: (6, 17), 7: (7, 16)}.items():
        for x in range(x0, x1 + 1):
            if y == 4:
                c = SILVER_D
            elif x >= x1:
                c = NAVY
            else:
                c = STEEL
            put(im, x + dx, y + dy, c)
    put(im, 14 + dx, 6 + dy, WHITE if lit else CYAN)
    put(im, 15 + dx, 6 + dy, CYAN_D)

    # 髋甲
    for y, (x0, x1) in {25: (8, 15), 26: (7, 15), 27: (8, 14)}.items():
        for x in range(x0, x1 + 1):
            put(im, x + dx, y + dy, SILVER_D if y == 25 else (NAVY if y == 27 else STEEL))

    # 上下机械臂：3px 厚钢板 + 青色能量线
    arm_x1 = 26 + reach
    for base_y, light_y, shade_y in ((9, 9, 12), (20, 20, 23)):
        for y in range(base_y, base_y + 4):
            for x in range(14, arm_x1 + 1):
                if y == light_y:
                    c = SILVER_D
                elif y == shade_y:
                    c = NAVY
                else:
                    c = STEEL
                put(im, x + dx, y + dy, c)
        for x in range(16, arm_x1 + 1, 3):
            put(im, x + dx, base_y + 1 + dy, WHITE if lit else CYAN)

    # 双爪夹钳（张开的上下两指）
    palm_x = 26 + reach
    for py, fy, cy in ((9, 7, 11), (19, 17, 21)):
        box(im, palm_x + dx, py + dy, palm_x + 2 + dx, py + 4 + dy, STEEL)
        put(im, palm_x + 1 + dx, cy + dy, WHITE if lit else CYAN)
        box(im, palm_x + 2 + dx, fy + dy, palm_x + 4 + dx, fy + 1 + dy, SILVER_D)
        box(im, palm_x + 2 + dx, py + 4 + dy, palm_x + 4 + dx, py + 5 + dy, SILVER_D)

    # 腰部握把（贴住持械手）
    box(im, 13 + dx, 15 + dy, 20 + dx, 18 + dy, STEEL)
    for x in range(14, 19):
        put(im, x + dx, 16 + dy, NAVY)
    put(im, 19 + dx, 17 + dy, WHITE if lit else CYAN)

    # 尾部双喷口（朝左）
    for y, (x0, x1) in {6: (6, 8), 7: (5, 8), 8: (4, 8), 9: (5, 8)}.items():
        for x in range(x0, x1 + 1):
            put(im, x + dx, y + dy, NAVY if y == 8 else STEEL)
    put(im, 6 + dx, 7 + dy, CYAN)
    for y, (x0, x1) in {22: (5, 8), 23: (4, 8), 24: (5, 8), 25: (6, 8)}.items():
        for x in range(x0, x1 + 1):
            put(im, x + dx, y + dy, NAVY if y == 23 else STEEL)
    put(im, 6 + dx, 24 + dy, CYAN)

    # 开火：喷口青焰
    if lit:
        for y in (7, 8, 23, 24):
            put(im, 2, y, CYAN_D)
            put(im, 3, y, CYAN)
        put(im, 1, 7, CYAN)
        put(im, 1, 24, CYAN)
        put(im, 4, 6, CYAN_D)
        put(im, 4, 25, CYAN_D)


def icon_harness(im):
    # 背板
    box(im, 9, 4, 12, 19, STEEL)
    for y in range(4, 20):
        put(im, 9, y, SILVER_D)
        put(im, 12, y, NAVY)
    for y in (6, 10, 14, 18):
        put(im, 10, y, CYAN)
        put(im, 11, y, CYAN_D)
    # 肩甲
    box(im, 7, 3, 15, 5, STEEL)
    for x in range(7, 16):
        put(im, x, 3, SILVER_D)
    put(im, 13, 4, CYAN)
    # 折叠双机械臂
    box(im, 13, 6, 18, 8, STEEL)
    box(im, 13, 15, 18, 17, STEEL)
    box(im, 17, 5, 18, 9, SILVER_D)
    box(im, 17, 14, 18, 18, SILVER_D)
    put(im, 18, 7, CYAN)
    put(im, 18, 16, CYAN)
    # 尾部双喷口
    box(im, 5, 7, 7, 9, STEEL)
    put(im, 5, 8, CYAN)
    box(im, 5, 14, 7, 16, STEEL)
    put(im, 5, 15, CYAN)


# ---------------------------------------------------------------- Codex 律法典籍
def draw_codex(im, f):
    dx, dy = frame_of(f)
    lift = 1 if f == 1 else 0
    # 书页
    spans = {10: [(8, 16), (17, 24)], 11: [(7, 16), (17, 25)],
             12: [(7, 16), (17, 25)], 13: [(7, 16), (17, 25)],
             14: [(7, 16), (17, 25)], 15: [(7, 16), (17, 25)],
             16: [(7, 16), (17, 25)], 17: [(7, 16), (17, 25)],
             18: [(7, 16), (17, 25)], 19: [(7, 16), (17, 25)],
             20: [(8, 16), (17, 24)]}

    def col(x, y):
        return CREAM if y > 12 else CREAM_D

    paint(im, spans, col, dx, dy)
    # 书脊
    for y in range(10, 21):
        put(im, 16 + dx, y + dy, NAVY)
    # 金色括号
    for y in range(11, 20):
        put(im, 6 + dx, y + dy, GOLD)
        put(im, 26 + dx, y + dy, GOLD)
    for y in (10, 20):
        for x in range(6, 9):
            put(im, x + dx, y + dy, GOLD)
        for x in range(24, 27):
            put(im, x + dx, y + dy, GOLD)
    # 符文行
    for y in (13, 15, 17):
        for x in range(9, 14):
            put(im, x + dx, y + dy, GOLD_D)
        for x in range(19, 24):
            put(im, x + dx, y + dy, GOLD_D)
    # 开火：三枚金色符文飞出
    if f == 1:
        for px, py in [(27, 6), (29, 9), (26, 12)]:
            put(im, px, py, GOLD)
            put(im, px, py + 1, GOLD_D)
    # 待机时书页微光
    put(im, 12 + dx, 12 + dy - lift, WHITE)
    put(im, 21 + dx, 12 + dy - lift, WHITE)


def icon_codex(im):
    paint(im, {6: [(4, 11), (12, 19)], 7: [(3, 11), (12, 20)], 8: [(3, 11), (12, 20)],
               9: [(3, 11), (12, 20)], 10: [(3, 11), (12, 20)], 11: [(3, 11), (12, 20)],
               12: [(3, 11), (12, 20)], 13: [(4, 11), (12, 19)]},
          lambda x, y: CREAM)
    for y in range(6, 14):
        put(im, 11, y, NAVY)
        put(im, 12, y, NAVY)
    for y in range(7, 13):
        put(im, 2, y, GOLD)
        put(im, 21, y, GOLD)
    for y in (8, 10, 12):
        for x in range(5, 9):
            put(im, x, y, GOLD_D)
        for x in range(15, 19):
            put(im, x, y, GOLD_D)
    for px, py in [(17, 3), (20, 5)]:
        put(im, px, py, GOLD)


# ---------------------------------------------------------------- Claude Code 终端法典
def draw_claude_code(im, f):
    dx, dy = frame_of(f)
    # 顶部天线
    for y in range(4, 7):
        put(im, 17 + dx, y + dy, GOLD_D)
    put(im, 17 + dx, 3 + dy, GOLD)
    # 石板
    box(im, 9 + dx, 7 + dy, 25 + dx, 24 + dy, STEEL)
    box(im, 10 + dx, 8 + dy, 24 + dx, 23 + dy, TERM)
    # 标题栏
    for x in range(10 + dx, 25 + dx):
        put(im, x, 8 + dy, STEEL)
    put(im, 11 + dx, 8 + dy, ORANGE)
    put(im, 13 + dx, 8 + dy, CYAN)
    # 代码行
    rows = (12, 15, 18) if f != 1 else (11, 14, 17)
    for i, y in enumerate(rows):
        end = (21, 19, 23)[i]
        for x in range(11 + dx, end + dx):
            put(im, x, y + dy, CYAN if x % 3 else CYAN_D)
    # 橙色光标块
    put(im, 21 + dx, 18 + dy, ORANGE)
    put(im, 22 + dx, 18 + dy, ORANGE)
    # 背面小雏菊
    put(im, 12 + dx, 21 + dy, ORANGE)
    put(im, 13 + dx, 21 + dy, GOLD)
    put(im, 12 + dx, 22 + dy, GOLD)


def icon_claude_code(im):
    for y in range(2, 5):
        put(im, 11, y, GOLD_D)
    put(im, 11, 1, GOLD)
    box(im, 4, 5, 19, 20, STEEL)
    box(im, 5, 6, 18, 19, TERM)
    for x in range(5, 19):
        put(im, x, 6, STEEL)
    put(im, 6, 6, ORANGE)
    put(im, 8, 6, CYAN)
    for y, end in ((9, 14), (12, 12), (15, 16)):
        for x in range(6, end + 1):
            put(im, x, y, CYAN if x % 3 else CYAN_D)
    box(im, 15, 15, 16, 16, ORANGE)


# ---------------------------------------------------------------- 输出
def center(im):
    bbox = im.split()[3].getbbox()
    if bbox is None:
        return im
    x0, y0, x1, y1 = bbox
    dx = (im.width - (x1 - x0)) // 2 - x0
    dy = (im.height - (y1 - y0)) // 2 - y0
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy))
    return out


def sheet(drawfn, path):
    out = Image.new("RGBA", (96, 32), (0, 0, 0, 0))
    for f in range(3):
        im = new()
        drawfn(im, f)
        _outline_all(im)
        out.alpha_composite(im, (f * 32, 0))
    out.save(path)


def _outline_all(im):
    """统一 1px 深色外描边：所有武器共用，避免各画各的导致边缘深浅不一。"""
    mask = set()
    for y in range(im.height):
        for x in range(im.width):
            if im.getpixel((x, y))[3] > 0:
                mask.add((x, y))
    outline(im, mask)


def make_icon(drawfn, path):
    im = new(24, 24)
    drawfn(im)
    _outline_all(im)
    center(im).save(path)


WEAPONS = {
    "deepseek_starter": draw_bowl,
    "gpt_starter": draw_staff,
    "claude_starter": draw_claude_book,
    "excl_harness": draw_harness,
    "excl_codex": draw_codex,
    "excl_claude_code": draw_claude_code,
}

ICONS = {
    "deepseek": icon_bowl,
    "gpt": icon_staff,
    "claude": icon_book,
    "excl_harness": icon_harness,
    "excl_codex": icon_codex,
    "claude_code": icon_claude_code,
}

if __name__ == "__main__":
    WPN.mkdir(parents=True, exist_ok=True)
    ICO.mkdir(parents=True, exist_ok=True)
    for name, fn in WEAPONS.items():
        sheet(fn, WPN / f"{name}.png")
    for name, fn in ICONS.items():
        make_icon(fn, ICO / f"{name}.png")
    print("weapons:", ", ".join(WEAPONS))
    print("icons:", ", ".join(ICONS))
