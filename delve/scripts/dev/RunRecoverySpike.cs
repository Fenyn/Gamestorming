using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the run's out-of-combat healing (design/core_concept.md "After a fight"
/// and "Day and time"). One member is dropped to dying and one is killed outright by massive damage;
/// <see cref="PartyRecovery.CompleteEncounter"/> must bring BOTH back at 1 HP, alive, Wounded at
/// least 1. <see cref="PartyRecovery.LongRest"/> must then clear Wounded, heal, advance the day and
/// hand the short-rest budget back.
/// </summary>
public partial class RunRecoverySpike : SpikeBase
{
    private const int PartyLevel = 2;

    protected override string Banner => "==================== RUN RECOVERY SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        var party = Party.Build(
            PresetCharacters.PlayerId,
            new List<string> { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId },
            new UnlockState(),
            PartyLevel);

        var clock = new DayClock();
        var dying = party.Members[1];
        var slain = party.Members[2];
        var healthy = party.Members[0];

        // (1) Down one member into the dying pipeline and kill another outright.
        GD.Print("-------------------- (1) Down and kill --------------------");
        dying.Health.TakeDamage(Physical(dying.Health.MaxHP));
        slain.Health.TakeDamage(Physical(slain.Health.MaxHP * 2 + 10));

        Check("(1) the downed member is at 0 HP and Dying",
            dying.Health.CurrentHP == 0 && dying.Conditions.HasCondition(Condition.Dying));
        Check("(1) the downed member is NOT dead", !dying.Health.IsDead);
        Check("(1) massive damage killed the other member", slain.Health.IsDead);

        // (2) Post-fight stabilize.
        GD.Print("-------------------- (2) CompleteEncounter --------------------");
        int healthyBefore = healthy.Health.CurrentHP;
        PartyRecovery.CompleteEncounter(party, BattleResult.Team1Wins);

        Check("(2) the downed member stands at 1 HP", dying.Health.CurrentHP == 1);
        Check("(2) the slain member stands at 1 HP", slain.Health.CurrentHP == 1);
        Check("(2) neither is dead", !dying.Health.IsDead && !slain.Health.IsDead);
        Check("(2) neither is still Dying",
            !dying.Conditions.HasCondition(Condition.Dying) && !slain.Conditions.HasCondition(Condition.Dying));
        Check($"(2) the downed member is Wounded >= 1 ({Wounded(dying)})", Wounded(dying) >= 1);
        Check($"(2) the revived dead member is Wounded >= 1 ({Wounded(slain)})", Wounded(slain) >= 1);
        Check("(2) the untouched member is unchanged", healthy.Health.CurrentHP == healthyBefore);
        Check("(2) the party is not wiped", !party.IsWiped);

        // (3) Campsite night's rest.
        GD.Print("-------------------- (3) LongRest --------------------");
        clock.SpendShortRest();
        Check("(3) a short rest was spent before resting", clock.ShortRestsUsed == 1);

        int dayBefore = clock.Day;
        int dyingBefore = dying.Health.CurrentHP;
        int slainBefore = slain.Health.CurrentHP;
        PartyRecovery.LongRest(party, clock);

        Check("(3) both healed above their stabilized 1 HP",
            dying.Health.CurrentHP > dyingBefore && slain.Health.CurrentHP > slainBefore);
        Check("(3) Wounded is cleared party-wide", Wounded(dying) == 0 && Wounded(slain) == 0);
        Check("(3) the day advanced", clock.Day == dayBefore + 1);
        Check("(3) the short-rest budget is back to full",
            clock.ShortRestsUsed == 0 && clock.ShortRestsRemaining == clock.ShortRestsPerDay);

        // The night's rest heals max(1, Con mod) x level, so a level-2 member gains at least 2 HP.
        int expectedFloor = PartyLevel;
        Check($"(3) the rest healed at least {expectedFloor} HP (min 1/level)",
            dying.Health.CurrentHP - dyingBefore >= expectedFloor);

        return Task.CompletedTask;
    }

    private static int Wounded(PF2eCharacter member)
    {
        var wounded = ConditionDatabase.Instance?.Wounded;
        return wounded == null ? 0 : member.Conditions.GetConditionValue(wounded);
    }

    private static DamageResult Physical(int amount) =>
        new DamageResult { TotalDamage = amount, DamageType = DamageType.Slashing };
}
