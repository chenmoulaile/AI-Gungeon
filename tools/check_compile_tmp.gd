extends SceneTree
## 一次性编译自检（修复工程师专用，可删）：在项目环境（autoload 已注册）下
## load() 全部本次改动的脚本，编译失败即退出码 1。不启动游戏主循环、不截图。

const PATHS := [
	"res://scripts/main/game.gd",
	"res://scripts/systems/game_state.gd",
	"res://scripts/systems/coin.gd",
	"res://scripts/systems/bullet_pattern.gd",
	"res://scripts/enemies/enemy_base.gd",
	"res://scripts/enemies/enemy_ring_shooter.gd",
	"res://scripts/enemies/enemy_shooter.gd",
	"res://scripts/enemies/enemy_spreader.gd",
	"res://scripts/enemies/enemy_sniper.gd",
	"res://scripts/ui/hud.gd",
]


func _initialize() -> void:
	var bad := 0
	for p in PATHS:
		# load() 即触发编译；不调 reload()——autoload 脚本已有实例，reload 必失败（误报）
		var s: Script = load(p)
		if s == null:
			print("FAIL(load) ", p)
			bad += 1
		else:
			print("OK ", p)
	print("RESULT bad=", bad)
	quit(1 if bad > 0 else 0)
