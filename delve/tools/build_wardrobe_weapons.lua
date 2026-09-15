-- Native weapon additions. Source-compatible palette and pose registrations.
-- Writes new weapon assets/manifest only; originals and identity choices stay intact.
local out='G:/Godot/Gamestorming/delve/design/race-identities'
local pc=app.pixelColor
local races={{name='Human',body='human-03',x=47,y=49},{name='Elf',body='elf-04',x=48,y=47},{name='Dwarf',body='dwarf-04',x=47,y=56},{name='Orc',body='orc-04',x=49,y=46}}
local specs={{id='rapier',name='Rapier'},{id='shortsword',name='Shortsword'},{id='dagger',name='Dagger'},{id='scimitar',name='Scimitar'},{id='mace',name='Flanged mace'},{id='battleaxe',name='Battleaxe'},{id='warhammer',name='Warhammer'},{id='staff',name='Iron-shod staff'}}
local shapes=dofile('G:/Godot/Gamestorming/delve/tools/wardrobe_weapon_shapes.lua')
local function make(spec,race)return shapes(out,spec,race)end
local manifest={};local isolated={};local held={}
for _,spec in ipairs(specs)do
 local s=Sprite(128,96,ColorMode.RGB)
 local layerNames={'01 Handle and bindings','02 Head and silhouette','03 Edges and fittings','04 Source fingers - per race'}
 local ls={}
 for i,name in ipairs(layerNames)do ls[i]=i==1 and s.layers[1]or s:newLayer();ls[i].name=name end
 for frame,race in ipairs(races)do
  if frame>1 then s:newEmptyFrame()end
  local ims=make(spec,race)
  for i,im in ipairs(ims)do s:newCel(ls[i],frame,im,Point(0,0))end
  s:newTag(frame,frame).name=string.lower(race.name)
  local composed=Image(s.spec);composed:drawSprite(s,frame)
  local id=string.lower(race.name)..'-weapon-'..spec.id
  local file='weapons/'..id..'.png';composed:saveAs(out..'/'..file)
  local pure=Image(128,96,ColorMode.RGB);for i=1,3 do pure:drawImage(ims[i],Point(0,0))end
  pure:saveAs(out..'/weapons/'..id..'-isolated.png')
  manifest[#manifest+1]={id=id,name=spec.name..' (new)',group='Weapons',file=file,registered=true,issue='',race=race.name,order=200+#manifest,sourceLayer='Authored weapon; '..race.body..' fingers',grip={race.x,race.y},master='weapons/'..spec.id..'.aseprite',frame=frame}
  if frame==1 then isolated[#isolated+1]=pure end
  local body=Image{fromFile=out..'/previews/'..({Human='player',Elf='elara',Dwarf='tharr',Orc='arkus'})[race.name]..'-wardrobe.png'}
  body:drawImage(composed,Point(0,0));body:saveAs(out..'/weapons/'..id..'-equipped.png');held[#held+1]=body
 end
 s:saveAs(out..'/weapons/'..spec.id..'.aseprite')
 local reopened=app.open(out..'/weapons/'..spec.id..'.aseprite')
 assert(#reopened.frames==4 and #reopened.layers==4)
 for frame,race in ipairs(races)do
  local check=Image(reopened.spec);check:drawSprite(reopened,frame)
  local png=Image{fromFile=out..'/weapons/'..string.lower(race.name)..'-weapon-'..spec.id..'.png'}
  for y=0,95 do for x=0,127 do
   assert(check:getPixel(x,y)==png:getPixel(x,y),'Reopen mismatch')
   local a=pc.rgbaA(check:getPixel(x,y));assert(a==0 or a==255,'Partial alpha')
  end end
 end
 reopened:close();s:close()
end
local f=assert(io.open(out..'/weapons/manifest.json','w'));f:write(json.encode(manifest));f:close()
local function board(images,name,cols)
 local rows=math.ceil(#images/cols);local im=Image(cols*128,rows*96,ColorMode.RGB);im:clear(pc.rgba(53,56,62,255))
 for i,img in ipairs(images)do im:drawImage(img,Point(((i-1)%cols)*128,math.floor((i-1)/cols)*96))end
 im:saveAs(out..'/weapons/'..name..'-native.png')
 local s=Sprite(im.width,im.height,ColorMode.RGB);s:newCel(s.layers[1],1,im,Point(0,0));app.sprite=s
 app.command.SpriteSize{width=im.width*4,height=im.height*4,method='nearest'}
 s:saveAs(out..'/weapons/'..name..'-4x.png');s:close()
end
board(isolated,'weapon-lineup',4);board(held,'race-grip-review',4)
-- Compact, identical-scale comparisons: source controls above the additions.
local function compact(images,name)
 local im=Image(416,math.ceil(#images/4)*40,ColorMode.RGB);im:clear(pc.rgba(53,56,62,255))
 for i,img in ipairs(images)do
  local crop=Image(104,40,ColorMode.RGB);crop:drawImage(img,Point(0,-34))
  im:drawImage(crop,Point(((i-1)%4)*104,math.floor((i-1)/4)*40))
 end
 local s=Sprite(im.width,im.height,ColorMode.RGB);s:newCel(s.layers[1],1,im,Point(0,0));app.sprite=s
 app.command.SpriteSize{width=im.width*4,height=im.height*4,method='nearest'}
 s:saveAs(out..'/weapons/'..name..'-4x.png');s:close()
end
local refs={}
for _,id in ipairs({'human-33','human-30','human-31','human-29'})do refs[#refs+1]=Image{fromFile=out..'/layers/'..id..'.png'}end
for _,im in ipairs(isolated)do refs[#refs+1]=im end
compact(refs,'source-style-comparison')
local comparison={}
for row=0,1 do
 for i=1,4 do comparison[#comparison+1]=Image{fromFile=out..'/weapons/before-refinement/human-weapon-'..specs[row*4+i].id..'-isolated.png'}end
 for i=1,4 do comparison[#comparison+1]=isolated[row*4+i]end
end
compact(comparison,'before-after')
print('PASS: eight weapon masters, four race frames each, 32 registered exports; binary alpha and reopened pixels match.')
