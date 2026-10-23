using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Ungilded.Props;

/// <summary>
/// One chamber wall as the eye reads it: the faces looking one way, one per tile along the wall,
/// unbroken. A culvert or a passage breaks it, and its mouth carries the torch. A ribbed wall keeps two lines, the pier fronts
/// and the recesses between them, and steps back and forth between them. A third line, or a single
/// step from one line to the other, is where two walls meet (a chamfer, a buttress's side).
/// </summary>
public sealed record WallRun(Vector2I Normal, List<WallFace> Faces)
{
    public int First => SewerWalls.Along(Faces[0]);

    public int Last => SewerWalls.Along(Faces[^1]);

    /// <summary>Tiles from the first face to the last, culvert gaps included.</summary>
    public int Length => Last - First + 1;

    /// <summary>The faces on the line nearest the chamber: the pier fronts of a ribbed wall, every
    /// face of a flat one.</summary>
    public IEnumerable<WallFace> Piers
    {
        get
        {
            int front = Faces.Max(SewerWalls.Forward);
            return Faces.Where(f => SewerWalls.Forward(f) == front);
        }
    }

    /// <summary>The faces at the back of a bay between deep buttresses: at least
    /// <see cref="SewerWalls.BayDepth"/> lines behind the fronts. A one-line niche is not a bay.</summary>
    public IEnumerable<WallFace> Bays
    {
        get
        {
            int front = Faces.Max(SewerWalls.Forward);
            return Faces.Where(f => front - SewerWalls.Forward(f) >= SewerWalls.BayDepth);
        }
    }
}

/// <summary>Splits wall faces into <see cref="WallRun"/>s.</summary>
public static class SewerWalls
{
    /// <summary>Lines a recess runs behind the pier fronts to count as a bay.</summary>
    public const int BayDepth = 2;

    public static int Along(WallFace f) => f.Normal.X != 0 ? f.Wall.y : f.Wall.x;

    public static int Line(WallFace f) => f.Normal.X != 0 ? f.Wall.x : f.Wall.y;

    /// <summary>How far into the chamber the face stands, along its own normal.</summary>
    public static int Forward(WallFace f) => Line(f) * (f.Normal.X + f.Normal.Y);

    /// <summary>The runs of <paramref name="faces"/>.</summary>
    public static List<WallRun> Runs(IEnumerable<WallFace> faces)
    {
        var runs = new List<WallRun>();
        foreach (var group in faces.GroupBy(f => f.Normal))
        {
            // One face per position along the wall: the one standing furthest into the chamber.
            var line = group.GroupBy(Along).Select(g => g.OrderByDescending(Forward).First()).OrderBy(Along);
            List<WallFace>? run = null;
            foreach (var face in line)
            {
                if (run == null || Broken(run, face))
                {
                    run = new List<WallFace>();
                    runs.Add(new WallRun(group.Key, run));
                }
                run.Add(face);
            }
        }
        return runs.SelectMany(SplitSingleStep).ToList();
    }

    /// <summary>A run that changes line once is two walls meeting: split it at the step.</summary>
    private static IEnumerable<WallRun> SplitSingleStep(WallRun run)
    {
        var steps = Enumerable.Range(1, run.Faces.Count - 1).Where(i => Line(run.Faces[i]) != Line(run.Faces[i - 1])).ToList();
        if (steps.Count != 1)
        {
            yield return run;
            yield break;
        }
        yield return run with { Faces = run.Faces.Take(steps[0]).ToList() };
        yield return run with { Faces = run.Faces.Skip(steps[0]).ToList() };
    }

    private static bool Broken(List<WallFace> run, WallFace next)
    {
        if (Along(next) != Along(run[^1]) + 1) return true;
        var lines = run.Select(Line).Append(Line(next)).Distinct().Count();
        return lines > 2;
    }
}
