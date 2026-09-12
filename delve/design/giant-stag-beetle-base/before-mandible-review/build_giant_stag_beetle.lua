-- Authored native pixel construction. Rebuild regenerates all masters and runtime assets.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/giant-stag-beetle-base/'
local W,H=88,64
local rgba=app.pixelColor.rgba
local swatches={m='995e45',s='633d32',d='34312e',l='c7986c',o='1e2222',c='666857',h='969981',e='ffc96c'}
local P={}; local palette=Palette(9); palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,k in ipairs({'m','s','d','l','o','c','h','e'}) do
 local hex=swatches[k]; local r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
 P[k]=rgba(r,g,b,255); palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local names={'01 Far hind leg','02 Far middle leg','03 Far foreleg','04 Abdomen and elytra','05 Pronotum','06 Head','07 Near hind leg','08 Near middle leg','09 Near foreleg','10 Far mandible','11 Near mandible','12 Antennae'}
local function polygon(im,pts,k)
 for y=0,H-1 do for x=0,W-1 do local inside=false
  for i,a in ipairs(pts) do local b=pts[i%#pts+1]
   if (a[2]>y+.5)~=(b[2]>y+.5) and x+.5<(b[1]-a[1])*(y+.5-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
  end
  if inside then im:drawPixel(x,y,P[k]) end
 end end
end
local function line(im,a,b,r1,r2,k)
 local dx,dy=b[1]-a[1],b[2]-a[2]; local len=dx*dx+dy*dy
 for y=0,H-1 do for x=0,W-1 do
  local t=len==0 and 0 or math.max(0,math.min(1,((x-a[1])*dx+(y-a[2])*dy)/len)); local r=r1+(r2-r1)*t
  if (x-a[1]-t*dx)^2+(y-a[2]-t*dy)^2<=r*r then im:drawPixel(x,y,P[k]) end
 end end
end
local function moved(pts,dx,dy) local q={}; for _,p in ipairs(pts) do q[#q+1]={p[1]+dx,p[2]+dy} end; return q end
local legs={{{41,37},{26,39},{15,55}},{{46,36},{42,40},{39,55}},{{51,37},{61,43},{67,55}},{{41,40},{27,47},{18,59}},{{46,41},{40,49},{45,59}},{{51,41},{58,47},{65,59}}}
local function pose(dx,dy,jaw)
 local ims={}; for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
 for n,chain in ipairs(legs) do
  local near=n>3; local im=ims[near and n+3 or n]
  local a={chain[1][1]+dx,chain[1][2]+dy}; local b={chain[2][1]+math.floor(dx/2),chain[2][2]+dy}; local c=chain[3]
  line(im,a,b,2,1.7,near and 'c' or 'd'); line(im,b,c,1.7,.6,near and 'c' or 'd')
  line(im,{c[1]-1,c[2]}, {c[1]+2,c[2]},.6,.4,'o')
  if near then
   line(im,a,{a[1]+(b[1]-a[1])*.35,a[2]+(b[2]-a[2])*.35},1.5,1,'o')
   line(im,{b[1],b[2]+1},{b[1]+(c[1]-b[1])*.65,b[2]+(c[2]-b[2])*.65},.8,.6,'d')
   line(im,{b[1]-1,b[2]-1},{b[1],b[2]},.6,.6,'h')
  end
 end
 local function poly(i,pts,k) polygon(ims[i],moved(pts,dx,dy),k) end
 poly(4,{{10,30},{13,23},{21,18},{32,17},{42,21},{48,28},{48,36},{43,43},{33,46},{21,44},{13,39}},'m')
 poly(4,{{10,30},{15,35},{25,39},{36,40},{44,36},{48,31},{48,36},{43,43},{33,46},{21,44},{13,39}},'s')
 poly(4,{{19,43},{30,44},{39,42},{46,37},{43,43},{33,46},{21,44}},'o')
 poly(4,{{16,22},{22,18},{31,17},{33,18},{23,20},{20,22}},'l')
 poly(4,{{13,27},{23,25},{34,27},{45,31},{45,33},{33,29},{23,27},{13,29}},'s')
 poly(5,{{43,26},{48,25},{54,28},{57,34},{55,42},{49,45},{44,41},{42,35}},'c')
 poly(5,{{43,34},{48,38},{54,39},{56,36},{55,42},{49,45},{44,41}},'d')
 poly(5,{{43,29},{44,28},{44,35},{46,39},{44,41},{42,35}},'d')
 poly(5,{{45,27},{48,25},{52,27},{50,28},{47,28}},'h')
 poly(6,{{55,30},{61,30},{66,34},{66,41},{61,46},{55,44},{52,39},{53,34}},'c')
 poly(6,{{53,37},{59,40},{65,38},{66,41},{61,46},{55,44},{52,39}},'d')
 poly(6,{{56,31},{61,30},{63,32},{59,32}},'h')
 ims[6]:drawPixel(63+dx,37+dy,P.o); ims[6]:drawPixel(63+dx,36+dy,P.e)
 -- Two curved pincers, each rooted to the head and bearing a single medial tooth.
 local upper={{64,33},{68,30-jaw},{74,29-jaw},{80,32-jaw},{82,37-jaw},{79,35-jaw},{75,33-jaw},{72,34-jaw},{71,37-jaw},{69,34-jaw},{65,37}}
 poly(10,upper,'s')
 poly(10,{{66,33},{70,31-jaw},{75,30-jaw},{79,32-jaw},{75,32-jaw},{70,33-jaw},{66,36}},'m')
 poly(11,{{64,41},{69,44+jaw},{75,45+jaw},{81,42+jaw},{82,38+jaw},{79,40+jaw},{75,41+jaw},{73,38+jaw},{72,42+jaw},{69,41+jaw},{65,38}},'s')
 poly(11,{{65,40},{69,43+jaw},{75,44+jaw},{79,42+jaw},{75,43+jaw},{70,42+jaw},{65,38}},'m')
 poly(11,{{69,42+jaw},{73,43+jaw},{74,44+jaw},{70,44+jaw}},'l')
 line(ims[12],{58+dx,32+dy},{59+dx,27+dy},.6,.5,'d')
 line(ims[12],{59+dx,27+dy},{63+dx,26+dy},.5,.8,'c')
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
  flats[f]=flat(s,f); flats[f]:saveAs(dir..(name=='base' and 'giant-stag-beetle-base' or name..'_'..f)..'.png')
 end
 local tag=s:newTag(1,#weights); tag.name=name=='idle' and 'rest' or name
 s:saveAs(dir..'giant-stag-beetle-'..name..'.aseprite')
 if name=='base' then preview(flats[1],dir..'giant-stag-beetle-base-8x.png',8)
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
 local reopened=app.open(dir..'giant-stag-beetle-'..name..'.aseprite')
 assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch') end end
 end
print('Verified '..name..': native master matches all frames')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{5,3,2,3,5},8,{{0,0,0},{0,-1,0},{0,-1,1},{0,-1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,1},{-2,-1,3},{3,0,-2},{2,1,-1},{0,0,0},{0,0,0}})
local board=Image(430,74,ColorMode.RGB); board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,22},{'design/goblin-base/goblin-base.png',48,6},
 {'design/wolf-base/wolf-base.png',108,12},{'design/boar-base/boar-base.png',182,20},
 {'design/spider-base/spider-base.png',256,20},{'design/giant-stag-beetle-base/giant-stag-beetle-base.png',334,4}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)


