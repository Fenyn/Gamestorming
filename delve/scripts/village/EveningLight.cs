using Godot;

namespace Delve.Village;

/// <summary>A lamp, door light or window spill that is dark by day and lit in the evening, with a slow flicker.</summary>
public partial class EveningLight : OmniLight3D
{
    public const string Group = "village_evening_light";

    [Export] public float Energy { get; set; } = 1.2f;
    [Export] public float FlickerAmount { get; set; } = 0.08f;
    [Export] public float FlickerSpeed { get; set; } = 6.1f;

    private bool _lit;
    private float _time;

    public override void _Ready()
    {
        AddToGroup(Group);
        // Each light flickers on its own phase, taken from where it stands.
        _time = GlobalPosition.X * 1.7f + GlobalPosition.Z * 2.3f;
        LightEnergy = 0;
    }

    public void SetEvening(bool evening)
    {
        _lit = evening;
        LightEnergy = evening ? Energy : 0;
    }

    public override void _Process(double delta)
    {
        if (!_lit || !IsVisibleInTree()) return;
        _time += (float)delta;
        LightEnergy = Energy * (1 + Mathf.Sin(_time * FlickerSpeed) * FlickerAmount + Mathf.Sin(_time * FlickerSpeed * 2.3f) * FlickerAmount * 0.5f);
    }
}
