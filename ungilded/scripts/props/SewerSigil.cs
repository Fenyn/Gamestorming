using Godot;

namespace Ungilded.Props;

/// <summary>
/// The Encounter 4 sigil. Its Pulse animation breathes the glow; <see cref="Awaken"/> stops the
/// breathing and brightens the glow and the light toward their awake values, for a cutscene.
/// </summary>
public partial class SewerSigil : Node3D
{
    [Export] public float AwakeGlowAlpha { get; set; } = 0.95f;
    [Export] public float AwakeLightEnergy { get; set; } = 2.4f;
    [Export] public float AwakeLightRange { get; set; } = 4.5f;

    /// <summary>0 asleep, 1 fully awake.</summary>
    public float Awakening { get; private set; }

    private Sprite3D _glow = null!;
    private OmniLight3D _light = null!;
    private AnimationPlayer _pulse = null!;

    public override void _Ready()
    {
        _glow = GetNode<Sprite3D>("%Glow");
        _light = GetNode<OmniLight3D>("%Light");
        _pulse = GetNode<AnimationPlayer>("%Pulse");
    }

    /// <summary>Brighten to <paramref name="strength"/> of the awake glow over
    /// <paramref name="seconds"/>.</summary>
    public void Awaken(float strength, float seconds)
    {
        Awakening = strength;
        _pulse.Pause();
        float alpha = Mathf.Lerp(_glow.Modulate.A, AwakeGlowAlpha, strength);
        var tween = CreateTween().SetParallel();
        tween.TweenProperty(_glow, "modulate:a", alpha, seconds);
        tween.TweenProperty(_light, "light_energy", Mathf.Lerp(_light.LightEnergy, AwakeLightEnergy, strength), seconds);
        tween.TweenProperty(_light, "omni_range", Mathf.Lerp(_light.OmniRange, AwakeLightRange, strength), seconds);
    }
}
