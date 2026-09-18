-- Flatten a generated Bram construction reference onto Zenith's 151x217 card grid.
-- Usage: Aseprite --batch --script-param src=<png> --script-param out=<folder> --script <this file>
local srcPath=app.params.src; local out=app.params.out; assert(srcPath and out)
local src=Image{fromFile=srcPath}; local W,H=151,217; local pc=app.pixelColor
local hex={'17191d','252326','332b2a','473936','60473b','7a5948','986e55','b88a69','d1a47b','e3bd92','343638','55585a','777975','9c9b92','c4bdad','dfd5c2','542c2b','8e342c','bd4c2d','de7134','ee9b42','f5c16c'}
local C={}; local pal=Palette(#hex)
for i,h in ipairs(hex) do local r,g,b=tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16); C[i]={r,g,b,pc.rgba(r,g,b,255)}; pal:setColor(i-1,Color{r=r,g=g,b=b,a=255}) end
local function nearest(r,g,b) local bi,bd=1,math.huge; for i,c in ipairs(C) do local d=(r-c[1])^2+(g-c[2])^2+(b-c[3])^2; if d<bd then bi,bd=i,d end end; return bi end
local a={}
for y=0,H-1 do a[y]={}; for x=0,W-1 do
 local x0=math.floor(x*src.width/W); local x1=math.min(src.width-1,math.floor((x+1)*src.width/W)-1); local y0=math.floor(y*src.height/H); local y1=math.min(src.height-1,math.floor((y+1)*src.height/H)-1)
 local sr,sg,sb,n=0,0,0,0
 for sy=y0,y1 do for sx=x0,x1 do local p=src:getPixel(sx,sy); local al=pc.rgbaA(p); if al>24 then sr=sr+pc.rgbaR(p); sg=sg+pc.rgbaG(p); sb=sb+pc.rgbaB(p); n=n+1 end end end
 if n==0 then a[y][x]=1 else a[y][x]=nearest(sr/n,sg/n,sb/n) end
end end
-- One conservative cleanup pass: only replace true isolated speckles.
for y=1,H-2 do for x=1,W-2 do local n={}; for dy=-1,1 do for dx=-1,1 do if dx~=0 or dy~=0 then local k=a[y+dy][x+dx]; n[k]=(n[k] or 0)+1 end end end; local best,count=a[y][x],0; for k,v in pairs(n) do if v>count then best,count=k,v end end; if count>=7 then a[y][x]=best end end end
local spr=Sprite(W,H,ColorMode.RGB); spr:setPalette(pal); local bg=Image(W,H,ColorMode.RGB); bg:clear(C[1][4]); spr.layers[1].name='01 Charcoal background'; spr:newCel(spr.layers[1],1,bg,Point(0,0)); local art=Image(W,H,ColorMode.RGB); for y=0,H-1 do for x=0,W-1 do art:drawPixel(x,y,C[a[y][x]][4]) end end; local l=spr:newLayer(); l.name='02 Flattened generated portrait'; spr:newCel(l,1,art,Point(0,0)); local cl=spr:newLayer(); cl.name='03 Aseprite cleanup'; spr:newCel(cl,1,Image(W,H,ColorMode.RGB),Point(0,0)); local stem=app.params.stem or 'bram-reference-flattened'; spr:saveAs(out..stem..'.aseprite'); art:saveAs(out..stem..'.png'); app.sprite=spr; app.command.SpriteSize{width=W*4,height=H*4,method='nearest'}; spr:saveAs(out..stem..'-preview-4x.png'); print('Flattened '..srcPath..' to '..out..stem)
