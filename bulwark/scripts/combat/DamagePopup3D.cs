using Godot;
using PF2e.Data;

namespace Bulwark.Combat;

/// <summary>Floating combat text (damage / crit / MISS / heal) as a billboarded Label3D that rises,
/// fades, and self-frees. Static presentation props live in scenes/combat/damage_popup.tscn; Create /
/// CreateHeal instance it and set the per-spawn text, size, and color.</summary>
public partial class DamagePopup3D : Label3D
{
    // Preloaded blockout (billboard/outline/render-priority props authored in the scene).
    private static readonly PackedScene Scene =
        GD.Load<PackedScene>("res://scenes/combat/damage_popup.tscn");

    public static DamagePopup3D Create(int amount, DamageType? damageType, DegreeOfSuccess? degree)
    {
        var popup = Scene.Instantiate<DamagePopup3D>();

        bool isCrit = degree == DegreeOfSuccess.CriticalSuccess;
        bool isMiss = degree == DegreeOfSuccess.Failure;
        bool isFumble = degree == DegreeOfSuccess.CriticalFailure;

        if (isMiss || isFumble)
        {
            popup.Text = isFumble ? "FUMBLE" : "MISS";
            popup.Modulate = new Color(0.65f, 0.65f, 0.65f);
            popup.FontSize = 40;
        }
        else
        {
            popup.Text = amount.ToString();
            popup.FontSize = isCrit ? 72 : 52;
            popup.Modulate = damageType switch
            {
                DamageType.Fire => new Color(1f, 0.4f, 0.1f),
                DamageType.Cold => new Color(0.3f, 0.7f, 1f),
                DamageType.Electricity => new Color(1f, 1f, 0.3f),
                DamageType.Acid => new Color(0.4f, 1f, 0.2f),
                DamageType.Poison => new Color(0.6f, 0.2f, 0.8f),
                DamageType.Mental => new Color(0.8f, 0.3f, 1f),
                _ => isCrit ? new Color(1f, 0.35f, 0.35f) : Colors.White,
            };
        }
        return popup;
    }

    public static DamagePopup3D CreateHeal(int amount)
    {
        var popup = Scene.Instantiate<DamagePopup3D>();
        popup.Text = $"+{amount}";
        popup.FontSize = 52;
        popup.Modulate = new Color(0.25f, 1f, 0.35f);
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
