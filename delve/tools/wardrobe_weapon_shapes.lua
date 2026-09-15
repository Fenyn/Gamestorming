-- Pixel construction for the refined wardrobe weapons. Existing artist-made
-- hilt/shaft clusters are retained; new heads use the same material ramps.
return function(out, spec, race)
 local pc=app.pixelColor
 local function rgb(h)return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255)end
 local P={o=rgb('1e1714'),d=rgb('212b28'),s=rgb('767c97'),h=rgb('a9c0e1'),e=rgb('92a9cb'),
  b=rgb('97887a'),v=rgb('5b543f'),w=rgb('5f4233'),m=rgb('452f23'),l=rgb('6c4937'),
  r=rgb('86483d'),q=rgb('45242c'),a=rgb('40413a'),f=rgb('625d68'),j=rgb('8388a0')}
 local ims={};for i=1,4 do ims[i]=Image(128,96,ColorMode.RGB)end
 local dx,dy=race.x-47,race.y-49
 local function put(i,x,y,k)
  x,y=x+dx,y+dy;assert(x>=0 and x<128 and y>=0 and y<96,'Clipped weapon')
  ims[i]:drawPixel(x,y,type(k)=='string' and (P[k] or 0) or k)
 end
 local function row(i,x,y,str)for j=1,#str do local k=str:sub(j,j);if k~='.'then put(i,x+j-1,y,k)end end end
 local function line(i,k,x1,y1,x2,y2)
  local n=math.max(math.abs(x2-x1),math.abs(y2-y1))
  for j=0,n do local t=n==0 and 0 or j/n;put(i,math.floor(x1+(x2-x1)*t+.5),math.floor(y1+(y2-y1)*t+.5),k)end
 end
 local cache={}
 local function copy(id,i,x1,y1,x2,y2,ox,oy)
  if not cache[id]then cache[id]=Image{fromFile=out..'/layers/'..id..'.png'}end
  local src=cache[id]
  for y=y1,y2 do for x=x1,x2 do local c=src:getPixel(x,y);if pc.rgbaA(c)>0 then put(i,x+(ox or 0),y+(oy or 0),c)end end end
 end
 -- All heads are drawn around one continuous shaft axis. Screen-space
 -- pixel rows previously introduced bends where separately authored parts met.
 local function uv(i,u,v,k)
  put(i,50+u,math.floor(50+.22*u+.5)+v,k)
 end
 local function hilt(length,guard)
  for u=-length,-6 do uv(1,u,0,'r');uv(1,u,1,'q')end
  uv(3,-length-1,0,'s');uv(3,-length-1,1,'d')
  for v=-guard,guard do uv(3,0,v,v<0 and 's' or 'd')end
  uv(3,0,-guard,'h')
 end
 local function haft(length)
  for u=-13,length do
   if u< -5 or u> -2 then
    uv(1,u,0,u%11<4 and 'l' or 'w');uv(1,u,1,'m')
   end
  end
 end
 local function straightBlade(length,width,shoulder)
  for u=1,length do
   local t=math.max(0,(u-shoulder)/(length-shoulder))
   local half=width*(1-t)
   local lo,hi=math.ceil(-half),math.floor(half)
   for v=lo,hi do
    -- Upper bevel, central ridge, dark lower face; one centered point.
    local color=v<0 and 's' or 'd'
    if v==lo then color=u<length*.65 and 'h' or 's'
    elseif v==0 then color='j' end
    uv(2,u,v,color)
   end
  end
 end
 if spec.id=='rapier'then
  hilt(12,4);straightBlade(42,1.25,10)
  -- Swept knuckle bow joins the pommel-side grip and crossguard.
  for u=-10,-2 do uv(3,u,3+math.floor((u+10)/8),'s')end
  uv(3,-11,2,'d');uv(3,-1,3,'d');uv(3,0,2,'s')
 elseif spec.id=='shortsword'then
  hilt(10,3);straightBlade(26,1.55,14)
 elseif spec.id=='dagger'then
  hilt(8,2);straightBlade(14,1.9,3)
 elseif spec.id=='scimitar'then
  hilt(11,3)
  -- Gradual curvature over the full blade; the point follows that curve.
  -- Thickness tapers on the last third, with no hooked terminal segment.
  for u=1,36 do
   local center=50+.30*u-11*(u/36)^2
   local half=(1.65+.4*math.sin(math.pi*u/36))*math.min(1,(37-u)/10)
   local lo=math.ceil(center-half);local hi=math.floor(center+half)
   if hi<lo then hi=lo end
   for v=lo,hi do
    local color=v==lo and 'd' or 's'
    if v==hi then color=u<10 and 's' or (u<27 and 'h' or 'e') end
    put(2,50+u,v,color)
   end
  end
 elseif spec.id=='mace'then
  haft(15)
  -- Flanges run along the shaft, broad in the middle and necked at ends.
  for u=13,24 do
   local half=(u<16 or u>21)and 2 or 4
   for v=-half,half do
    local color='a'
    -- Three raised ribs: short bevel catches, deep channels, dark far end.
    if v==-half then color=u<20 and 'j' or 'f'
    elseif v==-3 then color=u<19 and 's' or 'f'
    elseif v==-2 or v==1 then color='d'
    elseif v==-1 then color=u<19 and 'h' or 's'
    elseif v==0 then color='f'
    elseif v==2 then color=u<20 and 'j' or 'f'
    elseif v==half then color='d' end
    if u==13 or u==24 then color=v<0 and 's' or 'a'
    elseif u==23 then color=v<0 and 'f' or 'd' end
    uv(2,u,v,color)
   end
  end
  for v=-1,1 do uv(3,12,v,v<0 and 's' or 'd');uv(3,25,v,'a')end
 elseif spec.id=='battleaxe'then
  haft(23)
  -- Socket and squared poll across the haft; blade widens away from it.
  for u=19,23 do for v=-4,2 do uv(2,u,v,v==-4 and 's' or 'a')end end
  for v=2,11 do
   local left=19-math.floor((v-2)*.55)
   local right=23+math.floor((v-2)*.35)
   for u=left,right do
    local color=v>8 and 's' or 'a'
    if v==11 then color='h' elseif u==left then color='d' end
    uv(2,u,v,color)
   end
  end
  -- Shallow convex cutting edge, perpendicular to the direction of the haft.
  for u=17,24 do uv(2,u,12,u<22 and 'e' or 's')end
  uv(3,21,0,'w');uv(3,22,0,'m')
 elseif spec.id=='warhammer'then
  haft(20)
  -- Compact cross-head: a square striking face and an opposing tapered pick.
  for v=-3,6 do for u=17,21 do uv(2,u,v,u==17 and 'd' or 'a')end end
  for v=4,7 do for u=16,22 do uv(2,u,v,v==4 and 'j' or (v==7 and 's' or 'f'))end end
  for v=-7,-4 do
   local half=math.max(0,math.floor((v+7)/2))
   for u=19-half,19+half do uv(2,u,v,u==19-half and 's' or 'd')end
  end
  uv(3,19,0,'w');uv(3,20,0,'m')
 elseif spec.id=='staff'then
  -- Straight, substantial hardwood with continuous grain and fitted ferrules.
  -- Short runs of lighter wood follow the source spear's material clusters.
  for x=15,80 do
   if x<45 or x>48 then
    local y=math.floor(40+(x-7)*.215)
    put(1,x,y,(x%17<7)and'l'or'w');put(1,x,y+1,'w');put(1,x,y+2,'m')
   end
  end
  row(2,13,41,'ssj');row(2,13,42,'djs');row(2,13,43,'das');row(2,14,44,'da');
  row(2,79,55,'sjs');row(2,79,56,'ajs');row(2,79,57,'das');row(2,80,58,'dd');
 end
 -- The source weapons intentionally leave a narrow gap for the gripping
 -- fingers. Restore only hand pixels in that gap, independently per race.
 local body=Image{fromFile=out..'/layers/'..race.body..'.png'}
 for y=race.y-3,race.y+3 do for x=race.x-2,race.x+2 do
  local c=body:getPixel(x,y);if pc.rgbaA(c)>0 then ims[4]:drawPixel(x,y,c)end
 end end
 return ims
end
