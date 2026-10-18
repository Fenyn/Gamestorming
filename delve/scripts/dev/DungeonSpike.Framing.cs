using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Settings;
using Godot;

namespace Delve.Dev;

/// <summary>The crawl's camera work: every doorway framed clear of the HUD, a sign over each doorway
/// that agrees with the floor plan, an event framed beside its panel, and an exploration zoom kept
/// apart from the combat zoom.</summary>
public partial class DungeonSpike
{
    private static OrbitCameraRig Rig(DungeonDirector host) => host.GetNode<OrbitCameraRig>("%ExploreCamera");

    private void CheckRoomFraming(DungeonDirector host, DungeonHud hud, string room)
    {
        var rig = Rig(host);
        rig.FinishComposition();
        var clear = hud.ClearView().Grow(2);
        var doors = host.Current.Doors.Select(d => d.Side(host.Current.Id)).ToList();
        var outside = doors.Where(side => !clear.HasPoint(rig.Camera.UnprojectPosition(host.CurrentView.ToGlobal(host.CurrentView.DoorPosition(side))))).ToList();
        Check($"{room}: every doorway sits in the HUD's clear view ({clear}; outside: {string.Join(",", outside)})", outside.Count == 0);
        var plan = hud.Plan.Drawn();
        var signs = host.DoorSigns;
        Check($"{room}: a sign floats over each doorway, showing the plan's icon ({string.Join(", ", signs.Select(s => $"{s.Key}:{s.Value.IconKey}"))})",
            signs.Count == doors.Count && doors.All(side => signs.TryGetValue(side, out var sign) && sign.IsVisibleInTree()
                && sign.IconKey == plan[host.Current.Doors.First(d => d.Side(host.Current.Id) == side).Other(host.Current.Id)]));
        var tiles = host.GetNode<Node3D>("%TravelParty").GetChildren().OfType<Node3D>()
            .Select(t => Delve.Terrain.GridSpace.WorldToGrid(t.Position)).ToList();
        Check($"{room}: each hero stands on a tile of its own", tiles.Count > 0 && tiles.Distinct().Count() == tiles.Count);
    }

    /// <summary>An open event glides the camera in on the room and sets it right of the panel; the
    /// doorway signs step aside with the other door affordances.</summary>
    private async Task CheckEventFraming(DungeonDirector host)
    {
        var rig = Rig(host);
        await WaitSeconds((float)host.EventFocusSeconds + 0.15f);
        Check($"an event frames its room right of the panel and a little closer (shift {rig.Composition}, dolly {rig.Dolly:0.00})",
            rig.Composition.X > 0.05f && rig.Dolly < 1f && Mathf.IsEqualApprox(rig.Dolly, host.EventPushIn, 0.01f));
        Check("no doorway sign shows while the event is open", host.DoorSigns.Count == 0);
    }

    private async Task CheckEventUnframed(DungeonDirector host)
    {
        var rig = Rig(host);
        await WaitSeconds((float)host.FramingSeconds + 0.15f);
        Check($"closing the event returns to the room shot (shift {rig.Composition}, dolly {rig.Dolly:0.00})",
            Mathf.Abs(rig.Composition.X) < 0.01f && Mathf.IsEqualApprox(rig.Dolly, 1f, 0.01f) && host.DoorSigns.Count > 0);
    }

    /// <summary>A wheel zoom while exploring is remembered for exploring only.</summary>
    private void CheckZoomSlots(DungeonDirector host)
    {
        bool hadCombat = ViewPreferences.TryGetCameraDistance(CameraZoomSlot.Combat, out float combatBefore);
        Rig(host)._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.WheelDown, Pressed = true });
        bool combatAfter = ViewPreferences.TryGetCameraDistance(CameraZoomSlot.Combat, out float combatNow);
        Check("a zoom while exploring is kept for exploring, not combat",
            ViewPreferences.TryGetCameraDistance(CameraZoomSlot.Exploration, out _)
            && hadCombat == combatAfter && (!hadCombat || combatNow == combatBefore));
        Rig(host)._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.WheelUp, Pressed = true });
    }
}
