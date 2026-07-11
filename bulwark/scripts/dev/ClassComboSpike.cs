using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents.Contexts;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the four LOCKED class combos (user design):
///  (a) Medic — Cleric (Warpriest) + Aveline + Marshal line: Shield Block at L1, medium armor AC,
///      heal divine-font slots, favored-weapon (scimitar) attack, Marshal aura dedication;
///  (b) Scholar — Wizard (Battle Magic) + Spell Blending + Medic line: curriculum bonus slot per
///      rank (and its non-curriculum rejection), blend trade applied at L5, Force Bolt focus
///      spell, Medicine expert via Medic Dedication, Battle Medicine + Treat Condition;
///  (c) Scout — Rogue (Thief) + Dual-Weapon Warrior line: rapier + agile finesse shortsword,
///      agile MAP on the off-hand, Double Slice granted by the dedication and executable;
///  (d) Veteran — Fighter (Sentinel) + Bastion line: dedication grants Reactive Shield at L2,
///      Disarming Block lands at L4.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class ClassComboSpike : Node
{
    private int _failures;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== CLASS COMBO SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[ComboSpike] DataManager not loaded — aborting.");
            GD.Print("SPIKE RESULT: FAIL");
            GetTree().Quit(1);
            return;
        }

        CheckA_MedicWarpriest();
        CheckB_ScholarBattleMagic();
        await CheckC_ScoutDualWielder(data);
        CheckD_VeteranBastion();

        GD.Print("---------------------------------------------------------");
        bool pass = _failures == 0;
        GD.Print($"[ComboSpike] failures: {_failures}");
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    // ── (a) Medic: Warpriest doctrine + Aveline + Marshal ──

    private void CheckA_MedicWarpriest()
    {
        GD.Print("-------------------- (a) Medic (Warpriest, Aveline, Marshal) --------------------");
        var medic = PresetCharacters.BuildMedic(level: 2);

        Check("(a) resolved class is Warpriest", medic.Stats?.CharacterClass?.ClassName == "Warpriest");
        Check("(a) deity is Aveline", medic.BuildChoices?.Deity?.DefinitionId == "aveline");

        // First Doctrine: Shield Block at L1 + a shield to block with.
        Check("(a) Shield Block granted (First Doctrine, L1)",
            medic.Features?.GetFeatureById("shield-block") != null);
        Check("(a) steel shield equipped", medic.Equipment?.Shield?.EquippedShield != null);

        // Medium armor: breastplate (+4 item, Dex cap +1) at Trained (2 + level 2) → AC 19 at L2.
        var armor = medic.Equipment?.WornArmorDef;
        Check("(a) wearing MEDIUM armor (breastplate)", armor is { Category: ArmorCategory.Medium });
        int ac = StatsCalculator.CalculateAC(medic);
        GD.Print($"  [info] medic L2 AC = {ac} (expect 19 = 10 + trained 4 + item 4 + dex 1)");
        Check("(a) medium-armor AC == 19 (doctrine armor training applied)", ac == 19);

        // Divine font: 4 heal slots at the highest castable rank (1 at L2).
        var font = medic.Spellcasting?.DivineFont;
        Check("(a) divine font pool exists (Heal)", font != null && font.FontSpellIdentity != null);
        Check("(a) font has 4 slots at L2", font is { MaxSlots: 4, CurrentSlots: 4 });
        Check("(a) font rank == highest castable rank (1)", font?.FontRank == 1);
        // The font pays for Heal casts: the Heal action is castable via font identity.
        var heal = PresetSpells.Get(PresetSpells.HealId);
        Check("(a) Heal castable (font identity match)", heal != null && heal.CanPerform(medic));

        // Favored weapon: the equipped scimitar IS Aveline's favored weapon (same instance), and
        // the cleric is Trained with it at L1 while ordinary martial weapons stay untrained at L2.
        var mainHand = medic.Equipment?.MainHandWeapon;
        Check("(a) scimitar equipped", mainHand?.WeaponDef?.ItemName?.ToLower().Contains("scimitar") == true);
        Check("(a) equipped weapon IS the deity's favored weapon (same definition instance)",
            mainHand != null && ReferenceEquals(mainHand.WeaponDef, medic.BuildChoices!.GetFavoredWeapon()));

        int attack = WeaponAttackCalculator.CalculateAttackBonus(medic, mainHand);
        GD.Print($"  [info] medic L2 scimitar attack = +{attack} (expect +5 = 2 level + 2 trained favored + 1 Str)");
        Check("(a) scimitar attack bonus == +5 (favored-weapon training)", attack == 5);

        // Marshal Dedication at L2 (free archetype): granted + skill upgrade. The Medic now
        // trains Diplomacy at build (Inspiring Marshal Stance prerequisite), so the
        // dedication's upgrade path lands on Diplomacy: trained → EXPERT.
        Check("(a) Marshal Dedication granted at L2",
            medic.Features?.GetFeatureById("marshal-dedication") != null);
        Check("(a) Marshal skill upgrade landed (Diplomacy trained → expert)",
            medic.Skills?.GetProficiency(Skill.Diplomacy) == ProficiencyLevel.Expert);

        // Deity granted spells (Remaster Cleric "Deity" class feature): Aveline adds Breathe
        // Fire (R1) and Fireball (R3) to the Medic's spell list despite neither being divine.
        var breatheFire = PresetSpells.Get(PresetSpells.BreatheFireId);
        Check("(a) Breathe Fire on the rank-1 available list (deity grant)",
            medic.Spellcasting!.GetAvailableSpellsForRank(1).Contains(breatheFire));
        Check("(a) L2 medic can PREPARE granted Breathe Fire in a rank-1 slot",
            medic.Spellcasting.PrepareSpells(new List<SpellAction> { heal!, breatheFire }));
        Check("(a) control: non-granted arcane spell (Force Barrage) rejected",
            !medic.Spellcasting.PrepareSpells(
                new List<SpellAction> { PresetSpells.Get(PresetSpells.ForceBarrageId) }));

        // L5: font scales to 5 slots at rank 3; Second Doctrine martial training (L3) is live.
        var medic5 = PresetCharacters.BuildMedic(level: 5);
        var font5 = medic5.Spellcasting?.DivineFont;
        Check("(a) L5 font = 5 slots at rank 3", font5 is { MaxSlots: 5 } && font5.FontRank == 3);
        var martialProf = medic5.Stats!.CharacterClass!.GetWeaponProficiency(
            WeaponCategory.Martial, 5, WeaponGroup.Sword);
        Check("(a) L5 martial weapons Trained (Second Doctrine @3)",
            martialProf == ProficiencyLevel.Trained);

        // Rank-3 grant lands once rank-3 slots exist (L5); it is rank-locked to its grant rank.
        var fireball = PresetSpells.Get(PresetSpells.FireballId);
        Check("(a) L5 medic can PREPARE granted Fireball in a rank-3 slot",
            medic5.Spellcasting!.PrepareSpells(new List<SpellAction> { fireball }));
        Check("(a) Fireball NOT on the rank-1 available list (grant is rank 3)",
            !medic5.Spellcasting.GetAvailableSpellsForRank(1).Contains(fireball));

        // Inspiring Marshal Stance (Marshal Feat 4, free archetype): L2 no, L4+ yes.
        Check("(a) Inspiring Marshal Stance NOT granted at L2",
            medic.Features?.GetFeatureById("inspiring-marshal-stance") == null);
        Check("(a) Inspiring Marshal Stance granted at L4",
            medic5.Features?.GetFeatureById("inspiring-marshal-stance") != null);

        CheckA_InspiringMarshalStance();
    }

    /// <summary>
    /// Behavioral: the Medic enters Inspiring Marshal Stance on a Diplomacy success and the
    /// marshal's aura (15 ft emanation, Remaster Player Core 2) grants +1 STATUS to attack
    /// rolls for allies inside it — not for an ally outside — until the encounter ends.
    /// Runs a real TurnManager encounter (the same StartEncounter path CombatSession uses),
    /// which wires the engine AuraSystem handlers; rolls are forced via the DiceRoller queue.
    /// </summary>
    private void CheckA_InspiringMarshalStance()
    {
        var medic = PresetCharacters.BuildMedic(level: 5);
        var insideAlly = PresetCharacters.BuildScout(level: 5);
        var outsideAlly = PresetCharacters.BuildVeteran(level: 5);
        var enemy = PresetCharacters.BuildVeteran(level: 5, teamId: 2);

        medic.GridPosition = new PF2eVec(5, 5);
        insideAlly.GridPosition = new PF2eVec(5, 7);   // 10 ft — inside the 15 ft aura
        outsideAlly.GridPosition = new PF2eVec(5, 12); // 35 ft — outside
        enemy.GridPosition = new PF2eVec(6, 5);

        var tm = new TurnManager();
        TurnManager.Instance = tm;
        tm.StartEncounterWithFixedOrder(new List<ICharacter> { medic, insideAlly, outsideAlly, enemy });
        try
        {
            var stance = medic.Features!.GetAllGrantedActions()
                .OfType<InspiringMarshalStanceAction>().FirstOrDefault();
            Check("(a) stance feature grants the stance action", stance != null);
            if (stance == null)
                return;

            // No bonus before the stance: the dedication aura alone upgrades nothing on attacks.
            Check("(a) no attack bonus before entering the stance",
                AuraAttackBonus(insideAlly, enemy) == 0);

            // Diplomacy expert L5 (+10) vs easy level DC 18 — forced d20 15 → 25 = success.
            DiceRoller.EnqueueD20(15);
            stance.Execute(medic);
            Check("(a) success enters the stance",
                StanceRules.IsInStance(medic, InspiringMarshalStanceAction.StanceId));

            Check("(a) +1 status to ally attack roll INSIDE 10 ft",
                AuraAttackBonus(insideAlly, enemy) == 1);
            Check("(a) NO bonus to ally attack roll OUTSIDE the aura",
                AuraAttackBonus(outsideAlly, enemy) == 0);
            Check("(a) +1 status to the marshal's own attack roll",
                AuraAttackBonus(medic, enemy) == 1);

            tm.EndEncounter();
            Check("(a) stance ends at encounter end",
                StanceRules.GetActiveStanceId(medic) == null);
            Check("(a) aura benefit gone after encounter end",
                AuraAttackBonus(insideAlly, enemy) == 0);
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            if (tm.IsEncounterActive)
                tm.EndEncounter();
        }
    }

    /// <summary>Publish an attack-roll context through the attacker's bus (the seam the engine's
    /// AttackResolver uses) and report the net typed-modifier total the aura handlers added.</summary>
    private static int AuraAttackBonus(ICharacter attacker, ICharacter defender)
    {
        var ctx = new AttackRollContext
        {
            Attacker = attacker,
            Defender = defender,
            D20Roll = 10,
            BaseAttackBonus = 5,
        };
        attacker.RuleEvents?.Publish(ctx);
        return ctx.Modifiers.Total;
    }

    // ── (b) Scholar: Battle Magic school + Spell Blending + Medic line ──

    private void CheckB_ScholarBattleMagic()
    {
        GD.Print("-------------------- (b) Scholar (Battle Magic, Spell Blending, Medic) --------------------");
        var scholar = PresetCharacters.BuildScholar(level: 2);
        var casting = scholar.Spellcasting!;

        // School bonus slot: L2 wizard has 3 base rank-1 slots + 1 curriculum slot.
        Check("(b) rank-1 max slots == 4 (3 base + 1 school)", casting.GetMaxSlots(1) == 4);
        Check("(b) school bonus slot flagged at rank 1", casting.GetSchoolBonusSlots(1) == 1);
        Check("(b) 4 rank-1 preparations at build (school slot filled with curriculum)",
            casting.LeveledSpells.Count(s => s?.Spell != null && s.Spell.SpellLevel == 1 && !s.Spell.IsFocusSpell) == 4);

        // The school slot REJECTS a non-curriculum spell: 4× Fear cannot be prepared.
        var fear = PresetSpells.Get(PresetSpells.FearId);
        bool rejected = !casting.PrepareSpells(new List<SpellAction> { fear, fear, fear, fear });
        Check("(b) school slot rejects a 4th NON-curriculum preparation", rejected);
        // A curriculum spell in the 4th slot is legal.
        var breatheFire = PresetSpells.Get(PresetSpells.BreatheFireId);
        bool accepted = casting.PrepareSpells(new List<SpellAction> { fear, fear, fear, breatheFire });
        Check("(b) school slot accepts a curriculum spell", accepted);

        // Focus spell: Force Bolt granted with 1 focus point; curriculum cantrip added.
        Check("(b) Force Bolt focus spell granted",
            casting.LeveledSpells.Any(s => s?.SpellId == PresetSpells.ForceBoltId));
        Check("(b) focus pool == 1", casting.MaxFocusPoints == 1 && casting.CurrentFocusPoints == 1);
        Check("(b) curriculum cantrip (Telekinetic Projectile) added",
            casting.Cantrips.Any(c => c?.SpellId == PresetSpells.TelekineticProjectileId));

        // Medic line at L2: Battle Medicine (skill feat) + Medic Dedication → Medicine EXPERT.
        Check("(b) Battle Medicine granted at L2",
            scholar.Features?.GetFeatureById("battle-medicine") != null);
        Check("(b) Medic Dedication granted at L2",
            scholar.Features?.GetFeatureById("medic-dedication") != null);
        Check("(b) Medicine is Expert (trained at build, upgraded by Medic Dedication)",
            scholar.Skills?.GetProficiency(Skill.Medicine) == ProficiencyLevel.Expert);

        // L5: Spell Blending trade applied (2× rank-1 → 1× rank-3) on top of the school slots.
        var scholar5 = PresetCharacters.BuildScholar(level: 5);
        var casting5 = scholar5.Spellcasting!;
        Check("(b) L5 blend trade active", casting5.ActiveBlendTrades.Count == 1);
        GD.Print($"  [info] L5 slots r1={casting5.GetMaxSlots(1)} r2={casting5.GetMaxSlots(2)} r3={casting5.GetMaxSlots(3)}");
        Check("(b) L5 rank-1 max == 2 (3 base − 2 blended + 1 school)", casting5.GetMaxSlots(1) == 2);
        Check("(b) L5 rank-3 max == 4 (2 base + 1 blended + 1 school)", casting5.GetMaxSlots(3) == 4);
        Check("(b) L5 rank-3 prepared with Fireballs (curriculum, incl. school slot)",
            casting5.LeveledSpells.Count(s => s?.SpellId == PresetSpells.FireballId) == 4);
        Check("(b) Treat Condition granted at L4",
            scholar5.Features?.GetFeatureById("treat-condition") != null);
    }

    // ── (c) Scout: Thief racket + dual wield + DWW line ──

    private async Task CheckC_ScoutDualWielder(DataManager data)
    {
        GD.Print("-------------------- (c) Scout (Thief, Dual-Weapon Warrior) --------------------");
        var scout = PresetCharacters.BuildScout(level: 2);

        Check("(c) resolved class is Thief", scout.Stats?.CharacterClass?.ClassName == "Thief");
        Check("(c) Thief racket granted", scout.Features?.GetFeatureById("thief-racket") != null);

        var main = scout.Equipment?.MainHandWeapon;
        var off = scout.Equipment?.OffHandWeapon;
        Check("(c) rapier in main hand", main?.WeaponDef?.ItemName?.ToLower().Contains("rapier") == true);
        Check("(c) shortsword in off hand", off?.WeaponDef?.ItemName?.ToLower().Contains("shortsword") == true);
        Check("(c) off-hand is AGILE and FINESSE", off is { IsAgile: true, IsFinesse: true });

        // Agile MAP: after one attack the off-hand (agile) strikes at −4, non-agile at −5.
        scout.Combat!.IncrementAttackCount();
        Check("(c) agile MAP −4 on the off-hand after one attack",
            scout.Combat.GetCurrentMAP(off!.IsAgile) == -4);
        Check("(c) non-agile MAP −5 control (main hand rapier)",
            scout.Combat.GetCurrentMAP(main!.IsAgile) == -5);
        scout.Combat.ResetTurnState();

        // DWW Dedication at L2 grants Double Slice (Remaster: part of the dedication).
        Check("(c) DWW Dedication granted at L2",
            scout.Features?.GetFeatureById("dual-weapon-warrior-dedication") != null);
        Check("(c) Double Slice granted by the dedication",
            scout.Features?.GetFeatureById("double-slice") != null);
        var doubleSlice = scout.Features?.GetAllGrantedActions().OfType<DoubleSliceAction>().FirstOrDefault();
        Check("(c) Double Slice action surfaced via granted actions", doubleSlice != null);

        // Behavioral: Double Slice = two Strikes for 2 actions, both at the frozen (0) MAP,
        // counting as two attacks afterwards. Target is a tanky L5 fighter that survives.
        var target = PresetCharacters.BuildVeteran(level: 5, teamId: 2);
        var (session, _) = StartSession(data,
            party: new() { (scout, new PF2eVec(5, 5)) },
            enemies: new() { (target, new PF2eVec(6, 5)) }, seed: 11);
        try
        {
            scout.Actions.RefillActions();
            int actionsBefore = scout.Actions.TotalActionsRemaining;
            int hpBefore = target.Health.CurrentHP;

            DiceRoller.EnqueueD20(20); // main-hand strike: guaranteed crit
            DiceRoller.EnqueueD20(20); // off-hand strike: guaranteed crit
            await doubleSlice!.ExecuteAsync(scout, target);

            Check("(c) Double Slice consumed 2 actions",
                actionsBefore - scout.Actions.TotalActionsRemaining == 2);
            Check("(c) both strikes landed (target damaged)", target.Health.CurrentHP < hpBefore);
            Check("(c) Double Slice counts as two attacks for MAP",
                scout.Combat.GetCurrentMAP(false) == -10);
            var record = DoubleSliceAction.GetLastDoubleSlice(scout.UniqueId);
            Check("(c) double-slice record captured (both hit)", record is { BothHit: true });
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            session.Teardown();
        }

        // L5: Dual Thrower (the L4 DWW feat) is granted.
        var scout5 = PresetCharacters.BuildScout(level: 5);
        Check("(c) Dual Thrower granted at L4",
            scout5.Features?.GetFeatureById("dual-thrower") != null);
    }

    // ── (d) Veteran: Bastion line ──

    private void CheckD_VeteranBastion()
    {
        GD.Print("-------------------- (d) Veteran (Sentinel, Bastion) --------------------");
        var vet2 = PresetCharacters.BuildVeteran(level: 2);
        Check("(d) Bastion Dedication granted at L2",
            vet2.Features?.GetFeatureById("bastion-dedication") != null);
        Check("(d) dedication granted Reactive Shield",
            vet2.Features?.GetFeatureById("reactive-shield") != null);
        Check("(d) Disarming Block NOT granted at L2",
            vet2.Features?.GetFeatureById("disarming-block") == null);

        var vet5 = PresetCharacters.BuildVeteran(level: 5);
        Check("(d) Disarming Block granted at L4",
            vet5.Features?.GetFeatureById("disarming-block") != null);
        Check("(d) Reactive Shield still active at L5",
            vet5.Features?.GetFeatureById("reactive-shield") != null);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

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

    private void Check(string label, bool ok)
    {
        if (!ok) _failures++;
        GD.Print($"  [{(ok ? "PASS" : "FAIL")}] {label}");
    }
}
