using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Ungilded.Combat;
using Godot;
using PF2e.Core;
using PF2e.Data;

namespace Ungilded.Dev;

/// <summary>
/// The second fight: the hero, the friend and one rat at 1 HP with persistent acid. The rat's turn
/// ends, the tick kills it, and that ends the fight. Checks that the tick's DamageDealt (cause
/// Persistent) and one CreatureDied play after the rat's TurnEnded and before EncounterEnded, that
/// the dead rat is still the current actor when its death plays, and that no turn starts after it.
/// </summary>
public partial class ReactionKillSpike
{
    /// <summary>Flat acid damage of the tick; more than the rat's 1 HP.</summary>
    private const int TickDamage = 3;

    private ICharacter? _tickRat;
    private readonly List<string> _tickTimeline = new();
    private string _tickActorAtDeath = "";
    private BattleResult _tickResult = BattleResult.InProgress;

    private async Task RunTickKill(CombatSetup previous, EnemyDefinition ratDef)
    {
        _tickRat = CreatureFactory.Create(ratDef, teamId: 2);
        _tickRat.Health.SetCurrentHP(1);
        _tickRat.Conditions.ApplyPersistentDamage(new DiceFormula(0, 0, TickDamage), DamageType.Acid, _hero);
        var setup = previous with { Enemies = new() { (_tickRat, Vec(RatBTile)) } };

        _scene.StartEncounter(setup);
        var session = _scene.Session!;
        session.EncounterFinished += r => _tickResult = r;
        session.EventPresented += evt => NoteTick(session, evt);

        ulong deadline = Time.GetTicksMsec() + (ulong)(TimeoutSeconds * 1000);
        while (_tickResult == BattleResult.InProgress && Time.GetTicksMsec() < deadline)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            if (session.PlayerTurnActive && _scene.Controller is { CanAcceptOrders: true })
                session.RequestEndPlayerTurn();
        }
        GD.Print($"[ReactionKill] tick fight: {string.Join(" | ", _tickTimeline)}");

        string rat = _tickRat.Name;
        int ended = _tickTimeline.IndexOf($"TurnEnded {rat}");
        int tick = _tickTimeline.IndexOf($"DamageDealt {rat} Persistent Acid");
        int died = _tickTimeline.IndexOf($"Died {rat}");
        int over = _tickTimeline.IndexOf("EncounterEnded");
        Check($"tick fight: won ({_tickResult})", _tickResult == BattleResult.Team1Wins);
        Check("tick fight: the rat's TurnEnded, the persistent acid DamageDealt, its death, then EncounterEnded",
            ended >= 0 && ended < tick && tick < died && died < over);
        Check($"tick fight: one CreatureDied ({_tickTimeline.Count(e => e.StartsWith("Died "))})",
            _tickTimeline.Count(e => e.StartsWith("Died ")) == 1);
        Check($"tick fight: the dead rat was the current actor, its turn removed, when its death played ({_tickActorAtDeath})",
            _tickActorAtDeath == $"{rat} removed");
        Check("tick fight: no turn started after the rat's turn ended",
            ended >= 0 && !_tickTimeline.Skip(ended).Any(e => e.StartsWith("TurnStarted ")));
    }

    private void NoteTick(CombatSession session, BattleEvent evt)
    {
        switch (evt.Type)
        {
            case BattleEventType.TurnStarted: _tickTimeline.Add($"TurnStarted {evt.Source?.Name}"); break;
            case BattleEventType.TurnEnded: _tickTimeline.Add($"TurnEnded {evt.Source?.Name}"); break;
            case BattleEventType.DamageDealt:
                _tickTimeline.Add($"DamageDealt {evt.Target?.Name} {evt.Damage?.Cause} {evt.DamageType}");
                break;
            case BattleEventType.CreatureDied:
                _tickTimeline.Add($"Died {evt.Source?.Name}");
                _tickActorAtDeath = $"{session.CurrentActor?.Name}{(session.CurrentTurnRemoved ? " removed" : "")}";
                break;
            case BattleEventType.EncounterEnded: _tickTimeline.Add("EncounterEnded"); break;
        }
    }
}
