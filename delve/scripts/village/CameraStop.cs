using Godot;

namespace Delve.Village;

/// <summary>
/// One framed view of the village: the camera looks at this marker from <see cref="Pitch"/> degrees
/// up at <see cref="Distance"/>, at the village's fixed yaw. Stops in <see cref="Order"/> order are
/// the ones Q / E step through; order -1 marks a stop only code moves to (the Delve line-up).
/// </summary>
public partial class CameraStop : Marker3D
{
    [Export] public string Id { get; set; } = "";
    [Export] public string Title { get; set; } = "";
    [Export] public float Pitch { get; set; } = 34f;
    [Export] public float Distance { get; set; } = 34.7f;
    [Export] public int Order { get; set; } = -1;

    /// <summary>Things nearer the camera than this, past the target, are hidden at this stop.</summary>
    [Export] public float OccludeDepth { get; set; } = 9.5f;

    /// <summary>Trees fade earlier than props: a tree near the frame's bottom edge shows only its flattest facets.</summary>
    [Export] public float TreeOccludeDepth { get; set; } = 6f;

    [Export] public float OccludeHalfWidth { get; set; } = 20f;
}
