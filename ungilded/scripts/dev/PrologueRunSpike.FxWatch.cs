using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using Ungilded.Combat;
using Ungilded.Fx;

namespace Ungilded.Dev;

/// <summary>
/// Watches the HD-2D effects the run spawns (<see cref="AcidSplash"/>, <see cref="TreatWounds"/>,
/// <see cref="DeathDust"/>).
/// Each one is recorded as it becomes ready: the token it stands on, its Fx group, how long its frame
/// ran before the spawn, the longest of the next <see cref="FxFramesWatched"/> frames, and how long it
/// lived. Times are game time (the sum of process deltas), which the effects' tweens and particles
/// also run on: a capture blocks its frame for a few hundred milliseconds, and that time never
/// reaches the delta.
/// </summary>
public partial class PrologueRunSpike
{
    /// <summary>Furthest an effect may stand from its token's feet, in metres.</summary>
    [Export] public float FxFeetTolerance { get; set; } = 0.01f;

    /// <summary>Slack on an effect's own lifetime before it counts as not freed on time, in seconds.</summary>
    [Export] public float FxLifetimeSlack { get; set; } = 0.3f;

    /// <summary>How many frames after each spawn are timed.</summary>
    private const int FxFramesWatched = 3;

    /// <summary>What one effect showed when it became ready. Values are copied, because the node is
    /// freed long before the checks run.</summary>
    private class FxRecord
    {
        public FxRecord(OneShotFx node, int encounter)
        {
            Node = node;
            Encounter = encounter;
            Lifetime = node.Lifetime;
        }

        public OneShotFx Node { get; }
        public int Encounter { get; }
        public float Lifetime { get; }
        public ICharacter? Unit { get; set; }
        public float FeetGap { get; set; } = float.MaxValue;
        public float BarHeight { get; set; }
        public bool InFxGroup { get; set; }

        /// <summary>Milliseconds the spawn's frame had run before the spawn.</summary>
        public ulong BeforeSpawnMs { get; set; }

        /// <summary>Longest of the frames after the spawn, in milliseconds: a first draw that compiles
        /// the effect's shaders shows here.</summary>
        public ulong LongestFrameAfterMs { get; set; }

        public int FramesWatched { get; set; }
        public double SpawnedAt { get; set; }
        public double ExitedAt { get; set; } = -1;

        /// <summary>Game seconds from the spawn until the node left the tree.</summary>
        public double Lived => ExitedAt >= 0 ? ExitedAt - SpawnedAt : -1;

        public bool Freed => !GodotObject.IsInstanceValid(Node) && ExitedAt >= 0;

        public bool LivedItsLifetime(float slack) => Lived >= Lifetime - slack && Lived <= Lifetime + slack;

        public string Timing => $"frame before spawn {BeforeSpawnMs} ms, longest of the next {FxFramesWatched} frames "
            + $"{LongestFrameAfterMs} ms, lived {Lived:0.00} s";
    }

    private readonly List<FxRecord> _framesPending = new();
    private ulong _frameStartMs;

    /// <summary>Game seconds since the watch began: the sum of process deltas.</summary>
    private double _gameClock;

    /// <summary>Every token of the encounter, kept from its Prepare. The scene drops a creature's token
    /// from its map as the killing damage lands, before that damage is presented.</summary>
    private readonly Dictionary<ICharacter, UnitVisual3D> _fxTokens = new();

    private void WatchFx()
    {
        GetTree().NodeAdded += OnFxNodeAdded;
        GetTree().ProcessFrame += NoteFrameStart;
        _runner.Prepared += NoteFxTokens;
    }

    private void StopWatchingFx()
    {
        GetTree().NodeAdded -= OnFxNodeAdded;
        GetTree().ProcessFrame -= NoteFrameStart;
        _runner.Prepared -= NoteFxTokens;
    }

    private void NoteFrameStart()
    {
        ulong now = Time.GetTicksMsec();
        ulong frame = now - _frameStartMs;
        _frameStartMs = now;
        _gameClock += GetProcessDeltaTime();
        foreach (var record in _framesPending)
        {
            record.LongestFrameAfterMs = System.Math.Max(record.LongestFrameAfterMs, frame);
            record.FramesWatched++;
        }
        _framesPending.RemoveAll(r => r.FramesWatched >= FxFramesWatched);
    }

    private void NoteFxTokens(int encounter)
    {
        _fxTokens.Clear();
        if (_runner.Scene?.Session is not { } session) return;
        foreach (var unit in session.Team1.Concat(session.Team2))
            if (_runner.Scene.UnitVisual(unit) is { } token) _fxTokens[unit] = token;
    }

    private void OnFxNodeAdded(Node node)
    {
        if (node is AcidSplash splash) splash.Ready += () => NoteAcidSplash(splash);
        else if (node is TreatWounds wrap) wrap.Ready += () => NoteTreatWounds(wrap);
        else if (node is DeathDust dust) dust.Ready += () => NoteDeathDust(dust);
        if (node.Name == RemovedDeathEffect) _removedDeathEffects++;
    }

    /// <summary>Fill the fields every effect shares, for a node that just became ready.</summary>
    private T Track<T>(T record) where T : FxRecord
    {
        record.SpawnedAt = _gameClock;
        record.BeforeSpawnMs = Time.GetTicksMsec() - _frameStartMs;
        record.InFxGroup = record.Node.IsInGroup(OneShotFx.FxGroup);
        record.Node.TreeExiting += () => record.ExitedAt = _gameClock;
        _framesPending.Add(record);
        foreach (var (unit, token) in _fxTokens)
        {
            if (!IsInstanceValid(token)) continue;
            float gap = token.GlobalPosition.DistanceTo(record.Node.GlobalPosition);
            if (gap >= record.FeetGap) continue;
            record.FeetGap = gap;
            record.Unit = unit;
            record.BarHeight = token.HpBarHeight;
        }
        return record;
    }

    /// <summary>The token of a unit in the current encounter, or null.</summary>
    private UnitVisual3D? FxToken(ICharacter? unit)
        => unit != null && _fxTokens.TryGetValue(unit, out var token) && IsInstanceValid(token) ? token : null;

    /// <summary>Clear the hover once, then save the viewport at full size as the game clock reaches
    /// each time after the spawn. The print gives the game time of each grab.</summary>
    private async Task CaptureAfterSpawn(FxRecord record, string what, params (string File, double Seconds)[] shots)
    {
        if (ShotDirectory.Length == 0) return;
        _runner.Scene?.HoverTile(null);
        foreach (var (file, seconds) in shots)
        {
            while (_gameClock - record.SpawnedAt < seconds)
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            double at = _gameClock - record.SpawnedAt;
            Check($"{file} saved", SaveViewportCapture(ShotDirectory.PathJoin(file)) == Error.Ok);
            GD.Print($"[PrologueRun] {file} at {at:0.000} s of game time after {what}");
        }
    }

    private static string Units(IEnumerable<FxRecord> records)
        => string.Join(", ", records.Select(r => $"E{r.Encounter} {r.Unit?.Name ?? "?"}"));
}
