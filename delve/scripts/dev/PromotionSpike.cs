using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class PromotionSpike : SpikeBase
{
    [Export] public PackedScene DetailsScene { get; set; } = null!;
    [Export] public PackedScene MapScene { get; set; } = null!;
    [Export] public PackedScene VictoryScene { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var party = Party.Build(new[] { "player", "elara", "tharr", "fenwick" }, new UnlockState(), 2);
        var state = RunState.Start(123, party, new RunMapConfig());
        var fighter = party.Members[0];
        int hp = fighter.Health.MaxHP;
        int feats = fighter.Features.ChosenFeats.Count;
        fighter.Health.SetCurrentHP(hp - 7);
        Check("XP below threshold grants nothing", PartyLeveling.Award(state, 149) == 0);
        Check("two earned levels queue without changing characters", PartyLeveling.Award(state, 151) == 2
            && party.Level == 4 && party.Members.All(c => c.Stats.Level == 2)
            && fighter.Health.MaxHP == hp && fighter.Features.ChosenFeats.Count == feats);
        PresetCharacters.LevelUpInPlace(fighter, 4);
        RosterFeats.Apply(fighter);
        Check("automatic preset paths cannot bypass player choices", fighter.Stats.Level == 2 && fighter.Features.ChosenFeats.Count == feats);
        var promotion = CharacterPromotion.For(fighter);
        int revision = promotion.Revision;
        Check("future and foreign feats rejected", !promotion.Confirm(fighter, "shielded-stride", revision, out _)
            && !promotion.Confirm(fighter, "healing-hands", revision, out _) && fighter.Stats.Level == 2);
        Check("explicit choice applies only the next level", promotion.Confirm(fighter, "intimidating-strike", revision, out _)
            && fighter.Stats.Level == 3 && promotion.PendingLevels(fighter) == 1);
        Check("damage taken is preserved", fighter.Health.MaxHP - fighter.Health.CurrentHP == 7);
        Check("stale confirm cannot spend another level", !promotion.Confirm(fighter, "shielded-stride", revision, out _) && fighter.Stats.Level == 3);
        Check("second confirmation applies the chosen feat only", promotion.Confirm(fighter, "shielded-stride", promotion.Revision, out _)
            && fighter.Stats.Level == 4 && RosterFeats.Has(fighter, "shielded-stride") && !RosterFeats.Has(fighter, "disarming-block"));
        Check("repeated confirmation cannot grant another feat", !promotion.Confirm(fighter, "disarming-block", promotion.Revision, out _));

        foreach (string id in new[] { "tharr", "fenwick" })
        {
            var caster = party.Find(id)!;
            var casting = caster.Spellcasting;
            var spell = casting.LeveledSpells.First(s => !s.Spell.IsFocusSpell);
            casting.ConsumePreparedSpell(spell);
            int preparations = casting.LeveledSpells.Count;
            casting.ConsumeFocusPoint();
            int focus = casting.CurrentFocusPoints;
            casting.DivineFont?.ConsumeSlot();
            int? fontRemaining = casting.DivineFont?.CurrentSlots;
            var advance = CharacterPromotion.For(caster);
            Check($"{id}: selectable casting feat promotes", advance.Confirm(caster, "reach-spell", advance.Revision, out _));
            Check($"{id}: promotion preserves preparations, focus and font", casting.LeveledSpells.Count == preparations
                && casting.CurrentFocusPoints == focus && casting.DivineFont?.CurrentSlots == fontRemaining);
        }

        // Every existing character can progress even while its playable feat inventory is incomplete.
        foreach (var def in CharacterCatalog.All)
        {
            var member = def.Builder(2);
            var advance = CharacterPromotion.For(member);
            CharacterPromotion.Earn(member, 10);
            bool ok = true;
            while (advance.PendingLevels(member) > 0)
            {
                var option = PromotionFeats.For(member).FirstOrDefault(f => PromotionFeats.LockReason(member, f, advance.ChoiceLevel(member)) == null);
                ok &= option == null ? advance.SaveChoiceAndPromote(member, advance.Revision, out _)
                    : advance.Confirm(member, option.Id, advance.Revision, out _);
                if (!ok) break;
            }
            while (advance.SavedChoices.Count > 0)
            {
                var option = PromotionFeats.For(member).FirstOrDefault(f => PromotionFeats.LockReason(member, f, member.Stats.Level) == null);
                if (option == null) break;
                int before = advance.SavedChoices.Count;
                ok &= advance.Confirm(member, option.Id, advance.Revision, out _) && advance.SavedChoices.Count == before - 1;
                if (!ok) break;
            }
            Check($"{def.Id}: reaches 10 with every earned choice accounted for", ok && member.Stats.Level == 10
                && advance.Selections.Count + advance.SavedChoices.Count == 8);
        }

        var fresh = PresetCharacters.BuildPlayer(2);
        Check("new character has no leaked run choices", !CharacterPromotion.IsManaged(fresh) && fresh.Stats.Level == 2);
        var capBefore = party.Level;
        Check("XP cap counts earned levels even before confirmation", PartyLeveling.Award(state, 10000) == 10 - capBefore
            && state.Party.Level == 10 && state.Xp <= state.Leveling.XpPerLevel);

        var uiParty = Party.Build(new[] { "player" }, new UnlockState(), 2);
        var uiState = RunState.Start(44, uiParty, new RunMapConfig());
        PartyLeveling.Award(uiState, 300);
        var c = uiParty.Members[0];
        var details = DetailsScene.Instantiate<CharacterDetailsOverlay>();
        AddChild(details);
        details.Open(c, HeroPortraits.For(c.Id), UiColors.CharacterAccent(c.Id));
        var panel = details.GetNode<PromotionPanel>("%Progression");
        var confirm = panel.GetNode<Button>("%ConfirmPromotion");
        Check("opening sheet selects nothing and grants nothing", confirm.Disabled && c.Stats.Level == 2 && panel.Visible);
        panel.GetNode<GridContainer>("%FeatTree").GetNode<Button>("intimidating-strike").EmitSignal(Button.SignalName.Pressed);
        Check("selecting a card only previews", !confirm.Disabled && c.Stats.Level == 2);
        details.Close();
        details.Open(c, HeroPortraits.For(c.Id), UiColors.CharacterAccent(c.Id));
        Check("closing discards the unconfirmed selection", confirm.Disabled && c.Stats.Level == 2);
        panel.GetNode<GridContainer>("%FeatTree").GetNode<Button>("intimidating-strike").EmitSignal(Button.SignalName.Pressed);
        confirm.EmitSignal(Button.SignalName.Pressed);
        Check("sheet confirmation advances and refreshes next pending promotion", c.Stats.Level == 3 && confirm.Disabled
            && panel.GetNode<Label>("%PromotionHeading").Text.Contains("3 → 4"));
        await Capture();
        details.Close();
        var map = MapScene.Instantiate<RunMapPanel>();
        AddChild(map);
        map.Render(uiState);
        int encounter = uiState.Map.Nodes.First(n => n.Kind is NodeKind.Combat or NodeKind.Elite or NodeKind.Boss).Id;
        Check("map rejects encounter entry with a pending promotion", !map.CanEnterWithPromotions(encounter) && uiState.CurrentNodeId == null);
        map.Hide();
        var victory = VictoryScene.Instantiate<VictoryBanner>();
        AddChild(victory);
        victory.ShowResult("Victory", UiColors.Victory);
        victory.ShowParty(uiParty.Members);
        Check("results identify the member awaiting promotion", victory.GetNode<OptionButton>("%PartyMember").GetItemText(0).Contains("Promotion available"));
        victory.GetNode<Button>("%DetailsButton").EmitSignal(Button.SignalName.Pressed);
        Check("results open the live member's progression", victory.GetNode<CharacterDetailsOverlay>("%ResultDetails").Visible
            && victory.GetNode<CharacterDetailsOverlay>("%ResultDetails").GetNode<PromotionPanel>("%Progression").Visible);
        victory.HideResult();
    }

    private async Task Capture()
    {
        if (DisplayServer.GetName() == "headless") return;
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string path = ProjectSettings.GlobalizePath("res://.godot/promotion_sheet.png");
        Check("promotion sheet screenshot saved", SaveViewportCapture(path) == Error.Ok);
        GD.Print(path);
    }
}
