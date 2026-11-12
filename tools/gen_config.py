# Generates shaders.properties, block.properties and the lang files.
import io, os, re
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'shaders'))

def write(path, text):
    io.open(path, 'w', encoding='utf-8', newline='\n').write(text)

# ---------------------------------------------------------------- option table
# (screen, option, kind, ko name, ko comment, en name, en comment)
# kind: bool | pct (value shown as percent) | fmt:<suffix ko>|<suffix en> | raw
OPTIONS = [
 ('UPSCALING', 'RENDER_SCALE', 'pct', '렌더 배율',
  '내부 렌더링 해상도의 배율입니다. 낮을수록 그려야 하는 픽셀이 줄어들고, 시간적 업스케일링으로 화면 해상도까지 복원합니다. 50%는 가로세로 각각 절반 해상도입니다.',
  'Render Scale', 'Internal rendering resolution. Lower is faster; temporal upscaling reconstructs the image at screen resolution.'),
 ('UPSCALING', 'SHARPENING', 'pct', '선명도',
  '업스케일 과정에서 적용하는 선명화 강도입니다. 0%로 설정하면 선명화를 하지 않습니다.',
  'Sharpening', 'Sharpening strength applied while upscaling. 0% disables it.'),
 ('UPSCALING', 'TAA_RESPONSE', 'pct', '화면 반응 속도',
  '새 프레임을 화면에 반영하는 속도입니다. 높이면 움직일 때 잔상이 줄어들지만 화면이 조금 거칠어지고, 낮추면 화면이 부드러워지지만 잔상이 늘어납니다.',
  'Temporal Response', 'How quickly new frames replace the accumulated image. Higher reduces ghosting but adds noise.'),

 ('SHADOWS', 'SHADOWS', 'bool', '그림자',
  '태양과 달의 그림자를 켭니다. 끄면 그림자를 그리지 않으므로 fps가 높아집니다.',
  'Shadows', 'Sun and moon shadows. Turning this off is faster.'),
 ('SHADOWS', 'ENTITY_SHADOWS', 'bool', '엔티티 그림자',
  '몹과 아이템 같은 엔티티가 그림자를 드리웁니다. 엔티티를 한 번 더 그리므로 몹이 많은 곳에서 fps가 크게 낮아집니다. 플레이어 그림자는 이 옵션과 관계없이 표시됩니다.',
  'Entity Shadows', 'Mobs and other entities cast shadows. Costly near large mob groups. The player shadow is always drawn.'),
 ('SHADOWS', 'COLORED_SHADOWS', 'bool', '색유리 그림자',
  '색유리, 얼음처럼 반투명한 블록을 통과한 햇빛이 그 블록의 색으로 물듭니다.',
  'Colored Shadows', 'Sunlight passing through stained glass and other translucent blocks takes their color.'),
 ('SHADOWS', 'shadowDistance', 'fmt:블록| blocks', '그림자 거리',
  '그림자를 그리는 거리입니다. 길수록 먼 곳까지 그림자가 생기지만 fps가 낮아집니다.',
  'Shadow Distance', 'Distance covered by shadows. Longer distances cost more.'),
 ('SHADOWS', 'shadowMapResolution', 'raw', '그림자 해상도',
  '그림자 맵의 해상도입니다. 높을수록 그림자 윤곽이 선명해집니다.',
  'Shadow Resolution', 'Shadow map resolution. Higher gives sharper shadow outlines.'),
 ('SHADOWS', 'SHADOW_SAMPLES', 'fmt:회|', '그림자 샘플 수',
  '그림자 가장자리를 부드럽게 만드는 샘플 수입니다. 높을수록 가장자리의 노이즈가 줄어들지만 느려집니다.',
  'Shadow Samples', 'Samples used to soften shadow edges. Higher is smoother but slower.'),
 ('SHADOWS', 'SHADOW_SOFTNESS', 'raw', '그림자 부드러움',
  '그림자 가장자리가 퍼지는 정도입니다. 값이 클수록 가장자리가 흐릿해집니다.',
  'Shadow Softness', 'How far shadow edges are blurred.'),
 ('SHADOWS', 'sunPathRotation', 'fmt:°|°', '태양 경로 기울기',
  '태양과 달이 지나가는 경로를 기울입니다. 0°이면 머리 바로 위를 지나가고, 기울일수록 한낮에도 그림자가 비스듬하게 생깁니다.',
  'Sun Path Rotation', 'Tilts the path of the sun and moon, so shadows stay slanted at noon.'),

 ('LIGHTING', 'EXPOSURE', 'pct', '전체 밝기',
  '화면 전체의 밝기(노출)입니다. 낮 화면이 너무 밝으면 낮추고, 어두우면 높입니다.',
  'Exposure', 'Overall image brightness.'),
 ('LIGHTING', 'SUN_BRIGHTNESS', 'pct', '햇빛 세기',
  '햇빛을 직접 받는 면의 밝기입니다.',
  'Sunlight', 'Brightness of surfaces lit directly by the sun.'),
 ('LIGHTING', 'MOON_BRIGHTNESS', 'pct', '달빛 세기',
  '달빛을 직접 받는 면의 밝기입니다. 밤이 너무 어두우면 높입니다.',
  'Moonlight', 'Brightness of surfaces lit directly by the moon.'),
 ('LIGHTING', 'AMBIENT_BRIGHTNESS', 'pct', '환경광 세기',
  '하늘에서 오는 간접광의 밝기입니다. 높이면 그림자 속이 밝아집니다.',
  'Ambient Light', 'Brightness of indirect light from the sky. Higher makes shadowed areas brighter.'),
 ('LIGHTING', 'BLOCKLIGHT_BRIGHTNESS', 'pct', '블록 조명 세기',
  '횃불, 랜턴 같은 광원 블록이 주변을 밝히는 세기입니다.',
  'Block Light', 'Brightness of light from torches, lanterns and other light sources.'),
 ('LIGHTING', 'MIN_BRIGHTNESS', 'pct', '최소 밝기',
  '빛이 전혀 닿지 않는 곳의 밝기입니다. 0%이면 동굴 속이 완전히 어두워집니다.',
  'Minimum Light', 'Brightness of places no light reaches. 0% makes caves pitch black.'),
 ('LIGHTING', 'NIGHT_VISION_MODE', 'bool', '야간 투시 모드',
  '야간 투시 물약이 없어도 어두운 곳을 항상 밝게 보여 줍니다. 밝히는 정도는 야간 투시 세기로 조절합니다.',
  'Night Vision Mode', 'Always brightens dark areas, without the night vision effect. The amount is set by Night Vision.'),
 ('LIGHTING', 'NIGHT_VISION_STRENGTH', 'pct', '야간 투시 세기',
  '야간 투시 효과 또는 야간 투시 모드가 어두운 곳을 밝히는 정도입니다. 이미 밝은 곳에는 영향을 주지 않습니다.',
  'Night Vision', 'How much the night vision effect or Night Vision Mode brightens dark areas.'),
 ('LIGHTING', 'COLORED_LIGHTS', 'bool', '광원별 조명 색',
  '광원의 종류에 따라 조명 색이 달라집니다. 횃불은 주황색, 영혼 불은 푸른색, 레드스톤은 붉은색으로 주변을 밝힙니다. 색유리를 통과한 조명은 유리 색으로 물들고, 엔드 차원문 틀은 청록색 빛을 냅니다. 플레이어 주변 32블록 안의 광원에 적용됩니다.',
  'Colored Lights', 'Block light takes the color of its source: orange torches, blue soul fire, red redstone. Light passing through stained glass takes its color, and end portal frames glow. Applies within 32 blocks of the player.'),
 ('LIGHTING', 'COLORED_LIGHT_STRENGTH', 'pct', '조명 색 강도',
  '광원별 조명 색이 얼마나 진하게 나타나는지 정합니다. 낮추면 기본 조명 색에 가까워집니다.',
  'Light Color Strength', 'How strongly block light is tinted by its source.'),
 ('LIGHTING', 'GLASS_TINT_STRENGTH', 'pct', '유리 색 진하기',
  '색유리를 통과한 조명이 유리 색으로 물드는 정도입니다. 높일수록 색이 진해지지만, 유리 색과 반대되는 색의 표면은 더 어둡게 보입니다.',
  'Glass Tint', 'How strongly block light is colored by the stained glass it passes through.'),
 ('LIGHTING', 'COLORED_LIGHT_SPREAD', 'pct', '표면 색 반영',
  '색이 강한 조명이 표면에 얼마나 잘 드러나는지 정합니다. 0%이면 빨간 조명이 초록색 풀밭에서 거의 보이지 않고, 높일수록 표면 고유의 색보다 조명 색이 앞섭니다. 횃불 같은 일반 조명에는 영향을 주지 않습니다.',
  'Surface Color Response', 'How clearly strongly colored light shows on surfaces of a different color, such as red light on grass.'),
 ('LIGHTING', 'COLORED_LIGHT_FALLOFF', 'pct', '조명 색 유지율',
  '조명 색이 한 블록을 지날 때마다 남는 비율입니다. 낮출수록 유리를 통과한 색이 바닥에 뚜렷하게 비치고, 높일수록 여러 광원의 색이 넓게 섞이지만 유리 색은 옅어집니다.',
  'Light Color Carry', 'Share of the light color kept per block. Lower makes glass tints stand out; higher blends the colors of several lights over a wider area.'),
 ('LIGHTING', 'GLOW_LIGHT_LEVEL', 'fmt:|', '차원문 틀 밝기',
  '엔드 차원문 틀이 내는 빛의 밝기입니다. 횃불이 14, 발광석이 15에 해당하며, 0으로 설정하면 빛을 내지 않습니다.',
  'Portal Frame Glow', 'Light level given off by end portal frames. 0 turns the glow off.'),

 ('SKY', 'SKY_BRIGHTNESS', 'pct', '하늘 밝기',
  '하늘과 먼 곳의 안개 밝기입니다.',
  'Sky Brightness', 'Brightness of the sky and distant fog.'),
 ('SKY', 'CELESTIAL_BRIGHTNESS', 'pct', '해·달 밝기',
  '해와 달의 밝기입니다. 리소스팩의 하늘 그림에도 함께 적용됩니다.',
  'Sun and Moon', 'Brightness of the sun and moon textures, and of resource pack skies.'),
 ('SKY', 'STAR_BRIGHTNESS', 'pct', '별 밝기',
  '밤하늘 별의 밝기입니다. 0%이면 별이 보이지 않습니다.',
  'Stars', 'Brightness of the stars. 0% hides them.'),
 ('SKY', 'FOG_DENSITY', 'pct', '거리 안개 농도',
  '멀리 있는 지형이 하늘색으로 흐려지는 정도입니다. 0%이면 거리 안개를 사용하지 않습니다.',
  'Distance Haze', 'How much distant terrain fades into the sky color.'),
 ('SKY', 'BORDER_FOG_START', 'pct', '가장자리 안개 시작',
  '렌더 거리의 몇 % 지점부터 지형이 안개 속으로 사라지기 시작하는지 정합니다. 높일수록 지형이 멀리까지 또렷하게 보이지만 청크 경계가 드러날 수 있습니다.',
  'Border Fog Start', 'Where terrain starts fading out, as a fraction of the render distance.'),
 ('SKY', 'UNDERWATER_FOG', 'pct', '물속 안개 농도',
  '물속에서 시야가 흐려지는 정도입니다.',
  'Underwater Fog', 'How quickly visibility drops under water.'),

 ('WATER', 'WATER_WAVES', 'bool', '물결',
  '수면에 물결 모양의 반사를 적용합니다.',
  'Water Waves', 'Wavy reflections on water surfaces.'),
 ('WATER', 'WAVE_STRENGTH', 'pct', '물결 세기',
  '물결이 반사를 일그러뜨리는 정도입니다.',
  'Wave Strength', 'How much the waves distort reflections.'),
 ('WATER', 'WAVE_SPEED', 'pct', '물결 속도',
  '물결이 움직이는 속도입니다.',
  'Wave Speed', 'How fast the waves move.'),
 ('WATER', 'WATER_REFLECTION', 'pct', '하늘 반사 세기',
  '수면에 하늘이 비치는 정도입니다. 0%이면 반사가 없습니다.',
  'Sky Reflection', 'How strongly water reflects the sky.'),
 ('WATER', 'SUN_GLINT', 'pct', '태양 반짝임',
  '수면에 비치는 태양 반사광의 밝기입니다. 0%이면 표시하지 않습니다.',
  'Sun Glint', 'Brightness of the sun highlight on water.'),
 ('WATER', 'WATER_OPACITY', 'pct', '물의 불투명도',
  '물이 얼마나 불투명한지 정합니다. 낮추면 물속 바닥이 더 잘 비쳐 보입니다.',
  'Water Opacity', 'Lower values make the bottom easier to see through the water.'),

 ('COLOR', 'SATURATION', 'pct', '채도',
  '색의 진하기입니다. 0%이면 흑백이 됩니다.',
  'Saturation', 'Color intensity. 0% is black and white.'),
 ('COLOR', 'CONTRAST', 'pct', '대비',
  '밝은 부분과 어두운 부분의 차이입니다.',
  'Contrast', 'Difference between bright and dark areas.'),
]

SCREENS = [
 ('UPSCALING', '업스케일링', '내부 해상도와 화면 복원 방식을 설정합니다. fps에 가장 큰 영향을 주는 항목은 렌더 배율입니다.', 'Upscaling', 'Internal resolution and reconstruction.'),
 ('SHADOWS',   '그림자',     '그림자의 품질과 범위를 설정합니다.', 'Shadows', 'Shadow quality and range.'),
 ('LIGHTING',  '조명',       '햇빛, 달빛, 블록 조명의 밝기와 색을 설정합니다.', 'Lighting', 'Brightness and color of sun, moon and block light.'),
 ('SKY',       '하늘·안개',  '하늘의 밝기와 안개를 설정합니다.', 'Sky and Fog', 'Sky brightness and fog.'),
 ('WATER',     '물',         '수면의 물결과 반사를 설정합니다.', 'Water', 'Waves and reflections.'),
 ('COLOR',     '색감',       '최종 화면의 채도와 대비를 설정합니다.', 'Color', 'Saturation and contrast of the final image.'),
]

# Screens that exist in shaders.properties but are not linked from the main screen, so the
# Iris options screen never shows them. The AH Client menu lists every screen.SCREEN_* entry
# and shows these too; ahclient.screens names them.
HUB_SCREENS = [
 ('LIGHT_COLORS', '광원 색', '광원 종류별 조명 색을 빨강·초록·파랑 값으로 정합니다. AH Client 메뉴에서만 표시됩니다.',
  'Light Colors', 'Red, green and blue of the light from each kind of light source. Shown in the AH Client menu only.'),
]

# (key, ko name, ko blocks, en name, en blocks)
LIGHT_GROUPS = [
 ('TORCH', '횃불류', '횃불, 랜턴, 불, 모닥불, 켜진 화로, 버섯불, 촛불', 'Torches', 'torches, lanterns, fire, campfires, lit furnaces, shroomlights, candles'),
 ('LAVA', '용암', '용암, 마그마 블록, 용암 가마솥', 'Lava', 'lava, magma blocks, lava cauldrons'),
 ('SOUL', '영혼 불', '영혼 횃불, 영혼 랜턴, 영혼 불, 영혼 모닥불', 'Soul Fire', 'soul torches, soul lanterns, soul fire, soul campfires'),
 ('REDSTONE', '레드스톤', '레드스톤 횃불, 켜진 레드스톤 광석', 'Redstone', 'redstone torches, lit redstone ore'),
 ('GLOWSTONE', '발광석', '발광석, 켜진 레드스톤 조명, 황토색 개구리불', 'Glowstone', 'glowstone, lit redstone lamps, ochre froglights'),
 ('SEA', '바다 랜턴', '바다 랜턴, 엔드 막대, 신호기, 전달체', 'Sea Lantern', 'sea lanterns, end rods, beacons, conduits'),
 ('PORTAL', '차원문·자수정', '네더 차원문, 우는 흑요석, 자수정, 진주빛 개구리불, 충전된 리스폰 정박기', 'Portal and Amethyst', 'nether portals, crying obsidian, amethyst, pearlescent froglights, charged respawn anchors'),
 ('GREEN', '초록 광원', '초록 개구리불, 불우렁쉥이, 발광 이끼', 'Green Lights', 'verdant froglights, sea pickles, glow lichen'),
 ('FRAME', '엔드 차원문 틀', '엔드 차원문 틀 (이 쉐이더에서만 빛을 냅니다)', 'End Portal Frame', 'end portal frames (they only glow with this pack)'),
]
for key, ko, ko_blocks, en, en_blocks in LIGHT_GROUPS:
    for ch, ko_ch, en_ch in (('R', '빨강', 'Red'), ('G', '초록', 'Green'), ('B', '파랑', 'Blue')):
        OPTIONS.append(('LIGHT_COLORS', 'LIGHT_COLOR_%s_%s' % (key, ch), 'raw',
                        '%s: %s' % (ko, ko_ch), '%s의 조명 색에서 %s 성분입니다. 대상: %s.' % (ko, ko_ch, ko_blocks),
                        '%s: %s' % (en, en_ch), '%s part of the light color of %s.' % (en_ch, en_blocks)))

# ---------------------------------------------------------------- option values from settings.glsl
settings = io.open('lib/settings.glsl', encoding='utf-8').read()
def values_of(opt):
    m = re.search(r'(?:#define\s+%s\s+\S+|const\s+\w+\s+%s\s*=\s*[^;]+;)\s*//\s*\[([^\]]+)\]' % (opt, opt), settings)
    return m.group(1).split() if m else []

def label(kind, v, lang):
    f = float(v)
    if kind == 'pct':
        return '%d%%' % round(f * 100)
    if kind.startswith('fmt:'):
        ko, en = kind[4:].split('|')
        num = ('%g' % f)
        return num + (ko if lang == 'ko' else en)
    return None

for lang, fname in (('ko', 'lang/ko_kr.lang'), ('en', 'lang/en_us.lang')):
    out = []
    for key, ko, koc, en, enc in SCREENS + HUB_SCREENS:
        out.append('screen.SCREEN_%s=%s' % (key, ko if lang == 'ko' else en))
        out.append('screen.SCREEN_%s.comment=%s' % (key, koc if lang == 'ko' else enc))
    out.append('')
    for screen, opt, kind, ko, koc, en, enc in OPTIONS:
        out.append('option.%s=%s' % (opt, ko if lang == 'ko' else en))
        out.append('option.%s.comment=%s' % (opt, koc if lang == 'ko' else enc))
        if kind != 'bool':
            vals = values_of(opt)
            assert vals, opt
            for v in vals:
                lab = label(kind, v, lang)
                if lab:
                    out.append('value.%s.%s=%s' % (opt, v, lab))
        else:
            assert re.search(r'^(//)?#define %s\s*$' % opt, settings, re.M), opt
    write(fname, '\n'.join(out) + '\n')

# ---------------------------------------------------------------- shaders.properties
by_screen = {}
for screen, opt, kind, *_ in OPTIONS:
    by_screen.setdefault(screen, []).append(opt)
sliders = [opt for screen, opt, kind, *_ in OPTIONS if kind != 'bool']

props = '''# Vanilla effects the pack replaces or does not need
oldLighting=false
separateAo=false
underwaterOverlay=false
vignette=false

# Shadow pass
shadowBlockEntities=false
shadowPlayer=true
blend.shadow=off
#ifdef ENTITY_SHADOWS
shadowEntities=true
#else
shadowEntities=false
#endif
#ifdef COLORED_SHADOWS
shadowTranslucent=true
#else
shadowTranslucent=false
#endif

# Colored block light: a voxel grid around the camera (size = LPV_SIZE in lib/common.glsl).
# The shadow pass records light sources into it, so it has to run even without shadows.
# It needs image writes and a compute shader; where Iris does not support them it is left out.
iris.features.optional=CUSTOM_IMAGES COMPUTE_SHADERS BLOCK_EMISSION_ATTRIBUTE
#if defined COLORED_LIGHTS && defined IRIS_FEATURE_CUSTOM_IMAGES && defined IRIS_FEATURE_COMPUTE_SHADERS
shadow.culling=reversed
image.voxelImg=voxelSampler rgba rgba8 unsigned_byte true false 64 32 64
image.lightImgA=lightSamplerA rgba rgba16f half_float false false 64 32 64
image.lightImgB=lightSamplerB rgba rgba16f half_float false false 64 32 64
program.shadow.enabled=true
program.shadowcomp.enabled=true
#else
program.shadow.enabled=SHADOWS
program.shadowcomp.enabled=false
#endif

# Options screen
screen=%s
screen.columns=2
%s
sliders=%s

# Screens for the AH Client menu only. Nothing links to them, so Iris never shows them.
ahclient.screens=%s
%s
''' % (' '.join('[SCREEN_%s]' % s[0] for s in SCREENS),
       '\n'.join('screen.SCREEN_%s=%s' % (s[0], ' '.join(by_screen[s[0]])) for s in SCREENS),
       ' '.join(sliders),
       ' '.join('SCREEN_%s' % s[0] for s in HUB_SCREENS),
       '\n'.join('screen.SCREEN_%s=%s' % (s[0], ' '.join(by_screen[s[0]])) for s in HUB_SCREENS))
write('shaders.properties', props)

# ---------------------------------------------------------------- block.properties
blocks = '''block.10001=minecraft:water minecraft:flowing_water

# Cross-shaped plants, lit as if facing the sun
block.10002=minecraft:grass minecraft:short_grass minecraft:fern minecraft:tall_grass minecraft:large_fern minecraft:dead_bush \\
 minecraft:dandelion minecraft:poppy minecraft:blue_orchid minecraft:allium minecraft:azure_bluet minecraft:red_tulip minecraft:orange_tulip \\
 minecraft:white_tulip minecraft:pink_tulip minecraft:oxeye_daisy minecraft:cornflower minecraft:lily_of_the_valley minecraft:wither_rose \\
 minecraft:torchflower minecraft:sunflower minecraft:lilac minecraft:rose_bush minecraft:peony minecraft:pitcher_plant \\
 minecraft:oak_sapling minecraft:spruce_sapling minecraft:birch_sapling minecraft:jungle_sapling minecraft:acacia_sapling \\
 minecraft:dark_oak_sapling minecraft:cherry_sapling minecraft:mangrove_propagule \\
 minecraft:wheat minecraft:carrots minecraft:potatoes minecraft:beetroots minecraft:sweet_berry_bush minecraft:sugar_cane \\
 minecraft:melon_stem minecraft:pumpkin_stem minecraft:attached_melon_stem minecraft:attached_pumpkin_stem \\
 minecraft:brown_mushroom minecraft:red_mushroom minecraft:cobweb minecraft:seagrass minecraft:tall_seagrass minecraft:kelp minecraft:kelp_plant \\
 minecraft:nether_sprouts minecraft:crimson_roots minecraft:warped_roots minecraft:crimson_fungus minecraft:warped_fungus

# Light sources by color, ids 10010-10017. Colors: LIGHT_COLORS in shadow.vsh.
# Light sources not listed here keep the default warm color.

# Torches, lanterns, fire
block.10010=minecraft:torch minecraft:wall_torch minecraft:lantern minecraft:fire minecraft:campfire:lit=true minecraft:jack_o_lantern \\
 minecraft:furnace:lit=true minecraft:blast_furnace:lit=true minecraft:smoker:lit=true minecraft:shroomlight \\
 minecraft:candle:lit=true minecraft:cave_vines:berries=true minecraft:cave_vines_plant:berries=true

# Lava
block.10011=minecraft:lava minecraft:flowing_lava minecraft:magma_block minecraft:lava_cauldron

# Soul fire
block.10012=minecraft:soul_torch minecraft:soul_wall_torch minecraft:soul_lantern minecraft:soul_fire minecraft:soul_campfire:lit=true

# Redstone
block.10013=minecraft:redstone_torch:lit=true minecraft:redstone_wall_torch:lit=true minecraft:redstone_ore:lit=true minecraft:deepslate_redstone_ore:lit=true

# Glowstone
block.10014=minecraft:glowstone minecraft:redstone_lamp:lit=true minecraft:ochre_froglight

# Sea lantern, end rod
block.10015=minecraft:sea_lantern minecraft:end_rod minecraft:beacon minecraft:conduit

# Portal, amethyst
block.10016=minecraft:nether_portal minecraft:crying_obsidian minecraft:amethyst_cluster minecraft:large_amethyst_bud minecraft:medium_amethyst_bud \\
 minecraft:pearlescent_froglight minecraft:respawn_anchor:charges=1 minecraft:respawn_anchor:charges=2 minecraft:respawn_anchor:charges=3 minecraft:respawn_anchor:charges=4

# Green lights
block.10017=minecraft:verdant_froglight minecraft:sea_pickle minecraft:glow_lichen

# Gives no light in the game, glows with this pack (GLOW_COLOR in shadow.vsh)
block.10018=minecraft:end_portal_frame

# Colored light stops at full blocks, found by their shape (see shadow.vsh).
# These would be taken for full blocks but let light through.
block.10020=minecraft:glass minecraft:snow minecraft:scaffolding minecraft:moss_carpet \\
 %s \\
 %s \\
 %s \\
 %s

# Blocks that color the light passing through, ids 10030-10048. Colors: TINT_COLORS in shadow.vsh.
%s
block.10046=minecraft:ice minecraft:frosted_ice
block.10047=minecraft:slime_block
block.10048=minecraft:honey_block
'''
DYES = ['white', 'orange', 'magenta', 'light_blue', 'yellow', 'lime', 'pink', 'gray',
        'light_gray', 'cyan', 'purple', 'blue', 'brown', 'green', 'red', 'black']
WOODS = ['oak', 'spruce', 'birch', 'jungle', 'acacia', 'dark_oak', 'mangrove', 'cherry', 'bamboo', 'crimson', 'warped', 'iron']
LEAVES = ['oak', 'spruce', 'birch', 'jungle', 'acacia', 'dark_oak', 'mangrove', 'cherry', 'azalea', 'flowering_azalea']
names = lambda fmt, items: ' '.join('minecraft:' + fmt % i for i in items)
blocks = blocks % (
    names('%s_carpet', DYES), names('%s_trapdoor', WOODS), names('%s_door', WOODS), names('%s_leaves', LEAVES),
    '\n'.join('block.%d=minecraft:%s_stained_glass minecraft:%s_stained_glass_pane' % (10030 + i, d, d) for i, d in enumerate(DYES)))
write('block.properties', blocks)
print('generated: %d options, %d sliders' % (len(OPTIONS), len(sliders)))
