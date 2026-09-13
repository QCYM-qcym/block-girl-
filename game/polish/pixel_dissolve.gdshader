shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV) * tint;
	// Stable source-pixel mask. No screen blur, interpolated UV, or white flash.
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	float rank = mod(p.x * 3.0 + p.y * 5.0, 16.0) / 16.0;
	if (amount > 0.0 && rank < amount) source.a = 0.0;
	COLOR = source;
}
