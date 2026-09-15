-- Adult male construction revision. Authored native polygons, no scaling of v1.
-- Rebuild overwrites v2 outputs only. Preserve manual changes before rebuilding.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/human-base-study'
local W,H=64,80
local pc=app.pixelColor
local colors={m='d5a064',s='a16c4b',h='efd29a',d='664b38',o='302d29',c='7e6449',k='514535'}
local P={}; local palette=Palette(8)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,k in ipairs({'m','s','h','d','o','c','k'}) do
 local hex=colors[k]
 local r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
 P[k]=pc.rgba(r,g,b,255); palette:setColor(i,Color{r=r,g=g,b=b,a=255})
end
local names={'01 Far leg','02 Far arm and hand','03 Near leg','04 Torso and pelvis',
 '05 Head and neck','06 Shorts - removable','07 Near arm and hand','08 Face','09 Equipment - empty'}
local ims={}; for i=1,9 do ims[i]=Image(W,H,ColorMode.RGB) end
local function inside(x,y,pts)
 local result=false
 for i,a in ipairs(pts) do
  local b=pts[i%#pts+1]
  if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then result=not result end
 end
 return result
end
local function poly(layer,k,pts,clip)
 local im=ims[layer]
 for y=0,H-1 do for x=0,W-1 do
  if inside(x+.5,y+.5,pts) and (not clip or pc.rgbaA(im:getPixel(x,y))>0) then im:drawPixel(x,y,P[k]) end
 end end
end
local function line(layer,k,y,x1,x2)
 for x=x1,x2 do if pc.rgbaA(ims[layer]:getPixel(x,y))>0 then ims[layer]:drawPixel(x,y,P[k]) end end
end
-- Hip, knee and ankle chains are independently drawn at adult proportions.
poly(1,'s',{{32,39},{39,41},{40,47},{43,55},{43,61},{42,69},{44,71},{49,73},{49,75},{38,75},{37,72},{38,62},{36,56},{33,51},{30,45}})
poly(1,'d',{{31,42},{34,44},{36,51},{39,55},{40,60},{39,69},{40,73},{38,75},{36,70},{37,61},{34,55},{31,48}},true)
line(1,'o',74,38,48)
poly(2,'s',{{37,22},{42,24},{44,30},{44,35},{48,40},{50,43},{50,47},{47,49},{44,47},{44,43},{41,40},{39,36},{38,30}})
poly(2,'d',{{39,25},{40,31},{41,36},{44,40},{46,44},{46,47},{49,48},{47,50},{43,48},{43,43},{39,39},{37,32}},true)
line(2,'o',46,47,47)
poly(3,'m',{{24,39},{33,41},{33,47},{30,53},{27,58},{28,63},{27,70},{29,72},{34,73},{34,75},{22,75},{21,72},{23,67},{22,60},{22,56},{24,50},{23,45}})
poly(3,'s',{{30,42},{33,44},{32,49},{29,55},{25,58},{26,61},{26,66},{25,71},{28,74},{22,74},{23,70},{24,64},{23,59},{24,55},{27,50}},true)
poly(3,'d',{{31,42},{33,43},{33,48},{30,52},{29,49}},true)
line(3,'h',72,22,24); line(3,'d',74,22,33)
-- Trapezius and broad ribcage taper through the waist into a distinct pelvis.
poly(4,'m',{{29,18},{35,18},{37,21},{41,23},{42,27},{40,33},{37,38},{38,43},{37,47},{33,49},{28,48},{23,46},{23,42},{25,38},{23,33},{21,28},{22,24},{26,21}})
poly(4,'s',{{22,25},{26,26},{27,30},{28,34},{28,37},{27,41},{28,45},{30,48},{24,48},{23,43},{25,38},{23,32}},true)
poly(4,'s',{{39,25},{42,26},{40,33},{37,38},{38,42},{35,42},{35,37},{37,33}},true)
poly(4,'d',{{22,26},{24,27},{25,31},{24,34},{22,31}},true)
-- One short pectoral turn, no abs or texture marks.
poly(4,'s',{{37,27},{40,26},{39,29},{37,30},{34,30},{35,29}},true)
line(4,'h',22,26,28)
-- Short, substantial neck and smaller skull with an angular adult jaw.
poly(5,'m',{{29,15},{35,15},{35,19},{37,22},{32,24},{28,21},{29,18}})
poly(5,'s',{{30,16},{35,16},{35,20},{37,22},{34,23},{30,20}},true)
poly(5,'m',{{31,6},{37,6},{39,8},{39,11},{40,13},{40,14},{39,14},{39,17},{36,19},{32,18},{30,16},{29,13},{29,9}})
poly(5,'s',{{29,10},{32,11},{32,14},{34,16},{39,16},{39,18},{36,19},{32,18},{30,16},{29,13}},true)
poly(5,'d',{{32,17},{36,18},{39,16},{39,18},{36,20},{33,19}},true)
line(5,'h',6,31,34)
-- Straight brow, one eye, a nose plane and a restrained mouth corner.
line(5,'s',11,35,38)
ims[8]:drawPixel(37,11,P.d); ims[8]:drawPixel(38,12,P.o)
ims[8]:drawPixel(38,15,P.d)
ims[8]:drawPixel(30,12,P.d); ims[8]:drawPixel(31,13,P.m)
poly(6,'c',{{24,40},{29,41},{36,40},{38,42},{38,48},{33,49},{31,46},{29,49},{23,48},{23,44}})
poly(6,'k',{{34,41},{38,41},{38,48},{33,49},{31,46},{31,44}},true)
line(6,'k',47,23,27)
-- Full deltoid, upper arm, bent elbow, forearm and a closed relaxed hand.
poly(7,'m',{{22,22},{26,23},{28,26},{27,30},{24,33},{23,37},{24,41},{24,45},{25,47},{24,50},{20,50},{18,48},{18,44},{18,40},{17,36},{18,32},{18,28},{19,24}})
poly(7,'s',{{25,24},{28,26},{27,30},{24,33},{22,36},{22,39},{23,43},{22,46},{23,49},{20,50},{19,47},{20,43},{20,38},{20,35},{22,31},{24,28}},true)
poly(7,'d',{{26,28},{27,29},{25,32},{23,34},{23,32}},true)
line(7,'h',22,22,24); line(7,'h',23,20,21)
line(7,'d',48,23,24); line(7,'o',46,23,23)
local s=Sprite(W,H,ColorMode.RGB); s:setPalette(palette)
for i,name in ipairs(names) do
 local l=i==1 and s.layers[1] or s:newLayer(); l.name=name
 s:newCel(l,1,ims[i],Point(0,0))
end
s.frames[1].duration=.2; s:newTag(1,1).name='base'
s:saveAs(out..'/human-base-v2.aseprite')
local flat=Image(s.spec); flat:drawSprite(s,1); flat:saveAs(out..'/human-base-v2.png')
local function preview(im,path,scale)
 local p=Sprite(im.width,im.height,ColorMode.RGB)
 p:newCel(p.layers[1],1,im,Point(0,0)); app.sprite=p
 app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'}
 p:saveAs(out..'/'..path..'.png'); p:close()
end
preview(flat,'human-base-v2-8x',8)
s.layers[6].isVisible=false
local bare=Image(s.spec); bare:drawSprite(s,1)
s.layers[7].isVisible=false
local support=Image(s.spec); support:drawSprite(s,1)
s.layers[6].isVisible=true; s.layers[7].isVisible=true
local silhouette=Image(flat)
for it in silhouette:pixels() do if pc.rgbaA(it())>0 then it(pc.rgba(219,219,203,255)) end end
local function board(images,name)
 local im=Image(#images*72,88,ColorMode.RGB); im:clear(pc.rgba(53,56,62,255))
 for i,src in ipairs(images) do
  local bottom=0
  for y=0,src.height-1 do for x=0,src.width-1 do
   if pc.rgbaA(src:getPixel(x,y))>0 then bottom=math.max(bottom,y) end
  end end
  im:drawImage(src,Point((i-1)*72+math.floor((72-src.width)/2),79-bottom))
 end
 im:saveAs(out..'/'..name..'-native.png'); preview(im,name..'-5x',5)
end
board({Image{fromFile=out..'/human-base-v1.png'},flat,bare,support,silhouette},'adult-v2-construction')
board({Image{fromFile=root..'/assets/sprites/enemies/rat_v1/idle_1.png'},
 Image{fromFile=root..'/assets/sprites/enemies/goblin_base/base.png'},flat,
 Image{fromFile=root..'/assets/sprites/enemies/kobold_base/base.png'}},'adult-v2-monsters')
local reopened=app.open(out..'/human-base-v2.aseprite')
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
