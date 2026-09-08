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
/// Headless regression for the ten-minute activities. Asserts that blocks are priced in ward alone
/// and refused before one could put the ward out, the two Treat Wounds extremes forced through
/// <c>dcOverride</c> (a guaranteed
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

        // (1) No daily cap. Ward is the only cost, and resting stops before it puts the ward out.
        GD.Print("-------------------- (1) Ward is the only cost --------------------");
        var party = BuildParty();
        var clock = new DayClock();
        var wardstone = new Wardstone();

        var taken = new List<ShortRestResult>();
        while (wardstone.CanAffordShortRest)
        {
            taken.Add(ShortRest.Perform(
                party, clock, taken.Count % 2 == 0 ? ShortRestKind.Refocus : ShortRestKind.RepairShield,
                null, rules, wardstone: wardstone));
        }
        int affordable = taken.Count;
        var refused = ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules, wardstone: wardstone);

        bool allAffordablePerformed = true;
        foreach (var block in taken)
            allAffordablePerformed &= block.Performed;

        Check($"(1) the {affordable} blocks the ward pays for are taken, past the old three-a-day cap",
            affordable > 3 && allAffordablePerformed);
        Check($"(1) the clock counted them ({clock.ShortRestsToday})", clock.ShortRestsToday == affordable);
        Check("(1) the day did not roll over on its own", clock.Day == 1);
        Check($"(1) resting never puts the ward out ({wardstone.Ward} left)",
            wardstone.Ward > 0 && !wardstone.IsSpent);
        Check($"(1) the ward left is under one rest ({wardstone.Rules.ShortRestBurn})",
            wardstone.Ward <= wardstone.Rules.ShortRestBurn);
        Check("(1) the next block is refused", !refused.Performed);
        Check($"(1) the refusal says why: '{refused.Reason}'", !string.IsNullOrEmpty(refused.Reason));
        Check("(1) the refused block burns no ward and no time",
            clock.ShortRestsToday == affordable && wardstone.Ward > 0);
        Check("(1) Refocus and Repair Shield produced report lines",
            taken[0].Lines.Count > 0 && taken[1].Lines.Count > 0);

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
