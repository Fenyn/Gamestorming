using System.Collections.Generic;

namespace Delve.Flow;

/// <summary>
/// Reading summaries of the installed feat rules. Keep eligibility and exceptions here;
/// the complete pack wording remains on Full rules. Labels describe the same roles on every card.
/// </summary>
internal static class SheetFeatureSummaries
{
    internal static IReadOnlyList<SheetMetaRow>? Find(string slug)
        => Entries.TryGetValue(slug, out var rows) ? rows : null;

    private static SheetMetaRow Row(string label, string text) => new(label, text);

    private static readonly Dictionary<string, SheetMetaRow[]> Entries = new()
    {
        ["double-slice"] = new[]
        {
            Row("Requires", "Two melee weapons, one in each hand."),
            Row("Effect", "Strike once per weapon at the same target and current multiple attack penalty. Second Strike: extra -2 unless agile."),
            Row("Both hit", "Combine damage and both weapons' effects. Apply resistances and weaknesses once. Add precision damage once, to the attack you choose."),
            Row("Limits", "Counts as two attacks for later attack penalties."),
        },
        ["sneak-attack"] = new[]
        {
            Row("Requires", "An off-guard target."),
            Row("Effect", "Add 1d6 precision damage to a qualifying Strike."),
            Row("Weapons", "Agile or finesse melee weapons or unarmed attacks; any ranged weapon or ranged unarmed attack. Thrown melee weapons must be agile or finesse."),
            Row("Scaling", "Add another damage die at levels 5, 11, and 17."),
        },
        ["surprise-attack"] = new[]
        {
            Row("Requires", "Roll Deception or Stealth for initiative."),
            Row("Effect", "During round 1, creatures that haven't acted are off-guard to you."),
        },
        ["reactive-shield"] = new[]
        {
            Row("Requires", "Wield a shield."),
            Row("Trigger", "An enemy hits you with a melee Strike."),
            Row("Effect", "Raise your shield. Its AC bonus applies to the triggering attack and can turn the hit into a miss."),
        },
        ["shield-block"] = new[]
        {
            Row("Requires", "Your shield is raised."),
            Row("Trigger", "An attack would deal physical damage to you."),
            Row("Effect", "Reduce the damage by your shield's Hardness. You and the shield each take the remaining damage."),
            Row("Limits", "The damage can break or destroy the shield."),
        },
        ["reactive-strike"] = new[]
        {
            Row("Trigger", "A creature in reach uses a manipulate or move action, makes a ranged attack, or leaves a square during movement."),
            Row("Effect", "Make a melee Strike against that creature. A critical hit disrupts a triggering manipulate action."),
            Row("Limits", "Neither applies nor increases your multiple attack penalty."),
        },
        ["battle-medicine"] = new[]
        {
            Row("Requires", "Hold or wear a healer's toolkit."),
            Row("Check", "Medicine against a Treat Wounds DC. Higher DCs require the corresponding proficiency."),
            Row("Effect", "Restore HP for the check's result. Does not remove wounded."),
            Row("Limits", "The target is immune to your Battle Medicine for 1 day. Treat Wounds remains separate."),
        },
        ["medic-dedication"] = new[]
        {
            Row("Grants", "Expert proficiency in Medicine."),
            Row("Effect", "Successful Battle Medicine or Treat Wounds restores extra HP: +5 at DC 20, +10 at DC 30, +15 at DC 40."),
            Row("Limits", "Once per day, use Battle Medicine despite a target's Battle Medicine immunity. Once per hour if you're a master in Medicine."),
        },
        ["bastion-dedication"] = new[] { Row("Grants", "Reactive Shield: raise your shield in response to a melee hit.") },
        ["dual-weapon-warrior-dedication"] = new[] { Row("Grants", "Double Slice: attack the same target with both melee weapons.") },
        ["marshal-dedication"] = new[]
        {
            Row("Grants", "Trained Diplomacy or Intimidation; expert if already trained in your chosen skill."),
            Row("Effect", "You and allies in your 15-foot aura gain +1 status to saves against fear."),
            Row("Traits", "The aura has the emotion, mental, and visual traits."),
        },
        ["inspiring-marshal-stance"] = new[]
        {
            Row("Check", "Diplomacy, usually against an easy DC for your level; circumstances can change the DC."),
            Row("Success", "Your marshal's aura grants you and allies +1 status to attack rolls and saves against mental effects."),
            Row("Failure", "You don't enter the stance. On a critical failure, you also can't try again for 1 minute."),
        },
    };
}
