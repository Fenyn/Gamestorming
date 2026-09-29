using Godot;

namespace Delve.Combat;

/// <summary>
/// Tilt-shift depth of field: keeps the look scene's blur band on <see cref="FocusPoint"/>. At the
/// rig's pitch and narrow field of view, screen height maps closely to depth, so a near and a far
/// blur around the focus depth soften the top and bottom of the frame. The band widens with the
/// camera distance so both teams stay sharp in a planning view, and the overview turns blur off.
/// The blur amount and transitions are authored on the look scene's CameraAttributesPractical; the
/// rig only moves the two distances.
/// </summary>
public partial class OrbitCameraRig
{
    /// <summary>Smallest distance, metres, between the focus depth and either blur edge.</summary>
    [Export] public float DofNearOffset { get; set; } = 1.5f;

    [Export] public float DofFarOffset { get; set; } = 1.5f;

    /// <summary>Blur edge distance as a fraction of the focus depth, when that is wider than the offsets.</summary>
    [Export] public float DofDepthFraction { get; set; } = 0.14f;

    /// <summary>Seconds the focus depth takes to follow a new focus point.</summary>
    [Export] public float DofFollowSeconds { get; set; } = 0.35f;

    /// <summary>Distance pushed to both blur edges while blur is off; past any camera range.</summary>
    [Export] public float DofOffDistance { get; set; } = 10000f;

    private float _dofDepth = -1f;

    private void UpdateDof(double delta)
    {
        if (!_camera.Current) return;
        if (GetViewport().FindWorld3D()?.CameraAttributes is not CameraAttributesPractical attributes) return;

        if (InOverview)
        {
            attributes.DofBlurNearDistance = 0f;
            attributes.DofBlurFarDistance = DofOffDistance;
            return;
        }

        float depth = (FocusPoint - _camera.GlobalPosition).Dot(-_camera.GlobalBasis.Z);
        _dofDepth = _dofDepth < 0f || DofFollowSeconds <= 0f
            ? depth
            : Mathf.Lerp(_dofDepth, depth, Mathf.Min(1f, (float)delta / DofFollowSeconds));
        float band = DofDepthFraction * _dofDepth;
        attributes.DofBlurNearDistance = Mathf.Max(0.1f, _dofDepth - Mathf.Max(DofNearOffset, band));
        attributes.DofBlurFarDistance = _dofDepth + Mathf.Max(DofFarOffset, band);
    }
}
