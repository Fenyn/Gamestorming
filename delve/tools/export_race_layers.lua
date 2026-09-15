-- Read-only inspection/export of the supplied four-race design masters.
local root='F:/UnityNVME/Art/_P2eGame/Sprites'
local out='G:/Godot/Gamestorming/delve/design/race-identities'
local allowed={Body=true,Clothes=true,Hairs=true,Helmets=true,Weapons=true,Shields=true,Shields_Upper_Layer=true}
local entries={}
local unsupported={
 Human={[32]='Loose sword study, not registered to the main pose'},
 Elf={[27]='Human-position helmet', [28]='Human-position helmet',[29]='Human-position helmet',[30]='Human-position helmet',[31]='Helmet overlaps behind the head; needs fitting',[32]='Human-position face piece',[33]='Human-position helmet',[34]='Human-position spear',[35]='Human-position cudgel',[36]='Unregistered cudgel',[37]='Loose sword study'},
 Dwarf={[5]='Clothes on side reference',[6]='Clothes on side reference',[15]='Bracers on side reference',[17]='Clothes on side reference',[35]='Human-position helmet',[37]='Human-position helmet',[38]='Human-position helmet',[39]='Floating helmet study',[40]='Human-position face piece',[41]='Human-position helmet',[42]='Human-position spear',[43]='Human-position cudgel',[45]='Loose sword study',[46]='Human-position sword'},
 Orc={[5]='Human-position pants',[6]='Human-position pants',[9]='Bracers on side reference',[23]='Human-position helmet',[24]='Human-position helmet',[25]='Human-position helmet',[26]='Human-position helmet',[27]='Helmet overlaps behind the head; needs fitting',[28]='Human-position face piece',[29]='Human-position helmet'},
}
for _,race in ipairs({'Human','Elf','Dwarf','Orc'}) do
 local source=root..'/'..race..'/'..race..'_Design.aseprite'
 local s=app.open(source)
 local leaves={}
 local function walk(list,group)
  for _,l in ipairs(list) do
   if l.isGroup then walk(l.layers,l.name) else
    local g=group or l.name
    if g=='Body' or g=='Clothes' or g=='Hairs' or g=='Helmets' or g=='Weapons' or g=='Shields' or g=='Shields_Upper Layer' then
     local im=Image(s.spec)
     local cel=l:cel(1)
     if cel then im:drawImage(cel.image,cel.position) end
     local id=string.lower(race)..'-'..string.format('%02d',#leaves+1)
     local file='layers/'..id..'.png'
     local bounds={256,256,-1,-1}; local n=0
     for y=0,255 do for x=0,255 do if app.pixelColor.rgbaA(im:getPixel(x,y))>0 then
      bounds[1]=math.min(bounds[1],x); bounds[2]=math.min(bounds[2],y)
      bounds[3]=math.max(bounds[3],x); bounds[4]=math.max(bounds[4],y); n=n+1
     end end end
     local registered=not unsupported[race][#leaves+1]
     -- Body cels include extra studies. Mixed mail/bracer cels also include
     -- swatches or a second figure. Isolate only the main authored pose.
     if g=='Body' or (race=='Human' and (#leaves+1>=11 and #leaves+1<=13)) or (race=='Dwarf' and #leaves+1==16) then
      local left=race=='Human' and 77 or 118
      local right=race=='Human' and 141 or 183
      for y=0,255 do for x=0,255 do if x<left or x>right or y>81 then im:drawPixel(x,y,0) end end end
     end
     local normalized=Image(128,96,ColorMode.RGB)
     normalized:drawImage(im,Point(race=='Human' and -48 or -88,0))
     normalized:saveAs(out..'/'..file)
     leaves[#leaves+1]={id=id,name=l.name,group=g,file=file,visible=l.isVisible,bounds=bounds,pixels=n,registered=registered,issue=unsupported[race][#leaves+1] or ''}
     print(id..' '..g..'/'..l.name..' bounds='..table.concat(bounds,','))
    end
   end
  end
 end
 walk(s.layers,nil)
 entries[#entries+1]={race=race,source=source,width=128,height=96,frames=#s.frames,layers=leaves}
 -- Enumerated variants use the same body and pixel scale for visual inspection.
 local body
 for _,l in ipairs(leaves) do if l.group=='Body' then body=Image{fromFile=out..'/'..l.file} end end
 local valid={}; for _,l in ipairs(leaves) do if l.registered then valid[#valid+1]=l end end
 local cols=6; local rows=math.ceil(#valid/cols)
 local sheet=Image(cols*96,rows*100,ColorMode.RGB); sheet:clear(app.pixelColor.rgba(53,56,62,255))
 for i,l in ipairs(valid) do
  local x=((i-1)%cols)*96-16; local y=math.floor((i-1)/cols)*100
  sheet:drawImage(body,Point(x,y))
  sheet:drawImage(Image{fromFile=out..'/'..l.file},Point(x,y))
 end
 local p=Sprite(sheet.width,sheet.height,ColorMode.RGB); p:newCel(p.layers[1],1,sheet,Point(0,0)); app.sprite=p
 app.command.SpriteSize{width=sheet.width*3,height=sheet.height*3,method='nearest'}
 p:saveAs(out..'/'..string.lower(race)..'-variants-3x.png'); p:close()
 s:close()
end
local f=assert(io.open(out..'/catalog.json','w')); f:write(json.encode(entries)); f:close()
