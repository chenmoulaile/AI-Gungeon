shader_type canvas_item;

// 地面微波动：两层正弦叠加的极淡亮带，让地板不是完全静止
uniform float strength : hint_range(0.0, 0.3) = 0.055;
uniform vec4 tint : source_color = vec4(0.66, 0.80, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	float a = sin(uv.x * 13.0 + TIME * 0.85) * 0.5 + 0.5;
	float b = sin(uv.y * 9.0 - TIME * 0.55) * 0.5 + 0.5;
	float w = a * b;
	COLOR = vec4(tint.rgb, w * strength);
}
