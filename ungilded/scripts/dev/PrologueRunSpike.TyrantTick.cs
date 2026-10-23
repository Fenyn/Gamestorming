using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Data;
using Ungilded.Combat;
using Ungilded.Content;
using DialogueLine = Ungilded.Story.DialogueLine;

namespace Ungilded.Dev;

/// <summary>
/// Encounter 4 retry: the Sewer Tyrant dies to a persistent acid tick at the end of its own turn.
/// The run does not reach that on its own, so at the Tyrant's first turn start the spike drops it
/// to <see cref="TyrantTickHp"/> (under a quarter, which also fires both threshold sequences) and
/// gives it 1 persistent acid, which its acid weakness lifts past the HP left. The check wants the
/// tick's DamageDealt (acid, cause Persistent), then the Tyrant's CreatureDied right after it with
/// its HP bar at 0 once the death has played, then EncounterEnded, then the first victory line.
/// </summary>
public partial class PrologueRunSpike
{
    /// <summary>The Tyrant's HP when the tick is set up: at most a quarter of its 35.</summary>
    private const int TyrantTickHp = 7;

    private ICharacter? _tyrant;
    private UnitVisual3D? _tyrantVisual;
    private bool _tyrantTickForced;
    private readonly List<string> _tyrantTimeline = new();

    private void WatchTyrantTick()
    {
        _runner.Hooks.OnTurnStarted(ForceTyrantTick);
        _runner.Scene!.Session!.EventPresented += NoteTyrantEvent;
        _director.Dialogue.LineStarted += NoteVictoryLine;
    }

    private Task ForceTyrantTick(ICharacter unit)
    {
        if (_tyrantTickForced || unit.CreatureStats?.CreatureId != PrologueBestiary.SewerTyrantId
            || unit.Health?.IsAlive != true) return Task.CompletedTask;
        _tyrantTickForced = true;
        _tyrant = unit;
        _tyrantVisual = _runner.Scene!.UnitVisual(unit);
        if (unit.Health.CurrentHP > TyrantTickHp) unit.Health.SetCurrentHP(TyrantTickHp);
        unit.Conditions.ApplyPersistentDamage(new DiceFormula(0, 0, 1), DamageType.Acid, _runner.Friend);
        GD.Print($"[PrologueRun] E4 Tyrant tick set up: HP {unit.Health.CurrentHP}, 1 persistent acid, round {_runner.Scene.Session?.RoundNumber}");
        return Task.CompletedTask;
    }

    private void NoteTyrantEvent(BattleEvent evt)
    {
        if (_tyrant == null) return;
        if (evt.Type == BattleEventType.DamageDealt && ReferenceEquals(evt.Target, _tyrant))
            _tyrantTimeline.Add($"DamageDealt {evt.DamageType} {evt.Damage?.Cause} HP {evt.Damage?.HpBefore}->{evt.Damage?.HpAfter}");
        else if (evt.Type == BattleEventType.CreatureDied && ReferenceEquals(evt.Source, _tyrant))
            _tyrantTimeline.Add($"CreatureDied bar {(GodotObject.IsInstanceValid(_tyrantVisual) ? _tyrantVisual!.ShownHp : -1)}");
        else if (evt.Type == BattleEventType.EncounterEnded)
            _tyrantTimeline.Add($"EncounterEnded {evt.Description}");
    }

    private void NoteVictoryLine(DialogueLine line)
    {
        if (_tyrant != null && _runner.VictoryLines?.Lines.FirstOrDefault()?.Text == line.Text)
            _tyrantTimeline.Add("victory line");
    }

    private void CheckTyrantTick()
    {
        GD.Print($"[PrologueRun] E4 Tyrant tick proof: {string.Join(" | ", _tyrantTimeline)}");
        int tick = _tyrantTimeline.FindIndex(e => e.StartsWith($"DamageDealt {DamageType.Acid} {DamageCause.Persistent}"));
        int died = _tyrantTimeline.FindIndex(e => e.StartsWith("CreatureDied"));
        int over = _tyrantTimeline.FindIndex(e => e.StartsWith("EncounterEnded"));
        int victory = _tyrantTimeline.IndexOf("victory line");
        Check("E4: the Tyrant tick was set up at its turn start", _tyrantTickForced);
        Check("E4: the acid tick's DamageDealt (cause Persistent) came first, the Tyrant's CreatureDied right after it",
            tick >= 0 && died == tick + 1);
        Check($"E4: one CreatureDied for the Tyrant ({_tyrantTimeline.Count(e => e.StartsWith("CreatureDied"))})",
            _tyrantTimeline.Count(e => e.StartsWith("CreatureDied")) == 1);
        Check("E4: the Tyrant's HP bar showed 0 once its death had played", died >= 0 && _tyrantTimeline[died] == "CreatureDied bar 0");
        Check("E4: EncounterEnded, then the victory dialogue, after the death", died >= 0 && died < over && over < victory);
    }
}
