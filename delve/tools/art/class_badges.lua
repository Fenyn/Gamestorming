-- Original pixel shapes authored and exported through Aseprite. No rasterized vectors.
-- Aseprite --batch --script-param root=<delve> --script tools/art/class_badges.lua
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/assets/ui/classes'
local review=root..'/design/class-badges'
app.fs.makeAllDirectories(out..'/symbols')
app.fs.makeAllDirectories(review)
local pc=app.pixelColor
local function color(hex) return pc.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255) end
local P={dark=color('100f16'),face=color('27212e'),rim=color('746078'),rimHi=color('b49b79'),rimLo=color('443649'),
    ink=color('dbc394'),light=color('f7e8bd'),shade=color('ad895c'),bg=color('16141d'),card=color('221e2a'),text=color('eee0c4'),muted=color('ac9bb2')}
local mask
local function dot(x,y,v) if x>=0 and y>=0 and x<24 and y<24 then mask[y*24+x]=v~=false end end
local function rect(x,y,w,h,v) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(xx,yy,v) end end end
local function line(x,y,xx,yy,w,v)
    local dx,dy=math.abs(xx-x),-math.abs(yy-y)
    local sx,sy=x<xx and 1 or -1,y<yy and 1 or -1
    local err=dx+dy
    while true do
        rect(x,y,w or 2,w or 2,v)
        if x==xx and y==yy then break end
        local e=2*err
        if e>=dy then err=err+dy;x=x+sx end
        if e<=dx then err=err+dx;y=y+sy end
    end
end
local function poly(points,v)
    for y=0,23 do for x=0,23 do
        local inside=false
        local j=#points
        for i=1,#points do
            local a,b=points[i],points[j]
            if (a[2]>y+.5)~=(b[2]>y+.5) and x+.5<(b[1]-a[1])*(y+.5-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
            j=i
        end
        if inside then dot(x,y,v) end
    end end
end
local function diamond(x,y,r,v) poly({{x,y-r},{x+r,y},{x,y+r},{x-r,y}},v) end
local entries={
 {'fighter','Fighter','Upright sword / martial mastery',function()
    poly({{12,1},{15,5},{14,15},{10,15},{9,5}});rect(5,14,14,3);rect(10,17,4,3);rect(9,21,6,2)
 end},
 {'rogue','Rogue','Hood / hidden blade',function()
    poly({{12,1},{19,7},{22,17},{17,19},{16,9},{12,6},{8,9},{7,19},{2,17},{5,7}})
    poly({{12,10},{14,13},{13,19},{16,19},{16,21},{13,21},{13,23},{11,23},{11,21},{8,21},{8,19},{11,19},{10,13}})
 end},
 {'cleric','Cleric','Radiant sun / divine conduit',function()
    diamond(12,12,6);rect(11,1,2,4);rect(11,19,2,4);rect(1,11,4,2);rect(19,11,4,2)
    line(3,3,5,5);line(18,18,20,20);line(3,19,5,17);line(18,4,20,2)
 end},
 {'wizard','Wizard','Open grimoire / learned magic',function()
    poly({{2,8},{7,7},{11,10},{11,21},{6,18},{2,19}})
    poly({{13,10},{17,7},{22,8},{22,19},{18,18},{13,21}})
    rect(4,10,3,1,false);rect(4,13,4,1,false);rect(17,10,3,1,false);rect(16,13,4,1,false)
    diamond(12,3,3)
 end},
 {'barbarian','Barbarian','Riven axe / untamed force',function()
    rect(10,3,4,20)
    poly({{8,2},{8,7},{3,5},{1,9},{3,15},{8,13},{8,17},{10,14},{10,5}})
    poly({{16,2},{16,7},{21,5},{23,9},{21,15},{16,13},{16,17},{14,14},{14,5}})
    rect(11,7,1,3,false);rect(12,10,1,4,false)
 end},
 {'champion','Champion','Crowned shield / sworn protection',function()
    poly({{3,7},{21,7},{20,16},{17,20},{12,23},{7,20},{4,16}})
    poly({{6,10},{18,10},{17,15},{15,18},{12,20},{9,18},{7,15}},false)
    diamond(12,13,3);rect(5,2,2,3);rect(11,0,2,4);rect(17,2,2,3)
 end},
 {'witch','Witch','Moon and needle / woven hex',function()
    poly({{12,1},{6,3},{2,8},{2,15},{6,20},{12,22},{17,20},{11,19},{7,15},{6,10},{8,5}})
    line(19,4,12,18,2);diamond(19,3,3);diamond(19,3,1,false)
    line(15,15,19,16,1);line(19,16,20,20,1);line(20,20,17,22,1)
 end},
 {'monk','Monk','Bound fist / disciplined body',function()
    rect(4,6,3,8);rect(8,3,3,9);rect(12,2,3,10);rect(16,4,3,8)
    poly({{4,14},{15,14},{15,11},{19,9},{22,11},{20,16},{17,19},{7,19}})
    rect(7,20,10,3);rect(10,20,1,3,false);rect(14,20,1,3,false)
 end},
 {'ranger','Ranger','Trail arrow / tracking prey',function()
    poly({{12,1},{20,10},{14,8},{14,20},{10,20},{10,8},{4,10}})
    line(4,14,8,18,2);line(18,14,14,18,2)
    line(4,19,8,23,1);line(19,19,15,23,1)
 end},
 {'druid','Druid','Leaf and antlers / living world',function()
    poly({{12,3},{16,8},{16,12},{12,16},{8,12},{8,8}});rect(11,16,2,7)
    line(2,3,3,12,2);line(3,12,10,19,2);line(20,3,19,12,2);line(19,12,12,19,2)
    line(2,9,6,7,2);line(20,9,16,7,2);line(12,8,12,12,1,false)
 end},
 {'magus','Magus','Runeblade / spell and steel',function()
    poly({{20,1},{22,2},{20,7},{10,17},{7,14}})
    line(4,13,11,20,2);line(6,18,2,22,2)
    poly({{9,1},{3,8},{9,8},{7,13},{15,5},{9,5}})
 end},
 {'oracle','Oracle','Fractured eye / costly revelation',function()
    poly({{1,9},{6,4},{12,2},{18,4},{23,9},{18,14},{12,16},{6,14}})
    poly({{5,9},{8,6},{16,6},{19,9},{16,12},{8,12}},false);diamond(12,9,3)
    poly({{11,17},{15,17},{12,20},{15,20},{11,24},{12,21},{9,21}})
    line(4,17,2,20,2);line(19,17,21,20,2)
 end},
 {'thaumaturge','Thaumaturge','Charm ring / gathered mysteries',function()
    diamond(12,6,5);diamond(12,6,2,false)
    line(5,9,18,9,2);line(5,10,5,16,2);line(11,10,11,18,2);line(18,10,18,15,2)
    rect(3,16,6,5);rect(5,17,2,2,false);diamond(12,21,3)
    poly({{17,16},{21,16},{21,20},{19,23},{17,20}})
 end},
 {'bard','Bard','Lyre / the inspiring voice',function()
    poly({{2,2},{7,4},{6,7},{5,7},{5,15},{8,19},{16,19},{19,15},{19,7},{18,7},{17,4},{22,2},{22,15},{19,20},{16,22},{8,22},{5,20},{2,15}})
    rect(7,7,10,2);rect(8,8,2,9);rect(14,8,2,9)
 end},
 {'psychic','Psychic','Mind crystal / outward thought',function()
    diamond(12,12,5);diamond(12,12,2,false)
    line(5,5,2,8,2);rect(2,8,2,8);line(2,16,5,19,2)
    line(17,5,20,8,2);rect(20,8,2,8);line(20,16,17,19,2)
    rect(11,1,2,3);rect(11,21,2,3)
 end},
 {'swashbuckler','Swashbuckler','Sweeping rapier / daring finesse',function()
    line(20,2,7,15,2);line(6,17,2,21,2)
    line(5,12,11,18,2);line(11,18,8,21,1);line(8,21,4,20,1)
    line(2,8,5,4,1);line(5,4,12,2,1);line(15,21,20,17,1);line(20,17,22,11,1)
 end},
 {'summoner','Summoner','Linked seals / two lives bound',function()
    poly({{7,2},{15,10},{7,18},{0,10}});poly({{7,6},{11,10},{7,14},{3,10}},false)
    poly({{16,6},{24,14},{16,22},{8,14}});poly({{16,10},{20,14},{16,18},{12,14}},false)
    line(9,10,14,15,2)
 end},
 {'sorcerer','Sorcerer','Blood spark / inborn magic',function()
    poly({{12,0},{14,7},{18,5},{22,12},{21,18},{17,22},{8,22},{3,18},{2,12},{7,5},{7,11},{10,8}})
    poly({{12,9},{17,16},{16,19},{12,21},{8,18},{8,15}},false)
    diamond(12,17,2)
 end},
}
local function layer(s,name,im) local l=s:newLayer();l.name=name;s:newCel(l,1,im,Point(0,0));return l end
local function flattened(s) local im=Image(s.spec);im:drawSprite(s,1);return im end
local function scaleInto(dst,src,x,y,factor)
    for yy=0,src.height-1 do for xx=0,src.width-1 do
        local c=src:getPixel(xx,yy)
        if pc.rgbaA(c)>0 then for dy=0,factor-1 do for dx=0,factor-1 do dst:drawPixel(x+xx*factor+dx,y+yy*factor+dy,c) end end end
    end end
end
local glyphs={
 A={'01110','10001','10001','11111','10001','10001','10001'},B={'11110','10001','10001','11110','10001','10001','11110'},
 C={'01111','10000','10000','10000','10000','10000','01111'},D={'11110','10001','10001','10001','10001','10001','11110'},
 E={'11111','10000','10000','11110','10000','10000','11111'},F={'11111','10000','10000','11110','10000','10000','10000'},
 G={'01111','10000','10000','10111','10001','10001','01111'},H={'10001','10001','10001','11111','10001','10001','10001'},
 I={'111','010','010','010','010','010','111'},J={'00111','00010','00010','00010','10010','10010','01100'},
 K={'10001','10010','10100','11000','10100','10010','10001'},L={'10000','10000','10000','10000','10000','10000','11111'},
 M={'10001','11011','10101','10101','10001','10001','10001'},N={'10001','11001','10101','10011','10001','10001','10001'},
 O={'01110','10001','10001','10001','10001','10001','01110'},P={'11110','10001','10001','11110','10000','10000','10000'},
 Q={'01110','10001','10001','10001','10101','10010','01101'},R={'11110','10001','10001','11110','10100','10010','10001'},
 S={'01111','10000','10000','01110','00001','00001','11110'},T={'11111','00100','00100','00100','00100','00100','00100'},
 U={'10001','10001','10001','10001','10001','10001','01110'},V={'10001','10001','10001','10001','10001','01010','00100'},
 W={'10001','10001','10001','10101','10101','10101','01010'},X={'10001','10001','01010','00100','01010','10001','10001'},
 Y={'10001','10001','01010','00100','00100','00100','00100'},Z={'11111','00001','00010','00100','01000','10000','11111'},
 ['0']={'01110','10001','10011','10101','11001','10001','01110'},['1']={'010','110','010','010','010','010','111'},
 ['2']={'01110','10001','00001','00010','00100','01000','11111'},['3']={'11110','00001','00001','01110','00001','00001','11110'},
 ['4']={'10010','10010','10010','11111','00010','00010','00010'},['8']={'01110','10001','10001','01110','10001','10001','01110'},
 ['/']={'00001','00001','00010','00100','01000','10000','10000'},['-']={'000','000','000','111','000','000','000'},
}
local function text(im,str,x,y,k,c)
    for ch in str:upper():gmatch('.') do
        local g=glyphs[ch]
        if g then
            for yy,row in ipairs(g) do for xx=1,#row do if row:sub(xx,xx)=='1' then
                for a=0,k-1 do for b=0,k-1 do im:drawPixel(x+(xx-1)*k+a,y+(yy-1)*k+b,c) end end
            end end end
            x=x+(#g[1]+1)*k
        else x=x+4*k end
    end
end
local sheet=Sprite(1200,680,ColorMode.RGB)
sheet.layers[1].name='Review background'
sheet.cels[1].image:clear(P.bg)
local panels=Image(1200,680,ColorMode.RGB)
local labels=Image(1200,680,ColorMode.RGB)
text(labels,'DELVE / CLASS SIGILS',20,17,3,P.text)
text(labels,'18 CLASSES / 32PX BADGES / 24PX SYMBOLS / ASEPRITE PIXEL ART',20,49,1,P.muted)
local manifest={}
for index,e in ipairs(entries) do
    mask={};e[4]()
    local symbol=Image(24,24,ColorMode.RGB)
    local solid=Image(24,24,ColorMode.RGB)
    local shape=Image(32,32,ColorMode.RGB)
    local shadow=Image(32,32,ColorMode.RGB)
    local highlights=Image(32,32,ColorMode.RGB)
    local base=Image(32,32,ColorMode.RGB)
    local rim=Image(32,32,ColorMode.RGB)
    for y=0,31 do for x=0,31 do
        local d=math.min(x,y,31-x,31-y)
        local corner=math.min(x+y,31-x+y,x+31-y,62-x-y)
        if d>=1 and corner>=6 then base:drawPixel(x,y,P.face) end
        if d>=1 and corner>=6 and (d==1 or corner==6) then rim:drawPixel(x,y,y<16 and P.rimHi or P.rim) end
        if d>=2 and corner>=8 and (d==2 or corner==8) then rim:drawPixel(x,y,P.rimLo) end
    end end
    local count=0
    for y=0,23 do for x=0,23 do if mask[y*24+x] then
        count=count+1
        symbol:drawPixel(x,y,P.ink);solid:drawPixel(x,y,P.text)
        shape:drawPixel(x+4,y+4,P.ink)
        shadow:drawPixel(x+4,y+5,P.dark)
        if not mask[(y-1)*24+x] then highlights:drawPixel(x+4,y+4,P.light)
        elseif not mask[(y+1)*24+x] then highlights:drawPixel(x+4,y+4,P.shade) end
    end end end
    assert(count>25,e[1]..' is empty')
    local s=Sprite(32,32,ColorMode.RGB)
    s.layers[1].name='Enamel base';s:newCel(s.layers[1],1,base)
    layer(s,'Shared octagonal rim',rim)
    layer(s,'Symbol cast shadow',shadow)
    layer(s,e[2]..' symbol',shape)
    layer(s,'Symbol edge light',highlights)
    s:saveAs(out..'/'..e[1]..'.aseprite')
    local flat=flattened(s);flat:saveAs(out..'/'..e[1]..'.png')
    solid:saveAs(out..'/symbols/'..e[1]..'.png')
    s:close()
    local reopened=app.open(out..'/'..e[1]..'.aseprite')
    local check=flattened(reopened)
    for y=0,31 do for x=0,31 do
        assert(check:getPixel(x,y)==flat:getPixel(x,y),e[1]..' export differs')
        local a=pc.rgbaA(check:getPixel(x,y));assert(a==0 or a==255,'Soft alpha')
    end end
    reopened:close()
    local cx=18+((index-1)%6)*194;local cy=72+math.floor((index-1)/6)*190
    for y=cy,cy+181 do for x=cx,cx+185 do panels:drawPixel(x,y,P.card) end end
    local art=Image(1200,680,ColorMode.RGB)
    scaleInto(art,flat,cx+9,cy+10,3)
    scaleInto(art,solid,cx+123,cy+15,2)
    scaleInto(art,flat,cx+131,cy+78,1)
    layer(sheet,e[2]..' previews',art)
    text(labels,e[2],cx+10,cy+121,2,P.text)
    text(labels,e[3]:match('^(.-) /'),cx+10,cy+147,1,P.muted)
    text(labels,'3X / SYMBOL 2X / NATIVE',cx+10,cy+164,1,P.muted)
    manifest[#manifest+1]={id=e[1],name=e[2],motif=e[3],badge='../../assets/ui/classes/'..e[1]..'.png',symbol='../../assets/ui/classes/symbols/'..e[1]..'.png',source='../../assets/ui/classes/'..e[1]..'.aseprite'}
end
-- Insert the panel layer above the background but behind all badge layers.
local p=layer(sheet,'Review cards',panels);p.stackIndex=2
layer(sheet,'Class names and size legend',labels)
text(labels,'SHAPE IDENTIFIES CLASS / COLOUR REMAINS AVAILABLE FOR CHARACTER AND TEAM',20,654,1,P.muted)
-- newCel takes an image copy; update labels after the footer is drawn.
sheet.cels[#sheet.cels].image=labels
sheet:saveAs(review..'/class-badges.aseprite')
flattened(sheet):saveAs(review..'/class-badges.png')
sheet:close()
local f=assert(io.open(review..'/manifest.json','w'));f:write(json.encode(manifest));f:close()
print('PASS: 18 layered Aseprite badges; 18 matching PNGs; binary alpha; 18 monochrome symbols; editable review sheet.')
