"""Prepare a temporary browser page that checks canvas output against Aseprite."""
import base64
import json
from pathlib import Path

out = Path(__file__).resolve().parents[1] / 'design' / 'race-identities'
expected = {p.stem: 'data:image/png;base64,' + base64.b64encode(p.read_bytes()).decode()
            for p in (out / 'previews').glob('*.png')}
for p in (out / 'weapons').glob('*-equipped.png'):
    expected[p.stem] = 'data:image/png;base64,' + base64.b64encode(p.read_bytes()).decode()
for p in (out / 'weapons').glob('*-dual.png'):
    expected[p.stem] = 'data:image/png;base64,' + base64.b64encode(p.read_bytes()).decode()
script = r'''
const EXPECTED=__EXPECTED__;
(async()=>{
 try{
  await ready;
  if(document.querySelectorAll('#lineup .card').length!==11)throw Error('Preset cards did not load');
  let checked=0;
  for(const p of DATA.recipes){
   loadPreset(p);
   for(const gear of [true,false]){
    const expected=new Image();await new Promise((resolve,reject)=>{expected.onload=resolve;expected.onerror=reject;expected.src=EXPECTED[p.id+(gear?'':'-wardrobe')];});
    const c=document.createElement('canvas');c.width=128;c.height=96;c.getContext('2d').drawImage(expected,0,0);
    const a=c.getContext('2d').getImageData(0,0,128,96).data;
    const b=rawCanvas(race,selected,gear).getContext('2d').getImageData(0,0,128,96).data;
    if(a.some((v,i)=>v!==b[i]))throw Error('Pixel mismatch '+p.id+' gear='+gear);
    checked++;
   }
  }
  for(const r of DATA.catalog){
   const p=DATA.recipes.find(p=>p.id===({Human:'player',Elf:'elara',Dwarf:'tharr',Orc:'arkus'})[r.race]);
   loadPreset(p);
   for(const weapon of r.layers.filter(l=>l.master&&l.group==='Weapons')){
    const ids=new Set([...p.layers,weapon.id]);
    const im=new Image();await new Promise((resolve,reject)=>{im.onload=resolve;im.onerror=reject;im.src=EXPECTED[weapon.id+'-equipped'];});
    const c=document.createElement('canvas');c.width=128;c.height=96;c.getContext('2d').drawImage(im,0,0);
    const a=c.getContext('2d').getImageData(0,0,128,96).data;
    const b=rawCanvas(r,ids).getContext('2d').getImageData(0,0,128,96).data;
    if(a.some((v,i)=>v!==b[i]))throw Error('Weapon composite mismatch '+weapon.id);
    checked++;
   }
  }
  loadPreset(DATA.recipes.find(p=>p.id==='elara'));
  for(const weapon of race.layers.filter(l=>l.group==='Offhand Weapons')){
   const control=document.querySelector('select[aria-label="Off-hand weapon"]');
   control.value=weapon.id;control.dispatchEvent(new Event('change'));
   const im=new Image();await new Promise((resolve,reject)=>{im.onload=resolve;im.onerror=reject;im.src=EXPECTED[weapon.id+'-dual'];});
   const c=document.createElement('canvas');c.width=128;c.height=96;c.getContext('2d').drawImage(im,0,0);
   const a=c.getContext('2d').getImageData(0,0,128,96).data;
   const b=rawCanvas(race,selected).getContext('2d').getImageData(0,0,128,96).data;
   if(a.some((v,i)=>v!==b[i]))throw Error('Offhand mismatch '+weapon.id);
   checked++;
  }
  let shield=document.querySelector('select[aria-label="Shield"]');shield.value='elf-01';shield.dispatchEvent(new Event('change'));
  if(race.layers.some(l=>l.group==='Offhand Weapons'&&selected.has(l.id)))throw Error('Shield/offhand conflict');
  const offhand=document.querySelector('select[aria-label="Off-hand weapon"]');offhand.value='elf-offhand-shortsword';offhand.dispatchEvent(new Event('change'));
  if(race.layers.some(l=>l.group.startsWith('Shields')&&selected.has(l.id)))throw Error('Offhand/shield conflict');
  const none=document.querySelector('select[aria-label="Off-hand weapon"]');none.value='';none.dispatchEvent(new Event('change'));
  if(resolvedLayers(race,selected).has('elf-offhand-fingers'))throw Error('Offhand grip not cleared');
  $('race').value='Orc';$('race').dispatchEvent(new Event('change'));
  if(race.race!=='Orc')throw Error('Race change failed');
  const hair=document.querySelector('select[aria-label="Hair"]');hair.value='orc-15';hair.dispatchEvent(new Event('change'));
  if(!selected.has('orc-15')||selected.has('orc-14')||!dirty)throw Error('Hair swap failed');
  const cards=document.querySelectorAll('#weaponLibrary .weapon-card');
  if(cards.length!==8)throw Error('Weapon cards missing');
  cards[0].click();
  if(!selected.has('orc-weapon-rapier')||$('weaponMaster').classList.contains('hidden'))throw Error('Weapon equip/master link failed');
  $('mode').value='silhouette';render();
  const silhouette=$('preview').getContext('2d').getImageData(0,0,128,96).data;
  for(let i=0;i<silhouette.length;i+=4)if(silhouette[i+3]&&silhouette[i]!==221)throw Error('Silhouette mode failed');
  $('mode').value='color';loadPreset(DATA.recipes[0]);
  document.documentElement.dataset.check='PASS';
  const result=document.createElement('p');result.id='verification-result';result.textContent='PASS: '+checked+' canvas composites match Aseprite; race switch, hair swap and silhouette checks pass.';document.body.prepend(result);
 }catch(e){document.documentElement.dataset.check='FAIL';const p=document.createElement('pre');p.id='verification-result';p.textContent=e.stack;document.body.prepend(p);}
})();
'''.replace('__EXPECTED__', json.dumps(expected))
html = (out / 'index.html').read_text(encoding='utf-8')
(out / 'browser-check.html').write_text(html.replace('</body>', '<script>' + script + '</script></body>'), encoding='utf-8')
print('Prepared browser-check.html')
