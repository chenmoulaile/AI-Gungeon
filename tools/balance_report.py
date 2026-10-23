#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""理论平衡检查：直接读 resources/stats/*.tres 的数值，算 DPS / 生存 / 威胁 / 经济曲线。

输出 docs/balance.md，不改任何数值。
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = os.path.join(ROOT, "resources", "stats")


def read(path):
    """把 .tres 里的 key = value 读成 dict（够用即可）。"""
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^([a-z_0-9]+) = (.+)$", line.strip())
        if not m:
            continue
        k, v = m.group(1), m.group(2)
        try:
            out[k] = float(v)
        except ValueError:
            out[k] = v
    return out


def load_dir(sub):
    d = os.path.join(STATS, sub)
    return {f[:-5]: read(os.path.join(d, f)) for f in os.listdir(d) if f.endswith(".tres")}


chars = load_dir("characters")
weapons = load_dir("weapons")
enemies = load_dir("enemies")
econ = read(os.path.join(STATS, "economy.tres"))
diff = read(os.path.join(STATS, "difficulty.tres"))

# ---------------- DPS ----------------
ds = weapons["reasoning_chain"]
ds_main = ds["damage"] * ds["fire_rate"]
# 分裂：每代 2 枚、伤害 ×split_decay；单体全中 / 30% 命中两种口径
ds_all = ds["damage"] + 2 * ds["damage"] * ds["split_decay"] + \
    4 * ds["damage"] * ds["split_decay"] ** 2
ds_single_all = ds_all * ds["fire_rate"]
ds_single_real = (ds["damage"] + 0.6 * ds["damage"] * ds["split_decay"] * 2 +
                  0.36 * ds["damage"] * ds["split_decay"] ** 2 * 4) * ds["fire_rate"]

gpt = weapons["multimodal"]
gpt_text = gpt["damage"] * gpt["fire_rate"]
gpt_image = gpt["mode2_damage"] * 5 * gpt["mode2_rate"]
gpt_voice = gpt["mode3_damage"]  # 锥形，按 1 次/0.6s 近似
gpt_voice_dps = gpt_voice / 0.6

cl = weapons["long_context"]
cl_min, cl_max = cl["damage"], cl["beam_max_dps"]
cl_avg = (cl_min + cl_max) / 2

rows = []
rows.append(("DeepSeek 推理链", ds_single_real, ds_single_all, ds_single_all + 12.0))
rows.append(("GPT 文本模式", gpt_text, gpt_text, gpt_text * 1.4))
rows.append(("GPT 图像模式", gpt_image, gpt_image * 0.6, gpt_image * 1.4))
rows.append(("GPT 语音模式", gpt_voice_dps, gpt_voice_dps, gpt_voice_dps * 1.4))
rows.append(("Claude 光束", cl_min, cl_avg, cl_max))

# ---------------- 生存 ----------------
# 有效生命 = 生命 × (1 + 翻滚无敌覆盖率) × 护盾/减伤系数
roll_cov = 0.25 / 0.8
surv = []
for cid, c in chars.items():
    ehp = c["max_hp"] * (1 + roll_cov)
    if cid == "claude":
        ehp *= 1.6          # 护盾 6 发 × 每发回 2 点
    elif cid == "gpt":
        ehp *= 1.05
    surv.append((cid, c["max_hp"], round(ehp, 1)))

# ---------------- 每层威胁 ----------------
def threat(floor_index, kind_count=3, per_room=5, waves=2.5):
    scale = 1.2 ** (floor_index - 1)
    pool = list(enemies.values())
    avg_hp = sum(e["max_hp"] for e in pool) / len(pool) * scale
    avg_dmg = sum(e["contact_damage"] for e in pool) / len(pool)
    total_hp = avg_hp * per_room * waves
    total_dmg = avg_dmg * per_room * waves * 0.8
    return total_hp, total_dmg, total_hp / max(total_dmg, 0.1)


# ---------------- 经济 ----------------
avg_coin_per_enemy = sum(e["coin_value"] for e in enemies.values()) / len(enemies)
per_floor = avg_coin_per_enemy * 5 * 2.5 * 4 + econ["room_clear_coins"] * 4
prices = [22, 24, 26, 28, 30, 32, 34]
avg_price = sum(prices) / len(prices)

lines = []
lines.append("# 理论平衡检查（只读，未改数值）\n")
lines.append("## 角色 DPS（单体 / 群体 / 爆发）\n")
lines.append("| 角色 / 武器 | 单体 DPS | 群体 DPS | 爆发窗口 |")
lines.append("| --- | --- | --- | --- |")
for name, single, group, burst in rows:
    lines.append("| %s | %.1f | %.1f | %.1f |" % (name, single, group, burst))
lines.append("")
lines.append("## 生存能力（有效生命）\n")
lines.append("| 角色 | 生命 | 有效生命 |")
lines.append("| --- | --- | --- |")
for cid, hp, ehp in surv:
    lines.append("| %s | %d | %.1f |" % (cid, hp, ehp))
lines.append("")
lines.append("## 每层威胁（均值口径）\n")
lines.append("| 层 | 总血量 | 总输出 | 威胁比 |")
lines.append("| --- | --- | --- | --- |")
for f in (1, 2, 3):
    th, td, ratio = threat(f)
    lines.append("| B%d | %.0f | %.1f | %.1f |" % (f, th, td, ratio))
lines.append("")
lines.append("## 经济曲线\n")
lines.append("每层平均金币约 **%.0f**，商店均价 **%.0f**（每层 1 次商店、3 件货）。" % (per_floor, avg_price))
lines.append("")
lines.append("## 调整建议（未执行）\n")
ds_real = ds_single_real
gpt_best = max(gpt_text, gpt_image * 0.6, gpt_voice_dps)
cl_best = cl_avg
lines.append("1. DeepSeek 单体 %.0f、GPT %.0f、Claude %.0f：极差 %.0f%%，建议把分裂衰减从 %.0f%% 提到 35%%。"
             % (ds_real, gpt_best, cl_best, (max(ds_real, gpt_best, cl_best) / min(ds_real, gpt_best, cl_best) - 1) * 100,
                (1 - ds["split_decay"]) * 100))
lines.append("2. Claude 有效生命最高（护盾回血），建议把护盾单次回复从 2 点降到 1 点，或把吸收数从 6 降到 5。")
lines.append("3. GPT 三种模式里图像模式单体最高，语音模式最低，建议把语音锥形伤害从 %.0f 提到 %.0f。"
             % (gpt["mode3_damage"], gpt["mode3_damage"] * 1.35))
lines.append("4. 经济：每层收入 %.0f、均价 %.0f，第 2 层即可买 2 件，建议把均价提到 30–34 区间。" % (per_floor, avg_price))
lines.append("")

os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
out = os.path.join(ROOT, "docs", "balance.md")
open(out, "w", encoding="utf-8").write("\n".join(lines))
print("\n".join(lines))
