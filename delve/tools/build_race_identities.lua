local out='G:/Godot/Gamestorming/delve/design/race-identities'
local function read(path) local f=assert(io.open(path,'r')); local v=f:read('*a'); f:close(); return json.decode(v) end
local catalog=read(out..'/catalog.json'); local recipes=read(out..'/recipes.json')
-- Materialize decoded arrays before insertion/sorting (Aseprite JSON values
-- expose indexed access but are not ordinary mutable Lua arrays).
local plain={}
for _,r in ipairs(catalog) do
 local row={race=r.race,source=r.source,width=r.width,height=r.height,frames=r.frames,layers={}}
 for _,l in ipairs(r.layers) do
  row.layers[#row.layers+1]={id=l.id,name=l.name,group=l.group,file=l.file,registered=l.registered,issue=l.issue}
 end
 plain[#plain+1]=row
end
catalog=plain
local pc=app.pixelColor
local function rgb(hex) return pc.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255) end
local variants={
 {'Human','human-18','human-gray-beard','Grey hair and beard',{['1d1f27']='41424a',['52444b']='a6aaa7'}},
 {'Human','human-09','human-dark-vest','Dark plum vest',{['68342b']='433645',['45242c']='302634',['271418']='211d26',['976444']='75616e'}},
 {'Elf','elf-20','elf-violet-hair','Violet loose hair',{['1d1f27']='34283d',['52444b']='785e86'}},
 {'Elf','elf-11','elf-linen-wrap','Sleeveless linen tunic',{['3a5575']='b7ac91',['30334e']='777565',['1c131e']='3e3c39'}},
 {'Dwarf','dwarf-23','dwarf-gray-short','Squared grey beard and hair',{['86483d']='a6aaa7',['45242c']='51515a'}},
 {'Dwarf','dwarf-31','dwarf-gray-long','Long grey beard and hair',{['86483d']='c6c6b7',['45242c']='686878'}},
 {'Dwarf','dwarf-10','dwarf-elder-coat','Ash-purple coat',{['3a5575']='797086',['30334e']='514a60',['1c131e']='302936'}},
}
local byRace={}; local byId={}
for _,race in ipairs(catalog) do
 byRace[race.race]=race
 for i,l in ipairs(race.layers) do l.order=i; byId[l.id]=l end
end
for _,v in ipairs(variants) do
 local base=assert(byId[v[2]]); local original=Image{fromFile=out..'/'..base.file}; local im=Image(original)
 local map={}; for from,to in pairs(v[5]) do map[rgb(from)]=rgb(to) end
 for it in im:pixels() do if map[it()] then it(map[it()]) end end
 for y=0,95 do for x=0,127 do assert(pc.rgbaA(im:getPixel(x,y))==pc.rgbaA(original:getPixel(x,y))) end end
 local file='layers/'..v[3]..'.png'; im:saveAs(out..'/'..file)
 local l={id=v[3],name=v[4],group=base.group,file=file,registered=true,issue='',order=base.order+.1,sourceLayer=base.id,palette=v[5]}
 table.insert(byRace[v[1]].layers,l); byId[l.id]=l
end
-- Approved weapon additions belong in the editable character masters as well
-- as the browser. Keep them hidden until selected by a recipe.
local weaponManifest=io.open(out..'/weapons/manifest.json','r')
if weaponManifest then
 local weapons=json.decode(weaponManifest:read('*a'));weaponManifest:close()
 for _,w in ipairs(weapons)do
  local item={id=w.id,name=w.name,group=w.group,file=w.file,registered=true,issue='',order=w.order,master=w.master,frame=w.frame,sourceLayer=w.sourceLayer,grip={w.grip[1],w.grip[2]}}
  assert(byRace[w.race] and not byId[w.id],'Duplicate or invalid weapon registration')
  table.insert(byRace[w.race].layers,item);byId[w.id]=item
 end
end
local offhandFile=io.open(out..'/weapons/offhand.json','r')
if offhandFile then
 local items=json.decode(offhandFile:read('*a'));offhandFile:close()
 for _,w in ipairs(items)do
  local item={id=w.id,name=w.name,group=w.group,file=w.file,registered=true,issue='',order=w.order,master=w.master,frame=w.frame,sourceLayer=w.sourceLayer}
  if w.grip then item.grip={w.grip[1],w.grip[2]}end
  assert(not byId[w.id]);table.insert(byRace[w.race].layers,item);byId[w.id]=item
 end
end
for _,race in ipairs(catalog) do table.sort(race.layers,function(a,b)return a.order<b.order end) end
local f=assert(io.open(out..'/wardrobe.json','w')); f:write(json.encode(catalog)); f:close()
local renders={}; local nativeRenders={}
for _,recipe in ipairs(recipes) do
 local race=assert(byRace[recipe.race]); local selected={}
 for _,id in ipairs(recipe.layers) do selected[id]=true end
 for _,id in ipairs(recipe.gear) do selected[id]=true end
 local hasOffhand=false
 for id in pairs(selected)do if byId[id].group=='Offhand Weapons'then hasOffhand=true end end
 if hasOffhand then selected['elf-04']=nil;selected['elf-offhand-body']=true;selected['elf-offhand-fingers']=true end
 for id in pairs(selected) do assert(byId[id] and byId[id].registered,'Unregistered layer '..id) end
 local s=Sprite(128,96,ColorMode.RGB); local first=true
 for _,item in ipairs(race.layers) do if item.registered then
  local l=first and s.layers[1] or s:newLayer(); first=false
  l.name=item.id..' | '..item.group..' | '..item.name
  s:newCel(l,1,Image{fromFile=out..'/'..item.file},Point(0,0)); l.isVisible=selected[item.id] or false
 end end
 s:newTag(1,1).name='appearance-study'; s:saveAs(out..'/masters/'..recipe.id..'.aseprite')
 local im=Image(s.spec); im:drawSprite(s,1); im:saveAs(out..'/previews/'..recipe.id..'.png')
 local reopened=app.open(out..'/masters/'..recipe.id..'.aseprite')
 local check=Image(reopened.spec); check:drawSprite(reopened,1)
 for y=0,95 do for x=0,127 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch '..recipe.id) end end
 renders[#renders+1]=im
 -- Wardrobe-only render is useful for judging identity without weapons.
 for _,l in ipairs(s.layers) do
  for _,id in ipairs(recipe.gear) do if l.name:sub(1,#id+3)==id..' | ' then l.isVisible=false end end
  if hasOffhand then
   if l.name:find('elf%-offhand%-body |')or l.name:find('elf%-offhand%-fingers |')then l.isVisible=false end
   if l.name:sub(1,9)=='elf-04 | 'then l.isVisible=true end
  end
 end
 local wardrobe=Image(s.spec); wardrobe:drawSprite(s,1); wardrobe:saveAs(out..'/previews/'..recipe.id..'-wardrobe.png')
 nativeRenders[#nativeRenders+1]=wardrobe
 reopened:close(); s:close()
end
local function board(images,name)
 local cols=6; local rows=math.ceil(#images/cols)
 local im=Image(cols*112,rows*100,ColorMode.RGB); im:clear(pc.rgba(53,56,62,255))
 for i,img in ipairs(images) do im:drawImage(img,Point(((i-1)%cols)*112-8,math.floor((i-1)/cols)*100)) end
 im:saveAs(out..'/'..name..'-native.png')
 local s=Sprite(im.width,im.height,ColorMode.RGB); s:newCel(s.layers[1],1,im,Point(0,0)); app.sprite=s
 app.command.SpriteSize{width=im.width*4,height=im.height*4,method='nearest'}
 s:saveAs(out..'/'..name..'-4x.png'); s:close()
end
board(renders,'identity-lineup'); board(nativeRenders,'wardrobe-lineup')
print('PASS: '..#recipes..' layered identity masters reopen to their PNGs. Seven palette variants preserve alpha. Sources unchanged.')
