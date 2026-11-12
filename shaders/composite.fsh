#version 330 compatibility
#define FSH

// Temporal upscaling: rebuilds a full-resolution image from the low-resolution,
// jittered render (colortex0) plus the accumulated history (colortex1).
// The history is kept in a compact display-like encoding (see encodeHistory).

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;

in vec2 texcoord;
flat in mat4 reproject;

/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 fragColor;

void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 texel = 1.0 / viewSize;

    // Where this output pixel sits inside the render area, with the jitter undone
    vec2 srcMax = vec2(RENDER_SCALE) - 1.5 * texel;
    vec2 src = min(texcoord * RENDER_SCALE + taaOffset() * texel, srcMax);

    vec3 current = texture(colortex0, src).rgb;
    vec3 n0 = texture(colortex0, min(src + vec2(texel.x, 0.0), srcMax)).rgb;
    vec3 n1 = texture(colortex0, src - vec2(texel.x, 0.0)).rgb;
    vec3 n2 = texture(colortex0, min(src + vec2(0.0, texel.y), srcMax)).rgb;
    vec3 n3 = texture(colortex0, src - vec2(0.0, texel.y)).rgb;
    vec3 minColor = min(current, min(min(n0, n1), min(n2, n3)));
    vec3 maxColor = max(current, max(max(n0, n1), max(n2, n3)));

    // Sharpen the incoming sample with the neighbors already fetched (no extra
    // texture reads). Clamped to the neighborhood so edges do not ring.
    current = clamp(current + (current * 4.0 - (n0 + n1 + n2 + n3)) * (SHARPENING * 0.35), minColor, maxColor);

    minColor = encodeHistory(minColor);
    maxColor = encodeHistory(maxColor);
    current = encodeHistory(current);

    // Reproject into the previous frame. The hand (depth < 0.56) moves with the camera.
    float depth = texture(depthtex0, src).r;
    vec2 prevCoord = texcoord;
    if (depth > 0.56) {
        vec4 prevClip = reproject * vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0);
        prevCoord = prevClip.xy / prevClip.w * 0.5 + 0.5;
    }

    // Trust the new frame more when a rendered sample lies close to this pixel,
    // and when the pixel is moving fast (history gets blurry there).
    vec2 toSample = fract(src * viewSize) - 0.5;
    float blend = mix(0.04, 0.2, exp(-3.0 * dot(toSample, toSample)));
    blend = max(blend, min(length((texcoord - prevCoord) * viewSize) * 0.01, 0.3));
    blend = min(blend * TAA_RESPONSE, 1.0);
    if (prevCoord != clamp(prevCoord, 0.0, 1.0)) blend = 1.0;

    vec3 history = clamp(texture(colortex1, prevCoord).rgb, minColor, maxColor);

    // Random rounding: keeps slow accumulation from stalling at 10 bits per channel
    float dither = interleavedGradientNoise(gl_FragCoord.xy + 5.588238 * float(frameCounter % 64)) - 0.5;
    fragColor = vec4(mix(history, current, blend) + dither / 1023.0, 1.0);
}
