// User-facing options. Screen layout: shaders.properties. Names: lang/*.lang.

// --- Upscaling ---
#define RENDER_SCALE 0.5 // [0.5 0.6 0.67 0.75 0.85 1.0]
#define SHARPENING 0.5 // [0.0 0.25 0.5 0.75 1.0]
#define TAA_RESPONSE 1.0 // [0.5 0.75 1.0 1.5 2.0]

// --- Shadows ---
#define SHADOWS
//#define ENTITY_SHADOWS
#define COLORED_SHADOWS
#define SHADOW_SAMPLES 2 // [1 2 4 8]
#define SHADOW_SOFTNESS 1.5 // [0.5 1.0 1.5 2.0 3.0 4.0]
const int shadowMapResolution = 1024; // [512 1024 1536 2048 3072 4096]
const float shadowDistance = 48.0; // [32.0 48.0 64.0 80.0 96.0 128.0 160.0]
const float sunPathRotation = -25.0; // [-45.0 -35.0 -25.0 -15.0 0.0 15.0 25.0 35.0 45.0]

// --- Lighting ---
#define EXPOSURE 0.6 // [0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2]
#define SUN_BRIGHTNESS 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.35 1.5 2.0]
#define MOON_BRIGHTNESS 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0 3.0]
#define AMBIENT_BRIGHTNESS 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.35 1.5 2.0]
#define BLOCKLIGHT_BRIGHTNESS 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.35 1.5 2.0]
#define MIN_BRIGHTNESS 1.0 // [0.0 0.5 1.0 2.0 4.0 8.0]
//#define NIGHT_VISION_MODE
#define NIGHT_VISION_STRENGTH 0.5 // [0.0 0.25 0.5 0.75 1.0]
#define COLORED_LIGHTS
#define COLORED_LIGHT_STRENGTH 1.0 // [0.25 0.5 0.75 1.0]
#define GLASS_TINT_STRENGTH 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define COLORED_LIGHT_SPREAD 0.6 // [0.0 0.2 0.4 0.6 0.8 1.0]
#define COLORED_LIGHT_FALLOFF 0.6 // [0.5 0.6 0.7 0.8]
#define GLOW_LIGHT_LEVEL 12.0 // [0.0 4.0 6.0 8.0 10.0 12.0 14.0 15.0]

// --- Sky and fog ---
#define SKY_BRIGHTNESS 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.35 1.5]
#define CELESTIAL_BRIGHTNESS 2.0 // [1.0 1.5 2.0 3.0 4.0]
#define STAR_BRIGHTNESS 2.0 // [0.0 1.0 2.0 3.0 4.0]
#define FOG_DENSITY 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define BORDER_FOG_START 0.75 // [0.5 0.6 0.7 0.75 0.8 0.9]
#define UNDERWATER_FOG 1.0 // [0.5 0.75 1.0 1.5 2.0]

// --- Water ---
#define WATER_WAVES
#define WAVE_STRENGTH 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define WAVE_SPEED 1.0 // [0.25 0.5 1.0 1.5 2.0]
#define WATER_REFLECTION 1.0 // [0.0 0.25 0.5 0.75 1.0]
#define SUN_GLINT 1.0 // [0.0 0.5 1.0 1.5 2.0]
#define WATER_OPACITY 1.0 // [0.5 0.75 1.0 1.25 1.5]

// --- Color ---
#define SATURATION 1.0 // [0.0 0.5 0.75 0.9 1.0 1.1 1.25 1.5]
#define CONTRAST 1.0 // [0.8 0.9 1.0 1.1 1.2]

// ENTITY_SHADOWS is only read by shaders.properties; referenced here so it is listed as an option
#ifdef ENTITY_SHADOWS
#endif

// Colored block light writes images from the shadow pass and runs a compute
// shader (OpenGL 4.3 features). Where Iris reports them as unsupported, such
// as on macOS (OpenGL 4.1), it is left out and block light keeps its default color.
#ifdef COLORED_LIGHTS
#if defined IRIS_FEATURE_CUSTOM_IMAGES && defined IRIS_FEATURE_COMPUTE_SHADERS
#define USE_COLORED_LIGHTS 1
#endif
#endif

// --- Fixed directives ---
const float shadowDistanceRenderMul = 1.0;
const bool shadowHardwareFiltering = true;
// Chunks this close are always drawn in the shadow pass, so their light sources get recorded
const float voxelDistance = 32.0;

// --- Internal tuning ---
#define SHADOW_DISTORT 0.9
#define SHADOW_Z_SCALE 0.5
