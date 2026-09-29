using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;

/// <summary>
/// The floor as the party has seen it: visited rooms with their kind, and the unvisited rooms
/// beyond their doors as "?". Nothing further is shown, so the next door stays a choice made on
/// what the party has learned (Darkest Dungeon's map before scouting).
/// </summary>
public partial class FloorPlan : Control
{
    [Export] public Vector2 CellSize { get; set; } = new(64, 48);
    [Export] public float Gap { get; set; } = 22;
    [Export] public float IconSize { get; set; } = 30;
    [Export] public float WalkedLinkWidth { get; set; } = 4;
    [Export] public float LinkWidth { get; set; } = 3;
    [Export] public float CurrentFrameWidth { get; set; } = 3;
    [Export] public float UnseenDotRadius { get; set; } = 3;

    /// <summary>Icon alpha for a visited room that is finished.</summary>
    [Export] public float ClearedAlpha { get; set; } = 0.5f;

    [Export] public Texture2D Entrance { get; set; } = null!;
    [Export] public Texture2D Fight { get; set; } = null!;
    [Export] public Texture2D Event { get; set; } = null!;
    [Export] public Texture2D Lair { get; set; } = null!;
    [Export] public Texture2D Wayfarer { get; set; } = null!;
    [Export] public Texture2D Refuge { get; set; } = null!;
    [Export] public Texture2D Guardian { get; set; } = null!;
    [Export] public Texture2D Unknown { get; set; } = null!;

    /// <summary>A room next to the current one was clicked; the director travels there.</summary>
    public event System.Action<int>? CellPressed;

    /// <summary>The pointer moved onto a room next to the current one, or off it (null).</summary>
    public event System.Action<int?>? CellHovered;

    private int? _hoveredRoom;

    private DungeonFloor? _floor;
    private RunState? _state;
    private int _columns, _rows;
    private int? _focusedRoom;

    /// <summary>The room behind the door the player is considering, framed like a focused button.</summary>
    public int? FocusedRoom
    {
        get => _focusedRoom;
        set
        {
            if (value == _focusedRoom) return;
            _focusedRoom = value;
            QueueRedraw();
        }
    }

    public override void _GuiInput(InputEvent e)
    {
        if (_floor == null || _state == null) return;
        if (e is InputEventMouseMotion motion)
        {
            var over = NeighbourAt(motion.Position);
            MouseDefaultCursorShape = over == null ? CursorShape.Arrow : CursorShape.PointingHand;
            SetHovered(over);
        }
        else if (e is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left } click && NeighbourAt(click.Position) is { } target)
        {
            AcceptEvent();
            CellPressed?.Invoke(target);
        }
    }

    public override void _Notification(int what)
    {
        if (what == NotificationMouseExit) SetHovered(null);
    }

    private void SetHovered(int? room)
    {
        if (room == _hoveredRoom) return;
        _hoveredRoom = room;
        CellHovered?.Invoke(room);
    }

    /// <summary>The room under a point, when a door leads there from the current room.</summary>
    private int? NeighbourAt(Vector2 point)
    {
        int current = _state!.CurrentNodeId ?? _floor!.EntranceId;
        var room = _floor!.Rooms.FirstOrDefault(r => Cell(r).HasPoint(point) && r.Doors.Any(d => d.Other(r.Id) == current));
        return room?.Id;
    }

    public void Render(DungeonFloor floor, RunState state)
    {
        _floor = floor;
        _state = state;
        _columns = floor.Rooms.Max(r => r.X) + 1;
        _rows = floor.Rooms.Max(r => r.Y) + 1;
        CustomMinimumSize = new Vector2(_columns * CellSize.X + (_columns - 1) * Gap, _rows * CellSize.Y + (_rows - 1) * Gap);
        QueueRedraw();
    }

    /// <summary>Visited or scouted rooms, and every room one door away from a visited room.</summary>
    public static bool Shown(DungeonFloor floor, DungeonRoom room)
        => room.Discovered || room.Scouted || room.Doors.Any(d => floor.Rooms[d.Other(room.Id)].Discovered);

    /// <summary>The icon key a room shows: its kind once visited or scouted, else unknown.</summary>
    public static string IconKey(DungeonFloor floor, RunState state, DungeonRoom room)
    {
        if (!room.Discovered && !room.Scouted) return "unknown";
        if (room.Id == floor.EntranceId) return "entrance";
        return state.Map.Nodes[room.Id].Kind switch
        {
            NodeKind.Combat => "fight",
            NodeKind.Elite => "lair",
            NodeKind.Meeting => "wayfarer",
            NodeKind.Rest => "refuge",
            NodeKind.Boss => "guardian",
            _ => "event",
        };
    }

    private Texture2D Icon(string key) => key switch
    {
        "entrance" => Entrance,
        "fight" => Fight,
        "lair" => Lair,
        "wayfarer" => Wayfarer,
        "refuge" => Refuge,
        "guardian" => Guardian,
        "event" => Event,
        _ => Unknown,
    };

    private Rect2 Cell(DungeonRoom room)
        => new(new Vector2(room.X * (CellSize.X + Gap), room.Y * (CellSize.Y + Gap)), CellSize);

    /// <summary>Draw in dark ink for a parchment frame instead of the bone-on-slate HUD colours.</summary>
    [Export] public bool OnParchment { get; set; }

    private Color Strong => OnParchment ? UiColors.ParchmentInk : UiColors.Accent;
    private Color Faint => OnParchment ? UiColors.ParchmentLine : UiColors.Line;
    private Color CellFill => OnParchment ? UiColors.ParchmentCell : UiColors.Inset;
    private Color CellHot => OnParchment ? UiColors.ParchmentCellHot : UiColors.Surface;
    // The party's room wears the ward colour, the one hue on the parchment, so it reads at a glance.
    private Color Current => OnParchment ? UiColors.Ward : UiColors.Focus;
    private Color Dim => OnParchment ? UiColors.ParchmentDim : UiColors.TextDim;

    public override void _Draw()
    {
        if (_floor == null || _state == null) return;
        var shown = _floor.Rooms.Where(r => Shown(_floor, r)).ToHashSet();
        // Unseen rooms keep a faint slot, so the floor's size reads without its contents.
        foreach (var room in _floor.Rooms.Where(r => !shown.Contains(r)))
            DrawCircle(Cell(room).GetCenter(), UnseenDotRadius, Faint);
        foreach (var room in shown)
            foreach (var door in room.Doors.Where(d => d.A == room.Id))
            {
                var other = _floor.Rooms[door.B];
                if (!shown.Contains(other)) continue;
                bool walked = room.Discovered && other.Discovered;
                DrawLine(Cell(room).GetCenter(), Cell(other).GetCenter(), walked ? Strong : Faint,
                    walked ? WalkedLinkWidth : LinkWidth);
            }
        foreach (var room in shown)
        {
            var cell = Cell(room);
            bool current = room.Id == _state.CurrentNodeId;
            bool focused = room.Id == _focusedRoom;
            DrawRect(cell, current || focused ? CellHot : CellFill);
            DrawRect(cell, current || focused ? Current : room.Discovered ? Strong : Faint, false,
                current || focused ? CurrentFrameWidth : 1);
            var tint = room.Discovered || room.Scouted ? Strong : Dim;
            if (room.Completed && !current) tint = tint with { A = ClearedAlpha };
            var icon = new Rect2(cell.GetCenter() - Vector2.One * IconSize / 2, Vector2.One * IconSize);
            DrawTextureRect(Icon(IconKey(_floor, _state, room)), icon, false, tint);
        }
    }

    /// <summary>The floor's words for room names in the tooltips.</summary>
    public CrawlWords Words { get; set; } = CrawlWordsTable.For("station");

    public override string _GetTooltip(Vector2 atPosition)
    {
        if (_floor == null || _state == null) return "";
        var room = _floor.Rooms.FirstOrDefault(r => Shown(_floor, r) && Cell(r).HasPoint(atPosition));
        if (room == null) return "";
        if (!room.Discovered) return room.Scouted ? $"{Words.Name(room.Purpose)}\nScouted, not visited" : Words.UnexploredTitle;
        string status = room.Id == _state.CurrentNodeId ? "You are here" : room.Completed ? "Cleared" : "Visited";
        return $"{Words.Name(room.Purpose)}\n{status}";
    }

    /// <summary>What the plan shows, for spikes: room id to icon key, for every drawn room.</summary>
    public IReadOnlyDictionary<int, string> Drawn()
        => _floor == null || _state == null ? new Dictionary<int, string>()
            : _floor.Rooms.Where(r => Shown(_floor, r)).ToDictionary(r => r.Id, r => IconKey(_floor, _state, r));
}
