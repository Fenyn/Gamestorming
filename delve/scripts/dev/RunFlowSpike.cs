using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;
using RunState = Delve.Run.RunState;

namespace Delve.Dev;

/// <summary>
/// Headless walk of the whole run loop. Drives <see cref="RunDirector"/> through its public entry
/// points - the same methods the screens call - on a fixed seed: confirm a starting character, take
/// three companions in mid-run, fight a Skirmish with every PC handed to the AI, resolve a
/// Happenstance, spend a ten-minute block, take a night's rest, then start over. Asserts the phase
/// after each step and that no member is left down.
/// </summary>
public partial class RunFlowSpike : SpikeBase
{
    private const int RunSeed = 90210;
    private const int CombatTimeoutMs = 240_000;

    /// <summary>The run scene to drive. Assigned in run_flow_spike.tscn.</summary>
    [Export] public PackedScene? RunScene { get; set; }

    private TaskCompletionSource<RunPhase>? _leftCombat;

    protected override string Banner => "==================== RUN FLOW SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (RunScene == null)
        {
            AbortFail("[RunFlow] RunScene is not assigned - aborting.");
            return;
        }

        var director = RunScene.Instantiate<RunDirector>();
        director.Seed = RunSeed;
        // No input exists headless: every PC plays itself.
        director.AutoPlayCombat = true;
        AddChild(director);
        director.PhaseChanged += OnPhaseChanged;

        // ---------------------------------------------------- (1) hero select
        Check("(1) a fresh director opens on hero select", director.Phase == RunPhase.HeroSelect);

        // A run starts with the leader alone - the screen confirms no companions at all.
        director.ConfirmParty(PresetCharacters.PlayerId, System.Array.Empty<string>());
        var state = director.State;
        Check("(1) confirming the starting character opens the map", director.Phase == RunPhase.Map);
        Check("(1) the run carries a state, a party of one and a map",
            state != null && state.Party.Members.Count == 1 && state.Map.Nodes.Count > 0);
        if (state == null)
        {
            Fail();
            return;
        }

        // ---------------------------------------------------- (1b) companions join mid-run
        var unlocks = new UnlockState();
        var party = state.Party;
        Check("(1b) a companion joins the party", party.AddMember(PresetCharacters.ElaraId, unlocks));
        Check("(1b) the newcomer is built and on the roll",
            party.Members.Count == 2 && party.Find(PresetCharacters.ElaraId) != null);
        Check("(1b) the same companion cannot join twice",
            !party.AddMember(PresetCharacters.ElaraId, unlocks));
        Check("(1b) the leader cannot join as a companion",
            !party.AddMember(PresetCharacters.PlayerId, unlocks));
        Check("(1b) an unknown id is refused", !party.AddMember("nobody", unlocks));
        Check("(1b) a locked character is refused",
            !party.AddMember(PresetCharacters.TharrId, new UnlockState(new[] { PresetCharacters.PlayerId })));

        party.AddMember(PresetCharacters.TharrId, unlocks);
        party.AddMember(PresetCharacters.FenwickId, unlocks);
        Check($"(1b) the party fills at {Party.MaxSize}", party.IsFull && party.Members.Count == Party.MaxSize);
        Check("(1b) a full party takes nobody else",
            !party.AddMember(PresetCharacters.RecruitId, unlocks));

        // ---------------------------------------------------- (2) a fight
        int? skirmish = FirstReachable(state, NodeKind.Combat);
        Check("(2) a Skirmish is reachable from the entrance", skirmish != null);
        if (skirmish != null)
        {
            _leftCombat = new TaskCompletionSource<RunPhase>(TaskCreationOptions.RunContinuationsAsynchronously);
            director.PickNode(skirmish.Value);
            Check("(2) picking a Skirmish starts the fight", director.Phase == RunPhase.Combat);

            var finished = await Task.WhenAny(_leftCombat.Task, Task.Delay(CombatTimeoutMs));
            Check("(2) the fight finished inside the timeout", finished == _leftCombat.Task);
            Check($"(2) the run returns to the map ({director.Phase})", director.Phase == RunPhase.Map);
            Check("(2) the node is marked visited", state.CurrentNode is { Visited: true });
            Check("(2) every member walks off the field alive on 1 HP or better", AllStanding(state));
        }

        // ---------------------------------------------------- (3) a Happenstance
        var happenstance = FindNode(state, NodeKind.Event);
        Check("(3) the map holds a Happenstance", happenstance != null);
        if (happenstance != null)
        {
            director.OpenEvent(happenstance);
            Check("(3) the event screen opens", director.Phase == RunPhase.Event);

            director.PickEventOption(0, state.Party.Members[0]);
            Check("(3) the event stays open to show its result", director.Phase == RunPhase.Event);
            Check("(3) resolving it leaves nobody down", AllStanding(state));

            director.CloseEvent();
            Check("(3) Continue returns to the map", director.Phase == RunPhase.Map);
        }

        // ---------------------------------------------------- (4) ten minutes
        int blocksBefore = state.Clock.ShortRestsUsed;
        director.TakeShortRest(ShortRestKind.TreatWounds, null);
        Check("(4) the ten-minute screen opened", director.Phase == RunPhase.ShortRest);
        Check($"(4) one block was spent ({blocksBefore} -> {state.Clock.ShortRestsUsed})",
            state.Clock.ShortRestsUsed == blocksBefore + 1);
        director.CloseShortRest();
        Check("(4) Back returns to the map", director.Phase == RunPhase.Map);

        // ---------------------------------------------------- (5) a night's rest
        int day = state.Clock.Day;
        director.OpenRest();
        Check("(5) the Campsite screen opens", director.Phase == RunPhase.Rest);
        director.Rest();
        Check($"(5) the night's rest advances the day ({day} -> {state.Clock.Day})",
            state.Clock.Day == day + 1);
        Check("(5) the ten-minute budget is full again", state.Clock.ShortRestsUsed == 0);
        Check("(5) resting returns to the map", director.Phase == RunPhase.Map);

        // ---------------------------------------------------- (6) run end, then a second run
        director.EndRun(RunOutcome.Victory);
        Check("(6) ending the run shows the summary", director.Phase == RunPhase.RunEnd);
        Check("(6) the outcome is recorded", state.Outcome == RunOutcome.Victory);

        director.NewRun();
        Check("(6) a new run reopens hero select", director.Phase == RunPhase.HeroSelect);
        Check("(6) the finished run is dropped", director.State == null);

        // Leave the tree the way a host would, so the fight releases the engine globals.
        director.PhaseChanged -= OnPhaseChanged;
        RemoveChild(director);
        director.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private void OnPhaseChanged(RunPhase phase)
    {
        GD.Print($"[RunFlow] phase -> {phase}");
        if (phase != RunPhase.Combat)
            _leftCombat?.TrySetResult(phase);
    }

    /// <summary>Every member alive and above 0 HP - the no-permadeath contract after a fight.</summary>
    private static bool AllStanding(RunState state)
    {
        foreach (var member in state.Party.Members)
        {
            if (member.Health == null || member.Health.IsDead || member.Health.CurrentHP < 1)
                return false;
        }
        return true;
    }

    /// <summary>Id of a reachable node of this kind, or null.</summary>
    private static int? FirstReachable(RunState state, NodeKind kind)
    {
        foreach (int id in state.Reachable())
        {
            var node = state.Map.Node(id);
            if (node != null && node.Kind == kind) return id;
        }
        return null;
    }

    /// <summary>Any node of this kind anywhere on the map, or null.</summary>
    private static MapNode? FindNode(RunState state, NodeKind kind)
    {
        foreach (var node in state.Map.Nodes)
        {
            if (node.Kind == kind) return node;
        }
        return null;
    }
}
