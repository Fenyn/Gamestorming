using System;
using System.Collections.Generic;
using PF2e.Actions;
using PF2e.Actions.SkillActions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>How the player turn resolves a skill chip once its target is picked.</summary>
internal enum SkillExecutionMode
{
    /// <summary>No target: the chip fires at once (Parry, Reload).</summary>
    Self,
    /// <summary>Pick a creature tile; the generic skill executor resolves it.</summary>
    Tile,
    /// <summary>Pick a destination tile; the move executor resolves it (Shielded Stride).</summary>
    MoveTile,
    /// <summary>Pick a foe tile; the charge executor repositions then strikes (Sudden Charge).</summary>
    ChargeTile,
}

/// <summary>
/// Everything the player turn must know about one skill / maneuver / feat action chip: its engine
/// action, its targeting rule, its gating text and how it resolves.
/// </summary>
internal sealed record SkillActionDefinition
{
    /// <summary>Chip id used by the action bar and the controller ("trip", "sudden-charge").</summary>
    internal required string Id { get; init; }

    /// <summary>
    /// ActionName of the granting feature's action, for feat actions only. Null marks a basic action
    /// every combatant may attempt. <see cref="SkillActionCatalog.IdForGrantedAction"/> maps it back.
    /// </summary>
    internal string? GrantedActionName { get; init; }

    /// <summary>How the player picks what the chip affects.</summary>
    internal required TargetingKind Kind { get; init; }

    /// <summary>How the chip resolves once a target is picked.</summary>
    internal required SkillExecutionMode Mode { get; init; }

    /// <summary>
    /// Builds a per-call engine action instance. These SkillActionBase subclasses ship WITHOUT
    /// cost/target metadata (it's a construction-site concern), so the factory configures it: all
    /// cost 1; Trip/Demoralize target enemies; Battle Medicine targets allies including self. The
    /// engine maneuver/feat actions author their own name/cost/traits in their constructors.
    /// </summary>
    internal required Func<BaseAction> Factory { get; init; }

    /// <summary>
    /// Radius the chip scans for creature targets, in tiles. Null when the chip picks no creature
    /// (self actions and Shielded Stride, whose tiles come from the movement executor).
    /// </summary>
    internal Func<ICharacter, int>? RangeTiles { get; init; }

    /// <summary>True to scan foes, false to scan allies (the actor included).</summary>
    internal bool TargetsEnemies { get; init; } = true;

    /// <summary>Extra per-candidate rule on top of the range scan. Null keeps every candidate.</summary>
    internal Func<SkillActions, ICharacter, ICharacter, bool>? TargetFilter { get; init; }

    /// <summary>
    /// Why the legal-target set is empty, for the chip tooltip. Recall Knowledge and Battle Medicine
    /// read the board here to disambiguate "nobody in range" from "everyone in range filtered out"
    /// (attempted species / already-treated allies) — both facts the player already owns.
    /// </summary>
    internal required Func<ICharacter, string> NoTargetReason { get; init; }
}

/// <summary>
/// The single place that knows each skill chip. Add an action here and the action bar, the
/// targeting, the gating text, the executor dispatch and the controller all follow.
/// </summary>
internal static class SkillActionCatalog
{
    /// <summary>
    /// Every chip, basic actions first in action-bar order. Trip/Demoralize/Battle Medicine/Recall
    /// Knowledge (skills) and Shove/Tumble Through/Seek (maneuvers) target another creature;
    /// Parry/Reload are self-actions. Lunge/Sudden Charge/Shielded Stride are feat-granted.
    /// </summary>
    internal static readonly IReadOnlyList<SkillActionDefinition> All = new[]
    {
        new SkillActionDefinition
        {
            Id = "trip",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new TripAction
            {
                ActionName = "Trip", ActionCostCount = 1,
                RequiresTarget = true, TargetMode = TargetMode.Enemies
            },
            RangeTiles = _ => 1,
            NoTargetReason = _ => "No adjacent foe",
        },
        new SkillActionDefinition
        {
            Id = "demoralize",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new DemoralizeAction
            {
                ActionName = "Demoralize", ActionCostCount = 1,
                RequiresTarget = true, TargetMode = TargetMode.Enemies
            },
            RangeTiles = _ => 6, // 30 ft
            NoTargetReason = _ => "No foes within 30 ft",
        },
        new SkillActionDefinition
        {
            Id = "battle-medicine",
            Kind = TargetingKind.SingleAlly,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new BattleMedicineAction
            {
                ActionName = "Battle Medicine", ActionCostCount = 1,
                RequiresTarget = true, TargetMode = TargetMode.Allies, CanTargetSelf = true
            },
            RangeTiles = _ => 1,
            TargetsEnemies = false,
            TargetFilter = (_, actor, t) => !BattleMedicineAction.IsImmune(actor.UniqueId, t.UniqueId),
            NoTargetReason = actor => CombatantQuery.AnyTargetInRange(actor, 1, enemies: false)
                ? "Everyone in reach already treated"
                : "No ally within reach",
        },
        new SkillActionDefinition
        {
            Id = "recall-knowledge",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new RecallKnowledgeAction
            {
                ActionName = "Recall Knowledge", ActionCostCount = 1,
                RequiresTarget = true, TargetMode = TargetMode.Enemies,
                Description = "Study a foe to fill in its bestiary page. The skill follows the creature's "
                    + "type; one attempt per species each encounter, win or lose.",
            },
            // 30 ft (the Demoralize precedent). RAW gives each character ONE attempt per creature per
            // encounter, and knowledge is per-SPECIES here, so a foe whose species this actor already
            // studied this fight drops out of the target set — the Battle Medicine immunity filter is
            // the same shape. With every species studied the plan is empty, which greys the chip out.
            RangeTiles = _ => 6,
            TargetFilter = (skills, actor, t) =>
            {
                string? creatureId = t.CreatureStats?.CreatureId;
                return string.IsNullOrEmpty(creatureId)
                    || skills.HasRecallAttempted?.Invoke(actor.UniqueId, creatureId!) != true;
            },
            NoTargetReason = actor => CombatantQuery.AnyTargetInRange(actor, 6, enemies: true)
                ? "Already attempted every species in range this fight"
                : "No foes within 30 ft",
        },
        new SkillActionDefinition
        {
            Id = "shove",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new ShoveAction(),
            RangeTiles = _ => 1, // Athletics maneuver — adjacent foe.
            NoTargetReason = _ => "No adjacent foe",
        },
        new SkillActionDefinition
        {
            Id = "tumble-through",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new TumbleThroughAction(),
            // Adjacent foe with a legal exit tile — the tile continuing the actor->foe straight line,
            // one full footprint beyond. Simplification: only that single collinear exit is considered
            // (matches TumbleThroughAction.ComputeExitPosition); diagonal re-routes are not offered.
            // If that exit is off-grid/blocked/occupied the foe is not a legal target.
            RangeTiles = _ => 1,
            TargetFilter = (skills, actor, t) => skills.HasValidTumbleExit(actor, t),
            NoTargetReason = _ => "No adjacent foe with an open exit tile",
        },
        new SkillActionDefinition
        {
            Id = "seek",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new SeekAction(),
            // Locate a Hidden/Undetected foe. In the current prototype nothing makes enemies
            // Hidden/Undetected, so this is normally empty (chip disabled) — wired for correctness.
            RangeTiles = _ => 12,
            TargetFilter = (_, _, t) => t.Conditions?.HasCondition(Condition.Hidden) == true
                || t.Conditions?.HasCondition(Condition.Undetected) == true,
            NoTargetReason = _ => "No hidden or undetected foes in range",
        },
        new SkillActionDefinition
        {
            Id = "parry",
            Kind = TargetingKind.SelfArea,
            Mode = SkillExecutionMode.Self,
            Factory = () => new ParryAction(),
            NoTargetReason = _ => "No valid targets in range",
        },
        new SkillActionDefinition
        {
            Id = "reload",
            Kind = TargetingKind.SelfArea,
            Mode = SkillExecutionMode.Self,
            Factory = () => new ReloadAction(),
            NoTargetReason = _ => "No valid targets in range",
        },
        new SkillActionDefinition
        {
            Id = "lunge",
            GrantedActionName = "Lunge",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.Tile,
            Factory = () => new LungeAction(),
            // +5 ft of reach.
            RangeTiles = actor => WeaponAttackCalculator.ResolveWeapon(actor).GetRangeInTiles() + 1,
            NoTargetReason = _ => "No foes within extended reach",
        },
        new SkillActionDefinition
        {
            Id = "sudden-charge",
            GrantedActionName = "Sudden Charge",
            Kind = TargetingKind.SingleEnemy,
            Mode = SkillExecutionMode.ChargeTile,
            Factory = () => new SuddenChargeAction(),
            // Any foe you could plausibly reach with a double Stride (2x Speed) and then Strike.
            RangeTiles = actor =>
            {
                var weapon = WeaponAttackCalculator.ResolveWeapon(actor);
                int reach = weapon.IsMelee ? weapon.GetRangeInTiles() : 1;
                return MovementActions.SpeedInTiles(actor) * 2 + reach;
            },
            NoTargetReason = _ => "No foes within charge range",
        },
        new SkillActionDefinition
        {
            Id = "shielded-stride",
            GrantedActionName = "Shielded Stride",
            Kind = TargetingKind.SelfArea,
            Mode = SkillExecutionMode.MoveTile,
            // Never instantiated for the bar: the chip's action comes from the granting feature.
            Factory = () => new ShieldedStrideAction(),
            NoTargetReason = _ => "No reachable tiles",
        },
    };

    private static readonly Dictionary<string, SkillActionDefinition> ById = BuildById();

    /// <summary>Basic actions in action-bar order (everything not granted by a feature).</summary>
    internal static readonly IReadOnlyList<SkillActionDefinition> Basic = BuildBasic();

    /// <summary>The definition for a chip id, or null when the id is unknown.</summary>
    internal static SkillActionDefinition? Get(string id)
        => id != null && ById.TryGetValue(id, out var def) ? def : null;

    /// <summary>The chip id a feature-granted action maps to, or null when the action has no chip.</summary>
    internal static string? IdForGrantedAction(string actionName)
    {
        foreach (var def in All)
        {
            if (def.GrantedActionName == actionName) return def.Id;
        }
        return null;
    }

    private static Dictionary<string, SkillActionDefinition> BuildById()
    {
        var map = new Dictionary<string, SkillActionDefinition>();
        foreach (var def in All) map[def.Id] = def;
        return map;
    }

    private static List<SkillActionDefinition> BuildBasic()
    {
        var list = new List<SkillActionDefinition>();
        foreach (var def in All)
        {
            if (def.GrantedActionName == null) list.Add(def);
        }
        return list;
    }
}
