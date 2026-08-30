using Godot;

namespace Delve.Fx;

/// <summary>
/// Base for every one-shot combat effect in scripts/fx. The effect builds its geometry in code from a
/// baked table, animates it on one Tween, and then frees itself. House style keeps the geometry to
/// flat-colour, unshaded, alpha-blended <see cref="QuadMesh"/> billboards. No AnimationPlayer, no
/// particle system, no textures or shaders.
///
/// The caller sets <see cref="Tint"/>, <see cref="FxScale"/> and <see cref="Lifetime"/> BEFORE
/// AddChild, because <see cref="_Ready"/> reads them once to build the geometry. See
/// <c>Delve.Combat.GodotPresenter3D.SpawnFx</c>, which is the only caller today.
/// </summary>
public abstract partial class OneShotFx : Node3D
{
    /// <summary>Group every spawned effect joins, so the juice spike can count live effects.</summary>
    public const string FxGroup = "Fx";

    /// <summary>Effect colour. Each subclass sets its own default in its constructor.</summary>
    [Export] public Color Tint { get; set; } = Colors.White;

    /// <summary>Unit-size multiplier for every baked size and distance. The tables are authored for a
    /// ~1.6 m hero, so the presenter passes ~0.66 for a ~0.7 m rat.</summary>
    [Export] public float FxScale { get; set; } = 1f;

    /// <summary>Total lifetime in seconds. The node frees itself when the tween ends.</summary>
    [Export] public float Lifetime { get; set; } = 0.5f;

    /// <summary>Stand-in for "invisible" in a scale tween. A literal <see cref="Vector3.Zero"/> makes a
    /// singular billboard transform, which trips the renderer's determinant assertion.</summary>
    protected static readonly Vector3 NearZeroScale = Vector3.One * 0.001f;

    public sealed override void _Ready()
    {
        AddToGroup(FxGroup);

        var tween = CreateTween();
        tween.SetParallel(true);
        Build(tween);
        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }

    /// <summary>Add the effect's children and queue their tweens. The tween runs in parallel mode.</summary>
    protected abstract void Build(Tween tween);

    /// <summary>Make one unshaded, alpha-blended, camera-facing quad of the given size and colour. The
    /// caller sets its Position and Scale, and can tween <c>albedo_color:a</c> on the returned node's
    /// <see cref="MeshInstance3D.MaterialOverride"/>.</summary>
    protected static MeshInstance3D BillboardQuad(float size, Color color) => new()
    {
        Mesh = new QuadMesh { Size = Vector2.One * size },
        MaterialOverride = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            AlbedoColor = color,
            BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled,
        },
    };

    /// <summary>
    /// Build one expanding ring of quads under <paramref name="parent"/>. A ring is a circle of small
    /// quads, not one ring-shaped quad, because house style has no texture or shader to draw an annulus.
    /// Every quad pops from near zero, travels out to <paramref name="radius"/>, then shrinks away.
    /// </summary>
    /// <param name="height">Local Y the quads sit at, above the caller-placed base.</param>
    /// <param name="delay">Seconds before this ring starts.</param>
    /// <param name="popTrans">Transition for the pop-in. Back overshoots; Sine does not.</param>
    /// <param name="shrinkDelay">Seconds from t=0 (not from <paramref name="delay"/>) to the shrink.</param>
    protected static void BuildRing(Tween tween, Node3D parent, Color color, int count, float radius,
        float shardSize, float height, float delay, float expandTime, float popTime,
        Tween.TransitionType popTrans, float shrinkDelay, float shrinkTime)
    {
        var lift = new Vector3(0f, height, 0f);
        for (int i = 0; i < count; i++)
        {
            float rad = Mathf.Tau * i / count;
            var dot = BillboardQuad(shardSize, color);
            dot.Position = lift;
            dot.Scale = NearZeroScale;
            parent.AddChild(dot);

            Vector3 target = new Vector3(Mathf.Sin(rad), 0f, Mathf.Cos(rad)) * radius + lift;

            tween.TweenProperty(dot, "position", target, expandTime)
                .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(dot, "scale", Vector3.One, popTime)
                .SetDelay(delay).SetTrans(popTrans).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(dot, "scale", NearZeroScale, shrinkTime)
                .SetDelay(shrinkDelay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        }
    }
}
