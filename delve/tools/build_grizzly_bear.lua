-- Aseprite batch builder. Preserve manual master edits before rebuilding.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/grizzly-bear-base/'
local W,H=96,64
local rgba=app.pixelColor.rgba
local colors={
 {'m',143,110,84,149,115,86}, {'s',108,79,59,99,73,55},
 {'d',67,47,36,57,43,34}, {'l',202,175,136,198,169,126},
 {'c',215,193,154,227,210,167}, {'o',37,27,23,27,26,25}, {'e',240,219,163,250,207,114},
}
local P={}; local palette=Palette(8); palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(colors) do
 P[c[1]]=rgba(c[5],c[6],c[7],255); palette:setColor(i,Color{r=c[5],g=c[6],b=c[7],a=255})
end
local names={'01 Hidden tail - empty','02 Far hind leg','03 Far foreleg','04 Ribcage and shoulder',
 '05 Near hind leg','06 Near foreleg','07 Head and ears','08 Claws and face accents','09 Equipment - empty'}
local originals={}; for i=1,#names do originals[i]=Image(W,H,ColorMode.RGB) end
local function inside(x,y,ps)
 local b=false
 for i,a in ipairs(ps) do local z=ps[i%#ps+1]
  if (a[2]>y)~=(z[2]>y) and x<(z[1]-a[1])*(y-a[2])/(z[2]-a[2])+a[1] then b=not b end
 end
 return b
end
local function poly(im,ps,key)
 for y=0,H-1 do for x=0,W-1 do if inside(x+.5,y+.5,ps) then im:drawPixel(x,y,P[key]) end end end
end
local source=Image{fromFile=dir..'construction-reference.png'}
for gy=0,45 do for gx=0,75 do
 local x,y=gx*62/76,gy*38/46
 local p=source:getPixel(math.floor(124+(gx+.5)*1317/76),math.floor(120+(gy+.5)*796/46))
 if app.pixelColor.rgbaA(p)>200 then
  local r,g,b=app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)
  local key,dist='m',math.huge
  for _,c in ipairs(colors) do local d=(r-c[2])^2+(g-c[3])^2+(b-c[4])^2
   if d<dist then key,dist=c[1],d end
  end
  local layer=4
  if y>=23 and x>=15 and x<=26 then layer=2
  elseif y>=24 and x>=43 then layer=3
  elseif y>=19 and x<=15 then layer=5
  elseif y>=16 and x>=26 and x<=42 then layer=6
  elseif x>=45 then layer=7 end
  if layer==2 or layer==3 then key=key=='l' and 's' or key=='m' and 's' or key end
  -- Remove isolated coat marks; shade the ribcage as a single broad plane.
  if layer==4 and y<20 then
   key='m'
   if inside(x,y,{{0,19},{8,15},{17,17},{25,15},{30,10},{37,9},{44,14},{45,22},{0,23}}) then key='s' end
   if (x>=18 and x<=22 and y<=6) or (x>=34 and x<=39 and y<=2) then key='l' end
  end
  -- Remove isolated middle-shoulder highlight chips; retain toe accents.
  if layer==6 and gx+7>=40 and gx+7<=49 and gy+14>=33 and gy+14<=44 then key='s' end
  originals[layer]:drawPixel(gx+7,gy+14,P[key])
 end
end end
-- Complete the chest behind the removable near foreleg before posing it.
poly(originals[4],{{34,30},{44,25},{56,28},{62,37},{60,42},{52,45},{36,43}},'s')
poly(originals[4],{{48,38},{60,36},{59,42},{52,45},{43,43}},'d')
-- Near hind paw supports the same ground plane when the striking paw lifts.
for x=10,20 do originals[5]:drawPixel(x,59,P.d) end
originals[5]:drawPixel(18,59,P.c); originals[5]:drawPixel(20,59,P.c)
-- One warm eye pixel nested into the brow; keep muzzle and claws muted.
for _,p in ipairs({{75,35,'o'},{76,35,'e'},{77,35,'o'}}) do
 originals[8]:drawPixel(p[1],p[2],P[p[3]])
end
local function master()
 local s=Sprite(W,H,ColorMode.RGB); s:setPalette(palette)
 for i,n in ipairs(names) do local l=i==1 and s.layers[1] or s:newLayer(); l.name=n end
 return s
end
local function flat(s,f) local im=Image(s.spec); im:drawSprite(s,f); return im end
local function preview(im,path,scale)
 local s=Sprite(im.width,im.height,ColorMode.RGB); s:newCel(s.layers[1],1,im,Point(0,0)); app.sprite=s
 app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'}; s:saveAs(path)
end
local function saveClip(name,weights,fps,poses)
 local s=master(); local flats={}
 for f,ps in ipairs(poses) do
  if f>1 then s:newEmptyFrame() end
  for i,original in ipairs(originals) do
   local im=Image(W,H,ColorMode.RGB)
   if name=='attack' and f>=2 and f<=4 and i==6 then
    original=Image(W,H,ColorMode.RGB)
    if f==2 then
     poly(original,{{44,31},{52,29},{56,34},{55,41},{64,43},{64,48},{53,49},{47,44},{43,37}},'s')
     poly(original,{{51,36},{53,41},{61,44},{61,48},{53,48},{48,43}},'d')
    elseif f==3 then
     poly(original,{{44,31},{51,28},{58,33},{64,37},{73,32},{81,32},{85,35},{84,39},{76,41},{64,45},{57,42},{49,40}},'s')
     poly(original,{{50,36},{58,37},{65,41},{77,36},{83,36},{83,39},{76,41},{64,44},{56,41}},'d')
     for _,p in ipairs({{82,33},{84,35},{84,38}}) do original:drawPixel(p[1],p[2],P.c) end
    else
     poly(original,{{44,31},{51,29},{57,35},{65,43},{75,45},{78,48},{77,52},{70,52},{60,49},{50,43}},'s')
     poly(original,{{51,37},{61,44},{72,48},{77,48},{76,51},{69,51},{59,48}},'d')
     original:drawPixel(76,50,P.c)
    end
   end
   for y=0,H-1 do for x=0,W-1 do
    -- Shared connected deformation tapers to planted paws.
    local shift=math.floor(ps[1]*math.max(0,math.min(1,(58-y)/14))+.5)
    local lift=math.floor(ps[2]*math.max(0,math.min(1,(57-y)/12))+.5)
    
    local sx,sy=x-shift,y+lift
    if sx>=0 and sx<W and sy>=0 and sy<H then
     local p=original:getPixel(sx,sy)
     if name=='idle' and f==3 and p==P.e then p=P.s end
     im:drawPixel(x,y,p)
    end
   end end
   s:newCel(s.layers[i],f,im,Point(0,0))
  end
  s.frames[f].duration=weights[f]/fps
  flats[f]=flat(s,f); flats[f]:saveAs(dir..(name=='base' and 'grizzly-bear-base' or name..'_'..f)..'.png')
 end
 -- Foreleg passes in front of the cheek during a forward swipe.
 if name=='attack' then s.layers[6].stackIndex=8
  for f=1,#weights do flats[f]=flat(s,f); flats[f]:saveAs(dir..'attack_'..f..'.png') end
 end
 local tag=s:newTag(1,#weights); tag.name=name=='idle' and 'rest' or name
 s:saveAs(dir..'grizzly-bear-'..name..'.aseprite')
 if name=='base' then preview(flats[1],dir..'grizzly-bear-base-8x.png',8)
 else
  local timing=io.open(dir..name..'-timing.json','w')
  timing:write('{"fps":'..fps..',"weights":['..table.concat(weights,',')..']'..(name=='attack' and ',"impact_frame":2' or '')..'}\n'); timing:close()
  local sheet=Image(W*#weights,H,ColorMode.RGB); sheet:clear(Color{r=53,g=56,b=62,a=255})
  local gif=Sprite(W,H,ColorMode.RGB)
  for f,im in ipairs(flats) do
   sheet:drawImage(im,Point((f-1)*W,0)); if f>1 then gif:newEmptyFrame() end
   local bg=Image(W,H,ColorMode.RGB); bg:clear(Color{r=53,g=56,b=62,a=255}); bg:drawImage(im)
   gif:newCel(gif.layers[1],f,bg,Point(0,0)); gif.frames[f].duration=weights[f]/fps
  end
  if name=='attack' then gif.frames[#weights].duration=.8 end
  app.sprite=gif; app.command.SpriteSize{width=W*4,height=H*4,method='nearest'}; gif:saveAs(dir..name..'-preview.gif')
  preview(sheet,dir..name..'-frames-4x.png',4)
 end
 local reopened=app.open(dir..'grizzly-bear-'..name..'.aseprite')
 assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch') end end
 end
 print('Verified '..name..': native master matches every frame')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{6,3,1,3,5},8,{{0,0,0},{0,1,0},{0,1,0},{0,1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,-1},{-2,0,-2},{4,0,2},{2,0,1},{0,0,0},{0,0,0}})
local board=Image(572,68,ColorMode.RGB); board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,16},{'design/goblin-base/goblin-base.png',48,0},
 {'design/kobold-base/kobold-base.png',104,0},{'design/wolf-base/wolf-base.png',168,6},
 {'design/viper-base/viper-base.png',240,14},{'design/spider-base/spider-base.png',304,14},
 {'design/boar-base/boar-base.png',384,14},{'design/grizzly-bear-base/grizzly-bear-base.png',472,-2}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
local support=Image(W,H,ColorMode.RGB)
for i,im in ipairs(originals) do if i~=6 then support:drawImage(im) end end
preview(support,dir..'foreleg-hidden-8x.png',8)
local silhouette=Image(W,H,ColorMode.RGB)
local base=Image{fromFile=dir..'grizzly-bear-base.png'}
for y=0,H-1 do for x=0,W-1 do if app.pixelColor.rgbaA(base:getPixel(x,y))>0 then silhouette:drawPixel(x,y,P.c) end end end
preview(silhouette,dir..'silhouette-8x.png',8)

