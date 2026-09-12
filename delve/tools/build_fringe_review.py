"""Build a portable browser review of the enemy PNGs at a shared pixel scale."""
import base64
import json
import struct
from pathlib import Path

from enemy_sprite_sources import SOURCES, runtime_folder

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'design/fringe-sprite-review'


def png(path):
    data = path.read_bytes()
    width, height = struct.unpack('>II', data[16:24])
    return {'src': 'data:image/png;base64,' + base64.b64encode(data).decode(),
            'width': width, 'height': height}


units = []
rat_dir = ROOT / 'assets/sprites/enemies/rat_v1'
units.append({'name': 'Giant Rat', 'new': False, 'margin': 2,
              'base': png(rat_dir / 'idle_1.png'),
              'rest': {'frames': [png(p) for p in sorted(rat_dir.glob('idle_*.png'))],
                       'seconds': [1 / 4.5] * 8}})
for kind, margin in SOURCES:
    source = ROOT / f'design/{kind}-base'
    unit = {'name': kind.replace('-', ' ').title(), 'new': kind not in
            ['goblin', 'kobold', 'wolf', 'viper', 'spider', 'boar'], 'margin': margin,
            'base': png(source / f'{kind}-base.png')}
    for clip, mode in [('idle', 'rest'), ('attack', 'attack')]:
        timing = json.loads((source / f'{clip}-timing.json').read_text())
        unit[mode] = {'frames': [png(source / f'{clip}_{i}.png')
                                for i in range(1, len(timing['weights']) + 1)],
                      'seconds': [w / timing['fps'] for w in timing['weights']],
                      'impact': timing.get('impact_frame')}
    unit['runtime'] = runtime_folder(kind)
    units.append(unit)

html = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Delve · Fringe sprite review</title>
<style>
:root {color-scheme:dark;font:16px system-ui;background:#24272c;color:#eee8dc}
body {margin:28px} h1 {font-size:25px;margin-bottom:8px} p {color:#c2c3c5;max-width:900px}
button,input {font:inherit} button {background:#414650;color:inherit;border:1px solid #737a87;
border-radius:5px;padding:7px 15px;cursor:pointer} button:hover {background:#555c68}
nav {display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:22px 0}
h2 {font-size:18px;font-weight:500} .row {display:flex;gap:12px;overflow:auto;background:#35383e;
padding:14px 10px 8px} figure {margin:0;flex:none;text-align:center} .stage {position:relative;
overflow:hidden;border-bottom:1px solid #676a70} canvas {position:absolute;left:50%;
transform:translateX(-50%);image-rendering:pixelated} figcaption {padding-top:9px;font-size:14px}
.timing {font-size:12px;color:#c2c3c5;min-height:17px;margin:5px 0 3px}
</style>
<h1>Delve · Fringe sprite review</h1>
<p>All creatures use the same display pixel scale and aligned ground contacts. Scroll each row
to compare the full set. These are native enemy pixels; game cameras and hero pixel scale differ.</p>
<nav><button data-mode="base">Rest pose</button><button data-mode="rest">Play idle</button>
<button data-mode="attack">Play attacks</button><button id="pause">Pause</button>
<label>Scale <input id="scale" type="range" min="1" max="6" value="4"> <span id="zoom">4×</span></label>
<label><input id="silhouette" type="checkbox"> Silhouettes</label></nav>
<h2>Existing species</h2><div class="row" id="existing"></div>
<h2>New Fringe species</h2><div class="row" id="new"></div>
<p>Attack playback includes a short rest between repetitions for review. The rat uses its existing
idle during this comparison because it has no authored attack clip. Space pauses playback.</p>
<script>
const units = __DATA__;
let mode='base', scale=4, time=0, last=performance.now(), paused=false;
const views=units.map(unit=>{
  const figure=document.createElement('figure');
  const stage=document.createElement('div');stage.className='stage';
  const canvas=document.createElement('canvas');stage.append(canvas);
  const caption=document.createElement('figcaption');caption.textContent=unit.name;
  const timing=document.createElement('div');timing.className='timing';
  figure.append(stage,caption,timing);document.getElementById(unit.new?'new':'existing').append(figure);
  const load=p=>{const img=new Image();img.src=p.src;return img;};
  unit.base.img=load(unit.base);
  for(const clip of ['rest','attack']) if(unit[clip]) unit[clip].frames.forEach(p=>p.img=load(p));
  canvas.width=unit.base.width;canvas.height=unit.base.height;
  return {unit,stage,canvas,timing,ctx:canvas.getContext('2d')};
});
function resize(){
  for(const v of views){
    v.stage.style.width=Math.max(100,v.canvas.width+12)*scale+'px';
    v.stage.style.height=82*scale+'px';v.canvas.style.width=v.canvas.width*scale+'px';
    v.canvas.style.height=v.canvas.height*scale+'px';v.canvas.style.bottom=-v.unit.margin*scale+'px';
  }
}
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;time=0;});
function toggle(){paused=!paused;document.getElementById('pause').textContent=paused?'Resume':'Pause';}
document.getElementById('pause').onclick=toggle;
document.addEventListener('keydown',e=>{if(e.code==='Space' && e.target.tagName!=='INPUT'){e.preventDefault();toggle();}});
document.getElementById('scale').oninput=e=>{scale=+e.target.value;document.getElementById('zoom').textContent=scale+'×';resize();};
function draw(now){
  if(!paused)time+=(now-last)/1000;last=now;
  for(const v of views){
    let frame=v.unit.base, label='Rest pose';
    const clip=mode==='base'?null:v.unit[mode]||v.unit.rest;
    if(clip){
      const duration=clip.seconds.reduce((a,b)=>a+b,0);
      let t=time%(duration+(mode==='attack'?.65:0));let index=clip.frames.length-1;
      for(let i=0;i<clip.frames.length;i++){if(t<clip.seconds[i]){index=i;break;}t-=clip.seconds[i];}
      frame=clip.frames[index];label=`${duration.toFixed(2)}s · frame ${index+1}/${clip.frames.length}`;
      if(index===clip.impact)label+=' · contact';
    }
    v.ctx.clearRect(0,0,v.canvas.width,v.canvas.height);
    if(frame.img.complete){v.ctx.drawImage(frame.img,0,0);
      if(document.getElementById('silhouette').checked){v.ctx.globalCompositeOperation='source-in';
      v.ctx.fillStyle='#e0dac7';v.ctx.fillRect(0,0,v.canvas.width,v.canvas.height);v.ctx.globalCompositeOperation='source-over';}}
    v.timing.textContent=label;
  }
  requestAnimationFrame(draw);
}
resize();requestAnimationFrame(draw);
</script></html>'''
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'fringe-review.html').write_text(html.replace('__DATA__', json.dumps(units)), encoding='utf-8')
print(OUT / 'fringe-review.html')
