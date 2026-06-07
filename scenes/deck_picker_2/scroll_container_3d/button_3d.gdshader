shader_type spatial;
render_mode depth_draw_opaque;

uniform vec3 albedo_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float z_offset = 0.0;

uniform float fade_min_distance = 1.5;
uniform float fade_max_distance = 2.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

const float DITHER_THRESHOLDS[16] = float[](
    1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
    13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
    4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
    16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
);

void fragment() {
	// -0.1 is the position of the backface of a 0.2 wide mesh
	if (local_position.z + z_offset < -0.11) {
		discard;
	}
	
	float dist = length(VERTEX);
	float fade_ratio = clamp((dist - fade_min_distance) / (fade_max_distance - fade_min_distance), 0.0, 1.0);
	
	ivec2 screen_coord = ivec2(mod(FRAGCOORD.xy, 4.0));
	int matrix_index = screen_coord.x + screen_coord.y * 4;
	
	if (fade_ratio < DITHER_THRESHOLDS[matrix_index]) {
		discard;
	}
	
	ALBEDO = albedo_color;
	ROUGHNESS = 0.4;

	// proximity fade
	//ALPHA = smoothstep(0.0, fade_distance, length(VERTEX));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
