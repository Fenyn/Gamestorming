using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;

namespace Delve.Presets;

/// <summary>Playable feat inventory for the current prefabs. Never fabricates an unimplemented feature.</summary>
public static class PromotionFeats
{
    public sealed record Option(string Id, int Level, string Theme, string Source,
        Func<CharacterFeature> Build, string? Prerequisite = null);

    public static string PrefabId(string id) => id switch
    {
        "player" => "aldric-vanguard", "elara" => "elara-twinblade",
        "tharr" => "tharr-war-chaplain", "fenwick" => "fenwick-field-arcanist", _ => id + "-default",
    };

    public static IReadOnlyList<Option> For(PF2eCharacter character)
    {
        var options = new List<Option>();
        if (RosterFeats.Tracks.TryGetValue(character.Id, out var track))
            foreach (var pick in track)
            {
                string id = pick.Id;
                options.Add(new(id, RosterFeats.MinimumLevel(id), Theme(character.Id, id),
                    "Class feat", () => RosterFeats.Build(id)));
            }
        // Each archetype line starts with its dedication, the free archetype feat every preset
        // takes at level 2; it heads the column so the later feat's prerequisite is on the ladder.
        switch (character.Id)
        {
            case "player":
                options.Add(new("bastion-dedication", 2, "Hold", "Bastion", PresetClasses.BuildBastionDedication));
                options.Add(new("disarming-block", 4, "Hold", "Bastion", PresetClasses.BuildDisarmingBlock, "bastion-dedication"));
                break;
            case "tharr":
                options.Add(new("marshal-dedication", 2, "Command", "Marshal", PresetClasses.BuildMarshalDedication));
                options.Add(new("inspiring-marshal-stance", 4, "Command", "Marshal", PresetClasses.BuildInspiringMarshalStance, "marshal-dedication"));
                break;
            case "fenwick":
                options.Add(new("medic-dedication", 2, "Fieldcraft", "Medic", PresetClasses.BuildMedicDedication));
                options.Add(new("treat-condition", 4, "Fieldcraft", "Medic", PresetClasses.BuildTreatCondition, "medic-dedication"));
                break;
        }
        return options.DistinctBy(f => f.Id).OrderBy(f => f.Level).ThenBy(f => f.Theme).ThenBy(f => f.Id).ToArray();
    }

    private static string Theme(string characterId, string featId) => characterId switch
    {
        "player" => featId.Contains("shield") ? "Hold" : "Advance",
        "elara" => featId is "mobility" ? "Pursuit" : "Ambush",
        "tharr" => "Restoration",
        "fenwick" => "Artillery",
        _ => "Class feats",
    };

    public static bool Learned(PF2eCharacter character, string id) =>
        character.Features.ChosenFeats.Concat(character.Features.FreeArchetypeFeats)
            .Concat(character.Stats.CharacterClass.ClassFeatures)
            .Any(f => f.Level <= character.Stats.Level && f.Feature.FeatureId.Replace('_', '-') == id);

    public static string? LockReason(PF2eCharacter character, Option feat, int targetLevel)
    {
        if (Learned(character, feat.Id)) return "Learned";
        if (feat.Level > targetLevel) return $"Requires level {feat.Level}";
        if (feat.Prerequisite is { } prerequisite && !Learned(character, prerequisite))
            return $"Requires {RosterFeats.Name(prerequisite)}";
        if (feat.Id == "disarming-block" && character.Skills.GetProficiency(Skill.Athletics) < ProficiencyLevel.Trained)
            return "Requires trained Athletics";
        if (feat.Id == "inspiring-marshal-stance" && character.Skills.GetProficiency(Skill.Diplomacy) < ProficiencyLevel.Trained)
            return "Requires trained Diplomacy";
        return null;
    }
}
