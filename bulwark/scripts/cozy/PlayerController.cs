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
/// Controls: WASD / arrows move. Tab cycles the tool (Hoe → Watering Can → Seeds → Hand). Q cycles
/// the selected seed. E interacts with the cell in front of you (or the tile you stand on as a
/// fallback), and — with the Hand tool — sleeps when at the bedroll.
/// </summary>
public partial class PlayerController : CharacterBody2D
{
    // --- Mana Seed page-1 sheet: 8x8 grid of 64x64 cells. Rows 0-3 = stand S/N/E/W (col 0);
    // rows 4-7 = 6-frame walk in the same order (cols 0-5). ---
    private const int SheetColumns = 8;
    private const int WalkRowOffset = 4;
    private const int WalkFrames = 6;
    private const float WalkFrameTime = 0.135f;

    private const int TileSize = 48;

    /// <summary>Free-movement speed in pixels/second.</summary>
    [Export] public float Speed { get; set; } = 140f;

    private Sprite2D _sprite = null!;

    private OutpostScene? _outpost;
    private Area2D? _bedroll;
    private Vector2I _bedrollCell;

    private readonly ToolBelt _tools = new();
    public ToolBelt Tools => _tools;

    /// <summary>Raised when the player Hand-interacts at the bedroll; the scene runs the sleep flow.</summary>
    public event Action? SleepRequested;

    /// <summary>
    /// Raised on every interact press with the active tool, BEFORE any farm/bedroll handling.
    /// World scenes without farm plots (territories) consume this to resolve proximity
    /// interactions (resource nodes); the outpost ignores it.
    /// </summary>
    public event Action<ToolKind>? InteractRequested;

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
        _sprite.Frame = _facingRow * SheetColumns;

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
    }

    // ------------------------------------------------------------------ Movement / animation

    private void UpdateFacing(Vector2 v)
    {
        if (Mathf.Abs(v.X) >= Mathf.Abs(v.Y))
        {
            if (v.X >= 0f) { _facingRow = 2; _facingDir = new Vector2I(1, 0); }   // East
            else { _facingRow = 3; _facingDir = new Vector2I(-1, 0); }            // West
        }
        else
        {
            if (v.Y >= 0f) { _facingRow = 0; _facingDir = new Vector2I(0, 1); }   // South
            else { _facingRow = 1; _facingDir = new Vector2I(0, -1); }            // North
        }
    }

    private void UpdateAnimation(double delta)
    {
        if (_moving)
        {
            _animTimer += (float)delta;
            if (_animTimer >= WalkFrameTime)
            {
                _animTimer -= WalkFrameTime;
                _animFrame = (_animFrame + 1) % WalkFrames;
            }
            _sprite.Frame = (WalkRowOffset + _facingRow) * SheetColumns + _animFrame;
        }
        else
        {
            _animFrame = 0;
            _animTimer = 0f;
            _sprite.Frame = _facingRow * SheetColumns; // stand frame at column 0
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
        _target = TargetResolver.Resolve(
            _tools.Current, playerCell, _facingDir, _tools.SelectedSeed, gs.Clock.Season,
            _outpost.IsFarmable, gs.Farm.GetPlot, gs.Inventory.Count);
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
                gs.TillPlot(cell);
                break;
            case ToolKind.WateringCan:
                gs.WaterPlot(cell);
                break;
            case ToolKind.Seeds:
                ItemDefinition? seed = _tools.SelectedSeed;
                if (seed?.CropId != null)
                    gs.PlantCrop(cell, seed.CropId);
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
