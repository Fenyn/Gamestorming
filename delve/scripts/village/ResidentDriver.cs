using Delve.Data;
using Godot;

namespace Delve.Village;

/// <summary>What a resident's figure shows this moment. Run is the hurried walk of a call to the line-up.</summary>
public enum ResidentPose { Stand, Walk, Run, Work, Sit, Rise, Settle }

/// <summary>One spot a resident owns: where it stands, which way it faces there, whether it sits, and
/// what work it is for (empty: none, only standing about).</summary>
public readonly record struct SpotPlace(Vector2 At, Vector2 Facing, bool Seated, string Use = "");

/// <summary>Decides where a figure is and what it shows; <see cref="ResidentFigure"/> draws it. The driver is
/// the figure's place in the <see cref="VillageCrowd"/>.</summary>
public interface IResidentDriver : ICrowdMember
{
    Vector2 Position { get; }
    Vector2 Facing { get; }
    ResidentPose Pose { get; }
    ManaSeedClip? Clip { get; }

    /// <summary>Goes up each time a clip starts again, so the figure restarts it from its first frame.</summary>
    int Cycle { get; }

    void Tick(float delta);
}
