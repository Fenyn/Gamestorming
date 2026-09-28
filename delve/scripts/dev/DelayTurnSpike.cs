using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the Delay action. Part one drives <see cref="CombatSession"/> directly:
/// the first party member who is not last delays until after the last combatant of the round,
/// waits in the delayed pool, resumes right after that combatant with a full turn in the same
/// round, and keeps the slot next round. Part two drives the real HUD with pushed input on a
/// <see cref="CombatScene"/>: the Delay hotkey turns the later turn chips into a pick, Esc cancels
/// it, a click on a chip delays, the waiting chip sits after its anchor, the ally comes back at
/// that slot, and after a move the button is closed with the "first thing this turn" reason. The
/// last actor of a round can Delay into the next round and returns after an early actor there.
/// Captures the waiting state to <see cref="OutputDirectory"/>.
/// </summary>
public partial class DelayTurnSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export] public string OutputDirectory { get; set; } = "user://dev_shots";

    private const float TurnWaitSeconds = 30f;

    protected override string Banner => "==================== DELAY TURN SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        await RunSessionPart(data);
        if (CombatScene == null) { AbortFail("[DelayTurn] CombatScene not assigned."); return; }
        DirAccess.MakeDirRecursiveAbsolute(OutputDirectory);
        await RunHudPart(data);
    }

    // ---------------------------------------------------------------- Part one: session

    private async Task RunSessionPart(DataManager data)
    {
        GD.Print("-------------------- session --------------------");
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        // A long board: the goblins need several rounds to reach anyone, so nothing dies mid-test.
        var setup = new CombatSetup
        {
            GridWidth = 60, GridHeight = 10, RngSeed = 4,
            Party =
            {
                (PresetCharacters.BuildPlayer(level: 2, teamId: 1), new PF2eVec(3, 3)),
                (PresetCharacters.BuildElara(level: 2, teamId: 1), new PF2eVec(3, 5)),
                (PresetCharacters.BuildTharr(level: 2, teamId: 1), new PF2eVec(3, 7)),
                (PresetCharacters.BuildFenwick(level: 2, teamId: 1), new PF2eVec(2, 5)),
            },
        };
        for (int i = 0; i < 3; i++)
            setup.Enemies.Add((CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(56, 3 + i * 2)));

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        ICharacter? delayer = null;
        ICharacter? anchor = null;
        string? blockedAtStart = "unchecked";
        bool waitingSeen = false;
        ICharacter? waitingAnchor = null;
        int delayerTurns = 0;
        var actors = new List<string>();
        int resumeSlot = -1, anchorSlotAtResume = -2, actionsAtResume = 0, roundAtResume = 0;
        string beforeResume = "";
        string? resumedReason = null;
        int round2Slot = -1, anchorSlotRound2 = -2, roundAtRound2 = 0;

        session.TurnChanged += () =>
        {
            actors.Add(session.CurrentActor?.Name ?? "?");
            if (delayer != null && session.IsDelayed(delayer))
            {
                waitingSeen = true;
                waitingAnchor = session.DelayedEntries?[0].ReturnAfter;
            }
        };
        session.PlayerTurnStarted += c =>
        {
            if (delayer == null)
            {
                var order = session.TurnOrder!;
                if (order[^1].Character == c) { session.RequestEndPlayerTurn(); return; }
                delayer = c;
                anchor = order[^1].Character;
                blockedAtStart = session.DelayBlockedReason(c);
                GD.Print($"[DelayTurn] {c.Name} delays until after {anchor.Name} (order {Order(session)})");
                session.RequestDelay(anchor);
                return;
            }
            if (c == delayer)
            {
                delayerTurns++;
                if (delayerTurns == 1)
                {
                    resumeSlot = Slot(session, c);
                    anchorSlotAtResume = Slot(session, anchor!);
                    actionsAtResume = c.Actions?.TotalActionsRemaining ?? 0;
                    roundAtResume = session.RoundNumber;
                    beforeResume = actors.Count >= 2 ? actors[^2] : "";
                    resumedReason = session.DelayBlockedReason(c);
                    GD.Print($"[DelayTurn] {c.Name} resumes at slot {resumeSlot} (order {Order(session)})");
                }
                else if (delayerTurns == 2)
                {
                    round2Slot = Slot(session, c);
                    anchorSlotRound2 = Slot(session, anchor!);
                    roundAtRound2 = session.RoundNumber;
                }
            }
            session.RequestEndPlayerTurn();
        };

        using var cts = new CancellationTokenSource();
        _ = session.RunAsync(cts.Token);
        try
        {
            float waited = 0f;
            while (delayerTurns < 2 && waited < TurnWaitSeconds)
            {
                await WaitSeconds(0.1f);
                waited += 0.1f;
            }
            Check("[session] a party member could delay at the start of their turn", delayer != null && blockedAtStart == null);
            Check($"[session] while waiting the delayer is in the delayed pool, anchored to {anchor?.Name}",
                waitingSeen && waitingAnchor == anchor);
            Check($"[session] the delayer resumes right after the anchor ({beforeResume} then {delayer?.Name}, slot {resumeSlot} after {anchorSlotAtResume})",
                delayerTurns >= 1 && beforeResume == anchor?.Name && resumeSlot == anchorSlotAtResume + 1);
            Check($"[session] the resumed turn is in the same round with a full turn ({actionsAtResume} actions, round {roundAtResume})",
                actionsAtResume == 3 && roundAtResume == 1);
            Check($"[session] the resumed turn cannot Delay again ('{resumedReason}')",
                resumedReason == CombatSession.ResumedTurnReason);
            Check($"[session] the new slot is permanent (round {roundAtRound2}, slot {round2Slot} after {anchorSlotRound2})",
                roundAtRound2 == 2 && round2Slot == anchorSlotRound2 + 1);
        }
        finally
        {
            cts.Cancel();
            session.Teardown();
        }
    }

    private static int Slot(CombatSession session, ICharacter c)
    {
        var order = session.TurnOrder;
        if (order == null) return -1;
        for (int i = 0; i < order.Count; i++)
            if (order[i].Character == c) return i;
        return -1;
    }

    private static string Order(CombatSession session)
    {
        var names = new List<string>();
        foreach (var entry in session.TurnOrder ?? new List<PF2e.TurnManagement.TurnEntry>())
            names.Add(entry.Character.Name);
        return string.Join(",", names);
    }

    // ---------------------------------------------------------------- Part two: HUD

    private async Task RunHudPart(DataManager data)
    {
        GD.Print("-------------------- hud --------------------");
        var scene = CombatScene!.Instantiate<CombatScene>();
        AddChild(scene);
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;

        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var delayBtn = bar.GetNode<Button>("%DelayButton");
        var hint = bar.Decision.GetNode<Label>("%TargetingHint");
        var row = scene.GetNode<TurnOrderBar>("%TurnOrderBar").GetNode<BoxContainer>("%Row");
        var input = scene.GetNode<GridInput3D>("%GridInput");

        bool started = false;
        for (int seed = 1; seed <= 12 && !started; seed++)
        {
            scene.StartEncounter(new CombatSetup
            {
                GridWidth = 32, GridHeight = 10, RngSeed = seed,
                Party =
                {
                    (PresetCharacters.BuildFenwick(level: 2, teamId: 1), new PF2eVec(3, 5)),
                    (PresetCharacters.BuildElara(level: 2, teamId: 1), new PF2eVec(3, 3)),
                },
                Enemies = { (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(29, 5)) },
            });
            await WaitForPlayerTurn(scene);
            if (!scene.IsPlayerTurn) continue;
            await WaitSeconds(0.5f);
            if (!delayBtn.Disabled) { started = true; break; }
        }
        Check("[hud] the first ally to act can Delay", started);
        if (!started) return;

        string ally = bar.ActorName;
        bar._UnhandledInput(new InputEventAction { Action = InputNames.Delay, Pressed = true });
        await Frames(2);
        var picks = PickableChips(row);
        Check($"[hud] the Delay hotkey offers the later chips as a pick ({picks.Count} chips, hint '{hint.Text}')",
            picks.Count > 0 && hint.Text == "Act after" && bar.Decision.CancelKeyVisible);
        Check("[hud] every offered chip comes after the active one", AllAfterActive(row));

        input._UnhandledInput(new InputEventAction { Action = InputNames.UiCancel, Pressed = true });
        await Frames(2);
        Check($"[hud] Esc cancels the pick ({PickableChips(row).Count} chips offered, hint '{hint.Text}')",
            PickableChips(row).Count == 0 && hint.Text != "Act after" && !bar.Decision.CancelKeyVisible);

        bar._UnhandledInput(new InputEventAction { Action = InputNames.Delay, Pressed = true });
        await Frames(2);
        picks = PickableChips(row);
        if (picks.Count == 0) { AbortFail("[DelayTurn] no chips offered on the second Delay press."); return; }
        // The first later chip: the delayer keeps someone after it, so its next fresh turn can Delay again.
        var chosen = picks[0];
        string anchorName = ChipName(chosen);
        Click(chosen.GetGlobalRect().GetCenter());
        await WaitSeconds(0.5f);

        Check($"[hud] clicking {anchorName} ends {ally}'s turn now", bar.ActorName != ally || !scene.IsPlayerTurn);
        int anchorIndex = ChipIndex(row, anchorName);
        int waitingIndex = ChipIndex(row, "~ " + ally);
        Check($"[hud] the waiting chip sits right after its anchor (chips: {ChipNames(row)})",
            waitingIndex >= 0 && waitingIndex == anchorIndex + 1);
        Capture("delay_turn_waiting.png");

        await WaitForAllyTurn(scene, bar, ally);
        int activeIndex = ActiveIndex(row);
        Check($"[hud] {ally} returns as the active chip right after {anchorName} (chips: {ChipNames(row)})",
            activeIndex >= 0 && ChipName(row.GetChild(activeIndex)) == ally && PreviousChipName(row, activeIndex) == anchorName);
        Check($"[hud] the resumed turn opens with Delay closed (a turn only delays once; tooltip '{delayBtn.TooltipText}')",
            delayBtn.Disabled && delayBtn.TooltipText.Contains(CombatSession.ResumedTurnReason));

        // Spend an action on the resumed turn: the button must stay closed with the acted reason
        // on a later turn of this ally. Use the next fresh turn for that.
        bar._UnhandledInput(new InputEventAction { Action = InputNames.EndTurn, Pressed = true });
        for (float waited = 0; ActorName(scene) == ally && waited < TurnWaitSeconds; waited += 0.25f)
            await WaitSeconds(0.25f);
        await WaitForAllyTurn(scene, bar, ally);
        Check($"[hud] a fresh turn re-opens Delay ('{delayBtn.TooltipText}', chips: {ChipNames(row)})",
            scene.IsPlayerTurn && !delayBtn.Disabled);
        if (scene.HoverSteepestBandTile(out Vector3 world) || scene.HoverBandTile(1, out world))
        {
            scene.ClearHover();
            var camera = GetViewport().GetCamera3D();
            var screen = camera.UnprojectPosition(world);
            Push(new InputEventMouseMotion { Position = screen, GlobalPosition = screen });
            await Frames(3);
            Click(screen);
            await WaitSeconds(2.5f);
            Check($"[hud] after a move Delay is closed with the acted reason ('{delayBtn.TooltipText}')",
                delayBtn.Disabled && delayBtn.TooltipText.Contains("first thing"));
        }
        else
        {
            Check("[hud] a band tile was available to move to", false);
        }
        await RunLastActorCase(scene, bar, delayBtn, row, goblinDef);
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task WaitSeconds(float seconds)
    {
        var timer = GetTree().CreateTimer(seconds);
        await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
