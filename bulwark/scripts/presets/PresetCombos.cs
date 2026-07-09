using System.Collections.Generic;
using Bulwark.Data;
using PF2e.Data;
using PF2e.RuleEvents;

namespace Bulwark.Presets;

/// <summary>
/// Authored variant-combo content for the M0 spike, plus the FeatureDatabase registration that
/// lets <c>LevelUpApplicator</c> resolve scripted feats by id.
/// </summary>
public static class PresetCombos
{
    /// <summary>
    /// Fighter "Sentinel" = Sentinel subclass overlay + Bastion Dedication taken as the
    /// level-2 Free Archetype feat.
    /// </summary>
    public static VariantComboDefinition FighterSentinel { get; } = new()
    {
        Id = "fighter-sentinel",
        DisplayName = "Fighter (Sentinel)",
        Description =
            "A shield-focused Fighter: the Sentinel subclass overlay plus the Bastion "
            + "archetype dedication granted as the level-2 free-archetype feat.",
        Subclass = PresetClasses.BuildSentinelSubclass(),
        ScriptedChoices = new Dictionary<int, LevelUpChoices>
        {
            [2] = new LevelUpChoices
            {
                Level = 2,
                FreeArchetypeFeatId = "bastion-dedication",
                AutoAssigned = false,
            },
        },
    };

    /// <summary>
    /// Ensure a FeatureDatabase.Instance exists that can resolve the preset feats referenced by
    /// scripted level-up choices. Idempotent — safe to call before every build.
    /// </summary>
    public static void EnsureFeaturesRegistered()
    {
        if (FeatureDatabase.Instance != null)
            return;

        FeatureDatabase.Instance = new FeatureDatabase
        {
            Features = new List<CharacterFeature>
            {
                PresetClasses.BuildBastionDedication(),
                PresetClasses.BuildSentinelShieldFocus(),
            },
        };
    }
}
