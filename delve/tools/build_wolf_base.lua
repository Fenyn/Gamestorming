-- Aseprite --batch --script tools/build_wolf_base.lua
-- Rebuild overwrites generated outputs. Preserve manual edits first.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/wolf-base'
local W,H=72,56
local rgba=app.pixelColor.rgba
local swatches={
  {'m','737474','747d85'}, {'s','42443f','424b50'},
  {'d','30322b','252e2e'}, {'l','b9bfbd','adb7b7'},
  {'c','d2cbb2','c9c4ac'}, {'h','aaa48f','959888'},
  {'o','181a15','181f21'}, {'e','edb236','f3c063'},
}
local function rgb(v) return tonumber(v:sub(1,2),16),tonumber(v:sub(3,4),16),tonumber(v:sub(5,6),16) end
local P={}; local palette=Palette(#swatches+1)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,v in ipairs(swatches) do
  v.r,v.g,v.b=rgb(v[2]); local r,g,b=rgb(v[3])
  P[v[1]]=rgba(r,g,b,255); palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local source=Image{fromFile=out..'/construction-reference.png'}
local keys={}
for y=0,37 do keys[y]={}; for x=0,62 do
  local p=source:getPixel(math.floor(296+x*16.55),math.floor(186+y*16.55))
  local r,g,b=app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)
  if not(r>175 and b>150 and g<110) then
    local best,dist=nil,math.huge
    for _,v in ipairs(swatches) do local d=(r-v.r)^2+(g-v.g)^2+(b-v.b)^2
      if d<dist then best,dist=v[1],d end
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
local names={'01 Tail','02 Far hind leg','03 Far foreleg','04 Torso','05 Near hind leg','06 Near foreleg','07 Neck and head','08 Equipment - empty'}
local function owner(x,y)
  if inside(x,y,{{13,17},{17,18},{18,24},{13,29},{8,33},{0,34},{0,29},{8,24}}) then return 1 end
  if y>=23 and x>=21 and x<=31 then return 2 end
  if y>=24 and x>=44 then return 3 end
  if y>=18 and x<=24 then return 5 end
  if y>=20 and x>=37 then return 6 end
  if x>=43 or y<=10 then return 7 end
  return 4
end
local ims={}; for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
for y=0,37 do for x=0,62 do
  local k=keys[y][x]
  if k then
    local i=owner(x,y)
    -- Remove stray interior fur marks; retain structured underside shadows.
    if x>=35 and x<=41 and y>=14 and y<=19 then k='m' end
    if k=='h' and i==4 then k='m' end
    if i==2 or i==3 then
      if k=='m' or k=='s' or k=='d' then k='s' end
      if k=='l' or k=='c' then k='h' end
    elseif k=='s' or k=='d' then
      k=(i==5 or i==6) and 's' or 'd'
    end
    if y==9 and x==56 then k='e' end
    if y==9 and x==57 then k='o' end
    if y==8 and x>=55 and x<=56 then k='s' end
    ims[i]:drawPixel(x+4,y+14,P[k])
  end
end end
local s=Sprite(W,H,ColorMode.RGB); s:setPalette(palette)
for i,name in ipairs(names) do
  local l=i==1 and s.layers[1] or s:newLayer(); l.name=name
  s:newCel(l,1,ims[i],Point(0,0))
end
s.frames[1].duration=0.15
local tag=s:newTag(1,1); tag.name='base_idle'
s:saveAs(out..'/wolf-base.aseprite')
local flat=Image(s.spec); flat:drawSprite(s,1); flat:saveAs(out..'/wolf-base.png')
local preview=Sprite(W,H,ColorMode.RGB)
preview:newCel(preview.layers[1],1,flat,Point(0,0)); app.sprite=preview
app.command.SpriteSize{width=W*8,height=H*8,method='nearest'}
preview:saveAs(out..'/wolf-base-8x.png')
local board=Sprite(320,68,ColorMode.RGB)
local im=Image(320,68,ColorMode.RGB); im:clear(Color{r=53,g=56,b=62,a=255})
im:drawImage(Image{fromFile=root..'/assets/sprites/enemies/rat_v1/idle_1.png'},Point(0,16))
im:drawImage(Image{fromFile=root..'/design/goblin-base/goblin-base.png'},Point(56,0))
im:drawImage(Image{fromFile=root..'/design/kobold-base/kobold-base.png'},Point(112,0))
im:drawImage(flat,Point(176,6))
local silhouette=Image(flat)
for it in silhouette:pixels() do if app.pixelColor.rgbaA(it())>0 then it(rgba(219,219,203,255)) end end
im:drawImage(silhouette,Point(248,6))
board:newCel(board.layers[1],1,im,Point(0,0)); app.sprite=board
app.command.SpriteSize{width=1280,height=272,method='nearest'}
board:saveAs(out..'/reference-lineup-4x.png')
local reopened=app.open(out..'/wolf-base.aseprite')
assert(#reopened.layers==8)
local check=Image(reopened.spec); check:drawSprite(reopened,1)
for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==flat:getPixel(x,y),'Master/export mismatch') end end
print('Verified: eight layers; native master and PNG match.')
