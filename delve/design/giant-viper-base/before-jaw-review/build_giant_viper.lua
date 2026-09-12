-- Native Aseprite reconstruction. Preserve manual master edits before rebuilding.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/giant-viper-base/'
local runtime=root..'/assets/sprites/enemies/giant_viper_base/'
local W,H=96,64
local rgba=app.pixelColor.rgba
local colors={{'m',126,143,91},{'s',80,98,58},{'d',44,58,44},{'l',183,197,139},{'c',212,204,169},{'h',155,159,119},{'o',25,32,28},{'e',255,201,93}}
local P={};local palette=Palette(9);palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(colors) do P[c[1]]=rgba(c[2],c[3],c[4],255);palette:setColor(i,Color{r=c[2],g=c[3],b=c[4],a=255}) end
local names={'01 Tail','02 Rear coil','03 Front coil','04 Raised neck','05 Broad skull','06 Lower jaw','07 Eye and fangs','08 Equipment - empty'}
local originals={};for i=1,#names do originals[i]=Image(W,H,ColorMode.RGB) end
local shaped={}
-- Giant Viper is Medium: native authored landmarks are compacted to a 62x45
-- envelope, with ample blank canvas on the right for the forward strike.
local function X(x) return 12+math.floor((x-3)*.8+.5) end
local function Y(y) return 60-math.floor((60-y)*.9+.5) end
local function poly(i,k,ps)
 local transformed={};for _,p in ipairs(ps) do table.insert(transformed,{X(p[1]),Y(p[2])}) end;ps=transformed
 for y=0,H-1 do for x=0,W-1 do local on=false
  for a,p in ipairs(ps) do local q=ps[a%#ps+1];if (p[2]>y+.5)~=(q[2]>y+.5) and x+.5<(q[1]-p[1])*(y+.5-p[2])/(q[2]-p[2])+p[1] then on=not on end end
  if on and (not shaped[i] or i==7 or app.pixelColor.rgbaA(originals[i]:getPixel(x,y))>0) then originals[i]:drawPixel(x,y,P[k]) end
 end end;shaped[i]=true
end
local function px(i,k,x,y) originals[i]:drawPixel(X(x),Y(y),P[k]) end
-- A tapering tail continues behind the resting loop.
poly(1,'m',{{31,47},{31,58},{21,59},{14,57},{9,54},{5,50},{3,46},{7,49},{12,52},{19,54},{25,50}})
poly(1,'s',{{3,47},{8,52},{15,56},{23,56},{31,53},{31,58},{22,59},{14,57},{8,53}})
-- The rear loop is a complete broad oval; the front tube occludes its bottom half.
poly(2,'m',{{20,49},{24,44},{32,41},{42,40},{55,41},{68,43},{74,46},{77,51},{76,55},{71,58},{62,59},{40,59},{28,57},{22,54}})
poly(2,'s',{{67,44},{73,47},{75,51},{74,54},{70,57},{63,59},{70,59},{76,56},{78,51},{75,47}})
poly(2,'d',{{33,47},{39,44},{49,44},{60,47},{65,50},{63,53},{55,55},{39,54},{31,51}})
poly(2,'l',{{28,44},{33,42},{40,42},{40,43},{34,43},{31,45}})
-- Front loop: olive dorsal surface, pale ventral plane turning under the coil.
poly(3,'m',{{23,47},{29,46},{34,49},{41,52},{50,53},{59,52},{65,48},{69,44},{74,46},{74,51},{70,56},{63,59},{53,60},{38,60},{29,58},{23,55},{20,51}})
poly(3,'s',{{21,50},{25,53},{31,55},{40,57},{53,57},{65,54},{70,50},{73,46},{74,50},{71,55},{64,59},{54,60},{38,60},{29,58},{23,55}})
poly(3,'c',{{42,58},{52,57},{60,55},{66,52},{70,48},{73,46},{73,51},{69,56},{63,58},{54,60},{44,60}})
poly(3,'h',{{23,53},{29,56},{37,58},{43,58},{42,60},{35,59},{28,57}})
-- One continuous S-shaped neck tube overlaps the back of the ground loop.
poly(4,'m',{{54,15},{61,16},{63,22},{58,26},{55,29},{56,32},{61,36},{68,40},{71,44},{70,49},{66,54},{59,56},{53,54},{59,50},{61,46},{59,43},{54,40},{49,37},{45,32},{44,27},{46,22},{49,18}})
poly(4,'d',{{52,21},{57,19},{61,20},{59,24},{54,28},{51,30},{52,33},{57,37},{63,42},{65,47},{63,51},{58,54},{54,54},{59,49},{60,46},{57,42},{51,39},{47,35},{45,30},{46,26}})
-- Pale belly lies on the inner, front-facing curve and widens into the front loop.
poly(4,'c',{{58,24},{61,23},{58,27},{56,30},{58,33},{62,36},{67,39},{70,43},{70,48},{66,53},{61,55},{58,54},{63,50},{65,46},{64,43},{60,39},{56,35},{53,32},{53,28}})
poly(4,'h',{{55,27},{58,25},{56,28},{55,31},{57,34},{61,38},{64,42},{65,46},{63,50},{61,51},{63,46},{62,43},{59,40},{54,35},{52,32},{52,29}})
poly(4,'l',{{47,23},{49,20},{52,18},{53,19},{50,22},{49,24}})
-- Broad triangular viper head (no cobra hood); short crown accent.
poly(5,'m',{{51,16},{55,12},{61,10},{67,11},{72,14},{76,17},{80,19},{81,22},{78,25},{72,26},{65,24},{61,21},{56,22},{53,20}})
poly(5,'s',{{58,21},{62,20},{66,22},{72,23},{78,22},{80,21},{79,24},{74,26},{69,25},{64,23}})
poly(5,'l',{{57,13},{61,11},{66,12},{69,14},{66,14},{63,13},{60,13}})
poly(5,'c',{{74,23},{78,22},{80,22},{78,24},{74,25},{71,24}})
poly(6,'h',{{65,24},{70,25},{76,25},{78,24},{78,26},{74,27},{69,26}})
poly(6,'c',{{70,25},{75,25},{77,25},{76,26},{72,26}})
poly(7,'d',{{71,18},{73,18},{75,20},{73,21},{70,20}})
px(7,'e',72,19);px(7,'o',73,19);px(7,'o',78,20)

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
    local factor=math.max(0,math.min(1,(54-y)/18))
    local shift=math.floor(ps[1]*factor+.5); local lift=math.floor(ps[2]*factor+.5)
    local sx,sy=x-shift,y+lift
    
    if sx>=0 and sx<W and sy>=0 and sy<H then
     local p=original:getPixel(sx,sy); 
     im:drawPixel(x,y,p)
    end
   end end
   -- Lower jaw turns from its cheek hinge; the neck and upper skull stay connected.
   if i==6 and ps[3]>0 then
    im:clear()
    local shift=ps[1];local lift=ps[2]
    for x=62,72 do local depth=math.floor(ps[3]*(x-62)/10+.5)
     for y=29,29+depth do im:drawPixel(x+shift,y-lift,P.o) end
     im:drawPixel(x+shift,30+depth-lift,P.h)
     if x>=65 and x<=71 then im:drawPixel(x+shift,30+depth-lift,P.c) end
    end
    im:drawPixel(68+shift,30-lift,P.c)
    im:drawPixel(70+shift,30-lift,P.c)
   end
   s:newCel(s.layers[i],f,im,Point(0,0))
  end
  s.frames[f].duration=weights[f]/fps;flats[f]=flat(s,f)
  flats[f]:saveAs(dir..(name=='base' and 'giant-viper-base' or name..'_'..f)..'.png')
  flats[f]:saveAs(runtime..(name=='base' and 'base' or name..'_'..f)..'.png')
 end
 local tag=s:newTag(1,#weights);tag.name=name=='idle' and 'rest' or name;s:saveAs(dir..'giant-viper-'..name..'.aseprite')
 if name=='base' then baseFlat=flats[1];preview(baseFlat,dir..'giant-viper-base-8x.png',8)
 else
  local timing=io.open(dir..name..'-timing.json','w');timing:write('{"fps":'..fps..',"weights":['..table.concat(weights,',')..']'..(name=='attack' and ',"impact_frame":2' or '')..'}\n');timing:close()
  local sheet=Image(W*#weights,H,ColorMode.RGB);sheet:clear(Color{r=53,g=56,b=62,a=255})
  local gif=Sprite(W,H,ColorMode.RGB)
  for f,im in ipairs(flats) do sheet:drawImage(im,Point((f-1)*W,0));if f>1 then gif:newEmptyFrame() end;local bg=Image(W,H,ColorMode.RGB);bg:clear(Color{r=53,g=56,b=62,a=255});bg:drawImage(im);gif:newCel(gif.layers[1],f,bg,Point(0,0));gif.frames[f].duration=weights[f]/fps end
  if name=='attack' then gif.frames[#weights].duration=.8 end
  app.sprite=gif;app.command.SpriteSize{width=W*4,height=H*4,method='nearest'};gif:saveAs(dir..name..'-preview.gif');preview(sheet,dir..name..'-frames-4x.png',4)
 end
 local reopened=app.open(dir..'giant-viper-'..name..'.aseprite');assert(#reopened.layers==#names and #reopened.frames==#weights)
 for f,im in ipairs(flats) do local check=flat(reopened,f)
  for y=0,H-1 do for x=0,W-1 do local p=im:getPixel(x,y);assert(check:getPixel(x,y)==p,'Master mismatch');local a=app.pixelColor.rgbaA(p);assert(a==0 or a==255,'Partial alpha');if name=='attack' and f==#weights or name=='idle' and f==1 then assert(p==baseFlat:getPixel(x,y),'Recovery/base mismatch') end end end
 end
 print('Verified '..name..': every saved master frame matches PNG; alpha binary; recovery exact')
end
saveClip('base',{1},8,{{0,0,0}})
saveClip('idle',{5,3,2,3,5},8,{{0,0,0},{0,1,0},{0,1,0},{0,1,0},{0,0,0}})
saveClip('attack',{.8,1,.8,1,1.2,1},10,{{-1,0,0},{-3,0,4},{8,0,2},{5,0,3},{1,0,1},{0,0,0}})
local board=Image(430,70,ColorMode.RGB);board:clear(Color{r=53,g=56,b=62,a=255})
local refs={{'assets/sprites/enemies/rat_v1/idle_1.png',0,20},{'design/goblin-base/goblin-base.png',48,4},{'design/wolf-base/wolf-base.png',108,10},{'design/viper-base/viper-base.png',188,18},{'design/giant-viper-base/giant-viper-base.png',256,2}}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
local review=Image(W*2,H,ColorMode.RGB);review:clear(Color{r=53,g=56,b=62,a=255})
review:drawImage(Image{fromFile=dir..'before-depth-review/giant-viper-base.png'},Point(0,0));review:drawImage(baseFlat,Point(W,0));preview(review,dir..'neck-depth-before-after-6x.png',6)
local silhouette=Image(baseFlat);for it in silhouette:pixels() do if app.pixelColor.rgbaA(it())>0 then it(rgba(219,219,203,255)) end end;preview(silhouette,dir..'silhouette-8x.png',8)
