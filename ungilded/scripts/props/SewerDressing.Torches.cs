using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Ungilded.Props;

/// <summary>Torches mark the way: one beside each passage mouth and each culvert, and one every
/// <see cref="TorchSpacing"/> tiles along a long unbroken chamber wall.</summary>
public partial class SewerDressing
{
    /// <summary>Hang torches at all. Off leaves the boards to the key light and the lantern.</summary>
    [Export] public bool TorchesEnabled { get; set; } = true;

    /// <summary>Torch bracket height above the floor, metres.</summary>
    [Export] public float TorchHeight { get; set; } = 1.15f;

    /// <summary>Torches hang on faces looking onto floor at most this many rings out.</summary>
    [Export] public int TorchRings { get; set; } = 1;

    /// <summary>Tiles of unbroken wall along the board edge per torch, rounded to the nearest count.</summary>
    [Export] public int TorchSpacing { get; set; } = 6;

    /// <summary>A wall with no mouth needs at least this many tiles to carry a torch.</summary>
    [Export] public int TorchMinRun { get; set; } = 5;

    /// <summary>Two torches stand at least this many tiles apart, wherever they hang.</summary>
    [Export] public float TorchMinGap { get; set; } = 4f;

    /// <summary>The cutaway quadrant of the combat camera's opening view (yaw 45: the camera on the
    /// +x, +z side). A wall torch prefers a face this view shows.</summary>
    [Export(PropertyHint.Range, "0,3,1")] public int OpeningQuadrant { get; set; }

    private readonly List<string> _torchNotes = new();

    /// <summary>Per mouth, where its torch went or why every jamb was refused.</summary>
    public IReadOnlyList<string> TorchNotes => _torchNotes;

    private void PlaceTorches(Pass pass, WallFace? sigil)
    {
        if (!TorchesEnabled || TorchScene == null) return;
        // Wider openings first, so a side passage beside a tunnel mouth shares the tunnel's torch.
        foreach (var mouth in Openings.Where(o => o.Mouth).OrderByDescending(o => o.Width).ThenBy(o => o.First.X).ThenBy(o => o.First.Y))
            LightMouth(pass, mouth, sigil, mouth.Kind == OpeningKind.Culvert ? "culvert" : "mouth");

        var board = pass.Context.Board;
        foreach (var run in WallRuns.Where(r => r.Length >= TorchMinRun))
        {
            if (sigil is { } s && run.Normal == s.Normal && SewerWalls.Along(s) >= run.First && SewerWalls.Along(s) <= run.Last) continue;
            int edge = run.Normal.X != 0 ? board.Height : board.Width;
            int span = Math.Min(run.Last, pass.Margin + edge - 1) - Math.Max(run.First, pass.Margin) + 1;
            int count = Math.Max(1, (int)Math.Round((float)span / TorchSpacing, MidpointRounding.AwayFromZero));
            for (int i = 0; i < count; i++)
            {
                float target = run.First + (i + 0.5f) * run.Length / count - 0.5f;
                // A face the opening view shows first; then a pier front before the back of a bay.
                var piers = run.Piers.ToHashSet();
                var order = piers.Concat(run.Bays)
                    .OrderBy(f => ShownFrom(pass, f, OpeningQuadrant) ? 0 : 1)
                    .ThenBy(f => piers.Contains(f) ? 0 : 1)
                    .ThenBy(f => Mathf.Abs(SewerWalls.Along(f) - target)).ThenBy(SewerWalls.Along);
                foreach (var face in order)
                    if (TryHang(pass, face, sigil, $"wall {run.Length}") == null) break;
            }
        }

        // A deep recess (a bay, the apse) last, so it never takes a wall's torch.
        foreach (var recess in Openings.Where(o => o.Kind == OpeningKind.Recess && o.Lit))
            LightMouth(pass, recess, sigil, "recess");
    }

    private void LightMouth(Pass pass, SewerOpening mouth, WallFace? sigil, string reason)
    {
        var refused = new List<string>();
        string? placed = null;
        foreach (var face in Jambs(pass, mouth, OpeningQuadrant))
        {
            string? why = TryHang(pass, face, sigil, reason);
            if (why == null) { placed = $"torch on wall {pass.Board(face.Wall)}"; break; }
            refused.Add($"{pass.Board(face.Wall)} {why}");
        }
        _torchNotes.Add($"{mouth.Kind} at {pass.Board(mouth.First)}: "
            + (placed ?? (refused.Count == 0 ? "no jamb face" : "no torch, " + string.Join("; ", refused))));
    }

    /// <summary>The chamber faces beside a mouth that may carry its torch, lower end first: the
    /// outline wall flush beside the opening, a board wall standing in that line, then the end of
    /// the wall that turns into the opening.</summary>
    private static IEnumerable<WallFace> Jambs(Pass pass, SewerOpening mouth, int opening)
    {
        var (before, after) = mouth.Flanks;
        var inward = -mouth.Out;
        foreach (var (flank, edge, toMouth) in new[] { (before, mouth.Edge(0), mouth.Along), (after, mouth.Edge(mouth.Width - 1), -mouth.Along) })
        {
            var options = new[]
            {
                pass.Faces.FirstOrDefault(f => f.Normal == inward && f.Wall.x == flank.X && f.Wall.y == flank.Y),
                pass.Faces.FirstOrDefault(f => f.Normal == inward && f.Wall.x == flank.X + inward.X && f.Wall.y == flank.Y + inward.Y),
                pass.Faces.FirstOrDefault(f => f.Normal == toMouth && f.Open.x == edge.X && f.Open.y == edge.Y),
            };
            // At one end, a face the opening view shows comes first.
            foreach (var face in options.Where(f => f != default && f.OpenRing == 0)
                         .OrderBy(f => ShownFrom(pass, f, opening) ? 0 : 1))
                yield return face;
        }
    }

    /// <summary>A camera in <paramref name="quadrant"/> looks at the face and the cutaway leaves its
    /// wall standing.</summary>
    private static bool ShownFrom(Pass pass, WallFace face, int quadrant)
    {
        // Quadrant bit 0 is a camera on the -x side, bit 1 on the -z side.
        int sx = (quadrant & 1) != 0 ? -1 : 1, sz = (quadrant & 2) != 0 ? -1 : 1;
        if (face.Normal.X * sx + face.Normal.Y * sz <= 0) return false;
        return pass.Context.Cutaway?.Map is not { } map || !map.IsCut(face.Wall.x, face.Wall.y, quadrant);
    }

    /// <summary>Hangs a torch on the face, or returns why not: the sigil's wall, a face every camera
    /// that sees it cuts away (a buttress with floor on three sides), another wall prop or grate
    /// within <see cref="WallPropGap"/>, another torch within <see cref="TorchMinGap"/>.</summary>
    private string? TryHang(Pass pass, WallFace face, WallFace? sigil, string reason)
    {
        if (sigil is { } s && face.Normal == s.Normal && SewerWalls.Line(face) == SewerWalls.Line(s)) return "sigil wall";
        if (!Enumerable.Range(0, 4).Any(q => ShownFrom(pass, face, q))) return "always cut away";
        var foot = face.Foot(pass.Margin);
        var at = foot + Vector3.Up * TorchHeight + WallProps.Out(face) * WallInset;
        if (Crowded(at, pass.Taken)) return "beside a pipe, grate or the sigil";
        var spot = new Vector2(foot.X, foot.Z);
        if (_ledger.OfKind(DressKind.Torch).Any(t => t.At.DistanceTo(spot) < TorchMinGap)) return "near another torch";
        if (pass.Props.AddScene(TorchScene!, face, at, 1f, keepLights: true) is { } torch) _torches.Add(torch);
        pass.Taken.Add(at);
        _ledger.Add(new DressPlacement(DressKind.Torch, pass.Board(face.Open), pass.Board(face.Wall), spot, reason));
        return null;
    }
}
