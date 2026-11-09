shader_type spatial;
// Роба обходчика для фигуры двойника: комбинезон, полосы, землистое лицо выше шеи.
uniform float base_y = 0.0;
uniform sampler2D skin_tex : source_color, filter_nearest;
varying float h;

void vertex() {
	h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - base_y;
}

void fragment() {
	vec3 suit = vec3(0.09, 0.1, 0.12);
	// Складки и грязь — мелкий шум по UV.
	float n = fract(sin(dot(floor(UV * 96.0), vec2(12.9898, 78.233))) * 43758.5453);
	suit *= 0.85 + n * 0.3;
	float stripe = max(step(abs(h - 1.18), 0.03), step(abs(h - 0.5), 0.025));
	vec3 cloth = mix(suit, vec3(0.62, 0.62, 0.55), stripe);
	vec3 skin = texture(skin_tex, UV).rgb * vec3(0.36, 0.33, 0.32);
	bool head = h > 1.5;
	ALBEDO = head ? skin : cloth;
	ROUGHNESS = head ? 0.75 : 0.95;
	SPECULAR = 0.2;
}
