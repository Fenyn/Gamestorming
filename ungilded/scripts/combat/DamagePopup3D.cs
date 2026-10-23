using Ungilded.Fx;
using Ungilded.UI;
using Godot;
using PF2e.Data;

namespace Ungilded.Combat;

/// <summary>Floating combat text (damage / crit / MISS / heal) as a billboarded Label3D that rises,
/// fades, and self-frees. Static presentation props live in scenes/combat/damage_popup.tscn; Create /
/// CreateHeal instance it and set the per-spawn text, size, and color.</summary>
public partial class DamagePopup3D : Label3D
{
    /// <param name="label">A word shown before the number ("Splash 1"); null shows the number alone.</param>
    public static DamagePopup3D Create(int amount, DamageType? damageType, DegreeOfSuccess? degree, string? label = null)
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
            popup.Text = string.IsNullOrEmpty(label) ? amount.ToString() : $"{label} {amount}";
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

    /// <summary>Multiplier on every beat below; 1.25 plays them a quarter slower.</summary>
    public float Pace { get; set; } = 1f;

    /// <summary>The number drops this far onto its spot while it grows to <see cref="PopScale"/>,
    /// then settles to full size.</summary>
    [Export] public float DropMetres { get; set; } = 0.3f;
    [Export] public float PopScale { get; set; } = 1.7f;
    [Export] public float PopInSeconds { get; set; } = 0.10f;
    [Export] public float PopSettleSeconds { get; set; } = 0.14f;
    /// <summary>The landed number holds still this long; the presenter drains the HP bar after it.</summary>
    [Export] public float HitStopSeconds { get; set; } = 0.12f;
    [Export] public float RiseMetres { get; set; } = 0.9f;
    [Export] public float RiseSeconds { get; set; } = 0.8f;
    [Export] public float FadeDelaySeconds { get; set; } = 0.3f;
    [Export] public float FadeSeconds { get; set; } = 0.6f;

    /// <summary>Seconds at pace 1 from the spawn until the number sits at full size.</summary>
    public float LandSeconds => PopInSeconds + PopSettleSeconds;

    /// <summary>A zero scale gives the billboard a degenerate basis.</summary>
    private const float StartScale = 0.01f;

    public override void _Ready()
    {
        var rest = Position;
        Position = rest + Vector3.Up * DropMetres;
        Scale = Vector3.One * StartScale;
        var tween = CreateTween();
        tween.SetSpeedScale(1f / Pace);
        tween.TweenProperty(this, "position", rest, PopInSeconds).SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
        tween.Parallel().TweenProperty(this, "scale", Vector3.One * PopScale, PopInSeconds)
            .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(this, "scale", Vector3.One, PopSettleSeconds).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenInterval(HitStopSeconds);
        tween.TweenProperty(this, "position", rest + Vector3.Up * RiseMetres, RiseSeconds).SetEase(Tween.EaseType.Out);
        tween.Parallel().TweenProperty(this, "modulate:a", 0f, FadeSeconds).SetDelay(FadeDelaySeconds);
        tween.TweenCallback(Callable.From(QueueFree));
    }
}
