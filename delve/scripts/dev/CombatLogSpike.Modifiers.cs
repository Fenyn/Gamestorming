using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Dev;

public partial class CombatLogSpike
{
    /// <summary>The roll row and the hero roll name the condition modifiers the engine applied, split
    /// out of the logged bonus so the arithmetic still sums, and a masked AC stays "?".</summary>
    private async Task CheckAppliedModifiers(Control frame, DataManager data)
    {
        var log = LogScene.Instantiate<CombatLogPanel>();
        frame.AddChild(log);
        var dice = DiceScene.Instantiate<DiceRollPanel>();
        frame.AddChild(dice);
        Quicken(dice);
        CombatRoll? observed = null;
        log.RollObserved += (roll, _) => observed = roll;
        log.RollObserved += dice.ShowRoll;
        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        goblin.Conditions.AddCondition(ConditionDatabase.Instance.Prone);
        hero.Conditions.AddCondition(ConditionDatabase.Instance.Frightened, value: 1);
        var previous = CreatureKnowledgeLocator.Instance;
        var knowledge = new FixedKnowledge { Revealed = true };
        CreatureKnowledgeLocator.Instance = knowledge;
        var bridge = new CombatLogBridge(log, new ICharacter[] { hero }, new ICharacter[] { goblin });
        try
        {
            CombatLog.Emit($"{goblin.Name} Strikes {hero.Name} with Dogslicer", CombatLogSeverity.ActionHeader);
            CombatLog.Emit("d20(17)+5 MAP-4=18 vs AC 15 → Success", CombatLogSeverity.Hit, true);
            await dice.WaitForResultsAsync();
            string detail = dice.DetailText.Replace("\n", " | ");
            int engineAttack = goblin.Modifiers.GetModifierTotal(StatType.MeleeAttack, ModifierContext.General());
            Check($"an enemy roll lists 'Prone -2' then 'AC -1' after its arithmetic ('{detail}')",
                detail.Contains("17 +7 MAP-4") && detail.Contains("Prone -2") && detail.Contains("AC -1")
                && detail.IndexOf("Prone -2") < detail.IndexOf("AC -1") && !detail.Contains("Other"));
            await Settle();
            Check($"the roll row stays 600x72 with a named modifier line ({dice.Size})", dice.Size.X <= 600.5f && dice.Size.Y <= 72.5f);
            Check($"the named roll modifiers sum to the engine's attack total ({engineAttack})",
                observed?.Breakdown.Roll.Sum(m => m.Value) == engineAttack && observed.Breakdown.Defense.Single().Label == "Frightened 1");

            goblin.Conditions.AddCondition(ConditionDatabase.Instance.Frightened, value: 2);
            CombatLog.Emit($"{goblin.Name} Strikes {hero.Name} with Dogslicer", CombatLogSeverity.ActionHeader);
            CombatLog.Emit("d20(4)+3=7 vs AC 15 → Failure", CombatLogSeverity.Miss, true);
            await dice.WaitForResultsAsync();
            await Settle();
            detail = dice.DetailText.Replace("\n", " | ");
            Check($"a row with no room for the labels lets the icons name them and keeps 600x72 ('{detail}', {dice.Size})",
                detail.Contains("4 +7") && detail.Contains("-2   -2") && detail.Contains("AC -1") && dice.Size.X <= 600.5f && dice.Size.Y <= 72.5f);
            goblin.Conditions.RemoveCondition(ConditionDatabase.Instance.Frightened);

            knowledge.Revealed = false;
            CombatLog.Emit($"{hero.Name} Strikes {goblin.Name} with Longsword", CombatLogSeverity.ActionHeader);
            CombatLog.Emit("d20(12)+9=21 vs AC 14 → Success", CombatLogSeverity.Hit, true);
            await dice.WaitForResultsAsync();
            detail = dice.DetailText.Replace("\n", " | ");
            string math = dice.GetNode<RichTextLabel>("%RollMath").GetParsedText();
            Check($"a party roll against an unknown AC names its modifiers and keeps '?' ('{math}' / '{detail}')",
                math.StartsWith("21 vs ?") && detail.Contains("12 +10") && detail.Contains("Frightened 1 -1")
                && detail.Contains("AC -2") && !detail.Contains("14"));
            Check($"the hero roll prints the same named modifiers ('{dice.Hero?.AppliedText}')",
                dice.Hero?.AppliedText.Contains("Frightened 1 -1") == true && dice.Hero.AppliedText.Contains("AC -2"));
        }
        finally
        {
            bridge.Dispose();
            CreatureKnowledgeLocator.Instance = previous;
            dice.ClearRoll();
            log.QueueFree();
            dice.QueueFree();
        }
    }
}
