-- Aseprite --batch --script tools/build_kobold_base.lua
-- Rebuild replaces the generated master and exports. Preserve manual edits first.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/kobold-base'
local W,H=64,64
local rgba=app.pixelColor.rgba
local source=Image{fromFile=out..'/construction-reference.png'}
local swatches={
  {'m','b66746','a96d51'}, {'s','914a33','80513f'},
  {'d','703b2a','573e34'}, {'l','c27e54','be8d69'},
  {'b','573629','493a32'}, {'c','78513e','70513f'},
  {'t','ddc7ac','d0c09e'}, {'h','b29a81','a08d73'},
  {'o','30291f','2d302b'}, {'e','edb43e','e6b455'},
}
local P={}; local palette=Palette(#swatches+1)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
local function rgb(hex) return tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16) end
for i,v in ipairs(swatches) do
  v.r,v.g,v.b=rgb(v[2]); local r,g,b=rgb(v[3])
  P[v[1]]=rgba(r,g,b,255); palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local keys={}
for y=0,51 do keys[y]={}; for x=0,51 do
  local p=source:getPixel(math.floor(104+x*17.8),math.floor(264+y*17.8))
  local r,g,b=app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)
  if not(r>175 and b>150 and g<110) then
    local best,dist=nil,math.huge
    for _,v in ipairs(swatches) do
      local delta=(r-v.r)^2+(g-v.g)^2+(b-v.b)^2
      if delta<dist then best,dist=v[1],delta end
    end
    keys[y][x]=best
  end
end end
local function inside(x,y,ps)
  local result=false
  for i,a in ipairs(ps) do local b=ps[i%#ps+1]
    if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then result=not result end
  end
  return result
end
local cloth={{28,28},{34,29},{36,32},{35,37},{33,43},{30,40},{29,35},{26,31}}
local arm={{27,15},{30,17},{29,20},{25,24},{22,26},{22,30},{23,32},{22,36},{17,36},{15,33},{16,29},{18,25},{18,22},{21,18}}
local function owner(x,y)
  if y<=7 and (keys[y][x]=='t' or keys[y][x]=='h') then return 9 end
  if inside(x,y,cloth) then return 6 end
  if y<=14 or (y<=19 and x>=33) then return 7 end
  if inside(x,y,arm) then return 8 end
  if x<=23 and y>=23 and y<=40 then return 1 end
  if y>=33 then return x>=33 and 2 or 4 end
  if y>=24 and x>=35 then return 3 end
  return 5
end
local names={'01 Tail','02 Far leg','03 Far arm','04 Near leg','05 Torso and pelvis','06 Loincloth - removable','07 Head and neck','08 Near arm and hand','09 Horns','10 Equipment - empty'}
local ims={}; for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
for y=0,51 do for x=0,51 do
  local k=keys[y][x]
  if k then
    local i=owner(x,y)
    -- Collapse source texture into broad planes. Skin highlights are limited
    -- to upper silhouette edges; cloth has independent palette entries.
    if i==6 then k=x>=33 and 'b' or 'c'
    elseif k=='l' then k='m'
    elseif k=='c' or k=='b' then k='d' end
    if i~=6 and k~='t' and k~='h' and k~='e' and k~='o' then
      if i==2 or i==3 then k=(k=='d') and 'd' or 's' end
    end
    if k=='m' and ((y==14 and x>=28 and x<=30)
      or (y==15 and x>=25 and x<=27)
      or (y==4 and x>=39 and x<=40)) then k='l' end
    ims[i]:drawPixel(x+6,y+6,P[k])
    if i==6 and (y<=35 or (y<=38 and (x<=30 or x>=35))) then
      local under=y<34 and 5 or (x>=33 and 2 or 4)
      ims[under]:drawPixel(x+6,y+6,P[x<32 and 'm' or 's'])
    end
  end
end end
local s=Sprite(W,H,ColorMode.RGB); s:setPalette(palette)
for i,name in ipairs(names) do
  local l=i==1 and s.layers[1] or s:newLayer(); l.name=name
  s:newCel(l,1,ims[i],Point(0,0))
end
s.frames[1].duration=0.15
local tag=s:newTag(1,1); tag.name='base_idle'
s:saveAs(out..'/kobold-base.aseprite')
local flat=Image(s.spec); flat:drawSprite(s,1); flat:saveAs(out..'/kobold-base.png')
local preview=Sprite(W,H,ColorMode.RGB)
preview:newCel(preview.layers[1],1,flat,Point(0,0)); app.sprite=preview
app.command.SpriteSize{width=W*8,height=H*8,method='nearest'}
preview:saveAs(out..'/kobold-base-8x.png')
local review=Sprite(240,68,ColorMode.RGB)
local im=Image(240,68,ColorMode.RGB); im:clear(Color{r=53,g=56,b=62,a=255})
im:drawImage(Image{fromFile=root..'/assets/sprites/enemies/rat_v1/idle_1.png'},Point(0,16))
im:drawImage(Image{fromFile=root..'/design/goblin-base/goblin-base.png'},Point(56,0))
im:drawImage(flat,Point(112,0))
local silhouette=Image(flat)
for it in silhouette:pixels() do if app.pixelColor.rgbaA(it())>0 then it(rgba(219,219,203,255)) end end
im:drawImage(silhouette,Point(176,0))
review:newCel(review.layers[1],1,im,Point(0,0)); app.sprite=review
app.command.SpriteSize{width=1200,height=340,method='nearest'}
review:saveAs(out..'/reference-lineup-5x.png')
local reopened=app.open(out..'/kobold-base.aseprite')
local check=Image(reopened.spec); check:drawSprite(reopened,1)
assert(#reopened.layers==10)
for y=0,H-1 do for x=0,W-1 do assert(flat:getPixel(x,y)==check:getPixel(x,y),'Master/export mismatch') end end
-- Inspect the underlying body independently of its removable garment.
for _,layer in ipairs(reopened.layers) do
  if layer.name=='06 Loincloth - removable' then layer.isVisible=false end
end
local anatomy=Image(reopened.spec); anatomy:drawSprite(reopened,1)
anatomy:saveAs(out..'/body-without-loincloth.png')
print('Verified native master and PNG match.')
