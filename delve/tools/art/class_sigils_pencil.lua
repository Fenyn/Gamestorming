-- Builds each class from an empty Aseprite canvas using the native Pencil tool.
-- Every pixel position is explicitly authored in class_sigil_pixels.lua.
local root=app.params.root or 'G:/Godot/Gamestorming/delve'
local out=root..'/design/class-badges/pencil'
app.fs.makeAllDirectories(out..'/icons')
app.fs.makeAllDirectories(out..'/monochrome')
local definitions=dofile(root..'/tools/art/class_sigil_pixels.lua')
local text=dofile(root..'/tools/art/pixel_review_font.lua')
local pc=app.pixelColor
local chalk=Color{r=244,g=239,b=233,a=255}
local ash=Color{r=197,g=182,b=200,a=255}
local function rgb(r,g,b) return pc.rgba(r,g,b,255) end
local C={bg=rgb(20,15,24),panel=rgb(33,25,37),grid=rgb(55,42,60),text=rgb(244,239,233),muted=rgb(197,182,200)}
local function flat(sprite) local im=Image(sprite.spec);im:drawSprite(sprite,1);return im end
local function layer(s,name,im) local l=s:newLayer();l.name=name;s:newCel(l,1,im,Point(0,0));return l end
local function enlarge(dst,src,x,y,k)
    for yy=0,src.height-1 do for xx=0,src.width-1 do
        local c=src:getPixel(xx,yy)
        if pc.rgbaA(c)>0 then for dy=0,k-1 do for dx=0,k-1 do dst:drawPixel(x+xx*k+dx,y+yy*k+dy,c) end end end
    end end
end
local sheet=Sprite(1200,716,ColorMode.RGB)
sheet.layers[1].name='Review background';sheet.cels[1].image:clear(C.bg)
local panels=Image(1200,716,ColorMode.RGB)
local labels=Image(1200,716,ColorMode.RGB)
text(labels,'DELVE / CLASS PIXEL SIGILS',20,16,3,C.text)
text(labels,'NATIVE ASEPRITE PENCIL / INDIVIDUALLY AUTHORED PIXEL PATTERNS',20,49,1,C.muted)
local assets={}
local total=0
for i,d in ipairs(definitions) do
    local s=Sprite(24,24,ColorMode.RGB)
    app.activeSprite=s
    s.layers[1].name=d.name..' / silhouette'
    local primary=s.layers[1]
    local accent=s:newLayer();accent.name=d.name..' / secondary motif'
    local rows={}
    for row in d.pixels:gmatch('[^\r\n]+') do rows[#rows+1]=row end
    assert(#rows==16,d.id..' height')
    local n=0
    app.transaction('Draw '..d.name..' pixel sigil',function()
        for y,row in ipairs(rows) do
            assert(#row==16,d.id..' width')
            for x=1,16 do
                local mark=row:sub(x,x)
                if mark~='.' then
                    assert(mark=='#' or mark=='+')
                    app.activeLayer=mark=='#' and primary or accent
                    app.useTool{tool='pencil',brush=Brush(1),color=mark=='#' and chalk or ash,
                        points={Point(x+3,y+3)},ink='simple',opacity=255}
                    n=n+1
                end
            end
        end
    end)
    total=total+n
    s:saveAs(out..'/icons/'..d.id..'.aseprite')
    local im=flat(s)
    im:saveAs(out..'/icons/'..d.id..'.png')
    local mono=Image(im)
    local visible=0
    for y=0,23 do for x=0,23 do
        local c=im:getPixel(x,y);local a=pc.rgbaA(c)
        assert(a==0 or a==255,d.id..' antialiased pixel')
        if a>0 then visible=visible+1;mono:drawPixel(x,y,C.text) end
    end end
    assert(visible==n,d.id..' pencil output does not match authored pixels')
    mono:saveAs(out..'/monochrome/'..d.id..'.png')
    s:close()
    local saved=app.open(out..'/icons/'..d.id..'.aseprite')
    assert(#saved.layers==2,d.id..' layer count')
    local reopened=flat(saved)
    for y=0,23 do for x=0,23 do assert(reopened:getPixel(x,y)==im:getPixel(x,y),d.id..' export mismatch') end end
    saved:close()
    local x=18+((i-1)%6)*194;local y=74+math.floor((i-1)/6)*198
    for yy=y,y+189 do for xx=x,x+185 do panels:drawPixel(xx,yy,C.panel) end end
    -- Six-times native pixels, with a grid only behind the large proof.
    for yy=y+7,y+102 do for xx=x+7,x+102 do
        if (xx-x-7)%6==0 or (yy-y-7)%6==0 then panels:drawPixel(xx,yy,C.grid) end
    end end
    local art=Image(1200,716,ColorMode.RGB)
    local cropped=Image(16,16,ColorMode.RGB)
    cropped:drawImage(im,Point(-4,-4))
    enlarge(art,cropped,x+7,y+7,6)
    enlarge(art,im,x+124,y+15,2)
    enlarge(art,mono,x+136,y+81,1)
    app.activeSprite=sheet
    layer(sheet,d.name..' / scale proofs',art)
    text(labels,d.name,x+8,y+120,2,C.text)
    text(labels,d.motif,x+8,y+146,1,C.muted)
    text(labels,'6X GRID / 2X / NATIVE',x+8,y+169,1,C.muted)
    assets[#assets+1]={id=d.id,name=d.name,motif=d.motif,source='icons/'..d.id..'.aseprite',png='icons/'..d.id..'.png',pencilPixels=n}
end
app.activeSprite=sheet
local panel=layer(sheet,'Review cards and pixel grids',panels);panel.stackIndex=2
text(labels,'24PX CANVAS / 16PX MOTIF / TWO FLAT COLOURS / TRANSPARENT BACKGROUND',20,689,1,C.muted)
layer(sheet,'Names and scale labels',labels)
sheet:saveAs(out..'/class-sigils.aseprite')
flat(sheet):saveAs(out..'/class-sigils.png')
sheet:close()
local f=assert(io.open(out..'/manifest.json','w'));f:write(json.encode(assets));f:close()
local report=assert(io.open(out..'/verification.txt','w'))
report:write('PASS: 18 classes constructed from blank sprites with '..total..' native Aseprite Pencil placements.\n')
report:write('PASS: two editable layers per class; saved masters match PNG exports pixel for pixel.\n')
report:write('PASS: binary alpha and exact authored pixel counts; no image inputs or rasterization.\n')
report:close()
