-- Aseprite --batch --script tools/build_goblin_outfits.lua
-- Keeps the approved base unchanged. Rebuild overwrites outfit outputs.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/goblin-outfits'
app.fs.makeAllDirectories(out)
local W,H=56,64
local rgba=app.pixelColor.rgba
local C={}
for k,v in pairs({ink='303432',leather='89664d',hide='594638',edge='ae8963',steel='879598',steelLight='bac3b8',steelDark='526367',red='914f48',redDark='603c39',blue='63798b',blueDark='414f64',bone='d1bf92',wood='796044'}) do
  C[k]=rgba(tonumber(v:sub(1,2),16),tonumber(v:sub(3,4),16),tonumber(v:sub(5,6),16),255)
end
local function inside(x,y,p)
  local b=false
  for i,a in ipairs(p) do
    local z=p[i%#p+1]
    if (a[2]>y)~=(z[2]>y) and x<(z[1]-a[1])*(y-a[2])/(z[2]-a[2])+a[1] then b=not b end
  end
  return b
end
local function poly(im,p,color,mask)
  for y=0,H-1 do for x=0,W-1 do
    if inside(x,y,p) and (not mask or app.pixelColor.rgbaA(mask:getPixel(x,y))>0) then im:drawPixel(x,y,C[color]) end
  end end
end
local function rect(im,x,y,w,h,c)
  for yy=y,y+h-1 do for xx=x,x+w-1 do im:drawPixel(xx,yy,C[c]) end end
end
local function segment(im,x0,y0,x1,y1,c)
  local n=math.max(math.abs(x1-x0),math.abs(y1-y0))
  for i=0,n do im:drawPixel(math.floor(x0+(x1-x0)*i/n+0.5),math.floor(y0+(y1-y0)*i/n+0.5),C[c]) end
end
local function blank() return Image(W,H,ColorMode.RGB) end
local function flattened(s) local im=Image(s.spec); im:drawSprite(s,1); return im end
local basePath=root..'/design/goblin-base/goblin-base.aseprite'
local base=app.open(basePath)
local original=flattened(base)
local mask=blank()
for _,l in ipairs(base.layers) do
  if l.name=='04 Torso and pelvis' or l.name=='05 Plain loincloth - removable' then
    local cel=l:cel(1); mask:drawImage(cel.image,cel.position)
  end
end
local variants={
  {id='warrior',name='Goblin Warrior',accent='leather'},
  {id='commando',name='Goblin Commando',accent='red'},
  {id='war-chanter',name='Goblin War Chanter',accent='blue'},
}
local results={}
for _,v in ipairs(variants) do
  local dir=out..'/'..v.id; app.fs.makeAllDirectories(dir)
  local s=app.open(basePath)
  local originals={}; for _,l in ipairs(s.layers) do originals[#originals+1]=l end
  local baseGroup=s:newGroup(); baseGroup.name='BASE - approved goblin - unchanged'
  for _,l in ipairs(originals) do l.parent=baseGroup end
  baseGroup.isEditable=false
  local gear=s:newGroup(); gear.name='OUTFIT - '..v.name
  local pieces={}
  local function add(name,im)
    local layer=s:newLayer(); layer.name=name; layer.parent=gear
    s:newCel(layer,1,im,Point(0,0))
    pieces[#pieces+1]={name=name,layer=layer,image=im}
  end
  local armor=blank()
  poly(armor,{{24,25},{29,26},{33,31},{32,38},{29,40},{23,38},{22,32}},'leather',mask)
  poly(armor,{{23,29},{25,33},{26,36},{31,38},{28,40},{22,38}},'hide',mask)
  poly(armor,{{24,25},{28,26},{30,29},{28,29},{26,27},{24,27}},'edge',mask)
  add('01 Leather jerkin',armor)
  local hem=blank()
  poly(hem,{{22,37},{29,38},{32,41},{30,46},{26,47},{23,44}},'leather',mask)
  poly(hem,{{28,39},{31,40},{30,46},{28,47}},'hide',mask)
  if v.id=='commando' then
    poly(hem,{{23,38},{27,39},{27,45},{25,48},{24,45}},'red')
    poly(hem,{{27,39},{29,40},{28,47},{27,45}},'redDark')
  elseif v.id=='war-chanter' then
    poly(hem,{{24,37},{28,38},{30,45},{28,48},{25,44}},'blue')
    poly(hem,{{27,39},{28,39},{30,45},{28,48},{27,45}},'blueDark')
  end
  add('02 Skirt and role sash',hem)
  local shoulder=blank()
  if v.id=='warrior' then
    poly(shoulder,{{20,24},{24,22},{27,24},{26,27},{22,29},{19,28}},'hide')
    poly(shoulder,{{20,24},{24,23},{26,24},{25,26},{22,27},{20,27}},'leather')
    segment(shoulder,21,24,24,23,'edge')
  elseif v.id=='commando' then
    poly(shoulder,{{20,23},{24,22},{28,24},{27,27},{23,30},{19,28}},'hide')
    poly(shoulder,{{20,24},{24,22},{27,24},{26,27},{22,28},{20,27}},'steelDark')
    poly(shoulder,{{20,24},{24,23},{26,24},{24,26},{21,27}},'steel')
    segment(shoulder,21,24,24,23,'steelLight')
  else
    poly(shoulder,{{22,22},{26,22},{30,25},{28,27},{24,26},{21,28},{19,27}},'blueDark')
    poly(shoulder,{{22,22},{25,23},{27,25},{24,25},{20,27},{20,25}},'blue')
    poly(shoulder,{{27,24},{30,26},{30,28},{27,27}},'blue')
  end
  add('03 Shoulder armor or mantle',shoulder)
  local straps=blank()
  poly(straps,{{24,27},{26,27},{31,35},{30,37},{28,34}},'hide',mask)
  poly(straps,{{22,36},{27,37},{31,37},{32,39},{27,39},{22,38}},'hide',mask)
  rect(straps,28,37,2,2,v.id=='commando' and 'steel' or 'edge')
  if v.id=='war-chanter' then
    segment(straps,26,28,29,32,'hide')
    rect(straps,28,31,2,2,'bone')
  end
  add('04 Belt and straps',straps)
  local cuffs=blank()
  poly(cuffs,{{11,36},{15,37},{16,39},{12,39},{10,38}},'hide')
  segment(cuffs,11,36,14,37,'leather')
  if v.id=='commando' then
    poly(cuffs,{{13,49},{16,50},{15,54},{12,55},{11,54}},'hide')
    poly(cuffs,{{13,50},{15,50},{14,53},{12,54}},'leather')
  end
  add('05 Bracer and wraps',cuffs)
  local weapon=blank()
  if v.id=='commando' then
    segment(weapon,42,55,45,21,'wood')
    segment(weapon,43,55,46,21,'hide')
    poly(weapon,{{45,16},{49,15},{53,18},{53,23},{50,26},{47,25},{47,22},{45,22}},'steelDark')
    poly(weapon,{{46,16},{49,16},{52,18},{52,22},{49,24},{48,23},{48,20},{46,20}},'steel')
    segment(weapon,49,16,52,18,'steelLight')
    segment(weapon,52,19,52,22,'steelLight')
    rect(weapon,44,24,3,2,'ink')
  else
    segment(weapon,41,44,43,35,'hide')
    poly(weapon,{{43,27},{45,25},{47,27},{46,32},{45,32},{45,36},{42,36}},'steelDark')
    poly(weapon,{{44,27},{45,26},{46,27},{45,31},{44,31},{44,35},{43,35}},'steel')
    segment(weapon,45,27,44,30,'steelLight')
    segment(weapon,41,36,45,37,'edge')
  end
  add(v.id=='commando' and '06 Horsechopper - optional' or '06 Dogslicer - optional',weapon)
  local grip=blank()
  -- The original hand occludes the handle; no body pixels are repainted.
  for y=39,43 do for x=39,43 do
    local p=original:getPixel(x,y)
    if app.pixelColor.rgbaA(p)>0 then grip:drawPixel(x,y,p) end
  end end
  add('07 Hand over weapon',grip)
  s:saveAs(dir..'/goblin-'..v.id..'.aseprite')
  local composite=flattened(s); composite:saveAs(dir..'/goblin-'..v.id..'.png')
  baseGroup.isVisible=false
  local overlay=flattened(s); overlay:saveAs(dir..'/outfit-overlay.png')
  pieces[6].layer.isVisible=false; pieces[7].layer.isVisible=false
  flattened(s):saveAs(dir..'/clothing-overlay.png')
  baseGroup.isVisible=true
  flattened(s):saveAs(dir..'/goblin-'..v.id..'-unarmed.png')
  pieces[6].layer.isVisible=true; pieces[7].layer.isVisible=true
  for _,piece in ipairs(pieces) do piece.image:saveAs(dir..'/'..piece.name:sub(1,2)..'-layer.png') end
  gear.isVisible=false; baseGroup.isVisible=true
  local check=flattened(s)
  for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==original:getPixel(x,y),'Base altered') end end
  gear.isVisible=true
  local reopened=app.open(dir..'/goblin-'..v.id..'.aseprite')
  local saved=flattened(reopened)
  for y=0,H-1 do for x=0,W-1 do assert(saved:getPixel(x,y)==composite:getPixel(x,y),'Export mismatch') end end
  results[#results+1]=composite
  print(v.name..': saved seven outfit layers; base unchanged; master matches PNG.')
end
local sheet=Sprite(224,68,ColorMode.RGB)
local im=Image(224,68,ColorMode.RGB); im:clear(Color{r=53,g=56,b=62,a=255})
im:drawImage(original,Point(0,0))
for i,result in ipairs(results) do im:drawImage(result,Point(i*56,0)) end
sheet:newCel(sheet.layers[1],1,im,Point(0,0))
app.sprite=sheet
app.command.SpriteSize{width=1120,height=340,method='nearest'}
sheet:saveAs(out..'/outfit-lineup-5x.png')
