using Ungilded.Data;
using Godot;

namespace Ungilded.Combat;

/// <summary>
/// A logical facing in grid space (x along world X, y along world Z) as a camera sees it, and the
/// Mana Seed facing row that draws it. Shared by every billboard that picks a row from a facing.
/// </summary>
public static class CameraFacing
{
    /// <summary>X = screen right, Y = into the screen (away from the viewer).</summary>
    public static Vector2 OnScreen(Vector2 facing, Camera3D? camera)
    {
        Vector3 right = Vector3.Right, forward = Vector3.Forward;
        if (camera != null)
        {
            var basis = camera.GlobalBasis;
            forward = -basis.Z; forward.Y = 0f; forward = forward.LengthSquared() > 0.0001f ? forward.Normalized() : Vector3.Forward;
            right = basis.X; right.Y = 0f; right = right.LengthSquared() > 0.0001f ? right.Normalized() : Vector3.Right;
        }
        var ground = new Vector3(facing.X, 0f, facing.Y);
        if (ground.LengthSquared() < 0.0001f) ground = Vector3.Right;
        ground = ground.Normalized();
        return new Vector2(ground.Dot(right), ground.Dot(forward));
    }

    /// <summary>4-direction snap on the dominant screen axis: S = toward viewer, N = away, E = screen
    /// right, W = screen left (<see cref="ManaSeedSheet"/> facing rows).</summary>
    public static int Row(Vector2 facing, Camera3D? camera)
    {
        var screen = OnScreen(facing, camera);
        return Mathf.Abs(screen.X) >= Mathf.Abs(screen.Y)
            ? (screen.X >= 0f ? ManaSeedSheet.RowEast : ManaSeedSheet.RowWest)
            : (screen.Y >= 0f ? ManaSeedSheet.RowNorth : ManaSeedSheet.RowSouth);
    }
}
