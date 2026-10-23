using System.Threading.Tasks;
using Godot;
using Godot.Collections;

namespace Ungilded.Story.Cutscene;

/// <summary>
/// Moves the set camera to a shot: it orbits a look-at point at <see cref="Yaw"/>,
/// <see cref="Pitch"/> and <see cref="Distance"/>. Yaw 0 puts the camera south of the point
/// (+y), 90 east (+x). The point is the mean of <see cref="Actors"/> where they stop, or
/// <see cref="Tile"/> when the list is empty, raised by <see cref="Height"/>.
/// </summary>
[GlobalClass]
public partial class ShotCue : StageCue
{
    [Export] public Array<StringName> Actors { get; set; } = new();

    /// <summary>Board tile to look at when <see cref="Actors"/> is empty. Fractions move the point
    /// within the tile; (2, 3) is the centre of tile (2, 3).</summary>
    [Export] public Vector2 Tile { get; set; }

    /// <summary>Metres above the floor the camera looks at.</summary>
    [Export] public float Height { get; set; } = 0.6f;

    [Export(PropertyHint.Range, "-360,360,1")] public float Yaw { get; set; } = 30f;

    [Export(PropertyHint.Range, "0,89,1")] public float Pitch { get; set; } = 25f;

    [Export] public float Distance { get; set; } = 12f;

    [Export(PropertyHint.Range, "5,90,1")] public float Fov { get; set; } = 26f;

    /// <summary>Camera shift in its own plane, metres. A negative y lowers the camera, so the subject
    /// sits higher in the frame, clear of the dialogue box.</summary>
    [Export] public Vector2 Shift { get; set; }

    /// <summary>Blend time from the shot before. Zero cuts.</summary>
    [Export] public float Seconds { get; set; } = 1.5f;

    [Export] public Tween.TransitionType Transition { get; set; } = Tween.TransitionType.Sine;

    [Export] public Tween.EaseType Ease { get; set; } = Tween.EaseType.InOut;

    public override Task Play(CutsceneSet set) => set.Camera.Blend(ShotOn(set), Seconds, Transition, Ease);

    /// <summary>The shot this cue frames on <paramref name="set"/>.</summary>
    public CameraShot ShotOn(CutsceneSet set)
    {
        var target = Actors.Count > 0 ? set.ActorsCentre(Actors) : set.TileToWorld(Tile);
        return new CameraShot(target + Vector3.Up * Height, Yaw, Pitch, Distance, Fov, Shift);
    }
}
