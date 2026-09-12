-- Native Aseprite construction. Rebuild overwrites generated masters.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/spider-base/'
local W,H=72,48
local rgba=app.pixelColor.rgba
local swatches={m='997055',s='6a4b3b',d='2d2724',l='bf9470',o='201e1c',c='e4d8b6',e='ffca66'}
local P={}; local palette=Palette(8); palette:setColor(0,Color{r=0,g=0,b=0,a=0})
local index=1
for _,k in ipairs({'m','s','d','l','o','c','e'}) do
 local hex=swatches[k]; local r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
 P[k]=rgba(r,g,b,255); palette:setColor(index,Color{r=r,g=g,b=b,a=255}); index=index+1
end
local names={'01 Far rear leg','02 Far middle rear leg','03 Far middle front leg','04 Far front leg',
 '05 Abdomen','06 Cephalothorax','07 Near rear leg','08 Near middle rear leg','09 Near middle front leg','10 Near front leg','11 Palps and fangs','12 Equipment - empty'}
local function polygon(im,pts,k)
 for y=0,H-1 do for x=0,W-1 do
  local inside=false
  for i,a in ipairs(pts) do local b=pts[i%#pts+1]
   if (a[2]>y+.5)~=(b[2]>y+.5) and x+.5<(b[1]-a[1])*(y+.5-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
  end
  if inside then im:drawPixel(x,y,P[k]) end
 end end
end
local function line(im,a,b,r1,r2,k)
 local dx,dy=b[1]-a[1],b[2]-a[2]; local len=dx*dx+dy*dy
 for y=0,H-1 do for x=0,W-1 do
  local t=len==0 and 0 or math.max(0,math.min(1,((x-a[1])*dx+(y-a[2])*dy)/len))
  local r=r1+(r2-r1)*t
  if (x-a[1]-t*dx)^2+(y-a[2]-t*dy)^2<=r*r then im:drawPixel(x,y,P[k]) end
 end end
end
local function moved(pts,dx,dy)
 local q={}; for _,p in ipairs(pts) do q[#q+1]={p[1]+dx,p[2]+dy} end; return q
end
local legs={
 {{36,28},{9,29},{3,40}},{{38,27},{22,32},{17,41}},
 {{41,27},{48,21},{53,41}},{{43,28},{56,23},{66,41}},
 {{36,29},{25,26},{8,43}},{{39,30},{33,25},{26,43}},
 {{42,31},{42,32},{45,43}},{{44,30},{55,27},{63,43}},
}
local function pose(dx,dy,frontLift)
 local ims={}; for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
 for n,chain in ipairs(legs) do
  local near=n>4; local im=ims[near and n+2 or n]
  local a={chain[1][1]+dx,chain[1][2]+dy}
  local b={chain[2][1]+math.floor(dx/2),chain[2][2]+dy}
  local c={chain[3][1],chain[3][2]}
  if n==8 and frontLift~=0 then b[2]=b[2]-2; c[1]=c[1]+math.max(0,dx); c[2]=c[2]-frontLift end
  line(im,a,b,near and 2 or 1.5,1.6,near and 'd' or 's')
  line(im,b,c,1.6,.6,'s')
  if near then
   line(im,{b[1]+(c[1]-b[1])*.72,b[2]+(c[2]-b[2])*.72},c,.7,.5,'d')
   line(im,{a[1],a[2]-1},{b[1],b[2]-1},1.1,1.1,'m')
   local t=.7; line(im,{b[1],b[2]-1},{b[1]+(c[1]-b[1])*t,b[2]+(c[2]-b[2])*t},.9,.6,'m')
   if n==5 or n==8 then line(im,{b[1]-1,b[2]-1},{b[1]+1,b[2]-1},.5,.5,'l') end
  else
   -- Far limbs recede, but their upper segments must remain legible.
   line(im,{c[1],c[2]-2},c,.6,.5,'d')
  end
 end
 local abdomen=ims[5]
 polygon(abdomen,moved({{11,19},{16,15},{25,14},{31,16},{36,21},{36,27},{32,32},{24,34},{16,31},{11,26}},dx,dy),'m')
 polygon(abdomen,moved({{11,24},{16,27},{23,29},{30,29},{35,25},{36,27},{32,32},{24,34},{16,31},{11,26}},dx,dy),'s')
 polygon(abdomen,moved({{16,15},{25,14},{28,15},{25,16},{18,17}},dx,dy),'l')
 polygon(abdomen,moved({{16,29},{23,31},{30,30},{35,26},{36,27},{32,32},{24,34},{16,31}},dx,dy),'d')
 local head=ims[6]
 polygon(head,moved({{34,24},{38,22},{43,23},{48,26},{51,30},{50,34},{44,36},{37,34},{33,30}},dx,dy),'m')
 polygon(head,moved({{35,24},{38,22},{42,23},{44,25},{39,24}},dx,dy),'l')
 polygon(head,moved({{33,29},{38,31},{44,33},{50,31},{50,34},{44,36},{37,34}},dx,dy),'s')
 polygon(head,moved({{37,32},{43,33},{49,31},{50,34},{46,36},{42,35}},dx,dy),'d')
 local mouth=ims[11]
 local bite=frontLift>0 and dx>0
 -- Two solid brown chelicerae, each ending in a dark inward-curving fang.
 -- No open vertebrate jaw, white teeth, or hanging ivory bars.
 local rows=bite and {'mmsds..','mmsdmms','smodmms','.oodsss','.o...oo','..o.oo.'} or
   {'mmsds..','mmsdmms','smodmms','.oodsss','..o.oo.','..ooo..'}
 for row,mask in ipairs(rows) do for col=1,#mask do
  local key=mask:sub(col,col)
  if P[key] then mouth:drawPixel(47+col+dx,28+row+dy,P[key]) end
 end end
 -- The face is in front of the near foreleg, including the tiny eye accents.
 mouth:drawPixel(49+dx,28+dy,P.o)
 mouth:drawPixel(49+dx,27+dy,P.e)
 return ims
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
  for i,im in ipairs(pose(ps[1],ps[2],ps[3])) do s:newCel(s.layers[i],f,im,Point(0,0)) end
  s.frames[f].duration=weights[f]/fps
  flats[f]=flat(s,f); flats[f]:saveAs(dir..(name=='base' and 'spider-base' or name..'_'..f)..'.png')
 end
 local tag=s:newTag(1,#weights); tag.name=name=='idle' and 'rest' or name
 s:saveAs(dir..'spider-'..name..'.aseprite')
 if name=='base' then preview(flats[1],dir..'spider-base-8x.png',8)
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
 local reopened=app.open(dir..'spider-'..name..'.aseprite')
 assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch') end end
 end
 print('Verified '..name..': native master matches all frames')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{4,3,2,3,4},8,{{0,0,0},{0,-1,0},{0,-1,1},{0,-1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,0},{-2,-1,5},{4,1,4},{2,1,2},{0,0,0},{0,0,0}})
local board=Image(400,68,ColorMode.RGB); board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,16},{'design/goblin-base/goblin-base.png',48,0},
 {'design/kobold-base/kobold-base.png',104,0},{'design/wolf-base/wolf-base.png',168,6},
 {'design/viper-base/viper-base.png',240,14},{'design/spider-base/spider-base.png',310,14}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
