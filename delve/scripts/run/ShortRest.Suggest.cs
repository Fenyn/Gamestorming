using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run;

public static partial class ShortRest
{
    /// <summary>
    /// The schedule a careful party would pick, so the rest screen never opens on a block that spends
    /// ward for nothing. The most wounded are treated first, each by the best free trained medic; the
    /// others Refocus if their pool is spent, repair a damaged shield, or rest. The result always
    /// passes <see cref="Validate"/>.
    /// </summary>
    public static IReadOnlyList<RestAssignment> Suggest(Party party)
    {
        var living = party.Living();
        var chosen = new Dictionary<PF2eCharacter, RestAssignment>();
        var medics = living.Where(m => m.Skills.GetProficiency(Skill.Medicine) >= ProficiencyLevel.Trained)
            .OrderByDescending(m => SkillCalculator.CalculateSkillBonus(m, Skill.Medicine)).ToList();
        foreach (var patient in living.Where(m => m.Health.CurrentHP < m.Health.MaxHP)
                     .OrderByDescending(m => m.Health.MaxHP - m.Health.CurrentHP))
        {
            var medic = medics.FirstOrDefault(m => !chosen.ContainsKey(m));
            if (medic == null) break;
            chosen[medic] = new RestAssignment(medic, ShortRestKind.TreatWounds, patient);
        }

        var repaired = new HashSet<PF2eCharacter>();
        foreach (var actor in living.Where(m => !chosen.ContainsKey(m)))
        {
            if (actor.Spellcasting is { MaxFocusPoints: > 0 } casting && casting.CurrentFocusPoints < casting.MaxFocusPoints)
            {
                chosen[actor] = new RestAssignment(actor, ShortRestKind.Refocus);
                continue;
            }
            var owner = living.FirstOrDefault(m => !repaired.Contains(m) && m.Equipment?.Shield is { EquippedShield: not null } shield
                && shield.CurrentShieldHP < shield.MaxShieldHP);
            if (owner != null)
            {
                repaired.Add(owner);
                chosen[actor] = new RestAssignment(actor, ShortRestKind.RepairShield, owner);
                continue;
            }
            chosen[actor] = new RestAssignment(actor, ShortRestKind.Rest);
        }
        return living.Select(m => chosen[m]).ToArray();
    }
}
