local out='G:/Godot/Gamestorming/delve/design/race-identities'
local pc=app.pixelColor
local function c(r,g,b)return pc.rgba(r,g,b,255)end
local P={s=c(118,124,151),h=c(169,192,225),j=c(131,136,160),d=c(33,43,40),r=c(134,72,61),q=c(69,36,44),skin=c(182,160,151),shade=c(134,105,109),dark=c(69,55,59)}
local body=Image{fromFile=out..'/layers/elf-04.png'}
-- Retain wrist and forearm; replace the open fingertips with a closed grip.
for y=40,43 do for x=80,85 do body:drawPixel(x,y,0)end end
body:saveAs(out..'/layers/elf-offhand-body.png')
local blade=Image(128,96,ColorMode.RGB)
local hilt=Image(128,96,ColorMode.RGB)
local hand=Image(128,96,ColorMode.RGB)
local function uv(im,u,v,k)im:drawPixel(84+u,math.floor(40-.45*u+.5)+v,P[k])end
-- Same 26-pixel shortsword length and double-edged taper as the main hand.
for u=1,26 do
 local half=1.55*(1-math.max(0,(u-14)/12))
 local lo,hi=math.ceil(-half),math.floor(half)
 for v=lo,hi do uv(blade,u,v,v==lo and (u<17 and 'h'or's')or(v==0 and 'j'or(v<0 and 's'or'd')))end
end
for u=-8,-1 do uv(hilt,u,0,'r');uv(hilt,u,1,'q')end
for v=-3,3 do uv(hilt,0,v,v<0 and 's'or'd')end
uv(hilt,0,-3,'h');uv(hilt,-9,0,'s')
local function row(x,y,keys)for i,k in ipairs(keys)do hand:drawPixel(x+i-1,y,P[k])end end
row(79,40,{'skin','skin','shade'})
row(79,41,{'skin','shade','skin','shade'})
row(79,42,{'shade','dark','skin','shade'})
row(80,43,{'dark','shade','dark'})
-- The hand and wrist are shared by every offhand item, never baked into it.
hand:saveAs(out..'/layers/elf-offhand-fingers.png')
local manifest={
 {id='elf-offhand-body',name='Elf body - offhand grip',race='Elf',group='Body',file='layers/elf-offhand-body.png',registered=true,order=4.01,issue=''},
 {id='elf-offhand-fingers',name='Closed offhand fingers',race='Elf',group='Offhand Grip',file='layers/elf-offhand-fingers.png',registered=true,order=310,issue=''}
}
local f=assert(io.open(out..'/weapons/manifest.json','r'));local source=json.decode(f:read('*a'));f:close()
local options={}
for _,w in ipairs(source)do if w.race=='Elf'then options[#options+1]={key=w.id:sub(12),name=w.name,source=w.file:gsub('%.png$','-isolated.png'),x=48,y=47}end end
options[#options+1]={key='longsword',name='Longsword',source='layers/elf-38.png',x=48,y=47}
local review=Image(128*3,96*3,ColorMode.RGB);review:clear(c(53,56,62))
for index,w in ipairs(options)do
 local weapon=Image(128,96,ColorMode.RGB)
 if w.key=='shortsword'then weapon:drawImage(blade,Point(0,0));weapon:drawImage(hilt,Point(0,0))
 else
  local src=Image{fromFile=out..'/'..w.source}
  -- Re-register isolated source pixels around the same offhand attachment.
  -- Inverse nearest-neighbor mapping avoids holes and keeps binary alpha.
  local angle=-36*math.pi/180;local cs,sn=math.cos(angle),math.sin(angle)
  for y=0,95 do for x=0,127 do
   local xx,yy=x-81,y-42
   local sx=math.floor(w.x+cs*xx+sn*yy+.5)
   local sy=math.floor(w.y-sn*xx+cs*yy+.5)
   if sx>=0 and sx<128 and sy>=0 and sy<96 then weapon:drawPixel(x,y,src:getPixel(sx,sy))end
  end end
 end
 local id='elf-offhand-'..w.key
 local s=Sprite(128,96,ColorMode.RGB);s.layers[1].name='Weapon - shared offhand anchor 81,42';s:newCel(s.layers[1],1,weapon,Point(0,0))
 s:saveAs(out..'/weapons/'..id..'.aseprite');weapon:saveAs(out..'/weapons/'..id..'.png');s:close()
 local reopened=app.open(out..'/weapons/'..id..'.aseprite');local check=Image(reopened.spec);check:drawSprite(reopened,1)
 for y=0,95 do for x=0,127 do assert(check:getPixel(x,y)==weapon:getPixel(x,y));local a=pc.rgbaA(weapon:getPixel(x,y));assert(a==0 or a==255)end end
 reopened:close()
 manifest[#manifest+1]={id=id,name=w.name:gsub(' %(new%)','')..' - off hand',race='Elf',group='Offhand Weapons',file='weapons/'..id..'.png',registered=true,order=290+index,issue='',master='weapons/'..id..'.aseprite',frame=1,grip={81,42},sourceLayer=w.source}
 local preview=Image{fromFile=out..'/previews/elara-wardrobe.png'}
 for y=40,43 do for x=80,85 do preview:drawPixel(x,y,0)end end
 preview:drawImage(Image{fromFile=out..'/weapons/elf-weapon-rapier.png'},Point(0,0));preview:drawImage(weapon,Point(0,0));preview:drawImage(hand,Point(0,0))
 preview:saveAs(out..'/weapons/'..id..'-dual.png')
 review:drawImage(preview,Point(((index-1)%3)*128,math.floor((index-1)/3)*96))
 if w.key=='shortsword'then
  local p=Sprite(128,96,ColorMode.RGB);p:newCel(p.layers[1],1,preview,Point(0,0));app.sprite=p
  app.command.SpriteSize{width=768,height=576,method='nearest'};p:saveAs(out..'/weapons/elara-dual-wield-6x.png');p:close()
 end
end
f=assert(io.open(out..'/weapons/offhand.json','w'));f:write(json.encode(manifest));f:close()
local p=Sprite(review.width,review.height,ColorMode.RGB);p:newCel(p.layers[1],1,review,Point(0,0));app.sprite=p
app.command.SpriteSize{width=review.width*3,height=review.height*3,method='nearest'};p:saveAs(out..'/weapons/elf-offhand-options-3x.png');p:close()
print('PASS: nine modular offhand weapons, one shared hand and wrist; masters match exports.')
