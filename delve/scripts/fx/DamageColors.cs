using Godot;
using PF2e.Data;

namespace Delve.Fx;

/// <summary>Single per-damage-type colour table for combat feedback. The damage popup and the hit
/// spark both read it, so a fire hit tints its number and its shards the same way.</summary>
public static class DamageColors
{
    /// <summary>Colour for a damage type, or null when the type has no flavour colour. A null result
    /// tells the caller to use its own neutral default.</summary>
    public static Color? For(DamageType? damageType) => damageType switch
    {
        DamageType.Fire => new Color(1f, 0.4f, 0.1f),
        DamageType.Cold => new Color(0.3f, 0.7f, 1f),
        DamageType.Electricity => new Color(1f, 1f, 0.3f),
        DamageType.Acid => new Color(0.4f, 1f, 0.2f),
        DamageType.Poison => new Color(0.6f, 0.2f, 0.8f),
        DamageType.Mental => new Color(0.8f, 0.3f, 1f),
        _ => null,
    };
}
