using Bulwark.Props;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Smoke test for the Winlu prop library (scenes/dev/props_spike.tscn). Walks a dummy body
/// through the door trigger, then drives the gate/chest/lever/lamp through their APIs on a
/// timeline and prints a PASS/FAIL summary. Run headless:
///   godot --headless --path bulwark res://scenes/dev/props_spike.tscn
/// </summary>
public partial class PropsSpike : Node2D
{
    private Door _door = null!;
    private Door _gate = null!;
    private Chest _chest = null!;
    private Lever _lever = null!;
    private AmbientProp _lamp = null!;
    private CharacterBody2D _walker = null!;

    private int _doorOpened;
    private int _doorClosed;
    private int _chestOpened;
    private int _leverToggles;

    private double _time;
    private bool _walkingBack;
    private bool _done;

    public override void _Ready()
    {
        _door = GetNode<Door>("Door");
        _gate = GetNode<Door>("Gate");
        _chest = GetNode<Chest>("Chest");
        _lever = GetNode<Lever>("Lever");
        _lamp = GetNode<AmbientProp>("Lamp");
        _walker = GetNode<CharacterBody2D>("Walker");

        _door.Opened += () => { _doorOpened++; GD.Print("[spike] door opened"); };
        _door.Closed += () => { _doorClosed++; GD.Print("[spike] door closed"); };
        _chest.Opened += () => { _chestOpened++; GD.Print("[spike] chest opened"); };
        _lever.Toggled += on => { _leverToggles++; GD.Print($"[spike] lever toggled -> {on}"); };
        _gate.Opened += () => GD.Print("[spike] gate opened");
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_done)
            return;
        _time += delta;

        // Walk the dummy through the door trigger and back out again.
        if (!_walkingBack)
        {
            _walker.Position += new Vector2(0, (float)(90 * delta));
            if (_walker.Position.Y > 60)
                _walkingBack = true;
        }
        else if (_walker.Position.Y > -90)
        {
            _walker.Position += new Vector2(0, (float)(-90 * delta));
        }

        if (_time > 2.0 && !_gate.IsOpen)
            _gate.Open();
        if (_time > 3.0 && !_chest.IsOpen)
            _chest.Open();
        if (_time > 3.5 && _leverToggles == 0)
            _lever.Toggle();
        if (_time > 4.0 && _time < 4.4 && _lamp.IsOn)
            _lamp.SetOn(false);
        if (_time > 4.5 && !_lamp.IsOn)
            _lamp.SetOn(true);

        if (_time > 7.0)
            Finish();
    }

    private void Finish()
    {
        _done = true;
        bool pass = _doorOpened >= 1 && _doorClosed >= 1 && _gate.IsOpen &&
                    _chestOpened == 1 && _leverToggles == 1 && _lamp.IsOn;
        GD.Print($"[spike] doorOpened={_doorOpened} doorClosed={_doorClosed} gateOpen={_gate.IsOpen} " +
                 $"chestOpened={_chestOpened} leverToggles={_leverToggles} lampOn={_lamp.IsOn}");
        GD.Print(pass ? "[spike] PASS" : "[spike] FAIL");
        GetTree().Quit(pass ? 0 : 1);
    }
}
