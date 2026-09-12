-- Recover the current shipped characters as editable, pixel-identical native masters.
-- Optional preview is a mild palette adjustment; runtime assets are never overwritten.
local root='G:/Godot/Gamestorming/delve/'
local dir=root..'design/manaseed-identities/'
local f=assert(io.open(dir..'source-recipes.json','r'))
local recipes=json.decode(f:read('*a'));f:close()
local pc=app.pixelColor
local function preview(im,path,scale)
 local copy=Image(im);copy:resize(im.width*scale,im.height*scale);copy:saveAs(path)
end
local function equalVisible(a,b)
 assert(a.width==b.width and a.height==b.height,'Different dimensions')
 for y=0,a.height-1 do for x=0,a.width-1 do
  local u,v=a:getPixel(x,y),b:getPixel(x,y)
  assert(pc.rgbaA(u)==pc.rgbaA(v),'Alpha mismatch '..x..','..y..' '..pc.rgbaA(u)..'/'..pc.rgbaA(v))
  assert(pc.rgbaA(u)==0 or u==v,'Visible pixel mismatch')
 end end
end
local function subtle(im)
 local out=Image(im)
 for it in out:pixels() do local c=it()
  if pc.rgbaA(c)>0 then
   local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
   local lum=.2126*r+.7152*g+.0722*b
   -- Small value/saturation adjustment. Never change alpha or pixel placement.
   local shift=lum<65 and -4 or lum>175 and 3 or 0
   local function channel(v) return math.max(0,math.min(255,math.floor(v*.98+lum*.02+shift+.5))) end
   it(pc.rgba(channel(r),channel(g),channel(b),pc.rgbaA(c)))
  end
 end
 return out
end
local sheets={}
for _,rec in ipairs(recipes) do
 local path=dir..rec.name..'/';app.fs.makeAllDirectories(path..'layers/'..rec.page)
 local s=Sprite(512,512,ColorMode.RGB);s:deleteLayer(s.layers[1])
 for _,part in ipairs(rec.layers) do
  local im=Image{fromFile=part.source};assert(im.width==512 and im.height==512,'Unexpected source size')
  -- Match the existing baker: only alpha == 255 contributes. Fenwick's hat
  -- contains a few semi-transparent pixels which the shipped bake excludes.
  for it in im:pixels() do if pc.rgbaA(it())~=255 then it(0) end end
  local l=s:newLayer();l.name=part.slot..' '..part.asset;s:newCel(l,1,im,Point(0,0))
  im:saveAs(path..'layers/'..rec.page..'/'..part.slot..'.png')
 end
 local rendered=Image(s.spec);rendered:drawSprite(s,1)
 local current=Image{fromFile=root..'assets/sprites/heroes/'..rec.folder..'/'..rec.page..'.png'}
 equalVisible(rendered,current)
 s:saveAs(path..rec.page..'.aseprite');rendered:saveAs(path..rec.page..'-current.png')
 s:close()
 local reopened=app.open(path..rec.page..'.aseprite');local again=Image(reopened.spec);again:drawSprite(reopened,1)
 equalVisible(rendered,again);reopened:close()
 local adjusted=subtle(rendered);adjusted:saveAs(path..rec.page..'-subtle-preview.png')
 if rec.page=='p1' then sheets[rec.name]={rendered,adjusted} end
 print(rec.name..'/'..rec.page..': source and reopened master match runtime')
end
-- Left-to-right: Aldric, Elara, Tharr, Fenwick. Two rows per treatment: south and east.
local board=Image(160,160,ColorMode.RGB)
for it in board:pixels() do it(pc.rgba(52,63,70,255)) end
for i,name in ipairs({'aldric','elara','tharr','fenwick'}) do
 for treatment=1,2 do for face=0,1 do
  local crop=Image(sheets[name][treatment],Rectangle(16,face*128+6,32,44))
  board:drawImage(crop,Point((i-1)*40+4,(treatment-1)*80+face*40-4))
 end end
end
board:saveAs(dir..'comparison-native.png');preview(board,dir..'comparison-6x.png',6)
-- Inspect actual source anatomy, outfit and hair separately using the east-facing stand.
local stack=Image(160,160,ColorMode.RGB)
for it in stack:pixels() do it(pc.rgba(52,63,70,255)) end
for i,name in ipairs({'aldric','elara','tharr','fenwick'}) do
 for row,slot in ipairs({'0bas','1out',name=='fenwick' and '5hat' or '4har'}) do
  local source=Image{fromFile=dir..name..'/layers/p1/'..slot..'.png'}
  stack:drawImage(Image(source,Rectangle(16,134,32,44)),Point((i-1)*40+4,(row-1)*40-4))
 end
 stack:drawImage(Image(sheets[name][1],Rectangle(16,134,32,44)),Point((i-1)*40+4,116))
end
preview(stack,dir..'current-layers-6x.png',6)
