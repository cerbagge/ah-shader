#version 330 compatibility
#define FSH

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 color = texture(gtexture, texcoord) * glcolor;
    if (color.a < 0.1) discard;

    // Light let through by stained glass and other translucent blocks.
    // Opaque blocks also write here, but their value is never read.
    fragColor = vec4(mix(vec3(1.0), color.rgb, min(color.a * 1.6, 1.0)), 1.0);
}
