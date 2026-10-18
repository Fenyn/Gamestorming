using System;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;

namespace Ungilded.Content;

/// <summary>
/// Heritage resistance to one damage type equal to half the character's level (minimum 1), as
/// Wintertouched Human grants for cold. Written into the character's <see cref="PF2e.CharacterComponents.DefenseProfile"/>
/// so the resistance reads like any other. The value is fixed at grant; re-grant after a level up.
/// </summary>
public sealed class HalfLevelResistanceFeature : CharacterFeature
{
    public DamageType ResistanceType { get; init; }

    public static int ValueAt(int level) => Math.Max(1, level / 2);

    public override void OnGranted(ICharacter character, RuleEventBus bus)
    {
        int level = character.StatProvider?.Level ?? 1;
        character.DefenseProfile?.AddResistance(new DamageAffinity(ResistanceType, ValueAt(level)), this);
    }

    public override void OnRevoked(ICharacter character, RuleEventBus bus)
        => character.DefenseProfile?.RemoveAllFromSource(this);
}
