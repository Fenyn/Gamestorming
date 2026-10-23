using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>Blends the set's colour grade toward a tint multiplied over the view, or back to neutral.</summary>
[GlobalClass]
public partial class GradeCue : StageCue
{
    /// <summary>Multiplied over the view: a channel below 1 is taken down. White is neutral.</summary>
    [Export] public Color Tint { get; set; } = Colors.White;

    [Export] public float Seconds { get; set; } = 2f;

    public override Task Play(CutsceneSet set)
    {
        set.BlendGrade(Tint, Seconds);
        return Task.CompletedTask;
    }
}
