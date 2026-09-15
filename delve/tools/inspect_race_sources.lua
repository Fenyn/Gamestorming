local root='F:/UnityNVME/Art/_P2eGame/Sprites'
local out='G:/Godot/Gamestorming/delve/design/race-identities'
local files={'Human/Human_Design.aseprite','Human/Human_Character.aseprite','Human/Human_Character_First.aseprite','Human/Human_Character_Second.aseprite','Elf/Elf_Design.aseprite','Dwarf/Dwarf_Design.aseprite','Orc/Orc_Design.aseprite'}
local function layers(list,indent)
 for _,l in ipairs(list) do
  print(indent..l.name..' visible='..tostring(l.isVisible)..' group='..tostring(l.isGroup)..' cels='..#l.cels)
  if l.isGroup then layers(l.layers,indent..'  ') end
 end
end
for i,path in ipairs(files) do
 local s=app.open(root..'/'..path)
 print('\nSOURCE '..path..' '..s.width..'x'..s.height..' frames='..#s.frames)
 layers(s.layers,' ')
 local im=Image(s.spec); im:drawSprite(s,1); im:saveAs(out..'/source-'..i..'.png')
 s:close()
end
