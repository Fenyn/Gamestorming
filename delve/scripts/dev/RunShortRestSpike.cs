using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the ten-minute activities. Asserts the day budget (three blocks, the
/// fourth refused), the two Treat Wounds extremes forced through <c>dcOverride</c> (a guaranteed
/// critical success heals and clears Wounded; a guaranteed critical failure damages but can never
/// push a member below 1 HP), and that Refocus and Repair Shield run over the preset party without
/// throwing.
/// </summary>
public partial class RunShortRestSpike : SpikeBase
{
    private const int PartyLevel = 2;

    protected override string Banner => "==================== RUN SHORT REST SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        // The d20 behind every check comes from the engine's global Rng; a natural 1 at DC 0 would
        // downgrade a forced success, so the roll is pinned.
        Rng.Seed(1234);

        var rules = new RecoveryRules();

        // (1) Budget: three blocks a day, the fourth refused.
        GD.Print("-------------------- (1) Day budget --------------------");
        var party = BuildParty();
        var clock = new DayClock();

        var first = ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules);
        var second = ShortRest.Perform(party, clock, ShortRestKind.RepairShield, null, rules);
        var third = ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules);
        var fourth = ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules);

        Check("(1) three ten-minute blocks are taken",
            first.Performed && second.Performed && third.Performed);
        Check("(1) the fourth is refused", !fourth.Performed);
        Check($"(1) the refusal says why: '{fourth.Reason}'", !string.IsNullOrEmpty(fourth.Reason));
        Check("(1) the budget is spent, not overspent", clock.ShortRestsUsed == clock.ShortRestsPerDay);
        Check("(1) Refocus and Repair Shield produced report lines",
            first.Lines.Count > 0 && second.Lines.Count > 0);

        // (2) Treat Wounds, forced critical success.
        GD.Print("-------------------- (2) Treat Wounds, DC 0 --------------------");
        var healed = BuildParty();
        var patient = healed.Members[1];
        var wounded = ConditionDatabase.Instance?.Wounded;

        // Down the patient and stabilize it so the engine grants Wounded the way a fight would.
        patient.Health.TakeDamage(Physical(patient.Health.MaxHP));
        patient.Health.Heal(1);
        Check("(2) the patient starts Wounded at 1 HP",
            patient.Health.CurrentHP == 1 && Value(patient, wounded) >= 1);

        var success = ShortRest.Perform(healed, new DayClock(), ShortRestKind.TreatWounds, patient, rules, dcOverride: 0);
        Check("(2) the block was taken", success.Performed);
        Check($"(2) DC 0 forces a success ({success.Degree})",
            success.Degree == DegreeOfSuccess.Success || success.Degree == DegreeOfSuccess.CriticalSuccess);
        Check($"(2) the patient healed ({patient.Health.CurrentHP} HP)", patient.Health.CurrentHP > 1);
        Check("(2) Wounded is removed", Value(patient, wounded) == 0);

        // (3) Treat Wounds, forced critical failure on a 1-HP target.
        GD.Print("-------------------- (3) Treat Wounds, DC 99 --------------------");
        var botched = BuildParty();
        var victim = botched.Members[1];
        victim.Health.SetCurrentHP(1);

        var failure = ShortRest.Perform(botched, new DayClock(), ShortRestKind.TreatWounds, victim, rules, dcOverride: 99);
        Check("(3) the block was taken", failure.Performed);
        Check($"(3) DC 99 forces a critical failure ({failure.Degree})",
            failure.Degree == DegreeOfSuccess.CriticalFailure);
        Check("(3) the botch never pushes the target below 1 HP", victim.Health.CurrentHP == 1);
        Check("(3) the target is still alive and not dying",
            !victim.Health.IsDead && !victim.Conditions.HasCondition(Condition.Dying));

        // (4) Refocus and Repair Shield actually move their resources.
        GD.Print("-------------------- (4) Refocus / Repair Shield --------------------");
        var resourced = BuildParty();
        var caster = FindFocusCaster(resourced);
        var shieldBearer = FindShieldBearer(resourced);

        if (caster != null) caster.Spellcasting!.ConsumeFocusPoint();
        if (shieldBearer != null) shieldBearer.Equipment!.Shield.SetCurrentShieldHP(1);

        int focusBefore = caster?.Spellcasting?.CurrentFocusPoints ?? 0;
        var refocus = ShortRest.Perform(resourced, new DayClock(), ShortRestKind.Refocus, null, rules);
        var repair = ShortRest.Perform(resourced, new DayClock(), ShortRestKind.RepairShield, null, rules);

        Check("(4) Refocus ran", refocus.Performed);
        Check("(4) Repair Shield ran", repair.Performed);
        Check("(4) the party has a focus caster", caster != null);
        if (caster != null)
        {
            Check($"(4) a focus point came back ({focusBefore} -> {caster.Spellcasting!.CurrentFocusPoints})",
                caster.Spellcasting.CurrentFocusPoints > focusBefore);
        }
        Check("(4) the party has a shield bearer", shieldBearer != null);
        if (shieldBearer != null)
        {
            var shield = shieldBearer.Equipment!.Shield;
            Check($"(4) the shield is repaired ({shield.CurrentShieldHP}/{shield.MaxShieldHP})",
                shield.CurrentShieldHP == shield.MaxShieldHP);
        }

        return Task.CompletedTask;
    }

    private static Party BuildParty() => Party.Build(
        PresetCharacters.PlayerId,
        new List<string> { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId },
        new UnlockState(),
        PartyLevel);

    private static PF2eCharacter? FindFocusCaster(Party party)
    {
        foreach (var member in party.Members)
        {
            if (member.Spellcasting != null && member.Spellcasting.CurrentFocusPoints > 0) return member;
        }
        return null;
    }

    private static PF2eCharacter? FindShieldBearer(Party party)
    {
        foreach (var member in party.Members)
        {
            if (member.Equipment?.Shield?.EquippedShield != null) return member;
        }
        return null;
    }

    private static int Value(PF2eCharacter member, ConditionDefinition? def) =>
        def == null ? 0 : member.Conditions.GetConditionValue(def);

    private static DamageResult Physical(int amount) =>
        new DamageResult { TotalDamage = amount, DamageType = DamageType.Slashing };
}
