// Lit geometry: terrain, water, entities, block entities, hand, lit particles.
// Defines: USE_NORMALS, TERRAIN, WATER, ENTITY

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;
out vec4 lightVar;      // xy: lightmap (block, sky), z: N.L, w: ambient shade
out vec3 viewPos;
out vec3 shadowClip;    // shadow clip space, before distortion
flat out vec3 directColor;
flat out vec3 ambientColor;
#ifdef USE_COLORED_LIGHTS
out vec3 lightCoord;    // position in the colored light grid, 0-1
#endif

#ifdef TERRAIN
in vec4 mc_Entity;
#endif

#ifdef WATER
out vec3 waterNormal;   // world space
out vec2 wavePos;
flat out float isWater;
#endif

void getLightColors(out vec3 direct, out vec3 ambient) {
    vec3 sky = srgbToLinear(skyColor);
    vec3 fog = srgbToLinear(fogColor);

    if (!hasSkylight) {
        // Nether / End: no sun, flat ambient tinted by the dimension fog
        direct = vec3(0.0);
        ambient = (fog * 0.75 + vec3(0.21, 0.20, 0.22)) * AMBIENT_BRIGHTNESS;
        return;
    }

    float sunHeight = sin(sunAngle * 6.2831853);
    vec3 sun = mix(vec3(1.0, 0.45, 0.2), vec3(1.0, 0.94, 0.84), smoothstep(0.0, 0.45, sunHeight)) * (1.4 * SUN_BRIGHTNESS);
    vec3 moon = vec3(0.15, 0.21, 0.36) * MOON_BRIGHTNESS;

    // Fades out at the horizon, where the shadow light switches between sun and moon
    direct = (sunHeight > 0.0 ? sun : moon) * smoothstep(0.0, 0.12, abs(sunHeight)) * (1.0 - 0.9 * rainStrength);
    // Sky color only: the vanilla fog color changes with the view direction at sunrise/sunset
    ambient = (mix(sky, vec3(dot(sky, vec3(0.2126, 0.7152, 0.0722))), 0.5) + vec3(0.018, 0.024, 0.042)) * AMBIENT_BRIGHTNESS;
}

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    vec4 view = gl_ModelViewMatrix * gl_Vertex;
    viewPos = view.xyz;
    gl_Position = gl_ProjectionMatrix * view;

    vec2 lm = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * (32.0 / 30.0), 0.0, 1.0);

    // Particles and weather have no usable normals: light them as facing the sun
    vec3 worldNormal = vec3(0.0, 1.0, 0.0);
    float NdotL = 1.0;
#ifdef USE_NORMALS
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    worldNormal = mat3(gbufferModelViewInverse) * normal;
    NdotL = dot(normal, normalize(shadowLightPosition));
#endif

#ifdef TERRAIN
    // Cross-shaped plants: their quad normals give patchy lighting
    if (mc_Entity.x == 10002.0) {
        worldNormal = vec3(0.0, 1.0, 0.0);
        NdotL = 1.0;
    }
#endif

    getLightColors(directColor, ambientColor);
    if (!hasSkylight) {
        lm.y = 1.0;
        NdotL = 0.0;
    }
    lightVar = vec4(lm, NdotL, 0.75 + 0.25 * worldNormal.y);

    // Shadow position, pushed along the normal by about one shadow texel to avoid acne
    vec3 playerPos = (gbufferModelViewInverse * view).xyz;
    vec3 shadowView = (shadowModelView * vec4(playerPos, 1.0)).xyz;
    vec2 shadowXY = (shadowProjection * vec4(shadowView, 1.0)).xy;
    float texelWorld = 2.0 * shadowDistance / float(shadowMapResolution);
    float distortFactor = length(shadowXY) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
    shadowView += mat3(shadowModelView) * worldNormal * (texelWorld * distortFactor * (SHADOW_SOFTNESS + 1.0) + 0.02);
    shadowClip = (shadowProjection * vec4(shadowView, 1.0)).xyz;

#ifdef USE_COLORED_LIGHTS
    // Half a block off the surface: the cell in front of a block face, not the block itself
    lightCoord = (playerPos + worldNormal * 0.5 + fract(cameraPosition) + vec3(LPV_SIZE / 2)) / vec3(LPV_SIZE);
#endif

#ifdef WATER
    isWater = mc_Entity.x == 10001.0 ? 1.0 : 0.0;
    waterNormal = worldNormal;
    wavePos = playerPos.xz + mod(cameraPosition.xz, 512.0);
#endif

    applyRenderScale(gl_Position);
}
