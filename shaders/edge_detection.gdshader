shader_type spatial;
render_mode unshaded;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

uniform float depth_sensitivity : hint_range(0.01, 1.0) = 0.15;
uniform float normal_sensitivity : hint_range(0.05, 1.0) = 0.2;
uniform float outline_thickness : hint_range(0.5, 3.0) = 1.0;

uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;
uniform vec4 tintColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tintStrength = 0.0;

float GetLinearDepth(vec2 sUV, sampler2D depthTexture, mat4 invProjectionMat) {
    float depth = texture(depthTexture, sUV).x;
    vec3 ndc = vec3(sUV * 2.0 - 1.0, depth);
    vec4 view = invProjectionMat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return -view.z;
}

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

void fragment() {
    vec2 texelSize = outline_thickness / VIEWPORT_SIZE.xy;

    float depth = GetLinearDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
    float depthScale = clamp(depth / 15.0, 1.0, 2.0);
    vec2 scaledTexel = texelSize * depthScale;

    vec2 UVOffsets[4];
    UVOffsets[0] = SCREEN_UV + vec2(0.0, -1.0) * scaledTexel;
    UVOffsets[1] = SCREEN_UV + vec2(0.0, 1.0) * scaledTexel;
    UVOffsets[2] = SCREEN_UV + vec2(1.0, 0.0) * scaledTexel;
    UVOffsets[3] = SCREEN_UV + vec2(-1.0, 0.0) * scaledTexel;

    float depthDifference = 0.0;
    float normalDifference = 0.0;
    
    vec3 normal = texture(NORMAL_TEXTURE, SCREEN_UV).rgb * 2.0 - 1.0;
    float safeDepth = depth + 0.0001;

    for (int i = 0; i < 4; i++) {
        float dOff = GetLinearDepth(UVOffsets[i], DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
        float relativeDiff = (dOff - depth) / safeDepth;
        depthDifference += clamp(relativeDiff, 0.0, 1.0);

        vec3 nOff = texture(NORMAL_TEXTURE, UVOffsets[i]).rgb * 2.0 - 1.0;
        normalDifference += (1.0 - dot(normal, nOff));
    }

    float depthEdge = smoothstep(depth_sensitivity, depth_sensitivity * 2.0, depthDifference);
    float normalEdge = smoothstep(normal_sensitivity, normal_sensitivity * 2.0, normalDifference);

    float innerLines = clamp(normalEdge - depthEdge, 0.0, 1.0);
    
    ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    ALBEDO += innerLines * lineHighlight;

    vec3 shadowTarget = tintColor.rgb * 0.15;
    ALBEDO = mix(ALBEDO, shadowTarget, depthEdge * lineShadow);
    ALBEDO = mix(ALBEDO, ALBEDO * tintColor.rgb, tintStrength);
}