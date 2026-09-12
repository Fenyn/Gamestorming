using System.Threading.Tasks;
using Delve.Combat;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatShotSpike
{
    // Deterministic presentation fixtures cover states the random encounter cannot guarantee.
    private async Task CaptureHudReview(CombatScene scene)
    {
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var controls = bar.GetNode<Button>("%ControlButton");
        var options = bar.GetNode<Control>("%ControlOptions");
        var spells = bar.GetNode<Button>("%SpellsButton");
        controls.ButtonPressed = true;
        await WaitSeconds(PoseSeconds);
        Check("control preferences open without the spell menu", options.Visible && !bar.GetNode<Control>("%Flyout").Visible);
        Capture("combat_controls.png");
        spells.ButtonPressed = true;
        Check("spell menu closes control preferences", !options.Visible && !controls.ButtonPressed);
        spells.ButtonPressed = false;
        controls.ButtonPressed = true;
        bar._UnhandledInput(new InputEventAction { Action = InputNames.UiCancel, Pressed = true });
        Check("Escape closes preferences", !options.Visible && !controls.ButtonPressed);

        var inspect = scene.GetNode<UnitInspectPanel>("%UnitInspect");
        inspect.Render(new UnitInspectView
        {
            Name = "Goblin Warrior", IsAlly = false, Hp = 14, MaxHp = 20,
            AcText = "AC ?", HpText = "?/?",
            Conditions = new[] { "Frightened 2", "Off-guard", "Shield Raised" },
        });
        bar.SetTargetingHint(true);
        bar.ShowAttackPreview(new AttackPreviewView
        {
            AttackerName = "Fenwick", TargetName = "Goblin Warrior", WeaponName = "Crossbow",
            TotalAttackBonus = 8, TargetAcText = "?", HitChanceText = "?%",
            CritChanceText = "?%", DamageFormula = "1d8 piercing", TargetOffGuard = true,
        });
        await WaitSeconds(PoseSeconds);
        var preview = bar.GetNode<Control>("%PreviewCard");
        var end = bar.GetNode<Control>("%EndButton");
        Check("inspect does not overlap the command row", !inspect.GetGlobalRect().Intersects(end.GetGlobalRect()));
        Check("inspect and attack forecast have separate space", !inspect.GetGlobalRect().Intersects(preview.GetGlobalRect()));
        Check("forecast preserves unknown hit chance", bar.GetNode<Label>("%PreviewStatsLabel").Text.StartsWith("?% hit"));
        Check("inspect preserves unknown HP and AC", inspect.GetNode<Label>("%HpLabel").Text == "?/?"
            && inspect.GetNode<Label>("%AcLabel").Text == "AC ?");
        Capture("combat_target_preview.png");
        inspect.Render(null);
        bar.ShowAttackPreview(null);
        bar.SetTargetingHint(false);
    }
}
