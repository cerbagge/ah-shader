#version 430
#define CSH

// Spreads the recorded light sources through the voxel grid, one block per
// frame. Walls stop the light and stained glass colors it.
//
// lightImg (rgba16f), all four lose a fixed share per block (LPV_FALLOFF):
//   rgb: color of the light, times its weight (the emitted light level)
//   a:   brightness setting of its source, times the same weight.
//        a / max(r, g, b) gives back the brightness setting of the nearest source.
// extraImg (rg16f):
//   r:   light level the pack adds on its own, 1.0 = LEVEL_SCALE levels. It drops by one
//        level per block like the game's. Used for a longer range and for glowing blocks.
//   g:   how many levels to take off the game's light (shorter range), times the weight.

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(8, 4, 8);    // 64 x 32 x 64 voxels = LPV_SIZE

writeonly uniform image3D lightImgA;
writeonly uniform image3D lightImgB;
writeonly uniform image3D extraImgA;
writeonly uniform image3D extraImgB;
uniform sampler3D lightSamplerA;
uniform sampler3D lightSamplerB;
uniform sampler3D extraSamplerA;
uniform sampler3D extraSamplerB;
uniform sampler3D voxelSampler;

// Indexed by light group (block id - 10010, see block.properties). All are options.
const vec3 LIGHT_COLORS[9] = vec3[9](
    vec3(LIGHT_COLOR_TORCH_R, LIGHT_COLOR_TORCH_G, LIGHT_COLOR_TORCH_B),            // torches, lanterns, fire
    vec3(LIGHT_COLOR_LAVA_R, LIGHT_COLOR_LAVA_G, LIGHT_COLOR_LAVA_B),               // lava
    vec3(LIGHT_COLOR_SOUL_R, LIGHT_COLOR_SOUL_G, LIGHT_COLOR_SOUL_B),               // soul fire
    vec3(LIGHT_COLOR_REDSTONE_R, LIGHT_COLOR_REDSTONE_G, LIGHT_COLOR_REDSTONE_B),   // redstone
    vec3(LIGHT_COLOR_GLOWSTONE_R, LIGHT_COLOR_GLOWSTONE_G, LIGHT_COLOR_GLOWSTONE_B),// glowstone
    vec3(LIGHT_COLOR_SEA_R, LIGHT_COLOR_SEA_G, LIGHT_COLOR_SEA_B),                  // sea lantern, end rod
    vec3(LIGHT_COLOR_PORTAL_R, LIGHT_COLOR_PORTAL_G, LIGHT_COLOR_PORTAL_B),         // portal, amethyst
    vec3(LIGHT_COLOR_GREEN_R, LIGHT_COLOR_GREEN_G, LIGHT_COLOR_GREEN_B),            // green lights
    vec3(LIGHT_COLOR_FRAME_R, LIGHT_COLOR_FRAME_G, LIGHT_COLOR_FRAME_B)             // end portal frame
);
const float LIGHT_BRIGHTNESS[9] = float[9](
    LIGHT_BRIGHTNESS_TORCH, LIGHT_BRIGHTNESS_LAVA, LIGHT_BRIGHTNESS_SOUL, LIGHT_BRIGHTNESS_REDSTONE, LIGHT_BRIGHTNESS_GLOWSTONE,
    LIGHT_BRIGHTNESS_SEA, LIGHT_BRIGHTNESS_PORTAL, LIGHT_BRIGHTNESS_GREEN, LIGHT_BRIGHTNESS_FRAME
);
// Blocks added to (or taken off) the distance the light reaches. The end portal frame
// gives no light in the game: its whole range is GLOW_LIGHT_LEVEL.
const float LIGHT_RANGE[9] = float[9](
    LIGHT_RANGE_TORCH, LIGHT_RANGE_LAVA, LIGHT_RANGE_SOUL, LIGHT_RANGE_REDSTONE, LIGHT_RANGE_GLOWSTONE,
    LIGHT_RANGE_SEA, LIGHT_RANGE_PORTAL, LIGHT_RANGE_GREEN, 0.0
);
const int GROUP_FRAME = 8;

vec4 previousLight(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, LPV_SIZE))) return vec4(0.0);
    return frameCounter % 2 == 0 ? texelFetch(lightSamplerB, pos, 0) : texelFetch(lightSamplerA, pos, 0);
}

vec2 previousExtra(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, LPV_SIZE))) return vec2(0.0);
    return frameCounter % 2 == 0 ? texelFetch(extraSamplerB, pos, 0).rg : texelFetch(extraSamplerA, pos, 0).rg;
}

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID);

    vec4 cell = texelFetch(voxelSampler, pos, 0);
    int kind = int(cell.a * 4.0 + 0.5);     // VOXEL_* in lib/common.glsl

    vec4 light = vec4(0.0);
    vec2 extra = vec2(0.0);
    if (kind != 1) {
        // The grid follows the camera in whole blocks
        ivec3 prev = pos + ivec3(floor(cameraPosition)) - ivec3(floor(previousCameraPosition));

        light = max(max(previousLight(prev + ivec3(1, 0, 0)), previousLight(prev - ivec3(1, 0, 0))),
                max(max(previousLight(prev + ivec3(0, 1, 0)), previousLight(prev - ivec3(0, 1, 0))),
                    max(previousLight(prev + ivec3(0, 0, 1)), previousLight(prev - ivec3(0, 0, 1))))) * LPV_FALLOFF;
        extra = max(max(previousExtra(prev + ivec3(1, 0, 0)), previousExtra(prev - ivec3(1, 0, 0))),
                max(max(previousExtra(prev + ivec3(0, 1, 0)), previousExtra(prev - ivec3(0, 1, 0))),
                    max(previousExtra(prev + ivec3(0, 0, 1)), previousExtra(prev - ivec3(0, 0, 1)))));
        extra = vec2(max(extra.r - 1.0 / LEVEL_SCALE, 0.0), extra.g * LPV_FALLOFF);

        if (kind == 2) {
            // The strongest color gets through in full, so tinted light stays as bright
            // as the light that went around the glass and is not drowned out by it
            vec3 tint = pow(cell.rgb, vec3(1.5 * GLASS_TINT_STRENGTH));
            tint /= max(tint.r, max(tint.g, tint.b));
            float before = max(light.r, max(light.g, light.b));
            light.rgb *= tint;
            // The weighted values have to shrink with the color, or dividing by it would overstate them
            float kept = max(light.r, max(light.g, light.b)) / max(before, 0.0000001);
            light.a *= kept;
            extra.g *= kept;
        } else if (kind == 4) {
            int group = clamp(int(cell.r * 16.0), 0, 8);
            float emitted = group == GROUP_FRAME ? GLOW_LIGHT_LEVEL : cell.g * 15.0;    // light level, 0-15
            float weight = emitted / 15.0;
            // Only the hue of the color setting counts: its largest part is taken as 1
            vec3 color = LIGHT_COLORS[group];
            color /= max(max(color.r, color.g), max(color.b, 0.01));

            light.rgb = max(light.rgb, color * weight);
            light.a = max(light.a, LIGHT_BRIGHTNESS[group] * weight);

            float range = LIGHT_RANGE[group];
            if (group == GROUP_FRAME) {
                extra.r = max(extra.r, emitted / LEVEL_SCALE);
            } else if (range > 0.0) {
                extra.r = max(extra.r, (emitted + range) / LEVEL_SCALE);
            } else if (range < 0.0) {
                extra.g = max(extra.g, -range / RANGE_CUT_SCALE * weight);
            }
        }
    }

    if (frameCounter % 2 == 0) {
        imageStore(lightImgA, pos, light);
        imageStore(extraImgA, pos, vec4(extra, 0.0, 0.0));
    } else {
        imageStore(lightImgB, pos, light);
        imageStore(extraImgB, pos, vec4(extra, 0.0, 0.0));
    }
}
