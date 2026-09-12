-- Reopen the saved master, inspect its actual hierarchy, and exercise motion layers.
local P=dofile('tools/title_pixels.lua')
local dir='design/title-study/v3/'
local s=app.open(dir..'delve-title-v3.aseprite')
assert(s.width==640 and s.height==360 and #s.frames==1,'Wrong native master')
assert(#s.layers==6,'Missing layer groups')
local paints={}
local byName={}
for _,g in ipairs(s.layers) do
  assert(g.isGroup,'Expected top-level group')
  for _,l in ipairs(g.layers) do
    local cel=l:cel(1)
    assert(cel,'Empty paint layer: '..l.name)
    local item={name=l.name,group=g.name,im=Image(cel.image),pos=cel.position}
    paints[#paints+1]=item; byName[l.name]=item
  end
end
assert(#paints==18,'Unexpected paint-layer count')
local clean=byName['Valley clean plate - full coverage'].im
local opaque=0
for pixel in clean:pixels() do if app.pixelColor.rgbaA(pixel())==255 then opaque=opaque+1 end end
assert(opaque==640*360,'Clean valley has holes')
local names={'Aldric','Elara','Tharr','Fenwick'}
for _,name in ipairs(names) do
  local actor=byName[name..' - idle base']
  assert(actor and actor.im.height<60 and actor.im.width<40,'Invalid character scale')
  local clear,solid=0,0
  for pixel in actor.im:pixels() do
    if app.pixelColor.rgbaA(pixel())==0 then clear=clear+1 else solid=solid+1 end
  end
  assert(clear>0 and solid>100,'Missing character transparency')
end
-- Cutaway verifies a genuinely empty path behind the travelers and banner.
s.layers[4].isVisible=false
s.layers[3].layers[3].isVisible=false
s:saveCopyAs(dir..'clean-path-check.png')
s.layers[4].isVisible=true
s.layers[3].layers[3].isVisible=true
s:close()
local animation=Sprite(640,360,ColorMode.RGB)
local blank=animation.layers[1]
local layers={}
for _,item in ipairs(paints) do
  local l=animation:newLayer(); l.name=item.name
  layers[#layers+1]=l
end
animation:deleteLayer(blank)
local frameCount=16
for frame=1,frameCount do
  if frame>1 then animation:newEmptyFrame() end
  animation.frames[frame].duration=0.16
  local phase=(frame-1)/frameCount*2*math.pi
  for i,item in ipairs(paints) do
    local im=Image(item.im)
    local pos=Point(item.pos.x,item.pos.y)
    local opacity=255
    if item.name:find('mist') then
      local sign=item.name:find('Near') and -1 or 1
      pos.x=pos.x+math.floor(sign*3*math.sin(phase)+0.5)
    elseif item.name:find('Lantern cores') then
      opacity=({200,230,255,225,180,230,245,210})[(frame-1)%8+1]
    elseif item.name:find('Banner cloth') then
      local bent=P.image(im.width,im.height)
      for y=0,im.height-1 do
        local worldY=y+pos.y
        local weight=math.max(0,math.min(1,(worldY-85)/85))
        local dx=math.floor(1.8*weight*math.sin(phase-worldY/34)+0.5)
        for x=0,im.width-1 do
          if x+dx>=0 and x+dx<im.width then bent:drawPixel(x+dx,y,im:getPixel(x,y)) end
        end
      end
      im=bent
    elseif item.name:find('idle base') then
      -- A one-pixel torso compression only; feet and contact shadows stay planted.
      local bob=(math.sin(phase+i*0.7)>0.5) and 1 or 0
      if bob==1 then
        local breathed=P.image(im.width,im.height)
        for y=0,im.height-1 do for x=0,im.width-1 do
          local target=y<im.height-8 and math.max(0,y-1) or y
          breathed:drawPixel(x,target,im:getPixel(x,y))
        end end
        im=breathed
      end
    end
    local cel=animation:newCel(layers[i],frame,im,pos); cel.opacity=opacity
  end
end
animation:saveAs(dir..'delve-title-v3-motion-study.aseprite')
animation:saveCopyAs(dir..'delve-title-v3-motion-study.gif')
local im=P.image(); im:drawSprite(animation,5)
im:saveAs(dir..'motion-frame-check.png')
print('TITLE V3 CHECK PASS: 6 groups, 18 nonempty layers, opaque clean plate, 4 transparent sprites')
print('MOTION STUDY: 16 frames, 2.56-second loop; mist, banner, light and idle torso only')
