using Godot;
using PF2e.Data;

namespace Autobattler;

public partial class DamagePopup : Label
{
    public static DamagePopup Create(int amount, DamageType? damageType, PF2e.Data.DegreeOfSuccess? degree)
    {
        var popup = new DamagePopup();

        bool isCrit = degree == DegreeOfSuccess.CriticalSuccess;
        bool isMiss = degree == DegreeOfSuccess.Failure;
        bool isFumble = degree == DegreeOfSuccess.CriticalFailure;

        if (isMiss)
        {
            popup.Text = "MISS";
            popup.AddThemeColorOverride("font_color", new Color(0.5f, 0.5f, 0.5f));
            popup.AddThemeFontSizeOverride("font_size", 12);
        }
        else if (isFumble)
        {
            popup.Text = "FUMBLE";
            popup.AddThemeColorOverride("font_color", new Color(0.4f, 0.4f, 0.4f));
            popup.AddThemeFontSizeOverride("font_size", 12);
        }
        else
        {
            popup.Text = amount.ToString();
            popup.AddThemeFontSizeOverride("font_size", isCrit ? 22 : 16);

            Color color = damageType switch
            {
                DamageType.Fire => new Color(1f, 0.4f, 0.1f),
                DamageType.Cold => new Color(0.3f, 0.7f, 1f),
                DamageType.Electricity => new Color(1f, 1f, 0.3f),
                DamageType.Acid => new Color(0.4f, 1f, 0.2f),
                DamageType.Poison => new Color(0.6f, 0.2f, 0.8f),
                DamageType.Mental => new Color(0.8f, 0.3f, 1f),
                DamageType.Vitality => new Color(1f, 1f, 0.8f),
                DamageType.Void => new Color(0.4f, 0f, 0.6f),
                _ => isCrit ? new Color(1f, 0.2f, 0.2f) : Colors.White
            };
            popup.AddThemeColorOverride("font_color", color);
        }

        popup.AddThemeColorOverride("font_shadow_color", Colors.Black);
        popup.AddThemeConstantOverride("shadow_offset_x", 1);
        popup.AddThemeConstantOverride("shadow_offset_y", 1);

        return popup;
    }

    public static DamagePopup CreateHeal(int amount)
    {
        var popup = new DamagePopup();
        popup.Text = $"+{amount}";
        popup.AddThemeFontSizeOverride("font_size", 16);
        popup.AddThemeColorOverride("font_color", new Color(0.2f, 1f, 0.3f));
        popup.AddThemeColorOverride("font_shadow_color", Colors.Black);
        popup.AddThemeConstantOverride("shadow_offset_x", 1);
        popup.AddThemeConstantOverride("shadow_offset_y", 1);
        return popup;
    }

    public override void _Ready()
    {
        var tween = CreateTween();
        tween.SetParallel(true);
        tween.TweenProperty(this, "position:y", Position.Y - 40, 0.8f)
            .SetEase(Tween.EaseType.Out);
        tween.TweenProperty(this, "modulate:a", 0f, 0.8f)
            .SetDelay(0.3f);
        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }
}
