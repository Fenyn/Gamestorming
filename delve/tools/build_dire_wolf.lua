-- Native authored reconstruction from the generated pose; master edits must be encoded here.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/dire-wolf-base/'
local runtime=root..'/assets/sprites/enemies/dire_wolf_base/'
local W,H=96,64
local rgba=app.pixelColor.rgba
local colors={{'m',119,115,107},{'s',70,73,72},{'d',39,46,46},{'l',172,179,174},{'c',204,201,178},{'h',147,150,137},{'o',23,29,30},{'e',247,190,78}}
local P={}; local palette=Palette(9); palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(colors) do P[c[1]]=rgba(c[2],c[3],c[4],255); palette:setColor(i,Color{r=c[2],g=c[3],b=c[4],a=255}) end
local names={'01 Tail','02 Far hind leg','03 Far foreleg','04 Ribcage','05 Near hind leg','06 Near foreleg','07 Ruff and skull','08 Lower jaw','09 Face accents','10 Equipment - empty'}
local originals={}; for i=1,#names do originals[i]=Image(W,H,ColorMode.RGB) end
local shaped={}
local function poly(i,k,ps)
 for y=0,H-1 do for x=0,W-1 do local on=false
  for a,p in ipairs(ps) do local q=ps[a%#ps+1]; if (p[2]>y+.5)~=(q[2]>y+.5) and x+.5<(q[1]-p[1])*(y+.5-p[2])/(q[2]-p[2])+p[1] then on=not on end end
  if on and (not shaped[i] or i==9 or app.pixelColor.rgbaA(originals[i]:getPixel(x,y))>0) then originals[i]:drawPixel(x,y,P[k]) end
 end end
 shaped[i]=true
end
local function px(i,k,x,y) originals[i]:drawPixel(x,y,P[k]) end
-- Complete tail and supporting limbs continue under foreground anatomy.
poly(1,'s',{{29,27},{27,37},{22,46},{16,51},{7,54},{3,52},{7,47},{14,43},{21,34}})
poly(1,'m',{{27,27},{29,31},{22,41},{14,46},{6,50},{4,52},{7,47},{14,42},{21,33}})
poly(1,'c',{{5,49},{10,48},{9,51},{14,49},{12,52},{7,54},{3,52}})
poly(2,'s',{{33,33},{41,36},{39,43},{35,48},{37,54},{40,57},{44,58},{44,60},{36,60},{33,56},{30,49},{31,43}})
poly(2,'d',{{35,35},{40,37},{38,43},{34,46},{32,45}})
poly(2,'h',{{40,57},{43,58},{43,60},{39,60},{39,58}})
poly(3,'s',{{64,32},{71,33},{73,38},{71,44},{73,51},{76,56},{81,58},{81,60},{73,60},{70,56},{68,51},{66,44}})
poly(3,'d',{{64,34},{67,34},{69,39},{68,44},{67,47},{66,43}})
poly(3,'h',{{78,57},{80,58},{80,60},{77,60},{77,58}})
poly(4,'m',{{22,30},{26,25},{34,23},{41,24},{49,22},{56,18},{65,17},{72,22},{70,33},{64,41},{54,44},{46,41},{39,40},{33,36},{26,38},{22,36}})
poly(4,'s',{{29,35},{36,36},{43,38},{50,38},{55,36},{59,33},{65,32},{65,41},{56,44},{47,42},{40,40},{34,38},{29,39}})
poly(4,'d',{{36,39},{43,40},{50,41},{55,41},{57,43},{55,44},{48,42},{41,41}})
poly(4,'l',{{27,25},{34,23},{38,24},{37,25},{32,25},{28,26}})
poly(4,'l',{{47,23},{51,21},{55,20},{55,22},{50,23}})
poly(5,'m',{{26,30},{32,29},{36,32},{38,37},{36,42},{33,45},{29,49},{25,52},{25,56},{29,57},{31,59},{31,60},{22,60},{21,58},{22,51},{25,47},{28,43},{26,41},{23,38},{23,34}})
-- Shadow turns around the rear of the rounded thigh, then narrows at the hock.
poly(5,'s',{{26,39},{29,42},{29,44},{26,48},{23,52},{23,56},{25,57},{23,58},{22,57},{22,51},{25,46},{27,43},{24,40}})
poly(5,'h',{{24,56},{27,57},{29,58},{30,60},{23,60},{22,58}})
poly(5,'c',{{25,57},{28,58},{28,59},{24,59},{23,58}})
px(5,'d',28,59)
poly(6,'m',{{57,27},{63,28},{67,33},{67,38},{64,43},{62,48},{62,55},{65,57},{68,58},{68,60},{59,60},{57,58},{57,54},{58,48},{59,44},{57,41},{54,37},{54,32}})
-- Back-facing shoulder plane curves into the elbow; wrist remains slender.
poly(6,'s',{{55,32},{57,34},{57,38},{60,42},{61,44},{60,48},{59,53},{59,56},{61,58},{58,58},{57,55},{58,48},{59,44},{56,41},{54,37}})
poly(6,'h',{{60,56},{63,57},{67,58},{68,60},{59,60},{58,58}})
poly(6,'c',{{61,57},{64,58},{65,59},{60,59},{59,58}})
px(6,'d',65,59)
poly(7,'m',{{54,24},{57,18},{61,17},{60,15},{65,16},{69,18},{72,13},{74,8},{77,17},{80,12},{81,11},{82,18},{85,21},{86,24},{90,27},{91,29},{88,31},{81,31},{77,34},{74,38},{71,41},{67,43},{68,38},{64,39},{65,35},{61,35},{63,31},{59,32},{60,28},{56,29}})
poly(7,'s',{{71,17},{74,9},{76,16},{75,21},{72,24},{69,24},{68,28},{65,28},{67,24},{67,21}})
poly(7,'c',{{73,14},{74,11},{75,16},{74,19},{72,21},{72,18}})
poly(7,'d',{{79,15},{81,12},{82,18},{80,19}})
poly(7,'c',{{79,25},{82,26},{83,28},{87,28},{88,27},{90,29},{88,31},{83,31},{80,30},{77,32},{74,36},{71,38},{71,40},{67,42},{69,37},{69,34},{72,31},{75,29},{75,27}})
poly(7,'h',{{69,33},{72,31},{70,35},{70,38},{67,42},{68,37},{65,38},{66,35}})
poly(7,'l',{{57,18},{61,17},{65,18},{66,20},{63,20},{61,19},{58,20}})
poly(7,'l',{{79,20},{82,20},{84,22},{82,22}})
poly(8,'h',{{80,30},{83,31},{88,30},{89,31},{87,33},{82,33},{79,32}})
poly(8,'c',{{82,31},{87,31},{87,32},{82,32}})
poly(9,'o',{{87,28},{91,28},{91,30},{89,31},{88,30}})
poly(9,'d',{{79,24},{82,24},{83,26},{80,27},{79,26}})
px(9,'e',81,25);px(9,'e',80,25);px(9,'o',82,25)
local function master() local s=Sprite(W,H,ColorMode.RGB);s:setPalette(palette);for i,n in ipairs(names) do local l=i==1 and s.layers[1] or s:newLayer();l.name=n end;return s end
local function flat(s,f) local im=Image(s.spec);im:drawSprite(s,f);return im end
local function preview(im,path,scale) local s=Sprite(im.width,im.height,ColorMode.RGB);s:newCel(s.layers[1],1,im,Point(0,0));app.sprite=s;app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'};s:saveAs(path) end
local baseFlat
local function saveClip(name,weights,fps,poses)
 local s=master();local flats={}
 for f,ps in ipairs(poses) do
  if f>1 then s:newEmptyFrame() end
  for i,original in ipairs(originals) do
   local im=Image(W,H,ColorMode.RGB)
   for y=0,H-1 do for x=0,W-1 do
    local factor=math.max(0,math.min(1,(57-y)/17))
    local shift=math.floor(ps[1]*factor+.5); local lift=math.floor(ps[2]*factor+.5)
    local sx,sy=x-shift,y+lift
    if i==8 and ps[3]>0 then sy=sy-math.floor(ps[3]*math.max(0,math.min(1,(sx-79)/8))+.5) end
    if sx>=0 and sx<W and sy>=0 and sy<H then
     local p=original:getPixel(sx,sy); if name=='idle' and f==3 and p==P.e then p=P.d end
     im:drawPixel(x,y,p)
    end
   end end
   -- Exposed cavity follows the cheek hinge; upper nose/muzzle stay fixed.
   if i==8 and ps[3]>0 then
    im:clear()
    local shift=ps[1]; local lift=ps[2]
    for x=79,88 do local depth=math.floor(ps[3]*(x-79)/9+.5)
     for y=31,31+depth do im:drawPixel(x+shift,y-lift,P.o) end
     im:drawPixel(x+shift,32+depth-lift,P.h)
     if x>=81 and x<=87 then im:drawPixel(x+shift,32+depth-lift,P.c) end
    end
    im:drawPixel(85+shift,32-lift,P.c)
    if ps[3]>=2 then im:drawPixel(87+shift,33-lift,P.c) end
   end
   s:newCel(s.layers[i],f,im,Point(0,0))
  end
  s.frames[f].duration=weights[f]/fps;flats[f]=flat(s,f)
  flats[f]:saveAs(dir..(name=='base' and 'dire-wolf-base' or name..'_'..f)..'.png')
  flats[f]:saveAs(runtime..(name=='base' and 'base' or name..'_'..f)..'.png')
 end
 local tag=s:newTag(1,#weights);tag.name=name=='idle' and 'rest' or name;s:saveAs(dir..'dire-wolf-'..name..'.aseprite')
 if name=='base' then baseFlat=flats[1];preview(baseFlat,dir..'dire-wolf-base-8x.png',8)
 else
  local timing=io.open(dir..name..'-timing.json','w');timing:write('{"fps":'..fps..',"weights":['..table.concat(weights,',')..']'..(name=='attack' and ',"impact_frame":2' or '')..'}\n');timing:close()
  local sheet=Image(W*#weights,H,ColorMode.RGB);sheet:clear(Color{r=53,g=56,b=62,a=255})
  local gif=Sprite(W,H,ColorMode.RGB)
  for f,im in ipairs(flats) do sheet:drawImage(im,Point((f-1)*W,0));if f>1 then gif:newEmptyFrame() end;local bg=Image(W,H,ColorMode.RGB);bg:clear(Color{r=53,g=56,b=62,a=255});bg:drawImage(im);gif:newCel(gif.layers[1],f,bg,Point(0,0));gif.frames[f].duration=weights[f]/fps end
  if name=='attack' then gif.frames[#weights].duration=.8 end
  app.sprite=gif;app.command.SpriteSize{width=W*4,height=H*4,method='nearest'};gif:saveAs(dir..name..'-preview.gif');preview(sheet,dir..name..'-frames-4x.png',4)
 end
 local reopened=app.open(dir..'dire-wolf-'..name..'.aseprite');assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do local p=im:getPixel(x,y);assert(check:getPixel(x,y)==p,'Master mismatch');local a=app.pixelColor.rgbaA(p);assert(a==0 or a==255,'Partial alpha');if name=='attack' and f==#weights or name=='idle' and f==1 then assert(p==baseFlat:getPixel(x,y),'Recovery/base mismatch') end end end
 end
 print('Verified '..name..': every saved master frame matches PNG; alpha binary; recovery exact')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{5,4,1,3,5},8,{{0,0,0},{0,1,0},{0,1,0},{0,1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,0},{-2,0,4},{3,0,2},{2,0,3},{0,0,1},{0,0,0}})
local board=Image(400,70,ColorMode.RGB);board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,20},{'design/goblin-base/goblin-base.png',48,4},{'design/wolf-base/wolf-base.png',108,10},{'design/boar-base/boar-base.png',182,18},{'design/dire-wolf-base/dire-wolf-base.png',258,2}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
local review=Image(W*3,H,ColorMode.RGB);review:clear(Color{r=53,g=56,b=62,a=255})
review:drawImage(Image{fromFile=dir..'before-leg-shading-review/dire-wolf-base.png'},Point(0,0))
review:drawImage(baseFlat,Point(W,0))
local support=Image(W,H,ColorMode.RGB)
for i,im in ipairs(originals) do if i~=5 and i~=6 then support:drawImage(im) end end
support:saveAs(dir..'near-legs-hidden.png');review:drawImage(support,Point(W*2,0));preview(review,dir..'leg-shading-before-after-support-6x.png',6)
local silhouette=Image(baseFlat);for it in silhouette:pixels() do if app.pixelColor.rgbaA(it())>0 then it(rgba(219,219,203,255)) end end;preview(silhouette,dir..'silhouette-8x.png',8)
