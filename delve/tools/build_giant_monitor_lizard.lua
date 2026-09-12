-- Aseprite batch builder. Preserve manual master edits before rebuilding.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/giant-monitor-lizard-base/'
local W,H=120,56
local rgba=app.pixelColor.rgba
local colors={
 {'m',105,105,83,122,132,98}, {'s',75,72,59,75,87,65},
 {'d',47,45,36,42,53,41}, {'l',166,165,134,176,182,143},
 {'c',209,203,171,217,211,171}, {'o',29,28,22,24,30,27}, {'e',245,184,67,255,200,82},
}
local P={}; local palette=Palette(8); palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(colors) do
 P[c[1]]=rgba(c[5],c[6],c[7],255); palette:setColor(i,Color{r=c[5],g=c[6],b=c[7],a=255})
end
local names={'01 Tail','02 Far hind leg','03 Far foreleg','04 Ribcage and shoulder',
 '05 Near hind leg','06 Near foreleg','07 Neck and upper head','08 Lower jaw','09 Equipment - empty'}
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
for y=0,29 do for x=0,99 do
 local p=source:getPixel(math.floor(75+(x+.5)*1900/100),math.floor(160+(y+.5)*490/30))
 if app.pixelColor.rgbaA(p)>200 then
  local r,g,b=app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)
  local key,dist='m',math.huge
  for _,c in ipairs(colors) do local d=(r-c[2])^2+(g-c[3])^2+(b-c[4])^2
   if d<dist then key,dist=c[1],d end
  end
  local layer=4
  if x<53 then layer=1
  elseif y>=19 and x>=64 and x<=72 then layer=2
  elseif y>=17 and x>=85 then layer=3
  elseif y>=13 and x>=52 and x<=65 then layer=5
  elseif y>=16 and x>=73 and x<=84 then layer=6
  elseif x>=82 or y<10 and x>=73 then layer=7 end
  if layer==7 and y>=6 and y<=9 and x>=91 then layer=8 end
  if layer==2 or layer==3 then key=key=='l' and 's' or key=='m' and 's' or key end
  -- Remove isolated coat marks; shade the ribcage as a single broad plane.
  if key=='l' and layer==4 and y>=7 then key='m' end
  if layer==7 and x<88 and key=='s' and y<12 then key='m' end
  -- Neck-top chip has no overlap to explain it; keep this plane flat.
  if x>=79 and x<=82 and y>=11 and y<=13 then key='m' end
  if layer==4 then
   key=inside(x,y,{{52,19},{60,17},{66,17},{72,19},{82,15},{84,22},{52,24}}) and 's' or 'm'
  end
  if layer==5 and y<=20 then
   key=inside(x,y,{{59,15},{64,17},{64,21},{58,24},{57,21},{61,19}}) and 's' or 'm'
  end
  originals[layer]:drawPixel(x+5,y+22,P[key])
 end
end end
-- Tiny eye focal point and nose; no body texture.
originals[7]:drawPixel(99,25,P.o); originals[7]:drawPixel(100,25,P.e)
-- A monitor has a long blunt snout, distinct from the rising neck.
poly(originals[7],{{100,25},{106,25},{110,27},{110,30},{102,30},{99,28}},'m')
originals[7]:drawPixel(108,27,P.o); originals[7]:drawPixel(109,27,P.o)
originals[7]:drawPixel(100,25,P.e)
originals[8]=Image(W,H,ColorMode.RGB)
poly(originals[8],{{96,28},{102,29},{110,29},{109,31},{102,32},{96,31}},'c')
-- Connected splayed palms support short claw tips, not floating light clusters.
for _,foot in ipairs({{5,57,49},{6,81,49},{3,99,48}}) do
 local im,x,y=originals[foot[1]],foot[2],foot[3]
 for yy=y,51 do for xx=x,x+6 do im:drawPixel(xx,yy,0) end end
 poly(im,{{x,y},{x+4,y},{x+6,y+1},{x+6,y+2},{x,y+2},{x-1,y+1}},foot[1]==3 and 's' or 'm')
 for _,dx in ipairs({0,3,5}) do im:drawPixel(x+dx,y+2,P.c) end
end
-- A short chosen shoulder highlight, with no continuous rim.
for x=63,66 do originals[4]:drawPixel(x,30,P.l) end
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
   if name=='attack' and f>=2 and f<=4 and i==8 then
    original=Image(W,H,ColorMode.RGB)
    local gape=f==4 and 2 or 4
    -- Tapered cavity, upper snout stays fixed; lower jaw turns from cheek.
    poly(original,{{96,28},{110,29},{109,30+gape},{101,30+gape},{96,31}},'o')
    poly(original,{{95,29},{98,31},{109,30+gape},{109,32+gape},{102,32+gape},{96,32}},'c')
    poly(original,{{95,31},{99,33},{108,32+gape},{102,33+gape},{96,33}},'s')
    original:drawPixel(105,30,P.c); original:drawPixel(108,30,P.c)
   end
   for y=0,H-1 do for x=0,W-1 do
    -- Shared body deformation tapers to planted reptile feet.
    local shift=math.floor(ps[1]*math.max(0,math.min(1,(50-y)/14))+.5)
    local lift=math.floor(ps[2]*math.max(0,math.min(1,(49-y)/12))+.5)
    -- Tusk thrust lifts the muzzle through the same mapping as its support.
    
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
  flats[f]=flat(s,f); flats[f]:saveAs(dir..(name=='base' and 'giant-monitor-lizard-base' or name..'_'..f)..'.png')
 end
 local tag=s:newTag(1,#weights); tag.name=name=='idle' and 'rest' or name
 s:saveAs(dir..'giant-monitor-lizard-'..name..'.aseprite')
 if name=='base' then preview(flats[1],dir..'giant-monitor-lizard-base-8x.png',8)
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
 local reopened=app.open(dir..'giant-monitor-lizard-'..name..'.aseprite')
 assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch') end end
 end
 print('Verified '..name..': native master matches every frame')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{5,3,1,3,4},8,{{0,0,0},{0,1,0},{0,1,0},{0,1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,-1},{-2,0,-2},{4,0,2},{2,0,1},{0,0,0},{0,0,0}})
local board=Image(688,68,ColorMode.RGB); board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,16},{'design/goblin-base/goblin-base.png',48,0},
 {'design/kobold-base/kobold-base.png',104,0},{'design/wolf-base/wolf-base.png',168,6},
 {'design/viper-base/viper-base.png',240,14},{'design/spider-base/spider-base.png',304,14},
 {'design/boar-base/boar-base.png',384,14},{'design/grizzly-bear-base/grizzly-bear-base.png',472,-2},
 {'design/giant-monitor-lizard-base/giant-monitor-lizard-base.png',568,6}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
local silhouette=Image(W,H,ColorMode.RGB)
local base=Image{fromFile=dir..'giant-monitor-lizard-base.png'}
for y=0,H-1 do for x=0,W-1 do if app.pixelColor.rgbaA(base:getPixel(x,y))>0 then silhouette:drawPixel(x,y,P.c) end end end
preview(silhouette,dir..'silhouette-8x.png',8)

