shader_type canvas_item;

// This automatically captures the 3D scene behind the ColorRect
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// This will receive our Texture2DRD from the Compositor
uniform sampler2D jfa_texture : filter_linear; 

uniform float outline_thickness = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

uniform vec2 jfa_resolution = vec2(1920.0, 1080.0); 

void fragment() {
    vec4 scene_color = texture(screen_texture, SCREEN_UV);
    
    vec2 nearest_coord_jfa_pixels = texture(jfa_texture, SCREEN_UV).xy;
    
    if (nearest_coord_jfa_pixels.x < 0.0) {
        COLOR = scene_color;
    } else {
        vec2 nearest_uv = nearest_coord_jfa_pixels / jfa_resolution;
        
        vec2 diff = (SCREEN_UV - nearest_uv) * (1.0 / SCREEN_PIXEL_SIZE);
        float dist = length(diff);
        
        if (dist > 0.0 && dist <= outline_thickness) {
            COLOR = mix(scene_color, outline_color, outline_color.a);
        } else {
            COLOR = scene_color;
        }
    }
}