"""Copy catalogued user audio unchanged into the runtime asset library."""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / '00_用户素材/音频'
ASSETS = ROOT / '01_制作工程/Godot/Miku_Hcxmmx/Assets'


def main():
    entries = json.loads((SOURCE / 'catalog.json').read_text(encoding='utf-8'))['entries']
    catalog = {'melodies': {}, 'heavy': [], 'music': [], 'light_groups': [], 'emphasis_db': 3.0}
    light_groups = {}
    for entry in entries:
        if entry['role'] == 'battle_bgm':
            continue
        source = SOURCE / entry['path']
        destination = ASSETS / 'Audio/User' / entry['role'] / (entry['id'] + source.suffix.lower())
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        row = {'id': entry['id'], 'path': 'res://Miku_Hcxmmx/Assets/' + destination.relative_to(ASSETS).as_posix(),
               'duration': entry['duration_seconds'],
               'playback_gain_db': entry.get('playback_gain_db', 0.0)}
        if entry['role'].startswith('melody_'):
            catalog['melodies'][entry['role'].removeprefix('melody_')] = row
        elif entry['role'] == 'heavy_candidate':
            catalog['heavy'].append(row)
        elif entry['role'] == 'light_attack':
            light_groups.setdefault(entry['group_id'], []).append((entry['sequence'], row))
    for group_id, clips in light_groups.items():
        clips.sort(key=lambda item: item[0])
        if [order for order, _ in clips] != list(range(1, len(clips) + 1)):
            raise ValueError('Light attack group must have consecutive sequence numbers: ' + group_id)
        catalog['light_groups'].append({'id': group_id, 'clips': [row for _, row in clips]})
    (ASSETS / 'user_audio.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Imported user audio:', len(entries))


if __name__ == '__main__':
    main()
