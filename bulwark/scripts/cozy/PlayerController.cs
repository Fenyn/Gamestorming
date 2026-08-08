using System;
using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// The player avatar: a CharacterBody3D that moves on the XZ ground plane and is DRAWN as a
/// billboarded 2D Mana Seed sprite (the same sheet + 4-direction facing rule as the combat token,
/// <see cref="Bulwark.Combat.UnitVisual3D"/>). Thin world adapter per CLAUDE.md — it reads input and
/// renders state, but every world mutation is forwarded to a <see cref="GameState"/> command. The
/// actionable decision lives in <see cref="TargetResolver"/> (pure, unchanged by the 3D pivot) and
/// the selection state in <see cref="ToolBelt"/>; this node only translates between them and the engine.
///
/// Grid contract: one world cell is ONE METRE. Cell (x, y) covers world X ∈ [x, x+1) and
/// Z ∈ [y, y+1); its centre is (x + 0.5, 0, y + 0.5). Facing is still a grid-space
/// <see cref="Vector2I"/> whose Y component runs along world Z (+Z = south, toward the camera).
///
/// Controls: WASD / arrows move. 1-6 select a tool slot directly, Tab / mouse wheel cycle the tool,
/// Q cycles the selected seed. E, LMB and RMB all interact/use the active tool on the targeted cell
/// (the hovered cell under the cursor when adjacent, else the cell in front of you, else the tile you
/// stand on), and — with the Hand tool — sleep when at the bedroll. Mouse input is read in
/// _UnhandledInput so clicks/scrolls consumed by UI buttons never leak into the world.
///
/// Camera: a follow arm (%CameraPivot → %Camera) that tracks the avatar with smoothing; the arm's
/// 40° downward pitch is authored on %CameraPivot in player.tscn, shared by the outpost and territories
/// (much below 40° and the camera sees over the map's perimeter into empty sky);
/// <see cref="Bulwark.Settings.ViewPreferences.CozyZoom"/> maps to the arm's DISTANCE through
/// <see cref="SetCameraZoom"/> (higher zoom = closer), the 3D equivalent of the old Camera2D zoom.
/// </summary>
public partial class PlayerController : CharacterBody3D
{
    /// <summary>Direct-select actions in hotbar slot order (index i selects ToolBelt slot i).</summary>
    private static readonly string[] ToolSelectActions =
    {
        "select_tool_1", "select_tool_2", "select_tool_3",
        "select_tool_4", "select_tool_5", "select_tool_6",
    };

    /// <summary>Camera arm length at <see cref="Bulwark.Settings.ViewPreferences.ZoomDefault"/>-relative
    /// zoom 1. Divided by the zoom factor, so zoom 2 (the default) sits at half this distance.</summary>
    [Export] public float CameraBaseDistance { get; set; } = 28f;

    /// <summary>How fast the follow camera catches up with the avatar (units of 1/second).</summary>
    [Export] public float CameraFollowSpeed { get; set; } = 8f;

    /// <summary>Free-movement speed in metres/second (≈3 cells/s — a brisk Stardew walk).</summary>
    [Export] public float Speed { get; set; } = 3.2f;

    private Sprite3D _sprite = null!;
    private Node3D? _cameraPivot;
    private Camera3D? _camera;
    private MeshInstance3D? _highlight;

    private OutpostScene? _outpost;
    private Area3D? _bedroll;
    private Vector2I _bedrollCell;

    private readonly ToolBelt _tools = new();
    public ToolBelt Tools => _tools;

    /// <summary>The follow camera (null in an F6 run whose scene has no %Camera). Exposed so world
    /// scenes and cutscene staging can read the view basis.</summary>
    public Camera3D? Camera => _camera;

    /// <summary>Current facing direction as a grid-space unit vector (kept when idle) — exposed so the
    /// world scene's interaction-hint proximity check can mirror <see cref="TrySleepAtBedroll"/>'s
    /// exact cell math without duplicating the cached facing state.</summary>
    public Vector2I FacingDirection => _facingDir;

    /// <summary>Raised when the player Hand-interacts at the bedroll; the scene runs the sleep flow.</summary>
    public event Action? SleepRequested;

    /// <summary>
    /// Raised on every interact press with the active tool, BEFORE any farm/bedroll handling.
    /// World scenes without farm plots (territories) consume this to resolve proximity
    /// interactions (resource nodes); the outpost ignores it.
    /// </summary>
    public event Action<ToolKind>? InteractRequested;

    /// <summary>
    /// Raised when a farm action was rejected because the WORLD disallows the cell (non-farmable
    /// or occupied ground) — the scene turns it into a subtle toast. Rule-level failures that are
    /// silent in Stardew (re-tilling tilled soil, wrong season, no seed) do not raise it.
    /// </summary>
    public event Action<string>? ActionRejected;

    // Facing row (0=S, 1=N, 2=E, 3=W) and its grid-space unit vector. Kept when idle.
    private int _facingRow;
    private Vector2I _facingDir = new(0, 1); // start facing South (+Z, toward the camera)

    private float _animTimer;
    private int _animFrame;
    private bool _moving;
    private float _cameraDistance = 14f;

    private TargetResolver.Target _target;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite3D>("%Sprite");
        _sprite.Frame = _facingRow * ManaSeedSheet.Columns;

        _cameraPivot = GetNodeOrNull<Node3D>("%CameraPivot");
        _camera = GetNodeOrNull<Camera3D>("%Camera");
        _highlight = GetNodeOrNull<MeshInstance3D>("%TargetHighlight");

        // The arm follows in WORLD space (smoothed) rather than rigidly inheriting the avatar's
        // transform, and the highlight is placed at an arbitrary world cell — both must be top-level.
        if (_cameraPivot != null)
        {
            _cameraPivot.TopLevel = true;
            _cameraPivot.GlobalPosition = GlobalPosition;
        }
        if (_highlight != null)
        {
            _highlight.TopLevel = true;
            _highlight.Visible = false;
        }
        ApplyCameraDistance();

        var gs = GameState.Instance;
        if (gs != null)
        {
            RefreshSeeds();
            gs.InventoryChanged += OnInventoryChanged;
        }
    }

    public override void _ExitTree()
    {
        var gs = GameState.Instance;
        if (gs != null)
            gs.InventoryChanged -= OnInventoryChanged;
    }

    /// <summary>Injected by <see cref="OutpostScene"/> after instancing: world queries + bedroll.</summary>
    public void Setup(OutpostScene outpost, Area3D? bedroll)
    {
        _outpost = outpost;
        _bedroll = bedroll;
        if (outpost != null && bedroll != null)
            _bedrollCell = outpost.WorldToCell(bedroll.GlobalPosition);
    }

    /// <summary>Session zoom preference → follow-arm distance (Godot-2D semantics preserved: a HIGHER
    /// zoom means CLOSER). Safe before _Ready — the distance is re-applied there.</summary>
    public void SetCameraZoom(float zoom)
    {
        _cameraDistance = CameraBaseDistance / Mathf.Max(zoom, 0.25f);
        ApplyCameraDistance();
    }

    private void ApplyCameraDistance()
    {
        if (_camera != null)
            _camera.Position = new Vector3(0f, 0f, _cameraDistance);
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 input = new(
            Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left"),
            Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up"));
        if (input.LengthSquared() > 1f)
            input = input.Normalized();

        // Screen down (+Y of the input vector) is world +Z with the fixed cozy camera yaw.
        // A small constant sink keeps the capsule seated on the authored floor collider.
        Velocity = new Vector3(input.X * Speed, -1f, input.Y * Speed);
        MoveAndSlide();

        _moving = input.LengthSquared() > 0.01f;
        if (_moving)
            UpdateFacing(input);

        UpdateAnimation(delta);
        RecomputeTarget();
        UpdateHighlight();
    }

    public override void _Process(double delta)
    {
        UpdateCameraFollow(delta);

        if (Input.IsActionJustPressed("cycle_tool"))
            _tools.CycleTool();
        if (Input.IsActionJustPressed("cycle_seed"))
            _tools.CycleSeed();
        if (Input.IsActionJustPressed("interact"))
            DoInteract();

        for (int i = 0; i < ToolSelectActions.Length; i++)
            if (Input.IsActionJustPressed(ToolSelectActions[i]))
                _tools.SelectTool(i);
    }

    /// <summary>
    /// Mouse controls (unhandled only, so UI-consumed clicks never reach the world): LMB/RMB
    /// interact with the active tool (aliases of E through the same seam), wheel cycles the hotbar
    /// (down = next, up = previous). The cozy camera never zooms with the wheel — zoom is HUD
    /// buttons only.
    /// </summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is not InputEventMouseButton mb || !mb.Pressed)
            return;

        switch (mb.ButtonIndex)
        {
            case MouseButton.Left:
            case MouseButton.Right:
                DoInteract();
                GetViewport().SetInputAsHandled();
                break;
            case MouseButton.WheelDown:
                _tools.CycleTool();
                GetViewport().SetInputAsHandled();
                break;
            case MouseButton.WheelUp:
                _tools.CycleToolBack();
                GetViewport().SetInputAsHandled();
                break;
        }
    }

    // ------------------------------------------------------------------ Movement / animation / camera

    private void UpdateCameraFollow(double delta)
    {
        if (_cameraPivot == null)
            return;
        float t = Mathf.Clamp((float)delta * CameraFollowSpeed, 0f, 1f);
        _cameraPivot.GlobalPosition = _cameraPivot.GlobalPosition.Lerp(GlobalPosition, t);
    }

    private void UpdateFacing(Vector2 v)
    {
        if (Mathf.Abs(v.X) >= Mathf.Abs(v.Y))
        {
            if (v.X >= 0f) { _facingRow = ManaSeedSheet.RowEast; _facingDir = new Vector2I(1, 0); }
            else { _facingRow = ManaSeedSheet.RowWest; _facingDir = new Vector2I(-1, 0); }
        }
        else
        {
            if (v.Y >= 0f) { _facingRow = ManaSeedSheet.RowSouth; _facingDir = new Vector2I(0, 1); }
            else { _facingRow = ManaSeedSheet.RowNorth; _facingDir = new Vector2I(0, -1); }
        }
    }

    /// <summary>
    /// Pick the sheet row from the logical facing AS SEEN THROUGH THE CAMERA (the same rule as
    /// <see cref="Bulwark.Combat.UnitVisual3D.ApplyFacingFrame"/>): the dominant screen axis wins,
    /// so the avatar still reads "toward/away/left/right" if the view ever yaws. With no camera the
    /// grid facing row is used verbatim.
    /// </summary>
    private int ScreenFacingRow()
    {
        if (_camera == null || !IsInstanceValid(_camera))
            return _facingRow;

        Basis basis = _camera.GlobalBasis;
        Vector3 fwd = -basis.Z; fwd.Y = 0f;
        fwd = fwd.LengthSquared() > 0.0001f ? fwd.Normalized() : Vector3.Forward;
        Vector3 right = basis.X; right.Y = 0f;
        right = right.LengthSquared() > 0.0001f ? right.Normalized() : Vector3.Right;

        var facing = new Vector3(_facingDir.X, 0f, _facingDir.Y);
        if (facing.LengthSquared() < 0.0001f)
            facing = Vector3.Back;
        facing = facing.Normalized();

        float sx = facing.Dot(right);   // + = screen right
        float sy = facing.Dot(fwd);     // + = into the screen (away from the viewer)
        return Mathf.Abs(sx) >= Mathf.Abs(sy)
            ? (sx >= 0f ? ManaSeedSheet.RowEast : ManaSeedSheet.RowWest)
            : (sy >= 0f ? ManaSeedSheet.RowNorth : ManaSeedSheet.RowSouth);
    }

    private void UpdateAnimation(double delta)
    {
        int row = ScreenFacingRow();
        if (_moving)
        {
            _animTimer += (float)delta;
            if (_animTimer >= ManaSeedSheet.WalkFrameTime)
            {
                _animTimer -= ManaSeedSheet.WalkFrameTime;
                _animFrame = (_animFrame + 1) % ManaSeedSheet.WalkFrames;
            }
            _sprite.Frame = (ManaSeedSheet.WalkRowOffset + row) * ManaSeedSheet.Columns + _animFrame;
        }
        else
        {
            _animFrame = 0;
            _animTimer = 0f;
            _sprite.Frame = row * ManaSeedSheet.Columns; // stand frame at column 0
        }
    }

    // ------------------------------------------------------------------ Targeting / interaction

    private void RecomputeTarget()
    {
        var gs = GameState.Instance;
        if (_outpost == null || gs == null)
        {
            _target = default;
            return;
        }

        Vector2I playerCell = _outpost.WorldToCell(GlobalPosition);
        Vector2I? hoveredCell = CursorCell();
        _target = TargetResolver.Resolve(
            _tools.Current, playerCell, _facingDir, _tools.SelectedSeed, gs.Clock.Season,
            _outpost.IsTillable, gs.Farm.GetPlot, gs.Inventory.Count, hoveredCell);
    }

    /// <summary>The grid cell under the mouse cursor: the camera ray intersected with the ground
    /// plane (y = 0). Null when there is no camera or the ray runs parallel to / away from the
    /// ground (then <see cref="TargetResolver"/> falls back to the faced/standing cell).</summary>
    private Vector2I? CursorCell()
    {
        if (_camera == null || !IsInstanceValid(_camera) || _outpost == null)
            return null;

        Vector2 mouse = GetViewport().GetMousePosition();
        Vector3 from = _camera.ProjectRayOrigin(mouse);
        Vector3 dir = _camera.ProjectRayNormal(mouse);
        if (Mathf.Abs(dir.Y) < 0.0001f)
            return null;

        float t = -from.Y / dir.Y;
        if (t <= 0f)
            return null;
        return _outpost.WorldToCell(from + dir * t);
    }

    /// <summary>Move the target-cell quad onto the actionable cell (replaces the old _Draw rect).</summary>
    private void UpdateHighlight()
    {
        if (_highlight == null)
            return;

        bool show = _outpost != null && _target.CanAct;
        _highlight.Visible = show;
        if (show)
            _highlight.GlobalPosition = _outpost!.CellToWorld(_target.Cell) + new Vector3(0f, 0.04f, 0f);
    }

    private void DoInteract()
    {
        InteractRequested?.Invoke(_tools.Current);

        var gs = GameState.Instance;
        if (gs == null || _outpost == null)
            return; // no farm world injected (e.g. a territory scene) — proximity handling only

        Vector2I cell = _target.Cell;
        switch (_tools.Current)
        {
            case ToolKind.Hoe:
                // World-level rejection (non-farmable / occupied cell) gets the subtle toast;
                // rule-level failures (already tilled) stay silent, like Stardew.
                if (!gs.TillPlot(cell) && !_outpost.IsTillable(cell))
                    ActionRejected?.Invoke("Can't till here");
                break;
            case ToolKind.WateringCan:
                gs.WaterPlot(cell);
                break;
            case ToolKind.Seeds:
                ItemDefinition? seed = _tools.SelectedSeed;
                if (seed?.CropId != null && !gs.PlantCrop(cell, seed.CropId)
                    && (gs.Farm.GetPlot(cell)?.Stage ?? PlotStage.Untilled) == PlotStage.Untilled)
                    ActionRejected?.Invoke("Can't plant here"); // no tilled soil under the cursor
                break;
            case ToolKind.Hand:
                // Bedroll first (sleep); otherwise harvest a mature crop.
                if (!TrySleepAtBedroll())
                    gs.HarvestPlot(cell);
                break;
        }
    }

    /// <summary>Sleep when standing on, or facing, the bedroll cell.</summary>
    private bool TrySleepAtBedroll()
    {
        if (_bedroll == null || _outpost == null)
            return false;

        Vector2I self = _outpost.WorldToCell(GlobalPosition);
        Vector2I faced = self + _facingDir;
        if (self == _bedrollCell || faced == _bedrollCell)
        {
            SleepRequested?.Invoke();
            return true;
        }
        return false;
    }

    private void OnInventoryChanged(string itemId) => RefreshSeeds();

    private void RefreshSeeds()
    {
        var inv = GameState.Instance?.Inventory;
        if (inv == null)
            return;

        var held = new List<ItemDefinition>();
        foreach (ItemDefinition item in Items.All)
            if (item.Category == ItemCategory.Seed && inv.Count(item.Id) > 0)
                held.Add(item);
        held.Sort((a, b) => string.CompareOrdinal(a.Id, b.Id));

        _tools.RefreshSeeds(held);
    }
}
