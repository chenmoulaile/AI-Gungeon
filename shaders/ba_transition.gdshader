shader_type canvas_item;

// 转场遮罩（v0.7 P2）：8 步 Bayer 抖动擦除 / 抖动圆形收缩 / 抖动横向滑动
// 全部硬边 alpha（0/1），不做平滑淡入淡出。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int mode : hint_range(0, 2) = 0;
uniform vec4 tint : source_color = vec4(0.031, 0.043, 0.078, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = y * 4 + x;
	float m[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0;
}

void fragment() {
	vec2 px = floor(UV * vec2(640.0, 360.0));
	float b = bayer4(px);
	float q = floor(clamp(progress, 0.0, 1.0) * 8.0 + 0.5) / 8.0;
	float cover = 0.0;
	if (mode == 0) {
		cover = step(b, q);
	} else if (mode == 1) {
		float d = distance(UV, vec2(0.5)) / 0.72;
		float v = q * 1.08 - d;
		cover = step(0.0, v + (b - 0.5) * 0.12);
	} else {
		float v = q - UV.x;
		cover = step(0.0, v + (b - 0.5) * 0.06);
	}
	COLOR = vec4(tint.rgb, tint.a * cover);
}
