using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Flow;
using Delve.Run;
using Godot;

namespace Delve.Village;

/// <summary>
/// Puts every resident at home in the village for the time of day: each takes its scheduled area if
/// that area is built and has room, else the first fallback with room. A resident owns the spots it
/// takes, so no two share one. Roster order wins a clash.
/// </summary>
public partial class VillageResidents : Node3D
{
    [Export] public PackedScene FigureScene { get; set; } = null!;
    [Export] public CampTerrain Ground { get; set; } = null!;

    /// <summary>Routes every walk round the town's pieces.</summary>
    [Export] public VillageWalkable? Walkable { get; set; }

    /// <summary>Parent of the village's <see cref="ResidentSpot"/> markers.</summary>
    [Export] public Node3D Spots { get; set; } = null!;

    /// <summary>Residents with seated art, and that art, index for index.</summary>
    [Export] public string[] SeatedIds { get; set; } = System.Array.Empty<string>();
    [Export] public CampAppearance[] SeatedLooks { get; set; } = System.Array.Empty<CampAppearance>();

    private readonly List<ResidentFigure> _figures = new();
    private readonly List<string> _unplaced = new();
    private readonly Dictionary<ResidentFigure, List<ResidentSpot>> _owned = new();
    private readonly List<ResidentSpot> _free = new();
    private CampTimeOfDay _time;

    public IReadOnlyList<ResidentFigure> Figures => _figures;

    /// <summary>The village's lit-billboard materials, handed to every figure on spawn.</summary>
    public LitBillboards? Lighting { get; set; }

    /// <summary>The village's movers: every resident joins it and veers round the others while walking.</summary>
    public VillageCrowd? Crowd { get; set; }

    /// <summary>The current sun for new figures' shadow twins; the stage keeps it up to date.</summary>
    public SunAngle Sun { get; set; } = new(0, 1);

    /// <summary>Residents the last <see cref="Place"/> found no room for.</summary>
    public IReadOnlyList<string> Unplaced => _unplaced;

    /// <summary>
    /// Everyone first takes one spot, in roster order; then residents whose activity moves between
    /// spots take spare ones in the same area. A full roster still fits, and the spare room goes to walking.
    /// </summary>
    public void Place(IReadOnlyList<string> ids, CampTimeOfDay time, TownTier tier)
    {
        Clear();
        _time = time;
        _free.AddRange(Spots.GetChildren().OfType<ResidentSpot>().Where(s => s.Builds((int)tier)));
        var placed = new List<(string Id, VillageTask Task, List<ResidentSpot> Spots)>();
        foreach (string id in ids)
        {
            if (First(id) is { } first) placed.Add((id, first.Task, new List<ResidentSpot> { first.Spot }));
            else _unplaced.Add(id);
        }
        foreach (var (_, task, spots) in placed) TakeSpares(task, spots);
        foreach (var (id, task, spots) in placed) Spawn(id, task, spots, Seed(id, time));
    }

    /// <summary>Takes one resident out of the village (called to the line-up); its spots come free.</summary>
    public void Release(string id)
    {
        if (_figures.FirstOrDefault(f => f.Id == id) is not { } figure) return;
        _free.AddRange(_owned[figure]);
        _owned.Remove(figure);
        _figures.Remove(figure);
        figure.Retire();
    }

    /// <summary>Puts one resident back at home for the current time, if there is room.</summary>
    public bool Admit(string id)
    {
        if (_figures.Any(f => f.Id == id) || First(id) is not { } first) return false;
        var spots = new List<ResidentSpot> { first.Spot };
        TakeSpares(first.Task, spots);
        Spawn(id, first.Task, spots, Seed(id, _time));
        _unplaced.Remove(id);
        return true;
    }

    public void Clear()
    {
        foreach (var figure in _figures) figure.Retire();
        _figures.Clear();
        _owned.Clear();
        _free.Clear();
        _unplaced.Clear();
    }

    /// <summary>The scheduled task with room, else the first fallback with room, and one spot in it.</summary>
    private (VillageTask Task, ResidentSpot Spot)? First(string id)
    {
        foreach (var task in new[] { VillageSchedule.For(id, _time) }.Concat(VillageSchedule.Fallbacks))
            if (Claim(task, _free) is { } spot) return (task, spot);
        return null;
    }

    /// <summary>A spot for every use the activity works at that the resident lacks, then any spare room up to its count.</summary>
    /// <summary>A spot for every use the activity works at that the resident lacks, then any spare room up to
    /// its count; each the nearest free one to the resident's first spot, so its walks stay short.</summary>
    private void TakeSpares(VillageTask task, List<ResidentSpot> spots)
    {
        var activity = VillageActivities.For(task.Activity);
        var home = spots[0].GlobalPosition;
        foreach (string use in activity.Uses)
            if (spots.All(s => s.Use != use) && Claim(task, _free, use, home) is { } needed) spots.Add(needed);
        while (spots.Count < activity.Spots && Claim(task, _free, null, home) is { } spare) spots.Add(spare);
    }

    /// <summary>
    /// Takes one free spot of the right kind in the task's area, or none if it has no room. A spot with
    /// a use goes only to an activity that works at it; <paramref name="use"/> asks for that use alone,
    /// and without it the activity's first use is preferred. With <paramref name="near"/>, the nearest fit wins.
    /// </summary>
    private static ResidentSpot? Claim(VillageTask task, List<ResidentSpot> free, string? use = null, Vector3? near = null)
    {
        var activity = VillageActivities.For(task.Activity);
        var fits = free.Where(s => s.Area == task.Area && s.Seated == activity.Seated
            && (use == null ? s.Use == "" || activity.Uses.Contains(s.Use) : s.Use == use)).ToList();
        if (near is { } at) fits = fits.OrderBy(s => s.GlobalPosition.DistanceTo(at)).ToList();
        string first = activity.Uses.FirstOrDefault() ?? "";
        var spot = fits.FirstOrDefault(s => s.Use == first) ?? fits.FirstOrDefault();
        if (spot != null) free.Remove(spot);
        return spot;
    }

    private void Spawn(string id, VillageTask task, List<ResidentSpot> spots, int seed)
    {
        var figure = FigureScene.Instantiate<ResidentFigure>();
        figure.Name = id;
        AddChild(figure);
        figure.Sprite.Lighting = Lighting;
        figure.Crowd = Crowd;
        int look = System.Array.IndexOf(SeatedIds, id);
        var poses = look >= 0 && look < SeatedLooks.Length ? SeatedLooks[look].Poses() : System.Array.Empty<Texture2D>();
        figure.Begin(id, task.Area, HeroSpriteMap.FolderFor(id), poses, VillageActivities.For(task.Activity),
            spots.Select(s => s.Place).ToList(), seed, Ground, Walkable == null ? null : Walkable.Route);
        SunShadows.Sync(figure.Sprite, Sun);
        _figures.Add(figure);
        _owned[figure] = spots;
    }

    /// <summary>A stable seed per resident and time; string hashes change between runs in .NET.</summary>
    public static int Seed(string id, CampTimeOfDay time)
    {
        int hash = 17 + (int)time * 7919;
        foreach (char c in id) hash = hash * 31 + c;
        return hash & 0x7fffffff;
    }
}
