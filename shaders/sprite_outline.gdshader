shader_type canvas_item;

// 像素描边：四方向采样邻居 alpha，补一圈暗色轮廓
// 用于浅色地面（第 1 层）上白色系角色与背景分离
uniform vec4 outline_color : source_color = vec4(0.10, 0.13, 0.22, 0.85);
uniform float outline_size = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	float edge = clamp(a - col.a, 0.0, 1.0) * outline_color.a;
	vec3 rgb = mix(col.rgb, outline_color.rgb, edge);
	COLOR = vec4(rgb, max(col.a, edge));
}
