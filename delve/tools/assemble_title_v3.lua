local P=dofile('tools/title_pixels.lua')
local masks=dofile('tools/title_v3_masks.lua')
local dir='design/title-study/v3/'
app.fs.makeAllDirectories(dir..'layers')
local pc=app.pixelColor
local env=P.load(dir..'parts/environment.png')
local valley=P.load(dir..'parts/valley.png')
local outpostMask=P.mask(masks.outpost)
local approachMask=P.mask(masks.approach)
local leftMask=P.mask(masks.leftTree)
local rightMask=P.mask(masks.rightTree)
local skyColors={}
for _,h in ipairs({'486983','5c7e96','7895a8','536996','687dac','827da3','a88cab','c998aa','dba09f','e8b096'}) do skyColors[P.rgba(h)]=true end
local planes={sky=P.image(),forest=P.image(),outpost=P.image(),approach=P.image(),trees=P.image()}
local coverage={sky=0,forest=0,outpost=0,approach=0,trees=0}
for y=0,359 do for x=0,639 do
  local c=env:getPixel(x,y)
  local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
  local treeColor=r+g+b<130 or (b<r*1.15 and math.max(r,g,b)<105) or (g>b+12 and r>g*0.85)
  local key
  if (P.contains(leftMask,x,y) or P.contains(rightMask,x,y)) and treeColor then key='trees'
  elseif P.contains(approachMask,x,y) then key='approach'
  elseif P.contains(outpostMask,x,y) then
    local opening=(x>=278 and x<=311 and y>=113 and y<=140)
      or (x>=431 and x<=460 and y>=115 and y<=137)
      or (x>=307 and x<=412 and y<106)
    key=opening and skyColors[c] and (y<96 and 'sky' or 'forest') or 'outpost'
  elseif y<83+math.floor(23*math.sin(x/640*math.pi)) then key='sky'
  else key='forest' end
  planes[key]:drawPixel(x,y,c); coverage[key]=coverage[key]+1
end end
local total=0; for _,n in pairs(coverage) do total=total+n end
assert(total==640*360,'Incomplete environment coverage')
local s=Sprite(640,360,ColorMode.RGB)
local blank=s.layers[1]
local manifest={}
local function group(name)
  local g=s:newGroup(); g.name=name; return g
end
local function add(g,name,im,x,y)
  local l=P.layer(s,name,im,x,y); l.parent=g
  local path=name:lower():gsub('[^a-z0-9]+','-')..'.png'
  local full=P.image(); full:drawImage(im,Point(x or 0,y or 0))
  full:saveAs(dir..'layers/'..path)
  manifest[#manifest+1]={name=name,file=path,x=x or 0,y=y or 0,w=im.width,h=im.height}
  return l
end
local backdrop=group('01 BACKDROP - complete valley behind cutouts')
add(backdrop,'Valley clean plate - full coverage',valley)
add(backdrop,'Sky and dusk clouds',planes.sky)
add(backdrop,'Distant forest and ruins',planes.forest)
local function mist(x,y,w,c)
  local im=P.image()
  P.poly(im,{{x,y+5},{x+w//6,y+2},{x+w//3,y+3},{x+w//2,y},{x+3*w//4,y+2},{x+w,y+6},{x+w-8,y+9},{x+w//2,y+8},{x+12,y+10}},c)
  return im
end
local farFog=mist(120,193,102,P.rgba('7895a8',35))
farFog:drawImage(mist(536,218,111,P.rgba('7895a8',28)))
add(backdrop,'Far mist - drift 1 to 3 pixels',farFog)
local architecture=group('02 OUTPOST - rigid scenery and light')
add(architecture,'Chapel tower and bridge',planes.outpost)
local lights=P.image()
-- Small authored hot cores, distinct from the static light on masonry.
for _,v in ipairs({{477,52},{449,158},{472,188},{478,262},{479,267},{427,146},{333,143},{350,136},{390,143}}) do
  P.rect(lights,v[1],v[2],1,2,P.rgba('fff0bf',210))
  P.rect(lights,v[1]-1,v[2]+1,3,2,P.rgba('efc079',62))
end
add(architecture,'Lantern cores - flicker overlay',lights)
local ground=group('03 FOREGROUND - empty path and framing')
add(ground,'Approach paving and banks - no people',planes.approach)
add(ground,'Framing trees and empty banner support',planes.trees)
local banner=P.image()
P.poly(banner,{{91,80},{126,88},{123,115},{125,139},{115,168},{112,177},{108,163},{102,176},{99,158},{91,167},{94,141},{88,114}},P.rgba('502f3b'))
P.poly(banner,{{94,83},{101,85},{98,116},{103,140},{98,159},{95,163},{97,138},{92,112}},P.rgba('79505b'))
P.poly(banner,{{113,87},{123,90},{120,114},{123,137},{115,156},{113,166},{111,143},{115,121}},P.rgba('623c49'))
P.line(banner,92,83,124,90,P.rgba('b29779'))
P.line(banner,92,87,97,139,P.rgba('79505b'))
P.poly(banner,{{108,102},{112,115},{109,127},{105,115}},P.rgba('b29779'))
P.poly(banner,{{108,107},{109,115},{107,120},{107,114}},P.rgba('efd094'))
P.line(banner,99,128,116,132,P.rgba('99907a'))
P.line(banner,107,127,106,143,P.rgba('99907a'))
add(ground,'Banner cloth - hand drawn folds and watchlight',banner)
local party=group('04 PARTY - separate organic silhouettes')
local shadows=P.image()
local cast={
 {name='Aldric',x=139,feet=309},
 {name='Elara',x=177,feet=316},
 {name='Tharr',x=212,feet=321},
 {name='Fenwick',x=253,feet=315}
}
for _,v in ipairs(cast) do
  P.poly(shadows,{{v.x-4,v.feet-1},{v.x+6,v.feet-4},{v.x+23,v.feet-2},{v.x+26,v.feet+1},{v.x+12,v.feet+3},{v.x-3,v.feet+2}},P.rgba('10151f',120))
end
add(party,'Contact shadows',shadows)
for _,v in ipairs(cast) do
  local im=P.load(dir..'parts/'..v.name:lower()..'.png')
  add(party,v.name..' - idle base',im,v.x,v.feet-im.height)
end
local effects=group('05 ATMOSPHERE - independent motion overlays')
local nearFog=mist(492,300,123,P.rgba('7895a8',29))
add(effects,'Near valley mist - drift separately',nearFog)
local title=group('06 TITLE - fixed screen space')
local old=app.open('design/title-study/delve-title-hd2d-v2.aseprite')
local titleParts={}
for i=2,#old.layers do
  local im=Image(960,540,ColorMode.RGB)
  local cel=old.layers[i]:cel(1)
  im:drawImage(cel.image,cel.position)
  im:resize{width=640,height=360,method='nearest-neighbor'}
  titleParts[#titleParts+1]={name=old.layers[i].name,im=im}
end
old:close(); app.sprite=s
for _,v in ipairs(titleParts) do add(title,v.name,v.im) end
s:deleteLayer(blank)
local pal=Palette(#P.environment+#P.people+1)
pal:setColor(0,Color{r=0,g=0,b=0,a=0})
local index=1
for _,ramp in ipairs({P.environment,P.people}) do for _,h in ipairs(ramp) do
  local c=P.rgba(h); pal:setColor(index,Color{r=pc.rgbaR(c),g=pc.rgbaG(c),b=pc.rgbaB(c),a=255}); index=index+1
end end
s:setPalette(pal)
s:saveAs(dir..'delve-title-v3.aseprite')
s:saveCopyAs(dir..'delve-title-v3.png')
-- Exact integer preview; native editable file remains 640x360 and one frame.
app.command.SpriteSize{ui=false,width=1920,height=1080,method='nearest-neighbor'}
s:saveCopyAs(dir..'delve-title-v3-1080p.png')
local f=io.open(dir..'layers/manifest.tsv','w')
f:write('layer\tfile\tx\ty\tcel_width\tcel_height\n')
for _,v in ipairs(manifest) do f:write(v.name,'\t',v.file,'\t',v.x,'\t',v.y,'\t',v.w,'\t',v.h,'\n') end
f:close()
print('TITLE V3 OK: '..#manifest..' paint layers in 6 groups; 640x360 source and 1080p preview')
