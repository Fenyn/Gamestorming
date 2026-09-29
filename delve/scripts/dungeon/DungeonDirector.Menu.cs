using Godot;

namespace Delve.Dungeon;

/// <summary>Keeps the exploration party menu floating beside the party, as the combat command menu
/// floats beside the active unit.</summary>
public partial class DungeonDirector
{
    /// <summary>Metres above the party's feet the menu centres on.</summary>
    [Export] public float PartyMenuLift { get; set; } = 0.9f;

    private void AnchorPartyMenu()
    {
        if (!IsVisibleInTree()) return;
        _hud.SetOverlayOpen(_details.Visible || _event.Visible);
        if (_tokens.Count == 0 || !_hud.PartyMenu.Visible) return;
        var centre = Vector3.Zero;
        foreach (var token in _tokens) centre += token.GlobalPosition;
        centre = centre / _tokens.Count + Vector3.Up * PartyMenuLift;
        var camera = _camera.Camera;
        if (camera.IsPositionBehind(centre)) return;
        // Under canvas_items stretch, UnprojectPosition already returns HUD (canvas) coordinates.
        _hud.AnchorPartyMenu(camera.UnprojectPosition(centre));
    }
}
