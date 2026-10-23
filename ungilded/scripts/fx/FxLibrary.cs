using Godot;

namespace Ungilded.Fx;

/// <summary>Single place that loads the one-shot effect and popup blockouts. Each scene loads on
/// first use, so a headless tool that never spawns an effect never touches the disk for one. The
/// HD-2D effect scenes are the exception: <see cref="PreloadEncounterEffects"/> loads them as an
/// encounter starts.</summary>
public static class FxLibrary
{
    private static PackedScene? _hitSpark;
    private static PackedScene? _shieldFlash;
    private static PackedScene? _damagePopup;
    private static PackedScene? _acidSplash;
    private static PackedScene? _treatWounds;
    private static PackedScene? _deathDust;
    private static PackedScene? _flaskThrow;

    public static PackedScene HitSparkScene =>
        _hitSpark ??= GD.Load<PackedScene>("res://scenes/fx/hit_spark.tscn");

    public static PackedScene AcidSplashScene =>
        _acidSplash ??= GD.Load<PackedScene>("res://scenes/fx/acid_splash.tscn");

    public static PackedScene TreatWoundsScene =>
        _treatWounds ??= GD.Load<PackedScene>("res://scenes/fx/treat_wounds.tscn");

    public static PackedScene DeathDustScene =>
        _deathDust ??= GD.Load<PackedScene>("res://scenes/fx/death_dust.tscn");

    public static PackedScene FlaskThrowScene =>
        _flaskThrow ??= GD.Load<PackedScene>("res://scenes/fx/flask_throw.tscn");

    public static PackedScene ShieldFlashScene =>
        _shieldFlash ??= GD.Load<PackedScene>("res://scenes/fx/shield_flash.tscn");

    public static PackedScene DamagePopupScene =>
        _damagePopup ??= GD.Load<PackedScene>("res://scenes/combat/damage_popup.tscn");

    /// <summary>Load the HD-2D effect scenes now. Loaded on first use instead, the acid splash cost
    /// the frame of the first flask hit about 170 ms. <c>CombatScene.StartEncounter</c> calls this
    /// while the board builds. Add each new HD-2D effect scene here.</summary>
    public static void PreloadEncounterEffects()
    {
        _ = AcidSplashScene;
        _ = TreatWoundsScene;
        _ = DeathDustScene;
        _ = FlaskThrowScene;
    }
}
