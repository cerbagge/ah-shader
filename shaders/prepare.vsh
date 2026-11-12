#version 330 compatibility
#define VSH

#include "/lib/settings.glsl"

// Covers only the render area (lower-left RENDER_SCALE portion of the screen).

void main() {
    gl_Position = ftransform();
    gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0);
}
