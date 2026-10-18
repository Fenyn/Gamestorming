using Godot;

namespace Delve.Village;

/// <summary>A thing in the village the player can click: the Delve trail, the unlocks board, the bestiary table.</summary>
public partial class VillageStation : Area3D
{
    [Signal] public delegate void PressedEventHandler(string id);
    [Signal] public delegate void HoveredEventHandler(string id, bool over);

    [Export] public string Id { get; set; } = "";
    [Export] public string Title { get; set; } = "";

    /// <summary>The input action that also opens this station, shown on its nameplate; empty for none.</summary>
    [Export] public StringName Action { get; set; } = "";

    /// <summary>Where the nameplate's bottom edge sits, from the station's center.</summary>
    [Export] public Vector3 TagOffset { get; set; }

    /// <summary>A way out of the view (the Delve trail): just past the frame, its plate stays on the edge.</summary>
    [Export] public bool PinToEdge { get; set; }

    public override void _Ready()
    {
        InputEvent += OnInput;
        MouseEntered += () => EmitSignal(SignalName.Hovered, Id, true);
        MouseExited += () => EmitSignal(SignalName.Hovered, Id, false);
    }

    private void OnInput(Node camera, InputEvent input, Vector3 position, Vector3 normal, long shape)
    {
        if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true })
            EmitSignal(SignalName.Pressed, Id);
    }
}
