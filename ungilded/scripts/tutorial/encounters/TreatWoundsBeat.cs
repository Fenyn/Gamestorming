using System;
using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// Treat Wounds between encounters (spec sections 3 and 8): the healer's trained Medicine check at
/// DC 15 is forced to a success and the 2d8 is forced to restore all but 1 of the patient's missing
/// HP. The check and the HP pair go to the combat log, the heal plays on the board, and a popup
/// with the id <c>tipId</c> shows the same values before the screen goes black. A patient at full
/// HP gets no beat.
/// </summary>
internal static class TreatWoundsBeat
{
    private const string ActionName = "Treat Wounds";
    private const int HealDie = 8;

    internal static async Task Play(EncounterStage s, string tipId, ICharacter healer, ICharacter patient)
    {
        if (patient.Health == null || patient.Health.CurrentHP >= patient.Health.MaxHP) return;
        int bonus = SkillCalculator.CalculateSkillBonus(healer, Skill.Medicine);
        int before = patient.Health.CurrentHP;
        int missing = patient.Health.MaxHP - before;

        s.Force(TutorialHooks.D20ForCheck(bonus, TutorialRolls.FlatDc, EncounterStage.Hit), HealDice(missing));
        var result = TreatWoundsResolver.Resolve(bonus, TutorialRolls.FlatDc, healer);
        s.Hooks.ClearForcedDice();
        if (result.HealingOrDamage > 0) patient.Health.Heal(result.HealingOrDamage);
        int after = patient.Health.CurrentHP;

        s.Scene.AppendLog($"{healer.Name} uses {ActionName} on {patient.Name}");
        s.Scene.AppendCheckLog($"Medicine: {result.D20Roll} + {bonus} = {result.Total} vs DC {TutorialRolls.FlatDc} → {result.Degree}");
        s.Scene.AppendLog($"{patient.Name} HP {before} → {after}", isDetail: true);
        await s.Scene.PresentHeal(healer, patient, after - before);
        await s.ShowValues(tipId,$"[b]{ActionName}[/b]\n{healer.Name} Medicine {result.Total} vs DC {TutorialRolls.FlatDc}: {result.Degree}\n"
            + $"{patient.Name} HP {before} → {after}");
    }

    /// <summary>Two d8 results that sum to the missing HP less 1, kept between 2 and 16.</summary>
    private static int[] HealDice(int missing)
    {
        int total = Math.Clamp(missing - 1, 2, 2 * HealDie);
        int first = Math.Min(HealDie, total - 1);
        return new[] { first, total - first };
    }
}
