-- Native Aseprite attack poses. Bases and idle masters remain independent.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local rgba=app.pixelColor.rgba
local weights={0.8,1,0.8,1,1.2,1}
local kinds={
 {name='goblin',arm=9,shoulder={23,25},main=rgba(132,148,103,255),shadow=rgba(75,89,62,255),light=rgba(178,189,142,255),
  elbows={{17,29},{15,28},{35,27},{34,29},{23,32}},hands={{23,25},{21,24},{47,25},{45,29},{31,34}}},
 {name='kobold',arm=8,shoulder={33,24},main=rgba(178,118,87,255),shadow=rgba(120,73,52,255),light=rgba(212,158,119,255),
  elbows={{26,29},{24,28},{43,27},{42,29},{30,33}},hands={{31,25},{29,24},{55,26},{53,30},{34,36}}},
 {name='wolf'},
}
local function disk(im,x,y,r,p)
 for yy=math.floor(y-r),math.ceil(y+r) do for xx=math.floor(x-r),math.ceil(x+r) do
  if (xx-x)^2+(yy-y)^2<=r*r and xx>=0 and yy>=0 and xx<im.width and yy<im.height then im:drawPixel(xx,yy,p) end
 end end
end
local function limb(im,a,b,r,p)
 local n=math.max(math.abs(b[1]-a[1]),math.abs(b[2]-a[2]))
 for j=0,n do local t=n==0 and 0 or j/n; disk(im,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,r,p) end
end
local function restoreUnderpainting(k,images)
 -- Authored anatomy beneath the resting arm. These are continuous surfaces,
 -- not a fill of the vacated arm silhouette. Coordinates use the base canvas.
 local function rows(layer,first,spans,main,shadow,repaint)
  for n,span in ipairs(spans) do
   local y=first+n-1
   for x=span[1],span[2] do
    if repaint or app.pixelColor.rgbaA(images[layer]:getPixel(x,y))==0 then
     images[layer]:drawPixel(x,y,x==span[1] and shadow or main)
    end
   end
  end
 end
 -- These pixels belonged to the resting arm but were assigned to adjacent
 -- layers by the original segmentation. Remove them from the support anatomy
 -- before posing, including diagonal shoulder spurs and a stray wrist pixel.
 local remnants=k.name=='goblin' and {{17,24},{18,23},{17,33},{10,42},{16,37}}
  or (k.name=='kobold' and {{22,34},{30,22},{31,21},{32,21},{33,21}} or {})
 for _,p in ipairs(remnants) do
  for i,im in ipairs(images) do if i~=k.arm then im:drawPixel(p[1],p[2],0) end end
 end
 if k.name=='kobold' then
  -- The thick tail rises smoothly into the pelvis behind the lowered fist.
  rows(1,35,{{29,32},{28,32},{26,32},{23,32},{21,32},{21,32},{22,32},{25,32}},
   k.main,k.main,true)
  -- Restore the back/ribcage where the upper arm used to cover it.
  rows(5,22,{{34,37},{33,37},{32,37},{31,37},{31,37},{30,37},{30,37},{30,37},
   {30,37},{31,37},{31,37},{32,37},{32,37},{32,37}},k.main,k.shadow)
 elseif k.name=='goblin' then
  rows(4,24,{{24,29},{23,29},{22,29},{22,29},{21,29},{21,29},
   {21,29},{21,29},{21,29},{22,29},{23,29},{23,29}},k.main,k.shadow)
 end
end
for _,k in ipairs(kinds) do
 local dir=root..'/design/'..k.name..'-base/'
 local source=app.open(dir..k.name..'-base.aseprite')
 local s=Sprite(source.width,source.height,ColorMode.RGB); s:setPalette(source.palettes[1])
 local originals={}
 for i,l in ipairs(source.layers) do
  local dst=i==1 and s.layers[1] or s:newLayer(); dst.name=l.name
  local im=Image(s.spec); local c=l:cel(1); if c then im:drawImage(c.image,c.position) end; originals[i]=im
 end
 local rest={}
 for i,im in ipairs(originals) do rest[i]=Image(im) end
 restoreUnderpainting(k,originals)
 -- Keep completed hidden surfaces beneath the resting arm too, without
 -- changing the accepted visible recovery pose.
 if k.arm then
  for i,im in ipairs(originals) do
   if i~=k.arm then
    for y=0,s.height-1 do for x=0,s.width-1 do
     if app.pixelColor.rgbaA(rest[k.arm]:getPixel(x,y))>0 then
      rest[i]:drawPixel(x,y,im:getPixel(x,y))
     end
    end end
   end
  end
 end
 -- Export the support anatomy with the near arm hidden for explicit review.
 if k.arm then
  local under=Sprite(s.width,s.height,ColorMode.RGB)
  for i,im in ipairs(originals) do
   if i~=k.arm then
    local layer=under:newLayer(); layer.name=source.layers[i].name
    under:newCel(layer,1,im)
   end
  end
  under:saveAs(dir..'attack-underbody.aseprite')
  app.sprite=under; app.command.SpriteSize{width=under.width*4,height=under.height*4,method='nearest'}
  under:saveAs(dir..'attack-underbody-4x.png')
 end
 local flats={}
 for f,w in ipairs(weights) do
  if f>1 then s:newEmptyFrame() end
  local lean=({-1,-2,2,1,0,0})[f]
  for i,l in ipairs(s.layers) do
   local im=Image(s.spec)
   for y=0,s.height-1 do for x=0,s.width-1 do
    local dx=math.floor(lean*math.min(1,math.max(0,(44-y)/12))+0.5)
    local sx=x-dx
    local sourceImage=f==6 and rest[i] or originals[i]
    if sx>=0 and sx<s.width then im:drawPixel(x,y,sourceImage:getPixel(sx,y)) end
   end end
   if i==k.arm and f<6 then
    im:clear()
    local a={k.shoulder[1]+lean,k.shoulder[2]}; local b=k.elbows[f]; local c=k.hands[f]
    limb(im,a,b,3,k.shadow); limb(im,b,c,2.5,k.shadow)
    limb(im,{a[1],a[2]-1},{b[1],b[2]-1},2,k.main)
    limb(im,{b[1],b[2]-1},{c[1],c[2]-1},1.5,k.main)
    disk(im,c[1],c[2],3,k.shadow); disk(im,c[1],c[2]-1,2.5,k.main)
    limb(im,{a[1]-1,a[2]-2},{a[1]+1,a[2]-2},0.6,k.light)
   end
   if k.name=='wolf' and i==7 and f<=5 then
    -- The upper muzzle/nose stays fixed. The lower jaw turns down from the
    -- cheek hinge, rather than becoming a detached horizontal cream bar.
    -- Sparse cream teeth sit against the mouth shadow at open and contact.
    local poses={
     {'AAoototo.','s...sss..','.........','.........','.........'},
     {'AAoototo.','AAooooto.','.AAooto..','..AAAAs..','....ss...'},
     {'AAototto.','s..sssss.','.........','.........','.........'},
     {'AAoototo.','AAootoo..','.AAAAAs..','...sss...','.........'},
     {'AAooooos.','s...sss..','.........','.........','.........'},
    }
    local colors={A=rgba(201,196,172,255),t=rgba(201,196,172,255),o=rgba(24,31,33,255),s=rgba(37,46,46,255)}
    for row,line in ipairs(poses[f]) do
     for col=1,#line do im:drawPixel(57+col+lean,27+row,colors[line:sub(col,col)] or 0) end
    end
   end
   s:newCel(l,f,im,Point(0,0))
  end
  s.frames[f].duration=w/10
  local flat=Image(s.spec); flat:drawSprite(s,f)
  -- Raising the near arm exposes a few boundary pixels owned by adjacent
  -- layers. Remove detached fragments, preserving the original final pose.
  if f<6 then
   local seen={}
   for y=0,s.height-1 do for x=0,s.width-1 do
    local key=y*s.width+x
    if not seen[key] and app.pixelColor.rgbaA(flat:getPixel(x,y))>0 then
     local group={{x,y}}; seen[key]=true; local cursor=1
     while cursor<=#group do
      local p=group[cursor]; cursor=cursor+1
      for dy=-1,1 do for dx=-1,1 do
       local xx,yy=p[1]+dx,p[2]+dy; local id=yy*s.width+xx
       if xx>=0 and yy>=0 and xx<s.width and yy<s.height and not seen[id] and app.pixelColor.rgbaA(flat:getPixel(xx,yy))>0 then
        seen[id]=true; group[#group+1]={xx,yy}
       end
      end end
     end
     if #group<=4 then
      for _,p in ipairs(group) do for _,layer in ipairs(s.layers) do
       local cel=layer:cel(f); local im=Image(cel.image)
       local xx,yy=p[1]-cel.position.x,p[2]-cel.position.y
       if xx>=0 and yy>=0 and xx<im.width and yy<im.height then im:drawPixel(xx,yy,0); cel.image=im end
      end end
     end
    end
   end end
   flat=Image(s.spec); flat:drawSprite(s,f)
  end
  flats[f]=flat; flat:saveAs(dir..'attack_'..f..'.png')
 end
 local tag=s:newTag(1,#weights); tag.name='attack'
 s:saveAs(dir..k.name..'-attack.aseprite')
 local file=io.open(dir..'attack-timing.json','w'); file:write('{"fps":10,"weights":['..table.concat(weights,',')..'],"impact_frame":2}\n'); file:close()
 local board=Sprite(s.width*#weights,s.height,ColorMode.RGB); local sheet=Image(board.spec)
 sheet:clear(Color{r=53,g=56,b=62,a=255})
 for f,im in ipairs(flats) do sheet:drawImage(im,Point((f-1)*s.width,0)) end
 board:newCel(board.layers[1],1,sheet); app.sprite=board
 app.command.SpriteSize{width=board.width*4,height=board.height*4,method='nearest'}; board:saveAs(dir..'attack-frames-4x.png')
 local preview=Sprite(s.width,s.height,ColorMode.RGB)
 for f,im in ipairs(flats) do
  if f>1 then preview:newEmptyFrame() end
  local bg=Image(preview.spec); bg:clear(Color{r=53,g=56,b=62,a=255}); bg:drawImage(im)
  preview:newCel(preview.layers[1],f,bg); preview.frames[f].duration=f==6 and 0.8 or weights[f]/10
 end
 app.sprite=preview; app.command.SpriteSize{width=preview.width*4,height=preview.height*4,method='nearest'}
 preview:saveAs(dir..'attack-preview.gif')
 local reopened=app.open(dir..k.name..'-attack.aseprite')
 assert(#reopened.layers==#source.layers and #reopened.frames==6)
 for f,flat in ipairs(flats) do
  local check=Image(reopened.spec); check:drawSprite(reopened,f)
  for y=0,s.height-1 do for x=0,s.width-1 do assert(check:getPixel(x,y)==flat:getPixel(x,y)) end end
 end
 print(k.name..': six layered attack frames verified')
end
