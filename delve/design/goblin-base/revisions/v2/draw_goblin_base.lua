-- Run in Aseprite: --batch --script tools/draw_goblin_base.lua
-- Native pixel drawing only. Rebuild overwrites generated art; preserve manual edits first.
local root = app.params.root or 'G:/Godot/Gamestorming/delve'
local out = root .. '/design/goblin-base'
app.fs.makeAllDirectories(out)
local s = Sprite(56,48,ColorMode.RGB)
local initial = s.layers[1]
local colors = {
  o='252d29', d='3e4d38', s='596c45', m='7b8c58', l='a4ad70',
  p='80655a', q='ae8874', b='493f3b', c='726052', h='95806a',
  e='d6ba7c', r='a95340', t='e6d9b5',
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
pixels('01 Far leg',29,31,{
  'dssss','dsssms','ddssms','.dssms','.dssms','.dsss',
  '..dsss','..dsss','...dss','...dss','...dssm','...dssmmm','...odddddd',
})
pixels('02 Far arm',31,20,{
  'dss','dssms','dssms','.dssm','.dssm','.dssm','..dss',
  '..dss','..dss','..dssm','..dssmm','..dsssm','...ddd',
})
pixels('03 Near leg',23,31,{
  'ssmmms','smmmms','smmmms','ssmmms','dsmmls','dsmms',
  'dsmms','dsmm','dsmm','dsmm','.smm','.smlmmm','.odsssss',
})
pixels('04 Torso',22,17,{
  '.....ssmms','.....ssmms','...ssmmmms','..smmllmmms',
  '.ssmmlmmmms','.ssmmmmmmms','..ssmmmsss','..ssmmmmss',
  '..ssmmmms','..ssmmmms','..ssmmmms','..ssmmmmss',
  '..ssmmmmmss','..ssmmmmmss','..ssmmmssss','...sssss',
})
pixels('05 Plain loincloth - removable',24,29,{
  'hhhhccccb','ccccccccb','.cchccbb','.cchccbb','.cccccbb','..ccbbb',
})
pixels('06 Head',23,5,{
  '.....mmmmmm','...mmllllllm','..smmmllllmmm',
  '.ssmmmmmmmmmm','.ssmmmmmmmmmmm','.ssmmmmmmmmmmm',
  '.dssmmmmmmmssm','..ssmmmmmmssmmm','..ssmmmmmmmmmllmm',
  '...smmmmmmmmmmmms','...ssmmmmmmmmss','....ssmmmmmssss',
  '.....ssmmmmms','......dssss',
})
pixels('07 Near pointed ear',17,7,{
  'lm','sllmm','smlmmmm','dsmpqmmm','dspppqmmms',
  '.dsppqmms','..dsppms','...dssms','....dss',
})
pixels('08 Face - eye brow mouth tooth',32,9,{
  'sssss','.oeo','.ooo','....m','......d','....ss',
  '.soooos','..t.mm',
})
pixels('09 Near arm and bare hand',18,20,{
  '....smm','...smllm','...smlmm','...smmms','...smms',
  '..dsmm','..dsmm','.dsmm','.smmm','dsmlm',
  'dsmm','smml','smmms','ssmms','.ddd',
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
sheet:newCel(before,1,Image{fromFile=out..'/revisions/v1/goblin-base.png'},Point(2,4))
local after=sheet:newLayer(); after.name='Revised proportions'
sheet:newCel(after,1,flat,Point(62,4))
app.sprite=sheet
app.command.SpriteSize{width=960,height=448,method='nearest'}
sheet:saveAs(out..'/proportions-comparison.png')
print('Goblin: 56x48, 10 layers, one base pose; master and PNG exported.')
