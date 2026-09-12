-- Run in Aseprite: --batch --script tools/draw_goblin_base.lua
-- Native pixel drawing only. Rebuild overwrites generated art; preserve manual edits first.
local root = app.params.root or 'G:/Godot/Gamestorming/delve'
local out = root .. '/design/goblin-base'
app.fs.makeAllDirectories(out)
local s = Sprite(56,48,ColorMode.RGB)
local initial = s.layers[1]
local colors = {
  o='252e31', d='354b40', s='58744d', m='87a360', l='bdc780',
  p='795955', q='b4826c', b='493c3b', c='79594b', h='ac8160',
  e='e4b96e', r='a95340', t='e6d9b5',
}
local palette = Palette(14)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
local keys={'o','d','s','m','l','p','q','b','c','h','e','r','t'}
for i,k in ipairs(keys) do
  local hex=colors[k]
  colors[k]=Color{r=tonumber(hex:sub(1,2),16),g=tonumber(hex:sub(3,4),16),b=tonumber(hex:sub(5,6),16),a=255}
  palette:setColor(i,colors[k])
end
s:setPalette(palette)
local function pixels(name,x,y,rows)
  local layer=s:newLayer(); layer.name=name
  local im=Image(56,48,ColorMode.RGB)
  for yy,row in ipairs(rows) do
    for xx=1,#row do
      local c=colors[row:sub(xx,xx)]
      if c then im:drawPixel(x+xx-1,y+yy-1,c) end
    end
  end
  s:newCel(layer,1,im,Point(0,0))
  return layer
end
-- Orthographic right-facing construction. Far limbs remain behind the torso.
-- Head: y8-22. Shoulder: (25,24). Hip: (25,33). Feet: y43.
pixels('01 Far leg',27,32,{
  'dssss','dsssmm','ddssmm','.ddssm','..dssm','..dssm',
  '..dss','..dss','..dssm','..dssmmmm','..odsssss',
})
pixels('02 Far arm',29,22,{
  'dsss','dssms','dssms','odssm','.dssm...ss',
  '.dssm..smms','.dssmsssmms','..dssssmms','...dddddd',
})
pixels('03 Near leg',19,32,{
  '....smmmms','...smmmms','..smmmms','..smmls',
  '..smmls','..dsmms','...smms','...smms','...smmlm',
  '..smmlmmmm','..osssssss','...oooooo',
})
pixels('04 Torso',21,20,{
  '.....dssss','...ssmmmmm','..smmmmmmms','.smmlllmmmms',
  '.smmllmmmmms','ssmmmmmmmmms','ssmmmmmmmss','dssmmmmmmss',
  '.ssmmmmmss','.ssmmmmms','.ssmmmmms','.ssmmmmmss',
  '.dssmmmmss','..dssssss',
})
pixels('05 Plain loincloth - removable',22,31,{
  'chhhccccb','cccccccbb','ccchccbbb','.cchccbb','.ccccbb','..cbbb',
})
pixels('06 Head',22,8,{
  '......sssssss','....ssmmmmmmmss','...smmmllllmmmms',
  '..smmmllllllmmmms','..smmmllllmmmmmmss','..smmmmmmmmmmmmsss',
  '..smmmmmmmmmmmmmmmm','..ssmmmmmmmmmmlmmmms','...smmmmmmmmmmlmmmms',
  '...ssmmmmmmmmmmssss','....ssmmmmmssssss','.....ssmmmmmmmms',
  '......ssmmmmmms','.......dsssss','.......ddsss',
})
pixels('07 Near pointed ear',16,11,{
  'ss','smmss','dsmmmsss','dsmlmmmmss','.dsmpqqmmms',
  '..dsppqqmms','...dsppqmms','....dssmms','......sss',
})
pixels('08 Face - eye brow mouth tooth',32,13,{
  'ssssss','..oeeo','..ooo..m','......ms','.......o',
  '.sssoooo','...t.mms','.....ss',
})
pixels('09 Near arm and bare hand',21,23,{
  '..ssmm','..smlmm','..smlmms','..smmmms','..smmms',
  '..smmms....ss','..smmms...smmls','..smmmmmmsmllms',
  '...smmmlmmmmms','....ssssmmsss','......dddddd',
})
local gear=s:newLayer(); gear.name='10 Gear overlay - empty'
s:deleteLayer(initial)
s.frames[1].duration=0.15
local tag=s:newTag(1,1); tag.name='base_idle'
s:saveAs(out..'/goblin-base.aseprite')
local flat=Image(s.spec); flat:drawSprite(s,1)
flat:saveAs(out..'/goblin-base.png')
local preview=Sprite(56,48,ColorMode.RGB)
preview:newCel(preview.layers[1],1,flat,Point(0,0))
app.sprite=preview
app.command.SpriteSize{width=448,height=384,method='nearest'}
preview:saveAs(out..'/goblin-base-8x.png')
-- Compare silhouettes at the same pixel scale, on a neutral background.
local sheet=Sprite(120,56,ColorMode.RGB)
sheet.layers[1].name='Neutral background'
local bg=Image(120,56,ColorMode.RGB)
bg:clear(Color{r=48,g=49,b=54,a=255})
sheet:newCel(sheet.layers[1],1,bg,Point(0,0))
local before=sheet:newLayer(); before.name='Previous proportions'
sheet:newCel(before,1,Image{fromFile=out..'/revisions/v2/goblin-base.png'},Point(2,4))
local after=sheet:newLayer(); after.name='Revised proportions'
sheet:newCel(after,1,flat,Point(62,4))
app.sprite=sheet
app.command.SpriteSize{width=960,height=448,method='nearest'}
sheet:saveAs(out..'/proportions-comparison.png')
print('Goblin: 56x48, 10 layers, one base pose; master and PNG exported.')
