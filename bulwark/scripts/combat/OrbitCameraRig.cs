using Godot;

namespace Bulwark.Combat;

/// <summary>
/// Free-orbit tactical camera. Middle-mouse drag or right-mouse drag orbits (free yaw, pitch
/// clamped), the mouse wheel zooms (distance clamped), and the pivot sits at the board center.
/// A right *click* (released within <see cref="DragThresholdPixels"/> of travel) is deliberately
/// left unconsumed so <see cref="GridInput3D"/> can treat it as cancel-targeting; only once the
/// travel exceeds the threshold does the rig start orbiting and consuming the motion. Left clicks
/// are never consumed here. Thin input adapter: holds only camera tunables and pose, no game rules.
/// </summary>
public partial class OrbitCameraRig : Node3D
{
    [Export] public float PitchMinDegrees { get; set; } = 15f;
    [Export] public float PitchMaxDegrees { get; set; } = 75f;
    [Export] public float ZoomMin { get; set; } = 6f;
    [Export] public float ZoomMax { get; set; } = 30f;
    [Export] public float OrbitSensitivity { get; set; } = 0.4f;
    [Export] public float ZoomStep { get; set; } = 1.6f;
    /// <summary>Right-button travel (pixels) below which the gesture counts as a click, not a drag.
    /// Keep in sync with <see cref="GridInput3D.DragThresholdPixels"/>.</summary>
    [Export] public float DragThresholdPixels { get; set; } = 6f;
    /// <summary>WASD pan speed in meters/second at the ground plane.</summary>
    [Export] public float PanSpeed { get; set; } = 10f;

    [Export] public float InitialYawDegrees { get; set; } = 45f;
    [Export] public float InitialPitchDegrees { get; set; } = 50f;
    [Export] public float InitialDistance { get; set; } = 16f;

    private Camera3D _camera = null!;
    private float _yaw;
    private float _pitch;
    private float _distance;
    private bool _middleDragging;
    private bool _rightHeld;
    private float _rightTravel;

    public Camera3D Camera => _camera;

    public override void _Ready()
    {
        _camera = GetNode<Camera3D>("Camera3D");
        _yaw = InitialYawDegrees;
        _pitch = InitialPitchDegrees;
        _distance = InitialDistance;
        _camera.Current = true;
        UpdateCameraPose();
    }

    /// <summary>Point the orbit pivot at the board center in world space.</summary>
    public void FocusOn(Vector3 worldPivot)
    {
        GlobalPosition = worldPivot;
        UpdateCameraPose();
    }

    public override void _Process(double delta)
    {
        // WASD pans the pivot across the ground plane, camera-relative (W = screen-up).
        var pan = Vector2.Zero;
        if (Input.IsKeyPressed(Key.W)) pan.Y -= 1f;
        if (Input.IsKeyPressed(Key.S)) pan.Y += 1f;
        if (Input.IsKeyPressed(Key.A)) pan.X -= 1f;
        if (Input.IsKeyPressed(Key.D)) pan.X += 1f;
        if (pan == Vector2.Zero) return;

        pan = pan.Normalized() * PanSpeed * (float)delta;
        float yawRad = Mathf.DegToRad(_yaw);
        // Camera looks toward -offset; screen-up on the ground plane is the yaw-forward direction.
        var forward = new Vector3(-Mathf.Sin(yawRad), 0f, -Mathf.Cos(yawRad));
        var right = new Vector3(-forward.Z, 0f, forward.X);
        GlobalPosition += forward * -pan.Y + right * pan.X;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        switch (@event)
        {
            case InputEventMouseButton mb:
                if (mb.ButtonIndex == MouseButton.Middle)
                {
                    _middleDragging = mb.Pressed;
                    GetViewport().SetInputAsHandled();
                }
                else if (mb.ButtonIndex == MouseButton.Right)
                {
                    // Observe only — never consume. GridInput3D decides on release whether the
                    // gesture was a cancel click (under the threshold) using the same travel rule.
                    _rightHeld = mb.Pressed;
                    if (mb.Pressed) _rightTravel = 0f;
                }
                else if (mb.Pressed && mb.ButtonIndex == MouseButton.WheelUp)
                {
                    Zoom(-ZoomStep);
                    GetViewport().SetInputAsHandled();
                }
                else if (mb.Pressed && mb.ButtonIndex == MouseButton.WheelDown)
                {
                    Zoom(ZoomStep);
                    GetViewport().SetInputAsHandled();
                }
                break;

            case InputEventMouseMotion motion when _middleDragging:
                Orbit(motion.Relative);
                GetViewport().SetInputAsHandled();
                break;

            case InputEventMouseMotion motion when _rightHeld:
                _rightTravel += motion.Relative.Length();
                if (_rightTravel > DragThresholdPixels)
                {
                    Orbit(motion.Relative);
                    GetViewport().SetInputAsHandled();
                }
                break;
        }
    }

    private void Orbit(Vector2 relative)
    {
        _yaw -= relative.X * OrbitSensitivity;
        _pitch = Mathf.Clamp(_pitch + relative.Y * OrbitSensitivity, PitchMinDegrees, PitchMaxDegrees);
        UpdateCameraPose();
    }

    private void Zoom(float delta)
    {
        _distance = Mathf.Clamp(_distance + delta, ZoomMin, ZoomMax);
        UpdateCameraPose();
    }

    private void UpdateCameraPose()
    {
        if (_camera == null) return;

        float pitchRad = Mathf.DegToRad(_pitch);
        float yawRad = Mathf.DegToRad(_yaw);
        float horizontal = _distance * Mathf.Cos(pitchRad);

        var offset = new Vector3(
            horizontal * Mathf.Sin(yawRad),
            _distance * Mathf.Sin(pitchRad),
            horizontal * Mathf.Cos(yawRad));

        _camera.Position = offset;
        _camera.LookAt(GlobalPosition, Vector3.Up);
    }
}
