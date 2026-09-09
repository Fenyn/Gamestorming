using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;
using RunState = Delve.Run.RunState;

namespace Delve.Dev;

/// <summary>
/// Headless walk of recruitment. A run opens with the leader alone, fights the entrance Skirmish,
/// then takes the Wayfarer row above it: the drawn character fights as an AI ally on team 1 and
/// joins on the win. Asserts the pool order, the join, and that the pool moves on to the next
/// character afterwards. Walking on to the second Wayfarer row is left out: a two-member party can
/// legitimately wipe on the way, and the join is what this spike is for.
/// </summary>
public partial class RunMeetingSpike : SpikeBase
{
    private const int RunSeed = 12345;
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

        var director = RunScene.Instantiate<RunDirector>();
        director.Seed = RunSeed;
        director.AutoPlayCombat = true;
        AddChild(director);
        director.PhaseChanged += OnPhaseChanged;

        director.ConfirmParty(PresetCharacters.PlayerId, System.Array.Empty<string>());
        var state = director.State;
        if (state == null)
        {
            AbortFail("[RunMeeting] the run did not start.");
            return;
        }

        // ---------------------------------------------------- (1) the pool
        var pool = state.Recruits;
        Check("(1) the pool holds every character but the leader",
            pool.Order.Count == CharacterCatalog.All.Count - 1);
        Check("(1) the leader is not in the pool", !pool.Order.Contains(PresetCharacters.PlayerId));
        Check("(1) the first meeting is the first catalog entry after the leader",
            pool.Next(state.Party) == pool.Order[0]);

        // ---------------------------------------------------- (2) the map
        var cfg = new RunMapConfig();
        var rows = cfg.MeetingFloorsFor(0);
        Check("(2) floor 1 has at least two Wayfarer rows", rows.Count >= 2);
        int wayfarers = 0;
        foreach (var node in state.Map.Nodes)
        {
            if (node.Kind == NodeKind.Meeting) wayfarers++;
        }
        Check($"(2) the map carries Wayfarer nodes ({wayfarers})", wayfarers > 0);

        // ---------------------------------------------------- (3) the entrance fight
        if (!await Walk(director, state, NodeKind.Combat, "(3) the entrance Skirmish")) return;
        Check("(3) the party is still alone", state.Party.Members.Count == 1);

        // ---------------------------------------------------- (4) the first Wayfarer
        string? expected = pool.Next(state.Party);
        if (!await Walk(director, state, NodeKind.Meeting, "(4) the first Wayfarer")) return;
        Check($"(4) the Wayfarer joins ({expected})",
            expected != null && state.Party.Find(expected) != null);
        Check("(4) the party is two", state.Party.Members.Count == 2);
        Check("(4) the newcomer is on the party's level",
            state.Party.Find(expected!)?.Stats?.Level == state.Party.Level);

        // ---------------------------------------------------- (5) the pool moves on
        string? second = pool.Next(state.Party);
        Check($"(5) the next meeting is somebody else ({second})",
            second != null && second != expected);
        Check("(5) the joined character is not offered again",
            pool.Next(state.Party) != expected);

        // ---------------------------------------------------- (6) a full party meets nobody
        var full = Party.Build(
            PresetCharacters.PlayerId,
            new[] { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId },
            new UnlockState(), Party.DefaultLevel);
        Check("(6) a full party draws no Wayfarer", new RecruitPool(full, new UnlockState()).Draw(full) == null);
        Check("(6) a locked character stays out of the pool",
            new RecruitPool(state.Party, new UnlockState(new[] { PresetCharacters.PlayerId })).Order.Count == 0);

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
        Check($"{label} returns to the map ({director.Phase})", director.Phase == RunPhase.Map);
        return director.Phase == RunPhase.Map;
    }

    private void OnPhaseChanged(RunPhase phase)
    {
        GD.Print($"[RunMeeting] phase -> {phase}");
        if (phase != RunPhase.Combat)
            _leftCombat?.TrySetResult(phase);
    }
}
