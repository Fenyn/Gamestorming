using Godot;
using PF2e.Data;

namespace Bulwark.Combat;

/// <summary>Floating combat text (damage / crit / MISS / heal) as a billboarded Label3D that rises,
/// fades, and self-frees. Same Create semantics as the old 2D DamagePopup.</summary>
public partial class DamagePopup3D : Label3D
{
    public static DamagePopup3D Create(int amount, DamageType? damageType, DegreeOfSuccess? degree)
    {
        var popup = NewPopup();

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
        var popup = NewPopup();
        popup.Text = $"+{amount}";
        popup.FontSize = 52;
        popup.Modulate = new Color(0.25f, 1f, 0.35f);
        return popup;
    }

    private static DamagePopup3D NewPopup() => new()
    {
        Billboard = BaseMaterial3D.BillboardModeEnum.Enabled,
        PixelSize = 0.006f,
        OutlineSize = 10,
        OutlineModulate = Colors.Black,
        NoDepthTest = true,
        RenderPriority = 2,
    };

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
