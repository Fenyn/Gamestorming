using Godot;
using PF2e.Core;
using PF2e.Data;

namespace Autobattler;

public static class CreatureColors
{
    public static readonly Color Humanoid = new(0.85f, 0.25f, 0.25f);
    public static readonly Color Undead = new(0.6f, 0.2f, 0.8f);
    public static readonly Color Beast = new(0.3f, 0.75f, 0.3f);
    public static readonly Color Dragon = new(0.2f, 0.4f, 0.9f);
    public static readonly Color Fiend = new(0.9f, 0.5f, 0.15f);
    public static readonly Color Elemental = new(0.2f, 0.75f, 0.75f);
    public static readonly Color Aberration = new(0.85f, 0.85f, 0.2f);
    public static readonly Color Construct = new(0.5f, 0.5f, 0.55f);
    public static readonly Color Fey = new(0.7f, 0.4f, 0.85f);
    public static readonly Color Plant = new(0.25f, 0.6f, 0.2f);
    public static readonly Color Ooze = new(0.7f, 0.8f, 0.1f);
    public static readonly Color Default = new(0.5f, 0.5f, 0.5f);

    public static readonly Color PlayerOutline = new(0.3f, 0.9f, 0.3f);
    public static readonly Color EnemyOutline = new(0.9f, 0.3f, 0.3f);

    public static Color GetCreatureColor(EnemyDefinition def)
    {
        var traits = def.CreatureTraits;
        if (traits == null) return Default;

        if (traits.HasTraitById("dragon")) return Dragon;
        if (traits.HasTraitById("fiend")) return Fiend;
        if (traits.HasTraitById("undead")) return Undead;
        if (traits.HasTraitById("elemental")) return Elemental;
        if (traits.HasTraitById("aberration")) return Aberration;
        if (traits.HasTraitById("construct")) return Construct;
        if (traits.HasTraitById("fey")) return Fey;
        if (traits.HasTraitById("ooze")) return Ooze;
        if (traits.HasTraitById("plant")) return Plant;
        if (traits.HasTraitById("beast") || traits.HasTraitById("animal")) return Beast;
        if (traits.HasTraitById("humanoid")) return Humanoid;

        return Default;
    }

    public static string GetPrimaryTrait(EnemyDefinition def)
    {
        var traits = def.CreatureTraits;
        if (traits == null) return "Unknown";

        string[] typeTraits = { "dragon", "fiend", "undead", "elemental", "aberration",
            "construct", "fey", "ooze", "plant", "beast", "animal", "humanoid" };

        foreach (var t in typeTraits)
        {
            if (traits.HasTraitById(t))
                return char.ToUpper(t[0]) + t[1..];
        }

        return "Creature";
    }
}
