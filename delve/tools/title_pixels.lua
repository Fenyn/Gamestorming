-- Shared Aseprite helpers for title artwork. No external image libraries.
local M = {}
local pc = app.pixelColor
function M.rgba(hex, alpha)
  return pc.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),alpha or 255)
end
function M.image(w,h) return Image(w or 640,h or 360,ColorMode.RGB) end
function M.load(path,w,h)
  local s=app.open(path)
  local im=Image(s.cels[1].image)
  if w then im:resize{width=w,height=h,method='nearest-neighbor'} end
  s:close()
  return im
end
function M.rect(im,x,y,w,h,c)
  for yy=math.max(0,y),math.min(im.height-1,y+h-1) do
    for xx=math.max(0,x),math.min(im.width-1,x+w-1) do im:drawPixel(xx,yy,c) end
  end
end
function M.poly(im,p,c)
  local lo,hi=im.height,0
  for _,v in ipairs(p) do lo=math.min(lo,v[2]); hi=math.max(hi,v[2]) end
  for y=math.max(0,lo),math.min(im.height-1,hi) do
    local cuts={}
    for i,a in ipairs(p) do
      local b=p[i%#p+1]
      if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then
        cuts[#cuts+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
      end
    end
    table.sort(cuts)
    for i=1,#cuts-1,2 do M.rect(im,math.ceil(cuts[i]),y,math.floor(cuts[i+1])-math.ceil(cuts[i])+1,1,c) end
  end
end
function M.line(im,x0,y0,x1,y1,c)
  local dx,dy=math.abs(x1-x0),-math.abs(y1-y0)
  local sx,sy=x0<x1 and 1 or -1,y0<y1 and 1 or -1
  local err=dx+dy
  while true do
    if x0>=0 and x0<im.width and y0>=0 and y0<im.height then im:drawPixel(x0,y0,c) end
    if x0==x1 and y0==y1 then break end
    local e=2*err
    if e>=dy then err=err+dy; x0=x0+sx end
    if e<=dx then err=err+dx; y0=y0+sy end
  end
end
-- Curated material ramps. Small shared palette replaces thousands of near-colors.
M.environment={
 '10151f','192333','23364a','2e465b','3a566e','486983','5c7e96','7895a8',
 '293654','34456a','425780','536996','687dac','827da3','a88cab','c998aa',
 'dba09f','e8b096','293236','374346','4a5250','62655c','7c7a68','99907a',
 '313040','454052','5a5263','706477','89778a','273735','334b42','456052',
 '5c7560','102928','193b37','294b43','3b5c4b','303c28','4a5030','64653a',
 '808149','a09b5b','342a2c','4c3735','68493b','845b42','a6754d','c49460',
 'dbad71','efd094','fff0bf','744949','985b51','b87662','233b51','385572',
 '4e7590','7099ad','493b51','66506c','8a6889','b490a5','b29779','d1b393'
}
M.people={
 '161b24','29313b','42464b','666765','929083','c2bdaa','ece0c2',
 '302a28','4f3b2c','715039','99704b','bf9567','dfb486','f0d0a1',
 '502f2e','78453b','a4614a','c4825d','3c3041','604357','865e77','b18b9e',
 '1d3437','305052','477072','75918a','24354b','3b536e','587896','839cae'
}
function M.quantize(im,colors)
  local pal={}
  for _,h in ipairs(colors) do
    local c=M.rgba(h)
    pal[#pal+1]={c,pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)}
  end
  local cache={}
  for it in im:pixels() do
    local c=it()
    if pc.rgbaA(c)<128 then it(0)
    else
      local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
      local key=(r//4)*4096+(g//4)*64+b//4
      local best=cache[key]
      if not best then
        local distance=math.huge
        for _,p in ipairs(pal) do
          local d=2*(r-p[2])^2+3*(g-p[3])^2+(b-p[4])^2
          if d<distance then distance=d; best=p[1] end
        end
        cache[key]=best
      end
      it(best)
    end
  end
end
-- Remove weak isolated interior flecks, preserving transparency and silhouettes.
function M.depeckle(im,passes,clusterPass)
  local count=0
  for _=1,passes do
    local source=Image(im)
    for y=1,im.height-2 do for x=1,im.width-2 do
      local c=source:getPixel(x,y)
      if pc.rgbaA(c)>0 then
        local histogram,matching,opaque={},0,true
        for dy=-1,1 do for dx=-1,1 do
          if dx~=0 or dy~=0 then
            local n=source:getPixel(x+dx,y+dy)
            if pc.rgbaA(n)==0 then opaque=false end
            if n==c then matching=matching+1 end
            histogram[n]=(histogram[n] or 0)+1
          end
        end end
        if opaque and matching<=(clusterPass and 2 or 0) then
          local best,amount=c,0
          for n,k in pairs(histogram) do if k>amount or (k==amount and n<best) then best,amount=n,k end end
          local dr=pc.rgbaR(c)-pc.rgbaR(best)
          local dg=pc.rgbaG(c)-pc.rgbaG(best)
          local db=pc.rgbaB(c)-pc.rgbaB(best)
          if amount>=(clusterPass and 4 or 3) and dr*dr+dg*dg+db*db<(clusterPass and 16000 or 8000) and best~=c then
            im:drawPixel(x,y,best); count=count+1
          end
        end
      end
    end end
  end
  return count
end
function M.mask(p)
  local im=M.image(); M.poly(im,p,M.rgba('ffffff')); return im
end
function M.contains(mask,x,y)
  return x>=0 and y>=0 and x<mask.width and y<mask.height and pc.rgbaA(mask:getPixel(x,y))>0
end
function M.extract(im,mask)
  local out=M.image(im.width,im.height)
  for y=0,im.height-1 do for x=0,im.width-1 do
    if M.contains(mask,x,y) then out:drawPixel(x,y,im:getPixel(x,y)) end
  end end
  return out
end
function M.layer(s,name,im,x,y)
  local l=s:newLayer(); l.name=name
  s:newCel(l,1,im,Point(x or 0,y or 0)); return l
end
return M
