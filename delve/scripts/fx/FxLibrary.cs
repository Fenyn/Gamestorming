using Godot;

namespace Delve.Fx;

/// <summary>Single place that loads the one-shot effect and popup blockouts. Each scene loads on
/// first use, so a headless tool that never spawns an effect never touches the disk for one.</summary>
public static class FxLibrary
{
    private static PackedScene? _hitSpark;
    private static PackedScene? _healMotes;
    private static PackedScene? _shieldFlash;
    private static PackedScene? _deathPoof;
    private static PackedScene? _damagePopup;

    public static PackedScene HitSparkScene =>
        _hitSpark ??= GD.Load<PackedScene>("res://scenes/fx/hit_spark.tscn");

    public static PackedScene HealMotesScene =>
        _healMotes ??= GD.Load<PackedScene>("res://scenes/fx/heal_motes.tscn");

    public static PackedScene ShieldFlashScene =>
        _shieldFlash ??= GD.Load<PackedScene>("res://scenes/fx/shield_flash.tscn");

    public static PackedScene DeathPoofScene =>
        _deathPoof ??= GD.Load<PackedScene>("res://scenes/fx/death_poof.tscn");

    public static PackedScene DamagePopupScene =>
        _damagePopup ??= GD.Load<PackedScene>("res://scenes/combat/damage_popup.tscn");
}
