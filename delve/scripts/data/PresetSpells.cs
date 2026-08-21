using System.Collections.Generic;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Data;
using PF2e.Spellcasting;
using PF2e.Utilities;

namespace Delve.Data;

/// <summary>
/// Code-authored PLACEHOLDER spell list that exercises every lane of the PF2e spell pipeline:
/// spell attacks, basic/effect saves, multi-target, per-degree conditions, cones, and the
/// variable-action-cost Heal (touch / ranged / self-centered emanation).
///
/// Each spell is a <see cref="SpellDefinition"/> wrapped in a <see cref="SpellCastAction"/>. A single
/// canonical instance per spell is built once and registered into <see cref="SpellDatabase"/> via the
/// idempotent <see cref="EnsureRegistered"/>. SpellCastAction holds no per-character state (its only
/// per-cast field, ActiveVariant, is cleared after each synchronous cast), so preset characters share
/// the canonical instances safely — the same way creature abilities are shared across a monster stack.
///
/// PLACEHOLDER numbers: approximate PF2e Remaster values at rank 1 / cantrip-heightened-to-1. Exact
/// fidelity is intentionally NOT required here; these back throwaway placeholder characters.
/// </summary>
public static class PresetSpells
{
    public const string DivineLanceId = "preset-divine-lance";
    public const string ElectricArcId = "preset-electric-arc";
    public const string IgnitionId = "preset-ignition";
    public const string DazeId = "preset-daze";
    public const string FrostbiteId = "preset-frostbite";
    public const string HealId = "preset-heal";
    public const string FearId = "preset-fear";
    public const string BreatheFireId = "preset-breathe-fire";
    public const string TelekineticProjectileId = "preset-telekinetic-projectile";
    public const string ForceBarrageId = "preset-force-barrage";
    public const string ForceBoltId = "preset-force-bolt";
    public const string FireballId = "preset-fireball";

    /// <summary>
    /// Canonical shared identity for Heal. DeityDefinition.FontSpellIdentity and the Heal
    /// SpellDefinition.Identity must be the SAME instance — DivineFontPool.MatchesSpell compares
    /// by reference, which is how a cast of Heal gets routed to divine-font slots.
    /// </summary>
    public static readonly SpellIdentity HealIdentity = new() { SpellName = "Heal" };

    private static bool _registered;
    private static readonly Dictionary<string, SpellCastAction> _byId = new();

    /// <summary>Register the canonical preset spells into SpellDatabase exactly once. Safe to spam.</summary>
    public static void EnsureRegistered()
    {
        if (_registered) return;
        _registered = true;

        var all = new List<SpellCastAction>
        {
            BuildDivineLance(),
            BuildElectricArc(),
            BuildIgnition(),
            BuildDaze(),
            BuildFrostbite(),
            BuildHeal(),
            BuildFear(),
            BuildBreatheFire(),
            BuildTelekineticProjectile(),
            BuildForceBarrage(),
            BuildForceBolt(),
            BuildFireball(),
        };

        foreach (var s in all)
            _byId[s.SpellId] = s;

        // Append into the shared database and re-trigger its lookup rebuild via the singleton setter.
        var db = SpellDatabase.Instance ?? new SpellDatabase();
        db.Spells.AddRange(all);
        SpellDatabase.Instance = db;
    }

    /// <summary>Fetch a canonical preset spell instance by id (registers on first use).</summary>
    public static SpellCastAction Get(string spellId)
    {
        EnsureRegistered();
        return _byId.TryGetValue(spellId, out var spell) ? spell : null!;
    }

    // ─────────────────────────────── Cantrips ───────────────────────────────

    private static SpellCastAction BuildDivineLance() => new()
    {
        SpellId = DivineLanceId,
        ActionName = "Divine Lance",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 }, // range carrier; Type stays None
        Spell = new SpellDefinition
        {
            SpellLevel = 0, // cantrip
            Traditions = new List<SpellcastingTradition> { SpellcastingTradition.Divine },
            DefenseType = SpellDefenseType.SpellAttack,
            DamageFormula = new DiceFormula(1, 4, 0), // PLACEHOLDER numbers
            DamageType = DamageType.Spirit,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(1, 4, 0),
        },
    };

    private static SpellCastAction BuildElectricArc() => new()
    {
        SpellId = ElectricArcId,
        ActionName = "Electric Arc",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 2, // PF2e: up to two creatures
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 0,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Primal },
            DefenseType = SpellDefenseType.BasicSave,
            SaveType = SavingThrow.Reflex,
            DamageFormula = new DiceFormula(1, 4, 0), // PLACEHOLDER numbers
            DamageType = DamageType.Electricity,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(1, 4, 0),
        },
    };

    private static SpellCastAction BuildIgnition() => new()
    {
        SpellId = IgnitionId,
        ActionName = "Ignition",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 0,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Primal },
            DefenseType = SpellDefenseType.SpellAttack,
            DamageFormula = new DiceFormula(2, 4, 0), // PLACEHOLDER numbers (ranged Ignition)
            DamageType = DamageType.Fire,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(1, 4, 0),
        },
    };

    private static SpellCastAction BuildDaze() => new()
    {
        SpellId = DazeId,
        ActionName = "Daze",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 0,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Divine, SpellcastingTradition.Occult },
            DefenseType = SpellDefenseType.BasicSave,
            SaveType = SavingThrow.Will,
            DamageFormula = new DiceFormula(1, 6, 0), // PLACEHOLDER numbers (mental)
            DamageType = DamageType.Mental,
            HeightenIncrement = 2,
            HeightenBonusDamage = new DiceFormula(1, 6, 0),
        },
    };

    private static SpellCastAction BuildFrostbite() => new()
    {
        SpellId = FrostbiteId,
        ActionName = "Frostbite",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 0,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Primal },
            DefenseType = SpellDefenseType.BasicSave,
            SaveType = SavingThrow.Fortitude,
            DamageFormula = new DiceFormula(2, 4, 0), // PLACEHOLDER numbers
            DamageType = DamageType.Cold,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(1, 4, 0),
        },
    };

    // ─────────────────────────────── Rank 1 ───────────────────────────────

    /// <summary>
    /// Heal — three cost variants modelled through <see cref="SpellCostVariant"/>:
    ///   1 action: touch, single ally, 1d8.
    ///   2 action: 30 ft, single ally, 1d8 + 8 flat.
    ///   3 action: 30 ft self-centered emanation, allies only, 1d8.
    /// </summary>
    private static SpellCastAction BuildHeal() => new()
    {
        SpellId = HealId,
        ActionName = "Heal",
        Spell = new SpellDefinition
        {
            // Shared identity + font flag: lets DivineFontPool slots (Aveline's heal font)
            // pay for casts of this spell, and enables the undead-reversal channel rules.
            Identity = HealIdentity,
            IsDivineFontSpell = true,
            SpellLevel = 1,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Divine, SpellcastingTradition.Primal },
            DefenseType = SpellDefenseType.None,
            HealingFormula = new DiceFormula(1, 8, 0), // fallback if no variant is applied
            HeightenIncrement = 1,
            HeightenBonusHealing = new DiceFormula(1, 8, 0),
            CostVariants = new List<SpellCostVariant>
            {
                new SpellCostVariant // [0] Touch
                {
                    Label = "Touch",
                    ActionCost = 1,
                    HealingFormula = new DiceFormula(1, 8, 0), // PLACEHOLDER numbers
                    RangeInFeet = 0,
                    MaxTargets = 1,
                    TargetMode = TargetMode.Allies,
                    CanTargetSelf = true,
                },
                new SpellCostVariant // [1] Ranged
                {
                    Label = "30 ft",
                    ActionCost = 2,
                    HealingFormula = new DiceFormula(1, 8, 8), // PLACEHOLDER numbers (1d8 + 8)
                    RangeInFeet = 30,
                    MaxTargets = 1,
                    TargetMode = TargetMode.Allies,
                    CanTargetSelf = true,
                },
                new SpellCostVariant // [2] Channel (self-centered emanation)
                {
                    Label = "Burst",
                    ActionCost = 3,
                    HealingFormula = new DiceFormula(1, 8, 0), // PLACEHOLDER numbers
                    IsAreaEffect = true,
                    IsSelfCentered = true,
                    CanTargetSelf = true,
                    TargetMode = TargetMode.Allies,
                    Area = new AreaDefinition { Type = AreaType.Emanation, SizeInFeet = 30 },
                },
            },
        },
    };

    /// <summary>Fear — Will save, Frightened 1 / 2 / 3 by degree via ConditionEffect.</summary>
    private static SpellCastAction BuildFear() => new()
    {
        SpellId = FearId,
        ActionName = "Fear",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 1,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Divine, SpellcastingTradition.Occult },
            DefenseType = SpellDefenseType.Save,
            SaveType = SavingThrow.Will,
            ConditionEffect = new SpellConditionEffect
            {
                Condition = ConditionDatabase.Instance?.Frightened,
                ValueOnSuccess = 1,     // PLACEHOLDER numbers
                ValueOnFailure = 2,
                ValueOnCritFailure = 3,
                DurationInRounds = 0,   // Frightened decays by its own value each turn
            },
        },
    };

    /// <summary>
    /// Telekinetic Projectile — Battle Magic curriculum cantrip. Spell attack, 2d6 bludgeoning
    /// (hurled debris), heightened +1d6. PLACEHOLDER-faithful numbers like the other cantrips.
    /// </summary>
    private static SpellCastAction BuildTelekineticProjectile() => new()
    {
        SpellId = TelekineticProjectileId,
        ActionName = "Telekinetic Projectile",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 0,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Occult },
            DefenseType = SpellDefenseType.SpellAttack,
            DamageFormula = new DiceFormula(2, 6, 0),
            DamageType = DamageType.Bludgeoning,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(1, 6, 0),
        },
    };

    /// <summary>
    /// Force Barrage — Battle Magic curriculum rank 1. Unerring force darts (no attack roll, no
    /// save). MVP simplification: fixed 2-action cast = two darts (2d4+2 force) instead of the
    /// RAW 1-3 action scaling; heightened (+2) adds another dart's worth per RAW pacing.
    /// </summary>
    private static SpellCastAction BuildForceBarrage() => new()
    {
        SpellId = ForceBarrageId,
        ActionName = "Force Barrage",
        ActionCostCount = 2,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 120 },
        Spell = new SpellDefinition
        {
            SpellLevel = 1,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Occult },
            DefenseType = SpellDefenseType.None, // auto-hit: full damage, no roll
            DamageFormula = new DiceFormula(2, 4, 2),
            DamageType = DamageType.Force,
            HeightenIncrement = 2,
            HeightenBonusDamage = new DiceFormula(1, 4, 1),
        },
    };

    /// <summary>
    /// Force Bolt — School of Battle Magic initial focus spell. 1 action, unerring force bolt
    /// (1d4+1, no roll), heightened (+2) +1d4+1. IsFocusSpell: consumes a focus point and
    /// auto-heightens with character level.
    /// </summary>
    private static SpellCastAction BuildForceBolt() => new()
    {
        SpellId = ForceBoltId,
        ActionName = "Force Bolt",
        ActionCostCount = 1,
        RequiresTarget = true,
        TargetMode = TargetMode.Enemies,
        MaxTargets = 1,
        Area = new AreaDefinition { RangeInFeet = 30 },
        Spell = new SpellDefinition
        {
            SpellLevel = 1,
            IsFocusSpell = true,
            Traditions = new List<SpellcastingTradition> { SpellcastingTradition.Arcane },
            DefenseType = SpellDefenseType.None, // auto-hit: full damage, no roll
            DamageFormula = new DiceFormula(1, 4, 1),
            DamageType = DamageType.Force,
            HeightenIncrement = 2,
            HeightenBonusDamage = new DiceFormula(1, 4, 1),
        },
    };

    /// <summary>
    /// Fireball — Battle Magic curriculum rank 3 (also Aveline's rank-3 granted spell).
    /// 20 ft burst, basic Reflex, 6d6 fire, heightened (+1) +2d6.
    /// </summary>
    private static SpellCastAction BuildFireball() => new()
    {
        SpellId = FireballId,
        ActionName = "Fireball",
        ActionCostCount = 2,
        RequiresAreaTarget = true,
        TargetMode = TargetMode.Enemies,
        Area = new AreaDefinition { Type = AreaType.Burst, SizeInFeet = 20, RangeInFeet = 500 },
        Spell = new SpellDefinition
        {
            SpellLevel = 3,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Primal },
            DefenseType = SpellDefenseType.BasicSave,
            SaveType = SavingThrow.Reflex,
            DamageFormula = new DiceFormula(6, 6, 0),
            DamageType = DamageType.Fire,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(2, 6, 0),
        },
    };

    /// <summary>Breathe Fire — 15 ft cone, basic Reflex, 2d6 fire.</summary>
    private static SpellCastAction BuildBreatheFire() => new()
    {
        SpellId = BreatheFireId,
        ActionName = "Breathe Fire",
        ActionCostCount = 2,
        RequiresAreaTarget = true,
        TargetMode = TargetMode.Enemies,
        Area = new AreaDefinition { Type = AreaType.Cone, SizeInFeet = 15 },
        Spell = new SpellDefinition
        {
            SpellLevel = 1,
            Traditions = new List<SpellcastingTradition>
                { SpellcastingTradition.Arcane, SpellcastingTradition.Primal },
            DefenseType = SpellDefenseType.BasicSave,
            SaveType = SavingThrow.Reflex,
            DamageFormula = new DiceFormula(2, 6, 0), // PLACEHOLDER numbers
            DamageType = DamageType.Fire,
            HeightenIncrement = 1,
            HeightenBonusDamage = new DiceFormula(1, 6, 0),
        },
    };
}
