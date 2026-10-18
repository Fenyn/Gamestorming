using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Flow;
using Delve.Run;
using Godot;

namespace Delve.Village;

/// <summary>
/// The four party slots at the trailhead, XCOM style. A pick is called from the fixed entry point
/// offscreen, hurries up the trail and waits in its slot; a dismissed pick walks back out of frame.
/// </summary>
public partial class VillageLineup : Node3D
{
    [Export] public PackedScene FigureScene { get; set; } = null!;
    [Export] public CampTerrain Ground { get; set; } = null!;

    /// <summary>One marker per party slot, left to right.</summary>
    [Export] public Marker3D[] Slots { get; set; } = System.Array.Empty<Marker3D>();

    /// <summary>The way in: the entry point offscreen, then the bends of the trail. The slot ends it.</summary>
    [Export] public Marker3D[] Path { get; set; } = System.Array.Empty<Marker3D>();

    /// <summary>Which way a waiting pick faces, in grid space.</summary>
    [Export] public Vector2 SlotFacing { get; set; } = new(0, 1);

    /// <summary>Sideways gap between the slots' lanes up the trail.</summary>
    [Export] public float LaneSpacing { get; set; } = 0.9f;

    /// <summary>The village's lit-billboard materials, handed to every pick on spawn.</summary>
    public LitBillboards? Lighting { get; set; }

    /// <summary>The village's movers: picks veer round them on the way in and out.</summary>
    public VillageCrowd? Crowd { get; set; }

    /// <summary>The current sun for new figures' shadow twins; the stage keeps it up to date.</summary>
    public SunAngle Sun { get; set; } = new(0, 1);

    private readonly Dictionary<string, (ResidentFigure Figure, MarchRoutine March, int Slot)> _standing = new();
    private readonly List<ResidentFigure> _leaving = new();

    public bool IsCalled(string id) => _standing.ContainsKey(id);
    public bool HasArrived(string id) => _standing.TryGetValue(id, out var entry) && entry.March.Arrived;
    public int SlotOf(string id) => _standing.TryGetValue(id, out var entry) ? entry.Slot : -1;
    public ResidentFigure? FigureOf(string id) => _standing.TryGetValue(id, out var entry) ? entry.Figure : null;

    /// <summary>Figures still walking back out.</summary>
    public int Leaving => _leaving.Count;

    /// <param name="walk">False stands the pick in its slot at once.</param>
    public void Call(string id, int slot, bool walk)
    {
        if (_standing.ContainsKey(id) || slot < 0 || slot >= Slots.Length) return;
        int seed = VillageResidents.Seed(id, CampTimeOfDay.Morning) + slot;
        var march = new MarchRoutine(LaneFor(slot), SlotFacing, seed, walk, Crowd);
        var figure = FigureScene.Instantiate<ResidentFigure>();
        figure.Name = id;
        AddChild(figure);
        figure.Sprite.Lighting = Lighting;
        figure.Crowd = Crowd;
        figure.March(id, HeroSpriteMap.FolderFor(id), march, seed, Ground);
        SunShadows.Sync(figure.Sprite, Sun);
        _standing[id] = (figure, march, slot);
    }

    /// <summary>A slot's way in, from the entry point to the slot. Each slot runs its own lane, so picks
    /// called together do not overlap on the way in.</summary>
    public List<Vector2> LaneFor(int slot)
    {
        var lane = new Vector2((slot - (Slots.Length - 1) / 2f) * LaneSpacing, 0);
        return Path.Select(p => Flat(p) + lane).Append(Flat(Slots[slot])).ToList();
    }

    /// <param name="walk">False removes the pick at once.</param>
    public void Dismiss(string id, bool walk)
    {
        if (!_standing.Remove(id, out var entry)) return;
        if (!walk)
        {
            entry.Figure.Retire();
            return;
        }
        entry.March.Leave();
        _leaving.Add(entry.Figure);
    }

    public void Clear()
    {
        foreach (var (figure, _, _) in _standing.Values) figure.Retire();
        foreach (var figure in _leaving) figure.Retire();
        _standing.Clear();
        _leaving.Clear();
    }

    public override void _Process(double delta)
    {
        for (int i = _leaving.Count - 1; i >= 0; i--)
            if (_leaving[i].Driver is MarchRoutine { Gone: true })
            {
                _leaving[i].Retire();
                _leaving.RemoveAt(i);
            }
    }

    private static Vector2 Flat(Node3D marker) => new(marker.GlobalPosition.X, marker.GlobalPosition.Z);
}
