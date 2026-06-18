shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float border_width : hint_range(0.0, 0.5) = 0.05;

void fragment() {
    vec2 border = step(vec2(border_width), UV) * step(UV, vec2(1.0 - border_width));
    float is_inside = border.x * border.y;
    COLOR = mix(border_color, bg_color, is_inside);
}