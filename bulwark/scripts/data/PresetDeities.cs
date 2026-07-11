using System.Collections.Generic;
using PF2e.Data;
using PF2e.Import;
using PF2e.Spellcasting;

namespace Bulwark.Data;

/// <summary>
/// Code-authored campaign deities. Aveline is a faithful port of the Unity original's
/// ScriptableObject asset (Tactics/Assets/ScriptableObjects/Deities/Aveline.asset) — the engine's
/// DeityDefinition data type was already ported 1:1, so only the asset content lives here.
///
/// Consumed via CharacterBuildChoices.Deity: HealingFontFeature reads FontSpellIdentity to
/// configure the DivineFontPool, favored-weapon proficiency getters and WarpriestThirdDoctrine
/// read GetFavoredWeapon(), and RuntimeCharacterBuilder-style skill grants read DivineSkill.
///
/// GrantedSpells joins the Medic's preparable list via Spellcasting.GetAvailableSpellsForRank
/// (Remaster Cleric "Deity" class feature: granted spells are added to your spell list even
/// outside your tradition) — the grants reference the SAME canonical PresetSpells instances the
/// SpellDatabase registers, since prep validation compares by reference. Domain initial/advanced
/// focus spells are not authored (Domain Initiate is not part of the locked combos); the domains
/// carry ids/names only.
/// </summary>
public static class PresetDeities
{
    private static DeityDefinition? _aveline;

    /// <summary>
    /// Aveline, the Lady of Dawn — heal font, holy sanctification, favored weapon scimitar,
    /// divine skill Medicine, domains fire/healing/sun/truth. Requires GameDataLoader (the
    /// favored-weapon WeaponDefinition is resolved from the equipment packs); the instance is
    /// cached so every consumer shares the SAME WeaponDefinition reference — favored-weapon
    /// checks (WarpriestThirdDoctrine, WeaponAttackCalculator) compare by reference.
    /// </summary>
    public static DeityDefinition Aveline
    {
        get
        {
            _aveline ??= BuildAveline();
            return _aveline;
        }
    }

    private static DeityDefinition BuildAveline() => new()
    {
        DefinitionId = "aveline",
        DisplayName = "Aveline, the Lady of Dawn",

        DivineFontType = DivineFontType.Heal,
        // Same instance as the preset Heal spell's SpellDefinition.Identity (reference-compared).
        FontSpellIdentity = PresetSpells.HealIdentity,

        AllowedSanctification = SanctificationType.Holy,

        // Scimitar (martial sword) — resolved from the pack so the equipped weapon and the
        // favored weapon are the same definition instance (see BuildMedic).
        FavoredWeapon = GameDataLoader.FindEquipment("scimitar")?.ToWeaponDefinition(),

        DivineSkill = Skill.Medicine,
        KeyAttributes = new[] { AbilityScore.Constitution, AbilityScore.Wisdom },

        Domains = new List<DomainDefinition>
        {
            new() { DefinitionId = "fire", DisplayName = "Fire" },
            new() { DefinitionId = "healing", DisplayName = "Healing" },
            new() { DefinitionId = "sun", DisplayName = "Sun" },
            new() { DefinitionId = "truth", DisplayName = "Truth" },
        },

        GrantedSpells = new List<LeveledSpellGrant>
        {
            new() { SpellRank = 1, Spell = PresetSpells.Get(PresetSpells.BreatheFireId) },
            new() { SpellRank = 3, Spell = PresetSpells.Get(PresetSpells.FireballId) },
        },

        Description =
            "Aveline is the Lady of Dawn, she who kindled the first light when the world lay dark "
            + "and formless. In the age before the Crown, when men huddled in the long shadow and "
            + "the dead walked freely, Aveline set her hand against the horizon and the sun came, "
            + "and with it warmth and the slow green mending of all wounded things. She is patron "
            + "of healers and of soldiers who fight without cruelty, of those who carry lanterns "
            + "into dark places and who offer the open hand before the closed fist. Her worship ran "
            + "through the Crown like a golden thread in the years of Arthur’s reign, and her "
            + "chapels rose tall in every city and hamlet along the borderlands. Now many of those "
            + "chapels stand half-ruined, their congregations scattered by war and abandonment, "
            + "tended by the faithful few who will not leave. Sister Cael keeps a shrine to Aveline "
            + "in the outpost chapel, and Maren carries her light into battle.",
        Edicts =
            "Destroy the undead, bring light to dark places, offer mercy to those who surrender",
        Anathema =
            "Create undead, abandon the wounded, extinguish a source of light in the darkness",
    };
}
