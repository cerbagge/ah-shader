#version 330 compatibility
#ifdef IRIS_FEATURE_CUSTOM_IMAGES
#extension GL_ARB_shader_image_load_store : enable
#endif
#define VSH

// Shadow map pass. Also records nearby blocks into a small voxel grid: light
// sources, walls and tinting blocks such as stained glass. shadowcomp.csh
// turns that grid into colored block light.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;

in vec4 mc_Entity;

#ifdef USE_COLORED_LIGHTS
in vec4 at_midBlock;    // xyz: vertex -> block center in 1/64 blocks, w: light level (0-15)
writeonly uniform image3D voxelImg;

// Indexed by block id - 10030: stained glass in dye order, then ice, slime, honey.
// The share of each color that gets through. Kept mild on purpose: light also
// finds its way around the glass, and a strong tint would lose out to that.
const vec3 TINT_COLORS[19] = vec3[19](
    vec3(1.00, 1.00, 1.00), vec3(0.85, 0.50, 0.20), vec3(0.70, 0.30, 0.85), vec3(0.40, 0.60, 0.85),
    vec3(0.90, 0.90, 0.20), vec3(0.50, 0.80, 0.10), vec3(0.95, 0.50, 0.65), vec3(0.30, 0.30, 0.30),
    vec3(0.60, 0.60, 0.60), vec3(0.30, 0.50, 0.60), vec3(0.50, 0.25, 0.70), vec3(0.20, 0.30, 0.70),
    vec3(0.40, 0.30, 0.20), vec3(0.40, 0.50, 0.20), vec3(0.60, 0.20, 0.20), vec3(0.10, 0.10, 0.10),
    vec3(0.70, 0.85, 1.00), vec3(0.50, 0.90, 0.40), vec3(1.00, 0.70, 0.25)
);
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    vec4 shadowView = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * shadowView;
    gl_Position.xy = shadowDistort(gl_Position.xy);
    gl_Position.z *= SHADOW_Z_SCALE;

#ifdef USE_COLORED_LIGHTS
    int id = int(mc_Entity.x + 0.5);
    vec4 cell = vec4(0.0);
    if (id >= 10010 && id <= 10018) {
        // Light sources: which group (its color, brightness and range are looked up in
        // shadowcomp.csh) and the light level the block gives off. 10018 is the end
        // portal frame, which only glows with this pack.
        float level = at_midBlock.w >= 1.0 && at_midBlock.w <= 15.0 ? at_midBlock.w / 15.0 : 1.0;
        cell = vec4((float(id - 10010) + 0.5) / 16.0, level, 0.0, VOXEL_LIGHT);
    } else if (id >= 10030 && id <= 10048) {
        cell = vec4(TINT_COLORS[id - 10030], VOXEL_TINT);
    } else if (gl_VertexID % 4 == 0 && id < 10000 && all(greaterThan(abs(at_midBlock.xyz), vec3(31.5)))) {
        // A vertex on a corner of its block: a full cube, or close enough (slabs, stairs).
        // Thin blocks that would pass this test are listed under id 10020.
        // Entities have no at_midBlock and never get here.
        // One vertex per face is enough, and writing from all four cost about 1 ms per frame.
        cell = vec4(0.0, 0.0, 0.0, VOXEL_WALL);
    }
    if (cell.a > 0.0) {
        vec3 playerPos = (shadowModelViewInverse * shadowView).xyz;
        ivec3 voxel = ivec3(floor(playerPos + at_midBlock.xyz / 64.0 + fract(cameraPosition))) + LPV_SIZE / 2;
        if (all(greaterThanEqual(voxel, ivec3(0))) && all(lessThan(voxel, LPV_SIZE))) {
            imageStore(voxelImg, voxel, cell);
        }
    }
#endif

#ifdef SHADOWS
    // Water never casts a shadow
    if (mc_Entity.x == 10001.0) gl_Position = vec4(-10.0, -10.0, -10.0, 1.0);
#else
    // The pass only runs to fill the voxel grid
    gl_Position = vec4(-10.0, -10.0, -10.0, 1.0);
#endif
}
