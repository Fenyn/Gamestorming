using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>Brightens the set's sigil (Encounter 4) toward its awake glow.</summary>
[GlobalClass]
public partial class SigilCue : StageCue
{
    /// <summary>0 keeps the glow, 1 is fully awake.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float Strength { get; set; } = 1f;

    [Export] public float Seconds { get; set; } = 3f;

    public override Task Play(CutsceneSet set)
    {
        set.Sigil?.Awaken(Strength, Seconds);
        return Task.CompletedTask;
    }
}
