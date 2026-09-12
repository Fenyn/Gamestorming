-- Aseprite reconstruction from the generated construction reference.
-- --batch --script-param root=.../delve --script tools/draw_goblin_base.lua
-- Rebuilding overwrites the master and exports. Preserve manual edits first.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/goblin-base'
local W,H=56,64
local rgba=app.pixelColor.rgba
local red,green,blue=app.pixelColor.rgbaR,app.pixelColor.rgbaG,app.pixelColor.rgbaB
-- Comparison colors used for de-texturing the reference, then remapped to
-- a muted game palette with cool shadows and warm upper planes.
local swatches={
  {'o','202609','202624'}, {'d','354312','29362c'},
  {'s','515c1d','4b593e'}, {'m','868a3d','849467'},
  {'l','b9bf68','b2bd8e'}, {'p','613e21','594439'},
  {'c','906035','a77562'}, {'h','ad7b47','b28a69'},
  {'e','f0b32c','ffcd6e'}, {'t','f3e8b3','eee2c7'},
}
local function parse(hex)
  return tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
end
local P={}
local palette=Palette(#swatches+1)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,v in ipairs(swatches) do
  v.r,v.g,v.b=parse(v[2])
  local r,g,b=parse(v[3]); P[v[1]]=rgba(r,g,b,255)
  palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local source=Image{fromFile=out..'/construction-reference.png'}
local flat=Image(W,H,ColorMode.RGB)
local keys={}
for y=0,51 do
  keys[y]={}
  for x=0,34 do
    -- Sample the middle of each large source pixel, never filter the edges.
    local c=source:getPixel(math.floor(400+x*14.45),math.floor(325+y*14.4))
    local r,g,b=red(c),green(c),blue(c)
    if not (r>170 and b>150 and g<100) then
      local best,dist=nil,math.huge
      for _,v in ipairs(swatches) do
        local delta=(r-v.r)^2+(g-v.g)^2+(b-v.b)^2
        if delta<dist then best,dist=v[1],delta end
      end
      keys[y][x]=best
      flat:drawPixel(x+10,y+6,P[best])
    end
  end
end
local s=Sprite(W,H,ColorMode.RGB)
s:setPalette(palette)
-- Deliberate cleanup of the sampled clusters. Remove texture-color islands,
-- keep the crown/shoulder highlights joined, and simplify the toe contours.
local function row(y,x,text)
  for i=1,#text do
    local k=text:sub(i,i)
    keys[y][x+i-1]=k~='.' and k or nil
  end
end
row(0,18,'dddddoo')
row(6,3,'oooddoomlllldoo')
row(7,4,'odpppdooomlllld')
row(17,8,'dommlllmoodood')
row(18,7,'osmllllmmosdoo')
row(20,6,'oommmmmmmmms')
row(22,4,'osmmmllssoommmmss')
row(25,1,'dmmmllddooodssdddmsmoo')
row(35,27,'odooooo')
row(40,6,'oosmmlmo')
row(41,15,'ooo')
row(42,16,'o')
row(50,0,'ommmlmlsslo')
row(51,0,'osssdommomo')

local function inside(x,y,points)
  local result=false
  for i,a in ipairs(points) do
    local b=points[i%#points+1]
    if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then
      result=not result
    end
  end
  return result
end
local cloth={{10,30},{14,31},{19,32},{21,37},{19,41},{17,44},{15,43},{13,39},{12,35},{10,33}}
local nearArm={{10,16},{14,17},{16,20},{15,23},{11,25},{7,27},{6,31},{8,33},{8,39},{2,40},{0,35},{0,26},{5,21}}
local names={
  '01 Far leg','02 Far arm','03 Near leg','04 Torso and pelvis',
  '05 Plain loincloth - removable','06 Head and neck','07 Near ear',
  '08 Face','09 Near arm and hand','10 Equipment - empty',
}
local ims={}
for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
local function owner(x,y,k)
  if y>=30 and inside(x,y,cloth) then return 5 end
  if y<=15 and x<21 and y>=3 and x<(y<8 and 19 or 20) then return 7 end
  if y<=15 or (y<=22 and x>=20) then
    if y>=9 and x>=26 then return 8 end
    return 6
  end
  if inside(x,y,nearArm) then return 9 end
  if y>=25 and x>=20+math.max(0,y-26)*0.65 then return 2 end
  if y>=33 then return x<16 and 3 or 1 end
  return 4
end
-- Rat-style rendering: preserve the constructed silhouette, replace the
-- reference's texture and modeled muscles with broad, flat color planes.
local function exists(x,y)
  return keys[y] and keys[y][x]~=nil
end
-- Stepped shadow boundaries follow the changing thickness and direction of
-- each limb. Avoid rectangular thresholds across joints and the abdomen.
local function boundary(first,values)
  local result={}
  for i,x in ipairs(values) do result[first+i-1]=x end
  return result
end
local nearLegShade=boundary(33,{12,12,13,13,13,12,11,10,8,7,6,5,4,3,3,4,6,9,10})
local farLegShade=boundary(35,{17,17,18,19,20,21,21,20,19,19,19,19,20,20,21,24})
local forearmShade=boundary(25,{5,4,3,3,3,3,4,5,6,6,5,4,4,3})
local torsoShade=boundary(22,{13,12,12,11,11,12,13,14,15,16,17})
local neckShade=boundary(17,{17,16,16,17,18,20})
local function shade(x,y,i,k)
  local below=not exists(x,y+1)
  -- Short upper-facing contour accents, as on the rat's back. They describe
  -- the silhouette rather than adding spots of reflected light inside it.
  if (y==2 and x>=15 and x<=16) or (y==3 and x==14)
    or (y==3 and x>=2 and x<=3)
    or (y==16 and x>=10 and x<=13)
    or (y==17 and x>=8 and x<=9) then return 'l' end
  if i==5 then
    return x>=17 and 'p' or 'c'
  elseif i==7 then
    if inside(x,y,{{5,7},{11,9},{17,12},{17,15},{12,14},{8,11}}) then return 'c' end
    if below and y>=12 then return 'd' end
    return y>=12 and 's' or 'm'
  elseif i==6 or i==8 then
    if y==11 and x>=27 and x<=30 then return 'o' end
    if y==12 and x>=27 and x<=29 then return x==28 and 'e' or 'o' end
    if y==13 and x>=28 and x<=30 then return 's' end
    if y>=18 and y<=19 and x>=27 and x<=29 and k=='t' then return 't' end
    if y==18 and x>=29 and x<=31 then return 'o' end
    if y==17 and x>=31 and k=='o' then return 'o' end
    if (y==0 and x>=18 and x<=24) or (y==1 and x>=17 and x<=20) then return 'l' end
    if y>=20 and x<=26 then return below and 'o' or 'd' end
    if y==17 and x>=24 and x<=27 then return 's' end
    if below and y>=20 then return 'd' end
    if y>=18 or (x<=20 and y>=13) then return 's' end
    return 'm'
  elseif i==1 then
    if below and y>=48 then return 'o' end
    if farLegShade[y] and x<=farLegShade[y] then return 'd' end
    return 's'
  elseif i==2 then
    if below or inside(x,y,{{21,27},{24,30},{28,32},{30,35},{30,38},{27,36},{25,33},{22,31}}) then return 'd' end
    return 's'
  elseif i==3 then
    if below and y>=49 then return 'd' end
    if nearLegShade[y] and x>=nearLegShade[y] then return 's' end
    return below and 's' or 'm'
  elseif i==9 then
    if inside(x,y,{{14,21},{14,23},{11,25},{8,26},{10,24},{12,23}}) then return 'd' end
    if inside(x,y,{{13,19},{15,21},{13,23},{10,25},{7,26},{8,24},{11,22}}) then return 's' end
    if y>=35 and ((x==5 and y<=37) or below) then return 'd' end
    if forearmShade[y] and x>=forearmShade[y] then return 's' end
    return 'm'
  else
    if neckShade[y] and x>=neckShade[y] then
      return x>=neckShade[y]+2 and 'd' or 's'
    end
    if inside(x,y,{{20,24},{22,26},{22,29},{19,28},{18,26}}) then return 's' end
    if torsoShade[y] and x<=torsoShade[y] then return 's' end
    return 'm'
  end
end
flat:clear()
for y=0,51 do
  for x=0,34 do
    local k=keys[y][x]
    if k then
      local i=owner(x,y,k)
      k=shade(x,y,i,k)
      ims[i]:drawPixel(x+10,y+6,P[k])
      if i==5 then
        -- Skin continues under the removable garment, including the hips.
        local bodyLayer=y<35 and 4 or (x<16 and 3 or 1)
        local skin=x<14 and 'm' or (x<17 and 's' or 'd')
        ims[bodyLayer]:drawPixel(x+10,y+6,P[skin])
      end
    end
  end
end
for i,name in ipairs(names) do
  local layer=i==1 and s.layers[1] or s:newLayer()
  layer.name=name
  s:newCel(layer,1,ims[i],Point(0,0))
end
s.frames[1].duration=0.15
local tag=s:newTag(1,1); tag.name='base_idle'
s:saveAs(out..'/goblin-base.aseprite')
flat:drawSprite(s,1)
flat:saveAs(out..'/goblin-base.png')
local preview=Sprite(W,H,ColorMode.RGB)
preview:newCel(preview.layers[1],1,flat,Point(0,0))
app.sprite=preview
app.command.SpriteSize{width=W*8,height=H*8,method='nearest'}
preview:saveAs(out..'/goblin-base-8x.png')
local board=Sprite(168,68,ColorMode.RGB)
local bg=Image(168,68,ColorMode.RGB)
bg:clear(Color{r=53,g=56,b=62,a=255})
board:newCel(board.layers[1],1,bg,Point(0,0))
local function add(name,im,x,y)
  local l=board:newLayer(); l.name=name
  board:newCel(l,1,im,Point(x,y))
end
add('Rat - same pixel scale',Image{fromFile=root..'/assets/sprites/enemies/rat_v1/idle_1.png'},0,16)
add('Goblin - same pixel scale',flat,56,0)
local silhouette=Image(flat)
for it in silhouette:pixels() do
  if app.pixelColor.rgbaA(it())>0 then it(rgba(219,219,203,255)) end
end
add('Silhouette',silhouette,112,0)
app.sprite=board
app.command.SpriteSize{width=840,height=340,method='nearest'}
board:saveAs(out..'/rat-and-silhouette-review.png')
local compare=Sprite(112,64,ColorMode.RGB)
local comparison=Image(112,64,ColorMode.RGB)
comparison:clear(Color{r=53,g=56,b=62,a=255})
comparison:drawImage(Image{fromFile=out..'/revisions/edges-v4/goblin-base.png'},Point(0,0))
comparison:drawImage(flat,Point(56,0))
compare:newCel(compare.layers[1],1,comparison,Point(0,0))
app.sprite=compare
app.command.SpriteSize{width=672,height=384,method='nearest'}
compare:saveAs(out..'/proportions-comparison.png')
-- Reopen the native file and verify the exported render is reproducible.
local reopened=app.open(out..'/goblin-base.aseprite')
assert(#reopened.layers==10 and #reopened.frames==1)
local check=Image(reopened.spec); check:drawSprite(reopened,1)
for y=0,H-1 do for x=0,W-1 do
  assert(check:getPixel(x,y)==flat:getPixel(x,y),'Master / PNG mismatch')
end end
print('Verified: 56x64 RGBA, ten layers, one pose, master matches PNG.')
