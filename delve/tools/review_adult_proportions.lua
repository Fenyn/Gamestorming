local dir='G:/Godot/Gamestorming/delve/design/manaseed-identities/'
local board=Image(192,192,ColorMode.RGB)
for p in board:pixels() do p(app.pixelColor.rgba(52,63,70,255)) end
for i,name in ipairs({'aldric','elara','tharr','fenwick'}) do
 for j,face in ipairs({'south','east'}) do
  for pass,folder in ipairs({'before-adult-proportions/monster-style/','monster-style/'}) do
   local im=Image{fromFile=dir..folder..name..'-'..face..'.png'}
   board:drawImage(Image(im,Rectangle(8,0,48,48)),Point((i-1)*48,((j-1)*2+pass-1)*48))
  end
 end
end
board:resize(960,960);board:saveAs(dir..'monster-style/adult-proportions-before-after-5x.png')
