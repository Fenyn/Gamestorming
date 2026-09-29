using System.Linq;
using System.Threading.Tasks;
using Delve.Data;
using Godot;

namespace Delve.Dungeon;

/// <summary>The two set-piece beats of a floor: the guardian's reveal and the walk down the stairs.
/// Both run on the travel tween, so a click or Enter skips them like a crossing.</summary>
public partial class DungeonDirector
{
    /// <summary>How long the camera holds on the ward engine before the guardian fight starts.</summary>
    [Export] public double GuardianRevealSeconds { get; set; } = 0.9;

    /// <summary>The shorter hold before a Lair fight.</summary>
    [Export] public double LairRevealSeconds { get; set; } = 0.45;

    /// <summary>How far the party sinks down the stairs, and how long it takes.</summary>
    [Export] public float StairsDepth { get; set; } = 1.5f;

    [Export] public double StairsSinkSeconds { get; set; } = 0.8;

    /// <summary>Gap between heroes lined up at the stairs, and the delay between their descents.</summary>
    [Export] public float StairsSpacing { get; set; } = 0.5f;

    [Export] public double StairsStagger { get; set; } = 0.15;

    /// <summary>XCOM 2's pod reveal: the camera settles on the room's focus, the card names the
    /// enemies waiting there, then the fight begins.</summary>
    private async Task RevealRoster(int epoch, double seconds, Vector3? focus)
    {
        Phase = DungeonPhase.Transition;
        RefreshHud();
        var roster = _encounters[Current.Id].Enemies
            .GroupBy(e => e.Unit.CreatureStats?.SourceDefinition?.CreatureName ?? e.Unit.Name)
            .Select(g => g.Key + (g.Count() > 1 ? $" ×{g.Count()}" : ""));
        _hud.ShowRoomCard(Words.Name(Current.Purpose), string.Join("  ·  ", roster));
        _camera.FocusOn(focus ?? new Vector3(CurrentView.Width / 2f, 0, CurrentView.Width / 2f), (float)seconds / 2, false);
        _travelTween = CreateTween();
        _travelTween.TweenInterval(seconds);
        while (epoch == _epoch && IsInsideTree() && GodotObject.IsInstanceValid(_travelTween) && _travelTween.IsRunning())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (epoch != _epoch || !IsInsideTree()) return;
        StartCombat(_encounters[Current.Id]);
    }

    /// <summary>The party walks to the stairs and sinks out of sight before the floor ends.</summary>
    private async Task WalkDownStairs(int epoch)
    {
        var stairs = SignatureProp(Words.ExitProp);
        if (stairs is { } foot && _tokens.Count > 0)
        {
            _travelTween = CreateTween().SetParallel(true);
            for (int i = 0; i < _tokens.Count; i++)
            {
                // Single file down the stairs: each hero stops a step apart and sinks a beat later.
                var token = _tokens[i];
                var step = foot + new Vector3(i * StairsSpacing, 0, 0);
                double walk = token.Position.DistanceTo(step) * TravelSecondsPerTile + i * StairsStagger;
                var heading = new Vector2(step.X - token.Position.X, step.Z - token.Position.Z);
                if (heading.LengthSquared() > 0.01f) token.Facing = heading.Normalized();
                token.SetMoving(true);
                _travelTween.TweenProperty(token, "position", step with { Y = token.Position.Y }, walk);
                _travelTween.TweenProperty(token, "position:y", token.Position.Y - StairsDepth, StairsSinkSeconds).SetDelay(walk);
            }
            while (epoch == _epoch && IsInsideTree() && GodotObject.IsInstanceValid(_travelTween) && _travelTween.IsRunning())
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            if (epoch != _epoch || !IsInsideTree()) return;
            foreach (var token in _tokens) token.SetMoving(false);
        }
        LeaveFloor();
    }

    /// <summary>Room-space top-centre of the current room's first prop of a kind, if it has one.</summary>
    private Vector3? SignatureProp(string kind)
        => CurrentView.Generated.Props.Where(p => p.Kind == kind).Select(p => (Vector3?)new Vector3(p.X, 0, p.Y)).FirstOrDefault();
}
