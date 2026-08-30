using System.Collections.Generic;
using Delve.Props;
using Godot;

namespace Delve.Terrain;

/// <summary>
/// The HD-2D occluder pass: every frame the camera moves, each tracked tree is tested against the
/// battlefield's bounding box, and a tree standing between the camera and the box fades to a ghost
/// (<see cref="TreeProp.SetOccluding"/>) so the fight stays readable from any pitch. The test is a
/// ray from the camera through the tree's canopy: if that ray goes on to pass through a meaningful
/// depth of battlefield volume, the tree is in the way; a tree past the far edge, or off to the
/// side, never fades.
///
/// Owned per build by <see cref="TerrainStage"/>, which hands it the board box and every spawned
/// tree. Does nothing until configured.
/// </summary>
public partial class TreeFader : Node
{
    /// <summary>World depth of battlefield the ray must still cross behind the tree before the tree
    /// counts as occluding. Keeps far-edge trees solid: nothing readable stands behind them.</summary>
    private const float ClearDepth = 3f;

    /// <summary>Fractions of a tree's height the test rays are aimed through. Three points because
    /// the camera regime decides which part of the tree covers the fight: from a high orbit it is
    /// the mid canopy (a trunk ray dives under the board), and from the pitch floor it is the
    /// UPPER canopy of a tall tree in front of a low eye — a mid ray from there plunges below the
    /// board floor before it can enter the box. Any ray hitting fades the tree.</summary>
    private static readonly float[] TestPoints = { 0.15f, 0.5f, 0.85f };

    private readonly List<TreeProp> _trees = new();
    private Aabb _board;
    private bool _configured;
    private Transform3D _lastCamera;
    private bool _dirty = true;

    /// <summary>Set the battlefield box (world space) and forget any previously tracked trees.</summary>
    public void Configure(Aabb board)
    {
        _board = board;
        _trees.Clear();
        _configured = true;
        _dirty = true;
    }

    /// <summary>Add one tree to the pass.</summary>
    public void Track(TreeProp tree)
    {
        _trees.Add(tree);
        _dirty = true;
    }

    public override void _Process(double delta)
    {
        if (!_configured || _trees.Count == 0) return;
        var camera = GetViewport()?.GetCamera3D();
        if (camera == null) return;
        if (!_dirty && camera.GlobalTransform == _lastCamera) return;

        Vector3 eye = camera.GlobalPosition;
        foreach (var tree in _trees)
            tree.SetOccluding(Occludes(eye, tree));

        _lastCamera = camera.GlobalTransform;
        _dirty = false;
    }

    /// <summary>True when a ray from <paramref name="eye"/> through one of the tree's test points
    /// crosses at least <see cref="ClearDepth"/> of battlefield volume BEYOND the tree.</summary>
    private bool Occludes(Vector3 eye, TreeProp tree)
    {
        foreach (float point in TestPoints)
            if (OccludesThrough(eye, tree.GlobalPosition + Vector3.Up * (tree.Height * point)))
                return true;
        return false;
    }

    private bool OccludesThrough(Vector3 eye, Vector3 target)
    {
        Vector3 delta = target - eye;
        float distance = delta.Length();
        if (distance < 0.001f) return false;
        Vector3 dir = delta / distance;

        // Slab ray/AABB intersection: [enter, exit] along the ray, in world units from the eye.
        float enter = float.MinValue, exit = float.MaxValue;
        for (int axis = 0; axis < 3; axis++)
        {
            float origin = eye[axis], d = dir[axis];
            float lo = _board.Position[axis], hi = lo + _board.Size[axis];
            if (Mathf.Abs(d) < 1e-6f)
            {
                if (origin < lo || origin > hi) return false;
                continue;
            }
            float t0 = (lo - origin) / d, t1 = (hi - origin) / d;
            if (t0 > t1) (t0, t1) = (t1, t0);
            enter = Mathf.Max(enter, t0);
            exit = Mathf.Min(exit, t1);
            if (enter > exit) return false;
        }

        // The box must lie ahead of the eye, and the tree must sit at least ClearDepth of
        // battlefield short of where the ray leaves it.
        return exit > 0f && exit - distance > ClearDepth;
    }
}
