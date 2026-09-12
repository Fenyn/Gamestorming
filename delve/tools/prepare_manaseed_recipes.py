"""Resolve Delve's actual Mana Seed recipes. Does not edit runtime art."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = Path('F:/UnityNVME/Art/Sprites/Mana Seed')
# Recovered from Delve's current pixels, not the older Bulwark recipe.
RECIPES = {
    'aldric': ('veteran', {'0bas':'humn_v04','1out':'pfpn_v02','4har':'dap1_v11'}),
    'elara': ('rogue', {'0bas':'humn_v02','1out':'fstr_v03','4har':'pon1_v07'}),
    'tharr': ('cleric', {'0bas':'humn_v06','1out':'bksm_v03','4har':'flat_v00'}),
    'fenwick': ('wizard', {'0bas':'humn_v03','1out':'alch_v04','5hat':'pnty_v01'}),
}
PAGES = {'p1':('p1',{}),'p2':('p2',{'6tla':'farm_v01'}),
         'p2_mine':('p2',{'6tla':'mine_v01'}),'p2_wood':('p2',{'6tla':'wood_v01'})}
index = {}
for p in sorted(PACK.rglob('char_a_*.png')):
    index.setdefault(p.name,p)
records=[]
for name,(folder,recipe) in RECIPES.items():
    for dest,(page,extras) in PAGES.items():
        layers=[]
        for slot,asset in (recipe | extras).items():
            filename=f'char_a_{page}_{slot}_{asset}.png'
            if filename not in index: raise FileNotFoundError(filename)
            layers.append({'slot':slot,'asset':asset,'source':str(index[filename])})
        records.append({'name':name,'folder':folder,'page':dest,'layers':layers})
out=ROOT/'design/manaseed-identities'
out.mkdir(parents=True,exist_ok=True)
(out/'source-recipes.json').write_text(json.dumps(records,indent=2),encoding='utf8')
print(f'Resolved {len(records)} page recipes')
