using System.Collections.Generic;
using System.Linq;
using PF2e.RuleEvents.Reactions;
using PF2e.Core;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>A compact snapshot of a combatant, without target-dependent attack modifiers. Feeds the party chip hover.</summary>
public sealed record ActiveCharacterView(string Id, string Name, int Hp, int MaxHp,
    string HpText, string Gear, string Bonuses, bool IsHero)
{
    public string Status { get; init; } = "";
    public string StatusTip { get; init; } = "";
    public ReactionMark Reaction { get; init; }

    /// <summary>Every line as plain sentences, for a hover.</summary>
    public string Tooltip => string.Join("\n", new[] { Name, $"HP {HpText} · {Bonuses}", Gear, Status, StatusTip }
        .Where(line => line.Length > 0));

    internal static ActiveCharacterView? From(ICharacter? actor)
    {
        if (actor == null) return null;
        var inspect = UnitInspectFactory.BuildInspectView(actor);
        bool hero = actor.CreatureStats == null;
        var gear = new List<string>();
        var bonuses = new List<string> { inspect.AcText };
        if (hero)
        {
            var equipment = actor.Equipment;
            var weapon = WeaponAttackCalculator.ResolveWeapon(actor);
            gear.Add($"{weapon.WeaponDef.ItemName} {WeaponAttackCalculator.CalculateAttackBonus(actor, weapon):+0;-0;0}");
            var offhand = equipment?.OffHandWeapon;
            if (offhand != null && offhand != weapon)
                gear.Add($"{offhand.WeaponDef.ItemName} {WeaponAttackCalculator.CalculateAttackBonus(actor, offhand):+0;-0;0}");
            gear.Add(equipment?.WornArmorDef?.ItemName ?? "Unarmored");
            var shield = equipment?.Shield?.EquippedShield;
            if (shield != null)
                gear.Add($"{shield.ItemName} ({(equipment!.IsShieldRaised ? "raised" : "lowered")})");
            if (actor.Spellcasting != null)
                bonuses.Add($"Spell {StatsCalculator.CalculateSpellAttack(actor):+0;-0;0} / DC {StatsCalculator.CalculateSpellDC(actor)}");
        }
        var status = hero ? Delve.Rules.ClassStatus.Active(actor).ToList() : new List<string>();
        if (hero && StanceRules.IsInStance(actor, "inspiring-marshal-stance")) status.Add("Marshal Stance");
        var reactions = ReactionNames(actor);
        bool ready = ReactionReady(actor);
        if (reactions.Length > 0)
            status.Add(actor.Conditions?.AreReactionsBlocked() == true ? "Reactions blocked"
                : ready ? "Reaction ready" : "Reaction spent");
        return new(actor.Id, actor.Name, inspect.Hp, inspect.MaxHp, inspect.HpText,
            string.Join(" · ", gear), string.Join(" · ", bonuses), hero)
        {
            Status = string.Join(" · ", status),
            StatusTip = reactions.Length > 0 ? string.Join(", ", reactions) + "\nUse reactions when their trigger and requirements are met." : "",
            Reaction = ReactionOf(actor),
        };
    }

    /// <summary>The reaction features a hero has; creatures report none.</summary>
    private static string[] ReactionNames(ICharacter actor) => actor.CreatureStats != null
        ? System.Array.Empty<string>()
        : actor.Features?.ActiveFeatures
            .Where(f => f is IMovementReaction or IActionReaction or IDamageReaction).Select(f => f.DisplayName).Distinct().ToArray()
          ?? System.Array.Empty<string>();

    private static bool ReactionReady(ICharacter actor)
        => actor.Conditions?.AreReactionsBlocked() != true && actor.Actions?.ReactionAvailable == true;

    /// <summary>The hero's reaction mark: none without a reaction feature, else ready or spent.</summary>
    internal static ReactionMark ReactionOf(ICharacter actor)
        => ReactionNames(actor).Length == 0 ? ReactionMark.None : ReactionReady(actor) ? ReactionMark.Ready : ReactionMark.Spent;
}
