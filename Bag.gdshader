shader_type canvas_item;

uniform vec4 bag_color : source_color = vec4(1.0, 1.0, 1.0, 0.28);
uniform float rim_power : hint_range(0.0, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 3.0) = 1.1;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.5;
uniform float highlight_speed : hint_range(-2.0, 2.0) = 0.12;
uniform float highlight_width : hint_range(0.01, 1.0) = 0.15;
uniform float wrinkle_scale : hint_range(0.0, 50.0) = 20.0;
uniform float wrinkle_strength : hint_range(0.0, 1.0) = 0.12;
uniform float noise_speed : hint_range(0.0, 2.0) = 0.04;

// Pushed from GDScript every time the polygon shape changes,
// since Polygon2D.uv is unreliable without an assigned texture.
uniform vec2 bounds_min;
uniform vec2 bounds_size = vec2(1.0, 1.0);

varying vec2 local_uv;

void vertex() {
	// VERTEX is the local-space vertex position for canvas_item
	// shaders — this always works, unlike Polygon2D's uv array.
	local_uv = (VERTEX - bounds_min) / bounds_size;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = local_uv;

	float edge_dist = min(uv.x, 1.0 - uv.x) * 2.0;
	float side_rim = (1.0 - smoothstep(0.0, 0.25, edge_dist)) * rim_strength;

	float bottom_rim = smoothstep(0.6, 1.0, uv.y) * rim_strength * 0.5;

	float diag = uv.x + uv.y * 0.3 - TIME * highlight_speed;
	float sheen = smoothstep(highlight_width, 0.0, abs(fract(diag) - 0.5)) * highlight_strength;

	float n = noise(uv * wrinkle_scale + TIME * noise_speed);
	float wrinkle = (n - 0.5) * wrinkle_strength;

	float alpha = bag_color.a + side_rim + bottom_rim + wrinkle;
	alpha = clamp(alpha, 0.0, 0.85);

	vec3 color = bag_color.rgb + sheen * 0.3;

	COLOR = vec4(color, alpha);
}