using PF2e.Data;
using Ungilded.Content;

namespace Ungilded.Tutorial.Encounters;

/// <summary>A start past an encounter: the journal and HP that encounter leaves when its script plays it.</summary>
public partial class PrologueEncounterRunner
{
    /// <summary>HP below max the Player ends Encounter 2 on: the scripted bite less the Treat Wounds heal.</summary>
    private const int Encounter2PlayerShortfall = 1;

    /// <summary>HP below max the Friend ends Encounter 3 on: the bite and the bleed less the Treat
    /// Wounds heal. The Player's 1 missing HP heals in full.</summary>
    private const int Encounter3FriendShortfall = 1;

    public void Skip(int index)
    {
        Player ??= PrologueCast.BuildPlayer();
        Friend ??= PrologueCast.BuildFriend();
        foreach (var spawn in PrologueMaps.Encounter(index).Enemies)
            if (PrologueBestiary.Find(spawn.CreatureId) is { } creature)
                Journal.MarkEncountered(creature.CreatureId, creature.CreatureName);
        if (index == 3)
        {
            Player.Health.RestoreToFull();
            Friend.Health.SetCurrentHP(Friend.Health.MaxHP - Encounter3FriendShortfall);
        }
        if (index != 2) return;
        // Encounter 2's two forced Recall Knowledge successes.
        Journal.Reveal(PrologueBestiary.SewerRatId, DegreeOfSuccess.Success, forced: new[] { CreatureKnowledgeField.Strikes });
        Journal.Reveal(PrologueBestiary.SewerRatId, DegreeOfSuccess.Success, forced: new[] { CreatureKnowledgeField.AC });
        Player.Health.SetCurrentHP(Player.Health.MaxHP - Encounter2PlayerShortfall);
    }
}
