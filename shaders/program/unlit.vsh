// Unlit geometry: sky, sun/moon, clouds, glint, beacon beams, unlit particles.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifndef BASIC
out vec2 texcoord;
#endif
out vec4 glcolor;
#ifdef CLOUDS
out vec3 viewPos;
#endif

void main() {
#ifndef BASIC
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif
    glcolor = gl_Color;
    gl_Position = ftransform();
#ifdef CLOUDS
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
#endif
    applyRenderScale(gl_Position);
}
