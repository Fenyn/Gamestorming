using Godot;

using Delve.Settings;
namespace Delve.Combat;

/// <summary>
/// Free-orbit tactical camera. Middle-mouse drag or right-mouse drag orbits (free yaw, pitch
/// clamped), the mouse wheel zooms (distance clamped), and the pivot sits on the acting unit: the
/// presenter lands it there at every turn start and tracks a walking unit through
/// <see cref="ICameraFocus"/>. A right *click* (released within <see cref="DragThresholdPixels"/> of
/// travel) is deliberately left unconsumed so <see cref="GridInput3D"/> can treat it as
/// cancel-targeting; only once the travel exceeds the threshold does the rig start orbiting and
/// consuming the motion. Left clicks are never consumed here. WASD pans the pivot and marks the turn
/// as manually framed, so following stops until the next actor. Thin input adapter: holds only
/// camera tunables and pose, no game rules.
/// The rig reads <see cref="ViewPreferences.CombatCameraDistance"/> on _Ready and writes it back on
/// every wheel zoom, so the zoom survives a re-encounter within the session.
/// </summary>
public partial class OrbitCameraRig : Node3D, ICameraFocus
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

    /// <summary>How long the pivot takes to glide onto the unit whose turn starts.</summary>
    [Export] public float FocusSeconds { get; set; } = 0.35f;

    private Camera3D _camera = null!;
    private ShakePivot _shake = null!;
    private float _yaw;
    private float _pitch;
    private float _distance;
    private bool _middleDragging;
    private bool _rightHeld;
    private float _rightTravel;

    // Focus state: one tween owns global_position; a manual pan latches follow off for the turn.
    private Tween? _focusTween;
    private bool _userPanned;
    private Vector3? _turnTarget;
    private Vector3 _boardMin;
    private Vector3 _boardMax;
    private bool _hasBoard;

    public Camera3D Camera => _camera;

    /// <summary>
    /// The trauma-shake node the camera hangs off (rig &gt; ShakePivot &gt; Camera3D) — exposed so the
    /// presenter can add trauma on a crit or a death.
    /// </summary>
    public ShakePivot Shake => _shake;

    /// <summary>True while the player's pan has taken over framing for the current turn.</summary>
    public bool UserPanned => _userPanned;

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
    /// sewer both open as a full view. A distance the player chose earlier still wins. Also
    /// records the board rect every later focus is clamped to, and drops any glide still in
    /// flight from the previous encounter.
    /// </summary>
    public void FrameBoard(Vector3 worldPivot, int boardWidth, int boardHeight)
    {
        float framing = Mathf.Max(boardWidth, boardHeight) * FramingDistancePerTile;
        ZoomMax = Mathf.Max(ZoomMax, framing * ZoomOutFactor);
        _distance = ViewPreferences.HasStoredCombatCameraDistance
            ? Mathf.Clamp(ViewPreferences.CombatCameraDistance, ZoomMin, ZoomMax)
            : Mathf.Clamp(framing, ZoomMin, ZoomMax);
        KillFocus();
        _userPanned = false;
        _turnTarget = null;
        _boardMin = new Vector3(0f, 0f, 0f);
        _boardMax = new Vector3(boardWidth, 0f, boardHeight);
        _hasBoard = true;
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

    /// <inheritdoc/>
    public void FocusOn(Vector3 target, float seconds, bool turnStart)
    {
        if (turnStart)
        {
            _userPanned = false;
            _turnTarget = target;
        }
        else if (_userPanned)
        {
            return;
        }

        var to = ClampToBoard(target);
        KillFocus();
        if (seconds <= 0f)
        {
            GlobalPosition = to;
            return;
        }

        // Moving the pivot moves the camera with it: the camera's local offset and look basis are
        // fixed relative to the rig, so no pose update is needed (the WASD pan relies on the same).
        _focusTween = CreateTween();
        _focusTween.TweenProperty(this, "global_position", to, seconds)
            .SetTrans(turnStart ? Tween.TransitionType.Sine : Tween.TransitionType.Linear)
            .SetEase(Tween.EaseType.Out);
    }

    /// <summary>Glide back onto the unit whose turn it is (the C hotkey). No-op before the first turn.</summary>
    public void FocusOnActive()
    {
        if (_turnTarget is { } target) FocusOn(target, FocusSeconds, turnStart: true);
    }

    private Vector3 ClampToBoard(Vector3 target)
    {
        if (!_hasBoard) return target;
        return new Vector3(
            Mathf.Clamp(target.X, _boardMin.X, _boardMax.X),
            target.Y,
            Mathf.Clamp(target.Z, _boardMin.Z, _boardMax.Z));
    }

    private void KillFocus()
    {
        _focusTween?.Kill();
        _focusTween = null;
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

        Pan(pan.Normalized() * PanSpeed * (float)delta);
    }

    /// <summary>Manual pan by a screen-relative ground offset (X right, Y down). Takes framing away
    /// from the presenter's follow until the next turn start.</summary>
    public void Pan(Vector2 pan)
    {
        KillFocus();
        _userPanned = true;
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
