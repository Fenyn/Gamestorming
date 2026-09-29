using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Actions.SkillActions;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

public partial class KnowledgeJournalSpike
{
    private async Task CheckLiveCombat(DataManager data)
    {
        GD.Print("-------------------- live combat --------------------");
        var scene = CombatScene!.Instantiate<CombatScene>();
        AddChild(scene);
        var journal = new MonsterJournal();
        int changes = 0;
        journal.Changed += () => changes++;
        var previous = CreatureKnowledgeLocator.Instance;
        CreatureKnowledgeLocator.Instance = journal;
        scene.Journal = journal;
        try
        {
            var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
            var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
            var goblinA = CreatureFactory.Create(goblinDef, teamId: 2);
            var goblinB = CreatureFactory.Create(goblinDef, teamId: 2);
            var wolf = CreatureFactory.Create(data.ResolveCreature(WolfRef)!, teamId: 2);
            scene.StartEncounter(new CombatSetup
            {
                GridWidth = 40, GridHeight = 10, RngSeed = 3,
                Party =
                {
                    (hero, new PF2eVec(3, 5)),
                    (PresetCharacters.BuildElara(level: 2, teamId: 1), new PF2eVec(3, 3)),
                },
                Enemies = { (goblinA, new PF2eVec(36, 3)), (goblinB, new PF2eVec(36, 5)), (wolf, new PF2eVec(36, 7)) },
            });
            await WaitSeconds(0.5f);
            var panel = scene.JournalPanel;
            var log = scene.GetNode<CombatLogPanel>("%CombatLog");
            Check($"entering the fight lists both species ({changes} journal changes)",
                journal.IsEncountered(Goblin) && journal.IsEncountered(WolfRef.Slug) && changes == 2);
            var groups = panel.Groups;
            Check($"the Journal panel groups the fight by species ({Describe(groups)})",
                groups.Count == 2 && groups[0].Name == "Goblin Warrior" && groups[0].Letters == "A, B"
                && groups[0].KnownText == "Known 0 of 11" && groups[0].Facts.All(f => !f.Known) && groups[1].Letters == "C");

            int ac = goblinA.CreatureStats!.Data.AC;
            RecallKnowledgeAction.NotifyKnowledgeResolved(hero, goblinA, DegreeOfSuccess.Failure);
            Check("a failed Recall Knowledge teaches nothing", journal.KnownCount(Goblin) == 0);
            RecallKnowledgeAction.NotifyKnowledgeResolved(hero, goblinA, DegreeOfSuccess.Success);
            Check($"a success logs one fact ('{LastLine(log.HistoryText)}')", LastLine(log.HistoryText) == $"Journal: Goblin Warrior  AC {ac}");
            Check("the panel and the other goblin's inspect card show the AC",
                panel.Groups[0].KnownText == "Known 1 of 11" && panel.Groups[0].Facts[0].Known
                && UnitInspectFactory.BuildInspectView(goblinB).AcText == $"AC {ac}"
                && UnitInspectFactory.BuildInspectView(wolf).AcText == "AC ?");
            RecallKnowledgeAction.NotifyKnowledgeResolved(goblinA, hero, DegreeOfSuccess.Success);
            Check("an enemy's check teaches the party nothing", journal.KnownCount(Goblin) == 1);
            CombatLog.Emit($"{hero.Name} studies {goblinB.Name}", CombatLogSeverity.ActionHeader);
            CombatLog.Emit(CombatLogMasks.CriticalRecall, CombatLogSeverity.CriticalHit, isDetail: true);
            RecallKnowledgeAction.NotifyKnowledgeResolved(hero, goblinB, DegreeOfSuccess.CriticalSuccess);
            string line = LastLine(log.HistoryText);
            Check($"a critical success logs the next two facts in place of the engine's line ('{line}')",
                line.StartsWith("Journal: Goblin Warrior  Weak ") && line.Contains($"  HP {goblinB.CreatureStats!.Data.MaxHP}")
                && panel.Groups[0].KnownText == "Known 3 of 11" && !log.HistoryText.Contains(CombatLogMasks.CriticalRecall));

            var hud = scene.GetNode<HudRoot>("%HudRoot");
            if (scene.IntroPlaying)
            {
                hud._UnhandledInput(new InputEventAction { Action = InputNames.Journal, Pressed = true });
                scene.GetNode<Button>("%JournalButton").EmitSignal(BaseButton.SignalName.Pressed);
                Check("neither J nor the button opens the journal over the encounter intro", !panel.Visible);
                scene.SkipIntro();
                for (int i = 0; i < 60 && scene.IntroPlaying; i++) await WaitSeconds(0.05f);
            }
            hud._UnhandledInput(new InputEventAction { Action = InputNames.Journal, Pressed = true });
            Check("J opens the Journal panel", panel.Visible);
            hud._UnhandledInput(new InputEventAction { Action = InputNames.UiCancel, Pressed = true });
            Check("Esc closes it", !panel.Visible);
            scene.GetNode<Button>("%JournalButton").EmitSignal(BaseButton.SignalName.Pressed);
            await WaitSeconds(0.3f);
            var rail = scene.GetNode<TurnOrderBar>("%TurnOrderBar").Row.GetGlobalRect();
            var rect = panel.GetGlobalRect();
            Check($"the Journal button opens it clear of the timeline ({rect} vs timeline end x {rail.End.X})",
                panel.Visible && rect.Position.X >= rail.End.X + 16 && rect.Position.Y >= 16);
            Capture("knowledge_journal_combat.png");
            hud._UnhandledInput(new InputEventAction { Action = InputNames.Journal, Pressed = true });
            Check("J closes it again", !panel.Visible);
        }
        finally
        {
            scene.Journal = null;
            CreatureKnowledgeLocator.Instance = previous;
            RemoveChild(scene);
            scene.QueueFree();
        }
    }

    private async Task CheckBestiary(DataManager data)
    {
        GD.Print("-------------------- outpost bestiary --------------------");
        var camp = CampScene!.Instantiate<HeroSelectPanel>();
        AddChild(camp);
        var campaign = SampleCampaign();
        camp.Setup(campaign.Unlocks, campaign);
        await Frames(2);
        camp.OpenBestiary();
        await Frames(3);
        var bestiary = camp.Bestiary;
        var goblinDef = data.FindCreature("Goblin Warrior")!;
        int pool = BestiaryPanel.CampaignPool(campaign.Journal).Count;
        Check($"the bestiary lists the campaign's whole creature pool ({bestiary.EntryCount} entries, {bestiary.MetCount} met)",
            bestiary.Visible && bestiary.EntryCount == pool && pool > 20 && bestiary.MetCount == 2);
        var facts = bestiary.PageFacts;
        Check($"the first met species opens with its progress ('{bestiary.PageKnownText}')",
            bestiary.SelectedId == Goblin && bestiary.PageKnownText == "Known 3 of 11" && bestiary.PageTitle == "Goblin Warrior");
        Check($"the page prints only the known facts ({bestiary.ShownFactCount}: '{string.Join("', '", facts.Where(f => f.Known).Select(f => f.Text))}')",
            facts[0].Text == $"AC {goblinDef.StatBlock.AC}" && facts[2].Text == $"HP {goblinDef.StatBlock.MaxHP}"
            && facts.Count(f => f.Known) == 3 && bestiary.ShownFactCount == 3);
        var portrait = bestiary.Portrait;
        int scale = portrait.Texture == null ? 0 : (int)(portrait.Size.Y / portrait.Texture.GetHeight());
        Check($"a met species shows its idle sprite at a whole scale ({portrait.Size} from {portrait.Texture?.GetSize()})",
            portrait.Texture != null && !bestiary.PortraitSilhouette && scale >= 2
            && Mathf.IsEqualApprox(portrait.Size.Y, portrait.Texture.GetHeight() * scale)
            && Mathf.IsEqualApprox(portrait.Size.X, portrait.Texture.GetWidth() * scale));
        Check("the first met entry holds focus", GetViewport().GuiGetFocusOwner() is Button { Text: "Goblin Warrior" });
        Capture("knowledge_journal_bestiary.png");

        GetViewport().PushInput(new InputEventAction { Action = InputNames.UiDown, Pressed = true });
        await Frames(2);
        Check($"Down moves to the next species and the page follows ('{bestiary.PageKnownText}')",
            bestiary.SelectedId == WolfRef.Slug && bestiary.PageKnownText == "Known 0 of 11" && bestiary.ShownFactCount == 0);
        GetViewport().PushInput(new InputEventAction { Action = InputNames.UiUp, Pressed = true });
        GetViewport().PushInput(new InputEventAction { Action = InputNames.UiUp, Pressed = true });
        await Frames(2);
        Check($"a species not met yet shows a dark silhouette, '???' and no facts ('{bestiary.PageTitle}', {bestiary.SelectedId})",
            bestiary.PageTitle == BestiaryPanel.Unknown && bestiary.PortraitSilhouette && bestiary.Portrait.Texture != null
            && bestiary.PageKnownText == "" && bestiary.ShownFactCount == 0 && bestiary.PageFacts.Count == 0);
        Capture("knowledge_journal_bestiary_unmet.png");
        GetViewport().PushInput(new InputEventAction { Action = InputNames.Decline, Pressed = true });
        await Frames(2);
        Check("Esc closes the bestiary and gives focus back to its button",
            !bestiary.Visible && GetViewport().GuiGetFocusOwner()?.Name == "BestiaryButton");
        RemoveChild(camp);
        camp.QueueFree();
    }

    private static string LastLine(string text) => text.Split('\n').LastOrDefault(l => l.Trim().Length > 0)?.Trim() ?? "";

    private static string Describe(IReadOnlyList<JournalGroupView> groups)
        => string.Join("; ", groups.Select(g => $"{g.Name} [{g.Letters}] {g.KnownText}"));
}
