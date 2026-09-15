-- Reconstruct the fresh adult reference on a fixed native grid in Aseprite.
-- The construction is sampled; rendering and overlap support are authored.
-- Rebuilding writes v3 files only. Preserve manual master edits before rebuild.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/human-base-study'
local W,H=64,120
local pc=app.pixelColor
local swatches={
 {'m',194,141,92,'c29265'}, {'s',157,108,64,'966343'},
 {'d',113,77,42,'634834'}, {'o',70,51,31,'302d29'},
 {'h',227,180,124,'e6bf86'}, {'c',132,94,55,'806347'},
 {'k',88,63,37,'514331'},
}
local P={}; local pal=Palette(8); pal:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,v in ipairs(swatches) do
 local hex=v[5]
 local r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
 P[v[1]]=pc.rgba(r,g,b,255); pal:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local src=Image{fromFile=out..'/human-construction-v3.png'}
local keys={}
for y=0,108 do
 keys[y]={}
 for x=0,42 do
  local c=src:getPixel(math.floor(194+x*12.4),math.floor(200+y*12.4))
  local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
  if not (r>180 and b>160 and g<90) then
   local k,dist='m',math.huge
   for _,v in ipairs(swatches) do
    local delta=(r-v[2])^2+(g-v[3])^2+(b-v[4])^2
    if delta<dist then k,dist=v[1],delta end
   end
   keys[y][x]=k
  end
 end
end
local function inside(x,y,pts)
 local result=false
 for i,a in ipairs(pts) do
  local b=pts[i%#pts+1]
  if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then result=not result end
 end
 return result
end
local nearArm={{12,23},{14,28},{13,35},{11,39},{8,43},{8,46},{9,51},{9,56},{11,60},{13,63},{13,69},{9,70},{2,66},{0,61},{1,56},{0,49},{-1,40},{0,31},{3,24},{7,21}}
local shorts={{12,46},{27,47},{31,46},{32,51},{33,58},{34,69},{29,70},{23,70},{21,67},{20,67},{19,70},{9,70},{9,64},{10,55},{10,50}}
local function owner(x,y)
 if y<=18 or (y<=22 and x>=15 and x<=27) then return 5 end
 if (y>=19 and y<=23 and x<15) or (y>=24 and y<59 and x<11)
  or (y>=59 and y<=68 and x<=13) then return 7 end
 if inside(x+.5,y+.5,nearArm) then return 7 end
 if y>=46 and inside(x+.5,y+.5,shorts) then return 6 end
 if y>=69 then return x<21 and 3 or 1 end
 if y>=27 and x>=32 then return 2 end
 return 4
end
local names={'01 Far leg','02 Far arm and hand','03 Near leg','04 Torso and pelvis',
 '05 Head and neck','06 Shorts - removable','07 Near arm and hand','08 Face','09 Equipment - empty'}
local ims={}; for i=1,9 do ims[i]=Image(W,H,ColorMode.RGB) end
local function dot(im,x,y,k) im:drawPixel(x+10,y+6,P[k] or 0) end
local function poly(i,k,pts)
 for y=0,108 do for x=0,42 do
  if inside(x+.5,y+.5,pts) then dot(ims[i],x,y,k) end
 end end
end
-- Covered anatomy follows the source's shoulder/waist/hip contours. These
-- overlap allowances are for this standing pose, not a complete animation rig.
poly(1,'s',{{22,49},{31,49},{33,67},{32,72},{26,74},{23,68},{21,59}})
poly(3,'m',{{11,49},{22,50},{23,57},{21,65},{19,72},{11,73},{10,65}})
poly(4,'m',{{13,24},{21,22},{31,24},{33,30},{32,37},{31,45},{32,52},{29,56},{24,56},{21,55},{17,56},{12,53},{12,45},{10,37},{10,29}})
poly(4,'s',{{11,29},{14,33},{15,38},{14,42},{14,48},{16,54},{12,54},{12,46},{10,38}})
poly(2,'s',{{30,25},{34,26},{35,34},{33,39},{31,34}})
local sampled=Image(W,H,ColorMode.RGB)
local function exists(x,y) return keys[y] and keys[y][x]~=nil end
for y=0,108 do for x=0,42 do
 local k=keys[y][x]
 if k then
  dot(sampled,x,y,k)
  local i=owner(x,y)
  local below=not exists(x,y+1)
  if i==6 then
   k=inside(x,y,{{24,51},{31,51},{32,69},{23,70},{22,64},{23,59},{27,56}}) and 'k' or 'c'
   if y>=67 and below then k='k' end
  elseif i==4 then
   k='m'
   if inside(x,y,{{10,29},{14,32},{15,37},{16,39},{15,41},{14,43},{14,47},{17,52},{13,54},{11,47},{11,42},{10,39}}) then k='s' end
   if inside(x,y,{{32,30},{32,47},{29,47},{29,42},{30,39},{30,35}}) then k='s' end
   if inside(x,y,{{11,30},{13,32},{14,34},{13,38},{11,39}}) then k='d' end
   if inside(x,y,{{28,33},{32,32},{31,34},{29,35},{27,35}}) then k='s' end
   if y==22 and x>=10 and x<=12 then k='h' end
  elseif i==1 then
   k='s'
   if inside(x,y,{{22,70},{25,74},{27,79},{26,83},{26,88},{28,93},{28,99},{26,103},{24,100},{24,93},{22,87},{23,81},{23,77}}) then k='d' end
   if y>=104 and below then k='o' end
  elseif i==3 then
   k='m'
   if inside(x,y,{{18,70},{20,71},{20,76},{17,81},{15,85},{15,90},{13,94},{12,99},{12,102},{14,104},{13,107},{10,104},{10,100},{11,94},{12,90},{12,85},{14,80},{16,75}}) then k='s' end
   if y>=105 and below then k='d' end
   if (y==102 and x>=5 and x<=7) then k='h' end
  elseif i==2 then
   local hand=y>=60
   if not hand then
    k='s'
    if inside(x,y,{{32,32},{34,37},{34,43},{36,46},{36,50},{38,53},{37,56},{34,52},{33,48},{32,42}}) then k='d' end
   elseif k=='c' or k=='k' then k='d'
   elseif k=='h' or k=='m' then k='s' end
  elseif i==7 then
   if y<59 then
    k='m'
    if inside(x,y,{{12,25},{14,28},{13,34},{11,38},{8,41},{6,43},{6,47},{7,51},{7,55},{9,58},{7,60},{5,56},{5,51},{4,47},{4,42},{7,38},{10,34}}) then k='s' end
    if inside(x,y,{{12,29},{13,31},{12,35},{10,38},{8,39},{10,35}}) then k='d' end
    if (y==23 and x>=6 and x<=9) or (y==24 and x>=5 and x<=6) then k='h' end
   elseif k=='c' or k=='k' then k='d' end
  elseif i==5 then
   if k=='c' then k='s' elseif k=='k' then k='d' end
   -- Keep brow, ear and jaw construction; simplify the bald cranium.
   if y<=6 then k='m' end
   if y==0 and x>=18 and x<=23 then k='h' end
   if y>=7 and y<=10 and x>=26 then i=8 end
  end
  dot(ims[i],x,y,k)
 end
end end
-- Head continues under the face marks.
for y=7,10 do for x=26,32 do
 if exists(x,y) then dot(ims[5],x,y,'m') end
end end
local s=Sprite(W,H,ColorMode.RGB); s:setPalette(pal)
for i,name in ipairs(names) do
 local l=i==1 and s.layers[1] or s:newLayer(); l.name=name
 s:newCel(l,1,ims[i],Point(0,0))
end
s.frames[1].duration=.2; s:newTag(1,1).name='base'
s:saveAs(out..'/human-base-v3.aseprite')
local flat=Image(s.spec); flat:drawSprite(s,1); flat:saveAs(out..'/human-base-v3.png')
local function preview(im,path,scale)
 local p=Sprite(im.width,im.height,ColorMode.RGB)
 p:newCel(p.layers[1],1,im,Point(0,0)); app.sprite=p
 app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'}
 p:saveAs(out..'/'..path..'.png'); p:close()
end
preview(flat,'human-base-v3-6x',6)
s.layers[6].isVisible=false
local bare=Image(s.spec); bare:drawSprite(s,1)
s.layers[7].isVisible=false
local support=Image(s.spec); support:drawSprite(s,1)
s.layers[6].isVisible=true; s.layers[7].isVisible=true
local silhouette=Image(flat)
for it in silhouette:pixels() do if pc.rgbaA(it())>0 then it(pc.rgba(219,219,203,255)) end end
local function board(images,name)
 local im=Image(#images*72,128,ColorMode.RGB); im:clear(pc.rgba(53,56,62,255))
 for i,srcIm in ipairs(images) do
  local bottom=0
  for y=0,srcIm.height-1 do for x=0,srcIm.width-1 do
   if pc.rgbaA(srcIm:getPixel(x,y))>0 then bottom=math.max(bottom,y) end
  end end
  im:drawImage(srcIm,Point((i-1)*72+math.floor((72-srcIm.width)/2),119-bottom))
 end
 im:saveAs(out..'/'..name..'-native.png'); preview(im,name..'-4x',4)
end
board({sampled,flat,bare,support,silhouette},'v3-construction')
board({Image{fromFile=root..'/assets/sprites/enemies/rat_v1/idle_1.png'},
 Image{fromFile=root..'/assets/sprites/enemies/goblin_base/base.png'},flat,
 Image{fromFile=root..'/assets/sprites/enemies/kobold_base/base.png'}},'v3-monsters')
local reopened=app.open(out..'/human-base-v3.aseprite')
assert(#reopened.layers==9 and #reopened.frames==1)
local check=Image(reopened.spec); check:drawSprite(reopened,1)
local used={}; local n=0; local bounds={W,H,0,0}
for y=0,H-1 do for x=0,W-1 do
 local c=flat:getPixel(x,y); assert(c==check:getPixel(x,y),'Reopen mismatch')
 local a=pc.rgbaA(c); assert(a==0 or a==255,'Partial alpha')
 if a>0 then
  if not used[c] then used[c]=true; n=n+1 end
  bounds[1]=math.min(bounds[1],x); bounds[2]=math.min(bounds[2],y)
  bounds[3]=math.max(bounds[3],x); bounds[4]=math.max(bounds[4],y)
 end
end end
print(string.format('PASS: %dx%d, %d colors, 9 layers, 1 frame; bounds %d,%d to %d,%d; binary alpha; reopened render matches PNG.',W,H,n,table.unpack(bounds)))
