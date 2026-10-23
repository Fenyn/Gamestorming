using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>Lights or puts out the glow an actor carries, at a height above its feet.</summary>
[GlobalClass]
public partial class GlowCue : StageCue
{
    [Export] public StringName Actor { get; set; } = "";

    [Export] public bool On { get; set; } = true;

    /// <summary>Metres above the actor's feet: about 0.5 for a satchel, 1.2 for the face.</summary>
    [Export] public float Height { get; set; } = 0.5f;

    public override Task Play(CutsceneSet set)
    {
        set.Actor(Actor).SetGlow(On, Height);
        return Task.CompletedTask;
    }
}
