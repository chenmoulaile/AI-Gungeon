shader_type canvas_item;

// 战斗层全屏后处理：暗角 / 色差 / 全屏闪色 / 弹幕密集警示
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 8.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dense : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 screen_size = vec2(640.0, 360.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = vec2(aberration / max(screen_size.x, 1.0), 0.0);
	vec3 col;
	col.r = texture(screen_texture, uv + px).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - px).b;

	float d = distance(uv, vec2(0.5));
	// 暗角：只压四角，中央弹幕区不动
	float v = smoothstep(0.44, 0.80, d) * vignette;
	col *= 1.0 - v * 0.5;
	// 弹幕密集：四角红色光晕
	float corner = smoothstep(0.34, 0.78, d);
	col = mix(col, vec3(0.95, 0.22, 0.28), corner * dense * 0.18);
	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
