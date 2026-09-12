-- Aseprite --batch --script tools/build_viper.lua
-- Rebuilds generated masters. Preserve manual edits before running.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local dir=root..'/design/viper-base/'
local W,H=64,48
local rgba=app.pixelColor.rgba
local colors={
  {'m',106,120,84,126,143,91}, {'d',45,55,42,44,58,44},
  {'s',80,94,62,80,98,58}, {'l',180,187,145,183,197,139},
  {'c',198,190,159,212,204,169}, {'o',26,32,27,25,32,28},
  {'e',249,185,44,255,201,93},
}
local P={}; local palette=Palette(#colors+1)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(colors) do
  P[c[1]]=rgba(c[5],c[6],c[7],255)
  palette:setColor(i,Color{r=c[5],g=c[6],b=c[7],a=255})
end
local names={'01 Tail','02 Ground coil','03 Raised neck','04 Head and jaw','05 Equipment - empty'}
local originals={}; for i=1,#names do originals[i]=Image(W,H,ColorMode.RGB) end
local src=Image{fromFile=dir..'construction-reference.png'}
for y=0,29 do for x=0,43 do
  local p=src:getPixel(math.floor(315+(x+.5)*823/44),math.floor(266+(y+.5)*568/30))
  if app.pixelColor.rgbaA(p)>200 then
    local r,g,b=app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)
    local key,dist='m',math.huge
    for _,c in ipairs(colors) do
      local d=(r-c[2])^2+(g-c[3])^2+(b-c[4])^2
      if d<dist then key,dist=c[1],d end
    end
    local layer=x<14 and 1 or y>=18 and 2 or y<=9 and x>=29 and 4 or 3
    -- Broad planes: keep highlights on the crown and the top of the rear coil.
    if key=='l' and not(y<3 or (y==18 and x>=18 and x<=21)) then key='m' end
    if key=='s' then key='m' end
    if key=='c' and x<20 and y>=24 then key='m' end
    originals[layer]:drawPixel(x+6,y+14,P[key])
  end
end end
-- Restore the single-pixel focal eye lost between generated sample columns.
originals[4]:drawPixel(44,19,P.e)
for x=45,47 do originals[4]:drawPixel(x,22,P.c) end
local function newMaster()
  local s=Sprite(W,H,ColorMode.RGB); s:setPalette(palette)
  for i,n in ipairs(names) do local l=i==1 and s.layers[1] or s:newLayer(); l.name=n end
  return s
end
local function flat(s,f) local im=Image(s.spec); im:drawSprite(s,f); return im end
local function preview(im,path,scale)
  local s=Sprite(im.width,im.height,ColorMode.RGB)
  s:newCel(s.layers[1],1,im,Point(0,0)); app.sprite=s
  app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'}
  s:saveAs(path)
end
local base=newMaster()
for i,im in ipairs(originals) do base:newCel(base.layers[i],1,im,Point(0,0)) end
base:saveAs(dir..'viper-base.aseprite')
local baseFlat=flat(base,1); baseFlat:saveAs(dir..'viper-base.png')
preview(baseFlat,dir..'viper-base-8x.png',8)
local function animate(clip,weights,fps,offsets)
  local s=newMaster(); local flats={}
  for f,weight in ipairs(weights) do
    if f>1 then s:newEmptyFrame() end
    for i,original in ipairs(originals) do
      local posed=Image(original)
      if clip=='attack' and i==4 and f>=2 and f<=4 then
        -- Mouth opens from the rear cheek; upper skull and eye remain stable.
        for y=21,25 do for x=39,50 do posed:drawPixel(x,y,0) end end
        local rows=f==3 and {'ddoocooocoo','.ddccccccc.'} or
          {'ddoocooocoo','.ddooooooo.','..ddooooo..','...cccccc..'}
        for row,mask in ipairs(rows) do for col=1,#mask do
          local key=mask:sub(col,col)
          if P[key] then posed:drawPixel(38+col,20+row,P[key]) end
        end end
      end
      local im=Image(W,H,ColorMode.RGB)
      for y=0,H-1 do for x=0,W-1 do
        local sy=y
        -- A snake keeps its eyes open; idle is a subtle neck lift, no blink.
        if clip=='idle' and f>=2 and f<=4 and y<34 then sy=y+1 end
        local shift=math.floor(offsets[f]*math.max(0,math.min(1,(39-y)/12))+.5)
        local sx=x-shift
        if sx>=0 and sx<W then im:drawPixel(x,y,posed:getPixel(sx,sy)) end
      end end
      s:newCel(s.layers[i],f,im,Point(0,0))
    end
    s.frames[f].duration=weight/fps
    flats[f]=flat(s,f); flats[f]:saveAs(dir..clip..'_'..f..'.png')
  end
  local tag=s:newTag(1,#weights); tag.name=clip=='idle' and 'rest' or 'attack'
  s:saveAs(dir..'viper-'..clip..'.aseprite')
  local timing=io.open(dir..clip..'-timing.json','w')
  timing:write('{"fps":'..fps..',"weights":['..table.concat(weights,',')..']'..(clip=='attack' and ',"impact_frame":2' or '')..'}\n'); timing:close()
  local sheet=Image(W*#weights,H,ColorMode.RGB); sheet:clear(Color{r=53,g=56,b=62,a=255})
  local gif=Sprite(W,H,ColorMode.RGB)
  for f,im in ipairs(flats) do
    sheet:drawImage(im,Point((f-1)*W,0))
    if f>1 then gif:newEmptyFrame() end
    local bg=Image(W,H,ColorMode.RGB); bg:clear(Color{r=53,g=56,b=62,a=255}); bg:drawImage(im)
    gif:newCel(gif.layers[1],f,bg,Point(0,0)); gif.frames[f].duration=weights[f]/fps
  end
  if clip=='attack' then gif.frames[#weights].duration=.8 end
  app.sprite=gif; app.command.SpriteSize{width=W*4,height=H*4,method='nearest'}
  gif:saveAs(dir..clip..'-preview.gif')
  preview(sheet,dir..clip..'-frames-4x.png',4)
  local reopened=app.open(dir..'viper-'..clip..'.aseprite')
  assert(#reopened.layers==#names and #reopened.frames==#weights)
  for f,im in ipairs(flats) do
    local check=flat(reopened,f)
    for y=0,H-1 do for x=0,W-1 do assert(check:getPixel(x,y)==im:getPixel(x,y),'Master mismatch') end end
  end
  print('Verified '..clip..': layered master matches every exported frame')
end
animate('idle',{4,3,2,3,4},8,{0,0,0,0,0})
animate('attack',{.8,1,.8,1,1.2,1},10,{-1,-3,6,4,1,0})
local board=Image(320,68,ColorMode.RGB); board:clear(Color{r=53,g=56,b=62,a=255})
local refs={
  {'assets/sprites/enemies/rat_v1/idle_1.png',0,16},
  {'design/goblin-base/goblin-base.png',48,0},
  {'design/kobold-base/kobold-base.png',104,0},
  {'design/wolf-base/wolf-base.png',168,6},
  {'design/viper-base/viper-base.png',246,14},
}
for _,r in ipairs(refs) do board:drawImage(Image{fromFile=root..'/'..r[1]},Point(r[2],r[3])) end
preview(board,dir..'reference-lineup-4x.png',4)
