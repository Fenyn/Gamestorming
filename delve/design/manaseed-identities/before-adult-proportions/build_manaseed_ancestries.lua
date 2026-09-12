-- Aseprite proportion study: four standing facings, with source-registered clothing.
local root='G:/Godot/Gamestorming/delve/'
local dir=root..'design/manaseed-identities/'
local out=dir..'ancestry-study/';app.fs.makeAllDirectories(out)
local pc=app.pixelColor
local configs={
 {name='aldric',slots={'0bas','1out','4har'},remove={},repeatRows={},pad=0},
 {name='elara',slots={'0bas','1out','4har'},remove={},repeatRows={[29]=true,[37]=true,[40]=true},pad=-3},
 {name='tharr',slots={'0bas','1out','4har'},remove={[30]=true,[36]=true,[38]=true,[40]=true},repeatRows={},pad=4},
 {name='fenwick',slots={'0bas','1out','5hat'},remove={[26]=true,[28]=true,[30]=true,[32]=true,[35]=true,[37]=true,[39]=true,[41]=true},repeatRows={},pad=8},
}
local function rows(c)
 local map={};local dest=c.pad
 for sy=0,63 do
  if not c.remove[sy] then
   map[dest]=sy;dest=dest+1
   if c.repeatRows[sy] then map[dest]=sy;dest=dest+1 end
  end
 end
 return map
end
local function sxFor(c,x,sy,face)
 local center=31.5;local scale=1
 if c.name=='tharr' then
  -- Head remains readable; shoulders, chest, apron and upper arms share extra breadth.
  if sy<25 then scale=1.10 elseif sy<36 then scale=face<2 and 1.28 or 1.22 else scale=1.16 end
 elseif c.name=='fenwick' then
  if sy>=42 then scale=1.18 elseif sy>=26 then scale=.94 end
 elseif c.name=='elara' then
  if sy>=29 and sy<36 then scale=.92 end
 end
 return math.floor(center+(x-center)/scale+.5)
end
local function enlarge(im,path,factor) local a=Image(im);a:resize(a.width*factor,a.height*factor);a:saveAs(path) end
local board=Image(192,192,ColorMode.RGB)
local bodies=Image(192,192,ColorMode.RGB)
for _,im in ipairs({board,bodies}) do for p in im:pixels() do p(pc.rgba(52,63,70,255)) end end
for i,c in ipairs(configs) do
 local s=Sprite(64,64,ColorMode.RGB);s:deleteLayer(s.layers[1])
 for k=2,4 do s:newEmptyFrame() end
 local map=rows(c)
 for _,slot in ipairs(c.slots) do
  local source=Image{fromFile=dir..c.name..'/layers/p1/'..slot..'.png'}
  local l=s:newLayer();l.name=slot..' - '..c.name
  for face=0,3 do
   local im=Image(64,64,ColorMode.RGB)
   for y=0,63 do local sy=map[y]
    if sy and sy>=0 and sy<64 then for x=0,63 do
     local sx=sxFor(c,x,sy,face)
     if sx>=0 and sx<64 then im:drawPixel(x,y,source:getPixel(sx,face*64+sy)) end
    end end
   end
   s:newCel(l,face+1,im,Point(0,0))
   if slot=='0bas' then
    bodies:drawImage(Image(im,Rectangle(8,0,48,48)),Point((i-1)*48,face*48))
   end
  end
 end
 local faces={'south','north','east','west'}
 for face=0,3 do
  local tag=s:newTag(face+1,face+1);tag.name=faces[face+1]
  local im=Image(s.spec);im:drawSprite(s,face+1)
  im:saveAs(out..c.name..'-'..faces[face+1]..'.png')
  board:drawImage(Image(im,Rectangle(8,0,48,48)),Point((i-1)*48,face*48))
 end
 s:saveAs(out..c.name..'.aseprite');s:close()
 local reopened=app.open(out..c.name..'.aseprite')
 assert(#reopened.frames==4 and #reopened.layers==#c.slots,'Master structure mismatch')
 for face=0,3 do
  local actual=Image(reopened.spec);actual:drawSprite(reopened,face+1)
  local expected=Image{fromFile=out..c.name..'-'..faces[face+1]..'.png'}
  assert(actual:isEqual(expected),'Master/export mismatch: '..c.name..' '..faces[face+1])
 end
 reopened:close()
 print(c.name..': four registered facings exported')
end
board:saveAs(out..'lineup-native.png');enlarge(board,out..'lineup-5x.png',5)
bodies:saveAs(out..'bodies-native.png');enlarge(bodies,out..'bodies-5x.png',5)
