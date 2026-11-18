"""Generate Godot resources from the recovered Miku snapshot and supplied voices."""
import json
import pathlib
import shutil
import struct

import UnityPy

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'CrossingVoid_Investigation'
GODOT = ROOT / '01_制作工程/Godot'
ASSETS = GODOT / 'Miku_Hcxmmx/Assets'


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


def build_performances(logic, animations):
    actions = {action['name']: action for action in logic['action']}
    entries = [
        ('stand', '待机', True), ('walk', '移动 · 四阶段', True),
        ('defence', '防御', False), ('behit_middle', '受击', False),
        ('behit_up', '上段受击', False), ('push', '击退与起身', False),
        ('show_1_1', '出场展示一', False), ('show_1_2', '出场展示二', False),
        ('winpose', '胜利', False), ('lose', '败北 · 进入保持姿势', False),
        ('s100', '技能一 · 回复', False), ('s200', '技能二 · 三阶段', False),
        ('s100_EX', '技能一 EX · 回复', False), ('s200_EX', '技能二 EX · 三阶段', False),
        ('Link1009500', '连携 10095 · 三阶段', False),
        ('Link1009600_A', '连携 10096 · 三阶段', False),
        ('s300', '大招舞步 · 身体动作连播', False),
    ]
    performances = {}
    for entry, label, repeat in entries:
        segments = []
        visited = {}
        name = entry
        tail_loop_index = -1
        while name in actions:
            if name in visited:
                # walk returns to its first stage. lose repeats only its final pose.
                tail_loop_index = visited[name] if visited[name] > 0 else -1
                break
            visited[name] = len(segments)
            action = actions[name]
            clip = action.get('animate', name)
            if clip not in animations:
                raise ValueError(f'{entry}: unsupported animation stage {name} -> {clip}')
            animation = animations[clip]
            segments.append({'action': name, 'clip': clip,
                             'duration': animation['delay'] * len(animation['frames'])})
            name = action.get('nextAction', '')
        note = ''
        if entry in ['s100', 's100_EX']:
            note = '原作回复技能；目标侧按首次命中演示，位置与随机分支待实机校准。'
        elif entry == 's300':
            note = '展示 s300–s308 的身体链；原作大招还包含 9.5 秒调度段、替身与镜头。'
        elif entry.startswith(('s1', 's2', 'Link')):
            note = '按原始事件调度特效；全屏层、镜头、材质与粒子细节仍在校准。'
        performances[entry] = {'label': label, 'segments': segments, 'repeat': repeat,
                               'tail_loop_index': tail_loop_index, 'note': note}
    return performances


def main():
    extracted = SOURCE / 'Extracted_Miku/Recovered_iOS'
    sprites = json.loads((extracted / 'sprite_metadata.json').read_text(encoding='utf-8'))
    timelines = json.loads((extracted / 'animation_timelines.json').read_text(encoding='utf-8'))
    bundles = SOURCE / 'Recovered_AssetBundles/iOS_3.0.1'
    cab_textures = {}
    for path in (bundles / 'assetbundle/dependencies/sprite2d/role/miku').iterdir():
        for obj in UnityPy.load(str(path)).objects:
            if obj.type.name == 'Texture2D' and obj.read().m_Name != 'miku_palette':
                data = obj.read()
                cab_textures[obj.assets_file.name] = (data.m_Name, data.m_Height)
                target = ASSETS / 'Body' / (data.m_Name + '.png')
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(extracted / 'Atlases' / (data.m_Name + '_classic.png'), target)

    sprite_data = {}
    for sprite in sprites:
        data = sprite['metadata']
        render = data['m_RD']
        if render['settingsRaw'] & 0x1:
            raise ValueError('Packed Sprite needs an explicit rotation conversion')
        atlas, height = cab_textures[sprite['asset_file']]
        rectangle = render['textureRect']
        vertices = struct.unpack_from('<12f', bytes.fromhex(render['m_VertexData']['m_DataSize']['bytes_hex']))
        ppu = data['m_PixelsToUnits']
        # Unity local vertices preserve the trimmed sprite's original anchor.
        sprite_data[str(sprite['path_id'])] = {
            'name': sprite['name'], 'atlas': f'res://Miku_Hcxmmx/Assets/Body/{atlas}.png',
            'region': [rectangle['x'], height - rectangle['y'] - rectangle['height'], rectangle['width'], rectangle['height']],
            'offset': [min(vertices[0::3]) * ppu, -max(vertices[1::3]) * ppu],
        }
    main_cab = next(obj.assets_file.name for obj in UnityPy.load(str(bundles / 'assetbundle/animation/role/miku')).objects)
    animations = {}
    for animation in timelines:
        if animation['asset_file'] != main_cab:
            continue
        animations[animation['name'].removeprefix('miku_')] = {
            'frames': [str(frame['m_PathID']) if frame['m_PathID'] else '' for frame in animation['metadata']['mSpriteList']],
            'delay': animation['delay_seconds'], 'source_anchor': animation['metadata']['mAnchor'],
            'source_scale': animation['metadata']['mScale'],
        }
    stand = sprite_data[animations['stand']['frames'][0]]
    ground_offset = -(stand['offset'][1] + stand['region'][3])
    logic = json.loads((SOURCE / 'Parsed/miku.json').read_text(encoding='utf-8'))
    performances = build_performances(logic, animations)
    from effect_logic import compile_timeline, effect_references
    for performance in performances.values():
        performance['effects'] = compile_timeline(performance['segments'], animations)
    raw_effects = {}
    for name, animation in animations.items():
        segment = {'action': name, 'duration': animation['delay'] * len(animation['frames'])}
        raw_effects[name] = compile_timeline([segment], animations)
    effect_previews = {}
    for row in effect_references():
        source = row['source']
        hit = row['field'] == 'hitEffects'
        position = source.get('offPosition' if hit else 'position', {})
        effect_previews[row['effect']] = {'effect': row['effect'], 'start': 0,
            'inventory_only': row['field'] == 'inventory_only',
            'anchor': 'target' if hit else 'self',
            'offset': [position.get('x', 0), position.get('y', 0) * (1 if hit else -1)],
            'scale': [source.get('scale', {}).get('x', 1), source.get('scale', {}).get('y', 1)],
            'layer': source.get('behindRole', 0), 'conditional_hit': hit,
            'random_play': source.get('randomPlay', False), 'source': source}
    audio_sources = {}
    voices = json.loads((SOURCE / 'Recovered_Audio/Voice_SoundsResource/inventory.json').read_text(encoding='utf-8'))
    for row in voices:
        audio_sources['voice/miku/' + row['relative_path'].removesuffix('.wav').lower()] = pathlib.Path(row['file_path'])
    for path in (SOURCE / 'Recovered_Audio/WAV/sound/se/miku').glob('*.wav'):
        audio_sources['sound/se/miku/' + path.stem.lower()] = path
    cues = {}
    copied = {}
    for action in logic['action']:
        events = []
        for cue in action.get('audio', []):
            candidates = []
            for name in cue.get('path', []):
                key = name.lower()
                if key not in audio_sources:
                    continue
                destination = ASSETS / 'Audio' / (key + '.wav')
                destination.parent.mkdir(parents=True, exist_ok=True)
                if key not in copied:
                    shutil.copy2(audio_sources[key], destination)
                    copied[key] = str(audio_sources[key])
                candidates.append('res://Miku_Hcxmmx/Assets/Audio/' + key + '.wav')
            if candidates:
                events.append({'time': cue.get('start', 0.0), 'volume': cue.get('volume', 1.0),
                               'kind': 'voice' if candidates[0].find('/voice/') >= 0 else 'sfx', 'paths': candidates})
        cues[action['name']] = events
    write_json(ASSETS / 'actor.json', {'sprites': sprite_data, 'animations': animations,
                                    'ground_offset': ground_offset, 'audio': cues,
                                    'performances': performances, 'raw_effects': raw_effects,
                                    'effect_previews': effect_previews})
    write_json(ROOT / '02_构建产物/import_summary.json', {
        'animations': len(animations), 'sprite_objects': len(sprite_data), 'atlases': len(cab_textures),
        'audio_sources': copied, 'ground_offset': ground_offset,
        'source': str(extracted), 'palette_image_row': 9,
        'performances': performances,
    })
    print(f'Imported {len(animations)} animations, {len(sprite_data)} Sprite records, {len(copied)} audio files')


if __name__ == '__main__':
    main()
