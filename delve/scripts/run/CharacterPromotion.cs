using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using Delve.Presets;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Run;

/// <summary>Run-member advancement. XP queues levels; only an explicit sheet command applies them.</summary>
public sealed class CharacterPromotion
{
    private static readonly ConditionalWeakTable<PF2eCharacter, CharacterPromotion> States = new();
    private readonly List<int> _savedChoices = new();
    private readonly List<Selection> _selections = new();
    public sealed record Selection(int EarnedAt, int LearnedAt, string FeatId);

    private CharacterPromotion(PF2eCharacter character)
    {
        EarnedLevel = character.Stats.Level;
        PrefabId = PromotionFeats.PrefabId(character.Id);
    }

    public int EarnedLevel { get; private set; }
    public string PrefabId { get; }
    public int Revision { get; private set; }
    public IReadOnlyList<int> SavedChoices => _savedChoices;
    public IReadOnlyList<Selection> Selections => _selections;

    public static CharacterPromotion For(PF2eCharacter character) => States.GetValue(character, c => new(c));
    public static bool IsManaged(PF2eCharacter character) => States.TryGetValue(character, out _);
    public int PendingLevels(PF2eCharacter character) => Math.Max(0, EarnedLevel - character.Stats.Level);
    public int ChoiceLevel(PF2eCharacter character) => PendingLevels(character) > 0
        ? character.Stats.Level + 1 : character.Stats.Level;
    public bool HasChoice(PF2eCharacter character) => PendingLevels(character) > 0 || _savedChoices.Count > 0;

    public static void Earn(PF2eCharacter character, int level)
    {
        var state = For(character);
        if (level <= state.EarnedLevel) return;
        state.EarnedLevel = level;
        state.Revision++;
    }

    public static string Status(PF2eCharacter character)
    {
        if (!States.TryGetValue(character, out var state)) return "";
        int pending = state.PendingLevels(character);
        if (pending > 0) return $"Promotion available ({pending})";
        return state._savedChoices.Count > 0 ? $"{state._savedChoices.Count} unspent feat choice(s)" : "";
    }

    public static bool HasPending(Party party) => party.Living().Any(c => For(c).PendingLevels(c) > 0);

    /// <summary>Reject stale callbacks, duplicates and choices from other prefabs before changing anything.</summary>
    public bool Confirm(PF2eCharacter character, string featId, int expectedRevision, out string error)
    {
        error = "";
        if (!ReferenceEquals(For(character), this) || Revision != expectedRevision || !HasChoice(character))
        { error = "This promotion has changed. Select a feat again."; return false; }
        if (character.Health.IsDead)
        { error = "A dead character cannot be promoted."; return false; }
        var feat = PromotionFeats.For(character).FirstOrDefault(f => f.Id == featId);
        int target = ChoiceLevel(character);
        if (feat == null || PromotionFeats.LockReason(character, feat, target) is { })
        { error = "This feat is not available for this promotion."; return false; }

        // Construct first, so a failed factory cannot spend a level or a choice.
        var feature = feat.Build();
        bool advance = PendingLevels(character) > 0;
        int earnedAt = advance ? target : _savedChoices[0];
        if (advance) PresetCharacters.LevelUpInPlace(character, target, useScriptedFeats: false);
        character.Features.AddChosenFeat(new LeveledFeature { Level = target, Feature = feature });
        character.Features.ResolveAndGrantFeatures();
        if (!advance) _savedChoices.RemoveAt(0);
        _selections.Add(new(earnedAt, target, feat.Id));
        Revision++;
        return true;
    }

    /// <summary>Incomplete content never consumes an earned choice or traps a character below the next tier.</summary>
    public bool SaveChoiceAndPromote(PF2eCharacter character, int expectedRevision, out string error)
    {
        error = "";
        if (!ReferenceEquals(For(character), this) || Revision != expectedRevision || PendingLevels(character) == 0
            || character.Health.IsDead)
        { error = "This promotion is no longer available."; return false; }
        int target = ChoiceLevel(character);
        if (PromotionFeats.For(character).Any(f => PromotionFeats.LockReason(character, f, target) == null))
        { error = "Choose an available feat to complete this promotion."; return false; }
        PresetCharacters.LevelUpInPlace(character, target, useScriptedFeats: false);
        _savedChoices.Add(target);
        Revision++;
        return true;
    }
}
