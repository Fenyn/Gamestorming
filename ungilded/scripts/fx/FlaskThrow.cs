using Godot;

namespace Ungilded.Fx;

/// <summary>
/// One-shot thrown flask: a corked acid flask lobs from the thrower's hand to the target's impact
/// point, turning end over end, while a few drops fall from it and its shadow runs along the floor.
/// An HD-2D effect like <see cref="AcidSplash"/>: the scene (scenes/fx/flask_throw.tscn) is written by
/// tools/vfx/flask_throw/build_flask_throw.gd, whose NOTES.md holds the round log and the hook
/// contract. The acid splash is not part of this scene; the presenter spawns it after the flight.
///
/// Unlike the other HD-2D effects this class moves the scene's parts itself, on the one tween:
/// <c>%Flask</c> (a one-particle flipbook, the tumble) along the arc, with <c>%Trail</c> under it,
/// and <c>%Shadow</c> along the ground track, its frame and alpha taken from the flask's height. The
/// scene's <c>%Anim</c> flies a fixed throw for the contact sheets only and is never played here.
///
/// The caller calls <see cref="Aim"/> (or sets <see cref="Start"/>, <see cref="End"/>,
/// <see cref="TargetFeet"/>, <see cref="FlightSeconds"/> and <see cref="ApexHeight"/>) and sets
/// <see cref="BodyPixelSize"/> BEFORE AddChild, and places the root at the thrower's FEET. Positions are
/// in the space of the node's parent, the same space as Position (the presenter's popup layer). The
/// flask leaves <see cref="Start"/> at t = 0 and reaches <see cref="End"/> at <see cref="FlightSeconds"/>,
/// when <see cref="Arrived"/> fires and the node frees itself (<see cref="OneShotFx.Lifetime"/> =
/// <see cref="FlightSeconds"/>). <see cref="OneShotFx.Tint"/> and <see cref="OneShotFx.FxScale"/> are
/// unused: the frames carry their own palette and sit on the thrower's pixel grid.
/// </summary>
public partial class FlaskThrow : OneShotFx
{
    /// <summary>The flask reached <see cref="End"/>. Fires once, in the frame the node frees itself.</summary>
    [Signal] public delegate void ArrivedEventHandler();

    /// <summary>Where the flask leaves the thrower's hand.</summary>
    [Export] public Vector3 Start { get; set; }

    /// <summary>Where the flask breaks: the target's impact point.</summary>
    [Export] public Vector3 End { get; set; }

    /// <summary>The target's feet. The shadow runs on the floor from the root to here.</summary>
    [Export] public Vector3 TargetFeet { get; set; }

    /// <summary>Seconds from the hand to the impact point.</summary>
    [Export] public float FlightSeconds { get; set; } = 0.45f;

    /// <summary>Metres the arc peaks above the straight line from <see cref="Start"/> to <see cref="End"/>.</summary>
    [Export] public float ApexHeight { get; set; } = 1.2f;

    /// <summary>The thrower's sprite pixel size in metres. The presenter reads it off the unit.</summary>
    [Export] public float BodyPixelSize { get; set; } = 0.02f;

    /// <summary>Metres per texel of the frames at scale 1. Written by the build script.</summary>
    [Export] public float FramePixelSize { get; set; } = 0.02f;

    [ExportGroup("Flight rule")]
    /// <summary>Flight of a throw of <see cref="BaseFlightTiles"/> tiles.</summary>
    [Export] public float BaseFlightSeconds { get; set; } = 0.4f;
    [Export] public float BaseFlightTiles { get; set; } = 3f;
    /// <summary>Seconds added (or taken off) per tile beyond (or short of) <see cref="BaseFlightTiles"/>.</summary>
    [Export] public float FlightSecondsPerTile { get; set; } = 0.03f;
    [Export] public float MinFlightSeconds { get; set; } = 0.3f;
    [Export] public float MaxFlightSeconds { get; set; } = 0.65f;
    /// <summary>Apex per tile thrown: 1.2 m for a 4-tile throw.</summary>
    [Export] public float ApexPerTile { get; set; } = 0.3f;
    [Export] public float MinApexHeight { get; set; } = 0.5f;
    [Export] public float MaxApexHeight { get; set; } = 2f;
    /// <summary>Metres the hand sits in front of the thrower's feet, toward the target.</summary>
    [Export] public float HandForward { get; set; } = 0.15f;

    [ExportGroup("Drops")]
    /// <summary>Share of the flight at which <c>%Trail</c> starts and stops shedding drops. Written by the build script.</summary>
    [Export] public float TrailFrom { get; set; } = 0.1f;
    [Export] public float TrailUntil { get; set; } = 0.5f;

    [ExportGroup("Shadow")]
    // frame = clamp(round(height * ShadowFramesPerMetre - ShadowFrameLift), 0, hframes - 1);
    // alpha = clamp(ShadowAlphaGround - height * ShadowAlphaPerMetre, ShadowAlphaMin, ShadowAlphaGround)
    //         * clamp((ground left - ShadowGoneMetres) / ShadowFadeMetres, 0, 1). Written by the build script.
    [Export] public float ShadowFramesPerMetre { get; set; } = 3.6f;
    [Export] public float ShadowFrameLift { get; set; } = 1.15f;
    [Export] public float ShadowAlphaGround { get; set; } = 0.65f;
    [Export] public float ShadowAlphaPerMetre { get; set; } = 0.12f;
    [Export] public float ShadowAlphaMin { get; set; } = 0.4f;
    [Export] public float ShadowGoneMetres { get; set; } = 0f;
    [Export] public float ShadowFadeMetres { get; set; } = 1f;

    /// <summary>Most the shadow's alpha changes in a second. Where the surface steps (onto a pillar,
    /// into a pit) the shadow moves to the new surface at once and its strength eases over a few frames.</summary>
    [Export] public float ShadowAlphaPerSecond { get; set; } = 3f;

    /// <summary>Height of the drawn board surface at a point in the parent's space. The presenter sets
    /// it before AddChild. Null on the contact sheets: the shadow then runs on the straight line between
    /// the thrower's and the target's feet.</summary>
    public System.Func<Vector3, float>? SurfaceHeight { get; set; }

    private GpuParticles3D _flask = null!;
    private Sprite3D _shadow = null!;
    private Vector3 _start, _end, _feetEnd, _groundOffset;
    private float _shadowAlpha = -1f, _lastShare;

    /// <summary>Aim a throw from the thrower's feet at the target's feet: the hand <paramref name="handHeight"/>
    /// above the thrower's feet and <see cref="HandForward"/> toward the target, the impact
    /// <paramref name="impactHeight"/> above the target's feet, and the flight and apex from the tiles thrown
    /// (<see cref="FlightFor"/>, <see cref="ApexFor"/>).</summary>
    public void Aim(Vector3 throwerFeet, Vector3 targetFeet, float handHeight, float impactHeight)
    {
        var flat = new Vector3(targetFeet.X - throwerFeet.X, 0f, targetFeet.Z - throwerFeet.Z);
        float tiles = flat.Length();
        var toward = tiles > Mathf.Epsilon ? flat / tiles : Vector3.Zero;
        Start = throwerFeet + Vector3.Up * handHeight + toward * HandForward;
        End = targetFeet + Vector3.Up * impactHeight;
        TargetFeet = targetFeet;
        FlightSeconds = FlightFor(tiles);
        ApexHeight = ApexFor(tiles);
    }

    /// <summary>The flight rule: <see cref="BaseFlightSeconds"/> for <see cref="BaseFlightTiles"/> tiles, plus
    /// <see cref="FlightSecondsPerTile"/> per tile beyond, within the min and max. 1 tile = 1 m.</summary>
    public float FlightFor(float tiles) => Mathf.Clamp(
        BaseFlightSeconds + (tiles - BaseFlightTiles) * FlightSecondsPerTile, MinFlightSeconds, MaxFlightSeconds);

    public float ApexFor(float tiles) => Mathf.Clamp(tiles * ApexPerTile, MinApexHeight, MaxApexHeight);

    protected override void Build(Tween tween)
    {
        Lifetime = FlightSeconds;
        _flask = GetNode<GpuParticles3D>("%Flask");
        _shadow = GetNode<Sprite3D>("%Shadow");
        var trail = GetNode<GpuParticles3D>("%Trail");

        // The arc in the root's own space; the root sits at the thrower's feet.
        var toLocal = Transform.AffineInverse();
        _start = toLocal * Start;
        _end = toLocal * End;
        _feetEnd = toLocal * TargetFeet;
        _groundOffset = GetNode<Node3D>("%Ground").Position;

        var flat = new Vector3(_end.X - _start.X, 0f, _end.Z - _start.Z);
        float pixelScale = BodyPixelSize / FramePixelSize;
        _flask.Scale = Vector3.One * pixelScale;
        _shadow.Scale = Vector3.One * pixelScale;
        AimDrops(trail, flat);
        if (FliesLeftOnScreen(flat)) ReverseTumble();

        _flask.Lifetime = FlightSeconds;
        _flask.Restart();
        trail.Emitting = false;
        Fly(0f);

        tween.TweenMethod(Callable.From<float>(Fly), 0f, 1f, FlightSeconds);
        tween.TweenCallback(Callable.From(() => trail.Emitting = true)).SetDelay(TrailFrom * FlightSeconds);
        tween.TweenCallback(Callable.From(() => trail.Emitting = false)).SetDelay(TrailUntil * FlightSeconds);
        tween.TweenCallback(Callable.From(() => EmitSignal(SignalName.Arrived))).SetDelay(FlightSeconds);
    }

    /// <summary>Place the flask and its shadow at share <paramref name="s"/> of the flight. The shadow sits
    /// on the surface sampled at its own XZ on every step, never between samples, so it cannot sink into
    /// the side of a pillar; its size and strength come from the flask's height above that point.</summary>
    private void Fly(float s)
    {
        var at = _start.Lerp(_end, s) + Vector3.Up * (4f * ApexHeight * s * (1f - s));
        _flask.Position = at;

        float floorY = FloorUnder(at, s);
        // %Ground's own height is the lift that keeps the shadow off the surface it lies on
        _shadow.Position = new Vector3(at.X - _groundOffset.X, floorY, at.Z - _groundOffset.Z);
        float height = at.Y - floorY;
        float left = new Vector2(_feetEnd.X - at.X, _feetEnd.Z - at.Z).Length();
        _shadow.Frame = Mathf.Clamp(Mathf.RoundToInt(height * ShadowFramesPerMetre - ShadowFrameLift), 0, _shadow.Hframes - 1);
        float alpha = Mathf.Clamp(ShadowAlphaGround - height * ShadowAlphaPerMetre, ShadowAlphaMin, ShadowAlphaGround)
            * Mathf.Clamp((left - ShadowGoneMetres) / ShadowFadeMetres, 0f, 1f);
        _shadowAlpha = _shadowAlpha < 0f
            ? alpha
            : Mathf.MoveToward(_shadowAlpha, alpha, ShadowAlphaPerSecond * Mathf.Max(s - _lastShare, 0f) * FlightSeconds);
        _lastShare = s;
        _shadow.Modulate = new Color(1f, 1f, 1f, _shadowAlpha);
    }

    /// <summary>The surface under a root-space point: the sampled board surface, or without a sampler
    /// the straight line from the thrower's feet to the target's.</summary>
    private float FloorUnder(Vector3 at, float s)
    {
        if (SurfaceHeight == null) return Mathf.Lerp(0f, _feetEnd.Y, s);
        var point = Transform * at;
        return (Transform.AffineInverse() * new Vector3(point.X, SurfaceHeight(point), point.Z)).Y;
    }

    /// <summary>The scene throws its drops forward along +X, the sheets' throw. Turn that direction
    /// along this throw on the throw's own copy of the process material. Turning the node instead
    /// turns the billboard quads too, and a throw toward -X showed the flask edge-on.</summary>
    private static void AimDrops(GpuParticles3D trail, Vector3 flat)
    {
        if (flat.LengthSquared() <= Mathf.Epsilon) return;
        var drops = (ParticleProcessMaterial)trail.ProcessMaterial.Duplicate();
        drops.Direction = new Basis(Vector3.Up, Mathf.Atan2(-flat.Z, flat.X)) * drops.Direction;
        trail.ProcessMaterial = drops;
    }

    /// <summary>The tumble frames turn clockwise, right for a flask flying to the right of the screen.</summary>
    private bool FliesLeftOnScreen(Vector3 flat)
    {
        var camera = GetViewport().GetCamera3D();
        return camera != null && (GlobalBasis * flat).Dot(camera.GlobalBasis.X) < 0f;
    }

    /// <summary>Play the tumble backwards. The process material is the scene's shared one, so this
    /// throw gets its own copy.</summary>
    private void ReverseTumble()
    {
        var process = (ParticleProcessMaterial)_flask.ProcessMaterial.Duplicate();
        process.AnimSpeedMin = -process.AnimSpeedMin;
        process.AnimSpeedMax = -process.AnimSpeedMax;
        _flask.ProcessMaterial = process;
    }
}
