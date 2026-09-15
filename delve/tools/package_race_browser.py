"""Bundle existing PNG bytes and metadata into an offline wardrobe explorer."""
import base64
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'design' / 'race-identities'
catalog = json.loads((out / 'wardrobe.json').read_text(encoding='utf-8'))
recipes = json.loads((out / 'recipes.json').read_text(encoding='utf-8'))
weapon_path = out / 'weapons' / 'manifest.json'
weapons = json.loads(weapon_path.read_text(encoding='utf-8')) if weapon_path.exists() else []
for race in catalog:
    existing = {layer['id'] for layer in race['layers']}
    race['layers'].extend(w for w in weapons if w['race'] == race['race'] and w['id'] not in existing)
    race['layers'].sort(key=lambda layer: layer['order'])
images = {}
ids = set()
for race in catalog:
    for layer in race['layers']:
        assert layer['id'] not in ids
        ids.add(layer['id'])
        images[layer['id']] = 'data:image/png;base64,' + base64.b64encode(
            (out / layer['file']).read_bytes()).decode('ascii')
for recipe in recipes:
    assert set(recipe['layers'] + recipe['gear']) <= ids
    assert (out / 'masters' / (recipe['id'] + '.aseprite')).exists()
weapon_library = []
for weapon in weapons:
    if weapon['race'] != 'Human':
        continue
    isolated = out / weapon['file'].replace('.png', '-isolated.png')
    weapon_library.append(dict(key=weapon['id'].removeprefix('human-weapon-'), name=weapon['name'],
        image='data:image/png;base64,' + base64.b64encode(isolated.read_bytes()).decode('ascii')))
data = json.dumps(dict(catalog=catalog, recipes=recipes, images=images, weaponLibrary=weapon_library), ensure_ascii=True)
template = (root / 'tools' / 'race_identity_browser.html').read_text(encoding='utf-8')
(out / 'index.html').write_text(template.replace('/*__DATA__*/', 'const DATA=' + data + ';'), encoding='utf-8')
print(f'Packaged {len(recipes)} identities, {len(catalog)} races and {len(images)} layers. No server or network needed.')
