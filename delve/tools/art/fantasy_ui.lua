-- Run with Aseprite --batch --script-param out=<assets/ui> --script tools/art/fantasy_ui.lua
-- Authoring and PNG export both happen in Aseprite. Keep the .aseprite sources for manual edits.
local out = app.params.out
assert(out and #out > 0, 'Pass --script-param out=<assets/ui>')
local function color(hex)
  return app.pixelColor.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255)
end
local sprite, ink
local function begin(w,h)
  sprite=Sprite(w,h,ColorMode.RGB)
  sprite.layers[1].name='Leather and patina'
  ink=sprite.cels[1].image
end
local function dot(x,y,c)
  if x>=0 and y>=0 and x<ink.width and y<ink.height then ink:drawPixel(x,y,color(c)) end
end
local function line(x,y,x2,y2,c)
  local dx,dy=math.abs(x2-x),-math.abs(y2-y)
  local sx,sy=x<x2 and 1 or -1,y<y2 and 1 or -1
  local err=dx+dy
  while true do
    dot(x,y,c)
    if x==x2 and y==y2 then break end
    local e=err*2
    if e>=dy then err=err+dy;x=x+sx end
    if e<=dx then err=err+dx;y=y+sy end
  end
end
local function polygon(points,fill,edge)
  if fill then
    for y=0,ink.height-1 do
      for x=0,ink.width-1 do
        local inside=false
        local j=#points
        for i=1,#points do
          local a,b=points[i],points[j]
          if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
          j=i
        end
        if inside then dot(x,y,fill) end
      end
    end
  end
  if edge then for i=1,#points do local a,b=points[i],points[i%#points+1];line(a[1],a[2],b[1],b[2],edge) end end
end
local function layer(name)
  local l=sprite:newLayer();l.name=name
  ink=Image(sprite.width,sprite.height,ColorMode.RGB)
  sprite:newCel(l,1,ink)
  ink=sprite.cels[#sprite.cels].image
end
local function save(name)
  sprite:saveAs(out..'/'..name..'.aseprite')
  sprite:saveCopyAs(out..'/'..name..'.png')
  sprite:close()
end
local states={normal={'25251e','141712','766443','46402d'},hover={'3b3829','23251a','b6a06a','746140'},pressed={'171b16','11140f','ab8954','54432a'},disabled={'1d211b','171b16','414638','30372c'},accent={'3c3020','211e15','b89b5d','756040'}}
for name,c in pairs(states) do
  begin(96,40)
  polygon({{9,3},{85,2},{93,10},{94,30},{86,38},{10,38},{2,30},{2,11}},'080c09')
  polygon({{10,2},{85,2},{92,9},{92,29},{85,36},{10,36},{3,29},{3,10}},c[1],c[3])
  -- Deterministic scattered grain, restrained enough to leave small labels legible.
  for y=8,30 do for x=12,83 do if (x*17+y*31)%43==0 then dot(x,y,c[2]) end end end
  layer('Brass edging and worn highlights')
  polygon({{12,6},{83,6},{88,11},{88,27},{83,32},{12,32},{7,27},{7,12}},nil,c[4])
  line(13,34,82,34,c[2]);line(16,3,28,3,c[3]);line(69,3,79,3,c[3])
  polygon({{4,19},{7,16},{10,19},{7,22}},c[3]);polygon({{86,19},{89,16},{92,19},{89,22}},c[3])
  save('button_'..name)
end
begin(96,40)
sprite.layers[1].name='Keyboard focus corner marks'
for _,p in ipairs({{2,14,2,9},{2,9,10,1},{10,1,22,1},{74,1,86,1},{86,1,94,9},{94,9,94,14},{2,26,2,31},{2,31,10,39},{10,39,22,39},{74,39,86,39},{86,39,94,31},{94,31,94,26}}) do line(p[1],p[2],p[3],p[4],'ead49b') end
save('button_focus')
begin(128,128)
polygon({{15,3},{112,3},{125,16},{125,111},{112,125},{15,125},{3,111},{3,16}},'090e0b')
polygon({{16,6},{110,6},{122,18},{122,109},{110,121},{17,121},{6,109},{6,18}},'1b211b','817047')
polygon({{20,12},{105,12},{116,22},{116,104},{105,115},{22,115},{12,104},{12,23}},'121a16','3f4936')
layer('Stitches and brass corner ornaments')
-- Ornament stays inside each fixed nine-patch corner; the middle is unpatterned leather.
for _,mirror in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
  local function point(x,y) return mirror[1] and 127-x or x, mirror[2] and 127-y or y end
  local function stroke(x,y,x2,y2,c)
    local a,b=point(x,y);local d,e=point(x2,y2);line(a,b,d,e,c)
  end
  stroke(10,30,30,10,'a48b55');stroke(15,10,15,25,'756440');stroke(15,25,29,25,'756440')
  local points={}
  for _,v in ipairs({{18,14},{22,18},{18,22},{14,18}}) do local x,y=point(v[1],v[2]);table.insert(points,{x,y}) end
  polygon(points,'c1a265')
end
save('result_frame')
begin(400,20)
sprite.layers[1].name='Etched divider'
line(0,10,172,10,'756440');line(228,10,399,10,'756440')
line(0,11,172,11,'756440');line(228,11,399,11,'756440')
polygon({{181,10},{188,6},{195,10},{188,14}},nil,'756440');polygon({{205,10},{212,6},{219,10},{212,14}},nil,'756440')
polygon({{200,2},{206,10},{200,18},{194,10}},'b19861')
save('result_rule')
print('Exported fantasy UI Aseprite sources and PNGs')
