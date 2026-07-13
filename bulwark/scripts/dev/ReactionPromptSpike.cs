using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.Combat;
using Bulwark.Presets;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for interactive reaction prompts (no real UI): installs a scripted async
/// <see cref="CombatSession.ReactionPromptHandler"/> that delays a frame before answering, proving
/// the combat pipeline genuinely SUSPENDS on the prompt and resumes with the choice.
///
/// Checks: (1) an accepted Shield Block prompt (answered after a frame delay) reduces delivered
/// damage by the shield's hardness and dings the shield's HP — and no damage lands while the
/// prompt is pending; (2) a declined prompt delivers full damage and leaves shield + reaction
/// untouched; (3) a prompt raised DURING AN ENEMY TURN (goblin strike vs the raised shield)
/// suspends the enemy's turn until answered, and the turn sequence continues correctly afterwards.
/// Prints per-check PASS/FAIL and a SPIKE RESULT line.
/// </summary>
public partial class ReactionPromptSpike : SpikeBase
{
    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== REACTION PROMPT SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[PromptSpike] DataManager not loaded — aborting.");
            return;
        }

        await Check1_AcceptedPromptSuspendsAndBlocks(data);
        await Check2_DeclinedPromptTakesFullDamage(data);
        await Check3_PromptDuringEnemyTurn(data);

        FinishAndQuit("PromptSpike");
    }

    // ── (1) Accepted prompt: combat suspends while pending, then Shield Block applies ──

    private async Task Check1_AcceptedPromptSuspendsAndBlocks(DataManager data)
    {
        GD.Print("---------------- (1) Accept: suspend + Shield Block ----------------");
        var vet = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);
        var session = StartSession(data, vet, goblin, seed: 42);
        try
        {
            vet.Equipment!.RaiseShield(vet);
            int hardness = vet.Equipment.EquippedShield?.Hardness ?? 0;
            int shieldHpBefore = vet.Equipment.CurrentShieldHP;
            int hpBefore = vet.Health!.CurrentHP;
            Check("(1) shield raised with non-zero hardness", vet.Equipment.IsShieldRaised && hardness > 0);

            Task? delivery = null;
            bool promptSeen = false;
            bool suspendedWhilePending = false;

            session.ReactionPromptHandler = async view =>
            {
                promptSeen = true;
                Check("(1) prompt view names the reactor + reaction",
                    view.ReactorName == vet.Name && view.ReactionName == "Shield Block");
                Check("(1) prompt description mentions absorption", view.Description.Contains("Absorb"));

                // Delay a full frame before answering — combat must be parked on this Task.
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

                suspendedWhilePending = delivery is { IsCompleted: false }
                                        && vet.Health.CurrentHP == hpBefore
                                        && vet.Actions!.ReactionAvailable;
                return true; // Use
            };

            delivery = ReactionEvents.DeliverDamage(goblin, vet, Physical(10));
            Check("(1) delivery Task is pending while the prompt is unanswered", !delivery.IsCompleted);
            await delivery;

            Check("(1) the prompt was actually shown", promptSeen);
            Check("(1) while pending: no damage applied, reaction unspent", suspendedWhilePending);
            Check($"(1) accepted: damage reduced by hardness ({10 - hardness} taken)",
                hpBefore - vet.Health.CurrentHP == 10 - hardness);
            Check($"(1) shield HP dinged by {10 - hardness}",
                vet.Equipment.CurrentShieldHP == shieldHpBefore - (10 - hardness));
            Check("(1) Shield Block consumed the reaction", !vet.Actions!.ReactionAvailable);
        }
        finally { session.Teardown(); }
    }

    // ── (2) Declined prompt: full damage, nothing spent ──

    private async Task Check2_DeclinedPromptTakesFullDamage(DataManager data)
    {
        GD.Print("---------------- (2) Decline: full damage ----------------");
        var vet = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);
        var session = StartSession(data, vet, goblin, seed: 7);
        try
        {
            vet.Equipment!.RaiseShield(vet);
            int shieldHpBefore = vet.Equipment.CurrentShieldHP;
            int hpBefore = vet.Health!.CurrentHP;

            session.ReactionPromptHandler = async view =>
            {
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                return false; // Skip
            };

            await ReactionEvents.DeliverDamage(goblin, vet, Physical(10));

            Check("(2) declined: full 10 damage delivered", hpBefore - vet.Health.CurrentHP == 10);
            Check("(2) shield untouched", vet.Equipment.CurrentShieldHP == shieldHpBefore);
            Check("(2) reaction NOT spent on decline", vet.Actions!.ReactionAvailable);
        }
        finally { session.Teardown(); }
    }

    // ── (3) Prompt mid-ENEMY-turn: the goblin's turn suspends; turn order continues after ──

    private async Task Check3_PromptDuringEnemyTurn(DataManager data)
    {
        GD.Print("---------------- (3) Prompt during an enemy turn ----------------");

        bool scenarioRan = false;
        foreach (int seed in new[] { 3, 5, 11, 42, 99, 123, 500, 7, 1, 2 })
        {
            var vet = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
            var goblin = MakeGoblin(data);

            var setup = new CombatSetup { GridWidth = 12, GridHeight = 10, RngSeed = seed };
            setup.Party.Add((vet, new PF2eVec(5, 5)));
            setup.Enemies.Add((goblin, new PF2eVec(6, 5))); // adjacent — the goblin will strike

            var session = new CombatSession();
            session.Setup(setup);
            session.SetPresenter(_ => Task.CompletedTask);
            try
            {
                vet.Equipment!.RaiseShield(vet);

                bool promptHappened = false;
                bool promptedDuringEnemyTurn = false;
                bool enemyTurnStillCurrentAfterResume = false;
                int turnsAfterFirstPrompt = 0;
                int totalTurns = 0;

                session.ReactionPromptHandler = async view =>
                {
                    var actorAtPrompt = session.CurrentActor;
                    bool enemyTurn = actorAtPrompt != null && !session.IsPlayerControlled(actorAtPrompt);

                    await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

                    if (!promptHappened)
                    {
                        promptHappened = true;
                        promptedDuringEnemyTurn = enemyTurn;
                        // After the frame delay the enemy's turn must still be the current one —
                        // suspension did not let the turn loop advance past the goblin.
                        enemyTurnStillCurrentAfterResume = session.CurrentActor == actorAtPrompt;
                    }
                    return true; // Use Shield Block
                };

                // The veteran never acts: re-raise the shield (consumes nothing here — direct call)
                // and immediately end its turn so the goblin swings every round.
                session.PlayerTurnStarted += _ =>
                {
                    vet.Equipment.RaiseShield(vet);
                    session.RequestEndPlayerTurn();
                };

                // Cap the fight: after enough turns, put the goblin down so RunAsync ends cleanly
                // (a raised steel shield can absorb goblin hits forever).
                session.TurnChanged += () =>
                {
                    totalTurns++;
                    if (promptHappened) turnsAfterFirstPrompt++;
                    if (totalTurns >= 40 && goblin.Health is { IsDead: false })
                        goblin.Health.TakeDamage(new DamageResult
                        {
                            TotalDamage = 999, DamageType = DamageType.Slashing
                        });
                };

                BattleResult result = BattleResult.InProgress;
                session.EncounterFinished += r => result = r;

                await session.RunAsync();

                if (!promptHappened)
                    continue; // goblin never landed a hit with this seed — try the next

                scenarioRan = true;
                Check("(3) a Shield Block prompt fired during the encounter", promptHappened);
                Check("(3) the prompt fired during the ENEMY's turn", promptedDuringEnemyTurn);
                Check("(3) the enemy's turn stayed current across the suspension",
                    enemyTurnStillCurrentAfterResume);
                Check("(3) the turn sequence continued after the prompt resolved",
                    turnsAfterFirstPrompt >= 1);
                Check("(3) the encounter still reached a decisive result",
                    result != BattleResult.InProgress);
                break;
            }
            finally { session.Teardown(); }
        }

        Check("(3) scenario produced a prompt across the seed sweep", scenarioRan);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private static CombatSession StartSession(DataManager data, ICharacter pc, ICharacter enemy, int seed)
    {
        var setup = new CombatSetup { GridWidth = 12, GridHeight = 10, RngSeed = seed };
        setup.Party.Add((pc, new PF2eVec(5, 5)));
        setup.Enemies.Add((enemy, new PF2eVec(6, 5)));

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        // Direct-delivery checks don't run the turn loop; register combatants ourselves.
        CombatantRegistry.Instance!.Register(pc);
        CombatantRegistry.Instance.Register(enemy);
        return session;
    }

    private ICharacter MakeGoblin(DataManager data)
    {
        var def = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        return CreatureFactory.Create(def, teamId: 2);
    }

    private static DamageResult Physical(int amount) =>
        new DamageResult { TotalDamage = amount, DamageType = DamageType.Slashing };
}
