shader_type canvas_item;

uniform float scanline_density : hint_range(100.0, 1000.0) = 450.0;
uniform float scanline_intensity : hint_range(0.0, 0.15) = 0.035;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.45;
uniform vec4 alarm_color : source_color = vec4(1.0, 0.1, 0.1, 0.0);
uniform float alarm_pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Viñeta espacial suave
    vec2 coord = (uv - 0.5) * 2.0;
    float dist = length(coord);
    float vignette = smoothstep(0.7, 1.4, dist) * vignette_intensity;
    
    // Líneas de barrido discretas estilo monitor de telemetría NASA
    float scanline = sin(uv.y * scanline_density * 3.14159) * 0.5 + 0.5;
    float scan_effect = scanline * scanline_intensity;
    
    // Alarma pulsante de borde (cuando la nave entra en Safe Mode)
    float edge_dist = max(abs(coord.x), abs(coord.y));
    float edge_glow = smoothstep(0.75, 1.0, edge_dist) * alarm_pulse;
    
    vec4 col = vec4(0.0, 0.0, 0.0, vignette + scan_effect);
    if (edge_glow > 0.001) {
        col = mix(col, alarm_color, edge_glow * 0.45);
    }
    
    COLOR = col;
}
