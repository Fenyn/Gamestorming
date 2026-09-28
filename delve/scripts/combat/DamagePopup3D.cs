using Delve.Fx;
using Delve.UI;
using Godot;
using PF2e.Data;

namespace Delve.Combat;

/// <summary>Floating combat text (damage / crit / MISS / heal) as a billboarded Label3D that rises,
/// fades, and self-frees. Static presentation props live in scenes/combat/damage_popup.tscn; Create /
/// CreateHeal instance it and set the per-spawn text, size, and color.</summary>
public partial class DamagePopup3D : Label3D
{
    public static DamagePopup3D Create(int amount, DamageType? damageType, DegreeOfSuccess? degree)
    {
        var popup = FxLibrary.DamagePopupScene.Instantiate<DamagePopup3D>();

        bool isCrit = degree == DegreeOfSuccess.CriticalSuccess;
        bool isMiss = degree == DegreeOfSuccess.Failure;
        bool isFumble = degree == DegreeOfSuccess.CriticalFailure;

        if (isMiss || isFumble)
        {
            popup.Text = isFumble ? "FUMBLE" : "MISS";
            popup.Modulate = UiColors.PopupMiss;
            popup.FontSize = 40;
        }
        else
        {
            popup.Text = amount.ToString();
            popup.FontSize = isCrit ? 72 : 52;
            // An untyped hit has no flavour colour, so a crit reads red and an ordinary hit reads white.
            popup.Modulate = DamageColors.For(damageType)
                ?? (isCrit ? UiColors.PopupCrit : Colors.White);
        }
        return popup;
    }

    public static DamagePopup3D CreateHeal(int amount)
    {
        var popup = FxLibrary.DamagePopupScene.Instantiate<DamagePopup3D>();
        popup.Text = $"+{amount}";
        popup.FontSize = 52;
        popup.Modulate = UiColors.PopupHeal;
        return popup;
    }

    public override void _Ready()
    {
        var start = Position;
        var tween = CreateTween();
        tween.SetParallel(true);
        tween.TweenProperty(this, "position", start + new Vector3(0f, 0.9f, 0f), 0.8f).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(this, "modulate:a", 0f, 0.8f).SetDelay(0.3f);
        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }
}
