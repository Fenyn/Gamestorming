using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.Core;

namespace Delve.Run;

public sealed record RestAssignment(PF2eCharacter Actor, ShortRestKind Kind, PF2eCharacter? Target = null);

public static partial class ShortRest
{
    /// <summary>Validate the entire simultaneous schedule before spending resources or rolling.</summary>
    public static string? Validate(Party party, IReadOnlyList<RestAssignment> assignments)
    {
        var living = party.Living();
        if (assignments.Count != living.Count) return "Choose one activity for every living character.";
        var actors = new HashSet<PF2eCharacter>();
        var patients = new HashSet<PF2eCharacter>();
        var shields = new HashSet<PF2eCharacter>();
        foreach (var choice in assignments)
        {
            if (!living.Contains(choice.Actor) || !actors.Add(choice.Actor))
                return "Each character can perform only one activity in these ten minutes.";
            if (!Enum.IsDefined(choice.Kind)) return "Unknown rest activity.";
            if (choice.Kind == ShortRestKind.Refocus && choice.Actor.Spellcasting?.MaxFocusPoints is not > 0)
                return $"{choice.Actor.Name} has no focus pool.";
            if (choice.Kind is ShortRestKind.TreatWounds or ShortRestKind.RepairShield)
            {
                if (choice.Target == null || !living.Contains(choice.Target)) return "Choose a living party member as the target.";
                if (choice.Kind == ShortRestKind.TreatWounds && !patients.Add(choice.Target))
                    return $"{choice.Target.Name} can receive only one treatment in this window.";
                if (choice.Kind == ShortRestKind.RepairShield)
                {
                    if (choice.Target.Equipment?.Shield?.EquippedShield == null)
                        return $"{choice.Target.Name} has no shield to repair.";
                    if (!shields.Add(choice.Target)) return $"Assign only one character to repair {choice.Target.Name}'s shield.";
                }
            }
        }
        return null;
    }

    public static ShortRestResult PerformSchedule(Party party, DayClock clock,
        IReadOnlyList<RestAssignment> assignments, RecoveryRules rules, Wardstone? wardstone = null,
        int? dcOverride = null)
    {
        string? error = Validate(party, assignments);
        if (error == null && wardstone != null && !wardstone.CanAffordShortRest)
            error = "There is too little ward left for another rest.";
        if (error != null) return new() { Kind = ShortRestKind.Rest, Performed = false, Reason = error };

        int block = clock.ShortRestsToday;
        clock.SpendShortRest();
        wardstone?.BurnShortRest();
        var lines = new List<string>();
        int hpChange = 0;
        // Party order makes results independent of the order in which UI rows were edited.
        foreach (var actor in party.Living())
        {
            Delve.Rules.WayfarerFeature.State(actor).ChaliceDrained = false;
            var choice = assignments.Single(a => ReferenceEquals(a.Actor, actor));
            switch (choice.Kind)
            {
                case ShortRestKind.TreatWounds:
                    var rng = new Random(RunRng.StableSeed(clock.Day, block, "shortrest:" + actor.Id));
                    var treatment = TreatWounds(party, choice.Target, rules, dcOverride, rng, actor);
                    lines.AddRange(treatment.Lines);
                    hpChange += treatment.HpChange;
                    break;
                case ShortRestKind.Refocus:
                    Delve.Rules.WayfarerFeature.State(actor).Cursebound = Math.Max(0, Delve.Rules.WayfarerFeature.State(actor).Cursebound - 1);
                    int restored = actor.Spellcasting!.RestoreFocusPoints(Delve.Rules.WayfarerFeature.Find(actor)?.Class == "Psychic" ? 2 : rules.RefocusPoints);
                    lines.Add($"{actor.Name}: focus {actor.Spellcasting.CurrentFocusPoints}/{actor.Spellcasting.MaxFocusPoints} (+{restored}).");
                    break;
                case ShortRestKind.RepairShield:
                    var shield = choice.Target!.Equipment!.Shield;
                    shield.SetCurrentShieldHP(shield.MaxShieldHP);
                    lines.Add($"{actor.Name} repairs {choice.Target.Name}'s shield: {shield.CurrentShieldHP}/{shield.MaxShieldHP}.");
                    break;
                case ShortRestKind.Rest:
                    lines.Add($"{actor.Name} rests quietly.");
                    break;
            }
        }
        return new() { Kind = ShortRestKind.Rest, Performed = true, Lines = lines, HpChange = hpChange };
    }
}
