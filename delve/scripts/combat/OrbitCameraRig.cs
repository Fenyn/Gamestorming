using Godot;

using Delve.Settings;
namespace Delve.Combat;

/// <summary>
/// Free-orbit tactical camera. Middle-mouse drag or right-mouse drag orbits (free yaw, pitch
/// clamped), the mouse wheel zooms (distance clamped), and the pivot sits at the board center.
/// A right *click* (released within <see cref="DragThresholdPixels"/> of travel) is deliberately
/// left unconsumed so <see cref="GridInput3D"/> can treat it as cancel-targeting; only once the
/// travel exceeds the threshold does the rig start orbiting and consuming the motion. Left clicks
/// are never consumed here. Thin input adapter: holds only camera tunables and pose, no game rules.
/// The rig reads <see cref="ViewPreferences.CombatCameraDistance"/> on _Ready and writes it back on
/// every wheel zoom, so the zoom survives a re-encounter within the session.
/// </summary>
public partial class OrbitCameraRig : Node3D
{
    [Export] public float PitchMinDegrees { get; set; } = 15f;
    [Export] public float PitchMaxDegrees { get; set; } = 75f;
    [Export] public float ZoomMin { get; set; } = 6f;
    [Export] public float ZoomMax { get; set; } = 30f;
    [Export] public float OrbitSensitivity { get; set; } = 0.4f;
    [Export] public float ZoomStep { get; set; } = 1.6f;
    /// <summary>Default right-button travel (pixels) below which a gesture counts as a click, not a
    /// drag. The rig owns the gesture, so it owns the constant; GridInput3D defaults to it too, and
    /// CombatScene pushes the rig's live value into GridInput3D so both always agree.</summary>
    public const float DefaultDragThresholdPixels = 6f;

    /// <summary>Right-button travel (pixels) below which the gesture counts as a click, not a drag.</summary>
    [Export] public float DragThresholdPixels { get; set; } = DefaultDragThresholdPixels;
    /// <summary>WASD pan speed in meters/second at the ground plane.</summary>
    [Export] public float PanSpeed { get; set; } = 10f;

    [Export] public float InitialYawDegrees { get; set; } = 45f;
    [Export] public float InitialPitchDegrees { get; set; } = 50f;
    /// <summary>
    /// Start distance per tile of the board's longer side (1 tile = 1 m), used only until the player
    /// has ever zoomed in combat — after that <see cref="ViewPreferences.CombatCameraDistance"/> wins.
    /// Boards come in any size the biome rolls, so the framing is a ratio rather than a distance:
    /// 1.15 puts a 14-tile board at the 16 m the FX sprites were sized for.
    /// </summary>
    [Export] public float FramingDistancePerTile { get; set; } = 1.15f;

    /// <summary>Zoom ceiling as a multiple of the framing distance, so a big board can still be
    /// backed off to a full overview.</summary>
    [Export] public float ZoomOutFactor { get; set; } = 2f;

    private Camera3D _camera = null!;
    private ShakePivot _shake = null!;
    private float _yaw;
    private float _pitch;
    private float _distance;
    private bool _middleDragging;
    private bool _rightHeld;
    private float _rightTravel;

    public Camera3D Camera => _camera;

    /// <summary>
    /// The trauma-shake node the camera hangs off (rig &gt; ShakePivot &gt; Camera3D) — exposed so the
    /// presenter can add trauma on a crit or a death.
    /// </summary>
    public ShakePivot Shake => _shake;

    public override void _Ready()
    {
        // The camera sits under the shake pivot; the rig keeps writing the CAMERA's own orbit pose
        // (position + look-at) while the pivot writes only its own local position, so the shake offset
        // composes with the orbit instead of either overwriting the other.
        _shake = GetNode<ShakePivot>("%ShakePivot");
        _camera = _shake.GetNode<Camera3D>("Camera3D");
        _yaw = InitialYawDegrees;
        _pitch = InitialPitchDegrees;
        _distance = ZoomMin;
        _camera.Current = true;
        UpdateCameraPose();
    }

    /// <summary>
    /// Point the orbit pivot at the board center and frame the board: the zoom range and the
    /// default distance follow the board's longer side, so a 12-tile skirmish and a 30-tile
    /// sewer both open as a full view. A distance the player chose earlier still wins.
    /// </summary>
    public void FrameBoard(Vector3 worldPivot, int boardWidth, int boardHeight)
    {
        float framing = Mathf.Max(boardWidth, boardHeight) * FramingDistancePerTile;
        ZoomMax = Mathf.Max(ZoomMax, framing * ZoomOutFactor);
        _distance = ViewPreferences.HasStoredCombatCameraDistance
            ? Mathf.Clamp(ViewPreferences.CombatCameraDistance, ZoomMin, ZoomMax)
            : Mathf.Clamp(framing, ZoomMin, ZoomMax);
        GlobalPosition = worldPivot;
        UpdateCameraPose();
    }

    /// <summary>
    /// Set the orbit pose directly (degrees; pitch clamped to the rig's limits). Capture/dev use —
    /// the combat shot spike frames a low-pitch horizon angle with it. Play orbiting stays on input.
    /// </summary>
    public void SetOrbit(float yawDegrees, float pitchDegrees)
    {
        _yaw = yawDegrees;
        _pitch = Mathf.Clamp(pitchDegrees, PitchMinDegrees, PitchMaxDegrees);
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
        ViewPreferences.CombatCameraDistance = _distance;
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
