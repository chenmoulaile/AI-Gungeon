# AI Gungeon

**v0.11.0** · GPT / Claude 模型套餐与额度系统（耗尽降级 / 额度重置卡）· 开局全屏登场 · 成人版非像素立绘 · 翻滚 360° 空翻 · 全敌人与 Boss 强化 · 三层专属 Boss（镜盾反射 / 双生核心）· 分支地图（每层 7 节点 + 门后二选一）· 事件房三选一 · 藏品稀有度分档 / 商店刷新与治疗

一款 2D 像素俯视角 Roguelike 射击游戏，用 **Godot 4 + GDScript** 开发。
玩法参考《Enter the Gungeon》的核心循环（角色选择 → 房间清怪 → 开门 → 商店 → Boss → 下一层），
角色原型为三个 AI 助手的拟人形象，武器机制、数值、关卡与代码全部原创。

---

## 同人声明与署名

本游戏为非官方同人作品，完全免费，不含任何付费、广告、内购或捐赠解锁内容。

DeepSeek 鲸鱼娘形象基于 B站 UP 主 ZipZipPipe 的二创设计；
其原型为 B站 UP 主 上善无形 的原创角色「溟月」。
GPT 龙娘、Claude 大小姐形象基于 B站 UP 主 ZipZipPipe 的 AI 娘系列二创。

原角色形象以 CC BY-NC-SA 4.0 协议开放非商业二创。
本项目遵循该协议：署名、非商业、相同方式共享。

---

## 运行方式

### 方式一：直接运行已导出的构建

```
D:\projects\AiGungeon\build\windows\AIGungeon.exe
```

### 方式二：在 Godot 编辑器中运行

1. 启动编辑器（绿色版，无需安装）：

   ```
   D:\DevTools\Godot\Godot_v4.7.2-stable_win64.exe
   ```

2. 打开工程：`D:\projects\AiGungeon\project.godot`
3. 按 **F5** 运行。

### 方式三：浏览器本地预览（不弹游戏窗口）

```bat
:: 1) 导出 Web 版
D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\projects\AiGungeon --export-release "Web" build/web/index.html

:: 2) 起本地服务器（带 wasm MIME 与 COOP/COEP 头）
python D:\projects\AiGungeon\tools\serve_web.py 8765

:: 3) 浏览器打开 http://127.0.0.1:8765/index.html
```

Web 版关闭了线程（`thread_support=false`），不需要特殊服务器配置也能跑；
`tools/serve_web.py` 仍然带上 COOP/COEP 头，方便以后开线程时不用改服务器。

### 方式四：命令行无头自测（不需要显示器）

```bat
D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\projects\AiGungeon res://tests/smoke_test.tscn
```

自测覆盖：三个角色开局 / 开火 / 技能 / 翻滚 / 清场开门 / 门后二选一 / 商店购买与刷新 / 三层 Boss 选择与镜盾免伤 / 迷你首领数值 / 死亡结算。

---

## 构建桌面版与网页版

### 0. 一次性准备

1. 安装 Godot **4.7.2 stable**（绿色版即可，无需安装器）。
2. 安装同版本导出模板：编辑器菜单 `编辑器 → 管理导出模板 → 下载并安装`。
   检查目录 `%APPDATA%\Godot\export_templates\4.7.2.stable\` 存在。
3. 新增/替换 PNG 资产后，先让 Godot 生成 `.import`，否则运行时读不到贴图：

```bat
D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\projects\AiGungeon --editor --quit
```

### 1. Windows 桌面版

```bat
D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\projects\AiGungeon --export-release "Windows Desktop" D:\projects\AiGungeon\build\windows\AIGungeon.exe
```

产物 `build/windows/AIGungeon.exe`：单文件，PCK 已内嵌，双击即玩。
导出预设见 `export_presets.cfg`，已排除 `tests/`、`tools/`、`assets/reference/`、`preview/`、`docs/` 等开发资源。

Linux（可选）：

```bash
godot --headless --path . --export-release "Linux" build/linux/AIGungeon.x86_64
```

### 2. 网页版

```bat
D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\projects\AiGungeon --export-release "Web" D:\projects\AiGungeon\build\web\index.html
```

产物目录 `build/web/`：`index.html`、`index.js`、`index.wasm`、`index.pck`。
必须通过 HTTP 打开（`file://` 会被浏览器拦），本地预览：

```bat
python D:\projects\AiGungeon\tools\serve_web.py 8765
```

浏览器访问 `http://127.0.0.1:8765/index.html`。部署到静态服务器时保证 `.wasm`
的 MIME 为 `application/wasm`（`serve_web.py` 已带 COOP/COEP 与 MIME 配置）。

### 3. 一键发布（GitHub Actions）

推送 `v*` tag 会触发 `.github/workflows/release.yml`：云端安装 Godot 4.7.2 与导出模板，
分别导出 Windows / Linux / Web，打包后发布到 GitHub Release。

```bash
git tag v0.10.0
git push origin v0.10.0
```

### 4. 导出前自检

```bat
D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\projects\AiGungeon res://tests/smoke_test.tscn
```

确认输出 `失败项: 0` 再导出。

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
全程 0.25s 无敌帧、结束时靠减速度自然滑出（不是硬停）。
受击时不再清空翻滚缓冲：在 0.1s 输入窗口内按下的翻滚，会在硬直结束后照常触发。
普通敌人被击杀时追加 0.10s 顿帧，Boss 与精英不额外延长，避免打断弹幕节奏。

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
- Boss 血条标出 65% / 30% 阶段分界线，阶段转换时弹出「阶段转换！」横幅。

---

## 操作说明

| 操作 | 按键 |
| --- | --- |
| 移动 | `W` `A` `S` `D`（或方向键） |
| 瞄准 | 鼠标 |
| 射击 | 鼠标左键（Claude 为按住持续激光） |
| 翻滚 | `空格`（0.25s 无敌帧，0.8s 冷却） |
| 主动技能 | `E`（冷却 7–9s，角色不同） |
| 切换武器 | 鼠标滚轮 |
| 切换 AI 模型 | `R`（GPT：Luna / Sol / Astra；Claude：Sonnet / Opus） |
| 使用额度重置卡 | `T`（额度耗尽后立即回满） |
| 难度选择 | 鼠标点击「简单 / 普通 / 困难」，或按 `F1` `F2` `F3` |
| 角色选择 | 鼠标点击卡片，或按 `1` `2` `3` |
| 门后二选一 | 点击卡片 / `1` `2` / 方向键 + 回车 |
| 事件房三选一 | 点击卡片 / `1` `2` `3`，`ESC` 放弃奖励 |
| 商店 | 点击按钮 / 数字键 `1-4` 购买，`R` 刷新，`H` 治疗，`P` 升级套餐，`K` 买额度卡，`ESC` 离开 |
| 跳过对话 | `空格` / `回车` / 鼠标点击 |

---

## 玩法循环

```
角色选择 → 每层 7 节点分支地图（入口 → 二选一 → 事件房 → 二选一 → Boss）
        → 清层奖励 +10 与存款利息 → 下一层（地图按种子重建，敌人缩放封顶）
```

每层固定 7 个节点、5 层深度，岔口只能二选一：

```
             ┌─ 战斗房（混合） ─┐
入口（战斗） ─┤                  ├─ 事件房 ─┬─ 高潮战斗 ─┐
             └─ 精英房（紫色） ─┘           └─ 商店 ─────┴─ Boss
```

- 第一岔口「混合 / 精英」、第二岔口「高潮 / 商店」的左右顺序由本局种子决定，
  同一局内续玩可精确还原路线。
- **精英房**清场必掉一件蓝/紫档藏品；藏品集齐时改发 30 金币。
- **事件房**没有敌人，进门即开三选一：回复 25 生命 / 随机白档藏品 / 35 金币，
  `ESC` 可放弃；选完直接开门。
- 商店是第二岔口的选项之一，逛完商店直接进入 Boss；不走商店则打高潮战斗。
- 每波敌人数量封顶 10 只，超出的部分转为精英；敌人缩放封顶 6 倍。
- 层末结算：清层 +10 金币，另按存款发放利息 `min(15, 金币/50×5)`。
- HUD 右上角是分支小地图：走过的节点变暗、当前节点金框、Boss 红色、商店绿色。
- 房间固定 960×540，敌人按波次刷新，清场掉落金币。
- 死亡即结束本局，结算界面显示击杀数、到达层数、藏品与组合。
- 手感优先级：弹幕可读性 > 翻滚手感 > 构筑爽点 > 内容数量。

---

## 三个角色

### DeepSeek · 深蓝鲸歌

| 项目 | 内容 |
| --- | --- |
| 主武器 | **大白饭**：左键抛掷，落地炸开并留下 2s 白饭减速区；每发消耗 7 Token |
| 副武器 | **铁盆**：短按轻挥；长按蓄力（伤害/范围随蓄力提升）；连续 3 次落空触发「要饭」，敌人有概率掉大白饭（+15 Token） |
| 主动技能 | **鲸群集结**：消耗 20 Token 召唤小肥鱼，自动索敌吐泡，上限 8 只 |
| 被动 | **Token 账户**：移动/翻滚不耗 Token，出手/召唤消耗，击杀 +2 |

### GPT · 白鳞龙娘

| 项目 | 内容 |
| --- | --- |
| 主武器 | **云端龙息杖**：每次开火消耗额度，伤害/射速/弹速随当前模型倍率变化 |
| 模型模式 | **Luna**（轻量，稳）→ **Sol**（标准，+35% 伤害）→ **Astra**（深度，+85% 伤害、射速略降）；`R` 循环 |
| 套餐 | **Free / Plus / Pro**，金币在商店升级；套餐越高额度上限越高、重置更快，并解锁更高模型 |
| 额度 | Free 120 · Plus 300 · Pro 600；额度耗尽会全面弱化（伤害 45% / 射速 60% / 弹速 75% / 移速 55%），等待重置倒计时或使用额度重置卡 |
| 主动技能 | **涌现**：随机获得 伤害 +40% / 射速 +50% / 弹速 +60% 之一，持续 5s |
| 被动 | **上下文窗口**：每击杀 +1 token，满 20 后下一次「涌现」三种强化同时生效 |

### Claude · 橙羽书记

| 项目 | 内容 |
| --- | --- |
| 主武器 | **长上下文光束**：按住左键持续激光，宽度 1s 内由细变粗、伤害同步提升，松开进入 1.2s 冷却 |
| 模型模式 | **Sonnet**（均衡）→ **Opus**（深度，+55% 伤害、射速略降）；`R` 循环 |
| 套餐 | **Free / Pro / Max 5x / Max 20x**，额度 120 / 300 / 450 / 700，重置时间随套餐缩短 |
| 额度 | 与 GPT 同一套耗尽降级与重置卡规则；免费档只能使用 Sonnet |
| 主动技能 | **宪法规避**：展开可吸收 6 发敌弹的护盾，持续 3s，每吸收 1 发回复 2 点生命 |
| 被动 | **细致阅读**：自身 120 像素半径内敌方子弹速度 -25% |

### 额度系统（GPT / Claude）

- 每局开局回满额度，射击持续消耗；额度归零进入「耗尽」状态：伤害 ×0.45、射速 ×0.60、弹速 ×0.75、移速 ×0.55。
- 额度按真实产品逻辑使用滚动重置窗口：GPT Free 180s / Plus 150s / Pro 110s，Claude 180 / 150 / 120 / 90 秒。
- 商店可用金币购买**额度重置卡**（45 金，最多 3 张），按 `T` 立即回满额度并跳过重置等待。
- 套餐升级价格：GPT Plus 70 / Pro 180；Claude Pro 80 / Max 5x 200 / Max 20x 420。

---

## 藏品与组合效果

18 件藏品（`resources/upgrades/*.tres`），按稀有度分三档定价：**白 18 / 蓝 30 / 紫 48**。
白档是纯数值，蓝档带条件触发钩子，紫档是角色专属的质变件。

| 藏品 | 档位 | 效果 | 价格 |
| --- | --- | --- | --- |
| 冷却模块 | 白 | 技能冷却 -20% | 18 |
| 磁力线圈 | 白 | 金币拾取范围 +45 | 18 |
| 穿甲长钉 | 白 | 子弹穿透 +1 | 18 |
| 吸血芯片 | 白 | 每 8 次击杀回复 1 点生命 | 18 |
| 锋利弹头 | 蓝 | 同一目标连续命中 3 次后，之后每发暴击 | 30 |
| 急速循环 | 蓝 | 连续命中 6 次后射速大涨，2 秒不命中重置 | 30 |
| 轻羽长靴 | 蓝 | 翻滚之后的一小段路跑得比平时快得多 | 30 |
| 暴击透镜 | 蓝 | 对满血敌人的第一击必定暴击 | 30 |
| 备用心脏 | 蓝 | 生命上限 +1 并立即回复 1 点 | 30 |
| 翻滚核心 | 蓝 | 翻滚冷却 -25% | 30 |
| 分裂棱镜 | 蓝 | 每次射击额外发射 1 发子弹 | 30 |
| 学者手记 | 蓝 | 生命上限 +1，伤害 +5% | 30 |
| 回声追踪 | 紫 | 裂开的小弹会自己去找人（DeepSeek） | 48 |
| 余温记录 | 紫 | 光束走过的地方还会烧一会儿（DeepSeek） | 48 |
| 模态残响 | 紫 | 换模式的瞬间留下一个影子替你打一下（GPT） | 48 |
| 回声加速 | 紫 | 喊完之后手会变快（GPT） | 48 |
| 碎盾礼赞 | 紫 | 护盾碎掉的时候，四面都会还手（Claude） | 48 |
| 过载祷文 | 紫 | 举太久，光会烧过头（Claude） | 48 |

商店规则（v0.10）：

- 每次上架 3 件普通藏品，白档权重 4 / 蓝档 2 / 紫档 1，白档更容易出现；
- `R` 刷新货架，首次 5 金，之后每次 +5；刷新不会移除已出现的角色专属武器；
- `H` 治疗 25 点生命，价格 15 金起、每层 +5、封顶 30，每间商店限一次；
- 与已持有藏品能凑组合的选项权重 ×3，并用 `★ 与已有藏品共鸣` 标出。

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

## Boss：三层轮换 × 3

每层固定一只专属 Boss，招式池复用、登场台词与配色各自独立；循环顺序为
第 1 层「回响聚合体」→ 第 2 层「镜像回声」→ 第 3 层「双生回响」。

| 层 | Boss | 核心机制 | 招式池 |
| --- | --- | --- | --- |
| 一 | 回响聚合体 ECHO AGGREGATE | 三阶段抽招，残血召唤 | 环 / 扇 / 冲锋 / 追踪 / 激光 / 螺旋 / 地雷 / 召唤 |
| 二 | 镜像回声 MIRROR ECHO | 每 3.6s 展开 1.45s 镜盾：免伤并把子弹双发反射回玩家 | 扇 / 环 / 激光 / 地雷 / 螺旋 |
| 三 | 双生回响 TWIN ECHO | 左右核心共享血条，出招在两侧交替；三阶段双环交叉 | 扇 / 环 / 追踪 / 螺旋 / 交叉环 |

所有 Boss 在 65% / 30% 血量进入下一阶段，阶段转换有 1.25s 的硬直窗口。

**v0.11 强度重做（参考《元气骑士》）**：小怪血量约 ×1.7–2.4、弹速 +15–40%、攻击间隔 −25–35%；
射手 4 向螺旋、扩散者 7 发扇 / 12 发环、环形射手 14→16 发、狙击手双发点射。
Boss 血量 420 / 400 / 460（随层缩放），环 18 发、扇 9 发、追踪 5 发、螺旋 22 发、
第 3 阶段每 6.5s 召唤 3 只；双生回响三阶段双环 14×2 发。每波小怪数量也提高约 1 只。

**迷你首领**：混合房 / 高潮房的首波有 15% 概率把一只敌人升为迷你首领——
在精英（×1.55 血、+2 金币）之上再 ×1.6 血、×1.06 体积、+6 金币，头顶红金王冠。

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

### 2. 立绘（界面层）

- 成人版非像素立绘：`assets/portraits/<角色>_full.png` / `<角色>_bust.png` / `<角色>_face.png`（1024×1024）
- v0.11 起**角色选择卡片**与**开局全屏登场**使用 `_bust.png` / `_full.png`，`TEXTURE_FILTER_LINEAR`，不做像素化；
  `TextureRect` 必须设 `EXPAND_IGNORE_SIZE`，否则会被原图尺寸撑爆
- 像素立绘 `assets/portraits/<角色>_pixel.png`（96×128）与 `<角色>_pixel_avatar.png`（32×32）
  仍用于战斗内 HUD 头像 / 对话 / 结算等需要与像素 sprite 统一的界面
- 像素立绘处理：参考三视图 → 去背景 → 取正面视图 → 等比缩放到 96×128 → 20 色量化 → 补画虹膜 → 1px 描边
- 立绘**不进入战斗场景**

### 3. 视觉一致性

- 立绘与像素 sprite 不要求一模一样，但发色、瞳色、服装主色、标志性配件一致：
  - DeepSeek：深蓝长发 + 蓝瞳 + 深蓝白女仆裙 + 鲸尾 / 耳鳍
  - GPT：白发 + 紫瞳 + 白色长裙 + 龙角 / 龙翼 / 龙尾
  - Claude：橙发 + 橙瞳 + 橙白裙 + 雏菊发饰
- `assets/` 下**没有任何纯色矩形占位图**：房间地板、墙体、门、敌人、Boss、子弹、光束全部用 `_draw()` 程序化绘制。

### 4. 图标与音效

脚本：`tools/make_ui_icons.py`

- 18 个藏品图标：`assets/icons/<id>.png`（32×32，几何图形程序化绘制）
- 9 个音效：`assets/audio/*.wav`（22050Hz 单声道，numpy 正弦/方波/噪声合成，**未使用任何外部音效素材**）

### 5. 素材替换指南

| 想替换的东西 | 怎么做 |
| --- | --- |
| 像素 sprite | 直接覆盖 `assets/sprites/<角色>/<动画>.png`，要求**横向帧表、每帧 64×64、脚底对齐 y=61**；或改 `tools/make_pixel_sprites.py` 里的 `CHARACTERS` 配置后重跑 |
| 立绘 | 覆盖 `assets/portraits/<角色>_pixel.png`（96×128）与 `<角色>_pixel_avatar.png`（32×32），或改 `tools/make_pixel_sprites.py` 的 `CHARACTERS["<角色>"]["portrait"]` 后重跑 |
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
  portraits/                  96x128 像素立绘 + 32x32 头像
  icons/                      藏品图标
  audio/                      程序化合成音效
  fonts/                      字体（可选，放 ui.ttf）
scenes/
  main/    main.tscn game.tscn
  player/  player.tscn
  enemies/ enemy_chaser / enemy_shooter / enemy_spreader / boss / boss_mirror / boss_twins
  rooms/   room_basic.tscn
  ui/      hud / character_select / shop / result / boss_intro / portrait_dialog
scripts/
  player/  player.gd
  weapons/ weapon_base / weapon_reasoning_chain / weapon_multimodal / weapon_long_context
           bullet.gd / beam.gd
  enemies/ enemy_base / enemy_chaser / enemy_shooter / enemy_spreader / boss / boss_mirror / boss_twins
  systems/ game_config / game_state / upgrade_db / upgrade / character_data
           floor_map / room_basic / coin / sfx
  ui/      hud / character_select / shop / result / boss_intro / portrait_dialog
           event_room / room_choice
  main/    main.gd / game.gd
resources/
  characters/  3 个角色 .tres
  upgrades/    18 个藏品 .tres
tools/          Python 资源生成脚本
tests/          无头自测与截图脚本
build/          Windows 导出产物
```

---

## 环境与安装记录（当前机器）

| 工具 | 版本 | 实际安装路径 | 是否加入 PATH |
| --- | --- | --- | --- |
| Godot | 4.7.2.stable | `D:\DevTools\Godot\Godot_v4.7.2-stable_win64.exe` | 否（用绝对路径调用） |
| Godot 导出模板 | 4.7.2.stable | `%APPDATA%\Godot\export_templates\4.7.2.stable\` | — |
| Python | 3.14.6 | `C:\Users\<你>\AppData\Local\Python\pythoncore-3.14-64\python.exe` | 否（用绝对路径调用） |
| Pillow | 12.3.0 | 同上 `Lib\site-packages` | — |
| numpy | 2.5.3 | 同上 `Lib\site-packages` | — |

> 注意：PATH 里的 `python` 可能是 MSYS2 的 mingw python，**没有 pip 和 Pillow**。
> 跑 `tools/make_pixel_sprites.py` 时请用上面那个 Python 3.14 的绝对路径。
> Godot 导出模板现在位于默认 `%APPDATA%\Godot\export_templates\`，不再需要重定向 APPDATA。

---

## 已知问题与妥协

1. **Claude 仍用侧视图**：大肥鱼与 GPT 已有完整正面三视图（`assets/reference/*_3view*.png`），
   Claude 只有旧的 Q 版三视图且左格被裁，因此保持 `view=1`（侧面）。
   补一张完整的 Claude 正面三视图后，把 `make_pixel_sprites.py` 里 claude 的 `view` 改成 0 重跑即可。
2. **立绘分成两套**：战斗内仍用像素立绘以匹配像素 sprite；角色选择与开局登场使用
   1024×1024 成人版 `_bust` / `_full` 并开线性过滤，两套画风刻意不统一。
3. **Boss 没有参考立绘**：三只 Boss（回响聚合体 / 镜像回声 / 双生回响）都没有对应的参考图，
   登场界面用与战斗内一致的几何风格放大渲染（程序化绘制），未引入任何外部素材。
4. **中文字体依赖系统字体**：优先加载 `C:\Windows\Fonts\msyh.ttc` 等系统字体（只读，不复制、不打包），
   在缺少中文字体的机器上界面中文会显示为方块。把任意 ttf 放到 `assets/fonts/ui.ttf` 可解决。
5. **音效是合成的**：没有使用任何下载的音效，全部用 numpy 合成短促提示音，听感偏"电子"，属于占位级质量。
6. **商店是分支节点**：v0.10 起商店位于第二岔口，选了商店就直接进 Boss，
   放弃了才打高潮战斗；因此每层最多逛一次商店，不存在「第 4 间房后固定商店」。
7. **敌人没有像素 sprite**：需求只要求三个角色的战斗资源，敌人/Boss 用 `_draw()` 几何绘制，保证零占位图。
8. **Web 版性能**：本地无头 Chrome（软件光栅）实测平均 49.9 FPS、最差 1% 帧 33.4ms，
   桌面 GPU 下预期稳定 60；如果目标机器较弱，优先减少 `PointLight2D` 数量（当前 3 个）而不是降画质。
9. **像素 sprite 的细节损失**：从插画降采样到 52px 高，裙摆花纹等细节不可逆丢失。
   现在改为「正面参考图 + 去背景 + 24 色量化 + 1px 主题色描边」，不再叠加 2px 近黑描边和描边 shader，
   黑框问题已消除；细节保留仍受 52px 上限约束。
