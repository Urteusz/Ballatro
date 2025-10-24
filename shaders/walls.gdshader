shader_type spatial;

// Enable transparency
render_mode blend_mix, depth_draw_opaque, cull_back;

// --- Uniforms ---
// uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// This is the position of the object (e.g., the player)
// You must set this from your GDScript.
uniform vec3 object_position; 

// The distance at which the wall is fully VISIBLE (Alpha = 1.0)
uniform float visible_distance : hint_range(0.0, 20.0) = 3.0;
// The distance at which the wall is fully INVISIBLE (Alpha = 0.0)
uniform float invisible_distance : hint_range(0.0, 20.0) = 8.0;

// This 'varying' passes the world position from the vertex to the fragment
varying vec3 v_world_pos;

void vertex() {
	// Calculate the world position for this vertex
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Get the base color
	// vec4 tex_color = texture(albedo_texture, UV);
	// ALBEDO = tex_color.rgb;
	ALBEDO = albedo_color.rgb;

	// Calculate the distance from this pixel to the object's position
	float dist = distance(object_position, v_world_pos);

	// Calculate the fade amount
	// We use smoothstep(edge0, edge1, x)
	// We want Alpha = 0.0 (invisible) when dist >= invisible_distance (edge0)
	// We want Alpha = 1.0 (visible) when dist <= visible_distance (edge1)
	// This creates a smooth fade from 0 to 1 as the object moves
	// from the 'invisible_distance' to the 'visible_distance'.
	float fade_alpha = smoothstep(invisible_distance, visible_distance, dist);
	
	// Apply the final alpha
	// ALPHA = tex_color.a * fade_alpha;
	ALPHA = albedo_color.a * fade_alpha;
}