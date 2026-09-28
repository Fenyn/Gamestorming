using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Flow;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class DungeonRunSpike
{
    /// <summary>The exploration party strip sits where the combat party column does, and the
    /// Wardstone panel moved to the top right.</summary>
    private async Task CheckPartyStrip(RunDirector run, DungeonDirector dungeon, RunState state)
    {
        var hud = dungeon.GetNode<DungeonHud>("%DungeonHud");
        await Frames(2);
        var strip = hud.PartyStrip;
        var combatColumn = run.GetChildren().OfType<CombatScene>().Single().GetNode<SquadPanel>("%SquadPanel");
        Check($"the exploration strip shows one chip per member ({strip.Chips.Count})",
            strip.IsVisibleInTree() && strip.Chips.Count == state.Party.Members.Count);
        Check($"the strip uses the combat column's box ({strip.Position} {strip.Size.X} vs {combatColumn.Position} {combatColumn.Size.X})",
            strip.Position == combatColumn.Position && Mathf.IsEqualApprox(strip.Size.X, combatColumn.Size.X));
        var top = hud.GetNode<Control>("%Top");
        Check($"the Wardstone panel sits at the top right, clear of the strip ({top.GetGlobalRect()})",
            top.GetGlobalRect().End.X >= hud.Size.X - 24 && !top.GetGlobalRect().Intersects(strip.GetGlobalRect()));
        var ward = hud.GetNode<Control>("%Expedition").GetGlobalRect();
        Check($"the Wardstone panel takes the initiative list's 368 px box ({ward})",
            Mathf.Abs(ward.Size.X - 368) <= 1 && Mathf.Abs(ward.End.X - (hud.Size.X - 16)) <= 1 && Mathf.Abs(ward.Position.Y - 16) <= 1);
        var member = state.Party.Members[1];
        member.Health.SetCurrentHP(member.Health.MaxHP - 5);
        dungeon.RefreshHud();
        var chip = strip.Chips.First(c => c.MemberId == member.UniqueId);
        Check($"a chip prints current/max HP ('{chip.HealthText}')", chip.HealthText == $"{member.Health.CurrentHP}/{member.Health.MaxHP}");
        chip.EmitSignal(BaseButton.SignalName.Pressed);
        var details = dungeon.GetNode<CharacterDetailsOverlay>("%CharacterDetails");
        var hp = HeroSheetBuilder.Read(member).Headlines.First(h => h.Label == "HP").Value;
        Check($"clicking a chip opens that member's sheet, which shows current/max HP ('{hp}')",
            details.Visible && details.Character == member && hp == $"{member.Health.CurrentHP}/{member.Health.MaxHP}");
        details.Close();
        member.Health.SetCurrentHP(member.Health.MaxHP);
        dungeon.RefreshHud();
        Check("no badge without a pending promotion", strip.Chips.All(c => !c.PromotionBadge));
        await CheckExplorationDyingBadge(dungeon, member);
    }

    /// <summary>The Dying badge keeps its combat size and plate on the exploration camera.</summary>
    private async Task CheckExplorationDyingBadge(DungeonDirector dungeon, PF2e.Core.PF2eCharacter member)
    {
        if (DisplayServer.GetName() == "headless") return;
        var token = dungeon.GetNode<Node3D>("%TravelParty").GetChildren().OfType<UnitVisual3D>().FirstOrDefault(t => t.Character == member);
        if (token == null) { Check("the member has an exploration token", false); return; }
        member.Conditions.AddCondition(PF2e.Conditions.ConditionDatabase.Instance.Dying, value: 1);
        await Frames(3);
        var camera = dungeon.GetNode<OrbitCameraRig>("%ExploreCamera").Camera;
        var rect = token.Dying.ScreenRect(camera);
        var plate = token.Dying.GetNode<MeshInstance3D>("%DyingPlate");
        Check($"the exploration Dying badge keeps the combat size with its plate ({rect}; plate shown {plate.IsVisibleInTree()}, material {plate.MaterialOverride != null}, scale {plate.Scale})",
            rect is { } r && r.Size.Y is >= 26 and <= 32 && plate.IsVisibleInTree() && plate.MaterialOverride != null);
        await Capture("dungeon_run_dying_badge");
        member.Conditions.RemoveCondition(PF2e.Conditions.ConditionDatabase.Instance.Dying);
        member.Conditions.RemoveCondition(PF2e.Conditions.ConditionDatabase.Instance.Unconscious);
        await Frames(2);
    }

    /// <summary>After a won fight the strip badges every member with a feat to choose.</summary>
    private async Task CheckPromotionBadge(DungeonDirector dungeon, RunState state)
    {
        var strip = dungeon.GetNode<DungeonHud>("%DungeonHud").PartyStrip;
        await Frames(2);
        Check($"pending promotions show the strip badge ({strip.Chips.Count(c => c.PromotionBadge)} badges)",
            strip.Chips.Count > 0 && strip.Chips.All(c => c.PromotionBadge));
        await Capture("dungeon_run_party_strip");
        PromotionTestDriver.Complete(state.Party);
        dungeon.RefreshHud();
        Check("after promotion only members with an unspent feat choice keep the badge", strip.Chips.All(c =>
            c.PromotionBadge == CombatResults.HasFeatChoice(state.Party.Members.First(m => m.UniqueId == c.MemberId))));
    }

    /// <summary>Keyboard focus on a door shows the screen-space tooltip in pair style; Enter travels.</summary>
    private async Task CheckDoorTooltip(DungeonDirector dungeon, RunState state, int avoid)
    {
        var hud = dungeon.GetNode<DungeonHud>("%DungeonHud");
        var tip = hud.DoorTip;
        int start = dungeon.Current.Id;
        var camera = dungeon.GetNode<Delve.Combat.OrbitCameraRig>("%ExploreCamera").Camera;
        Vector2 DoorScreen(DoorSide side) => camera.UnprojectPosition(dungeon.CurrentView.ToGlobal(dungeon.CurrentView.DoorPosition(side)));
        bool arrowsFollowScreen = true;
        dungeon._UnhandledInput(new InputEventAction { Action = InputNames.UiFocusNext, Pressed = true });
        foreach (var (action, direction) in new[] { (InputNames.UiRight, Vector2.Right), (InputNames.UiLeft, Vector2.Left),
                     (InputNames.UiUp, Vector2.Up), (InputNames.UiDown, Vector2.Down) })
        {
            var before = dungeon.FocusedDoor!.Value;
            dungeon._UnhandledInput(new InputEventAction { Action = action, Pressed = true });
            var after = dungeon.FocusedDoor!.Value;
            if (after != before && (DoorScreen(after) - DoorScreen(before)).Normalized().Dot(direction) < dungeon.DoorArrowCone)
                arrowsFollowScreen = false;
        }
        Check("each arrow moves door focus only toward a door lying that way on screen", arrowsFollowScreen);
        for (int i = 0; i < dungeon.Current.Doors.Count && Destination(dungeon) == avoid; i++)
            dungeon._UnhandledInput(new InputEventAction { Action = InputNames.UiFocusNext, Pressed = true });
        await PhysicsFrames(2);
        var ward = tip.FigureLabels.FirstOrDefault();
        Check($"Tab focuses a door and the tooltip follows it ('{tip.TitleText}', {ward?.CaptionText} {ward?.BeforeText} → {ward?.ValueText})",
            dungeon.FocusedDoor != null && tip.Visible && ward?.CaptionText == "Ward"
            && ward.BeforeText == state.Wardstone.Ward.ToString()
            && ward.ValueText == (state.Wardstone.Ward - state.Wardstone.Rules.NodeBurn).ToString());
        int smallest = SmallestFont(tip);
        Check($"the door tooltip text is 18 px or larger (smallest {smallest})", smallest >= 18);
        await Capture("dungeon_run_door_tooltip");

        int saved = state.Wardstone.Ward;
        while (state.Wardstone.Ward > state.Wardstone.Rules.NodeBurn) state.Wardstone.BurnNode();
        await PhysicsFrames(2);
        ward = tip.FigureLabels.FirstOrDefault();
        Check($"a crossing that puts the ward out warns ('{tip.BodyText}', Ward {ward?.BeforeText} → {ward?.ValueText})",
            tip.BodyText.Contains(DoorTips.WardOutWarning) && ward?.ValueText == "0");
        state.Wardstone.RefillFull();
        while (state.Wardstone.Ward > saved) state.Wardstone.BurnNode();

        var fight = new DungeonRoom { Id = 99, X = 0, Y = 0, Family = RoomFamily.GuardHall, Seed = 1 };
        var blocked = DoorTips.For(fight, state.Wardstone, new[] { "Aldric", "Elara" });
        Check($"pending promotions before a fight warn in the tooltip ('{blocked.Body}')",
            blocked.Body.Contains($"{DoorTips.FeatsFirstWarning}: Aldric, Elara"));
        Check("an unexplored room keeps its name hidden", blocked.Title == DoorTips.UnexploredTitle);

        dungeon._UnhandledInput(new InputEventAction { Action = InputNames.Confirm, Pressed = true });
        var deadline = DateTime.UtcNow.AddSeconds(20);
        while ((dungeon.Current.Id == start || dungeon.Phase == DungeonPhase.Travel) && DateTime.UtcNow < deadline)
            await Frames(1);
        Check($"Enter travels through the focused door ({start} → {dungeon.Current.Id})", dungeon.Current.Id != start);
    }

    private static int SmallestFont(Node root)
    {
        int smallest = int.MaxValue;
        foreach (var child in root.GetChildren())
        {
            if (child is Label { Visible: true } label && label.Text.Length > 0)
                smallest = Math.Min(smallest, label.GetThemeFontSize("font_size"));
            smallest = Math.Min(smallest, SmallestFont(child));
        }
        return smallest;
    }

    private static int Destination(DungeonDirector dungeon)
    {
        if (dungeon.FocusedDoor is not { } side) return -1;
        return dungeon.Current.Doors.First(d => d.Side(dungeon.Current.Id) == side).Other(dungeon.Current.Id);
    }

    /// <summary>A party wipe goes straight to the run end: no reward screen, no second Defeat.</summary>
    private async Task CheckDefeatGoesToRunEnd(RunDirector run, DungeonDirector dungeon, string[] picks)
    {
        run.NewRun();
        run.ConfirmParty(picks);
        var state = run.State!;
        dungeon.ResolveEvent(0, null);
        dungeon.CloseEvent();
        int target = state.Map.Nodes.First(n => n.Kind == NodeKind.Combat).Id;
        foreach (var room in dungeon.Floor.Rooms.Where(r => r.Id != target)) room.Completed = true;
        var phases = new List<RunPhase>();
        void Record(RunPhase phase) => phases.Add(phase);
        run.PhaseChanged += Record;
        try
        {
            while (dungeon.Current.Id != target && run.Phase == RunPhase.Map) await Step(dungeon, target);
            Check("the fixture reaches a fight", run.Phase == RunPhase.Combat);
            var banner = run.GetChildren().OfType<CombatScene>().Single().GetNode<VictoryBanner>("%VictoryBanner");
            bool bannerSeen = false;
            var deadline = DateTime.UtcNow.AddSeconds(60);
            while (run.Phase == RunPhase.Combat && DateTime.UtcNow < deadline)
            {
                foreach (var member in state.Party.Members)
                    if (member.Health.CurrentHP > 0) member.Health.SetCurrentHP(0);
                bannerSeen |= banner.Visible;
                await Frames(1);
            }
            await Frames(2);
            Check($"a wipe goes straight to the run end ({string.Join(" > ", phases)})", run.Phase == RunPhase.RunEnd
                && state.Outcome == RunOutcome.Defeat && !phases.Contains(RunPhase.CombatResults));
            Check("no combat Defeat banner shows before the run end", !bannerSeen && !banner.Visible);
        }
        finally { run.PhaseChanged -= Record; }
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task PhysicsFrames(int count)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
    }
}
