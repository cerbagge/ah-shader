// Lit geometry, forward shaded: one pass, no G-buffer.
// Defines: WATER, ENTITY

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D gtexture;
#ifdef SHADOWS
uniform sampler2DShadow shadowtex1;     // opaque casters only
#ifdef COLORED_SHADOWS
uniform sampler2DShadow shadowtex0;     // opaque and translucent casters
uniform sampler2D shadowcolor0;
#endif
#endif
#ifdef USE_COLORED_LIGHTS
uniform sampler3D lightSamplerA;
uniform sampler3D lightSamplerB;
#endif

in vec2 texcoord;
in vec4 glcolor;
in vec4 lightVar;
in vec3 viewPos;
in vec3 shadowClip;
flat in vec3 directColor;
flat in vec3 ambientColor;
#ifdef USE_COLORED_LIGHTS
in vec3 lightCoord;
#endif

#ifdef WATER
uniform sampler2D depthtex1;    // depth of everything behind the water
in vec3 waterNormal;
in vec2 wavePos;
flat in float isWater;
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 fragColor;

const vec3 BLOCKLIGHT_COLOR = vec3(1.0, 0.72, 0.45);

// Sunlight reaching this fragment, tinted where it passed through stained glass.
// fallback: visibility used beyond the shadow map, estimated from sky light
vec3 getShadow(float fallback) {
#ifdef SHADOWS
    float edge = length(shadowClip.xy);
    if (edge >= 1.0) return vec3(fallback);

    vec3 pos = vec3(shadowDistort(shadowClip.xy), shadowClip.z * SHADOW_Z_SCALE) * 0.5 + 0.5;
    pos.z -= 0.00012;

    // Rotated disk, different every frame: temporal accumulation smooths it out
    float radius = SHADOW_SOFTNESS / float(shadowMapResolution);
    float angle = interleavedGradientNoise(gl_FragCoord.xy + 5.588238 * float(frameCounter % 64)) * 6.2831853;
    float sum = 0.0;        // not blocked by opaque casters
    float sumAll = 0.0;     // not blocked by anything
    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        float r = sqrt((float(i) + 0.5) / float(SHADOW_SAMPLES)) * radius;
        float a = float(i) * 2.3999632 + angle;
        vec3 tap = vec3(pos.xy + r * vec2(cos(a), sin(a)), pos.z);
        sum += texture(shadowtex1, tap);
#ifdef COLORED_SHADOWS
        // Same taps for both maps, so they only differ where a translucent block is in the way
        sumAll += texture(shadowtex0, tap);
#endif
    }
    vec3 light = vec3(sum / float(SHADOW_SAMPLES));

#ifdef COLORED_SHADOWS
    // Blocked by something translucent but not by anything opaque: colored light
    float unblocked = sumAll / float(SHADOW_SAMPLES);
    if (unblocked < light.r) {
        vec3 tint = srgbToLinear(texture(shadowcolor0, pos.xy).rgb);
        light = vec3(unblocked) + (light.r - unblocked) * tint;
    }
#endif

    return mix(light, vec3(fallback), smoothstep(0.85, 1.0, edge));
#else
    return vec3(fallback);
#endif
}

#ifdef USE_COLORED_LIGHTS
// Block light around this fragment, from the light grid.
// rgb: its color. Falls back to the default warm color where the grid has nothing.
// a:   light level (0-1) from glowing blocks the vanilla light map does not include.
vec4 getGridLight() {
    vec3 border = min(lightCoord, 1.0 - lightCoord);
    float inside = min(border.x, min(border.y, border.z));
    if (inside <= 0.0) return vec4(BLOCKLIGHT_COLOR, 0.0);

    vec4 light = frameCounter % 2 == 0 ? texture(lightSamplerA, lightCoord) : texture(lightSamplerB, lightCoord);
    float fade = smoothstep(0.0, 0.08, inside);
    float peak = max(light.r, max(light.g, light.b));
    // Fades out where the light has travelled about as far as block light reaches
    float reach = pow(LPV_FALLOFF, 14.0);
    float weight = smoothstep(0.1 * reach, reach, peak) * fade * COLORED_LIGHT_STRENGTH;

    // The grid loses a fixed share per block: turn that back into a distance in
    // blocks, then into a light level that drops by one per block like the game's.
    float dist = log(max(light.a, 0.0000001)) / log(LPV_FALLOFF);
    float level = clamp((GLOW_LIGHT_LEVEL - dist) / 15.0, 0.0, 1.0) * fade;

    return vec4(mix(BLOCKLIGHT_COLOR, light.rgb / max(peak, 0.000001), weight), level);
}
#endif

vec3 applyFog(vec3 color) {
    float dist = length(viewPos);
    vec3 dir = viewPos / dist;

    float amount;
    if (isEyeInWater == 1) {
        amount = 1.0 - exp(-dist * (0.06 * UNDERWATER_FOG));
    } else if (isEyeInWater >= 2) {
        amount = 1.0 - exp(-dist * 0.8);
    } else {
        float border = smoothstep(BORDER_FOG_START * far, far, dist);
        float haze = 0.6 * (1.0 - exp(-dist * ((0.0012 + 0.004 * rainStrength) * FOG_DENSITY)));
        amount = max(border, haze);
    }
    return mix(color, calcSkyColor(dir), amount);
}

void main() {
    discardOutsideRenderArea();

    vec4 color = texture(gtexture, texcoord) * glcolor;
    if (color.a < alphaTestRef) discard;
#ifdef ENTITY
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif
    color.rgb = srgbToLinear(color.rgb);

    vec2 lm = lightVar.xy;
    float NdotL = lightVar.z;
    vec3 shadow = NdotL > 0.0 ? getShadow(smoothstep(0.6, 0.95, lm.y)) : vec3(0.0);

    vec3 blockColor = BLOCKLIGHT_COLOR;
    float blockLevel = lm.x;
#ifdef USE_COLORED_LIGHTS
    vec4 gridLight = getGridLight();
    blockColor = gridLight.rgb;
    blockLevel = max(blockLevel, gridLight.a);
#endif

    vec3 blockLight = blockColor * ((blockLevel * blockLevel * blockLevel * 2.4 + blockLevel * 0.18) * BLOCKLIGHT_BRIGHTNESS);
    vec3 light = ambientColor * (lm.y * lm.y * lightVar.w)
               + directColor * (max(NdotL, 0.0) * shadow)
               + vec3(0.018 * MIN_BRIGHTNESS);
    // Night vision lifts dark areas only: the darker the place, the more it adds
#ifdef NIGHT_VISION_MODE
    float nightVisionAmount = 1.0;      // always on, with or without the potion effect
#else
    float nightVisionAmount = nightVision;
#endif
    float brightness = dot(light + blockLight, vec3(0.2126, 0.7152, 0.0722));
    light += (NIGHT_VISION_STRENGTH * nightVisionAmount) / (1.0 + 20.0 * brightness * brightness);

    vec3 blockAlbedo = color.rgb;
#ifdef USE_COLORED_LIGHTS
    // A surface only shows the part of the light that matches its own color: red
    // light on green grass would be nearly black. Where block light is far from
    // its usual warm color, treat the surface as partly gray so the color shows.
    float spread = smoothstep(0.15, 0.6, distance(blockColor, BLOCKLIGHT_COLOR)) * COLORED_LIGHT_SPREAD;
    blockAlbedo = mix(blockAlbedo, vec3(dot(blockAlbedo, vec3(0.2126, 0.7152, 0.0722))), spread);
#endif
    color.rgb = color.rgb * light + blockAlbedo * blockLight;

#ifdef WATER
    if (isWater > 0.5 && isEyeInWater == 0) {
        vec3 N = waterNormal;
#ifdef WATER_WAVES
        if (N.y > 0.9) {
            // Analytic slope of three sine waves
            float t = frameTimeCounter * WAVE_SPEED;
            vec2 slope = vec2( 0.80,  0.60) * (0.045 * cos(dot(wavePos, vec2( 0.80,  0.60)) * 1.1 + t * 1.3))
                       + vec2(-0.55,  0.83) * (0.035 * cos(dot(wavePos, vec2(-0.55,  0.83)) * 2.3 + t * 1.9))
                       + vec2( 0.30, -0.95) * (0.025 * cos(dot(wavePos, vec2( 0.30, -0.95)) * 4.1 + t * 2.6));
            slope *= WAVE_STRENGTH;
            N = normalize(vec3(-slope.x, 1.0, -slope.y));
        }
#endif
        vec3 viewN = mat3(gbufferModelView) * N;
        vec3 V = normalize(-viewPos);
        vec3 R = reflect(-V, viewN);
        float fresnel = (0.02 + 0.98 * pow(1.0 - max(dot(viewN, V), 0.0), 5.0)) * WATER_REFLECTION;

        // Sky reflection only: no screen-space ray march
        vec3 reflection = calcSkyColor(R) * smoothstep(0.3, 0.9, lm.y);
        float highlight = pow(max(dot(R, normalize(shadowLightPosition)), 0.0), 400.0);

        // The further the view ray travels through water before it hits something,
        // the less of that shows: shallow water is clear, deep water hides the bottom.
        float sceneDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
        float behind = 1.0 / (gbufferProjectionInverse[2][3] * (sceneDepth * 2.0 - 1.0) + gbufferProjectionInverse[3][3]);
        float through = max(behind + viewPos.z, 0.0) * (length(viewPos) / -viewPos.z);
        color.a = 1.0 - exp(-(through + 0.4) * (0.45 * WATER_OPACITY));
        color.rgb = mix(color.rgb, reflection, fresnel) + directColor * shadow * (highlight * 6.0 * SUN_GLINT);
        color.a = mix(color.a, 1.0, fresnel);
    }
#endif

    color.rgb = applyFog(color.rgb);
    fragColor = color;
}
