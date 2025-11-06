shader_type particles;

uniform float ring_radius = 0.5;
uniform float expansion_speed = 2.0;

void start() {
    float r = fract(sin(dot(vec2(float(INDEX), TIME), vec2(12.9898, 4.1414))) * 43758.5453);
    float angle = r * TAU;

    CUSTOM.x = angle;
    CUSTOM.y = ring_radius;
    CUSTOM.w = 0.0;

    // Użyj pozycji RELATYWNEJ do EMISSION_TRANSFORM
    vec3 local_pos = vec3(cos(angle) * ring_radius, 0.0, sin(angle) * ring_radius);
    TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(local_pos, 1.0)).xyz;

    VELOCITY = vec3(0.0);
}

void process() {
    CUSTOM.w += DELTA;

    if (CUSTOM.w >= LIFETIME) {
        ACTIVE = false;
    }

    CUSTOM.y += expansion_speed * DELTA;

    float angle = CUSTOM.x;
    float radius = CUSTOM.y;

    // Użyj EMISSION_TRANSFORM dla globalnej pozycji
    vec3 local_pos = vec3(cos(angle) * radius, 0.0, sin(angle) * radius);
    TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(local_pos, 1.0)).xyz;

    float lifetime_ratio = CUSTOM.w / LIFETIME;
    COLOR.a = 1.0 - lifetime_ratio;

    VELOCITY = vec3(0.0);
}