"""Build the agreed STS2 attack, strong-note, power-up and entrance previews."""
import json
import pathlib
import wave

import numpy as np

from import_miku import ASSETS, ROOT, SOURCE, write_json


def cut_sound(source, output_name, segments, fade_in_seconds=.002):
    destination = ASSETS / 'Audio/Adapted' / (output_name + '.wav')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(source), 'rb') as audio:
        channels, width, rate = audio.getnchannels(), audio.getsampwidth(), audio.getframerate()
        if width != 2:
            raise ValueError('Expected original PCM16 audio')
        original = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2').reshape(-1, channels).astype(float)
    chunks = [original[round(start * rate):round((start + length) * rate)].copy() for start, length in segments]
    samples = chunks[0]
    for chunk in chunks[1:]:
        overlap = min(round(rate * .05), len(samples), len(chunk))
        weight = np.linspace(0, 1, overlap)[:, None]
        joined = samples[-overlap:] * (1 - weight) + chunk[:overlap] * weight
        samples = np.concatenate([samples[:-overlap], joined, chunk[overlap:]])
    fade_in = min(round(rate * fade_in_seconds), len(samples))
    fade_out = min(round(rate * .025), len(samples))
    samples[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    samples[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    with wave.open(str(destination), 'wb') as audio:
        audio.setparams((channels, width, rate, len(samples), 'NONE', 'not compressed'))
        audio.writeframes(np.clip(samples, -32768, 32767).astype('<i2').tobytes())
    return {'path': 'res://Miku_Hcxmmx/Assets/Audio/Adapted/' + output_name + '.wav',
            'source': str(source), 'source_segments': segments,
            'crossfade_seconds': .05 if len(segments) > 1 else 0,
            'fade_in_seconds': fade_in_seconds, 'duration': len(samples) / rate}


def main():
    source = json.loads((ASSETS / 'actor.json').read_text(encoding='utf-8'))
    sprites = {sprite['name']: key for key, sprite in source['sprites'].items()}
    effects = json.loads((ASSETS / 'effects.json').read_text(encoding='utf-8'))
    materials = {row['name']: row for row in effects['materials']}
    texture_names = {'note': 'miku_s100_02', 'glow': 'public_lizi_01_D',
                     'spark': 'kirino_star_L_01', 'shard': 'luka_miku_smallsuipian',
                     'line': 'public_line_05', 'ring': 'miku_dz_ring_02', 'wave': 'rentaro_dazhao2_01'}
    textures = {name: materials[material]['texture'] for name, material in texture_names.items()}
    definitions = {
        'sts2_attack': [('Miku002_12', .055), ('Miku002_13', .055), ('Miku002_14', .06),
                        ('Miku002_15', .055), ('Miku002_16', .055), ('Miku002_17', .07), ('Miku002_18', .07)],
        'sts2_shootBow': [('Miku002_08', .065), ('Miku002_09', .065), ('Miku002_10', .065),
                          ('Miku002_11', .065), ('Miku002_09', .065), ('Miku002_10', .065),
                          ('Miku002_11', .065), ('Miku002_12', .055), ('Miku002_13', .055), ('Miku002_18', .055)],
    }
    animations = {}
    for name, frames in definitions.items():
        boundaries = []
        duration = 0.0
        for _, delay in frames:
            boundaries.append(round(duration, 6))
            duration += delay
        animations[name] = {'frames': [sprites[sprite] for sprite, _ in frames],
                            'frame_times': boundaries, 'delay': .05, 'duration': round(duration, 6)}
    sound_folder = SOURCE / 'Recovered_Audio/WAV/sound/se/miku'
    voices = json.loads((SOURCE / 'Recovered_Audio/Voice_SoundsResource/inventory.json').read_text(encoding='utf-8'))
    roar = next(row for row in voices if row['relative_path'] == 'Miku_RoarS.wav')
    sounds = {
        'attack_cast': cut_sound(sound_folder / 'MicroNoise.wav', 'attack_cast', [(.04, .26)]),
        'strong_voice': cut_sound(pathlib.Path(roar['file_path']), 'strong_voice', [(0, .44), (2.65, .28)]),
        'strong_bed': cut_sound(sound_folder / 'MikuSkill2_Sampling01.wav', 'strong_bed', [(0, .62)]),
        'strong_hit': cut_sound(sound_folder / 'MikuSkillHead.wav', 'strong_hit', [(.005, .23)]),
    }
    # Keep source audio intact and use separately trimmed copies in adapted actions.
    adapted_audio = {}
    trim_starts = {'miku_17': .055, 'miku_04': .03, 'miku_18': .02, 'mikuskillhead': .004}
    for action in ['s200', 'show_1_1']:
        adapted_audio[action] = []
        for source_cue in source['audio'].get(action, []):
            cue = dict(source_cue, time=0, paths=[])
            for path in source_cue['paths']:
                source_path = ASSETS.parent.parent / path.removeprefix('res://')
                with wave.open(str(source_path), 'rb') as audio:
                    length = audio.getnframes() / audio.getframerate()
                name = source_path.stem
                start = trim_starts[name]
                key = 'ready_' + name if action == 's200' else 'intro_' + name
                sounds[key] = cut_sound(source_path, key, [(start, length - start)])
                cue['paths'].append(sounds[key]['path'])
            adapted_audio[action].append(cue)
    hit_action = next(row for row in json.loads((SOURCE / 'Parsed/mikuBullet.json').read_text(encoding='utf-8'))['action']
                      if row['name'] == 's202_bullet_hit')
    hit_source = hit_action['hitEffects'][0]
    hit_effect = hit_source['name'].lower()
    hit_time = .22
    hit_duration = effects['effects'][hit_effect]['frame_count'] / effects['fps']
    performances = {
        'sts2_attack': {
            'label': 'Attack · s202 轻攻击', 'body_duration': .42, 'repeat': False,
            'segments': [{'clip': 'sts2_attack', 'action': '', 'duration': .42},
                         {'clip': 'stand', 'action': '', 'duration': round(hit_time + hit_duration - .42 + .05, 6), 'loop': True}],
            'effects': {'events': [{'effect': hit_effect, 'start': hit_time, 'anchor': 'target_center',
                                    'offset': [0, 0], 'scale': [1, 1], 'layer': 0, 'conditional_hit': True,
                                    'source': hit_source, 'source_action': 's202_bullet_hit'}]},
            'audio': [{'time': 0, 'kind': 'sfx', 'volume': .8, 'paths': [sounds['attack_cast']['path']]}],
            'note': 's202 出手 0.42 秒；目标效果使用原作 miku_s200_04_a，自然播放尾段。',
        },
        'sts2_shootBow': {
            'label': 'shootBow · s201 强音攻击', 'body_duration': .62, 'repeat': False,
            'segments': [{'clip': 'sts2_shootBow', 'action': '', 'duration': .62},
                         {'clip': 'stand', 'action': '', 'duration': 2.0, 'loop': True}],
            'effects': {'events': [{'effect': 'miku/miku_s200_03_a', 'start': 0, 'anchor': 'self',
                                    'offset': [0, 0], 'scale': [1, 1], 'layer': 1, 'conditional_hit': False,
                                    'time_scale': 4.5}]},
            'audio': [{'time': 0, 'kind': 'voice', 'volume': 1.0, 'paths': [sounds['strong_voice']['path']]},
                      {'time': 0, 'kind': 'sfx', 'volume': .75, 'paths': [sounds['strong_bed']['path']]}],
            'combat_effect': {'kind': 'strong', 'release': .08, 'hit': .22, 'origin': [10, -264],
                              'impact_duration': .75, 'impact_scale': 3.0, 'impact_flash_duration': .14,
                              'marker_burst_scale': 4.8, 'marker_ring_burst_scale': 3.0,
                              'marker_hold_duration': .12, 'marker_settle_duration': .5,
                              'hit_audio': {'kind': 'sfx', 'volume': 2.7, 'paths': [sounds['strong_hit']['path']]},
                              'return_at': 1.9, 'return_duration': .25, 'marker_scale': 4.0, 'textures': textures},
            'note': '常驻标记为上版两倍，命中峰值为上版三倍；峰值保持 0.12 秒，0.5 秒收缩，命中尾效 0.75 秒。',
        },
        'sts2_powerUp': {
            'label': 'PowerUp · s200 麦克风准备', 'body_duration': 1.0, 'repeat': False,
            'segments': [{'clip': 's200', 'action': '', 'duration': 1.0},
                         {'clip': 'stand', 'action': '', 'duration': .25, 'loop': True}],
            'audio': adapted_audio['s200'],
            'effects': {'events': []}, 'note': '独立播放原速 s200，完整表现拿出麦克风并做好准备。',
        },
        'sts2_intro': {
            'label': '入场 · 指向展示', 'body_duration': 1.0, 'repeat': False,
            'segments': [{'clip': 'show', 'action': '', 'duration': 1.0},
                         {'clip': 'stand', 'action': '', 'duration': .35, 'loop': True}],
            'audio': adapted_audio['show_1_1'],
            'effects': {'events': []}, 'note': '指向手势用于入场，采用原始 show 的展示节奏。',
        },
        'sts2_intro_alt': {
            'label': '入场 · 横葱吹奏', 'body_duration': 2.3, 'repeat': False,
            'segments': [{'clip': 'show01', 'action': 'show_1_2', 'duration': 2.3},
                         {'clip': 'stand', 'action': '', 'duration': .35, 'loop': True}],
            'effects': {'events': []}, 'note': '原速 show01，与指向展示随机用于入场。',
        },
    }
    user_audio = json.loads((ASSETS / 'user_audio.json').read_text(encoding='utf-8'))
    strong_voice = performances['sts2_shootBow']['audio'][0]
    strong_voice['paths'] = [row['path'] for row in user_audio['heavy']]
    strong_voice['exclusive_heavy'] = True
    for performance in performances.values():
        performance['repeat'] = True
        performance['loop_body_on_repeat'] = True
        performance['audio_at_start'] = True
    write_json(ASSETS / 'combat_profiles.json', {'animations': animations, 'performances': performances})
    write_json(ROOT / '02_构建产物/combat_adaptation_sources.json', {
        'frames': definitions, 'sounds': sounds, 'textures': textures,
        'performances': performances, 'source': str(SOURCE / 'Extracted_Miku/Recovered_iOS'),
    })
    print('Built s202 Attack, s201 strong-note, s200 PowerUp and entrance previews')


if __name__ == '__main__':
    main()
