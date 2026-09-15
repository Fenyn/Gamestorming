-- Native reconstruction of the approved human concept, using Aseprite only.
-- Output is a separate study. Preserve manual edits before rebuilding.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/human-base-study'
local W,H=56,64
local pc=app.pixelColor
local source=Image{fromFile=out..'/human-base-concept-v1.png'}
local swatches={
 {'m',224,169,99,'d5a064'}, {'s',171,111,71,'a16c4b'},
 {'h',249,211,143,'efd29a'}, {'d',114,78,49,'664b38'},
 {'o',58,48,34,'302d29'}, {'c',128,99,65,'7e6449'},
 {'k',90,71,49,'514535'},
}
local P={}
local palette=Palette(#swatches+1)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,v in ipairs(swatches) do
 local hex=v[5]
 local r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
 P[v[1]]=pc.rgba(r,g,b,255)
 palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local rows={}
for y=0,51 do
 local row=''
 for x=0,26 do
  local c=source:getPixel(498+x*12,310+y*12)
  local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
  local key='.'
  if r>g*1.12 and r>b*1.35 then
   local dist=math.huge
   for _,v in ipairs(swatches) do
    local delta=(r-v[2])^2+(g-v[3])^2+(b-v[4])^2
    if delta<dist then key,dist=v[1],delta end
   end
  end
  row=row..key
 end
 rows[y]=row
end
-- Store the sampled proposal separately for an honest before/after comparison.
local function pixel(im,x,y,k) im:drawPixel(x+14,y+8,P[k] or 0) end
local sampled=Image(W,H,ColorMode.RGB)
for y=0,50 do for x=0,26 do pixel(sampled,x,y,rows[y]:sub(x+1,x+1)) end end
sampled:saveAs(out..'/sampled-before.png')
local function set(x,y,k)
 rows[y]=rows[y]:sub(1,x)..k..rows[y]:sub(x+2)
end
-- The generated eye contained background-colored pixels. Redraw the entire
-- eye region as one small brow/eye accent, with no white eye column.
for y=8,10 do for x=17,21 do set(x,y,'m') end end
set(19,8,'s'); set(20,8,'d'); set(20,9,'o')
-- Short, joined contour highlights only. Remove all sampled internal shine.
for y=0,50 do for x=0,26 do
 if rows[y]:sub(x+1,x+1)=='h' then set(x,y,'m') end
end end
for _,p in ipairs({{12,0},{13,0},{14,0},{11,1},{7,15},{8,15},{6,16},{3,48},{4,48},{9,50}}) do set(p[1],p[2],'h') end
-- Clean the sampled neck's flecks and keep a tapered jaw overlap.
for x=13,18 do set(x,14,x<15 and 's' or 'd') end
set(16,15,'s'); set(15,15,'s')
set(3,34,'.'); set(4,34,'.'); set(23,34,'.')
local names={'01 Far leg','02 Far arm and hand','03 Near leg',
 '04 Torso and pelvis','05 Head and neck','06 Shorts - removable',
 '07 Near arm and hand','08 Face','09 Equipment - empty'}
local ims={}
for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
local function owner(x,y)
 if y<=13 or (y<=15 and x>=11) then return 5 end
 if (y>=29 and y<=34 and x<=5) or (y>=14 and y<=15 and x<=10) then return 7 end
 if y>=29 and y<=36 and x>=6 and x<=19 then
  local k=rows[y]:sub(x+1,x+1)
  if k=='c' or k=='k' or k=='o' or (y<=32 and x<=18) then return 6 end
 end
 if y>=33 then return x<=14 and 3 or 1 end
 if y>=20 and x>=19 then return 2 end
 if (y>=22 and x<=6) or (y>=18 and x<=8) or (y>=16 and x<=7) then return 7 end
 return 4
end
local function inside(x,y,pts)
 local yes=false
 for i,a in ipairs(pts) do
  local b=pts[i%#pts+1]
  if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then yes=not yes end
 end
 return yes
end
local function poly(im,pts,k)
 for y=0,50 do for x=0,26 do
  if inside(x+.5,y+.5,pts) then pixel(im,x,y,k) end
 end end
end
-- Continue joints and covered body volumes beneath their foreground layers.
-- These are useful overlap allowances for editing this pose, not an animation rig.
poly(ims[1],{{14,29},{19,29},{20,37},{18,39},{15,35}},'s')
poly(ims[2],{{17,18},{20,19},{21,24},{20,27},{18,25}},'s')
poly(ims[3],{{8,29},{15,29},{15,35},{13,38},{8,38},{7,34}},'m')
poly(ims[4],{{9,17},{13,15},{17,17},{20,21},{18,28},{19,32},{16,35},{12,34},{8,32},{9,25},{8,21}},'m')
poly(ims[4],{{9,21},{11,22},{12,26},{11,30},{12,34},{8,32},{9,26}},'s')
-- Paint visible regions over the overlap allowances.
for y=0,50 do for x=0,26 do
 local k=rows[y]:sub(x+1,x+1)
 if k~='.' then
  local i=owner(x,y)
  if i~=6 and (k=='c' or k=='k') then k='s' end
  if i==6 then
   k=(k=='o' or k=='k' or (y>=32 and x>=14)) and 'k' or 'c'
  elseif i==1 then
   k=(x<=17 and y>=36 and y<=39) and 'd' or 's'
   if y==50 then k='o' end
  elseif i==2 then
   k=(k=='m' or k=='h') and 's' or k
   if x==19 and y>=24 and y<=28 then k='d' end
  elseif i==4 and y>=21 and y<=28 then
   local boundary={10,11,11,12,12,12,11,10}
   k=x<=boundary[y-20] and 's' or 'm'
   if x==9 and y<=23 then k='d' end
  elseif i==3 then
   -- A single connected calf shadow, no bright knee stripes.
   if y==50 and x<9 then k='d' end
  end
  if y==9 and x==20 then i=8 end
  pixel(ims[i],x,y,k)
 end
end end
-- Fill the head beneath the removable face mark.
pixel(ims[5],20,9,'m')
local s=Sprite(W,H,ColorMode.RGB); s:setPalette(palette)
for i,name in ipairs(names) do
 local l=i==1 and s.layers[1] or s:newLayer(); l.name=name
 s:newCel(l,1,ims[i],Point(0,0))
end
s.frames[1].duration=0.2
local tag=s:newTag(1,1); tag.name='base'
s:saveAs(out..'/human-base-v1.aseprite')
local flat=Image(s.spec); flat:drawSprite(s,1)
flat:saveAs(out..'/human-base-v1.png')
local function exportPreview(im,path,scale)
 local p=Sprite(im.width,im.height,ColorMode.RGB)
 p:newCel(p.layers[1],1,im,Point(0,0)); app.sprite=p
 app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'}
 p:saveAs(path); p:close()
end
exportPreview(flat,out..'/human-base-v1-8x.png',8)
s.layers[6].isVisible=false
local bare=Image(s.spec); bare:drawSprite(s,1)
bare:saveAs(out..'/body-under-shorts.png')
s.layers[7].isVisible=false
local support=Image(s.spec); support:drawSprite(s,1)
s.layers[6].isVisible=true; s.layers[7].isVisible=true
local silhouette=Image(flat)
for it in silhouette:pixels() do if pc.rgbaA(it())>0 then it(pc.rgba(219,219,203,255)) end end
local function board(images,path,scale)
 local im=Image(#images*64,72,ColorMode.RGB); im:clear(pc.rgba(53,56,62,255))
 for i,entry in ipairs(images) do
  local src=entry
  local bottom=0
  for y=0,src.height-1 do for x=0,src.width-1 do
   if pc.rgbaA(src:getPixel(x,y))>0 then bottom=math.max(bottom,y) end
  end end
  im:drawImage(src,Point((i-1)*64+math.floor((64-src.width)/2),63-bottom))
 end
 im:saveAs(out..'/'..path..'-native.png')
 exportPreview(im,out..'/'..path..'-'..scale..'x.png',scale)
end
board({Image{fromFile=root..'/assets/sprites/enemies/rat_v1/idle_1.png'},
 Image{fromFile=root..'/assets/sprites/enemies/goblin_base/base.png'},
 flat,Image{fromFile=root..'/assets/sprites/enemies/kobold_base/base.png'},silhouette},'monster-comparison',5)
board({sampled,flat,bare,support,silhouette},'construction-review',5)
local reopened=app.open(out..'/human-base-v1.aseprite')
assert(#reopened.layers==9 and #reopened.frames==1)
local check=Image(reopened.spec); check:drawSprite(reopened,1)
local colors={}; local count=0; local bounds={W,H,0,0}
for y=0,H-1 do for x=0,W-1 do
 local c=flat:getPixel(x,y)
 assert(c==check:getPixel(x,y),'Master / export mismatch')
 local a=pc.rgbaA(c); assert(a==0 or a==255,'Partial alpha')
 if a>0 then
  if not colors[c] then colors[c]=true; count=count+1 end
  bounds[1]=math.min(bounds[1],x); bounds[2]=math.min(bounds[2],y)
  bounds[3]=math.max(bounds[3],x); bounds[4]=math.max(bounds[4],y)
 end
end end
print(string.format('PASS: %dx%d, %d colors, nine layers, one frame. Bounds %d,%d to %d,%d. Binary alpha. Reopened master matches PNG.',W,H,count,table.unpack(bounds)))
