// Shared uniforms and helpers.
// Keep this file free of compatibility-profile built-ins: the core-profile
// line program includes it too. Stage-specific code is guarded by VSH / FSH,
// which every program defines before including anything.

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float sunAngle;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float alphaTestRef;
uniform float nightVision;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int renderStage;
uniform bool hasSkylight;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 shadowLightPosition;
uniform vec4 entityColor;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

// Size of the colored light grid in blocks, centered on the camera.
// Must match the image sizes in shaders.properties and workGroups in shadowcomp.csh.
const ivec3 LPV_SIZE = ivec3(64, 32, 64);
// Share of the light that reaches the next block. Low on purpose: the light spreads
// in all directions, so a detour around a pane of stained glass has to cost enough
// for the tinted light that went straight through it to win.
const float LPV_FALLOFF = COLORED_LIGHT_FALLOFF;

// What a grid cell holds, stored in the alpha of voxelImg (8 bits).
// Written by shadow.vsh, read by shadowcomp.csh as int(alpha * 4 + 0.5).
const float VOXEL_WALL  = 0.25;     // stops light
const float VOXEL_TINT  = 0.5;      // rgb: share of each color that gets through
const float VOXEL_GLOW  = 0.75;     // rgb: color of a light the game itself does not have
const float VOXEL_LIGHT = 1.0;      // rgb: color of a regular light source, scaled by its light level

// Halton(2,3) sequence, centered on 0. Sub-pixel camera jitter in render pixels.
const vec2 TAA_OFFSETS[16] = vec2[16](
    vec2( 0.0000, -0.1667), vec2(-0.2500,  0.1667), vec2( 0.2500, -0.3889), vec2(-0.3750, -0.0556),
    vec2( 0.1250,  0.2778), vec2(-0.1250, -0.2778), vec2( 0.3750,  0.0556), vec2(-0.4375,  0.3889),
    vec2( 0.0625, -0.4630), vec2(-0.1875, -0.1296), vec2( 0.3125,  0.2037), vec2(-0.3125, -0.3519),
    vec2( 0.1875, -0.0185), vec2(-0.0625,  0.3148), vec2( 0.4375, -0.2407), vec2(-0.4688,  0.0926)
);

vec2 taaOffset() {
    return TAA_OFFSETS[frameCounter % 16];
}

vec3 srgbToLinear(vec3 c) {
    return pow(c, vec3(2.2));
}

// The upscaling history is stored in 10 bits per channel: HDR is compressed
// to [0, 1) and given a display-like curve so the bits go where the eye looks.
vec3 encodeHistory(vec3 c) {
    return sqrt(c / (1.0 + c));
}

vec3 decodeHistory(vec3 e) {
    vec3 s = min(e * e, 0.999);
    return s / (1.0 - s);
}

// Gives the shadow map more texels near the player.
vec2 shadowDistort(vec2 xy) {
    return xy / (length(xy) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT));
}

#ifdef VSH
// Jitters the camera by a sub-pixel offset, then squeezes the whole scene into
// the lower-left RENDER_SCALE portion of the framebuffer. The composite pass
// upscales that region back to the full screen.
void applyRenderScale(inout vec4 clipPos) {
    clipPos.xy += taaOffset() * (2.0 / (vec2(viewWidth, viewHeight) * RENDER_SCALE)) * clipPos.w;
    clipPos.xy = clipPos.xy * RENDER_SCALE + clipPos.w * (RENDER_SCALE - 1.0);
}
#endif

#ifdef FSH
// Geometry that was outside the original view now lands outside the render
// area instead of being clipped, so it has to be dropped here.
void discardOutsideRenderArea() {
    if (any(greaterThan(gl_FragCoord.xy, vec2(viewWidth, viewHeight) * RENDER_SCALE + 1.0))) discard;
}

float interleavedGradientNoise(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Vanilla sky and fog colors already follow time, weather and biome.
vec3 calcSkyColor(vec3 viewDir) {
    if (isEyeInWater != 0) return srgbToLinear(fogColor) * SKY_BRIGHTNESS;
    float up = max(dot(viewDir, gbufferModelView[1].xyz), 0.0);
    float horizon = 0.25 / (up * up + 0.25);
    return srgbToLinear(mix(skyColor, fogColor, horizon)) * SKY_BRIGHTNESS;
}
#endif
