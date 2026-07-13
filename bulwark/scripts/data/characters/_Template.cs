// Copy this file for a new character. Rename the class and add it to Characters.cs registry.
//
// Steps:
//   1. Copy this file to scripts/data/characters/<Name>.cs
//   2. Rename the class from _Template to <Name>
//   3. Fill in all required fields
//   4. Add <Name>.Profile to the Characters.cs registry constructor
//
// For recruitable PCs: set Kind = CharacterKind.RecruitablePC + provide an ArrivalTrigger.
//   The Characters registry will auto-emit a VillagerDefinition for arrival/placement.
//   The character joins the combat roster when BuildSpec is later populated.
//
// For townsfolk: set Kind = CharacterKind.Townsfolk + provide an ArrivalTrigger.
//   They arrive and get placed, but never join the combat party.

namespace Bulwark.Data.Characters;

public static class _Template
{
    public const string CharacterId = "template-id";

    public static readonly CharacterProfile Profile = new()
    {
        Id = CharacterId,
        DefaultName = "Display Name",
        PlayerNamed = false,
        Pronouns = "they/them",
        ClassName = "Fighter",          // Fighter, Cleric, Wizard, Rogue, Alchemist, Ranger, etc.
        AncestryName = "Human",         // Human, Dwarf, Elf, Halfling, Gnome, Goblin, etc.
        Kind = CharacterKind.Townsfolk,  // StartingPC, RecruitablePC, or Townsfolk
        Bio = "One-sentence background.",
        Personality = "Temperament and quirks.",
        RoleDescription = "What they do at the outpost and why they matter.",
        AssociatedBuildingId = null,     // e.g. "command_post", "trading_post", "smithy"
        Arrival = null,                 // null = starting PC; otherwise use ArrivalTrigger factories:
                                        //   ArrivalTrigger.BuildingReached("smithy", minTier: 1)
                                        //   ArrivalTrigger.StoryFlag("flag_id")
                                        //   ArrivalTrigger.DateReached(Season.Summer, day: 5)
                                        //   ArrivalTrigger.All(triggerA, triggerB)
        PortraitId = null,
        SpriteId = null,
        Build = null,                   // TODO: FA build layer (deferred)
    };
}
