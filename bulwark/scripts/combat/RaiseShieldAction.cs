using PF2e.Actions;
using PF2e.Core;

namespace Bulwark.Combat;

/// <summary>
/// Raise a Shield (1 action). The engine has no built-in action class for this, so bulwark
/// authors it against <see cref="BaseAction"/>. The shield auto-lowers on the owner's next turn
/// start (handled by <c>ShieldManager.OnTurnStart</c>, provided the manager is subscribed to the
/// TurnManager — <see cref="CombatSession"/> wires that).
/// </summary>
public sealed class RaiseShieldAction : BaseAction
{
    public RaiseShieldAction()
    {
        ActionName = "Raise a Shield";
        ActionCostCount = 1;
        Description = "Raise your shield to gain its circumstance bonus to AC until your next turn.";
    }

    public override bool CanPerform(ICharacter actor, ICharacter? target = null)
    {
        if (actor.Equipment?.CanRaiseShield() != true)
            return false;
        return base.CanPerform(actor, target);
    }

    public override void Execute(ICharacter actor, ICharacter? target = null)
    {
        if (actor.Equipment?.CanRaiseShield() != true)
            return;
        if (!TryConsumeCost(actor))
            return;
        actor.Equipment.RaiseShield(actor);
    }
}
