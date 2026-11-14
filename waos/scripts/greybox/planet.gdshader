shader_type spatial;
// Greybox de planeta: color plano + retícula de latitud/longitud cada 15°.
uniform vec3 base_color : source_color = vec3(0.30, 0.38, 0.52);
uniform vec3 line_color : source_color = vec3(0.62, 0.68, 0.80);
uniform float line_strength = 0.55;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(local_pos);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float lon = atan(p.z, p.x);
	vec2 g = vec2(lon / 6.2831853 * 24.0, lat / 3.1415927 * 12.0);
	vec2 d = abs(fract(g - 0.5) - 0.5) / max(fwidth(g), vec2(1e-4));
	float line = 1.0 - min(min(d.x, d.y), 1.0);
	float equator = 1.0 - min(abs(lat) / max(fwidth(lat) * 1.5, 1e-4), 1.0);
	ALBEDO = mix(base_color, line_color, max(line, equator) * line_strength);
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
