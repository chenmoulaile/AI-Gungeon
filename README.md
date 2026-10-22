# AI Gungeon

一款 2D 像素俯视角 Roguelike 射击游戏，用 **Godot 4.4.1 + GDScript** 开发。
玩法参考《Enter the Gungeon》的核心循环（角色选择 → 房间清怪 → 开门 → 商店 → Boss → 下一层），
角色原型为三个 AI 助手的拟人形象，武器机制、数值、关卡与代码全部原创。

---

## 同人声明

> 非官方同人作品，相关角色名称与形象权利归各自权利方所有，本项目不用于任何商业用途，
> 不包含付费或捐赠解锁内容。如有侵权请联系删除。

本项目完全免费发布，不含任何付费、广告、内购、捐赠解锁内容。

---

## 运行方式

### 方式一：直接运行已导出的构建

```
E:\Projects\AiGungeon\build\AIGungeon.exe
```

### 方式二：在 Godot 编辑器中运行

1. 启动编辑器（绿色版，无需安装）：

   ```
   E:\DevTools\Godot\Godot_v4.4.1-stable_win64.exe
   ```

2. 打开工程：`E:\Projects\AiGungeon\project.godot`
3. 按 **F5** 运行。

### 方式三：浏览器本地预览（不弹游戏窗口）

```bat
:: 1) 导出 Web 版
set APPDATA=E://DevTools//cache//appdata
E://DevTools//Godot//Godot_v4.4.1-stable_win64_console.exe --headless --path E://Projects//AiGungeon --export-release "Web" build/web/index.html

:: 2) 起本地服务器（带 wasm MIME 与 COOP/COEP 头）
E://DevTools//Python//python.exe E://Projects//AiGungeon//tools//serve_web.py 8765

:: 3) 浏览器打开 http://127.0.0.1:8765/index.html
```

Web 版关闭了线程（`thread_support=false`），不需要特殊服务器配置也能跑；
`tools/serve_web.py` 仍然带上 COOP/COEP 头，方便以后开线程时不用改服务器。

### 方式四：命令行无头自测（不需要显示器）

```bat
set APPDATA=E:\DevTools\cache\appdata
E:\DevTools\Godot\Godot_v4.4.1-stable_win64_console.exe --headless --path E:\Projects\AiGungeon res://tests/smoke_test.tscn
```

自测覆盖：三个角色开局 / 开火 / 技能 / 翻滚 / 清场开门 / 换房 / 商店购买 / Boss 三阶段 / 死亡结算。

---

## 手感与系统（v2）

### 全局反馈层 `scripts/systems/game_feel.gd`（Autoload）

所有反馈集中在一处，武器/敌人只调用预设，不在各自脚本里重复实现：

| 通道 | 实现 |
| --- | --- |
| `hit_stop(duration, scale)` | 改 `Engine.time_scale`，用真实时间计时恢复，不阻塞输入（输入在恢复后立即生效） |
| `screen_shake(trauma)` | trauma 衰减 + `trauma²` 映射，只改 `Camera2D.offset`，不影响碰撞体 |
| `flash(node, color)` | Tween 缓动回白，受击闪白/闪红 |
| `knockback(node, dir, strength)` | 写入节点 `knock_vel`，由节点逐帧衰减，不是瞬移 |
| `damage_number(pos, amount, crit)` | 上浮（TRANS_BACK）→ 下坠（TRANS_QUAD）→ 淡出 |
| `burst(pos, ...)` | 像素粒子爆散，单节点批量绘制，最多 16 粒 |
| `afterimage(...)` | 翻滚残影，0.15s 淡出 |

三档预设（`PRESETS`）：

| 档位 | hit-stop | 震屏 | 粒子 | 使用场景 |
| --- | --- | --- | --- | --- |
| small | 0 | 0.05 | 3 | 分裂弹末代命中、护盾回击 |
| medium | 0.028s | 0.16 | 6 | 普通子弹命中（默认） |
| large | 0.11s | 0.55 | 14 | Boss 阶段转换、玩家死亡 |

对象池：子弹、粒子、伤害数字全部复用，不在战斗中途 `instantiate/free`。

### 翻滚反馈

起手 1 帧挤压拉伸（1.28×0.76 回弹）、每 0.045s 生成一张残影、撞墙时扬尘 + 微震、
结束时靠减速度自然滑出（不是硬停）。

### 藏品钩子系统

藏品不再只是数值加算，`GameState` 把「藏品 × 角色」翻译成运行时修正表 `mods`，
武器只查表，不写 if 链：

| 协同 | 条件 | 效果 | 藏品描述里的暗示 |
| --- | --- | --- | --- |
| 裂开的推理也会穿透 | DeepSeek + 分裂棱镜 | 分裂出的小弹继承穿透 | 见「分裂棱镜」 |
| 说出口的话会自己找上下一句 | GPT + 冷却模块 | 语音冲击波击杀 -1.5s 技能冷却 | 见「冷却模块」 |
| 被挡住的东西会原路返回 | Claude + 穿甲长钉 | 护盾吸弹时向最近敌人回击 | 见「穿甲长钉」 |
| 翻滚之后的第一枪格外准 | 任意 + 翻滚核心 | 翻滚后首发 +60% 伤害 | 见「翻滚核心」 |
| 越接近极限越不肯放手 | 任意 + 备用心脏 | 生命 ≤3 时伤害 +25% | 见「备用心脏」 |
| 读完这一页就休息一下 | 任意 + 学者手记 | 每清空一个房间回复 1 点生命 | 见「学者手记」 |

商店改为**加权抽取**：与已持有藏品能凑成组合的选项权重 ×3，并且第一格优先放一个"能凑组合"的，
货架上会用 `★ 与已有藏品共鸣` 标出来。

### 视觉层

- `CanvasModulate` 把环境压成偏冷的深蓝灰（0.80/0.84/0.94），保留弹幕可读性；
- 玩家与 Boss 各带一个 `PointLight2D`（径向渐变贴图 `assets/fx/light_radial.png`，程序化生成）；
- 四面墙挂 `LightOccluder2D`，开启阴影，`SHADOW_FILTER_NONE` 保持像素硬边；
- 角色 sprite 设 `light_mask = 0`，避免被自己的点光源打成白色；
- 分层：地板棋盘 → 中央竞技圈/四角标记 → 墙内阴影 → 角色 → HUD 暗角，至少 4 层色阶；
- 敌方子弹：危险色（品红/暖红）+ 外发光 + 深色描边，与玩家子弹（青/紫）在色相上明确区分。

### UI

- `resources/ui/theme.tres`：蓝白主色、浅蓝强调、统一 4px 圆角，所有界面根节点都套用；
- HUD 全部贴边，中间 70% 留给弹幕；技能改成**环形冷却**（进度环 + 就绪脉冲）；
- 藏品拾取时图标 1.15 倍弹跳；
- Boss 血条标出 60% / 25% 阶段分界线，阶段转换时弹出「阶段转换！」横幅。

---

## 操作说明

| 操作 | 按键 |
| --- | --- |
| 移动 | `W` `A` `S` `D`（或方向键） |
| 瞄准 | 鼠标 |
| 射击 | 鼠标左键（Claude 为按住持续激光） |
| 翻滚 | `空格`（0.25s 无敌帧，0.8s 冷却） |
| 主动技能 | `E`（冷却 7–9s，角色不同） |
| 切换武器模式 | `R`（仅 GPT） |
| 角色选择 | 鼠标点击卡片，或按 `1` `2` `3` |
| 跳过对话 | `空格` / `回车` / 鼠标点击 |

---

## 玩法循环

```
角色选择 → 第 1~4 间战斗房（每间 2~3 波敌人）→ 清场后右侧开门
        → 第 4 间后进入商店（购买藏品）→ 第 5 间 Boss
        → 击破 Boss 进入下一层（敌人血量与数量 +20%）
```

- 房间固定 960×540，敌人按波次刷新，清场掉落金币。
- 死亡即结束本局，结算界面显示击杀数、到达层数、藏品与组合。
- 手感优先级：弹幕可读性 > 翻滚手感 > 构筑爽点 > 内容数量。

---

## 三个角色

### DeepSeek · 深蓝鲸歌

| 项目 | 内容 |
| --- | --- |
| 主武器 | **推理链**：主弹命中后分裂为 2 枚小弹，小弹再命中再分裂，最多 3 代，每代伤害 -30% |
| 主动技能 | **深度思考**：原地蓄力 1.5s（移速 -50%、额外无敌），释放贯穿全屏光束，伤害随蓄力线性提升至 3 倍 |
| 被动 | **注意力聚焦**：连续命中同一敌人，对其伤害每层 +5%，最高 10 层，切换目标清零 |

### GPT · 白鳞龙娘

| 项目 | 内容 |
| --- | --- |
| 主武器 | **多模态切换**（`R` 循环）：A 文本＝高射速单发直线弹；B 图像＝低射速 5 发扇形；C 语音＝短距锥形冲击波（0.6s 间隔） |
| 主动技能 | **涌现**：随机获得 伤害 +40% / 射速 +50% / 弹速 +60% 之一，持续 5s |
| 被动 | **上下文窗口**：每击杀 +1 token，满 20 后下一次「涌现」三种强化同时生效 |

### Claude · 橙羽书记

| 项目 | 内容 |
| --- | --- |
| 主武器 | **长上下文光束**：按住左键持续激光，宽度 1s 内由细变粗、伤害同步提升，松开进入 1.2s 冷却 |
| 主动技能 | **宪法规避**：展开可吸收 6 发敌弹的护盾，持续 3s，每吸收 1 发回复 2 点生命 |
| 被动 | **细致阅读**：自身 120 像素半径内敌方子弹速度 -25% |

---

## 藏品与组合效果

12 件藏品（`resources/upgrades/*.tres`），金币在商店购买；同时持有特定两件会激活组合效果。

| 藏品 | 效果 | 价格 |
| --- | --- | --- |
| 锋利弹头 | 伤害 +12% | 24 |
| 急速循环 | 射速 +18% | 26 |
| 轻羽长靴 | 移速 +12% | 22 |
| 备用心脏 | 生命上限 +1，立即回复 1 | 30 |
| 磁力线圈 | 金币拾取范围 +45 | 20 |
| 暴击透镜 | 暴击率 +10%（暴击 2 倍） | 28 |
| 穿甲长钉 | 穿透 +1 | 26 |
| 吸血芯片 | 每 8 次击杀回复 1 点生命 | 30 |
| 翻滚核心 | 翻滚冷却 -25% | 24 |
| 冷却模块 | 技能冷却 -20% | 26 |
| 分裂棱镜 | 每次射击额外 1 发子弹 | 32 |
| 学者手记 | 生命上限 +1、伤害 +5% | 32 |

12 组组合效果（定义在 `scripts/systems/upgrade_db.gd`）：

| 组合 | 配方 | 效果 |
| --- | --- | --- |
| 精准推理 | 锋利弹头 + 暴击透镜 | 暴击伤害 +50% |
| 多路并行 | 急速循环 + 分裂棱镜 | 射速再 +15% |
| 贯穿论证 | 穿甲长钉 + 学者手记 | 穿透 +1 |
| 续航协议 | 备用心脏 + 吸血芯片 | 每 5 次击杀回复 1 点生命 |
| 闪避本能 | 轻羽长靴 + 翻滚核心 | 翻滚冷却 -20% |
| 算力超频 | 冷却模块 + 急速循环 | 技能冷却 -15% |
| 穿甲推理 | 锋利弹头 + 穿甲长钉 | 伤害 +10% |
| 并行采样 | 暴击透镜 + 分裂棱镜 | 暴击率 +8% |
| 稳态系统 | 备用心脏 + 冷却模块 | 生命上限 +1 |
| 掠食步法 | 吸血芯片 + 轻羽长靴 | 移速 +10% |
| 深读精析 | 学者手记 + 锋利弹头 | 伤害 +8% |
| 场域牵引 | 磁力线圈 + 分裂棱镜 | 拾取范围 +40 |

---

## Boss：回响聚合体

| 阶段 | 血量区间 | 行为 |
| --- | --- | --- |
| 一 | 100% ~ 60% | 环形弹（14 发，逐圈旋转） |
| 二 | 60% ~ 25% | 3 发追踪弹（短时间制导） |
| 三 | 25% ~ 0% | 7 发扇形弹 + 每 6s 召唤 2 只追踪敌人 |

---

## 美术资源管线

### 1. 像素战斗资源（自动生成 + 手动修正）

脚本：`tools/make_pixel_sprites.py`（Pillow + numpy）

流程：**读参考图 → 去背景 → 切出正面/侧视视图 → 中心裁剪主体 → 降采样到目标尺寸
→ 中位切分量化到 24 色 → 手动修正 pass → 按 alpha 做 2px 描边 → 输出 PNG**

输出（每个角色独立目录与独立调色板，禁止混用）：

```
assets/sprites/<角色>/
    idle.png          64x64 x 4 帧（横向排列）
    walk.png          64x64 x 6 帧
    attack.png        64x64 x 3 帧
    roll.png          64x64 x 4 帧
    portrait_icon.png 32x32
    palette.gpl       该角色专属 24 色调色板
```

**哪些帧是自动生成、哪些做过手动修正：**

| 环节 | 说明 |
| --- | --- |
| 自动生成 | 全部帧的**几何变换**：idle 为 4 帧上下浮动；walk 为 6 帧位移+摆动；attack 为上半身错切前倾 + 轻微放大；roll 为 4 帧旋转（0°/90°/180°/270°）。以及基础图的降采样、24 色量化、2px 描边 |
| 手动修正（`manual_fix()`，作用于基础图，因此所有帧都继承） | ① 眼睛按参考图眼瞳色重绘 + 1px 高光；② 发型主色色相锚定（偏差 > 0.12 才拉回 40%，避免整体染色）；③ 服装主色色相锚定；④ 暗部按亮度加权提亮（保证主体明显亮于描边）；⑤ 顶部 rim light；⑥ 孤立像素清理；⑦ 统一 2px 描边 |
| 纯几何、无额外手工处理 | attack 第 2/3 帧、roll 全部 4 帧 |

> 说明：上传的三视图截图中，左起第一个视图在原始图片里被裁掉了约三分之一，
> 中间那个视图是唯一完整的主体，因此脚本统一取 **index=1（中间视图）**，保证三个角色一致；
> 侧视造型在俯视角射击里也更好读（左右移动靠 `flip_h` 翻转）。

### 2. 高分辨率立绘（界面层）

脚本：`tools/make_portraits.py`

- 输出 `assets/portraits/<角色>_full.png`（1024×1024）
- 处理：去背景 → 取中间视图 → 等比缩放到画布高度 92% → 统一渐变底板 + 光晕 + 底部渐隐 + 内描边
- 只用于**角色选择 / Boss 登场 / 结算 / 对话**，**不进入战斗场景**

### 3. 视觉一致性

- 立绘与像素 sprite 不要求一模一样，但发色、瞳色、服装主色、标志性配件一致：
  - DeepSeek：深蓝长发 + 蓝瞳 + 深蓝白女仆裙 + 鲸尾 / 耳鳍
  - GPT：白发 + 紫瞳 + 白色长裙 + 龙角 / 龙翼 / 龙尾
  - Claude：橙发 + 橙瞳 + 橙白裙 + 雏菊发饰
- `assets/` 下**没有任何纯色矩形占位图**：房间地板、墙体、门、敌人、Boss、子弹、光束全部用 `_draw()` 程序化绘制。

### 4. 图标与音效

脚本：`tools/make_ui_icons.py`

- 12 个藏品图标：`assets/icons/<id>.png`（32×32，几何图形程序化绘制）
- 9 个音效：`assets/audio/*.wav`（22050Hz 单声道，numpy 正弦/方波/噪声合成，**未使用任何外部音效素材**）

### 5. 素材替换指南

| 想替换的东西 | 怎么做 |
| --- | --- |
| 像素 sprite | 直接覆盖 `assets/sprites/<角色>/<动画>.png`，要求**横向帧表、每帧 64×64、脚底对齐 y=61**；或改 `tools/make_pixel_sprites.py` 里的 `CHARACTERS` 配置后重跑 |
| 立绘 | 覆盖 `assets/portraits/<角色>_full.png`（1024×1024，PNG），界面自动生效 |
| 藏品图标 | 覆盖 `assets/icons/<id>.png`（32×32） |
| 音效 | 覆盖 `assets/audio/<name>.wav`，文件名保持不变 |
| 中文字体 | 把 ttf 放到 `assets/fonts/ui.ttf`，程序会优先用系统微软雅黑，找不到时回退到它 |
| 数值 | 角色：`resources/characters/*.tres`；藏品：`resources/upgrades/*.tres`；组合：`scripts/systems/upgrade_db.gd` |
| 手感常量 | `scripts/systems/game_config.gd`（移速、翻滚时长/冷却、房间尺寸等） |

> 注意：`resources/*.tres` 由 `tools/gen_tres.py` 生成，直接改 .tres 也可以，但重跑脚本会覆盖。

---

## 工程结构

```
project.godot                 Godot 4 工程配置（1280x720 窗口 / 640x360 基准 / Nearest 过滤）
assets/
  reference/                  参考图（只读，未修改原图）
  sprites/<角色>/             像素战斗资源 + palette.gpl
  portraits/                  1024x1024 立绘
  icons/                      藏品图标
  audio/                      程序化合成音效
  fonts/                      字体（可选，放 ui.ttf）
scenes/
  main/    main.tscn game.tscn
  player/  player.tscn
  enemies/ enemy_chaser / enemy_shooter / enemy_spreader / boss
  rooms/   room_basic.tscn
  ui/      hud / character_select / shop / result / boss_intro / portrait_dialog
scripts/
  player/  player.gd
  weapons/ weapon_base / weapon_reasoning_chain / weapon_multimodal / weapon_long_context
           bullet.gd / beam.gd
  enemies/ enemy_base / enemy_chaser / enemy_shooter / enemy_spreader / boss
  systems/ game_config / game_state / upgrade_db / upgrade / character_data
           room_basic / coin / sfx
  ui/      hud / character_select / shop / result / boss_intro / portrait_dialog
  main/    main.gd / game.gd
resources/
  characters/  3 个角色 .tres
  upgrades/    12 个藏品 .tres
tools/          Python 资源生成脚本
tests/          无头自测与截图脚本
build/          Windows 导出产物
```

---

## 环境与安装记录（全部在 E 盘，未使用任何 C 盘默认路径）

| 工具 | 版本 | 实际安装路径 | 是否加入 PATH |
| --- | --- | --- | --- |
| Godot | 4.4.1.stable | `E:\DevTools\Godot\Godot_v4.4.1-stable_win64.exe` | 否（用绝对路径调用） |
| Godot 导出模板 | 4.4.1.stable | `E:\DevTools\cache\appdata\Godot\export_templates\4.4.1.stable\` | — |
| Python | 3.13.14（便携版） | `E:\DevTools\Python\python.exe` | 否（用绝对路径调用） |
| Pillow | 13.0.0 | `E:\DevTools\Python\Lib\site-packages` | — |
| numpy | 2.5.4 | `E:\DevTools\Python\Lib\site-packages` | — |
| LibreSprite | 未安装（可选，见下文） | 预留 `E:\DevTools\LibreSprite\` | — |

缓存与临时目录重定向：

```
pip   --cache-dir E:\DevTools\cache\pip
TEMP/TMP = E:\DevTools\cache\temp
APPDATA  = E:\DevTools\cache\appdata      （把 Godot 编辑器配置/导出模板从 C 盘拉走）
```

> 重要：如果直接用桌面图标启动 Godot，它会去 `C:\Users\<你>\AppData\Roaming\Godot` 找导出模板。
> 想让编辑器也能导出，请在启动前设置 `APPDATA=E:\DevTools\cache\appdata`，
> 或把 `E:\DevTools\cache\appdata\Godot\export_templates\4.4.1.stable` 整个目录
> 复制到 `%APPDATA%\Godot\export_templates\4.4.1.stable`（这一步会写 C 盘，需你手动决定）。

---

## 已知问题与妥协

1. **参考图被裁切**：上传的三视图截图中，左起第一个（正面）视图被裁掉了约三分之一，
   因此像素 sprite 与立绘统一采用中间那个完整的侧视视图，造型为侧身。
   如果你补一张完整的正面图，改 `tools/make_pixel_sprites.py` 里的 `idx = 1` 为 `0` 重跑即可。
2. **Claude 没有全身立绘**：只有 Q 版三视图，立绘由 Q 版放大 + 锐化补到 1024×1024，
   风格上比另外两张更「Q」，但发色/瞳色/服装主色/雏菊发饰一致。
3. **Boss 没有参考立绘**：Boss「回响聚合体」没有对应的参考图，
   登场界面用与战斗内一致的几何风格放大渲染（程序化绘制），未引入任何外部素材。
4. **中文字体依赖系统字体**：优先加载 `C:\Windows\Fonts\msyh.ttc` 等系统字体（只读，不复制、不打包），
   在缺少中文字体的机器上界面中文会显示为方块。把任意 ttf 放到 `assets/fonts/ui.ttf` 可解决。
5. **音效是合成的**：没有使用任何下载的音效，全部用 numpy 合成短促提示音，听感偏"电子"，属于占位级质量。
6. **商店出现位置**：按"每 5 个房间进入一次商店"实现为「每层第 4 间房清空后进入商店，然后打第 5 间 Boss」。
7. **敌人没有像素 sprite**：需求只要求三个角色的战斗资源，敌人/Boss 用 `_draw()` 几何绘制，保证零占位图。
8. **Web 版性能**：本地无头 Chrome（软件光栅）实测平均 49.9 FPS、最差 1% 帧 33.4ms，
   桌面 GPU 下预期稳定 60；如果目标机器较弱，优先减少 `PointLight2D` 数量（当前 3 个）而不是降画质。
9. **像素 sprite 的细节损失**：从插画 5 倍降采样到 52px 高，裙摆花纹等细节不可逆丢失，
   已通过对比度提升、暗部提亮、rim light、2px 描边尽量保住可读性。
