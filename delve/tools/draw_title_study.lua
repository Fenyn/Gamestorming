-- Aseprite composition study. Run from the delve directory:
-- Aseprite.exe --batch --script tools/draw_title_study.lua
-- Outputs are editable art studies, not wired into the game.
local out = app.params.output or 'design/title-study'
app.fs.makeAllDirectories(out)
math.randomseed(41)
local s = Sprite(640, 360, ColorMode.RGB)
local im
local function color(hex)
  return app.pixelColor.rgba(tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16),255)
end
local function layer(name)
  local l = s:newLayer(); l.name = name
  im = Image(640,360,ColorMode.RGB)
  s:newCel(l,1,im,Point(0,0))
  im = s.cels[#s.cels].image
end
local function rect(x,y,w,h,c)
  c = color(c)
  for yy=math.max(0,y),math.min(359,y+h-1) do
    for xx=math.max(0,x),math.min(639,x+w-1) do im:drawPixel(xx,yy,c) end
  end
end
local function poly(p,c)
  local lo,hi=359,0
  for _,v in ipairs(p) do lo=math.min(lo,v[2]); hi=math.max(hi,v[2]) end
  for y=math.max(0,lo),math.min(359,hi) do
    local xs={}
    for i,a in ipairs(p) do
      local b=p[i % #p+1]
      if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then
        xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
      end
    end
    table.sort(xs)
    for i=1,#xs-1,2 do rect(math.ceil(xs[i]),y,math.floor(xs[i+1])-math.ceil(xs[i])+1,1,c) end
  end
end
layer('01 Dusk')
rect(0,0,640,360,'141e2a')
rect(0,115,640,245,'1c2d38')
rect(0,171,640,189,'263d45')
layer('02 Distant forest')
for x=-10,660,13 do
  local y=math.random(128,189)
  poly({{x,y},{x-24,y+75},{x+24,y+75}},'30494e')
end
layer('03 Fog behind outpost')
for i=1,22 do
  local x,y=math.random(-80,590),math.random(175,248)
  rect(x,y,math.random(40,180),math.random(2,5),'3b5558')
end
layer('04 Outpost silhouette')
poly({{130,261},{185,223},{270,208},{348,207},{434,228},{506,265}},'17272e')
rect(223,169,144,70,'263039')
poly({{208,171},{289,123},{376,171}},'17252d')
poly({{220,165},{289,123},{300,130},{235,169}},'435154')
rect(363,125,44,119,'29363e')
rect(359,121,52,8,'4a5657')
for x=359,403,15 do rect(x,110,8,12,'37464c') end
rect(396,133,11,108,'1d2b33')
rect(205,204,24,40,'344047')
rect(197,200,37,7,'4a5555')
-- Sparse masonry follows the forms, keeping broad areas quiet.
for y=178,232,11 do
  for x=232,354,19 do
    if math.random()<0.55 then rect(x+math.random(0,5),y,12,1,'3d484b') end
  end
end
for y=141,221,14 do rect(366,y,19,1,'425056') end
-- Chapel entrance and watch light.
poly({{279,233},{279,191},{291,176},{303,191},{303,233}},'101b24')
rect(286,190,11,31,'84513c')
rect(289,189,5,29,'e3a35b')
rect(290,191,2,24,'f5dfaa')
rect(379,145,9,17,'111e29')
rect(382,147,3,12,'efbb72')
layer('05 Descending approach')
poly({{283,232},{302,232},{377,323},{252,323}},'505552')
for i=0,10 do
  local y=233+i*8; local left=282-i*3; local right=303+i*6
  rect(left,y,right-left,2,'8a8067')
  rect(left,y+2,right-left,3,'333e42')
end
poly({{0,274},{71,244},{144,262},{210,254},{266,283},{278,360},{0,360}},'111e28')
poly({{640,249},{567,244},{505,261},{439,251},{371,288},{353,360},{640,360}},'111e28')
layer('06 Foreground fog')
for i=1,16 do
  local x,y=math.random(-60,610),math.random(242,278)
  if x<235 or x>395 then rect(x,y,math.random(30,95),2,'30464c') end
end
layer('07 Four travelers')
local function traveler(x,y,cloak)
  rect(x-4,y+20,4,13,'090f19'); rect(x+3,y+20,4,13,'090f19')
  poly({{x-5,y+5},{x+5,y+5},{x+10,y+24},{x-10,y+24}},cloak)
  rect(x-4,y-2,8,9,'19242d'); rect(x-3,y-3,6,2,'82755f')
  rect(x+5,y+9,2,12,'a08a68')
end
traveler(263,278,'764e57')
traveler(287,284,'555070')
traveler(337,283,'496d76')
traveler(361,275,'41577b')
rect(371,271,2,39,'a88b65')
rect(249,287,3,28,'83908a')
layer('08 DELVE logo')
local letters={D={'11110','11001','11001','11001','11001','11001','11110'},E={'11111','11000','11000','11110','11000','11000','11111'},L={'11000','11000','11000','11000','11000','11000','11111'},V={'11011','11011','11011','11011','11011','01110','00100'}}
local function title(dx,dy,shade)
  for i=1,5 do
    for y,row in ipairs(letters[('DELVE'):sub(i,i)]) do
      for x=1,5 do
        if row:sub(x,x)=='1' then rect(207+(i-1)*47+(x-1)*7+dx,43+(y-1)*7+dy,7,7,shade or (y<4 and 'eee4c9' or 'c1ad85')) end
      end
    end
  end
end
title(3,4,'0b1420'); title(0,0)
rect(256,106,128,1,'6c7975')
poly({{320,102},{324,106},{320,110},{316,106}},'e2a263')
s:deleteLayer(s.layers[1])
s:saveAs(out .. '/delve-title-study.aseprite')
s:saveCopyAs(out .. '/delve-title-study.png')
print('TITLE STUDY OK: ' .. s.width .. 'x' .. s.height .. ', ' .. #s.layers .. ' layers; ' .. out)
