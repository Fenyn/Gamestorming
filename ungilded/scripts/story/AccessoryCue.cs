using Godot;

namespace Ungilded.Story;

/// <summary>Where an accessory is. One speaker at a time carries or wears it.</summary>
public enum AccessoryState
{
    /// <summary>Put away: no portrait overlay, no glow.</summary>
    Hidden,
    /// <summary>In the speaker's satchel or hand: a glow at hip height, no portrait overlay.</summary>
    Carried,
    /// <summary>On the speaker's face: the portrait overlay and a glow at eye height.</summary>
    Worn,
}

/// <summary>Moves an accessory to a speaker, or puts it away, as a <see cref="DialogueLine"/> starts.</summary>
[GlobalClass]
public partial class AccessoryCue : Resource
{
    /// <summary>Matches <see cref="SpeakerPortraits.Speaker"/>. The line itself may be narration.</summary>
    [Export] public string Speaker { get; set; } = "";

    /// <summary>A key of <see cref="SpeakerPortraits.Accessories"/>.</summary>
    [Export] public StringName Accessory { get; set; } = "";

    [Export] public AccessoryState State { get; set; } = AccessoryState.Worn;
}

/// <summary>The height of an accessory's glow above its carrier's feet.</summary>
public static class AccessoryGlow
{
    /// <summary>Metres above the feet for <paramref name="state"/>: <paramref name="carriedHeight"/>
    /// when carried, <paramref name="eyeShare"/> of <paramref name="bodyHeight"/> when worn, and
    /// <paramref name="current"/> when hidden, so a fading glow stays where it was.</summary>
    public static float Height(AccessoryState state, float bodyHeight, float carriedHeight, float eyeShare, float current) =>
        state switch
        {
            AccessoryState.Worn => bodyHeight * eyeShare,
            AccessoryState.Carried => carriedHeight,
            _ => current,
        };

    /// <summary>Metres toward the face side for <paramref name="state"/>: <paramref name="sideShare"/>
    /// of <paramref name="bodyHeight"/> when worn, else 0.</summary>
    public static float Side(AccessoryState state, float bodyHeight, float sideShare) =>
        state == AccessoryState.Worn ? bodyHeight * sideShare : 0f;

    /// <summary>The offset, in <paramref name="carrier"/>'s space, that moves a glow
    /// <paramref name="side"/> metres along the camera's right toward the side a billboard sprite
    /// faces. The hero art faces right, so a flipped sprite faces left.</summary>
    public static Vector3 Beside(Node3D carrier, bool flipped, float side)
    {
        if (side == 0f || carrier.GetViewport()?.GetCamera3D() is not { } camera) return Vector3.Zero;
        var right = camera.GlobalBasis.X with { Y = 0f };
        if (right.IsZeroApprox()) return Vector3.Zero;
        return carrier.GlobalBasis.Inverse() * (right.Normalized() * (flipped ? -side : side));
    }
}
