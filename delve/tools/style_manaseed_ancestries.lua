-- Aseprite style pass. Preserve approved anatomy, registration and layer alpha.
local root='G:/Godot/Gamestorming/delve/'
local input=root..'design/manaseed-identities/ancestry-study/'
local out=root..'design/manaseed-identities/monster-style/';app.fs.makeAllDirectories(out)
local pc=app.pixelColor
local function hex(h) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255) end
local mappings={};local highlights={}
local function ramp(name,slot,source,target)
 mappings[name]=mappings[name] or {};mappings[name][slot]=mappings[name][slot] or {}
 highlights[name]=highlights[name] or {};highlights[name][slot]=highlights[name][slot] or {}
 for i,h in ipairs(source) do mappings[name][slot][hex(h)]=hex(target[i]) end
 if slot~='0bas' then highlights[name][slot][hex(source[#source])]=hex(target[#target-1]) end
end
ramp('aldric','0bas',{'804828','c88028','f0c080'},{'79563e','bf9766','e2c391'})
ramp('elara','0bas',{'9b4326','d08070','f8c0b0'},{'805b51','bf9380','e5bfaa'})
ramp('tharr','0bas',{'772a1b','ab5544','e09060'},{'69443b','a16a53','cf9c72'})
ramp('fenwick','0bas',{'8c4131','de864b','ffc784'},{'805543','c38b61','e9bd87'})
ramp('aldric','1out',{'583828','986038','f09848'},{'433a30','9f7950','c5a677'})
ramp('aldric','1out',{'364a3f','5b7f6a','a8c898'},{'34483c','748b66','abb99a'})
ramp('aldric','4har',{'331616','4e2b20','725436','a08154'},{'302a25','50412f','87704b','b5a075'})
ramp('elara','1out',{'52525f','7c8989','a7b5a7'},{'3d484c','7b8c87','bac5b0'})
ramp('elara','1out',{'3d1200','632e11','8d6340'},{'392f29','715439','a88b62'})
ramp('elara','1out',{'2e4048','2d836d'},{'344a46','708f7b'})
ramp('elara','4har',{'272751','4e4878','8868a0','e098b8'},{'332e43','50445f','92779f','c3a5b8'})
ramp('elara','4har',{'905d03','d1a630','ede57f'},{'665435','b19859','dace9d'})
ramp('tharr','1out',{'304050','586870','90a0b0'},{'303e43','76898d','b6c5bf'})
ramp('tharr','1out',{'704058','b08898','e0c8d8'},{'57464f','a38b91','cab7b8'})
ramp('tharr','1out',{'7f4935','b47f54','dab988'},{'584533','997c57','c7b38c'})
ramp('tharr','4har',{'503850','686878','8898a0','c8c8b8'},{'343c3f','626f72','9aa7a4','ced0b9'})
ramp('fenwick','1out',{'374b5b','5b8586','9bbd87','c8d8a8'},{'304343','557570','94ab84','c6d1ac'})
ramp('fenwick','5hat',{'1e2b41','3c5575','6293ad','99d6e3'},{'293645','455f77','779eac','b7d1cb'})
ramp('fenwick','5hat',{'5b1839','8d2246','be5667'},{'48323d','83515f','ba8390'})
local function enlarge(im,path,scale) local a=Image(im);a:resize(a.width*scale,a.height*scale);a:saveAs(path) end
local function bg(w,h) local a=Image(w,h,ColorMode.RGB);for p in a:pixels() do p(hex('343f46')) end;return a end
local board=bg(192,192);local comparison=bg(192,192);local refs=bg(400,88)
local faces={'south','north','east','west'}
for n,name in ipairs({'aldric','elara','tharr','fenwick'}) do
 local s=app.open(input..name..'.aseprite')
 for _,l in ipairs(s.layers) do local slot=l.name:sub(1,4)
  local map=mappings[name][slot] or {};local hl=highlights[name][slot] or {}
  for _,cel in ipairs(l.cels) do
   local old=cel.image;local im=Image(old)
   for y=0,im.height-1 do for x=0,im.width-1 do local p=old:getPixel(x,y)
    if pc.rgbaA(p)>0 then
     local c=map[p] or (p==hex('181818') and hex('242c2b') or p)
     -- Consolidate interior light flecks. Keep short upper edge accents and trim.
     if hl[p] then
      local above=0
      for dy=1,3 do if y-dy>=0 and pc.rgbaA(old:getPixel(x,y-dy))>0 then above=above+1 end end
      if above==3 then c=hl[p] end
     end
     im:drawPixel(x,y,c)
    end
   end end
   cel.image=im
  end
 end
 for face=0,3 do
  local im=Image(s.spec);im:drawSprite(s,face+1)
  local old=Image{fromFile=input..name..'-'..faces[face+1]..'.png'}
  for y=0,63 do for x=0,63 do assert(pc.rgbaA(im:getPixel(x,y))==pc.rgbaA(old:getPixel(x,y)),'Silhouette changed') end end
  im:saveAs(out..name..'-'..faces[face+1]..'.png')
  board:drawImage(Image(im,Rectangle(8,0,48,48)),Point((n-1)*48,face*48))
  if face==0 or face==2 then
   local row=face==0 and 0 or 2
   comparison:drawImage(Image(old,Rectangle(8,0,48,48)),Point((n-1)*48,row*48))
   comparison:drawImage(Image(im,Rectangle(8,0,48,48)),Point((n-1)*48,(row+1)*48))
  end
  if face==2 then refs:drawImage(im,Point(160+(n-1)*60,32)) end
 end
 s:saveAs(out..name..'.aseprite');s:close()
 local check=app.open(out..name..'.aseprite')
 for i,face in ipairs(faces) do
  local im=Image(check.spec);im:drawSprite(check,i)
  assert(im:isEqual(Image{fromFile=out..name..'-'..face..'.png'}),'Master/export mismatch')
 end
 check:close();print(name..': four facings, silhouettes unchanged, master verified')
end
refs:drawImage(Image{fromFile=root..'assets/sprites/enemies/rat_v1/idle_1.png'},Point(0,38))
refs:drawImage(Image{fromFile=root..'design/goblin-base/goblin-base.png'},Point(84,18))
board:saveAs(out..'lineup-native.png');enlarge(board,out..'lineup-5x.png',5)
enlarge(comparison,out..'before-after-5x.png',5)
enlarge(refs,out..'monster-comparison-4x.png',4)
