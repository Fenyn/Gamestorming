using System;
using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// The player avatar: a CharacterBody2D with 8-way free movement, 4-direction Mana Seed sprite
/// facing, and tool/interaction input. Thin world adapter per CLAUDE.md — it reads input and renders
/// state, but every world mutation is forwarded to a <see cref="GameState"/> command. The actionable
/// decision lives in <see cref="TargetResolver"/> and the selection state in <see cref="ToolBelt"/>;
/// this node only translates between them and the engine.
///
/// Controls: WASD / arrows move. 1-6 select a tool slot directly, Tab / mouse wheel cycle the tool,
/// Q cycles the selected seed. E, LMB and RMB all interact/use the active tool on the targeted cell
/// (the hovered cell when adjacent, else the cell in front of you, else the tile you stand on), and
/// — with the Hand tool — sleep when at the bedroll. Mouse input is read in _UnhandledInput so
/// clicks/scrolls consumed by UI buttons never leak into the world.
/// </summary>
public partial class PlayerController : CharacterBody2D
{
    /// <summary>Direct-select actions in hotbar slot order (index i selects ToolBelt slot i).</summary>
    private static readonly string[] ToolSelectActions =
    {
        "select_tool_1", "select_tool_2", "select_tool_3",
        "select_tool_4", "select_tool_5", "select_tool_6",
    };
    private const int TileSize = 48;

    /// <summary>Free-movement speed in pixels/second.</summary>
    [Export] public float Speed { get; set; } = 140f;

    private Sprite2D _sprite = null!;

    private OutpostScene? _outpost;
    private Area2D? _bedroll;
    private Vector2I _bedrollCell;

    private readonly ToolBelt _tools = new();
    public ToolBelt Tools => _tools;

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
    private Vector2I _facingDir = new(0, 1); // start facing South (toward the camera)

    private float _animTimer;
    private int _animFrame;
    private bool _moving;

    private TargetResolver.Target _target;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite2D>("%Sprite");
        _sprite.Frame = _facingRow * ManaSeedSheet.Columns;

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
    public void Setup(OutpostScene outpost, Area2D? bedroll)
    {
        _outpost = outpost;
        _bedroll = bedroll;
        if (outpost != null && bedroll != null)
            _bedrollCell = outpost.WorldToCell(bedroll.GlobalPosition);
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 input = new(
            Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left"),
            Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up"));
        if (input.LengthSquared() > 1f)
            input = input.Normalized();

        Velocity = input * Speed;
        MoveAndSlide();

        _moving = input.LengthSquared() > 0.01f;
        if (_moving)
            UpdateFacing(input);

        UpdateAnimation(delta);
        RecomputeTarget();
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
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

    // ------------------------------------------------------------------ Movement / animation

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

    private void UpdateAnimation(double delta)
    {
        if (_moving)
        {
            _animTimer += (float)delta;
            if (_animTimer >= ManaSeedSheet.WalkFrameTime)
            {
                _animTimer -= ManaSeedSheet.WalkFrameTime;
                _animFrame = (_animFrame + 1) % ManaSeedSheet.WalkFrames;
            }
            _sprite.Frame = (ManaSeedSheet.WalkRowOffset + _facingRow) * ManaSeedSheet.Columns + _animFrame;
        }
        else
        {
            _animFrame = 0;
            _animTimer = 0f;
            _sprite.Frame = _facingRow * ManaSeedSheet.Columns; // stand frame at column 0
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
        Vector2I hoveredCell = _outpost.WorldToCell(GetGlobalMousePosition());
        _target = TargetResolver.Resolve(
            _tools.Current, playerCell, _facingDir, _tools.SelectedSeed, gs.Clock.Season,
            _outpost.IsTillable, gs.Farm.GetPlot, gs.Inventory.Count, hoveredCell);
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

    /// <summary>Sleep when standing on, or facing, the bedroll tile.</summary>
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

    // ------------------------------------------------------------------ Highlight

    public override void _Draw()
    {
        if (_outpost == null || !_target.CanAct)
            return;

        Vector2 center = ToLocal(_outpost.CellToWorld(_target.Cell));
        var rect = new Rect2(center - new Vector2(TileSize / 2f, TileSize / 2f), new Vector2(TileSize, TileSize));
        DrawRect(rect, new Color(0.6f, 0.9f, 0.4f, 0.16f), filled: true);
        DrawRect(rect, new Color(0.72f, 1f, 0.5f, 0.7f), filled: false, width: 2f);
    }
}
