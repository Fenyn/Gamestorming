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
    private const string OutDir = "user://dev_shots";

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
        panel.Setup(new UnlockState());
        DirAccess.MakeDirRecursiveAbsolute(OutDir);

        foreach (var def in CharacterCatalog.All)
        {
            if (!panel.CanPick(def.Id)) continue;
            panel.Pick(def.Id);
            await Settle();
            Capture($"hero_select_{def.DisplayName.ToLowerInvariant()}.png");
        }

        panel.Pick(PresetCharacters.FenwickId);
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

        panel.Pick(PresetCharacters.PlayerId);
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
        for (int i = 0; i < 4; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
