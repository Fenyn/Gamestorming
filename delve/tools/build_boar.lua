-- Aseprite batch builder. Preserve manual master edits before rebuilding.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/boar-base/'
local W,H=72,48
local rgba=app.pixelColor.rgba
local colors={
 {'m',106,90,81,128,111,96}, {'s',72,60,55,78,66,59},
 {'d',46,39,38,43,39,36}, {'l',157,140,120,184,168,141},
 {'c',240,227,194,239,224,183}, {'o',30,26,25,26,26,24}, {'e',245,184,67,255,201,96},
}
local P={}; local palette=Palette(8); palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(colors) do
 P[c[1]]=rgba(c[5],c[6],c[7],255); palette:setColor(i,Color{r=c[5],g=c[6],b=c[7],a=255})
end
local names={'01 Tail','02 Far hind leg','03 Far foreleg','04 Ribcage and shoulder',
 '05 Near hind leg','06 Near foreleg','07 Head and ears','08 Tusks','09 Equipment - empty'}
local originals={}; for i=1,#names do originals[i]=Image(W,H,ColorMode.RGB) end
local source=Image{fromFile=dir..'construction-reference.png'}
for y=0,30 do for x=0,55 do
 local p=source:getPixel(math.floor(155+(x+.5)*1328/56),math.floor(145+(y+.5)*725/31))
 if app.pixelColor.rgbaA(p)>200 then
  local r,g,b=app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)
  local key,dist='m',math.huge
  for _,c in ipairs(colors) do local d=(r-c[2])^2+(g-c[3])^2+(b-c[4])^2
   if d<dist then key,dist=c[1],d end
  end
  local layer=4
  if x<8 then layer=1
  elseif y>=20 and x>=14 and x<=22 then layer=2
  elseif y>=20 and x>=35 and x<=46 then layer=3
  elseif y>=15 and x<=15 then layer=5
  elseif y>=15 and x>=26 and x<=35 then layer=6
  elseif x>=39 then layer=7 end
  if key=='c' and x>=45 then layer=8 end
  if layer==2 or layer==3 then key=key=='l' and 's' or key=='m' and 's' or key end
  -- Remove isolated coat marks; shade the ribcage as a single broad plane.
  if key=='l' and layer==4 and y>=7 then key='m' end
  originals[layer]:drawPixel(x+6,y+13,P[key])
 end
end end
-- Keep the near tusk a crisp upward hook, visibly rooted in the lower cheek.
for _,p in ipairs({{56,32,'l'},{55,31,'c'},{55,30,'c'},{56,29,'c'},{57,28,'c'}}) do
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
   for y=0,H-1 do for x=0,W-1 do
    -- All layers share a continuous body shear, tapering to planted hooves.
    local shift=math.floor(ps[1]*math.max(0,math.min(1,(42-y)/12))+.5)
    local lift=math.floor(ps[2]*math.max(0,math.min(1,(41-y)/10))+.5)
    -- Tusk thrust lifts the muzzle through the same mapping as its support.
    if name=='attack' and x>=45 then lift=lift+math.floor(ps[3]*math.min(1,(x-45)/10)*math.max(0,math.min(1,(40-y)/6))+.5) end
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
  flats[f]=flat(s,f); flats[f]:saveAs(dir..(name=='base' and 'boar-base' or name..'_'..f)..'.png')
 end
 local tag=s:newTag(1,#weights); tag.name=name=='idle' and 'rest' or name
 s:saveAs(dir..'boar-'..name..'.aseprite')
 if name=='base' then preview(flats[1],dir..'boar-base-8x.png',8)
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
 local reopened=app.open(dir..'boar-'..name..'.aseprite')
 assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch') end end
 end
 print('Verified '..name..': native master matches every frame')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{5,3,1,3,5},8,{{0,0,0},{0,1,0},{0,1,0},{0,1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,-1},{-2,0,-2},{4,0,2},{2,0,1},{0,0,0},{0,0,0}})
local board=Image(472,68,ColorMode.RGB); board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,16},{'design/goblin-base/goblin-base.png',48,0},
 {'design/kobold-base/kobold-base.png',104,0},{'design/wolf-base/wolf-base.png',168,6},
 {'design/viper-base/viper-base.png',240,14},{'design/spider-base/spider-base.png',304,14},
 {'design/boar-base/boar-base.png',384,14}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
