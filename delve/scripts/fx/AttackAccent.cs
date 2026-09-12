using Godot;

namespace Delve.Fx;

/// <summary>Brief flat-color swing trail or closing jaw marks, including on a miss.</summary>
public partial class AttackAccent : OneShotFx
{
    [Export] public bool Bite { get; set; }
    [Export] public float HeightFraction { get; set; } = 0.65f;
    [Export] public float ForwardDistance { get; set; } = 0.35f;
    public Vector3 Direction { get; set; } = Vector3.Right;

    protected override void Build(Tween tween)
    {
        var camera = GetViewport().GetCamera3D();
        var right = camera?.GlobalBasis.X ?? Vector3.Right;
        var up = camera?.GlobalBasis.Y ?? Vector3.Up;
        float facing = Direction.Dot(right) < 0 ? -1 : 1;
        int count = Bite ? 8 : 9;
        for (int i = 0; i < count; i++)
        {
            float x, y, endY;
            if (Bite)
            {
                int tooth = i % 4;
                float side = i < 4 ? 1 : -1;
                x = (tooth - 1.5f) * 0.09f;
                y = side * (0.16f + (tooth == 0 || tooth == 3 ? -0.04f : 0));
                endY = side * 0.035f;
            }
            else
            {
                float angle = Mathf.Lerp(-1.1f, 1.1f, i / 8f);
                x = Mathf.Cos(angle) * 0.22f;
                y = Mathf.Sin(angle) * 0.3f;
                endY = y - 0.09f;
            }
            float size = Bite ? 0.08f : 0.06f + 0.025f * Mathf.Sin(Mathf.Pi * i / 8f);
            var shard = BillboardQuad(size * FxScale, Tint);
            shard.Position = (right * x * facing + up * y) * FxScale;
            AddChild(shard);
            tween.TweenProperty(shard, "position", (right * (x + 0.05f) * facing + up * endY) * FxScale, Lifetime * 0.6f)
                .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(shard.MaterialOverride, "albedo_color:a", 0f, Lifetime * 0.55f)
                .SetDelay(Lifetime * 0.45f);
            tween.TweenProperty(shard, "scale", NearZeroScale, Lifetime * 0.55f)
                .SetDelay(Lifetime * 0.45f);
        }
    }
}
