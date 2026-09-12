using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Core;
using PF2e.Data;
using RunState = Delve.Run.RunState;

namespace Delve.Dev;

/// <summary>Walk a full party through a guest fight and an explicit companion swap.</summary>
public partial class RunMeetingSpike : SpikeBase
{
    // Shared opening regression seed with RunFlowSpike. Random attrition balance is separate.
    private const int RunSeed = 90210;
    private const int CombatTimeoutMs = 240_000;

    /// <summary>The run scene to drive. Assigned in run_meeting_spike.tscn.</summary>
    [Export] public PackedScene? RunScene { get; set; }

    private TaskCompletionSource<RunPhase>? _leftCombat;

    protected override string Banner => "==================== RUN MEETING SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (RunScene == null)
        {
            AbortFail("[RunMeeting] RunScene is not assigned - aborting.");
            return;
        }

        CheckReplacementRules();

        var director = RunScene.Instantiate<RunDirector>();
        director.Seed = RunSeed;
        director.AutoPlayCombat = true;
        AddChild(director);
        director.PhaseChanged += OnPhaseChanged;

        director.ConfirmParty(PresetCharacters.PlayerId, new[] { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId });
        var state = director.State;
        if (state == null)
        {
            AbortFail("[RunMeeting] the run did not start.");
            return;
        }

        // ---------------------------------------------------- (1) the pool
        var pool = state.Recruits;
        Check("(1) the pool holds only characters outside the starting party",
            pool.Order.Count == CharacterCatalog.All.Count - Party.MaxSize);
        Check("(1) the leader is not in the pool", !pool.Order.Contains(PresetCharacters.PlayerId));
        Check("(1) the first meeting is the first available guest",
            pool.Next(state.Party) == pool.Order[0]);

        // ---------------------------------------------------- (2) the map
        var cfg = new RunMapConfig();
        int wayfarers = 0;
        foreach (var node in state.Map.Nodes)
        {
            if (node.Kind == NodeKind.Meeting) wayfarers++;
        }
        Check($"(2) the map carries one or two optional Wayfarers ({wayfarers})",
            wayfarers >= cfg.MinMeetingsPerFloor && wayfarers <= cfg.MaxMeetingsPerFloor);

        // Put the meeting on a reachable fresh-party fixture. Ordinary opener and paid
        // recovery behavior are covered by RunFlowSpike; this spike owns the guest transition.
        int entrance = state.Reachable()[0];
        state.Map.Node(entrance)!.Kind = NodeKind.Meeting;
        state.Xp = state.Leveling.XpPerLevel - 1; // Guarantee a victory levels party and guest in place.

        string? expected = pool.Next(state.Party);
        if (!await Walk(director, state, NodeKind.Meeting, "(4) the first Wayfarer")) return;
        Check("(4) a surviving guest offers a swap", director.Phase == RunPhase.Meetup);
        director.ReplaceCompanion(PresetCharacters.PlayerId);
        Check("(4) leader cannot be replaced", director.Phase == RunPhase.Meetup);
        director.ReplaceCompanion(PresetCharacters.ElaraId);
        director.ReplaceCompanion(PresetCharacters.TharrId);
        director.DeclineMeetup();
        Check("(4) late repeated choices leave the party unchanged", state.Party.Find(PresetCharacters.TharrId) != null);
        Check("(4) choosing a companion returns to map", director.Phase == RunPhase.Map);
        Check($"(4) the Wayfarer joins ({expected})",
            expected != null && state.Party.Find(expected) != null);
        Check("(4) the party stays four", state.Party.Members.Count == 4);
        Check("(4) the newcomer is on the party's level",
            state.Party.Find(expected!)?.Stats?.Level == state.Party.Level);

        // ---------------------------------------------------- (5) the pool moves on
        string? second = pool.Next(state.Party);
        Check($"(5) the next meeting is somebody else ({second})",
            second != null && second != expected);
        Check("(5) the joined character is not offered again",
            pool.Next(state.Party) != expected);

        // Guest membership must not alter the permanent unlock set.
        Check("(6) meeting follows the leader POV", expected != null && director.Campaign.HasPersonalProgress(state.Party.LeaderId, $"met/{expected}"));
        Check("(6) guest fight does not count as party membership", expected != null && RecruitmentCatalog.Find(expected)!.Steps.Where(step => step.Signal == RecruitmentSignal.PartyVictory).All(step => director.Campaign.RecruitmentCount(expected, step.Id) == 0));
        Check("(6) the guest is still locked", expected != null && !pool.Unlocks.IsUnlocked(expected));
        Check("(6) the dismissed companion cannot be met", !pool.Order.Contains(PresetCharacters.ElaraId));
        director.PhaseChanged -= OnPhaseChanged;
        RemoveChild(director);
        director.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    /// <summary>
    /// Step onto a reachable node of this kind (any kind when null) and wait out a fight if one
    /// starts. False when nothing of the kind is reachable or the run left the map.
    /// </summary>
    private async Task<bool> Walk(RunDirector director, RunState state, NodeKind? kind, string label)
    {
        int? target = null;
        foreach (int id in state.Reachable())
        {
            var node = state.Map.Node(id);
            if (node != null && (kind == null || node.Kind == kind.Value)) { target = id; break; }
        }
        Check($"{label} is reachable", target != null);
        if (target == null) return false;

        _leftCombat = new TaskCompletionSource<RunPhase>(TaskCreationOptions.RunContinuationsAsynchronously);
        director.PickNode(target.Value);
        if (director.Phase == RunPhase.Event) director.CloseEvent();
        else if (director.Phase == RunPhase.Rest) director.Rest();
        if (director.Phase != RunPhase.Combat) return director.Phase == RunPhase.Map;

        var finished = await Task.WhenAny(_leftCombat.Task, Task.Delay(CombatTimeoutMs));
        Check($"{label} finished inside the timeout", finished == _leftCombat.Task);
        Check($"{label} shows combat rewards", director.Phase == RunPhase.CombatResults);
        director.ContinueCombatResults();
        Check($"{label} returns to the map ({director.Phase})", director.Phase is RunPhase.Map or RunPhase.Meetup);
        return director.Phase is RunPhase.Map or RunPhase.Meetup;
    }

    private void CheckReplacementRules()
    {
        var unlocks = new UnlockState();
        var party = Party.Build(PresetCharacters.PlayerId,
            new[] { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, unlocks, Party.DefaultLevel);
        var pool = new RecruitPool(party, unlocks);
        var draw = pool.Draw(party);
        Check("(7) a full party draws a locked guest", draw != null && !unlocks.IsUnlocked(draw.Value.Id));
        if (draw is not { } guest) return;
        var leader = party.Members[0];
        var def = CharacterCatalog.Find(guest.Id)!;
        var wrongLevel = def.Builder(party.Level + 1);
        Check("(7) wrong level refused without mutation", !party.ReplaceCompanion(PresetCharacters.ElaraId, guest.Id, wrongLevel) && party.Find(PresetCharacters.ElaraId) != null);
        var dead = def.Builder(party.Level);
        dead.Health!.TakeDamage(new DamageResult { TotalDamage = dead.Health.MaxHP * 2 + 10, DamageType = DamageType.Slashing });
        Check("(7) dead guest refused", dead.Health.IsDead && !party.ReplaceCompanion(PresetCharacters.ElaraId, guest.Id, dead));
        guest.Character.Health!.SetCurrentHP(3);
        Check("(7) invalid outgoing member is refused", !party.ReplaceCompanion("unknown", guest.Id, guest.Character));
        Check("(7) leader replacement is refused", !party.ReplaceCompanion(party.LeaderId, guest.Id, guest.Character));
        Check("(7) locked guest can replace companion", party.ReplaceCompanion(PresetCharacters.ElaraId, guest.Id, guest.Character));
        Check("(7) fought instance and wounds retained", ReferenceEquals(party.Find(guest.Id), guest.Character) && guest.Character.Health.CurrentHP == 3);
        Check("(7) size and leader retained", party.Members.Count == 4 && ReferenceEquals(leader, party.Members[0]));
        Check("(7) repeated guest is refused", !party.ReplaceCompanion(PresetCharacters.TharrId, guest.Id, guest.Character));
        Check("(7) swap never unlocks guest", !unlocks.IsUnlocked(guest.Id));
        pool.Resolve(guest.Id);
        pool.Resolve(PresetCharacters.ElaraId);
        Check("(7) resolved and dismissed guests stay unavailable", pool.Next(party) != guest.Id && pool.Next(party) != PresetCharacters.ElaraId);
        if (pool.Draw(party) is { } declined)
        {
            pool.Resolve(declined.Id);
            Check("(7) declined guest is not offered again", pool.Next(party) != declined.Id);
        }
    }

    private void OnPhaseChanged(RunPhase phase)
    {
        GD.Print($"[RunMeeting] phase -> {phase}");
        if (phase != RunPhase.Combat)
            _leftCombat?.TrySetResult(phase);
    }
}
