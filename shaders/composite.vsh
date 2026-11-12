#version 330 compatibility
#define VSH

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out mat4 reproject;    // current NDC -> previous frame clip space

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();

    // Built once per vertex so the fragment shader needs a single matrix multiply
    mat4 cameraMotion = mat4(1.0);
    cameraMotion[3].xyz = cameraPosition - previousCameraPosition;
    reproject = gbufferPreviousProjection * gbufferPreviousModelView * cameraMotion
              * gbufferModelViewInverse * gbufferProjectionInverse;
}
