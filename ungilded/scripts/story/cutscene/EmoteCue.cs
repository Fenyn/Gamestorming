using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>Pops an emote bubble above an actor's head, holds it, then fades it.</summary>
[GlobalClass]
public partial class EmoteCue : StageCue
{
    [Export] public StringName Actor { get; set; } = "";

    [Export] public Emote Emote { get; set; }

    /// <summary>Seconds the bubble holds after it pops in.</summary>
    [Export] public float Hold { get; set; } = 1.6f;

    public override Task Play(CutsceneSet set)
    {
        set.Actor(Actor).ShowEmote(Emote, Hold);
        return Task.CompletedTask;
    }
}
