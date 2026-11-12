// Block outline and debug lines. Core profile: Iris feeds lines as quads and
// the shader has to widen them itself, like vanilla's rendertype_lines.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

in vec3 vaPosition;
in vec4 vaColor;
in vec3 vaNormal;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec4 glcolor;

const float VIEW_SHRINK = 1.0 - 1.0 / 256.0;
const float LINE_WIDTH = 1.5;   // in render pixels

void main() {
    vec4 start = projectionMatrix * vec4((modelViewMatrix * vec4(vaPosition, 1.0)).xyz * VIEW_SHRINK, 1.0);
    vec4 end = projectionMatrix * vec4((modelViewMatrix * vec4(vaPosition + vaNormal, 1.0)).xyz * VIEW_SHRINK, 1.0);

    vec3 ndcStart = start.xyz / start.w;
    vec3 ndcEnd = end.xyz / end.w;

    vec2 renderSize = vec2(viewWidth, viewHeight) * RENDER_SCALE;
    vec2 dir = normalize((ndcEnd.xy - ndcStart.xy) * renderSize);
    vec2 offset = vec2(-dir.y, dir.x) * LINE_WIDTH / renderSize;
    if (offset.x < 0.0) offset = -offset;
    if (gl_VertexID % 2 != 0) offset = -offset;

    glcolor = vaColor;
    gl_Position = vec4((ndcStart + vec3(offset, 0.0)) * start.w, start.w);
    applyRenderScale(gl_Position);
}
