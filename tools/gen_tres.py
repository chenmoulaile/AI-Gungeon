#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 resources/characters/*.tres 与 resources/upgrades/*.tres。

手写 .tres 容易漏字段，用脚本统一生成，改数值后重跑即可。
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR_DIR = os.path.join(ROOT, "resources", "characters")
UP_DIR = os.path.join(ROOT, "resources", "upgrades")

CHAR_HEADER = '''[gd_resource type="Resource" script_class="CharacterData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/character_data.gd" id="1_cd"]

[resource]
script = ExtResource("1_cd")
'''

CHARACTERS = [
    {
        "id": "deepseek",
        "display_name": "DeepSeek",
        "title": "深蓝鲸歌",
        "blurb": "冷静理性，靠一条推理链把伤害层层放大。",
        "weapon_path": "res://scripts/weapons/weapon_reasoning_chain.gd",
        "weapon_name": "推理链",
        "weapon_desc": "主弹命中分裂为 2 枚小弹，最多 3 代，每代伤害 -30%",
        "skill_name": "深度思考",
        "skill_desc": "蓄力 1.5s（移速 -50%、无敌），释放贯穿全屏光束，伤害最高 3 倍",
        "passive_name": "注意力聚焦",
        "passive_desc": "连续命中同一敌人，每层 +5% 伤害，最高 10 层，换目标清零",
        "skill_cd": "9.0",
        "accent": "Color(0.373, 0.525, 0.941, 1)",
    },
    {
        "id": "gpt",
        "display_name": "GPT",
        "title": "白鳞龙娘",
        "blurb": "全能多面手，三种武器模式随时切换。",
        "weapon_path": "res://scripts/weapons/weapon_multimodal.gd",
        "weapon_name": "多模态切换",
        "weapon_desc": "R 键循环：文本（高射速直线）/ 图像（5 发扇形）/ 语音（锥形冲击波）",
        "skill_name": "涌现",
        "skill_desc": "随机获得伤害 +40% / 射速 +50% / 弹速 +60% 之一，持续 5s",
        "passive_name": "上下文窗口",
        "passive_desc": "每击杀 +1 token，满 20 后下一次涌现三种强化同时生效",
        "skill_cd": "8.0",
        "accent": "Color(0.690, 0.612, 0.941, 1)",
    },
    {
        "id": "claude",
        "display_name": "Claude",
        "title": "橙羽书记",
        "blurb": "细腻谨慎，用持续光束和护盾稳稳推进。",
        "weapon_path": "res://scripts/weapons/weapon_long_context.gd",
        "weapon_name": "长上下文光束",
        "weapon_desc": "按住左键持续激光，宽度 1s 内由细变粗、伤害同步提升，松开冷却 1.2s",
        "skill_name": "宪法规避",
        "skill_desc": "展开吸收 6 发敌弹的护盾，持续 3s，每吸收 1 发回复 2 点生命",
        "passive_name": "细致阅读",
        "passive_desc": "自身 120 像素内的敌方子弹速度 -25%",
        "skill_cd": "7.0",
        "accent": "Color(0.941, 0.565, 0.290, 1)",
    },
]

UP_HEADER = '''[gd_resource type="Resource" script_class="Upgrade" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/upgrade.gd" id="1_up"]

[resource]
script = ExtResource("1_up")
'''

UPGRADES = [
    ("sharp_round", "锋利弹头", "同一目标连续命中 3 次后，之后的每一发都暴击", 30, {}, ""),
    ("rapid_cycle", "急速循环", "连续命中 6 次后射速大涨，2 秒不命中就重置", 30, {}, ""),
    ("feather_boots", "轻羽长靴", "翻滚之后的一小段路，跑得比平时快得多", 30, {}, ""),
    ("extra_heart", "备用心脏", "生命上限 +1 并立即回复 1 点", 30, {"max_hp_bonus": 1}, ""),
    ("magnet_coil", "磁力线圈", "金币拾取范围 +45", 18, {"magnet": 45.0}, ""),
    ("crit_lens", "暴击透镜", "对满血敌人的第一击必定暴击", 30, {}, ""),
    ("piercing_nail", "穿甲长钉", "子弹穿透 +1", 18, {"pierce": 1}, ""),
    ("vampire_chip", "吸血芯片", "每 8 次击杀回复 1 点生命", 18, {"lifesteal_every": 8}, ""),
    ("roll_core", "翻滚核心", "翻滚冷却 -25%", 30, {"roll_cd_mult": -0.25}, ""),
    ("cool_module", "冷却模块", "技能冷却 -20%", 18, {"skill_cd_mult": -0.20}, ""),
    ("split_prism", "分裂棱镜", "每次射击额外发射 1 发子弹", 30, {"proj": 1}, ""),
    ("scholar_page", "学者手记", "生命上限 +1，伤害 +5%", 30, {"max_hp_bonus": 1, "damage": 0.05}, ""),
    ("ds_homing_split", "回声追踪", "裂开的小弹会自己去找人", 48, {}, "deepseek"),
    ("ds_burn_zone", "余温记录", "光束走过的地方，还会烧一会儿", 48, {}, "deepseek"),
    ("gpt_echo_clone", "模态残响", "换模式的瞬间，留下一个影子替你打一下", 48, {}, "gpt"),
    ("gpt_voice_haste", "回声加速", "喊完之后手会变快", 48, {}, "gpt"),
    ("cl_break_burst", "碎盾礼赞", "护盾碎掉的时候，四面都会还手", 48, {}, "claude"),
    ("cl_overload", "过载祷文", "举太久，光会烧过头", 48, {}, "claude"),
]


def fmt_effects(effects):
    lines = ["effects = {"]
    for k, v in effects.items():
        lines.append('"%s": %s,' % (k, v))
    lines.append("}")
    return "\n".join(lines)


def main():
    os.makedirs(CHAR_DIR, exist_ok=True)
    os.makedirs(UP_DIR, exist_ok=True)
    for c in CHARACTERS:
        body = CHAR_HEADER
        for k in ("id", "display_name", "title", "blurb", "weapon_path", "weapon_name",
                  "weapon_desc", "skill_name", "skill_desc", "passive_name",
                  "passive_desc", "skill_cd", "accent"):
            body += '%s = "%s"\n' % (k, c[k]) if k not in ("skill_cd", "accent") else '%s = %s\n' % (k, c[k])
        open(os.path.join(CHAR_DIR, c["id"] + ".tres"), "w", encoding="utf-8").write(body)

    for uid, title, desc, price, effects, tag in UPGRADES:
        body = UP_HEADER
        body += 'id = "%s"\n' % uid
        body += 'title = "%s"\n' % title
        body += 'desc = "%s"\n' % desc
        body += "price = %d\n" % price
        body += 'icon_path = "res://assets/icons/%s.png"\n' % uid
        body += 'char_tag = "%s"\n' % tag
        body += "mutation = %s\n" % ("true" if tag != "" else "false")
        body += fmt_effects(effects) + "\n"
        open(os.path.join(UP_DIR, uid + ".tres"), "w", encoding="utf-8").write(body)

    print("characters:", len(CHARACTERS), "upgrades:", len(UPGRADES))


if __name__ == "__main__":
    main()
