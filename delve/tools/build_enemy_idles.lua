-- Aseprite batch: preserve approved masters; author layered breathing/blink loops.
local root = app.params.root or 'G:/Godot/Gamestorming/delve'
local rgba = app.pixelColor.rgba
local kinds = {
  {name='goblin', waist=36, eye=rgba(255,205,110,255), lid=rgba(75,89,62,255), weights={4,3,1,3,5}},
  {name='kobold', waist=35, eye=rgba(255,205,110,255), lid=rgba(120,73,52,255), weights={4,3,1,3,4}},
  {name='wolf', waist=35, eye=rgba(243,192,99,255), lid=rgba(66,75,80,255), weights={5,4,1,3,5}},
}
for _,k in ipairs(kinds) do
  local dir=root..'/design/'..k.name..'-base/'
  local source=app.open(dir..k.name..'-base.aseprite')
  local s=Sprite(source.width,source.height,ColorMode.RGB)
  s:setPalette(source.palettes[1])
  local originals={}
  for i,l in ipairs(source.layers) do
    local dst=i==1 and s.layers[1] or s:newLayer(); dst.name=l.name
    local im=Image(source.width,source.height,ColorMode.RGB)
    local cel=l:cel(1)
    if cel then im:drawImage(cel.image,cel.position) end
    originals[i]=im
  end
  local flats={}
  for f,weight in ipairs(k.weights) do
    if f>1 then s:newEmptyFrame() end
    local raised=f>=2 and f<=4
    for i,l in ipairs(s.layers) do
      local im=Image(s.width,s.height,ColorMode.RGB)
      for y=0,s.height-1 do for x=0,s.width-1 do
        -- One extra row through the waist/chest joins a lifted upper body to
        -- stationary legs. Use the same mapping on every layer to keep seams.
        local sy=y
        if raised and y<k.waist then sy=y+1 end
        -- Tail tip follows the breath, with its root and legs kept in place.
        if raised and i==1 and k.name~='goblin' and x<16 then sy=y+1 end
        local p=sy<s.height and originals[i]:getPixel(x,sy) or 0
        if f==3 and p==k.eye then p=k.lid end
        im:drawPixel(x,y,p)
      end end
      s:newCel(l,f,im,Point(0,0))
    end
    s.frames[f].duration=weight/8
    local flat=Image(s.spec); flat:drawSprite(s,f); flats[f]=flat
    flat:saveAs(dir..'idle_'..f..'.png')
  end
  local tag=s:newTag(1,#k.weights); tag.name='rest'
  s:saveAs(dir..k.name..'-idle.aseprite')
  local timing=io.open(dir..'idle-timing.json','w')
  timing:write('{"fps":8,"weights":['..table.concat(k.weights,',')..']}\n'); timing:close()
  local sheet=Sprite(s.width*#k.weights,s.height,ColorMode.RGB)
  local im=Image(sheet.spec); im:clear(Color{r=53,g=56,b=62,a=255})
  for f,flat in ipairs(flats) do im:drawImage(flat,Point((f-1)*s.width,0)) end
  sheet:newCel(sheet.layers[1],1,im,Point(0,0)); app.sprite=sheet
  app.command.SpriteSize{width=sheet.width*4,height=sheet.height*4,method='nearest'}
  sheet:saveAs(dir..'idle-frames-4x.png')
  -- GIF is a review artifact only; runtime uses the transparent PNGs.
  local preview=Sprite(s.width,s.height,ColorMode.RGB)
  for f,flat in ipairs(flats) do
    if f>1 then preview:newEmptyFrame() end
    local bg=Image(preview.spec); bg:clear(Color{r=53,g=56,b=62,a=255}); bg:drawImage(flat)
    preview:newCel(preview.layers[1],f,bg,Point(0,0)); preview.frames[f].duration=k.weights[f]/8
  end
  app.sprite=preview
  app.command.SpriteSize{width=preview.width*4,height=preview.height*4,method='nearest'}
  preview:saveAs(dir..'idle-preview.gif')
  local reopened=app.open(dir..k.name..'-idle.aseprite')
  assert(#reopened.frames==#k.weights and #reopened.layers==#source.layers)
  for f,flat in ipairs(flats) do
    local check=Image(reopened.spec); check:drawSprite(reopened,f)
    for y=0,s.height-1 do for x=0,s.width-1 do
      assert(check:getPixel(x,y)==flat:getPixel(x,y),'Master/export mismatch')
    end end
  end
  print(k.name..': verified layered idle and five PNG frames')
end
