shader_type canvas_item;

## Lightweight, low-overhead CRT scanline and vignette shader.
## Calibrated for 256x240 native NES viewport on low-spec hardware.

uniform float scanline_count : hint_range(0.0, 480.0) = 240.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Alternating horizontal scanline dimming
	float scanline = sin(UV.y * scanline_count * 3.14159265);
	scanline = (scanline + 1.0) * 0.5;
	col.rgb -= col.rgb * (1.0 - scanline) * scanline_intensity;

	// Subtle radial edge vignette
	vec2 uv = UV * (1.0 - UV.yx);
	float vig = uv.x * uv.y * 15.0;
	vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);
	col.rgb *= vig;

	COLOR = col;
}
