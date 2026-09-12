"""Copy approved poses/idles and update their authored rest clips.

Run from anywhere. Placement and other clips are preserved. Idle timing
manifests refresh the rest clip and textures from Aseprite exports.
"""
from pathlib import Path
import shutil
import json
import re
from enemy_sprite_sources import SOURCES, runtime_folder

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'assets/sprites/enemies'


def definition(folder, textures, margin, speed=6.0):
    target = ASSETS / folder / 'sprite.tres'
    if target.exists():
        return
    lines = [f'[gd_resource type="Resource" script_class="EnemySpriteDefinition" load_steps={len(textures) + 3} format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data/EnemySpriteDefinition.cs" id="script"]']
    for i, texture in enumerate(textures):
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{folder}/{texture}" id="frame_{i}"]')
    lines += ['', '[sub_resource type="SpriteFrames" id="Frames"]', 'animations = [{', '"frames": [']
    lines += [f'{{"duration": 1.0, "texture": ExtResource("frame_{i}")}}' + (',' if i < len(textures)-1 else '') for i in range(len(textures))]
    lines += ['],', '"loop": true,', '"name": &"rest",', f'"speed": {speed}', '}]', '', '[resource]',
              'script = ExtResource("script")', 'Frames = SubResource("Frames")', 'IdleAnimation = &"rest"',
              'PixelSize = 0.02', f'FootMarginPixels = {float(margin)}', 'FacesRight = true', '']
    target.write_text('\n'.join(lines), encoding='utf-8')


for kind, margin in SOURCES:
    folder = runtime_folder(kind)
    (ASSETS / folder).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / f'design/{kind}-base/{kind}-base.png', ASSETS / folder / 'base.png')
    definition(folder, ['base.png'], margin)
    timing_path = ROOT / f'design/{kind}-base/idle-timing.json'
    if timing_path.exists():
        timing = json.loads(timing_path.read_text())
        target = ASSETS / folder / 'sprite.tres'
        content = target.read_text(encoding='utf-8-sig')
        # Replace only the authored rest clip; preserve placement and other clips.
        content = re.sub(r'^\[ext_resource .* id="idle_\d+"\]\n', '', content, flags=re.M)
        refs, frames = [], []
        for i, weight in enumerate(timing['weights'], 1):
            name = f'idle_{i}.png'
            shutil.copyfile(timing_path.parent / name, ASSETS / folder / name)
            refs.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{folder}/{name}" id="idle_{i}"]')
            frames.append(f'{{"duration": {float(weight)}, "texture": ExtResource("idle_{i}")}}')
        content = content.replace('[sub_resource type="SpriteFrames"', '\n'.join(refs) + '\n\n[sub_resource type="SpriteFrames"', 1)
        clip = '{\n"frames": [\n' + ',\n'.join(frames) + '\n],\n"loop": true,\n"name": &"rest",\n"speed": ' + str(float(timing['fps'])) + '\n}'
        content, count = re.subn(r'\{\s*"frames":\s*\[[^\]]*\],\s*"loop":\s*\w+,\s*"name":\s*&"rest",\s*"speed":\s*[\d.]+\s*\}', lambda _: clip, content, count=1, flags=re.S)
        if count != 1:
            raise ValueError(f'{target}: expected an authored rest clip')
        steps = content.count('[ext_resource ') + content.count('[sub_resource ') + 1
        content = re.sub(r'load_steps=\d+', f'load_steps={steps}', content)
        content = re.sub(r'\n{3,}', '\n\n', content)
        target.write_text(content, encoding='utf-8')

for folder in ['rat_v1', 'rat_v2', 'rat_v3', 'placeholder_small', 'placeholder_medium', 'placeholder_large']:
    definition(folder, [p.name for p in sorted((ASSETS / folder).glob('idle_*.png'))], 4,
               speed=4.5 if folder.startswith('rat_') else 6.0)
