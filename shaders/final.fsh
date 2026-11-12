#version 330 compatibility
#define FSH

// Tone mapping and output encoding at full resolution.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/*
const int colortex0Format = R11F_G11F_B10F;
const int colortex1Format = RGB10_A2;
const bool colortex1Clear = false;
*/

uniform sampler2D colortex1;

in vec2 texcoord;

layout(location = 0) out vec4 fragColor;

// ACES filmic fit (Krzysztof Narkowicz)
vec3 tonemap(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec3 color = texture(colortex1, texcoord).rgb;

    color = tonemap(decodeHistory(color) * EXPOSURE);
    color = pow(color, vec3(1.0 / 2.2));

    color = mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, SATURATION);
    color = (color - 0.5) * CONTRAST + 0.5;

    color += (interleavedGradientNoise(gl_FragCoord.xy) - 0.5) / 255.0;

    fragColor = vec4(color, 1.0);
}
