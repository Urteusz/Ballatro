// ale wygenerowal shader
shader_type spatial;

// This enables transparency. CRITICAL!
// blend_mix = allows alpha blending
// depth_draw_opaque = makes the object still cast shadows and clip correctly
render_mode blend_mix, depth_draw_opaque;

// This lets you add a texture to your wall in the Inspector
//uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// These are the distances you can control from the Inspector
uniform float fade_start_distance : hint_range(0.0, 20.0) = 5.0;
uniform float fade_end_distance : hint_range(0.0, 20.0) = 2.0;

// This 'varying' will pass the world position from the vertex to the fragment
varying vec3 v_world_pos;

void vertex() {
	// Calculate the world position for this vertex
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Get the base color from the texture
	//vec4 tex_color = texture(albedo_texture, UV);
	//ALBEDO = tex_color.rgb;
	ALBEDO = albedo_color.rgb;

	// Calculate the distance from this specific pixel to the camera
	// CAMERA_POSITION_WORLD is a built-in Godot variable
	float dist = distance(CAMERA_POSITION_WORLD, v_world_pos);

	// Calculate the fade amount
	// smoothstep() creates a smooth gradient between the end and start distances
	// It returns 0.0 if dist < fade_end_distance (fully transparent)
	// It returns 1.0 if dist > fade_start_distance (fully opaque)
	float fade_alpha = smoothstep(fade_end_distance, fade_start_distance, dist);
	
	// Apply the final alpha
	//ALPHA = tex_color.a * fade_alpha;
	ALPHA = albedo_color.a * fade_alpha;
}