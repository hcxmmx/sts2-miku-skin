"""Trace effect events through the recovered main actor and helper action logic."""
import json

from import_miku import SOURCE


def load_actions():
    return {
        name: {row['name']: row for row in json.loads(
            (SOURCE / 'Parsed' / filename).read_text(encoding='utf-8'))['action']}
        for name, filename in [('main', 'miku.json'), ('helper', 'mikuBullet.json')]
    }


def effect_references():
    records = []
    for actor, actions in load_actions().items():
        for name, action in actions.items():
            for field in ['addEffects', 'hitEffects']:
                for effect in action.get(field, []):
                    records.append({'actor': actor, 'action': name, 'field': field,
                                    'effect': effect['name'].lower(), 'source': effect})
    manifest = json.loads((SOURCE / 'Recovered_AssetBundles/iOS_manifest.json').read_text(encoding='utf-8'))
    referenced = {row['effect'] for row in records}
    prefix = 'assetbundle/effect/show/'
    for _, path in manifest['AssetBundleNames']:
        name = path.removeprefix(prefix)
        if path.startswith(prefix + 'miku/') and name not in referenced:
            records.append({'actor': '', 'action': '', 'field': 'inventory_only',
                            'effect': name, 'source': {'name': name}})
    return records


def compile_timeline(segments, animations):
    actions = load_actions()
    events = []
    unresolved = []

    def visit(actor, name, start, anchor, offset, ancestors):
        key = (actor, name)
        if key in ancestors:
            return
        if name not in actions[actor]:
            unresolved.append({'actor': actor, 'action': name, 'reason': 'missing action'})
            return
        action = actions[actor][name]
        if action.get('dropEndAction'):
            unresolved.append({'actor': actor, 'action': name, 'reason': 'landing-dependent transition',
                               'next': action['dropEndAction']})
        for field in ['addEffects', 'hitEffects']:
            for effect in action.get(field, []):
                position = effect.get('position', {})
                off = effect.get('offPosition', {})
                hit = field == 'hitEffects'
                # Hit coordinates are a diagnostic target baseline. Preserve the raw data.
                xy = ([off.get('x', 0), off.get('y', 0)] if hit else
                      [offset[0] + position.get('x', 0), offset[1] - position.get('y', 0)])
                events.append({'effect': effect['name'].lower(), 'start': start + effect.get('start', 0),
                               'anchor': 'target' if hit else anchor, 'offset': xy,
                               'scale': [effect.get('scale', {}).get('x', 1), effect.get('scale', {}).get('y', 1)],
                               'layer': effect.get('behindRole', 0), 'conditional_hit': hit,
                               'random_play': effect.get('randomPlay', False),
                               'actor': actor, 'action': name, 'source': effect})
        for role in action.get('addRoles', []):
            position = role.get('position', {})
            option = position.get('posOption', 0)
            child_anchor = {3: 'stage', 9: 'target'}.get(option, anchor)
            xy = position.get('position', {})
            child_offset = [xy.get('x', 0), -xy.get('y', 0)]
            if child_anchor == anchor:
                child_offset = [offset[i] + child_offset[i] for i in range(2)]
            for child in role.get('startActions', []):
                child_start = start + role.get('start', 0)
                visited = set()
                while child in actions['helper'] and child not in visited:
                    visited.add(child)
                    visit('helper', child, child_start, child_anchor, child_offset, ancestors + (key,))
                    data = actions['helper'][child]
                    clip = data.get('animate', child)
                    if clip in animations:
                        length = len(animations[clip]['frames']) * animations[clip]['delay']
                    else:
                        try:
                            length = float(clip)
                        except ValueError:
                            unresolved.append({'actor': 'helper', 'action': child,
                                               'reason': 'duration requires runtime control', 'animation': clip})
                            break
                    child_start += length
                    child = data.get('nextAction', '')

    start = 0.0
    for segment in segments:
        visit('main', segment['action'], start, 'self', [0, 0], ())
        start += segment['duration']
    return {'events': sorted(events, key=lambda event: event['start']), 'unresolved': unresolved}
