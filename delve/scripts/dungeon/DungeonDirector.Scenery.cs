using Delve.Data;
using Delve.Look;
using Delve.Run;
using Godot;

namespace Delve.Dungeon;

public partial class DungeonDirector
{
    /// <summary>Crawl dressing per floor, keyed by <see cref="FloorTheme.Id"/>.</summary>
    [Export] public Godot.Collections.Dictionary<string, CrawlScenery> SceneryByFloor { get; set; } = new();

    /// <summary>Floor id a standalone crawl dresses as; a hosted crawl follows the run's floor.</summary>
    [Export] public string StandaloneFloorId { get; set; } = "station";

    public CrawlScenery Scenery { get; private set; } = null!;
    public CrawlWords Words { get; private set; } = null!;
    public string FloorId { get; private set; } = "";
    private LookScene? _look;
    private PackedScene? _lookSource;

    /// <summary>Pick the floor's dressing, swap in its lighting setup and its gap ground.</summary>
    private void ApplyScenery(RunState state)
    {
        string id = Hosted ? FloorThemes.ForStratum(state.Stratum).Id : StandaloneFloorId;
        if (!SceneryByFloor.TryGetValue(id, out var scenery))
        {
            GD.PushError($"[Dungeon] No crawl scenery for floor '{id}'.");
            return;
        }
        Scenery = scenery;
        FloorId = id;
        Words = CrawlWordsTable.For(id);
        _hud.SetWords(Words, FloorThemes.ById(id).DisplayName);
        _roomLight.Clear();
        _roomFade.Clear();
        if (scenery.Look != _lookSource)
        {
            if (_look != null) { _look.GetParent().RemoveChild(_look); _look.QueueFree(); }
            _look = scenery.Look?.Instantiate<LookScene>();
            _lookSource = scenery.Look;
            if (_look != null) GetNode<Node3D>("%LookSlot").AddChild(_look);
        }
        if (Hosted) _look?.SetActive(Visible);
        if (scenery.VoidMaterial != null)
            GetNode<MeshInstance3D>("%Bedrock").MaterialOverride = scenery.VoidMaterial;
    }
}
