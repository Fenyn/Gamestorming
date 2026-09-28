using System.Linq;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Dev;

public partial class KnowledgeJournalSpike
{
    /// <summary>The forecast names every modifier with the engine's own numbers: each label's value
    /// equals the shift the engine applies when the condition goes on, and masked stats stay "?".</summary>
    private void CheckForecastModifiers(DataManager data)
    {
        GD.Print("-------------------- forecast modifiers --------------------");
        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        var db = ConditionDatabase.Instance;
        var clean = CombatPreviewCalculator.CalculateAttackPreview(hero, goblin);
        int athletics = SkillCalculator.CalculateSkillBonus(hero, Skill.Athletics);
        int reflex = StatsCalculator.CalculateSave(goblin, SavingThrow.Reflex);

        goblin.Conditions.AddCondition(db.Prone);
        hero.Conditions.AddCondition(db.Frightened, value: 1);
        var data1 = CombatPreviewCalculator.CalculateAttackPreview(hero, goblin);
        var chips = ForecastModifiers.Strike(hero, goblin, data1.MAP);
        string texts = string.Join(", ", chips.Select(c => c.Text));
        int attackShift = data1.TotalAttackBonus - clean.TotalAttackBonus;
        int acShift = clean.TargetAC - data1.TargetAC;
        int offGuard = chips.Where(c => c.Label == "Off-guard (Prone)").Sum(c => c.Value);
        int frightened = chips.Where(c => c.Label == "Frightened 1").Sum(c => c.Value);
        Check($"a prone target and a frightened attacker read 'Off-guard (Prone) +2' and 'Frightened 1 -1' ({texts})",
            texts.Contains("Off-guard (Prone) +2") && texts.Contains("Frightened 1 -1") && chips.All(c => c.Value != 0));
        Check($"the labels carry the engine's numbers (AC {clean.TargetAC}→{data1.TargetAC}, attack {clean.TotalAttackBonus:+0;-0}→{data1.TotalAttackBonus:+0;-0})",
            offGuard == acShift && frightened == attackShift);
        Check("the granted off-guard shows the Prone icon", chips.Any(c => c.Label == "Off-guard (Prone)" && c.IconKey == nameof(Condition.Prone)));

        hero.Conditions.AddCondition(db.Prone);
        var data2 = CombatPreviewCalculator.CalculateAttackPreview(hero, goblin);
        var prone = ForecastModifiers.Strike(hero, goblin, data2.MAP);
        int proneValue = prone.Where(c => c.Label == "Prone").Sum(c => c.Value);
        Check($"a prone attacker reads 'Prone -2' at the engine's shift ({string.Join(", ", prone.Select(c => c.Text))}; attack {data1.TotalAttackBonus:+0;-0}→{data2.TotalAttackBonus:+0;-0})",
            proneValue == -2 && proneValue == data2.TotalAttackBonus - data1.TotalAttackBonus);

        goblin.Conditions.AddCondition(db.Frightened, value: 1);
        var check = ModifierBreakdown.Check(hero, Skill.Athletics, goblin, SavingThrow.Reflex);
        int skillShift = SkillCalculator.CalculateSkillBonus(hero, Skill.Athletics) - athletics;
        int saveShift = StatsCalculator.CalculateSave(goblin, SavingThrow.Reflex) - reflex;
        Check($"a check names the roller's and the save's modifiers at the engine's shifts ({string.Join(", ", check.Roll.Select(c => c.Text))} | {string.Join(", ", check.Defense.Select(c => c.Text))})",
            check.Roll.Sum(c => c.Value) == skillShift && check.Defense.Sum(c => c.Value) == saveShift && saveShift == -1);

        var journal = new MonsterJournal();
        journal.MarkEncountered(Goblin, "Goblin Warrior");
        var previous = CreatureKnowledgeLocator.Instance;
        CreatureKnowledgeLocator.Instance = journal;
        try
        {
            var view = ActionBarStateBuilder.BuildPreview(data1, chips);
            Check($"an unknown AC stays '?' beside the modifier line ('{view.HitChanceText}', AC '{view.TargetAcText}', {view.Modifiers.Count} modifiers)",
                view.HitChanceText == "?%" && view.CritChanceText == "?%" && view.TargetAcText == "?" && view.Modifiers.Count == chips.Count
                && view.Modifiers.All(m => !m.Text.Contains(data1.TargetAC.ToString())));
        }
        finally { CreatureKnowledgeLocator.Instance = previous; }
    }
}
