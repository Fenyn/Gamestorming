using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using Ungilded.Content;
using Ungilded.Fx;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// The thrown flask, recorded through the effect watch (PrologueRunSpike.FxWatch.cs): each
/// <see cref="FlaskThrow"/>, the token it left from, the token it lands on, its flight, when it was
/// freed, and its order against the <see cref="AcidSplash"/> on the same creature
/// (PrologueRunSpike.AcidSplash.cs). Rendered, Encounter 3's first throw is saved at
/// <see cref="FlaskShotShare"/> and <see cref="FlaskLateShotShare"/> of its flight, at full viewport size. The checks read the splash records, so they run after
/// CheckAcidSplashes.
/// </summary>
public partial class PrologueRunSpike
{
    /// <summary>Shares of the first Encounter 3 flight at which the rendered run saves the board:
    /// mid-flight and at the target.</summary>
    [Export] public float FlaskShotShare { get; set; } = 0.5f;
    [Export] public float FlaskLateShotShare { get; set; } = 0.95f;

    /// <summary>Furthest a throw may end from its target's axis, in metres.</summary>
    [Export] public float FlaskEndTolerance { get; set; } = 0.05f;

    /// <summary>Slack on a throw's own flight before it counts as not freed on time, in game seconds.</summary>
    [Export] public float FlaskLifetimeSlack { get; set; } = 0.1f;

    /// <summary>How much earlier than the flask's arrival a splash may spawn, in game seconds.</summary>
    [Export] public float FlaskArrivalSlack { get; set; } = 0.05f;

    /// <summary>Furthest the shadow may sit from the drawn surface at its XZ, in metres.</summary>
    [Export] public float FlaskShadowTolerance { get; set; } = 0.02f;

    /// <summary>Height of the flask above the surface under it from which its shadow must show, in metres.</summary>
    [Export] public float FlaskShadowShownAbove { get; set; } = 0.3f;

    /// <summary>Least alpha a shadow that must show may have.</summary>
    [Export] public float FlaskShadowMinAlpha { get; set; } = 0.1f;

    /// <summary>Shares of each flight at which the shadow is read against the drawn surface.</summary>
    private static readonly float[] ShadowSampleShares = { 0.25f, 0.5f, 0.75f };

    /// <summary>The shadow at one point of a flight: the tile under it, the drawn surface height there
    /// (the terrain, or the top of masonry the wall cut takes down), its own height, how high the
    /// flask was above that surface, its alpha, and whether it lay in the fade before the target.</summary>
    private readonly record struct ShadowSample(float Share, PF2eVec Tile, float Surface, float ShadowY,
        float FlaskUp, float Alpha, bool Shown, bool InFade, Vector2 Screen);

    private sealed class ThrowRecord : FxRecord
    {
        public ThrowRecord(FlaskThrow node, int encounter) : base(node, encounter)
        {
            FlightSeconds = node.FlightSeconds;
        }

        public float FlightSeconds { get; }
        public ICharacter? Target { get; set; }

        /// <summary>Horizontal metres from the throw's End to the target's feet.</summary>
        public float EndGap { get; set; } = float.MaxValue;

        /// <summary>Metres the throw's End sits above the target's feet.</summary>
        public float EndHeight { get; set; }

        public float TargetBar { get; set; }

        /// <summary>Game seconds the frame the node left the tree in took. A capture just before the
        /// arrival stretches that frame, and the clock reads the whole frame.</summary>
        public double ExitFrame { get; set; }

        public List<ShadowSample> Shadow { get; } = new();

        public double ArrivesAt => SpawnedAt + FlightSeconds;
    }

    private readonly List<ThrowRecord> _throws = new();

    private void WatchFlaskThrows() => GetTree().NodeAdded += OnFlaskNodeAdded;

    private void StopWatchingFlaskThrows() => GetTree().NodeAdded -= OnFlaskNodeAdded;

    private void OnFlaskNodeAdded(Node node)
    {
        if (node is FlaskThrow flask) flask.Ready += () => NoteFlaskThrow(flask);
    }

    private void NoteFlaskThrow(FlaskThrow flask)
    {
        // Track gives the token nearest the root, the thrower; the target is the token under End.
        var record = Track(new ThrowRecord(flask, _runner.CurrentEncounter));
        _throws.Add(record);
        flask.TreeExiting += () => record.ExitFrame = GetProcessDeltaTime();
        _ = SampleShadow(record, flask);

        var space = flask.GetParentOrNull<Node3D>();
        var end = space?.ToGlobal(flask.End) ?? flask.End;
        foreach (var (unit, token) in _fxTokens)
        {
            if (!IsInstanceValid(token)) continue;
            var feet = token.GlobalPosition;
            float gap = new Vector2(end.X - feet.X, end.Z - feet.Z).Length();
            if (gap >= record.EndGap) continue;
            record.EndGap = gap;
            record.EndHeight = end.Y - feet.Y;
            record.Target = unit;
            record.TargetBar = token.HpBarHeight;
        }

        if (record.Encounter == 3 && _throws.Count(t => t.Encounter == 3) == 1 && !Headless)
            _ = CaptureAfterSpawn(record, "flask throw 1",
                ("flask_throw.png", FlaskShotShare * record.FlightSeconds),
                ("flask_throw_late.png", FlaskLateShotShare * record.FlightSeconds));
        // the Encounter 3 throw crosses the heroes and rats between the Friend and Rat C, so its
        // shadow lies under their sprites; the Encounter 4 throw runs over open floor
        if (record.Encounter == 4 && _throws.Count(t => t.Encounter == 4) == 1 && !Headless)
            _ = CaptureAfterSpawn(record, "the Encounter 4 flask throw",
                ("flask_throw_e4.png", FlaskShotShare * record.FlightSeconds));
    }

    /// <summary>Read the shadow at each <see cref="ShadowSampleShares"/> of the flight, in game time,
    /// against the drawn surface the terrain stage reports at the shadow's own XZ.</summary>
    private async Task SampleShadow(ThrowRecord record, FlaskThrow flask)
    {
        var stage = _runner.Scene?.GetNode<TerrainStage>("%TerrainStage");
        var space = flask.GetParentOrNull<Node3D>();
        if (stage == null || space == null) return;
        foreach (float share in ShadowSampleShares)
        {
            while (_gameClock - record.SpawnedAt < share * record.FlightSeconds)
            {
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                if (!IsInstanceValid(flask)) return;
            }
            var shadow = flask.GetNode<Sprite3D>("%Shadow");
            var at = space.ToLocal(shadow.GlobalPosition);
            var tile = GridSpace.WorldToGrid(at);
            float surface = stage.Cutaway?.CutTopY(tile.x, tile.y)
                ?? stage.HeightMap.SampleY(tile, at.X - tile.x, at.Z - tile.y);
            float flaskUp = space.ToLocal(flask.GetNode<Node3D>("%Flask").GlobalPosition).Y - surface;
            float left = new Vector2(flask.TargetFeet.X - at.X, flask.TargetFeet.Z - at.Z).Length();
            var screen = GetViewport().GetCamera3D()?.UnprojectPosition(shadow.GlobalPosition) ?? Vector2.Zero;
            record.Shadow.Add(new ShadowSample(share, tile, surface, at.Y, flaskUp, shadow.Modulate.A,
                shadow.IsVisibleInTree(), left < flask.ShadowGoneMetres + flask.ShadowFadeMetres, screen));
        }
    }

    /// <summary>Above the surface by a lift under the tolerance: level with it, the floor's depth hid it.</summary>
    private bool ShadowOnSurface(ThrowRecord t) => t.Shadow.Count == ShadowSampleShares.Length
        && t.Shadow.All(p => p.ShadowY > p.Surface && p.ShadowY - p.Surface <= FlaskShadowTolerance);

    private bool ShadowShown(ThrowRecord t) => t.Shadow.All(p => p.FlaskUp <= FlaskShadowShownAbove || p.InFade
        || (p.Shown && p.Alpha >= FlaskShadowMinAlpha));

    private void CheckFlaskThrows()
    {
        foreach (var t in _throws)
            GD.Print($"[PrologueRun] flask throw E{t.Encounter} by {t.Unit?.Name ?? "?"} at {t.Target?.Name ?? "?"} "
                + $"fx group {t.InFxGroup} feet gap {t.FeetGap:0.000} end gap {t.EndGap:0.000} "
                + $"end height {t.EndHeight:0.00} of bar {t.TargetBar:0.00} flight {t.FlightSeconds:0.00} s, "
                + $"splash {SplashGap(t)} after the arrival, {t.Timing}; shadow "
                + string.Join("; ", t.Shadow.Select(p => $"at {p.Share:0.00} tile ({p.Tile.x},{p.Tile.y}) surface {p.Surface:0.000} "
                    + $"shadow {p.ShadowY:0.000} flask {p.FlaskUp:0.00} m up alpha {p.Alpha:0.00}{(p.InFade ? " fading" : "")} "
                    + $"screen ({p.Screen.X:0},{p.Screen.Y:0})")));

        var thrown = _throws.Where(t => t.Encounter is 3 or 4).ToArray();
        var hits = _splashes.Where(s => s.Encounter is 3 or 4 && !s.Minor).ToArray();
        int e3Throws = thrown.Count(t => t.Encounter == 3);
        int e3Hits = hits.Count(s => s.Encounter == 3);
        Check($"E3: a flask throw for each flask that hit ({e3Throws} throws, {e3Hits} hits)",
            e3Hits >= 1 && e3Throws >= e3Hits);
        Check("E4: a flask was thrown at the Sewer Tyrant", thrown.Any(t => t.Encounter == 4
            && t.Target?.CreatureStats?.CreatureId == PrologueBestiary.SewerTyrantId));

        CheckWith("every flask throw joined the Fx group", thrown.All(t => t.InFxGroup), Units(thrown.Where(t => !t.InFxGroup)));
        CheckWith("every flask throw left from the Friend's feet", thrown.All(FromFriend), Units(thrown.Where(t => !FromFriend(t))));
        CheckWith("every flask throw ended on its target's axis, under its HP bar",
            thrown.All(OnTarget), Units(thrown.Where(t => !OnTarget(t))));
        CheckWith($"every flask throw freed itself after its flight, within {FlaskLifetimeSlack:0.00} s",
            thrown.All(FreedOnArrival), Units(thrown.Where(t => !FreedOnArrival(t))));
        CheckWith("every flask hit's acid splash spawned after a throw at that creature arrived",
            hits.All(SplashAfterThrow), string.Join(", ", hits.Where(s => !SplashAfterThrow(s)).Select(s => $"E{s.Encounter} {s.Unit?.Name ?? "?"}")));
        CheckWith("no acid splash spawned on a flask's target while the flask was in the air",
            thrown.All(NoSplashInFlight), Units(thrown.Where(t => !NoSplashInFlight(t))));
        CheckWith($"every flask shadow sat on the drawn surface at its XZ within {FlaskShadowTolerance * 100f:0} cm "
            + $"at {ShadowSampleShares.Length} points of its flight", thrown.All(ShadowOnSurface), Units(thrown.Where(t => !ShadowOnSurface(t))));
        CheckWith($"every flask shadow showed while its flask was more than {FlaskShadowShownAbove:0.0} m up, outside the fade before the target",
            thrown.All(ShadowShown), Units(thrown.Where(t => !ShadowShown(t))));
    }

    private bool FromFriend(ThrowRecord t) => t.Unit == _runner.Friend && t.FeetGap <= FxFeetTolerance;

    private bool OnTarget(ThrowRecord t)
        => t.Target != null && t.EndGap <= FlaskEndTolerance && t.EndHeight > 0f && t.EndHeight < t.TargetBar;

    private bool FreedOnArrival(ThrowRecord t) => t.Freed && t.Lived >= t.FlightSeconds - FlaskLifetimeSlack
        && t.Lived - t.ExitFrame <= t.FlightSeconds + FlaskLifetimeSlack;

    /// <summary>Game seconds from a throw's arrival to the first acid splash on its target, or "no splash".</summary>
    private string SplashGap(ThrowRecord t)
    {
        var first = _splashes.Where(s => s.Unit == t.Target && s.SpawnedAt >= t.SpawnedAt)
            .OrderBy(s => s.SpawnedAt).FirstOrDefault();
        return first == null ? "no splash" : $"{first.SpawnedAt - t.ArrivesAt:0.000} s";
    }

    private bool SplashAfterThrow(SplashRecord s) => _throws.Any(t => t.Target == s.Unit
        && t.SpawnedAt < s.SpawnedAt && s.SpawnedAt >= t.ArrivesAt - FlaskArrivalSlack);

    private bool NoSplashInFlight(ThrowRecord t) => !_splashes.Any(s => s.Unit == t.Target
        && s.SpawnedAt >= t.SpawnedAt && s.SpawnedAt < t.ArrivesAt - FlaskArrivalSlack);
}
