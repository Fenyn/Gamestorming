-- Assemble existing approved Aseprite masters without rebuilding any class.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/class-badges/pencil/refinements'
local order=dofile(root..'/tools/art/class_sigil_pixels.lua')
local defs=dofile(root..'/tools/art/class_sigil_refinements.lua')
local text=dofile(root..'/tools/art/pixel_review_font.lua')
local pc=app.pixelColor
local function rgb(r,g,b) return pc.rgba(r,g,b,255) end
local function flat(s) local im=Image(s.spec);im:drawSprite(s,1);return im end
local function read(path)
    local s=assert(app.open(path),path);local im=flat(s);s:close();return im
end
local width,height=1440,796
local sheet=Sprite(width,height,ColorMode.RGB)
sheet.layers[1].name='Background';sheet.cels[1].image:clear(rgb(20,15,24))
local labels=Image(width,height,ColorMode.RGB)
local chalk=rgb(244,239,233);local muted=rgb(197,182,200)
text(labels,'DELVE / REFINED CLASS SIGILS',20,18,3,chalk)
text(labels,'COLOUR 4X / MONO 3X / BOTH AT NATIVE 24PX',20,51,1,muted)
local function layer(name,im)
    app.activeSprite=sheet;local l=sheet:newLayer();l.name=name
    sheet:newCel(l,1,im,Point(0,0))
end
local function zoom(dst,src,x,y,k)
    for yy=0,23 do for xx=0,23 do local c=src:getPixel(xx,yy)
        if pc.rgbaA(c)>0 then
            for dy=0,k-1 do for dx=0,k-1 do dst:drawPixel(x+xx*k+dx,y+yy*k+dy,c) end end
        end
    end end
end
local manifest={}
for i,entry in ipairs(order) do
    local d=assert(defs[entry.id]);local path=out..'/'..entry.id..'/'..entry.id
    local variants={}
    for _,kind in ipairs({'colour','mono'}) do
        local im=read(path..'-'..kind..'.aseprite');local png=read(path..'-'..kind..'.png')
        assert(im.width==24 and im.height==24)
        for y=0,23 do for x=0,23 do
            local c=im:getPixel(x,y);assert(c==png:getPixel(x,y),entry.id..' export mismatch')
            local a=pc.rgbaA(c);assert(a==0 or a==255)
        end end
        variants[kind]=im
    end
    local x=16+((i-1)%6)*238;local y=80+math.floor((i-1)/6)*232
    local art=Image(width,height,ColorMode.RGB)
    for yy=y,y+219 do for xx=x,x+229 do art:drawPixel(xx,yy,rgb(33,25,37)) end end
    zoom(art,variants.colour,x+14,y+8,4);zoom(art,variants.mono,x+137,y+20,3)
    zoom(art,variants.colour,x+51,y+125,1);zoom(art,variants.mono,x+161,y+125,1)
    layer(d.name,art)
    text(labels,d.name,x+10,y+169,2,chalk)
    text(labels,d.motif,x+10,y+198,1,muted)
    manifest[#manifest+1]={id=entry.id,revision=d.revision,colour=entry.id..'/'..entry.id..'-colour.aseprite',mono=entry.id..'/'..entry.id..'-mono.aseprite'}
end
layer('Names and labels',labels)
sheet:saveAs(out..'/class-sigils-refined.aseprite')
flat(sheet):saveAs(out..'/class-sigils-refined.png');sheet:close()
local f=assert(io.open(out..'/manifest.json','w'));f:write(json.encode(manifest));f:close()
local f=assert(io.open(out..'/verification.txt','w'))
f:write('PASS: '..#order..' classes; 36 Aseprite masters match PNG exports at 24 by 24 with binary alpha.\n')
f:write('PASS: review assembled from existing masters; individual class files were not modified.\n');f:close()
