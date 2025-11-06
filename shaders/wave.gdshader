shader_type particles;

uniform float ring_radius = 0.5;
uniform float expansion_speed = 2.0;

void start() {
    float r = fract(sin(dot(vec2(float(INDEX), TIME), vec2(12.9898, 4.1414))) * 43758.5453);
    float angle = r * TAU;

    CUSTOM.x = angle;
    CUSTOM.y = ring_radius;
    CUSTOM.w = 0.0;

    TRANSFORM[3].x = cos(angle) * ring_radius;
    TRANSFORM[3].z = sin(angle) * ring_radius;
    TRANSFORM[3].y = 0.0;

    VELOCITY = vec3(0.0);
}

void process() {
    CUSTOM.w += DELTA;
    CUSTOM.y += expansion_speed * DELTA;

    float angle = CUSTOM.x;
    float radius = CUSTOM.y;

    TRANSFORM[3].x = cos(angle) * radius;
    TRANSFORM[3].z = sin(angle) * radius;
    TRANSFORM[3].y = 0.0;

    float lifetime_ratio = CUSTOM.w / LIFETIME;
    COLOR.a = 1.0 - lifetime_ratio;

    VELOCITY = vec3(0.0);
}
