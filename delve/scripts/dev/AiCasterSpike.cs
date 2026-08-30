using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.AI;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// End-to-end regression for the AI action kit (engine WP: PC planner + spell planning).
/// Each scenario builds a fresh arena (BattleGrid + BattleRunner + AIBattleSimulator wiring),
/// runs ONE AI turn through <see cref="AITurnExecutor"/> for an AI-driven preset PC, and asserts
/// the observable outcome:
///   (a) the Medic (Cleric preset) heals the MOST-wounded living ally — not the barely-scratched
///       one, never a full-HP one;
///   (b) Fenwick (Wizard preset) casts a damage cantrip at an enemy while conserving its
///       slotted spells (judicious-slot heuristic);
///   (c) the Veteran (Fighter preset) plans equipment longsword strikes through the FULL planner
///       (probe: the "[AI] ... executing plan" log line names the plan, whose strike nodes carry
///       the equipment weapon's name — the retired fallback path never logged a plan).
/// Prints [PASS]/[FAIL] per check and a final "SPIKE RESULT: PASS/FAIL", then quits with the
/// matching exit code.
/// </summary>
public partial class AiCasterSpike : SpikeBase
{
    private Action<string>? _priorInfoSink;

    protected override string Banner => "==================== AI CASTER SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();

        // Damage delivery throws without a reaction handler; this scope installs one for the spike.
        using var reactions = UsePassthroughReactions();

        await Scenario_A_MedicHealsMostWounded(data);
        await Scenario_B_FenwickCastsCantrip(data);
        await Scenario_C_VeteranPlansEquipmentStrikes(data);
    }

    // ─────────────────── (a) AI Medic heals the most-wounded ally ───────────────────

    private async Task Scenario_A_MedicHealsMostWounded(DataManager data)
    {
        GD.Print("-- (a) AI Medic: Heal targets the most-wounded ally --");

        var (grid, events, executor) = MakeArena();

        var medic = PresetCharacters.BuildTharr(level: 2, teamId: 1);
        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);   // badly wounded
        var recruit = PresetCharacters.BuildRecruit(level: 2, teamId: 1);   // full HP
        var goblin = MakeGoblin(data);

        grid.PlaceCreature(medic, new PF2eVec(2, 5));
        grid.PlaceCreature(veteran, new PF2eVec(3, 5));
        grid.PlaceCreature(recruit, new PF2eVec(2, 6));
        grid.PlaceCreature(goblin, new PF2eVec(12, 5)); // far away: Medic keeps the Casting strategy
        Register(medic, veteran, recruit, goblin);

        // Wound the Veteran well below the 75% slotted-heal threshold; leave the Recruit at full.
        veteran.Health.TakeDamage(new DamageResult
        {
            TotalDamage = veteran.Health.MaxHP / 2 + 3,
            DamageType = DamageType.Slashing
        });

        int veteranBefore = veteran.Health.CurrentHP;
        int recruitBefore = recruit.Health.CurrentHP;
        int preparedBefore = medic.Spellcasting!.LeveledSpells.Count;

        medic.Actions.RefillActions();
        await executor.ExecuteTurn(medic);

        ICharacter? healedTarget = null;
        int healedAmount = 0;
        foreach (var e in events)
        {
            if (e.Type == BattleEventType.Healed && e.Source == medic)
            {
                healedTarget = e.Target;
                healedAmount = e.IntValue ?? 0;
            }
        }

        Check("(a) AI turn casts Heal (Healed event emitted)", healedTarget != null);
        Check("(a) heal lands on the MOST-wounded ally (the Veteran)",
            ReferenceEquals(healedTarget, veteran));
        Check("(a) the wounded ally's HP increased",
            veteran.Health.CurrentHP > veteranBefore);
        Check("(a) the full-HP ally was not healed",
            recruit.Health.CurrentHP == recruitBefore);
        // Warpriest Medic: Heal is Aveline's divine-font spell, so the cast is paid from
        // the font pool first — the prepared list stays intact until the font is dry.
        Check("(a) the Heal was paid from the divine font (font-first slot routing)",
            medic.Spellcasting.DivineFont?.CurrentSlots == 3
            && medic.Spellcasting.LeveledSpells.Count == preparedBefore);
        GD.Print($"    healed {healedTarget?.Name ?? "nobody"} for {healedAmount} " +
            $"({veteranBefore} -> {veteran.Health.CurrentHP}/{veteran.Health.MaxHP})");
    }

    // ─────────────────── (b) AI Fenwick casts a damage cantrip ───────────────────

    private async Task Scenario_B_FenwickCastsCantrip(DataManager data)
    {
        GD.Print("-- (b) AI Fenwick: casts a damage cantrip at an enemy --");

        var (grid, events, executor) = MakeArena();

        var fenwick = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        grid.PlaceCreature(fenwick, new PF2eVec(5, 5));
        grid.PlaceCreature(goblin, new PF2eVec(9, 5)); // 4 tiles: inside 30 ft, outside melee
        Register(fenwick, goblin);

        int goblinBefore = goblin.Health.CurrentHP;
        int preparedBefore = fenwick.Spellcasting!.LeveledSpells.Count;

        fenwick.Actions.RefillActions();
        await executor.ExecuteTurn(fenwick);

        string? castDescription = null;
        foreach (var e in events)
        {
            if (e.Type == BattleEventType.SpellCast && e.Source == fenwick)
                castDescription = e.Description;
        }

        // No-slot damage casts: the placeholder cantrips, the Battle Magic curriculum
        // cantrip, or Force Bolt (the school focus spell — costs a renewable focus point,
        // not a slot; the AI rightly prefers its higher damage vs a lone goblin).
        bool castNoSlotDamage = castDescription != null
            && (castDescription.Contains("Electric Arc") || castDescription.Contains("Ignition")
                || castDescription.Contains("Frostbite")
                || castDescription.Contains("Telekinetic Projectile")
                || castDescription.Contains("Force Bolt"));

        Check("(b) AI turn casts a spell (SpellCast event emitted)", castDescription != null);
        Check($"(b) the cast is a no-slot damage spell ({castDescription ?? "none"})", castNoSlotDamage);
        Check("(b) slotted spells conserved vs a single enemy (judicious-slot heuristic)",
            fenwick.Spellcasting.LeveledSpells.Count == preparedBefore);
        GD.Print($"    goblin HP {goblinBefore} -> {goblin.Health.CurrentHP} " +
            "(damage depends on the save/attack roll; the cast itself is the assertion)");
    }

    // ─────────────── (c) AI Veteran plans equipment strikes via the planner ───────────────

    private async Task Scenario_C_VeteranPlansEquipmentStrikes(DataManager data)
    {
        GD.Print("-- (c) AI Veteran: equipment longsword strikes through the planner --");

        var (grid, events, executor) = MakeArena();

        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        grid.PlaceCreature(veteran, new PF2eVec(3, 5));
        grid.PlaceCreature(goblin, new PF2eVec(7, 5)); // 4 tiles: one Stride away
        Register(veteran, goblin);

        // Planner probe: the retired fallback never logged "executing plan"; the planner does,
        // and its strike nodes are named after the equipment weapon (PcActionBuilder).
        string? planLine = null;
        _priorInfoSink = Log.OnInfo;
        Log.OnInfo = msg =>
        {
            _priorInfoSink?.Invoke(msg);
            if (msg != null && msg.Contains("executing plan") && msg.Contains(veteran.Name))
                planLine = msg;
        };

        veteran.Actions.RefillActions();
        try
        {
            await executor.ExecuteTurn(veteran);
        }
        finally
        {
            Log.OnInfo = _priorInfoSink;
            _priorInfoSink = null;
        }

        int strikes = 0;
        foreach (var e in events)
        {
            if (e.Type == BattleEventType.AttackRolled && e.Source == veteran)
                strikes++;
        }

        Check("(c) the planner ran for the AI PC (\"executing plan\" logged — no fallback path)",
            planLine != null);
        Check("(c) the plan contains equipment Longsword strikes",
            planLine != null && planLine.Contains("Longsword"));
        Check("(c) strikes resolved through StrikeResolver (AttackRolled events emitted)",
            strikes > 0);
        GD.Print($"    plan: {planLine ?? "NONE"}; strikes rolled: {strikes}");
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private static (BattleGrid grid, List<BattleEvent> events, AITurnExecutor executor) MakeArena()
    {
        Rng.Seed(1234);

        var grid = BattleGrid.CreateFlat(16, 12);
        var events = new List<BattleEvent>();
        var runner = new BattleRunner();
        runner.SetPresenter(evt =>
        {
            events.Add(evt);
            return Task.CompletedTask;
        });

        // AIBattleSimulator wires the grid/flanking delegates and installs fresh
        // TurnManager/CombatantRegistry singletons for this scenario.
        _ = new AIBattleSimulator(grid, runner);

        return (grid, events, new AITurnExecutor(runner, grid));
    }

    private static void Register(params ICharacter[] characters)
    {
        foreach (var c in characters)
            CombatantRegistry.Instance.Register(c);
    }

    private static ICharacter MakeGoblin(DataManager data)
    {
        var def = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        return CreatureFactory.Create(def, teamId: 2);
    }
}
