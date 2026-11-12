#version 430
#define CSH

// Spreads the recorded light sources through the voxel grid, one block per
// frame, losing brightness with distance. Walls stop the light and stained
// glass colors it.
// rgb: color of block light. Its strength still comes from the vanilla light map.
// a:   light from glowing blocks the vanilla light map does not include.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(8, 4, 8);    // 64 x 32 x 64 voxels = LPV_SIZE

writeonly uniform image3D lightImgA;
writeonly uniform image3D lightImgB;
uniform sampler3D lightSamplerA;
uniform sampler3D lightSamplerB;
uniform sampler3D voxelSampler;

vec4 previousLight(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, LPV_SIZE))) return vec4(0.0);
    return frameCounter % 2 == 0 ? texelFetch(lightSamplerB, pos, 0) : texelFetch(lightSamplerA, pos, 0);
}

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID);

    vec4 cell = texelFetch(voxelSampler, pos, 0);
    int kind = int(cell.a * 4.0 + 0.5);     // VOXEL_* in lib/common.glsl

    vec4 light = vec4(0.0);
    if (kind != 1) {
        // The grid follows the camera in whole blocks
        ivec3 prev = pos + ivec3(floor(cameraPosition)) - ivec3(floor(previousCameraPosition));

        light = max(max(previousLight(prev + ivec3(1, 0, 0)), previousLight(prev - ivec3(1, 0, 0))),
                max(max(previousLight(prev + ivec3(0, 1, 0)), previousLight(prev - ivec3(0, 1, 0))),
                    max(previousLight(prev + ivec3(0, 0, 1)), previousLight(prev - ivec3(0, 0, 1))))) * LPV_FALLOFF;

        if (kind == 2) {
            // The strongest color gets through in full, so tinted light stays as bright
            // as the light that went around the glass and is not drowned out by it
            vec3 tint = pow(cell.rgb, vec3(1.5 * GLASS_TINT_STRENGTH));
            light.rgb *= tint / max(tint.r, max(tint.g, tint.b));
        } else if (kind == 3) {
            light = max(light, vec4(cell.rgb, 1.0));
        } else if (kind == 4) {
            light.rgb = max(light.rgb, cell.rgb);
        }
    }

    if (frameCounter % 2 == 0) {
        imageStore(lightImgA, pos, light);
    } else {
        imageStore(lightImgB, pos, light);
    }
}
