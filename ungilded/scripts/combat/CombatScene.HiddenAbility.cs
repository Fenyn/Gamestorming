using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2e.RuleEvents.Features;

namespace Ungilded.Combat;

/// <summary>A creature ability that fires without being named (Vicious Bite): the "Abilities" row on
/// the card that shows the creature pulses as the hit lands. The row's text does not change.</summary>
public partial class CombatScene
{
    /// <summary>The knowledge row a hidden ability pulses.</summary>
    private const string AbilitiesRow = "Abilities";

    private readonly HashSet<ICharacter> _hiddenAbilityFired = new();

    /// <summary>Raised with the creature each time its card's Abilities row pulses.</summary>
    public event Action<ICharacter>? HiddenAbilityPulsed;

    /// <summary>Dev use: pulses shown since the scene was made.</summary>
    public int HiddenAbilityPulseCount { get; private set; }

    /// <summary>The engine event is static: subscribe per encounter, release in StopEncounter.</summary>
    private void WatchHiddenAbilities()
    {
        ViciousBiteFeature.OnTriggered -= OnHiddenAbility;
        ViciousBiteFeature.OnTriggered += OnHiddenAbility;
    }

    private void StopWatchingHiddenAbilities()
    {
        ViciousBiteFeature.OnTriggered -= OnHiddenAbility;
        _hiddenAbilityFired.Clear();
    }

    /// <summary>The rules fire before the bite is shown; the pulse waits for the bite's roll on the
    /// board and runs through the attack and the damage.</summary>
    private void OnHiddenAbility(ICharacter owner, ICharacter target, ViciousBiteFeature feature)
    {
        if (_session != null && _session.Team2.Contains(owner)) _hiddenAbilityFired.Add(owner);
    }

    private void PulseHiddenAbility(BattleEvent evt)
    {
        if (evt.Type != BattleEventType.AttackRolled || evt.Source == null || !_hiddenAbilityFired.Remove(evt.Source)) return;
        bool shown = ReferenceEquals(_actorCardUnit, evt.Source) && _actorCard.PulseKnowledgeRow(AbilitiesRow);
        shown |= ReferenceEquals(_targetCardUnit, evt.Source) && _targetCard.PulseKnowledgeRow(AbilitiesRow);
        if (!shown) return;
        HiddenAbilityPulseCount++;
        HiddenAbilityPulsed?.Invoke(evt.Source);
    }
}
