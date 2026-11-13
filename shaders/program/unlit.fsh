// Unlit geometry. Also used by the core-profile line program, so no
// compatibility built-ins here.
// Defines: BASIC (no texture), SKYBASIC, SKYTEXTURED, CLOUDS, RAW (keep vanilla colors)

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifndef BASIC
uniform sampler2D gtexture;
in vec2 texcoord;
#endif
in vec4 glcolor;
#ifdef CLOUDS
in vec3 viewPos;
// The fog range the game sets while it draws the clouds
uniform float fogStart;
uniform float fogEnd;
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 fragColor;

void main() {
    discardOutsideRenderArea();

    vec4 color = glcolor;

#ifdef SKYBASIC
    // The sky gradient itself is drawn by the prepare pass.
    // Only stars and the sunrise/sunset glow are kept from vanilla.
    if (renderStage == MC_RENDER_STAGE_STARS) {
        color.rgb *= STAR_BRIGHTNESS;
    } else if (renderStage != MC_RENDER_STAGE_SUNSET) {
        discard;
    }
#endif

#ifndef BASIC
    color *= texture(gtexture, texcoord);
#endif
    if (color.a < alphaTestRef) discard;

#ifndef RAW
    color.rgb = srgbToLinear(color.rgb);
#endif
#ifdef SKYTEXTURED
    color.rgb *= CELESTIAL_BRIGHTNESS;
#endif
#ifdef CLOUDS
    // The vertex color already follows the time of day and the weather
    color.rgb *= CLOUD_BRIGHTNESS;
    color.a *= CLOUD_OPACITY;
    // Far clouds fade out instead of ending in a hard edge
    if (fogEnd > fogStart) color.a *= 1.0 - smoothstep(fogStart, fogEnd, length(viewPos));
#endif

    fragColor = color;
}
