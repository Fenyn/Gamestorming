using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Utilities;

namespace Delve.Dev;

/// <summary>
/// Walk of the hero-select screen. Instances the panel on its own, drives it through
/// <see cref="HeroSelectPanel.Pick"/> - the same entry point a card click calls - and asserts the
/// gates: nothing embarks until a character is chosen, a character who cannot lead is refused, a
/// locked character is refused, and the confirmed payload is a legal solo party.
///
/// It then reads every roster entry's featured sheet straight off the character its preset builds
/// and checks the overview back against the rules engine: four headline numbers and no more, a
/// headlined key ability that names itself and leaves the modifier to the rail, six abilities with
/// one key, one line of plain words per row, an explanation behind every element, and a laid-out
/// height that fits the panel without scrolling.
/// </summary>
public partial class HeroSelectSpike : SpikeBase
{
    /// <summary>The screen under test. Assigned in hero_select_spike.tscn.</summary>
    [Export] public PackedScene? PanelScene { get; set; }

    /// <summary>One body section, for the over-long list no preset is long enough to reach.
    /// Assigned in hero_select_spike.tscn.</summary>
    [Export] public PackedScene? SectionScene { get; set; }

    /// <summary>The frame the layout check lays the screen out in - the project's own canvas.</summary>
    private static readonly Vector2 Canvas = new(1920, 1080);

    /// <summary>The least of its panel a sheet may fill before the panel's lower third reads as
    /// dead space. The ceiling is the panel itself: nothing scrolls.</summary>
    private const float MinFill = 0.85f;

    private string? _leaderSeen;
    private IReadOnlyList<string>? _membersSeen;

    protected override string Banner => "==================== HERO SELECT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (PanelScene == null)
        {
            AbortFail("[HeroSelect] PanelScene is not assigned - aborting.");
            return;
        }

        var panel = PanelScene.Instantiate<HeroSelectPanel>();
        AddChild(panel);
        panel.Confirmed += (leader, members) => { _leaderSeen = leader; _membersSeen = members; };

        // ---------------------------------------------------- (1) the empty screen
        panel.Setup(new UnlockState());
        Check("(1) nothing is chosen", panel.Chosen == null);
        Check("(1) Embark is disabled", !panel.CanEmbark);
        Check($"(1) the hint asks for a character ({panel.HintText})",
            panel.HintText == "Pick who enters the depths alone — companions join along the way.");
        Check("(1) an id outside the catalog cannot be picked", !panel.CanPick(PresetCharacters.RecruitId));
        Check("(1) a character who can lead is offered it", panel.CanPick(PresetCharacters.ElaraId));

        panel.Pick(PresetCharacters.RecruitId);
        Check("(1) picking an unknown id chooses nobody", panel.Chosen == null);

        var roster = HeroSelectChecks.Cards(panel);
        Check($"(1) the roster shows every catalog entry ({roster.Count})",
            roster.Count == CharacterCatalog.All.Count);
        Check("(1) a leader card takes clicks",
            HeroSelectChecks.Card(roster, PresetCharacters.PlayerId) is { Disabled: false });

        // ---------------------------------------------------- (2) choosing one
        panel.Pick(PresetCharacters.ElaraId);
        Check("(2) the pick is the starting character", panel.Chosen == PresetCharacters.ElaraId);
        Check($"(2) the hint reads as ready ({panel.HintText})", panel.HintText == "Ready to delve.");
        Check("(2) Embark is open", panel.CanEmbark);

        panel.Embark();
        Check("(2) the starting character is signalled", _leaderSeen == PresetCharacters.ElaraId);
        Check("(2) no companions are signalled", _membersSeen is { Count: 0 });
        Check("(2) the payload builds a legal solo party", HeroSelectChecks.BuildsAParty(_leaderSeen, _membersSeen));

        panel.Unpick();
        Check("(2) Esc gives the pick back", panel.Chosen == null && !panel.CanEmbark);

        // ---------------------------------------------------- (3) locked characters
        panel.Setup(new UnlockState(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId }));
        Check("(3) a locked card cannot be chosen", !panel.CanPick(PresetCharacters.TharrId));
        panel.Pick(PresetCharacters.TharrId);
        Check("(3) clicking a locked card chooses nobody", panel.Chosen == null);
        Check("(3) an unlocked card still works", panel.CanPick(PresetCharacters.PlayerId));

        var locked = HeroSelectChecks.Cards(panel);
        Check("(3) the locked card is disabled and says why",
            HeroSelectChecks.Card(locked, PresetCharacters.TharrId) is { Disabled: true, TooltipText: "Unavailable: locked" });
        Check("(3) an unlocked leader card still takes clicks",
            HeroSelectChecks.Card(locked, PresetCharacters.PlayerId) is { Disabled: false });

        RemoveChild(panel);
        panel.QueueFree();

        Overview();
        Explanations();
        await Fit();
    }

    // ---------------------------------------------------- (4) the overview

    /// <summary>What the page is allowed to print. Everything else demotes to a hover.</summary>
    private void Overview()
    {
        foreach (var def in CharacterCatalog.All)
        {
            var built = def.Builder(Party.DefaultLevel);
            var sheet = HeroSheetBuilder.Read(built);

            Check($"(4) {def.Id} headlines exactly four numbers ({sheet.Headlines.Count})",
                sheet.Headlines.Count == 4);
            Check($"(4) {def.Id} prints six ability boxes", sheet.Abilities.Count == 6);
            Check($"(4) {def.Id} flags exactly one key ability",
                HeroSelectChecks.KeyAbilities(sheet) == 1);
            Check($"(4) {def.Id} HP matches the build ({sheet.HitPoints})",
                sheet.HitPoints == built.Health?.MaxHP
                && HeroSelectChecks.Headline(sheet, "HP") == sheet.HitPoints.ToString());
            Check($"(4) {def.Id} AC matches the build ({sheet.ArmorClass})",
                sheet.ArmorClass == StatsCalculator.CalculateAC(built)
                && HeroSelectChecks.Headline(sheet, "AC") == sheet.ArmorClass.ToString());
            Check($"(4) {def.Id} headlines its key ability by name alone " +
                  $"({HeroSelectChecks.Headline(sheet, "KEY ABILITY")})",
                HeroSelectChecks.Headline(sheet, "KEY ABILITY") is { } key
                && key == HeroSelectChecks.KeyAbilityCode(sheet));

            Check($"(4) {def.Id} keeps every row to one line of words",
                HeroSelectChecks.SingleLine(sheet));
            Check($"(4) {def.Id} prints no rank letter on the page",
                HeroSelectChecks.NoRankLetters(sheet));
            Check($"(4) {def.Id} names a trained skill",
                HeroSelectChecks.RowEntries(sheet, HeroSheetBuilder.SkillsRow) > 0);
            Check($"(4) {def.Id} lists a feature or feat",
                HeroSelectChecks.RowEntries(sheet, HeroSheetBuilder.FeaturesRow) > 0);
            Check($"(4) {def.Id} strikes with what it carries",
                HeroSelectChecks.StrikeShowsBonus(built, sheet));
            Check($"(4) {def.Id} lists what it wears",
                HeroSelectChecks.RowEntries(sheet, HeroSheetBuilder.DefencesRow) > 0);

            bool caster = built.Spellcasting != null;
            Check($"(4) {def.Id} shows a spells row only if it casts",
                caster == (sheet.Row(HeroSheetBuilder.SpellsRow) != null));
            if (!caster) continue;

            Check($"(4) {def.Id} headlines its spell DC",
                HeroSelectChecks.Headline(sheet, "SPELL DC") is { Length: > 0 });
            Check($"(4) {def.Id} groups its cantrips and its rank 1 slots",
                HeroSelectChecks.HasChip(sheet, HeroSheetBuilder.SpellsRow, "Cantrips")
                && HeroSelectChecks.HasChip(sheet, HeroSheetBuilder.SpellsRow, "Rank 1"));
        }

        Check("(4) Tharr's divine font is a chip of its own",
            HeroSelectChecks.HasChip(Sheet(PresetCharacters.TharrId), HeroSheetBuilder.SpellsRow,
                "Divine Font"));
        Check("(4) Fenwick has no divine font",
            !HeroSelectChecks.HasChip(Sheet(PresetCharacters.FenwickId), HeroSheetBuilder.SpellsRow,
                "Divine Font"));
    }

    // ---------------------------------------------------- (5) what the sheet explains

    /// <summary>The depth the page gave up has to be somewhere, and it is on the hover.</summary>
    private void Explanations()
    {
        foreach (var def in CharacterCatalog.All)
        {
            var sheet = Sheet(def.Id);

            Check($"(5) {def.Id} explains every element it prints",
                HeroSelectChecks.Untipped(sheet) == 0);
            Check($"(5) {def.Id} titles and writes every tip ({HeroSelectChecks.TipCount(sheet)})",
                HeroSelectChecks.Blank(sheet) == 0);
            Check($"(5) {def.Id} spells the strike bonus out in its tip",
                HeroSelectChecks.StrikeTipCarriesBonus(sheet));
            Check($"(5) {def.Id} describes at least one feat",
                HeroSelectChecks.FeatureExplained(sheet));
        }

        var healTip = HeroSelectChecks.SpellTip(Sheet(PresetCharacters.TharrId), "Heal");
        Check("(5) Tharr's Heal is named on a spell chip", healTip != null);
        Check("(5) Tharr's Heal reads out of the pack",
            healTip != null && HeroSelectChecks.SpellRowText(healTip, "Heal") is { Length: > 40 } heal
            && heal.Contains(" — ", StringComparison.Ordinal));

        var fireTip = HeroSelectChecks.SpellTip(Sheet(PresetCharacters.FenwickId), "Breathe Fire");
        Check("(5) Fenwick's Breathe Fire reads out of the pack",
            fireTip != null
            && HeroSelectChecks.SpellRowText(fireTip, "Breathe Fire") is { Length: > 40 } fire
            && fire.Contains(" — ", StringComparison.Ordinal));
    }

    // ---------------------------------------------------- (6) the sheet fits

    /// <summary>
    /// Lay the whole screen out at the project's canvas size and read every character's sheet in
    /// it. The overview earns its shape only if it both fits and fills: content taller than the
    /// panel is the spreadsheet this screen was rebuilt to stop being, and content that stops two
    /// thirds of the way down leaves a panel with a dead lower third. The page's shared edges are
    /// measured in the same pass.
    /// </summary>
    private async Task Fit()
    {
        var frame = new Control { CustomMinimumSize = Canvas, Size = Canvas };
        AddChild(frame);

        var panel = PanelScene!.Instantiate<HeroSelectPanel>();
        frame.AddChild(panel);
        panel.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        panel.Setup(new UnlockState());

        var sheet = panel.GetNode<Control>("%Sheet");
        foreach (var def in CharacterCatalog.All)
        {
            panel.Preview(def.Id);
            await Settle();

            float content = sheet.GetCombinedMinimumSize().Y;
            float fill = sheet.Size.Y <= 0f ? 0f : content / sheet.Size.Y;
            Check($"(6) {def.Id}'s sheet fills its panel ({content:0} of {sheet.Size.Y:0} px, {fill:P0})",
                fill >= MinFill && fill <= 1f);
        }

        HeroSelectGrid.Report(panel, Canvas, Check);
        HeroSelectGrid.Bands(panel, Check);

        await Overflow(frame);
        RemoveChild(frame);
        frame.QueueFree();
    }

    /// <summary>
    /// A list section longer than the cap stops at the last entry that fits and prints "+N more",
    /// whose hover names everything hidden, so a build with twenty feats costs the sheet the same
    /// lines as one with eight. No preset reaches that branch, so the spike hands it one that does.
    /// </summary>
    private async Task Overflow(Control frame)
    {
        if (SectionScene == null) { Check("(7) SectionScene is assigned", false); return; }

        var probe = new Control { CustomMinimumSize = new Vector2(400, 400), Size = new Vector2(400, 400) };
        frame.AddChild(probe);

        var section = SectionScene.Instantiate<SheetSection>();
        SheetTip? tailTip = null;
        section.TipTarget += (tip, target) => tailTip = tip;
        probe.AddChild(section);

        var many = new List<SheetEntry>(40);
        for (int i = 0; i < 40; i++)
            many.Add(new SheetEntry($"Feat Number {i}", new SheetTip($"Feat {i}", "", "granted")));
        section.Fill(new SheetRow(HeroSheetBuilder.FeaturesRow, many, SheetRowStyle.Chips), inline: false);
        await Settle();

        var items = section.GetNode<Control>("%SectionItems");
        int shown = items.GetChildCount();
        Check($"(7) an over-long list drops its tail ({shown} items of {many.Count})",
            shown == SheetSection.MaxListItems);
        Check($"(7) the tail collapses into +N more ({HeroSelectChecks.LastChip(items)})",
            HeroSelectChecks.LastChip(items).StartsWith('+'));
        Check("(7) the tail's hover names every hidden entry",
            tailTip != null && tailTip.Body.Contains("Feat Number 39", StringComparison.Ordinal));

        probe.QueueFree();
    }

    /// <summary>Enough frames for the containers to size and the chip rows to settle their fit.</summary>
    private async Task Settle()
    {
        for (int i = 0; i < 4; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    // ---------------------------------------------------------------- Parts

    private static HeroSheetData Sheet(string id)
    {
        var def = CharacterCatalog.Find(id);
        return def == null
            ? HeroSheetData.Unknown(id)
            : HeroSheetBuilder.Read(def.Builder(Party.DefaultLevel));
    }
}
