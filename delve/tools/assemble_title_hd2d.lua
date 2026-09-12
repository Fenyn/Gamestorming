-- Run from delve with Aseprite --batch --script tools/assemble_title_hd2d.lua
-- Generated scenery is a single paint layer; logo and ornament are independent.
local dir = 'design/title-study/'
local s = app.open(dir .. 'delve-hd2d-source-v2.png')
app.command.SpriteSize { ui=false, width=960, height=540, method='nearest-neighbor' }
assert(s.width==960 and s.height==540, 'Unexpected canvas size')
s.layers[1].name = '01 HD2D scenery - generated flattened paint layer'
s:saveCopyAs(dir .. 'delve-hd2d-background-v2.png')
local function rgba(hex,a)
  return app.pixelColor.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),a or 255)
end
local function newLayer(name)
  local l=s:newLayer(); l.name=name
  return s:newCel(l,1,Image(960,540,ColorMode.RGB),Point(0,0)).image
end
local mask=Image(960,540,ColorMode.RGB)
local function rect(im,x,y,w,h,c)
  for yy=y,y+h-1 do for xx=x,x+w-1 do im:drawPixel(xx,yy,c) end end
end
local function polygon(im,p,c)
  local ymin,ymax=540,0
  for _,v in ipairs(p) do ymin=math.min(ymin,v[2]); ymax=math.max(ymax,v[2]) end
  for y=ymin,ymax do
    local cuts={}
    for i,a in ipairs(p) do
      local b=p[i%#p+1]
      if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then
        cuts[#cuts+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
      end
    end
    table.sort(cuts)
    for i=1,#cuts-1,2 do rect(im,math.ceil(cuts[i]),y,math.floor(cuts[i+1])-math.ceil(cuts[i])+1,1,c) end
  end
end
local white=rgba('ffffff')
local function box(x,y,w,h) rect(mask,x,y,w,h,white) end
local function shape(x,y,points,c)
  local p={}; for _,v in ipairs(points) do p[#p+1]={x+v[1],y+v[2]} end
  polygon(mask,p,c or white)
end
-- Roman capitals with flared serifs, a thick/thin stroke rhythm, and open counters.
local y=30
local function stem(x)
  box(x+5,y,8,53); box(x,y,20,3); box(x,y+50,20,3)
  shape(x,y,{{2,3},{5,3},{5,8}})
  shape(x,y,{{13,3},{17,3},{13,8}})
end
local x=346
stem(x)
shape(x,y,{{11,0},{27,0},{38,6},{43,17},{43,36},{38,46},{27,53},{11,53},{11,48},{25,48},{32,43},{35,34},{35,18},{32,10},{25,5},{11,5}})
x=401
stem(x); box(x+12,y,27,4); box(x+12,y+24,21,4); box(x+12,y+49,27,4)
shape(x,y,{{31,3},{39,3},{39,12},{36,12}})
shape(x,y,{{31,49},{39,41},{39,49}})
box(x+30,y+19,3,14)
x=453
stem(x); box(x+12,y+49,27,4)
shape(x,y,{{29,49},{39,40},{39,49}})
x=503
shape(x,y,{{0,0},{18,0},{18,3},{14,4},{27,42},{40,4},{35,3},{35,0},{50,0},{50,3},{44,5},{27,54},{23,54},{5,5},{0,3}})
x=565
stem(x); box(x+12,y,27,4); box(x+12,y+24,21,4); box(x+12,y+49,27,4)
shape(x,y,{{31,3},{39,3},{39,12},{36,12}})
shape(x,y,{{31,49},{39,41},{39,49}})
box(x+30,y+19,3,14)
local function filled(x,y)
  return app.pixelColor.rgbaA(mask:getPixel(x,y))>0
end
local shadow=newLayer('02 Title shadow')
for yy=28,86 do for xx=342,608 do
  if filled(xx,yy) then
    rect(shadow,xx-1,yy-1,3,3,rgba('101721',220))
    rect(shadow,xx+1,yy+2,3,3,rgba('101721',235))
  end
end end
local logo=newLayer('03 DELVE - pixel Roman lettering')
for yy=28,86 do for xx=342,608 do
  if filled(xx,yy) then
    local c=yy<53 and 'dfd3b4' or 'b5a17f'
    if not filled(xx,yy-1) or not filled(xx-1,yy) then c='f8edce'
    elseif not filled(xx,yy+1) or not filled(xx+1,yy) then c='78684f' end
    logo:drawPixel(xx,yy,rgba(c))
  end
end end
local ornament=newLayer('04 Watchlight ornament')
rect(ornament,399,99,63,1,rgba('a48e64',190))
rect(ornament,488,99,63,1,rgba('a48e64',190))
polygon(ornament,{{475,92},{482,99},{475,106},{468,99}},rgba('b69865'))
polygon(ornament,{{475,94},{480,99},{475,104},{470,99}},rgba('26353c'))
polygon(ornament,{{475,96},{477,99},{475,102},{473,99}},rgba('f2cc86'))
s:saveAs(dir .. 'delve-title-hd2d-v2.aseprite')
s:saveCopyAs(dir .. 'delve-title-hd2d-v2.png')
app.command.SpriteSize { ui=false, width=1920, height=1080, method='nearest-neighbor' }
s:saveCopyAs(dir .. 'delve-title-hd2d-v2-1080p.png')
print('TITLE HD2D OK: native 960x540, 5 layers, 1920x1080 preview')
