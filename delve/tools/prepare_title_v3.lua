local P=dofile('tools/title_pixels.lua')
local dir='design/title-study/v3/'
app.fs.makeAllDirectories(dir..'parts')
for _,name in ipairs({'environment','valley'}) do
  local im=P.load(dir..name..'-source.png',640,360)
  P.quantize(im,P.environment)
  local removed=P.depeckle(im,2)
  removed=removed+P.depeckle(im,2,true)
  im:saveAs(dir..'parts/'..name..'.png')
  print(name..': removed '..removed..' isolated interior flecks')
end
local sheet=P.load(dir..'travelers-source.png')
local names={'aldric','elara','tharr','fenwick'}
local crops={}
local tallest=0
for i,name in ipairs(names) do
  local x0,x1=math.floor((i-1)*sheet.width/4),math.floor(i*sheet.width/4)-1
  local left,right,top,bottom=x1,x0,sheet.height,0
  for y=0,sheet.height-1 do for x=x0,x1 do
    if app.pixelColor.rgbaA(sheet:getPixel(x,y))>=128 then
      left=math.min(left,x); right=math.max(right,x); top=math.min(top,y); bottom=math.max(bottom,y)
    end
  end end
  assert(right>left and bottom>top,'Missing transparent sprite: '..name)
  local im=Image(sheet,Rectangle(left,top,right-left+1,bottom-top+1))
  crops[i]=im; tallest=math.max(tallest,im.height)
end
-- One scale for the entire cast preserves dwarf/halfling height differences.
local scale=52/tallest
local review=P.image(224,64)
for i,im in ipairs(crops) do
  im:resize{width=math.floor(im.width*scale*1.3+0.5),height=math.floor(im.height*scale+0.5),method='nearest-neighbor'}
  P.quantize(im,P.people); P.depeckle(im,1)
  im:saveAs(dir..'parts/'..names[i]..'.png')
  review:drawImage(im,Point((i-1)*56+math.floor((56-im.width)/2),60-im.height))
  print(names[i]..': '..im.width..'x'..im.height)
end
review:resize{width=896,height=256,method='nearest-neighbor'}
review:saveAs(dir..'travelers-review-4x.png')
print('PREPARE TITLE V3 OK')
