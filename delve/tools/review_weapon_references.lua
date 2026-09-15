local out='G:/Godot/Gamestorming/delve/design/race-identities'
local refs={'human-33','human-30','human-31','human-29','dwarf-47','dwarf-48'}
for _,id in ipairs(refs)do
 local src=Image{fromFile=out..'/layers/'..id..'.png'}
 local im=Image(104,40,ColorMode.RGB);im:clear(app.pixelColor.rgba(53,56,62,255))
 im:drawImage(src,Point(-4,-34))
 local s=Sprite(104,40,ColorMode.RGB);s:newCel(s.layers[1],1,im,Point(0,0));app.sprite=s
 app.command.SpriteSize{width=104*10,height=40*10,method='nearest'}
 s:saveAs(out..'/weapons/reference-'..id..'-10x.png');s:close()
end
