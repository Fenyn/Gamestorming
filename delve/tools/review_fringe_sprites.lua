-- Same native pixel scale and ground line across both rows. No source art is modified.
local root = app.params.root or 'G:/Godot/Gamestorming/delve'
local out = root .. '/design/fringe-sprite-review/'
local rgba = app.pixelColor.rgba
local sources = {
  {'Giant Rat', 'assets/sprites/enemies/rat_v1/idle_1.png'},
  {'Goblin', 'design/goblin-base/goblin-base.png'},
  {'Kobold', 'design/kobold-base/kobold-base.png'},
  {'Wolf', 'design/wolf-base/wolf-base.png'},
  {'Viper', 'design/viper-base/viper-base.png'},
  {'Spider', 'design/spider-base/spider-base.png'},
  {'Boar', 'design/boar-base/boar-base.png'},
  {'Giant Viper', 'design/giant-viper-base/giant-viper-base.png'},
  {'Giant Monitor Lizard', 'design/giant-monitor-lizard-base/giant-monitor-lizard-base.png'},
  {'Dire Wolf', 'design/dire-wolf-base/dire-wolf-base.png'},
  {'Grizzly Bear', 'design/grizzly-bear-base/grizzly-bear-base.png'},
  {'Giant Stag Beetle', 'design/giant-stag-beetle-base/giant-stag-beetle-base.png'},
}
local board = Image(700, 180, ColorMode.RGB)
local silhouettes = Image(700, 180, ColorMode.RGB)
board:clear(rgba(53,56,62,255))
silhouettes:clear(rgba(53,56,62,255))
local records = {}
for i, source in ipairs(sources) do
  local im = Image{fromFile=root .. '/' .. source[2]}
  local minx,miny,maxx,maxy = im.width,im.height,-1,-1
  local colors = {}
  for y=0,im.height-1 do for x=0,im.width-1 do
    local p = im:getPixel(x,y)
    local a = app.pixelColor.rgbaA(p)
    assert(a==0 or a==255, source[1] .. ': partial alpha')
    if a==255 then
      minx=math.min(minx,x); miny=math.min(miny,y)
      maxx=math.max(maxx,x); maxy=math.max(maxy,y)
      colors[p]=true
    end
  end end
  local column = i<=7 and i-1 or i-8
  local cellWidth = i<=7 and 100 or 140
  local ground = i<=7 and 76 or 165
  local dx = column*cellWidth + math.floor((cellWidth-(maxx-minx+1))/2)-minx
  local dy = ground-maxy
  board:drawImage(im,Point(dx,dy))
  for y=0,im.height-1 do for x=0,im.width-1 do
    if app.pixelColor.rgbaA(im:getPixel(x,y))==255 then
      silhouettes:drawPixel(x+dx,y+dy,rgba(224,218,199,255))
    end
  end end
  local count=0; for _ in pairs(colors) do count=count+1 end
  table.insert(records, {name=source[1],canvas={im.width,im.height},
    bounds={minx,miny,maxx+1,maxy+1},opaque_colors=count})
end
local function save(im,path,scale)
  local sprite=Sprite(im.width,im.height,ColorMode.RGB)
  sprite:newCel(sprite.layers[1],1,im,Point(0,0))
  app.sprite=sprite
  if scale>1 then app.command.SpriteSize{width=im.width*scale,height=im.height*scale,method='nearest'} end
  sprite:saveAs(path)
  sprite:close()
end
save(board,out..'fringe-lineup-native.png',1)
save(board,out..'fringe-lineup-4x.png',4)
save(silhouettes,out..'fringe-silhouettes-4x.png',4)
local file=assert(io.open(out..'native-metrics.json','w'))
file:write(json.encode(records));file:close()
print('Fringe review: twelve species, same native pixel scale, aligned ground contacts.')
