using System.Collections.Generic;
using Ungilded.Terrain;
using Ungilded.UI;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>The HUD panels a tutorial tip box keeps off (the unit cards, the timeline with its
/// heading, the open command menu, the mode pill), and the board tiles a tile cutout may use: on screen and not
/// under one of those panels.</summary>
public partial class CombatScene
{
    private readonly List<Rect2> _panelScratch = new();

    /// <summary>Fill <paramref name="panels"/> with the drawn HUD panels, in HUD pixels.</summary>
    public void HudPanels(List<Rect2> panels)
    {
        panels.Clear();
        if (_session == null) return;
        foreach (var card in new[] { _inspectPanel, _actorCard, _targetCard })
            if (card.IsVisibleInTree()) panels.Add(card.GetGlobalRect());
        if (_turnBar.IsVisibleInTree()) panels.Add(_turnBar.ContentRect);
        if (_actionBar.BarPanel.IsVisibleInTree()) panels.Add(_actionBar.BarPanel.GetGlobalRect());
        var prompt = _commandPrompt ??= GetNode<CommandPromptView>("%CommandPrompt");
        if (prompt.Pill.IsVisibleInTree()) panels.Add(prompt.Pill.GetGlobalRect());
    }

    /// <summary>The tiles whose centre shows on screen outside every HUD panel.</summary>
    private List<PF2eVec> TilesInView(IReadOnlyCollection<PF2eVec> tiles)
    {
        var shown = new List<PF2eVec>(tiles.Count);
        var camera = _cameraRig.Camera;
        var screen = _tacticalHud.GetGlobalRect();
        HudPanels(_panelScratch);
        foreach (var tile in tiles)
        {
            var world = GridSpace.GridToWorld(tile, SurfaceHeights);
            if (camera.IsPositionBehind(world)) continue;
            var point = camera.UnprojectPosition(world);
            if (!screen.HasPoint(point) || UnderPanel(point)) continue;
            shown.Add(tile);
        }
        return shown;
    }

    private bool UnderPanel(Vector2 point)
    {
        foreach (var panel in _panelScratch)
            if (panel.HasPoint(point)) return true;
        return false;
    }
}
