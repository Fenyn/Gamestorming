using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered smoke test for the run's menu screens (scenes/dev/ui_shot_spike.tscn). Stands the
/// hero-select panel up on its own canvas layer and captures one shot per character the roster
/// lets you lead - the shortest sheet and the longest have to sit on the same grid - plus one
/// with a tooltip summoned over a chip.
///
/// Captures go to user://dev_shots (a run artifact, never repo content); each save prints its
/// globalized OS path. Must run rendered, NOT --headless:
///   godot --path delve res://scenes/dev/ui_shot_spike.tscn
/// </summary>
public partial class UiShotSpike : SpikeBase
{
    private string OutDir => string.IsNullOrEmpty(OS.GetEnvironment("DELVE_SHOT_DIRECTORY"))
        ? "user://dev_shots" : OS.GetEnvironment("DELVE_SHOT_DIRECTORY");

    /// <summary>Capture size. The screens are authored against the project viewport and reviewed at
    /// this reference size.</summary>
    private const int ShotWidth = 1600;
    private const int ShotHeight = 900;

    /// <summary>The chip the tooltip shot hovers - Fenwick's rank 1 slots, the longest tip the
    /// sheet can show.</summary>
    private const string TooltipUnderTest = "Rank 1";

    /// <summary>The screen to shoot. Assigned in ui_shot_spike.tscn.</summary>
    [Export] public PackedScene? PanelScene { get; set; }

    protected override string Banner => "==================== UI SHOT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (PanelScene == null)
        {
            AbortFail("[uishot] PanelScene is not assigned - aborting.");
            return;
        }

        var layer = new CanvasLayer();
        AddChild(layer);
        var panel = PanelScene.Instantiate<HeroSelectPanel>();
        layer.AddChild(panel);
        var campaign = new CampaignProgress();
        panel.Setup(campaign.Unlocks, campaign);
        DirAccess.MakeDirRecursiveAbsolute(OutDir);

        foreach (var def in CharacterCatalog.All)
        {
            if (!panel.CanPick(def.Id)) continue;
            panel.Preview(def.Id);
            await Settle();
            Capture($"hero_select_{def.DisplayName.ToLowerInvariant()}.png");
        }

        panel.Pick(PresetCharacters.ElaraId);
        panel.Pick(PresetCharacters.PlayerId);
        panel.Pick(PresetCharacters.TharrId);
        panel.Pick(PresetCharacters.FenwickId);
        await Settle();
        Check("four selected members enable embark", panel.CanEmbark);
        Capture("hero_select_formation.png");
        panel.Pick(PresetCharacters.PlayerId);
        await Settle();
        Capture("camp_companion_resting.png");
        panel.Pick(PresetCharacters.PlayerId);
        await ToSignal(GetTree().CreateTimer(0.2), SceneTreeTimer.SignalName.Timeout);
        Capture("camp_getting_ready.png");
        campaign.Unlocks.Unlock(PresetCharacters.RavenId);
        campaign.Unlocks.Unlock(PresetCharacters.ThistleId);
        panel.RefreshRecruitment();
        await Settle();
        Capture("camp_all_unlocked.png");
        await CaptureCampCapacity(panel);
        var recruitment = panel.GetNode<RecruitmentPanel>("%Recruitment");
        recruitment.Open();
        await Settle();
        Capture("hero_select_recruitment.png");
        recruitment.Hide();

        panel.Preview(PresetCharacters.FenwickId);
        await Settle();
        Check("a sheet tooltip can be summoned", panel.ShowTipForTesting(TooltipUnderTest));
        await Settle();
        Capture("hero_select_tooltip.png");

        // The full card template with every slot filled, so the shot proves the fixed layout
        // before real data reaches the new slots.
        Check("a full sample card renders", panel.ShowCardForTesting(new SheetTip(
            "Shield Block",
            "",
            "Your shield takes the hit instead of you. The shield's Hardness comes off the "
            + "damage, and you and the shield split what remains.",
            SheetActionCost.Reaction,
            new[] { "general", "fighter" },
            "FEAT 1",
            new[]
            {
                new SheetMetaRow("Trigger", "While you have your shield raised, you would take "
                    + "physical damage from an attack."),
                new SheetMetaRow("Requirements", "You are wielding a shield."),
            },
            "Steel shield - Hardness 5, HP 20, BT 10")));
        await Settle();
        Capture("hero_select_card.png");

        panel.Preview(PresetCharacters.PlayerId);
        await Settle();
        Check("a skill card can be summoned", panel.ShowTipForTesting("Intimidation"));
        await Settle();
        Capture("hero_select_skill.png");

        Check("a strike card can be summoned", panel.ShowTipForTesting("Longsword"));
        await Settle();
        Capture("hero_select_strike.png");

        Check("a vital card can be summoned", panel.ShowTipForTesting("Armour Class"));
        await Settle();
        Capture("hero_select_ac.png");

        Check("a feat card can be summoned", panel.ShowTipForTesting("Reactive Shield"));
        await Settle();
        Capture("hero_select_feat.png");

        panel.Preview(PresetCharacters.ElaraId);
        await Settle();
        Check("Sneak Attack tooltip renders", panel.ShowTipForTesting("Sneak Attack"));
        await Settle();
        Capture("hero_select_sneak_attack.png");
        Check("Shortsword tooltip renders", panel.ShowTipForTesting("Shortsword"));
        await Settle();
        Capture("hero_select_shortsword.png");
        Check("Double Slice summary opens", panel.ShowTipForTesting("Double Slice"));
        await Settle();
        var tip = panel.GetNode<HeroSheet>("%Sheet").GetNode<CanvasLayer>("%TipLayer").GetChild<Delve.UI.SheetTooltip>(0);
        Check("Double Slice summary fits without scrolling", !tip.GetNode<Label>("%ScrollHint").Visible);
        Capture("double_slice_summary.png");
        tip.GetNode<Button>("%FullRules").EmitSignal(Button.SignalName.Pressed);
        await Settle();
        Check("full rules stay within the viewport", GetViewport().GetVisibleRect().Encloses(tip.GetGlobalRect()));
        var scroll = tip.GetNode<ScrollContainer>("%Scroll");
        scroll.ScrollVertical = 10000;
        await Settle();
        var body = tip.GetNode<VBoxContainer>("%Body");
        var last = body.GetChild<Label>(body.GetChildCount() - 1);
        Check("Double Slice retains its final rule", last.Text.Replace("\n", " ").Contains("multiple attack penalty."));
        Check("the final rule is reachable by scrolling", scroll.GetGlobalRect().Encloses(last.GetGlobalRect()));
        Capture("double_slice_full_rules.png");
        tip.GetNode<Button>("%FullRules").EmitSignal(Button.SignalName.Pressed);
        await Settle();
        Check("returning to summary resets scrolling", scroll.ScrollVertical == 0 && !tip.GetNode<Label>("%ScrollHint").Visible);
        var reviewed = new System.Collections.Generic.HashSet<string>();
        foreach (var def in CharacterCatalog.All)
        {
            var sheet = HeroSheetBuilder.Read(def.Builder(Party.DefaultLevel));
            var features = sheet.Row(HeroSheetBuilder.FeaturesRow);
            if (features == null) continue;
            foreach (var entry in features.Entries)
            {
                if (entry.Tip is not { } feature || !reviewed.Add(feature.Title)) continue;
                Check($"{feature.Title} has summary and full rules", feature.Meta is { Count: > 0 }
                    && feature.Body.Length == 0 && feature.FullRules is { Length: > 0 });
                panel.ShowCardForTesting(feature);
                await Settle();
                Check($"{feature.Title} summary fits without scrolling", !tip.GetNode<Label>("%ScrollHint").Visible
                    && GetViewport().GetVisibleRect().Encloses(tip.GetGlobalRect()));
                Capture($"feat_{Delve.Data.PackText.Slug(feature.Title)}.png");
            }
        }
    }

    private async Task CaptureCampCapacity(HeroSelectPanel panel)
    {
        var stage = panel.GetNode<CampStage>("%CampStage");
        var roster = panel.GetNode<Control>("%RosterList");
        var hint = panel.GetNode<Label>("%HintLabel");
        string original = hint.Text;
        hint.Text = "LAYOUT STUDY / 18 reserved places / placeholder art for future recruits";
        var samples = new System.Collections.Generic.List<CampResident>();
        for (int i = 6; i < stage.SeatIds.Length; i++)
        {
            string id = stage.SeatIds[i];
            var def = CharacterCatalog.All[0] with { Id = id, DisplayName = id == "aldric" ? "Sir Garran*" : char.ToUpperInvariant(id[0]) + id[1..] };
            var sample = panel.CardScene!.Instantiate<CampResident>();
            roster.AddChild(sample);
            sample.Setup(def, stage.AppearanceFor(i % 6), i);
            sample.Position = stage.SeatPosition(i) - new Vector2(82, 160);
            samples.Add(sample);
        }
        await Settle();
        Capture("camp_capacity_study.png");
        foreach (var sample in samples) { roster.RemoveChild(sample); sample.QueueFree(); }
        hint.Text = original;
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(ShotWidth, ShotHeight, Image.Interpolation.Bilinear);
        string path = $"{OutDir}/{file}";
        Error err = img.SavePng(path);
        GD.Print($"[uishot] {file}: {err} ({ProjectSettings.GlobalizePath(path)})");
        Check($"{file} saved", err == Error.Ok);
    }

    /// <summary>Enough rendered frames for the state change, the chip rows settling their fit,
    /// and the hover tweens to all be on screen.</summary>
    private async Task Settle()
    {
        await ToSignal(GetTree().CreateTimer(0.8), SceneTreeTimer.SignalName.Timeout);
        for (int i = 0; i < 4; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
