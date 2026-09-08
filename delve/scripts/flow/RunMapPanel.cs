using System;
using System.Collections.Generic;
using Delve.Data;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// The run map: one row per floor, the entrance at the bottom and the Depths Warden at the top.
/// Every node is a <see cref="MapNodeButton"/> medallion jittered off its grid cell so the chart
/// reads hand-drawn, wired by <see cref="MapEdgeCanvas"/> dashed trails; the walked path burns
/// in the leader's color and the open choices pulse. Only ids <see cref="RunState.Reachable"/> lists are enabled,
/// so the panel cannot pick an illegal move. Passive - it renders what it is handed and signals
/// the pick outward.
/// </summary>
public partial class RunMapPanel : Control
{
    [Export] public RunMapAccentTheme AccentTheme { get; set; } = null!;
    private Theme _baseTheme = null!;
    private string? _leaderId;
    private Color _accent;
    [Export] public float LaneSpacing { get; set; } = 168f;
    [Export] public float FloorSpacing { get; set; } = 106f;
    private const float JitterX = 26f;
    private const float JitterY = 14f;

    /// <summary>Gap between a medallion's bounding edge and where its trail dashes start.</summary>
    private const float EdgePad = 3f;
    private string _guardianTitle = "Floor guardian";

    private Control _mapArea = null!;
    private Label _floorLabel = null!;
    private Label _floorTitle = null!;
    private Label _detailTitle = null!;
    private Label _detailBody = null!;
    private Label _detailState = null!;
    private RunMapStatus _status = null!;
    private ScrollContainer _mapScroll = null!;
    private BoxContainer _legendRow = null!;
    private MapScenery _scenery = null!;

    public event Action<int>? NodePicked;
    public event Action? ShortRestPressed;

    public override void _Ready()
    {
        _baseTheme = Theme;
        _mapArea = GetNode<Control>("%MapArea");
        _floorLabel = GetNode<Label>("%FloorLabel");
        _floorTitle = GetNode<Label>("%FloorTitle");
        _detailTitle = GetNode<Label>("%DetailTitle");
        _detailBody = GetNode<Label>("%DetailBody");
        _detailState = GetNode<Label>("%DetailState");
        _status = GetNode<RunMapStatus>("%Status");
        _mapScroll = GetNode<ScrollContainer>("%MapScroll");
        _legendRow = GetNode<BoxContainer>("%LegendRow");
        _scenery = GetNode<MapScenery>("%Scenery");
        _mapScroll.GetVScrollBar().ValueChanged += _ => _scenery.QueueRedraw();
        _mapScroll.GetHScrollBar().ValueChanged += _ => _scenery.QueueRedraw();
        _status.RestPressed += () => ShortRestPressed?.Invoke();
        BuildLegend();
    }

    /// <summary>Redraw the strip and the whole map from the run's current state.</summary>
    public void Render(RunState state)
    {
        if (_leaderId != state.Party.LeaderId)
        {
            _leaderId = state.Party.LeaderId;
            _accent = UiColors.CharacterAccent(_leaderId);
            Theme = AccentTheme.Build(_baseTheme, _accent);
            _status.Theme = Theme;
        }
        var theme = FloorThemes.ForStratum(state.Stratum);
        _floorLabel.Text = $"FLOOR {state.Stratum + 1} / {FloorThemes.Count}";
        _floorTitle.Text = theme.DisplayName;
        _guardianTitle = state.Stratum == FloorThemes.Count - 1 ? "Depths Warden" : "Floor guardian";
        _status.Render(state);
        _detailTitle.Text = "Choose your path";
        _detailBody.Text = "Choose a lit destination to travel. Hover or focus a node to inspect it.";
        _detailState.Text = "";
        _detailState.Visible = false;

        RebuildMap(state);
    }

    private void RebuildMap(RunState state)
    {
        foreach (var child in _mapArea.GetChildren())
        {
            _mapArea.RemoveChild(child);
            child.QueueFree();
        }

        var map = state.Map;
        _mapArea.CustomMinimumSize = new Vector2(map.Lanes * LaneSpacing, map.Floors * FloorSpacing);

        var centers = new Dictionary<int, Vector2>(map.Nodes.Count);
        foreach (var node in map.Nodes)
            centers[node.Id] = Center(node, map) + Jitter(state.Seed, node, map);

        var live = LiveNodes(state);
        _scenery.Configure(state, centers, _mapArea);
        _mapArea.AddChild(BuildEdgeCanvas(state, centers, live));

        var reachable = new HashSet<int>(state.Reachable());
        int? current = state.CurrentNodeId;
        foreach (var node in map.Nodes)
        {
            var button = new MapNodeButton { PartyAccent = _accent };
            button.Setup(node, reachable.Contains(node.Id), current == node.Id, live.Contains(node.Id));
            if (node.Kind == NodeKind.Boss)
                button.TooltipText = $"{_guardianTitle}\n{NodeKindInfo.Get(node.Kind).Blurb}";
            button.Position = centers[node.Id] - button.Size / 2f;
            int id = node.Id;
            button.Pressed += () => NodePicked?.Invoke(id);
            button.MouseEntered += () => ShowDestination(node, reachable.Contains(id), live.Contains(id), current == id);
            button.FocusEntered += () => ShowDestination(node, reachable.Contains(id), live.Contains(id), current == id);
            _mapArea.AddChild(button);
            if (current == id || (current == null && id == map.StartIds[0]))
                Callable.From(() =>
                {
                    // Several transitions can rebuild the map before this deferred call runs.
                    if (IsInstanceValid(button) && _mapScroll.IsAncestorOf(button))
                        _mapScroll.EnsureControlVisible(button);
                }).CallDeferred();
        }
    }

    private void ShowDestination(MapNode node, bool reachable, bool live, bool current)
    {
        var entry = NodeKindInfo.Get(node.Kind);
        _detailTitle.Text = node.Kind == NodeKind.Boss ? _guardianTitle : entry.DisplayName;
        _detailBody.Text = entry.Blurb;
        _detailState.Visible = true;
        _detailState.Text = current ? "Your party is here."
            : node.Visited ? "Already visited."
            : reachable ? "Click to travel."
            : live ? "Further along the path."
            : "This route is no longer reachable.";
    }

    /// <summary>Ids the run can still stand on: the current node and everything downstream of it
    /// (or of any entrance before the first pick). Whatever is outside this set - visited or
    /// bypassed - is dead and the map greys it out.</summary>
    private static HashSet<int> LiveNodes(RunState state)
    {
        var live = new HashSet<int>();
        var stack = new Stack<int>();
        if (state.CurrentNodeId is int current) stack.Push(current);
        else
        {
            foreach (int id in state.Map.StartIds) stack.Push(id);
        }
        while (stack.Count > 0)
        {
            int id = stack.Pop();
            if (!live.Add(id)) continue;
            var node = state.Map.Node(id);
            if (node == null) continue;
            foreach (int next in node.Next) stack.Push(next);
        }
        return live;
    }

    /// <summary>The dashed-trail layer: walked history in the leader's color, the current choices bright,
    /// paths still ahead receding, dead paths nearly gone.</summary>
    private MapEdgeCanvas BuildEdgeCanvas(
        RunState state, IReadOnlyDictionary<int, Vector2> centers, HashSet<int> live)
    {
        var traveled = new HashSet<(int, int)>();
        for (int i = 0; i + 1 < state.History.Count; i++)
            traveled.Add((state.History[i], state.History[i + 1]));

        var open = new HashSet<(int, int)>();
        if (state.CurrentNodeId is int from)
        {
            foreach (int to in state.Reachable())
                open.Add((from, to));
        }

        var edges = new List<MapEdgeCanvas.MapEdge>();
        foreach (var node in state.Map.Nodes)
        {
            foreach (int nextId in node.Next)
            {
                var next = state.Map.Node(nextId);
                if (next == null || !centers.TryGetValue(nextId, out var to)) continue;
                var pair = (node.Id, nextId);
                var edgeState = traveled.Contains(pair) ? MapEdgeCanvas.EdgeState.Traveled
                    : open.Contains(pair) ? MapEdgeCanvas.EdgeState.Open
                    : live.Contains(node.Id) && live.Contains(nextId) ? MapEdgeCanvas.EdgeState.Dim
                    : MapEdgeCanvas.EdgeState.Dead;
                edges.Add(new MapEdgeCanvas.MapEdge(
                    centers[node.Id], to,
                    NodeKindInfo.Get(node.Kind).MapDiameter * 0.5f + EdgePad,
                    NodeKindInfo.Get(next.Kind).MapDiameter * 0.5f + EdgePad,
                    edgeState));
            }
        }

        var canvas = new MapEdgeCanvas { PartyAccent = _accent };
        canvas.SetAnchorsPreset(LayoutPreset.FullRect);
        canvas.SetEdges(edges);
        return canvas;
    }

    /// <summary>One legend entry per kind the generator can place, straight from the kind table.</summary>
    private void BuildLegend()
    {
        foreach (NodeKind kind in Enum.GetValues<NodeKind>())
        {
            var entry = NodeKindInfo.Get(kind);
            if (!entry.Generated) continue;

            // The row itself owns the hover so one tooltip covers glyph and label alike.
            var item = new HBoxContainer
            {
                MouseFilter = MouseFilterEnum.Stop,
                TooltipText = entry.Blurb,
            };
            item.AddThemeConstantOverride("separation", 6);
            var glyph = new MapLegendGlyph { MouseFilter = MouseFilterEnum.Ignore };
            glyph.Setup(kind);
            item.AddChild(glyph);
            item.AddChild(new Label
            {
                Text = kind == NodeKind.Boss ? "Guardian" : entry.DisplayName,
                ThemeTypeVariation = "MapLegend",
            });
            _legendRow.AddChild(item);
        }
    }

    /// <summary>Pixel centre of a node's grid cell: lanes left to right, floor 0 at the bottom.</summary>
    private Vector2 Center(MapNode node, RunMap map) => new(
        node.Lane * LaneSpacing + LaneSpacing / 2f,
        (map.Floors - 1 - node.Floor) * FloorSpacing + FloorSpacing / 2f);

    /// <summary>Deterministic per-node offset off the grid cell, so the same seed always draws the
    /// same chart. The boss stays pinned - the summit does not wobble.</summary>
    private static Vector2 Jitter(int runSeed, MapNode node, RunMap map)
    {
        if (node.Id == map.BossId) return Vector2.Zero;
        var rng = new Random(RunRng.StableSeed(runSeed, node.Id, "mapjitter"));
        return new Vector2(
            ((float)rng.NextDouble() * 2f - 1f) * JitterX,
            ((float)rng.NextDouble() * 2f - 1f) * JitterY);
    }
}
