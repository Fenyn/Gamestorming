using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Dev;

public partial class CombatLogSpike
{
    /// <summary>The log and the dice panel print "vs AC ?" until the species' AC is revealed.</summary>
    private async Task CheckArmorClassMasking(Control frame, DataManager data)
    {
        var log = LogScene.Instantiate<CombatLogPanel>();
        frame.AddChild(log);
        var dice = DiceScene.Instantiate<DiceRollPanel>();
        frame.AddChild(dice);
        Quicken(dice);
        log.RollObserved += dice.ShowRoll;
        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        var previous = CreatureKnowledgeLocator.Instance;
        var knowledge = new FixedKnowledge();
        CreatureKnowledgeLocator.Instance = knowledge;
        var bridge = new CombatLogBridge(log, new ICharacter[] { hero }, new ICharacter[] { goblin });
        try
        {
            CombatLog.Emit($"{hero.Name} Strikes {goblin.Name} with Longsword", CombatLogSeverity.ActionHeader);
            CombatLog.Emit("d20(12)+10=22 vs AC 16 → Success", CombatLogSeverity.Hit, true);
            await dice.WaitForResultsAsync();
            string masked = log.HistoryText;
            Check($"an unrevealed enemy AC prints as ? in the log ('{masked.Replace("\n", " | ")}')",
                masked.Contains("vs AC ?") && !masked.Contains("AC 16"));
            Check($"the dice panel prints the masked AC ('{dice.GetNode<RichTextLabel>("%RollMath").GetParsedText().Replace("\n", " | ")}')",
                dice.GetNode<RichTextLabel>("%RollMath").GetParsedText().StartsWith("22 vs ?"));
            Check("an unrevealed AC plays centre stage", dice.Beat?.Stage == RollStage.CentreStage && dice.Hero!.TargetText == "?");

            CombatLog.Emit($"{goblin.Name} Strikes {hero.Name} with Dogslicer", CombatLogSeverity.ActionHeader);
            CombatLog.Emit("d20(9)+8=17 vs AC 18 → Failure", CombatLogSeverity.Miss, true);
            await dice.WaitForResultsAsync();
            Check("an ally's AC is never masked", log.HistoryText.Contains("vs AC 18"));

            knowledge.Revealed = true;
            CombatLog.Emit($"{hero.Name} Strikes {goblin.Name} with Longsword", CombatLogSeverity.ActionHeader);
            CombatLog.Emit("d20(15)+10=25 vs AC 16 → Success", CombatLogSeverity.Hit, true);
            await dice.WaitForResultsAsync();
            Check("a revealed enemy AC prints its number in the log and the dice panel",
                log.HistoryText.Contains("vs AC 16") && dice.GetNode<RichTextLabel>("%RollMath").GetParsedText().StartsWith("25 vs 16"));
            Check("a revealed AC plays the degree track", dice.Beat?.Stage == RollStage.DegreeTrack && dice.Hero!.Track.Dc == 16);

            knowledge.Revealed = false;
            CombatLog.Emit($"{hero.Name} attempts to Trip {goblin.Name}", CombatLogSeverity.ActionHeader);
            int reflexDc = 10 + PF2e.Utilities.StatsCalculator.CalculateSave(goblin, PF2e.Data.SavingThrow.Reflex);
            CombatLog.Emit($"Athletics: 12 + 5 = 17 vs DC {reflexDc} → Failure", CombatLogSeverity.Info, true);
            await dice.WaitForResultsAsync();
            Check($"a check against an unrevealed save prints vs DC ? and plays centre stage ('{LastLines(log.HistoryText)}')",
                log.HistoryText.Contains("vs DC ?") && !log.HistoryText.Contains($"vs DC {reflexDc}")
                && dice.Beat?.Stage == RollStage.CentreStage);
            knowledge.Revealed = true;
            CombatLog.Emit($"{hero.Name} attempts to Trip {goblin.Name}", CombatLogSeverity.ActionHeader);
            CombatLog.Emit($"Athletics: 12 + 5 = 17 vs DC {reflexDc} → Failure", CombatLogSeverity.Info, true);
            await dice.WaitForResultsAsync();
            Check("once the save is revealed the check prints its DC and plays the track",
                log.HistoryText.Contains($"vs DC {reflexDc}") && dice.Beat?.Stage == RollStage.DegreeTrack);
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

    private static string LastLines(string text) => string.Join(" | ", text.Split('\n')[^System.Math.Min(3, text.Split('\n').Length)..]);

    private sealed class FixedKnowledge : ICreatureKnowledgeProvider
    {
        public bool Revealed { get; set; }
        public bool IsFieldRevealed(string creatureId, CreatureKnowledgeField field) => Revealed;
        public bool IsEncountered(string creatureId) => true;
        public bool IsComplete(string creatureId) => Revealed;
    }
}
