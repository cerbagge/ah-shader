#version 330 compatibility
#define FSH

// Paints the sky gradient into the render area before any geometry is drawn.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 fragColor;

void main() {
    vec2 coord = gl_FragCoord.xy / (vec2(viewWidth, viewHeight) * RENDER_SCALE);
    vec4 view = gbufferProjectionInverse * vec4(coord * 2.0 - 1.0, 1.0, 1.0);
    fragColor = vec4(calcSkyColor(normalize(view.xyz / view.w)), 1.0);
}
