-- Refine one class at a time through Aseprite's native one-pixel Pencil tool.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local id=app.params.class or 'fighter'
local defs=dofile(root..'/tools/art/class_sigil_refinements.lua')
local d=assert(defs[id],'No individually authored refinement for '..id)
local oldDefs=dofile(root..'/tools/art/class_sigil_pixels.lua')
local old
for _,entry in ipairs(oldDefs) do if entry.id==id then old=entry end end
assert(old)
local text=dofile(root..'/tools/art/pixel_review_font.lua')
local out=root..'/design/class-badges/pencil/refinements/'..id
app.fs.makeAllDirectories(out)
local pc=app.pixelColor
local function col(r,g,b) return Color{r=r,g=g,b=b,a=255} end
local function rgba(c) return pc.rgba(c.red,c.green,c.blue,255) end
local chalk=col(244,239,233)
local palettes={
 original={['#']=chalk,['+']=col(197,182,200)},
 mono={['#']=chalk,s=chalk,g=chalk},
 colour={['#']=col(219,230,232),s=col(105,136,157),g=col(218,170,91)},
}
if d.colours then
    for key,c in pairs(d.colours) do palettes.colour[key]=col(c[1],c[2],c[3]);palettes.mono[key]=chalk end
end
local function flat(s) local im=Image(s.spec);im:drawSprite(s,1);return im end
local function build(pattern,palette,path)
    local rows={};for row in pattern:gmatch('[^\r\n]+') do rows[#rows+1]=row end
    local w=#rows[1];local h=#rows
    assert(w<=24 and h<=24)
    local ox=math.floor((24-w)/2);local oy=math.floor((24-h)/2)
    local s=Sprite(24,24,ColorMode.RGB);app.activeSprite=s
    local layers={}
    local names={['#']='Steel edges',s='Blue steel plates',g='Brass brow and ridge',['+']='Secondary motif'}
    for _,key in ipairs({'#','s','g','+','b'}) do if palette[key] then
        local l=next(layers)==nil and s.layers[1] or s:newLayer();l.name=(d.layerNames or names)[key];layers[key]=l
    end end
    local count=0
    app.transaction('Refine '..d.name..' with Pencil',function()
        for y,row in ipairs(rows) do
            assert(#row==w,'Unequal pattern width at row '..y)
            for x=1,w do local key=row:sub(x,x);if key~='.' then
                app.activeLayer=assert(layers[key])
                app.useTool{tool='pencil',brush=Brush(1),color=assert(palette[key]),points={Point(ox+x-1,oy+y-1)},ink='simple',opacity=255}
                count=count+1
            end end
        end
    end)
    local im=flat(s)
    if path then s:saveAs(path..'.aseprite');im:saveAs(path..'.png') end
    s:close()
    if path then
        local saved=app.open(path..'.aseprite');local check=flat(saved);local actual=0
        for y=0,23 do for x=0,23 do
            assert(check:getPixel(x,y)==im:getPixel(x,y),'Export mismatch')
            local a=pc.rgbaA(check:getPixel(x,y));assert(a==0 or a==255)
            if a>0 then actual=actual+1 end
        end end
        assert(actual==count,'Pencil count mismatch');saved:close()
    end
    return im,count
end
local original=build(old.pixels,palettes.original,nil)
local mono,count=build(d.monoPixels or d.pixels,palettes.mono,out..'/'..id..'-mono')
local coloured,colourCount=build(d.pixels,palettes.colour,out..'/'..id..'-colour')
local function previous(name)
    local old=app.open(out..'/'..(d.previous or 'pass01')..'/'..id..'-'..name..'.aseprite')
    local im=flat(old);old:close();return im
end
local comparisons
if app.fs.isFile(out..'/'..(d.previous or 'pass01')..'/'..id..'-mono.aseprite') then
    comparisons={{previous('mono'),'PREVIOUS MONO'},{mono,'REVISED MONO'},
        {previous('colour'),'PREVIOUS COLOUR'},{coloured,'REVISED COLOUR'}}
else
    comparisons={{original,'ORIGINAL'},{mono,'REFINED MONO'},{coloured,'COLOUR'}}
end
local width=#comparisons*250+24
local s=Sprite(width,486,ColorMode.RGB);app.activeSprite=s
local bg=rgba(col(20,15,24));local panel=rgba(col(33,25,37));local muted=rgba(col(197,182,200))
s.layers[1].name='Review background';s.cels[1].image:clear(bg)
local function layer(name,im) app.activeSprite=s;local l=s:newLayer();l.name=name;s:newCel(l,1,im,Point(0,0)) end
local function zoom(dst,src,x,y,k)
    for yy=0,src.height-1 do for xx=0,src.width-1 do local c=src:getPixel(xx,yy)
        if pc.rgbaA(c)>0 then for dy=0,k-1 do for dx=0,k-1 do dst:drawPixel(x+k*xx+dx,y+k*yy+dy,c) end end end
    end end
end
local labels=Image(width,486,ColorMode.RGB)
text(labels,d.name..' / CLEANUP '..(d.revision or '02'),20,20,3,rgba(chalk))
text(labels,d.subtitle or 'OPEN CROWN / CLEAN VISOR / CONTINUOUS CHEEK PLATES',20,54,1,muted)

for i,item in ipairs(comparisons) do
    local x=16+(i-1)*250
    local art=Image(width,486,ColorMode.RGB)
    for yy=82,430 do for xx=x,x+241 do art:drawPixel(xx,yy,panel) end end
    zoom(art,item[1],x+37,100,7)
    zoom(art,item[1],x+51,324,2)
    zoom(art,item[1],x+161,336,1)
    layer(item[2]..' comparison',art)
    text(labels,item[2],x+12,282,2,rgba(chalk))
    text(labels,'2X',x+65,388,1,muted)
    text(labels,'NATIVE 24PX',x+139,388,1,muted)
end
text(labels,'MONOCHROME HAS ITS OWN PIXEL PATTERN / BOTH VERSIONS ARE 24PX',20,455,1,muted)
layer('Labels',labels)
s:saveAs(out..'/review.aseprite');flat(s):saveAs(out..'/review.png');s:close()
local f=assert(io.open(out..'/verification.txt','w'))
f:write('PASS: '..d.name..' monochrome '..count..' and colour '..colourCount..' explicit Pencil pixels.\n')
f:write('PASS: both layered masters match PNGs; binary alpha and authored pixel counts verified.\n')
f:close()
