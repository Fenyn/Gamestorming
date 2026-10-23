using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>A short camera shake, and dust falling from the vault over a tile.</summary>
[GlobalClass]
public partial class QuakeCue : StageCue
{
    /// <summary>Largest camera shift, metres.</summary>
    [Export] public float Amplitude { get; set; } = 0.05f;

    [Export] public float Seconds { get; set; } = 0.4f;

    /// <summary>Board tile the dust falls over. Fractions move it within the tile.</summary>
    [Export] public Vector2 DustTile { get; set; }

    [Export] public bool Dust { get; set; } = true;

    public override Task Play(CutsceneSet set)
    {
        set.Camera.Shake(Amplitude, Seconds);
        if (Dust) set.DropDust(DustTile);
        return Task.CompletedTask;
    }
}
