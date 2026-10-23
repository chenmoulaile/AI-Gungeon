shader_type canvas_item;

// 转场遮罩：0 淡入淡出 / 1 圆形收缩 / 2 横向滑动
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int mode : hint_range(0, 2) = 0;
uniform vec4 tint : source_color = vec4(0.07, 0.10, 0.17, 1.0);

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	if (mode == 0) {
		a = progress;
	} else if (mode == 1) {
		float d = distance(uv, vec2(0.5)) / 0.72;
		float r = 1.0 - progress;
		a = smoothstep(r - 0.05, r + 0.05, d);
	} else {
		float edge = 0.10;
		a = 1.0 - smoothstep(progress - edge, progress + edge, uv.x);
	}
	COLOR = vec4(tint.rgb, tint.a * clamp(a, 0.0, 1.0));
}
