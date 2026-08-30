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
/// ember and the open choices pulse. Only ids <see cref="RunState.Reachable"/> lists are enabled,
/// so the panel cannot pick an illegal move. Passive - it renders what it is handed and signals
/// the pick outward.
/// </summary>
public partial class RunMapPanel : Control
{
    private const int LaneSpacing = 150;
    private const int FloorSpacing = 104;
    private const float JitterX = 26f;
    private const float JitterY = 14f;

    /// <summary>Gap between a medallion's bounding edge and where its trail dashes start.</summary>
    private const float EdgePad = 3f;

    /// <summary>Backdrop fog density per stratum: the mist thickens the deeper the run goes.</summary>
    [Export] public float[] FogDensityByStratum { get; set; } = { 0.5f, 0.68f, 0.8f };

    private Control _mapArea = null!;
    private Label _clockLabel = null!;
    private Label _partyLabel = null!;
    private Button _shortRestButton = null!;
    private BoxContainer _legendRow = null!;
    private ColorRect _backdrop = null!;

    public event Action<int>? NodePicked;
    public event Action? ShortRestPressed;

    public override void _Ready()
    {
        _mapArea = GetNode<Control>("%MapArea");
        _clockLabel = GetNode<Label>("%ClockLabel");
        _partyLabel = GetNode<Label>("%PartyLabel");
        _shortRestButton = GetNode<Button>("%ShortRestButton");
        _legendRow = GetNode<BoxContainer>("%LegendRow");
        _backdrop = GetNode<ColorRect>("%Backdrop");
        _shortRestButton.Pressed += () => ShortRestPressed?.Invoke();
        BuildLegend();
    }

    /// <summary>Redraw the strip and the whole map from the run's current state.</summary>
    public void Render(RunState state)
    {
        var clock = state.Clock;
        var ward = state.Wardstone;
        var theme = FloorThemes.ForStratum(state.Stratum);
        _clockLabel.Text = $"Floor {state.Stratum + 1}: {theme.DisplayName}"
            + $"      Level {state.Party.Level}  XP {state.Xp}/{state.Leveling.XpPerLevel}"
            + $"      Day {clock.Day}      Ten-minute rests {clock.ShortRestsUsed}/{clock.ShortRestsPerDay}"
            + $"      Ward {ward.Ward}/{ward.Rules.MaxWard}"
            + (ward.Upshift > 0 ? $" (threat +{ward.Upshift})" : "");
        _partyLabel.Text = PartyLines.Summary(state.Party);

        // Glacial information stays out of the combat HUD; the day and the rest budget live here,
        // where the player summons them between fights (design/ui_guidelines.md section 2.2).
        _shortRestButton.Disabled = !clock.CanShortRest;
        _shortRestButton.TooltipText = clock.CanShortRest ? "" : "Unavailable: no time left today";

        TintBackdrop(theme.Id, state.Stratum);
        RebuildMap(state);
    }

    /// <summary>Point the fog shader at this floor's palette tones and depth.</summary>
    private void TintBackdrop(string themeId, int stratum)
    {
        if (_backdrop.Material is not ShaderMaterial fog) return;
        fog.SetShaderParameter("base_color", UiColors.MapBase(themeId));
        fog.SetShaderParameter("fog_color", UiColors.MapFog(themeId));
        int i = Math.Clamp(stratum, 0, FogDensityByStratum.Length - 1);
        fog.SetShaderParameter("fog_density", FogDensityByStratum[i]);
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
        _mapArea.AddChild(BuildEdgeCanvas(state, centers, live));

        var reachable = new HashSet<int>(state.Reachable());
        int? current = state.CurrentNodeId;
        foreach (var node in map.Nodes)
        {
            var button = new MapNodeButton();
            button.Setup(node, reachable.Contains(node.Id), current == node.Id, live.Contains(node.Id));
            button.Position = centers[node.Id] - button.Size / 2f;
            int id = node.Id;
            button.Pressed += () => NodePicked?.Invoke(id);
            _mapArea.AddChild(button);
        }
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

    /// <summary>The dashed-trail layer: walked history in ember, the current choices bright,
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

        var canvas = new MapEdgeCanvas();
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
                Text = entry.DisplayName,
                ThemeTypeVariation = ThemeNames.HintLabel,
            });
            _legendRow.AddChild(item);
        }
    }

    /// <summary>Pixel centre of a node's grid cell: lanes left to right, floor 0 at the bottom.</summary>
    private static Vector2 Center(MapNode node, RunMap map) => new(
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
