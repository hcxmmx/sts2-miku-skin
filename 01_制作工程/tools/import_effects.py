"""Audit and bake the effect prefabs referenced by Miku and her helper logic."""
import collections
import csv
import hashlib
import json
import math
import pathlib
import zipfile

import numpy as np
import UnityPy
from UnityPy.classes import PPtr
from UnityPy.helpers.MeshHelper import MeshHandler

from import_miku import ROOT, SOURCE, ASSETS, write_json
from particle_math import curve, mm, color, vec, rotation, transform, shape_sample, birth_times, integrate
from effect_logic import effect_references

FPS = 30
DURATION = 10.0


def resolve(pointer, assets_file):
    return PPtr(**pointer, assetsfile=assets_file).deref() if pointer.get('m_PathID') else None


def object_key(obj):
    return obj.assets_file.name + ':' + str(obj.path_id)


def vector4(value, channels='rgba'):
    return np.array([value.get(axis, 1.0) for axis in channels], dtype=float)


class Extractor:
    def __init__(self):
        self.materials = []
        self.material_ids = {}
        self.meshes = {}
        self.textures = {}
        self.notes = collections.Counter()
        self.duration = DURATION

    def mesh(self, obj):
        key = object_key(obj)
        if key not in self.meshes:
            # APK built-in resources contain trailing bytes outside UnityPy's Mesh tree.
            builtin = obj.assets_file.name == 'unity default resources'
            helper = MeshHandler(obj.read(check_read=not builtin))
            if builtin:
                self.notes['builtin_mesh_relaxed_size_check'] += 1
            helper.process()
            self.meshes[key] = {
                'vertices': np.array(helper.m_Vertices, dtype=float),
                'uv': np.array(helper.m_UV0, dtype=float)[:, :2],
                'colors': np.array(helper.m_Colors, dtype=float) if helper.m_Colors else np.ones((len(helper.m_Vertices), 4)),
                'indices': [index for sub in helper.get_triangles() for triangle in sub for index in triangle],
            }
        return self.meshes[key]

    def material(self, obj):
        key = object_key(obj)
        if key in self.material_ids:
            return self.material_ids[key]
        raw = obj.read_typetree()
        properties = raw['m_SavedProperties']
        textures = dict(properties['m_TexEnvs'])
        texture_info = textures.get('_MainTex', {'m_Texture': {'m_PathID': 0},
                                                'm_Scale': {'x': 1, 'y': 1}, 'm_Offset': {'x': 0, 'y': 0}})
        tex_obj = resolve(texture_info['m_Texture'], obj.assets_file)
        tex_key = object_key(tex_obj) if tex_obj is not None else 'builtin_white'
        if tex_obj is None:
            self.textures[tex_key] = ''
            self.notes['null_main_texture_uses_white'] += 1
        if tex_key not in self.textures:
            data = tex_obj.read()
            filename = hashlib.sha256(tex_key.encode()).hexdigest()[:12] + '_' + data.m_Name + '.png'
            target = ASSETS / 'Effects' / filename
            target.parent.mkdir(parents=True, exist_ok=True)
            data.image.save(target)
            self.textures[tex_key] = 'res://Miku_Hcxmmx/Assets/Effects/' + filename
        floats = dict(properties['m_Floats'])
        colors = dict(properties['m_Colors'])
        if '_SolutionTex' in textures:
            self.notes['dissolve_material_uses_main_texture_preview'] += 1
        index = len(self.materials)
        self.material_ids[key] = index
        self.materials.append({'name': raw['m_Name'], 'texture': self.textures[tex_key],
                               'tint': colors.get('_TintColor', colors.get('_Color', dict(zip('rgba', [1] * 4)))),
                               'scale': [texture_info['m_Scale']['x'], texture_info['m_Scale']['y']],
                               'offset': [texture_info['m_Offset']['x'], texture_info['m_Offset']['y']],
                               'blend_src': floats.get('_BlendSrc', 5), 'blend_dst': floats.get('_BlendDst', 1)})
        return index

    def prefab(self, root):
        renderers = []
        self.control_duration = 0.0

        def walk(obj, chain, names, ancestors=(), force_active=False):
            key = object_key(obj)
            if key in ancestors:
                raise ValueError('Recursive effect prefab ' + key)
            raw = obj.read_typetree()
            components = [resolve(c['component'], obj.assets_file) for c in raw['m_Component']]
            tr_obj = next(c for c in components if c.type.name == 'Transform')
            tr = tr_obj.read_typetree()
            behaviours = []
            for component in components:
                if component.type.name == 'MonoBehaviour':
                    data = component.read_typetree()
                    script = resolve(data['m_Script'], component.assets_file)
                    if data.get('m_Enabled', 1):
                        behaviours.append({'class': script.read().m_ClassName, 'data': data})
            if any(b['class'] == 'NcDontActive' for b in behaviours):
                self.notes['NcDontActive_excluded'] += 1
                return
            if not raw['m_IsActive']:
                if not force_active:
                    return
                self.notes['inactive_node_enabled_by_replay'] += 1
            for behaviour in behaviours:
                data = behaviour['data']
                if behaviour['class'] == 'NcCurveAnimation':
                    self.control_duration = max(self.control_duration, data['m_fDelayTime'] + data['m_fDurationTime'])
                    for entry in data['m_CurveInfoList']:
                        if entry['m_bEnabled'] and entry['m_ApplyType'] in [5, 6]:
                            self.notes['animated_texture_uv_curve_pending'] += 1
                if behaviour['class'] == 'EffectSequence':
                    self.control_duration = max(self.control_duration, sum(item['m_duration'] for item in data['m_EffectBundleArray']))
                if behaviour['class'] not in ['EffectContainer', 'NcCurveAnimation', 'NcAutoDestruct',
                                               'NcDelayActive', 'NcAttachPrefab', 'NcUvAnimation', 'NcSpriteAnimation']:
                    self.notes['unsupported_script_' + behaviour['class']] += 1
            node = {'transform': tr, 'behaviours': behaviours}
            chain = chain + [node]
            names = names + '/' + raw['m_Name']
            by_type = {c.type.name: c for c in components}
            if 'Animation' in by_type or 'Animator' in by_type:
                self.notes['legacy_or_animator_tracks_pending'] += 1
            if 'MeshRenderer' in by_type and 'MeshFilter' in by_type:
                renderer = by_type['MeshRenderer'].read_typetree()
                mesh_pointer = by_type['MeshFilter'].read_typetree()['m_Mesh']
                valid_material = bool(renderer['m_Materials'] and renderer['m_Materials'][0]['m_PathID'])
                if not valid_material:
                    self.notes['null_material_renderer_excluded'] += 1
                if renderer['m_Enabled'] and mesh_pointer['m_PathID'] and valid_material:
                    renderers.append({'path': names, 'chain': chain, 'mesh': self.mesh(resolve(mesh_pointer, obj.assets_file)),
                                      'material': self.material(resolve(renderer['m_Materials'][0], obj.assets_file))})
            if 'ParticleSystem' in by_type and 'ParticleSystemRenderer' in by_type:
                particle = by_type['ParticleSystem'].read_typetree()
                renderer = by_type['ParticleSystemRenderer'].read_typetree()
                valid_material = bool(renderer['m_Materials'] and renderer['m_Materials'][0]['m_PathID'])
                if not valid_material:
                    self.notes['null_material_renderer_excluded'] += 1
                if renderer['m_Enabled'] and valid_material:
                    mesh = self.mesh(resolve(renderer['m_Mesh'], obj.assets_file)) if renderer['m_Mesh']['m_PathID'] else {
                        'vertices': np.array([[-.5, -.5, 0], [.5, -.5, 0], [.5, .5, 0], [-.5, .5, 0]]),
                        'uv': np.array([[0, 0], [1, 0], [1, 1], [0, 1]]),
                        'colors': np.ones((4, 4)), 'indices': [0, 1, 2, 0, 2, 3]}
                    rng = np.random.default_rng(int(hashlib.sha256(names.encode()).hexdigest()[:8], 16))
                    initial = particle['InitialModule']
                    particles = []
                    def distance_at(time):
                        matrix, _ = node_state(chain, time)
                        return matrix[:3, 3] if matrix is not None else np.zeros(3)

                    moving_emission = particle['EmissionModule']['rateOverDistance'].get('scalar', 0) > 0
                    for born in birth_times(particle, rng, self.duration, distance_at if moving_emission else None):
                        random = rng.random(12)
                        position, direction = shape_sample(particle['ShapeModule'], rng)
                        particles.append({'born': born, 'random': random, 'position': position, 'direction': direction,
                                          'life': mm(initial['startLifetime'], r=random[0]),
                                          'speed': mm(initial['startSpeed'], r=random[1]),
                                          'size': np.array([mm(initial['startSize'], r=random[2]),
                                                            mm(initial['startSizeY'], r=random[3]) if initial['size3D'] else mm(initial['startSize'], r=random[2]),
                                                            mm(initial['startSizeZ'], r=random[4]) if initial['size3D'] else mm(initial['startSize'], r=random[2])]),
                                          'angles': np.array([mm(initial['startRotationX'], r=random[5]) if initial['rotation3D'] else 0,
                                                              mm(initial['startRotationY'], r=random[6]) if initial['rotation3D'] else 0,
                                                              mm(initial['startRotation'], r=random[7])]),
                                          'color': color(initial['startColor'], 0, random[8])})
                    for module in ['NoiseModule', 'ForceModule', 'SubModule', 'TrailModule']:
                        if particle[module].get('enabled'):
                            self.notes['particle_' + module + '_pending'] += 1
                    if particle['EmissionModule']['rateOverDistance'].get('scalar', 0) > 0:
                        self.notes['distance_emission_sampled'] += 1
                    renderers.append({'path': names, 'chain': chain, 'mesh': mesh,
                                      'material': self.material(resolve(renderer['m_Materials'][0], obj.assets_file)),
                                      'particle': particle, 'particles': particles,
                                      'mesh_particle': bool(renderer['m_Mesh']['m_PathID'])})
            for child in tr['m_Children']:
                child_transform = resolve(child, obj.assets_file).read_typetree()
                walk(resolve(child_transform['m_GameObject'], obj.assets_file), chain, names, ancestors + (key,), force_active)
            for behaviour in behaviours:
                data = behaviour['data']
                for pointer_name in ['mEffectPrefab', 'm_AttachPrefab']:
                    if data.get(pointer_name, {}).get('m_PathID'):
                        attached_chain = chain
                        if pointer_name == 'm_AttachPrefab':
                            delay = data.get('m_fDelayTime', 0)
                            gate = {'transform': {'m_LocalPosition': data.get('m_AddStartPos', dict(x=0, y=0, z=0)),
                                                 'm_LocalScale': dict(x=1, y=1, z=1),
                                                 'm_LocalRotation': dict(x=0, y=0, z=0, w=1)},
                                    'behaviours': [], 'attachment_delay': delay}
                            attached_chain = chain + [gate]
                            if data.get('m_nRepeatCount', 1) != 1 or data.get('m_fPrefabSpeed', 1) != 1:
                                self.notes['attachment_repeat_or_speed_pending'] += 1
                        walk(resolve(data[pointer_name], obj.assets_file), attached_chain, names, ancestors + (key,), True)

        # EffectPoolManager.ReActiveEffect -> RunReplayEffect -> SetActiveRecursively.
        walk(root, [], '', force_active=True)
        return renderers


def node_state(chain, time):
    matrix = np.eye(4)
    tint = np.ones(4)
    for node in chain:
        time -= node.get('attachment_delay', 0)
        if time < 0:
            return None, tint
        tr = node['transform']
        local = transform([tr])
        scale_delta = np.ones(3)
        rotate_delta = np.zeros(3)
        for behaviour in node['behaviours']:
            data = behaviour['data']
            kind = behaviour['class']
            if kind == 'NcDelayActive' and time < data['m_fDelayTime']:
                return None, tint
            if kind == 'NcAutoDestruct' and data['m_fLifeTime'] > 0 and time >= data['m_fLifeTime']:
                return None, tint
            if kind != 'NcCurveAnimation':
                continue
            delay = data['m_fDelayTime']
            duration = max(data['m_fDurationTime'], .001)
            if time < delay or data['m_bAutoDestruct'] and time >= delay + duration:
                return None, tint
            fraction = np.clip((time - delay) / duration, 0, 1)
            for entry in data['m_CurveInfoList']:
                if not entry['m_bEnabled']:
                    continue
                value = curve(entry['m_AniCurve'], fraction)
                options = entry['m_bApplyOption']
                scaled = value * entry['m_fValueScale']
                apply = entry['m_ApplyType']
                for axis in range(3):
                    if options[axis] and apply == 1:
                        local[axis, 3] += scaled
                    if options[axis] and apply == 2:
                        rotate_delta[axis] += math.radians(scaled)
                    if options[axis] and apply == 3:
                        scale_delta[axis] *= 1 + scaled
                if apply in [4, 8]:
                    start, end = vector4(entry['m_FromColor'], 'xyzw'), vector4(entry['m_ToColor'], 'xyzw')
                    for axis in range(4):
                        if options[axis]:
                            tint[axis] *= start[axis] + (end[axis] - start[axis]) * value
        local[:3, :3] = local[:3, :3] @ rotation(*rotate_delta) @ np.diag(scale_delta)
        matrix = matrix @ local
    return matrix, tint


def geometry(renderer, time, material):
    matrix, tint = node_state(renderer['chain'], time)
    if matrix is None or tint[3] <= .001:
        return None
    mesh = renderer['mesh']
    time -= sum(node.get('attachment_delay', 0) for node in renderer['chain'])
    parts = []
    if 'particle' not in renderer:
        parts.append((mesh['vertices'] @ matrix[:3, :3].T + matrix[:3, 3], mesh['uv'], mesh['colors'] * tint))
    else:
        ps = renderer['particle']
        local_time = time * ps['simulationSpeed']
        for particle in renderer['particles']:
            age = local_time - particle['born']
            if not 0 <= age < particle['life']:
                continue
            fraction = age / max(.001, particle['life'])
            random = particle['random']
            rgba = particle['color'] * tint
            if ps['ColorModule']['enabled']:
                rgba *= color(ps['ColorModule']['gradient'], fraction, random[9])
            size = particle['size'].copy()
            if ps['SizeModule']['enabled']:
                mod = ps['SizeModule']
                size *= [mm(mod['curve'], fraction, random[2]),
                         mm(mod['y'], fraction, random[3]) if mod['separateAxes'] else mm(mod['curve'], fraction, random[2]),
                         mm(mod['z'], fraction, random[4]) if mod['separateAxes'] else mm(mod['curve'], fraction, random[2])]
            angle = particle['angles'].copy()
            mod = ps['RotationModule']
            if mod['enabled']:
                angle += [integrate(mod['x'], fraction, random[5]) * age if mod['separateAxes'] else 0,
                          integrate(mod['y'], fraction, random[6]) * age if mod['separateAxes'] else 0,
                          integrate(mod['curve'], fraction, random[7]) * age]
            position = particle['position'] + particle['direction'] * particle['speed'] * age
            mod = ps['VelocityModule']
            if mod['enabled']:
                position += np.array([integrate(mod[key], fraction, random[10]) * age for key in ['x', 'y', 'z']])
            position[1] -= .5 * 9.81 * mm(ps['InitialModule']['gravityModifier'], fraction, random[11]) * age * age
            local = (mesh['vertices'] * size) @ rotation(*angle).T
            center = matrix[:3, :3] @ position + matrix[:3, 3]
            world = local @ matrix[:3, :3].T + center if renderer['mesh_particle'] else local * np.linalg.norm(matrix[:3, :3], axis=0) + center
            uv = mesh['uv'].copy()
            mod = ps['UVModule']
            if mod['enabled']:
                columns, rows = max(1, mod['tilesX']), max(1, mod['tilesY'])
                frame = int(mm(mod['frameOverTime'], fraction, random[8]) * columns * rows * mod.get('cycles', 1) + mm(mod['startFrame'])) % (columns * rows)
                uv = (uv + [frame % columns, frame // columns]) / [columns, rows]
            parts.append((world, uv, mesh['colors'] * rgba))
    if not parts:
        return None
    vertices, uvs, colors, indices = [], [], [], []
    base_color = vector4(material['tint'])
    for world, uv, rgba in parts:
        indices.extend(index + len(vertices) for index in mesh['indices'])
        vertices.extend(np.stack([world[:, 0] * 100, -world[:, 1] * 100], axis=1).round(4).tolist())
        uv = uv * material['scale'] + material['offset']
        for node in renderer['chain']:
            for behaviour in node['behaviours']:
                data = behaviour['data']
                if behaviour['class'] == 'NcUvAnimation' and time >= data.get('m_fDelay', 0):
                    uv = uv * [data['m_fTilingX'], data['m_fTilingY']]
                    uv += [data['m_fOffsetX'] + data['m_fScrollSpeedX'] * (time - data.get('m_fDelay', 0)),
                           data['m_fOffsetY'] + data['m_fScrollSpeedY'] * (time - data.get('m_fDelay', 0))]
                if behaviour['class'] == 'NcSpriteAnimation' and data['m_TextureType'] == 0:
                    elapsed = time - data['m_fDelayTime']
                    if elapsed < 0:
                        return None
                    count = max(1, data['m_nFrameCount'])
                    frame = int(elapsed * data['m_fFps'])
                    if frame >= count and data['m_bAutoDestruct'] and not data['m_bLoop']:
                        return None
                    frame = data['m_nStartFrame'] + (frame % count if data['m_bLoop'] else min(frame, count - 1))
                    columns, rows = max(1, data['m_nTilingX']), max(1, data['m_nTilingY'])
                    uv = (uv + [frame % columns, rows - 1 - frame // columns]) / [columns, rows]
        uv[:, 1] = 1 - uv[:, 1]
        uvs.extend(uv.round(6).tolist())
        colors.extend(np.clip(rgba * base_color, 0, 1).round(5).tolist())
    return {'material': renderer['material'], 'vertices': vertices, 'uv': uvs, 'colors': colors, 'indices': indices}


def main():
    manifest = json.loads((SOURCE / 'Recovered_AssetBundles/iOS_manifest.json').read_text())
    names = dict(manifest['AssetBundleNames'])
    infos = dict(manifest['AssetBundleInfos'])
    ids = {name: key for key, name in names.items()}
    selected = set()
    references = effect_references()
    effect_paths = {row['effect']: 'assetbundle/effect/show/' + row['effect'] for row in references}
    pending = list(effect_paths.values())
    while pending:
        name = pending.pop()
        if name not in selected:
            selected.add(name)
            pending.extend(names[key] for key in infos[ids[name]]['AssetBundleDependencies'])
    env = UnityPy.Environment()
    for name in sorted(selected):
        env.load_file(str(SOURCE / 'Recovered_AssetBundles/iOS_3.0.1' / name))
    with zipfile.ZipFile(next(ROOT.glob('*.apk'))) as apk:
        env.load_file(apk.read('assets/bin/Data/unity default resources'), name='unity default resources')
    extractor = Extractor()
    output = {}
    report = {}
    for path, pointer in env.container.items():
        name = next((name for name, bundle in effect_paths.items() if path.lower().endswith('/' + name + '.prefab')), None)
        if name is None or name in output or not path.endswith('.prefab'):
            continue
        before = extractor.notes.copy()
        renderers = extractor.prefab(pointer.deref())
        end_times = []
        for renderer in renderers:
            limits = [DURATION]
            for node in renderer['chain']:
                for behaviour in node['behaviours']:
                    data = behaviour['data']
                    if behaviour['class'] == 'NcAutoDestruct' and data['m_fLifeTime'] > 0:
                        limits.append(data['m_fLifeTime'])
                    if behaviour['class'] == 'NcCurveAnimation' and data['m_bAutoDestruct']:
                        limits.append(data['m_fDelayTime'] + data['m_fDurationTime'])
            if 'particles' in renderer:
                limits.append(max((p['born'] + p['life'] for p in renderer['particles']), default=0))
            end_times.append(min(limits))
        duration = max(1 / FPS, max(end_times, default=extractor.control_duration))
        frames = []
        for index in range(math.ceil(duration * FPS)):
            draws = []
            for renderer in renderers:
                draw = geometry(renderer, index / FPS, extractor.materials[renderer['material']])
                if draw is not None:
                    draws.append(draw)
            frames.append(draws)
        baked_path = ASSETS / 'Effects/Baked' / (name + '.json')
        write_json(baked_path, {'frames': frames})
        draw_count = sum(len(frame) for frame in frames)
        output[name] = {'frames_path': 'res://Miku_Hcxmmx/Assets/Effects/Baked/' + name + '.json',
                        'frame_count': len(frames), 'source_renderers': len(renderers),
                        'max_draws': max(len(frame) for frame in frames), 'draw_count': draw_count}
        report[name] = {**output[name], 'notes': dict(extractor.notes - before)}
        print(name, len(renderers), 'renderers', sum(len(frame) for frame in frames), 'draws')
    if len(output) != len(effect_paths):
        raise ValueError('Missing effect prefabs ' + str(set(effect_paths) - set(output)))
    write_json(ASSETS / 'effects.json', {'fps': FPS, 'materials': extractor.materials, 'effects': output})
    write_json(ROOT / '02_构建产物/effect_conversion.json', {
        'source_bundles': sorted(selected), 'effects': report, 'references': references,
        'notes': dict(extractor.notes), 'projection': 'Orthographic Unity XY to Godot XY, 100 pixels per unit',
        'sampling_helpers': 'Adapted from SchneiderSkin/tools/particle_core.py',
    })
    with (ROOT / '02_构建产物/Miku_Effect_References.csv').open('w', encoding='utf-8-sig', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=['actor', 'action', 'field', 'effect', 'source'])
        writer.writeheader()
        for row in references:
            writer.writerow({**row, 'source': json.dumps(row['source'], ensure_ascii=False)})


if __name__ == '__main__':
    main()
