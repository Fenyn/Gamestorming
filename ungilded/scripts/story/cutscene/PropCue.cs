using System.Threading.Tasks;
using Godot;
using Ungilded.Props;

namespace Ungilded.Story.Cutscene;

/// <summary>Puts a prop on the floor of the set under an id (flat or standing, as its sprite says), or
/// takes the prop with that id away.</summary>
[GlobalClass]
public partial class PropCue : StageCue
{
    [Export] public StringName Id { get; set; } = "";

    /// <summary>True lays the prop, false takes it away.</summary>
    [Export] public bool Show { get; set; } = true;

    /// <summary>The art to put down.</summary>
    [Export] public DecorSprite? Sprite { get; set; }

    /// <summary>Board tile of the prop's centre; (2, 3) is the centre of tile (2, 3), fractions move
    /// it within the tile.</summary>
    [Export] public Vector2 Tile { get; set; }

    /// <summary>Quarter turns, so the pixels stay on the board grid.</summary>
    [Export(PropertyHint.Range, "0,3,1")] public int Turns { get; set; }

    public override Task Play(CutsceneSet set)
    {
        if (Show && Sprite != null) set.LayProp(Id, Sprite, Tile, Turns);
        else set.TakeProp(Id);
        return Task.CompletedTask;
    }
}
