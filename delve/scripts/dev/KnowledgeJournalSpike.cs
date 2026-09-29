using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the knowledge journal: the fixed reveal order (one field per success,
/// two per critical success, none on a failure), the campaign save round trip and a version 1
/// save, masking in the inspect card, the forecast and the log before and after a reveal, the live
/// combat path (encounter, Recall Knowledge, log line, Journal panel), the outpost bestiary, and
/// the run host clearing the engine locator when it leaves the tree. Run it without --headless to
/// capture the Journal panel and the bestiary page.
/// </summary>
public partial class KnowledgeJournalSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export] public PackedScene? RunScene { get; set; }
    [Export] public PackedScene? CampScene { get; set; }

    private const string Goblin = "goblin-warrior";
    private static readonly CreatureRef WolfRef = new() { DisplayName = "Wolf", Pack = "pathfinder-monster-core", Slug = "wolf" };

    protected override string Banner => "==================== KNOWLEDGE JOURNAL SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (CombatScene == null || RunScene == null || CampScene == null)
        {
            AbortFail("[KnowledgeJournal] a scene export is not assigned.");
            return;
        }
        CheckRevealOrder();
        CheckPersistence();
        CheckMasking(data);
        CheckLeakMasking(data);
        CheckForecastModifiers(data);
        await CheckLiveCombat(data);
        await CheckBestiary(data);
        await CheckLocatorTeardown();
    }

    private void CheckRevealOrder()
    {
        GD.Print("-------------------- reveal order --------------------");
        var journal = new MonsterJournal();
        Check("the name is known before any encounter", journal.IsFieldRevealed(Goblin, CreatureKnowledgeField.Name)
            && !journal.IsFieldRevealed(Goblin, CreatureKnowledgeField.AC) && !journal.IsEncountered(Goblin));
        journal.MarkEncountered(Goblin, "Goblin Warrior");
        Check("entering a fight lists the species with nothing known",
            journal.IsEncountered("Goblin Warrior") && journal.IsEncountered("Elite Goblin Warrior") && journal.KnownCount(Goblin) == 0);
        Check("a failure reveals nothing", journal.Reveal(Goblin, DegreeOfSuccess.Failure).Count == 0);
        Check("a critical failure reveals nothing", journal.Reveal(Goblin, DegreeOfSuccess.CriticalFailure).Count == 0);
        var first = journal.Reveal(Goblin, DegreeOfSuccess.Success);
        Check($"a success reveals AC first ({string.Join(",", first)})", first.SequenceEqual(new[] { CreatureKnowledgeField.AC }));
        var crit = journal.Reveal(Goblin, DegreeOfSuccess.CriticalSuccess);
        Check($"a critical success reveals the next two, Weaknesses then MaxHP ({string.Join(",", crit)})",
            crit.SequenceEqual(new[] { CreatureKnowledgeField.Weaknesses, CreatureKnowledgeField.MaxHP }));
        var rest = Enumerable.Range(0, 8).SelectMany(_ => journal.Reveal(Goblin, DegreeOfSuccess.Success)).ToArray();
        var expected = KnowledgeRevealOrder.Fields.Skip(3).Select(r => r.Field).ToArray();
        Check($"later successes follow the table ({string.Join(",", rest)})", rest.SequenceEqual(expected));
        Check("eleven fields complete the species, and every field reads as known",
            journal.IsComplete(Goblin) && journal.IsFieldRevealed(Goblin, CreatureKnowledgeField.All));
        Check("a complete species learns nothing more", journal.Reveal(Goblin, DegreeOfSuccess.CriticalSuccess).Count == 0);
    }

    private static CampaignProgress SampleCampaign()
    {
        var campaign = new CampaignProgress();
        campaign.Journal.MarkEncountered(Goblin, "Goblin Warrior");
        campaign.Journal.Reveal(Goblin, DegreeOfSuccess.Success);
        campaign.Journal.Reveal(Goblin, DegreeOfSuccess.CriticalSuccess);
        campaign.Journal.MarkEncountered(WolfRef.Slug, "Wolf");
        return campaign;
    }

    private void CheckPersistence()
    {
        GD.Print("-------------------- persistence --------------------");
        string path = Path.Combine(Path.GetTempPath(), $"delve-journal-spike-{Guid.NewGuid():N}.json");
        try
        {
            CampaignProgressStore.Save(path, SampleCampaign());
            var loaded = CampaignProgressStore.Load(path).Journal;
            Check($"the journal survives the campaign save (goblin {loaded.KnownCount(Goblin)} known, wolf listed)",
                loaded.KnownCount(Goblin) == 3 && loaded.IsFieldRevealed(Goblin, CreatureKnowledgeField.MaxHP)
                && !loaded.IsFieldRevealed(Goblin, CreatureKnowledgeField.Resistances)
                && loaded.IsEncountered(WolfRef.Slug) && loaded.NameFor(Goblin) == "Goblin Warrior");

            File.WriteAllText(path, "{\"Version\":1,\"UnlockedIds\":[" + JsonSerializer.Serialize(PresetCharacters.RavenId)
                + "],\"Recruitment\":{},\"Personal\":{},\"Outpost\":[]}");
            var restored = CampaignProgressStore.Load(path);
            Check("a version 1 save loads with an empty journal and its unlocks",
                restored.Journal.Encountered.Count == 0 && restored.Unlocks.IsUnlocked(PresetCharacters.RavenId));
        }
        finally { if (File.Exists(path)) File.Delete(path); }
    }

    private void CheckMasking(DataManager data)
    {
        GD.Print("-------------------- masking --------------------");
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        int ac = goblin.CreatureStats!.Data.AC;
        var journal = new MonsterJournal();
        journal.MarkEncountered(Goblin, "Goblin Warrior");
        var previous = CreatureKnowledgeLocator.Instance;
        CreatureKnowledgeLocator.Instance = journal;
        try
        {
            var preview = new AttackPreviewData { HitChance = 65, CritChance = 10, TargetAC = ac, TargetCreatureId = Goblin, DamageFormula = "1d8+4", TotalAttackBonus = 7 };
            var inspect = UnitInspectFactory.BuildInspectView(goblin);
            var forecast = ActionBarStateBuilder.BuildPreview(preview);
            Check($"before a reveal the inspect card masks AC and HP ('{inspect.AcText}', '{inspect.HpText}')",
                inspect.AcText == "AC ?" && inspect.HpText == "?/?");
            Check($"before a reveal the forecast masks the odds ('{forecast.HitChanceText}', AC '{forecast.TargetAcText}')",
                forecast.HitChanceText == "?%" && forecast.TargetAcText == "?");
            string masked = string.Join(", ", forecast.Figures.Select(f => $"{f.Caption} {f.Value}"));
            Check($"before a reveal the forecast figures lead with the attack total ({masked})",
                masked == "Attack +7, AC ?, Damage 1d8+4");
            var feint = TargetPreviewFactory.Ability(PresetCharacters.BuildFenwick(level: 2, teamId: 1), goblin,
                new PF2e.Actions.SkillActions.FeintAction());
            string feintFigures = feint == null ? "none" : string.Join(", ", feint.Figures.Select(f => $"{f.Caption} {f.Value}"));
            Check($"a Feint forecast masks the target's Perception DC ({feintFigures})",
                feint != null && feint.Figures.Any(f => f.Caption == "DC" && f.Value == "?") && !feintFigures.Contains('%'));
            Check("before a reveal the log masks the roll's AC",
                !CombatLogBridge.ArmorClassKnown(goblin) && CombatRoll.MaskArmorClass($"d20(12)+10=22 vs AC {ac} → Success").Contains("vs AC ?"));

            journal.Reveal(Goblin, DegreeOfSuccess.Success);
            inspect = UnitInspectFactory.BuildInspectView(goblin);
            forecast = ActionBarStateBuilder.BuildPreview(preview);
            Check($"after one success the AC shows everywhere and HP stays masked ('{inspect.AcText}', '{inspect.HpText}', '{forecast.HitChanceText}')",
                inspect.AcText == $"AC {ac}" && inspect.HpText == "?/?" && forecast.HitChanceText == "65%"
                && forecast.TargetAcText == ac.ToString() && CombatLogBridge.ArmorClassKnown(goblin));

            journal.Reveal(Goblin, DegreeOfSuccess.CriticalSuccess);
            inspect = UnitInspectFactory.BuildInspectView(goblin);
            Check($"after a critical success the HP shows ('{inspect.HpText}')", inspect.HpText != "?/?");

            var facts = CreatureFacts.Facts(goblin.CreatureStats.SourceDefinition, goblin.CreatureStats.Data,
                f => journal.IsFieldRevealed(Goblin, f));
            Check($"the journal pairs read '{facts[0].Text}', '{facts[1].Text}', '{facts[3].Text}'",
                facts[0].Text == $"AC {ac}" && facts[0].Known && facts[1].Text.StartsWith("Weak ")
                && facts[3].Text == "Resist ?" && !facts[3].Known && CreatureFacts.KnownText(facts) == "Known 3 of 11");
        }
        finally { CreatureKnowledgeLocator.Instance = previous; }
        Check("with no journal wired nothing is masked", UnitInspectFactory.BuildInspectView(goblin).AcText == $"AC {ac}");
    }

    private async Task CheckLocatorTeardown()
    {
        GD.Print("-------------------- locator lifetime --------------------");
        var director = RunScene!.Instantiate<RunDirector>();
        director.AutoPlayCombat = true;
        AddChild(director);
        await Frames(2);
        Check("the run host sets the campaign journal as the knowledge provider",
            ReferenceEquals(CreatureKnowledgeLocator.Instance, director.Campaign.Journal));
        RemoveChild(director);
        director.QueueFree();
        Check("leaving the tree clears the provider", CreatureKnowledgeLocator.Instance == null);
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task WaitSeconds(float seconds)
    {
        await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private void Capture(string file)
    {
        if (DisplayServer.GetName() == "headless")
        {
            GD.Print($"[KnowledgeJournal] {file}: skipped (headless, no viewport texture)");
            return;
        }
        Check($"{file} saved", SaveViewportCapture($"user://dev_shots/{file}", new Vector2I(1600, 900)) == Error.Ok);
    }
}
