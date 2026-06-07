shader_type canvas_item;

uniform vec2 target_pos;
uniform vec2 moving_pos;
uniform float radius = 80.0; // Increased base radius for the falloff reach
uniform float threshold = 0.3; // Where the actual outline starts (0.0 to 1.0)
uniform float outline_thickness = 0.15; // How thick the line is relative to the field
uniform float edge_softness = 0.02; // Anti-aliasing for smooth edges
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Calculates a smooth, bell-shaped falloff that drops exactly to 0 at the radius
float get_metaball_field(vec2 frag_coord, vec2 center, float r) {
    float d = distance(frag_coord, center);
    
    // If we are outside the radius, it has zero influence
    if (d > r) {
        return 0.0;
    }
    
    // Polynomial falloff for that "gooey" liquid merge
    float x = d / r;
    float x2 = x * x;
    return (1.0 - x2) * (1.0 - x2);
}

void fragment() {
    // 1. Calculate the influence fields for both points
    float c1 = get_metaball_field(FRAGCOORD.xy, target_pos, radius);
    float c2 = get_metaball_field(FRAGCOORD.xy, moving_pos, radius);

    // 2. Add them together to create the fusion
    float sum = c1 + c2;

    // 3. Carve out the outline using the thresholds
    // Outer edge of the line
    float outer_edge = smoothstep(threshold - edge_softness, threshold + edge_softness, sum);
    // Inner edge of the line
    float inner_edge = smoothstep(threshold + outline_thickness - edge_softness, threshold + outline_thickness + edge_softness, sum);

    // 4. Subtract inner from outer to get just the ring
    float final_alpha = outer_edge - inner_edge;

    COLOR = vec4(outline_color.rgb, final_alpha * outline_color.a);
}