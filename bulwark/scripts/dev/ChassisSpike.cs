using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.Combat;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the preset-chassis batch: proves the Fighter (Veteran) and Rogue (Scout)
/// presets are mechanically-true PF2e Remaster characters once ClassFeatures + ProficiencyProgressions
/// + CharacterBuildChoices are authored. Each check builds fresh presets, exercises one mechanic, and
/// prints PASS/FAIL; a final SPIKE RESULT line gates the process exit code.
///
/// Checks:
///  (a) Veteran L5 longsword attack bonus == +15 (5 level + 6 Master + 4 Str) — Master weapons @5;
///  (b) Veteran L1 longsword attack bonus == +9  (1 level + 4 Expert + 4 Str) — Expert weapons @1;
///  (c) Bravery (L3+) reduces an incoming Frightened value by 1 (L1 control does not);
///  (d) Scout L2 Sneak Attack adds precision damage vs an off-guard foe (non-off-guard control does not);
///  (e) Scout L1 finesse Strike uses Dex: rapier attack bonus == +7 (Dex +4, not Str +1);
///  (f) Weapon Mastery (L5) is granted with ChosenWeaponGroup=Sword, and a forced sword critical
///      applies the sword crit-spec Off-Guard rider to the target.
/// </summary>
public partial class ChassisSpike : SpikeBase
{
    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== CHASSIS SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[Chassis] DataManager not loaded — aborting.");
            return;
        }

        CheckA_VeteranL5AttackMaster();
        CheckB_VeteranL1AttackExpert();
        CheckC_BraveryReducesFrightened();
        CheckD_ScoutSneakAttackPrecision(data);
        CheckE_ScoutFinesseUsesDex();
        await CheckF_WeaponMasteryCritSpec(data);

        FinishAndQuit("Chassis");
    }

    // ── (a) Veteran L5: Master martial weapons → +15 with the longsword ──

    private void CheckA_VeteranL5AttackMaster()
    {
        GD.Print("-------------------- (a) Veteran L5 attack (Master) --------------------");
        var vet = PresetCharacters.BuildVeteran(level: 5);
        var weapon = vet.Equipment.MainHandWeapon;

        var prof = WeaponAttackCalculator.ResolveWeaponProficiency(
            vet.Stats.CharacterClass, vet.Stats.Level, weapon,
            WeaponGroup.Sword, null, vet.Features);
        int abilityMod = WeaponAttackCalculator.GetAttackAbilityModifier(vet.Stats, weapon);
        int profBonus = ProficiencyCalculator.GetBonus(prof, vet.Stats.Level);
        int total = WeaponAttackCalculator.CalculateAttackBonus(vet, weapon);

        GD.Print($"  [info] L5 longsword: proficiency={prof} profBonus={profBonus} strMod={abilityMod} total={total} (expect +15)");
        Check("(a) L5 martial weapon proficiency is Master", prof == ProficiencyLevel.Master);
        Check("(a) L5 longsword attack bonus == +15", total == 15);
    }

    // ── (b) Veteran L1: Expert martial weapons → +9 with the longsword (M0-verified value) ──

    private void CheckB_VeteranL1AttackExpert()
    {
        GD.Print("-------------------- (b) Veteran L1 attack (Expert) --------------------");
        var vet = PresetCharacters.BuildVeteran(level: 1);
        var weapon = vet.Equipment.MainHandWeapon;

        var prof = WeaponAttackCalculator.ResolveWeaponProficiency(
            vet.Stats.CharacterClass, vet.Stats.Level, weapon,
            WeaponGroup.Sword, null, vet.Features);
        int total = WeaponAttackCalculator.CalculateAttackBonus(vet, weapon);

        GD.Print($"  [info] L1 longsword: proficiency={prof} total={total} (expect +9)");
        Check("(b) L1 martial weapon proficiency is Expert", prof == ProficiencyLevel.Expert);
        Check("(b) L1 longsword attack bonus == +9", total == 9);
    }

    // ── (c) Bravery (L3) reduces incoming Frightened by 1; L1 control does not ──

    private void CheckC_BraveryReducesFrightened()
    {
        GD.Print("-------------------- (c) Bravery vs Frightened --------------------");
        var frightenedDef = ConditionDatabase.Instance?.Frightened;
        if (frightenedDef == null)
        {
            Check("(c) Frightened condition definition available", false);
            return;
        }

        var vetL3 = PresetCharacters.BuildVeteran(level: 3);
        Check("(c) L3 Veteran has Bravery", vetL3.Features?.GetFeatureById("bravery") != null);

        // Bravery's OnConditionApplied listener fires synchronously inside AddCondition.
        vetL3.Conditions.AddCondition(frightenedDef, value: 1);
        int reduced = vetL3.Conditions.GetConditionValue(Condition.Frightened);
        GD.Print($"  [info] L3 applied Frightened 1 → value {reduced} (Bravery should reduce to 0)");
        Check("(c) Bravery reduced Frightened 1 → 0", reduced == 0);

        // Control: an L1 fighter has no Bravery, so Frightened 1 stays 1.
        var vetL1 = PresetCharacters.BuildVeteran(level: 1);
        Check("(c) L1 Veteran does NOT have Bravery", vetL1.Features?.GetFeatureById("bravery") == null);
        vetL1.Conditions.AddCondition(frightenedDef, value: 1);
        int control = vetL1.Conditions.GetConditionValue(Condition.Frightened);
        GD.Print($"  [info] L1 applied Frightened 1 → value {control} (no Bravery, stays 1)");
        Check("(c) L1 control keeps Frightened at 1", control == 1);
    }

    // ── (d) Scout L2 Sneak Attack: precision damage vs an off-guard foe, none vs a control ──

    private void CheckD_ScoutSneakAttackPrecision(DataManager data)
    {
        GD.Print("-------------------- (d) Scout Sneak Attack precision --------------------");
        var offGuardDef = ConditionDatabase.Instance?.OffGuard;
        if (offGuardDef == null)
        {
            Check("(d) OffGuard condition definition available", false);
            return;
        }

        // Off-guard target: apply the global OffGuard condition (satisfies OffGuardHelper.IsOffGuardTo).
        var scout = PresetCharacters.BuildScout(level: 2);
        var rapier = scout.Equipment.MainHandWeapon;
        Check("(d) Scout has Sneak Attack", scout.Features?.GetFeatureById("sneak-attack") != null);

        var goblin = MakeGoblin(data);
        goblin.Conditions.AddCondition(offGuardDef);
        var hit = DamageCalculator.CalculateDamage(scout, rapier, isCritical: false, target: goblin);
        bool precision = HasSneakPrecision(hit);
        GD.Print($"  [info] off-guard hit: total={hit.TotalDamage} sneakPrecision={precision}");
        Check("(d) off-guard Sneak Attack includes precision damage", precision);

        // Control: an identical Scout striking a NON-off-guard goblin gets no precision.
        var scout2 = PresetCharacters.BuildScout(level: 2);
        var goblin2 = MakeGoblin(data);
        var control = DamageCalculator.CalculateDamage(
            scout2, scout2.Equipment.MainHandWeapon, isCritical: false, target: goblin2);
        bool controlPrecision = HasSneakPrecision(control);
        GD.Print($"  [info] control hit: total={control.TotalDamage} sneakPrecision={controlPrecision}");
        Check("(d) non-off-guard control has NO precision damage", !controlPrecision);
    }

    // ── (e) Scout L1 finesse Strike uses Dex (not Str): rapier attack bonus == +7 ──

    private void CheckE_ScoutFinesseUsesDex()
    {
        GD.Print("-------------------- (e) Scout L1 finesse uses Dex --------------------");
        var scout = PresetCharacters.BuildScout(level: 1);
        var rapier = scout.Equipment.MainHandWeapon;

        Check("(e) rapier is a finesse weapon", rapier != null && rapier.IsFinesse);

        int strMod = scout.Stats.GetAbilityModifier(AbilityScore.Strength);   // 12 → +1
        int dexMod = scout.Stats.GetAbilityModifier(AbilityScore.Dexterity);  // 18 → +4
        int attackAbility = WeaponAttackCalculator.GetAttackAbilityModifier(scout.Stats, rapier);
        int total = WeaponAttackCalculator.CalculateAttackBonus(scout, rapier);

        GD.Print($"  [info] L1 rapier: strMod={strMod} dexMod={dexMod} attackAbilityMod={attackAbility} total={total} (expect Dex +4, total +7)");
        Check("(e) finesse attack ability mod is Dex (> Str)", attackAbility == dexMod && dexMod > strMod);
        Check("(e) L1 rapier attack bonus == +7", total == 7);
    }

    // ── (f) Weapon Mastery (L5): sword crit-spec applies Off-Guard to the target ──

    private async Task CheckF_WeaponMasteryCritSpec(DataManager data)
    {
        GD.Print("-------------------- (f) Weapon Mastery crit-spec --------------------");
        var vet = PresetCharacters.BuildVeteran(level: 5, teamId: 1);
        Check("(f) L5 Veteran has Weapon Mastery", vet.Features?.GetFeatureById("weapon-mastery") != null);
        Check("(f) ChosenWeaponGroup is Sword", vet.BuildChoices?.ChosenWeaponGroup == WeaponGroup.Sword);

        // High-HP target (a second L5 Fighter) that survives the crit so the applied Off-Guard rider
        // is observable. Force a natural 20 through the deterministic d20 queue → guaranteed critical.
        var target = PresetCharacters.BuildVeteran(level: 5, teamId: 2);
        var (session, exec) = StartSession(data,
            party: new() { (vet, new PF2eVec(5, 5)) },
            enemies: new() { (target, new PF2eVec(6, 5)) }, seed: 5);
        try
        {
            vet.Actions.RefillActions();
            bool offGuardBefore = target.Conditions.HasCondition(Condition.OffGuard);
            DiceRoller.EnqueueD20(20);
            await exec.ExecuteStrike(vet, target);

            bool offGuardAfter = target.Conditions.HasCondition(Condition.OffGuard);
            GD.Print($"  [info] target off-guard before={offGuardBefore} after={offGuardAfter}; target alive={target.Health.IsAlive}");
            Check("(f) target was not off-guard before the strike", !offGuardBefore);
            Check("(f) target survived the crit (rider is observable)", target.Health.IsAlive);
            Check("(f) sword critical applied the Off-Guard crit-spec rider", offGuardAfter);
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            session.Teardown();
        }
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private static bool HasSneakPrecision(DamageResult dr)
    {
        if (dr?.BonusDamageEntries == null) return false;
        foreach (var e in dr.BonusDamageEntries)
            if (e.Type == DamageType.Precision && e.Source != null && e.Source.StartsWith("Sneak Attack"))
                return true;
        return false;
    }

    private (CombatSession session, PlayerActionExecutor exec) StartSession(
        DataManager data,
        List<(ICharacter, PF2eVec)> party,
        List<(ICharacter, PF2eVec)> enemies,
        int seed)
    {
        var setup = new CombatSetup { GridWidth = 16, GridHeight = 14, RngSeed = seed };
        setup.Party.AddRange(party);
        setup.Enemies.AddRange(enemies);

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        foreach (var (c, _) in party) CombatantRegistry.Instance.Register(c);
        foreach (var (c, _) in enemies) CombatantRegistry.Instance.Register(c);

        return (session, session.PlayerActions);
    }

    private ICharacter MakeGoblin(DataManager data)
    {
        var def = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        return CreatureFactory.Create(def, teamId: 2);
    }
}
