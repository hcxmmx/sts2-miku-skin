"""Build response-based action and effect candidates for the shared preview."""
import json
import hashlib
import wave
from copy import deepcopy

import numpy as np

from import_miku import ASSETS, ROOT, write_json


def music_spectrum(row):
    path = ASSETS.parent.parent / row['path'].removeprefix('res://')
    with wave.open(str(path), 'rb') as audio:
        if audio.getsampwidth() != 2:
            raise ValueError('Music preview expects PCM16 WAV')
        rate = audio.getframerate()
        samples = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2')
        samples = samples.reshape(-1, audio.getnchannels()).astype(float) / 32768
    frequencies = np.fft.rfftfreq(2048, 1 / rate)
    edges = [60, 120, 240, 480, 960, 1920, 3840, 7680, 16000]
    windows = []
    for index in range(int(np.ceil(len(samples) / rate * 60))):
        center = round(index * rate / 60)
        first, last = max(0, center - 1024), min(len(samples), center + 1024)
        window = np.zeros((2048, samples.shape[1]))
        offset = first - (center - 1024)
        window[offset:offset + last - first] = samples[first:last]
        powers = np.abs(np.fft.rfft(window * np.hanning(2048)[:, None], axis=0)) ** 2
        powers = powers.mean(axis=1)
        windows.append([powers[(frequencies >= low) & (frequencies < high)].sum()
                        for low, high in zip(edges, edges[1:])])
    values = np.asarray(windows)
    peaks = np.maximum(np.percentile(values, 96, axis=0), 1e-8)
    values = np.clip(values / peaks, 0, 1) ** .45
    previous = np.zeros(8)
    smoothed = []
    for value in values:
        previous += np.where(value > previous, .7, .22) * (value - previous)
        smoothed.append(previous.round(4).tolist())
    return {'id': row['id'], 'path': row['path'], 'duration': row['duration'],
            'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'rate': 60, 'bands': smoothed}


def add_music_demo(performances, demo_group):
    clips = []
    attacks = []
    cues = []
    segments = []
    clock = 0.0
    for index, row in enumerate(demo_group['clips']):
        start = round(.8 + index * 2.7, 6)
        clip = music_spectrum(row)
        clip['start'] = start
        clips.append(clip)
        cues.append({'time': start, 'kind': 'sfx', 'volume': 1.0,
                     'paths': [row['path']], 'sync_timeline': True})
        for beat in range(3):
            attack = round(start + beat * .45, 6)
            if attack > clock:
                segments.append({'clip': 'stand', 'action': '', 'duration': round(attack - clock, 6), 'loop': True})
            segments.append({'clip': 'draft_attack', 'action': '', 'duration': .42})
            clock = round(attack + .42, 6)
            attacks.append(attack)
    duration = round(clips[-1]['start'] + clips[-1]['duration'] + 1.15, 6)
    segments.append({'clip': 'stand', 'action': '', 'duration': round(duration - clock, 6), 'loop': True})
    hit_profile = dict(performances['draft_attack']['combat_effect'])
    hit_profile.update(duration=.58, return_at=.58, impact_duration=.37, release=.11,
                       readable_hold=.075, origin=[100, -300])
    return {
        'label': '轻攻击 · 片段与常驻联动', 'music_demo': True, 'repeat': True,
        'body_z_index': 1, 'body_duration': duration, 'segments': segments,
        'effects': {'events': []}, 'audio': cues, 'audio_at_start': False,
        'combat_effect': {'kind': 'music_light', 'hit': attacks[0] + hit_profile['hit'],
                          'hit_events': [round(time + hit_profile['hit'], 6) for time in attacks],
                          'attacks': attacks, 'clips': clips, 'hit_profile': hit_profile,
                          'duration': duration, 'return_at': duration, 'return_duration': 0,
                          'target_hit': True},
        'note': '先看常驻舞台，再连续轻击；三段原音频按序播放，频谱取自实际片段。命中轮廓保持约 0.075 秒后碎散。',
    }


def main():
    source = json.loads((ASSETS / 'actor.json').read_text(encoding='utf-8'))
    combat = json.loads((ASSETS / 'combat_profiles.json').read_text(encoding='utf-8'))
    light_groups = json.loads((ASSETS / 'user_audio.json').read_text(encoding='utf-8'))['light_groups']
    textures = combat['performances']['sts2_shootBow']['combat_effect']['textures']
    definitions = {
        'draft_cast_gesture': [('s300', 0, 1, .1), ('s300', 2, 3, .14),
                               ('s302', 1, 2, .15), ('s302', 2, 3, .16),
                               ('s302', 3, 4, .2), ('s301', 0, 1, .2),
                               ('s301', 2, 3, .15), ('s301', 3, 4, .16)],
        'draft_cast_step': [('s303', 11, 12, .055), ('s304', 0, 10, .035),
                           ('s305', 0, 8, .04), ('s306', 0, 14, .035)],
        'draft_celebrate': [('s307', 0, 9, .035), ('s308', 0, 8, .065),
                            ('s308', 8, 20, .045)],
        'draft_powerup_spin': [('Link1009600_A', 0, 1, .1),
                               ('Link1009601', 0, 2, .065),
                               ('Link1009601', 2, 11, .09)],
        'draft_hit': [('behit_middle', 0, 5, .11)],
        'draft_cast_link': [('Link1009601', 25, 28, .075),
                            ('Link1009601', 28, 31, .12),
                            ('Link1009601', 28, 31, .1)],
    }
    animations = {'draft_attack': combat['animations']['sts2_attack']}
    for name, parts in definitions.items():
        frames = []
        frame_times = []
        clock = 0.0
        for clip, first, last, interval in parts:
            selected = source['animations'][clip]['frames'][first:last]
            for frame in selected:
                frame_times.append(round(clock, 6))
                frames.append(frame)
                clock += interval
        animations[name] = {'frames': frames, 'frame_times': frame_times,
                            'duration': round(clock, 6), 'delay': .04}

    descriptions = {
        'draft_attack': ('Attack · 碎拍冲击', 'light', .16, .45,
                         '0.16 秒接触，命中约 0.23 秒爆开并碎散；压缩谱线、破碎音符与定向冲击。'),
        'draft_cast_gesture': ('Cast 一 · 谱面爆发', 'gesture', .14, .72,
                               '保留举手舞步；五线谱扇面在抬手时迅速展开、爆出音符和频谱碎片。'),
        'draft_cast_step': ('PowerUp · 扶腰侧步', 'step', .16, .88,
                            '保留侧步；两次短拍触发分段均衡器、地面震荡和上冲音符。'),
        'draft_powerup_spin': ('PowerUp · 旋转蓄势', 'spin', .28, .94,
                               '旋转剪为一圈，每帧约 0.09 秒，转完回待机。'),
        'draft_celebrate': ('入场 · 欢呼礼炮', 'celebrate', .32, 1.3,
                            '保留跳起庆祝；两侧舞台礼炮随起跳喷发音符、彩屑和闪光。'),
    }
    performances = {}
    for name, (label, kind, hit, effect_duration, note) in descriptions.items():
        body_duration = animations[name]['duration']
        total_duration = max(body_duration + .5, effect_duration)
        performances[name] = {
            'label': label, 'body_duration': body_duration, 'repeat': True, 'body_z_index': 1,
            'segments': [{'clip': name, 'action': '', 'duration': body_duration},
                         {'clip': 'stand', 'action': '', 'duration': round(total_duration - body_duration, 6), 'loop': True}],
            'effects': {'events': []},
            'audio': [],
            'combat_effect': {'kind': kind, 'release': .05, 'hit': hit,
                              'duration': effect_duration, 'body_duration': body_duration,
                              'origin': [25, -275], 'return_at': effect_duration,
                              'return_duration': 0, 'target_hit': kind == 'light', 'textures': textures},
            'note': note,
        }
    performances['draft_attack']['audio'] = combat['performances']['sts2_attack']['audio']
    performances['draft_powerup_spin']['audio'] = combat['performances']['sts2_powerUp']['audio']
    for performance in performances.values():
        performance['audio_at_start'] = True
    intro = dict(performances['draft_celebrate'])
    intro['segments'] = [{'clip': 'stand', 'action': '', 'duration': 1.25, 'loop': True},
                         *intro['segments']]
    intro['body_duration'] += 1.25
    intro_duration = sum(segment['duration'] for segment in intro['segments'])
    intro.update(
        label='入场 · 舞台建立',
        combat_effect={'kind': 'stage_intro', 'hit': 1.57, 'target_hit': False,
                       'duration': intro_duration, 'return_at': intro_duration,
                       'return_duration': 0, 'textures': textures},
        note='舞台分层建立，纯色剪影经过扫描显现，频谱与音符亮起后进入常驻。',
    )
    performances = {'draft_stage_intro': intro,
                    'draft_music_attack': add_music_demo(performances, light_groups[0]), **performances}
    link_duration = animations['draft_cast_link']['duration']
    link_cast = {
        'body_duration': link_duration,
        'segments': [{'clip': 'draft_cast_link', 'action': '', 'duration': link_duration, 'mirrored': True},
                     {'clip': 'stand', 'action': '', 'duration': .5, 'loop': True}],
    }
    available = {**source['performances'], **combat['performances'], **performances,
                 'link_cast': link_cast}
    available['hit_hold'] = {
        'body_duration': animations['draft_hit']['duration'],
        'segments': [{'clip': 'draft_hit', 'action': '', 'duration': animations['draft_hit']['duration']},
                     {'clip': 'stand', 'action': '', 'duration': .45, 'loop': True}],
    }
    response_sources = [
        ('powerup_spin', 'PowerUp · 一圈旋转', 'draft_powerup_spin'),
        ('cast_link', 'Cast · 连携末段（面向敌人）', 'link_cast'),
        ('powerup_step', 'PowerUp · 扶腰侧步', 'draft_cast_step'),
        ('cast_gesture', 'Cast · 猫爪舞步', 'draft_cast_gesture'),
        ('cast_original', 'Cast · 原有举手施法', 's100'),
        ('powerup_ready', 'PowerUp · 麦克风准备', 'sts2_powerUp'),
        ('attack', 'Attack · 轻攻击', 'draft_attack'),
        ('shootBow', 'shootBow · 强音射击', 'sts2_shootBow'),
        ('intro_cheer', '入场 · 欢呼', 'draft_celebrate'),
        ('intro_point', '入场 · 指向展示', 'sts2_intro'),
        ('victory_flute', 'Victory · 横葱吹奏', 'sts2_intro_alt'),
        ('victory_original', 'Victory · 原作胜利', 'winpose'),
        ('block', 'Block · 防御', 'defence'),
        ('hit', 'Hit · 普通受击', 'hit_hold'),
        ('dead', 'Dead · 站姿败北', 'lose'),
        ('idle', '待机', 'stand'),
    ]
    body_previews = {}
    combined_previews = {}
    for key, label, source_name in response_sources:
        performance = dict(available[source_name])
        performance.pop('combat_effect', None)
        performance.update(label=label, effects={'events': []}, audio=[], repeat=True,
                           note='当前响应分配的身体动作预览。')
        performance['segments'] = [dict(segment, action='') for segment in performance['segments']]
        body_previews['response_' + key] = performance
        effect_source = {'attack': 'draft_music_attack', 'intro_cheer': 'draft_stage_intro'}.get(key, source_name)
        combined = dict(available[effect_source])
        combined['segments'] = [dict(segment) for segment in combined['segments']]
        combined.update(label=label, repeat=True, loop_body_on_repeat=False)
        combined['effects'] = combined.get('effects', source.get('raw_effects', {}).get(effect_source, {'events': []}))
        if key == 'powerup_spin':
            body_duration = animations['draft_powerup_spin']['duration']
            combined['segments'][-1]['duration'] = .65
            combined['combat_effect'] = {
                'kind': 'stage_spin', 'hit': round(body_duration - .08, 6),
                'body_duration': body_duration, 'duration': body_duration + .65,
                'return_at': body_duration + .65, 'return_duration': 0,
                'target_hit': False, 'textures': textures,
            }
            combined['note'] = '一圈旋转带动舞台波形与灯带，音符卷起，收势时向外散开并亮拍。'
        if key == 'hit':
            combined['segments'][0]['action'] = 'behit_middle'
            body_duration = animations['draft_hit']['duration']
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_hit', 'hit': .02, 'body_duration': body_duration,
                'duration': body_duration + .45, 'return_at': body_duration + .45,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '扣血受击时人物短暂横向错位与青粉残影，舞台频谱受冲击后恢复。'
        if key == 'cast_link':
            effect_duration = link_duration + .5
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_cast', 'hit': .42, 'body_duration': link_duration,
                'duration': effect_duration, 'return_at': effect_duration,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '身前展开全息谱面，音符依次点亮，脉冲沿谱线在谱面内部传递。'
        if key == 'powerup_step':
            body_duration = animations['draft_cast_step']['duration']
            combined['segments'][-1]['duration'] = .6
            combined['combat_effect'] = {
                'kind': 'stage_step', 'hit': .16, 'beats': [.16, .46],
                'body_duration': body_duration, 'duration': body_duration + .6,
                'return_at': body_duration + .6, 'return_duration': 0,
                'target_hit': False, 'textures': textures,
            }
            combined['note'] = '两次踩拍依次点亮舞台灯板与左右频谱，第二拍音符升起并获得强化辉光。'
        if key == 'cast_gesture':
            body_duration = animations['draft_cast_gesture']['duration']
            landmarks = {
                'Miku395_00': (166, 42, -.08, 99, 99),
                'Miku395_01': (164, 55, -.12, 135, 27),
                'Miku395_02': (123, 45, .12, 91, 43),
                'Miku395_03': (43, 57, .14, 14, 35),
                'Miku395_04': (55, 54, .1, 49, 35),
                'Miku395_05': (83, 55, -.12, 72, 35),
                'Miku395_06': (73, 46, -.14, 116, 53),
                'Miku395_07': (148, 44, -.08, 117, 30),
            }
            head_poses = []
            for frame, time in zip(animations['draft_cast_gesture']['frames'],
                                   animations['draft_cast_gesture']['frame_times']):
                sprite = source['sprites'][frame]
                hx, hy, tilt, px, py = landmarks[sprite['name']]
                ox, oy = sprite['offset']
                ground = source['ground_offset']
                head_poses.append({'time': time, 'head': [ox + hx, oy + hy + ground],
                                   'tilt': tilt, 'paw': [ox + px, oy + py + ground]})
            combined['combat_effect'] = {
                'kind': 'stage_gesture', 'hit': .55, 'body_duration': body_duration,
                'duration': body_duration + .5, 'return_at': body_duration + .5,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
                'head_poses': head_poses,
            }
            combined['note'] = '一轮放慢的猫爪舞步，头部全息猫耳随姿势移动，定势时耳尖轻抖并闪出爪印。'
        if key == 'block':
            body_duration = sum(segment['duration'] for segment in combined['segments'])
            combined['segments'].append({'clip': 'stand', 'action': '', 'duration': .45, 'loop': True})
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_block', 'hit': .22, 'body_duration': body_duration,
                'duration': body_duration + .45, 'return_at': body_duration + .45,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '青粉应援棒交叉承力回弹。多段格挡的连续表现留待游戏接入时观察。'
        if key == 'dead':
            effect_duration = sum(segment['duration'] for segment in combined['segments'])
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_death', 'hit': 0, 'body_duration': combined['segments'][0]['duration'],
                'duration': effect_duration, 'return_at': effect_duration,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '信号短暂中断，频谱塌落、音符下坠，舞台按圆周逐层熄灯，人物保持站姿败北。'
        if key == 'victory_flute':
            body_duration = float(combined['body_duration'])
            combined['segments'][-1]['duration'] = .7
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_flute', 'hit': .14, 'body_duration': body_duration,
                'phrases': [.14, .66, 1.16, 1.66],
                'duration': body_duration + .7, 'return_at': body_duration + .7,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '吹奏音符分拍沿弧形谱线展开，舞台与两侧应援棒呼应，最后以星芒亮拍收尾。'
        if key == 'victory_original':
            body_duration = sum(segment['duration'] for segment in combined['segments'])
            animations['draft_victory_hold'] = {
                'frames': source['animations']['winpose']['frames'][-1:],
                'delay': .7, 'duration': .7,
            }
            combined['segments'].append({'clip': 'draft_victory_hold', 'action': '', 'duration': .7})
            combined['effects'] = source['raw_effects']['winpose']
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_victory', 'hit': .3, 'body_duration': body_duration,
                'phrases': [.3, 1.25, 2.2, 2.95], 'finale_time': 2.95,
                'duration': body_duration + .7, 'return_at': body_duration + .7,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '原作手部39与胜利光效结合双侧音符礼花、彩带和人物星芒，最后保持胜利末姿。'
        if key == 'intro_point':
            combined['segments'].insert(0, {'clip': 'stand', 'action': '', 'duration': 1.25, 'loop': True})
            combined['segments'][-1]['duration'] = .6
            effect_duration = sum(segment['duration'] for segment in combined['segments'])
            combined['body_duration'] += 1.25
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_point', 'hit': 1.55, 'body_duration': combined['body_duration'],
                'duration': effect_duration, 'return_at': effect_duration,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '舞台分层建立与扫描显现后接指向动作，频谱亮波向右传递并带动灯带。'
        if key == 'powerup_ready':
            body_duration = float(combined['body_duration'])
            combined['segments'][-1]['duration'] = .6
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_ready', 'hit': .78, 'body_duration': body_duration,
                'duration': body_duration + .6, 'return_at': body_duration + .6,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '小音符向身前汇聚缩小，凝成大号高亮音符，配合开麦亮拍与人物强化辉光。'
        if key == 'cast_original':
            body_duration = sum(segment['duration'] for segment in combined['segments'])
            combined['segments'].append({'clip': 'stand', 'action': '', 'duration': .9, 'loop': True})
            combined['effects'] = {'events': [event for event in source['raw_effects']['s100']['events']
                                               if event['anchor'] == 'self']}
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_lift', 'hit': .6, 'body_duration': body_duration,
                'duration': body_duration + .9, 'return_at': body_duration + .9,
                'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '以原作人物前后层的键盘螺旋、举手蓄光和粒子为主体，舞台频谱与灯带跟随蓄光响应。'
        if key == 'shootBow':
            combined['body_z_index'] = 1
            combined['combat_effect'] = dict(combined['combat_effect'])
            combined['combat_effect'].update(
                kind='stage_strong', body_duration=combined['body_duration'], target_hit=True,
                duration=sum(segment['duration'] for segment in combined['segments']))
            combined['note'] = '舞台蓄势、灯带与频谱向前推动，结合强音声波、放大音符命中及回收演示。'
        if key == 'idle':
            combined['segments'] = [{'clip': 'stand', 'action': '', 'duration': 8, 'loop': True}]
            combined['body_duration'] = 8
            combined['body_z_index'] = 1
            combined['combat_effect'] = {
                'kind': 'stage_ambient', 'hit': 0, 'duration': 8,
                'return_at': 8, 'return_duration': 0, 'target_hit': False, 'textures': textures,
            }
            combined['note'] = '常驻音乐舞台与漂浮音符，待机每次指尖点拍泛起两层青粉音波。'
        combined['note'] = combined.get('note', '') + ' 当前动作与特效制作入口。'
        combined_previews['combined_' + key] = combined
    combined_previews = {
        'combined_idle': combined_previews.pop('combined_idle'),
        'combined_shootBow': combined_previews.pop('combined_shootBow'),
        'combined_cast_original': combined_previews.pop('combined_cast_original'),
        'combined_powerup_ready': combined_previews.pop('combined_powerup_ready'),
        'combined_intro_point': combined_previews.pop('combined_intro_point'),
        'combined_victory_original': combined_previews.pop('combined_victory_original'),
        'combined_victory_flute': combined_previews.pop('combined_victory_flute'),
        'combined_dead': combined_previews.pop('combined_dead'),
        'combined_hit': combined_previews.pop('combined_hit'),
        'combined_block': combined_previews.pop('combined_block'),
        'combined_cast_gesture': combined_previews.pop('combined_cast_gesture'),
        'combined_powerup_step': combined_previews.pop('combined_powerup_step'),
        'combined_cast_link': combined_previews.pop('combined_cast_link'),
        'combined_powerup_spin': combined_previews.pop('combined_powerup_spin'),
        'combined_attack': combined_previews.pop('combined_attack'),
        'combined_intro_cheer': combined_previews.pop('combined_intro_cheer'),
        **combined_previews,
    }
    game_pools = {
        'Attack': ['sts2_attack'], 'shootBow': ['sts2_shootBow'],
        'Cast': ['game_cast_original', 'game_cast_link', 'game_cast_gesture'],
        'PowerUp': ['game_powerup_spin', 'game_powerup_step', 'game_powerup_ready'],
        'Intro': ['game_intro_cheer', 'game_intro_point'],
        'Victory': ['game_victory_original', 'game_victory_flute'],
        'Block': ['game_block'], 'Hit': ['game_hit'], 'Dead': ['game_dead'],
    }
    game_performances = {}
    for names in game_pools.values():
        for name in names:
            key = name.removeprefix('game_')
            key = {'sts2_attack': 'attack', 'sts2_shootBow': 'shootBow'}.get(key, key)
            performance = deepcopy(combined_previews['combined_' + key])
            performance['body_duration'] = performance['combat_effect'].get(
                'body_duration', performance.get('body_duration', 0))
            game_performances[name] = performance
    cast_voice = deepcopy(next(cue for cue in source['audio']['s100'] if cue['kind'] == 'voice'))
    cast_voice['paths'].extend(
        path for cue in source['audio']['Link1009601'] if cue['kind'] == 'voice' for path in cue['paths'])
    cast_voice.update(time=0, finish_on_idle=True)
    victory_voice = deepcopy(next(cue for cue in source['audio']['winpose'] if cue['kind'] == 'voice'))
    victory_voice['paths'].extend(
        path for cue in source['audio']['show_1_2'] if cue['kind'] == 'voice' for path in cue['paths'])
    shared_audio = {
        'Cast': [cast_voice],
        'PowerUp': combat['performances']['sts2_powerUp']['audio'],
        'Intro': combat['performances']['sts2_intro']['audio'],
        'Victory': [victory_voice],
    }
    for trigger, pool in shared_audio.items():
        for name in game_pools[trigger]:
            performance = game_performances[name]
            # These cues replace the segment voices, including the original cast and victory.
            for segment in performance['segments']:
                segment['action'] = ''
            performance['audio'] = deepcopy(pool)
    game_performances['game_cast_original']['audio'].extend(
        deepcopy([cue for cue in source['audio']['s100'] if cue['kind'] == 'sfx']))
    attack = game_performances['sts2_attack']
    attack.update(segments=[{'clip': 'draft_attack', 'action': '', 'duration': .42},
                            {'clip': 'stand', 'action': '', 'duration': .2, 'loop': True}],
                  body_duration=.42, audio=deepcopy(combat['performances']['sts2_attack']['audio']),
                  audio_at_start=True)
    hit_profile = attack['combat_effect']['hit_profile']
    attack['combat_effect'].update(runtime_live=True, clips=[{'id': '', 'start': 0, 'duration': 0}],
                                   attacks=[0], hit_events=[hit_profile['hit']],
                                   hit=hit_profile['hit'], duration=.62, return_at=.62)
    idle = deepcopy(combined_previews['combined_idle'])
    idle['segments'][0]['duration'] = 1.4
    idle['body_duration'] = 1.4
    game_performances['stand'] = idle
    music_clips = deepcopy(combined_previews['combined_attack']['combat_effect']['clips'])
    music_clips.extend(music_spectrum(row) for group in light_groups[1:] for row in group['clips'])
    write_json(ASSETS / 'action_drafts.json', {
        'animations': animations, 'performances': performances,
        'body_previews': body_previews, 'combined_previews': combined_previews,
        'game_performances': game_performances, 'game_pools': game_pools, 'music_clips': music_clips})
    write_json(ROOT / '02_构建产物/action_draft_sources.json', {
        'definitions': definitions, 'performances': performances,
        'note': 'Preview candidates. Exact source ranges use zero-based, end-exclusive frame indices.',
    })
    print('Built response action drafts:', len(performances))


if __name__ == '__main__':
    main()
