"""Export Aseprite attack PNGs and timing into existing sprite libraries."""
import json
import re
import shutil
from pathlib import Path
from enemy_sprite_sources import SOURCES, runtime_folder

ROOT = Path(__file__).resolve().parent.parent
for kind, _ in SOURCES:
    source = ROOT / f'design/{kind}-base'
    folder = runtime_folder(kind)
    dest = ROOT / f'assets/sprites/enemies/{folder}'
    timing = json.loads((source / 'attack-timing.json').read_text())
    target = dest / 'sprite.tres'
    text = target.read_text(encoding='utf-8-sig')
    text = re.sub(r'^\[ext_resource .* id="attack_\d+"\]\n', '', text, flags=re.M)
    refs, frames = [], []
    for i, weight in enumerate(timing['weights'], 1):
        name = f'attack_{i}.png'
        shutil.copyfile(source / name, dest / name)
        refs.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{folder}/{name}" id="attack_{i}"]')
        frames.append(f'{{"duration": {float(weight)}, "texture": ExtResource("attack_{i}")}}')
    text = text.replace('[sub_resource type="SpriteFrames"', '\n'.join(refs) + '\n\n[sub_resource type="SpriteFrames"', 1)
    clip = '{\n"frames": [\n' + ',\n'.join(frames) + '\n],\n"loop": false,\n"name": &"attack",\n"speed": ' + str(float(timing['fps'])) + '\n}'
    pattern = r'\{\s*"frames":\s*\[[^\]]*\],\s*"loop":\s*\w+,\s*"name":\s*&"attack",\s*"speed":\s*[\d.]+\s*\}'
    text, count = re.subn(pattern, lambda _: clip, text, count=1, flags=re.S)
    if not count:
        text = text.replace('animations = [', 'animations = [' + clip + ', ', 1)
    text = re.sub(r'^Attack(?:Animation|ImpactFrame) = .*\n', '', text, flags=re.M)
    text += f'AttackAnimation = &"attack"\nAttackImpactFrame = {timing["impact_frame"]}\n'
    steps = text.count('[ext_resource ') + text.count('[sub_resource ') + 1
    text = re.sub(r'load_steps=\d+', f'load_steps={steps}', text)
    target.write_text(re.sub(r'\n{3,}', '\n\n', text), encoding='utf-8')
