"""Read-only source matching; writes recipe evidence, never image pixels."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = Path('F:/UnityNVME/Art/Sprites/Mana Seed')
heroes = {'aldric':'veteran','elara':'rogue','tharr':'cleric','fenwick':'wizard'}
targets = {name:np.asarray(Image.open(ROOT/f'assets/sprites/heroes/{folder}/p1.png').convert('RGBA'))[:, :64] for name,folder in heroes.items()}
scores = {name:{} for name in heroes}
for p in PACK.rglob('char_a_p1_*.png'):
    fields=p.stem.split('_')
    if len(fields)!=6 or fields[3] not in ('0bas','1out','2clo','3fac','4har','5hat'):
        continue
    a=np.asarray(Image.open(p).convert('RGBA'))
    if a.shape!=(512,512,4): continue
    a=a[:,:64]; mask=a[:,:,3]>0; count=int(mask.sum())
    if not count: continue
    for name,t in targets.items():
        matching=int((np.all(a==t,axis=2)&mask).sum())
        scores[name].setdefault(fields[3],[]).append((round(matching/count,5),matching,count,str(p)))
for name,slots in scores.items():
    print(name)
    for slot,rows in slots.items():
        slots[slot]=sorted(rows,reverse=True)[:4]
        print(slot,[(r[0],r[1],Path(r[3]).name,Path(r[3]).parts[-4]) for r in slots[slot][:2]])
(ROOT/'design/manaseed-identities/matching-evidence.json').write_text(json.dumps(scores,indent=2),encoding='utf8')
