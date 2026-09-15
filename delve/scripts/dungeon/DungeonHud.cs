using System;
using System.Linq;
using Delve.Run;
using Godot;

namespace Delve.Dungeon;
public partial class DungeonHud : Control
{
    public event Action? RestPressed, StairsPressed, LayoutPicked, EntryPicked;
    public event Action<int>? RestartPressed, SizePicked;
    private Label _status = null!, _notice = null!;
    private Control _expedition = null!;
    private Label _wardValue = null!, _wardDanger = null!, _roomProgress = null!;
    private ProgressBar _wardBar = null!, _roomsBar = null!;
    private StyleBoxFlat _wardFill = null!;
    private LineEdit _seed = null!;
    private HBoxContainer _sizes = null!;
    private Button _rest = null!, _stairs = null!, _layout = null!, _entry = null!;
    private DungeonFloor? _floor;
    private RunState? _state;
    private bool _showRoomMap;
    public override void _Ready()
    {
        _status = GetNode<Label>("%Status");
        _notice = GetNode<Label>("%Notice");
        _expedition = GetNode<Control>("%Expedition");
        _wardValue = GetNode<Label>("%WardValue");
        _wardDanger = GetNode<Label>("%WardDanger");
        _roomProgress = GetNode<Label>("%RoomProgress");
        _wardBar = GetNode<ProgressBar>("%WardBar");
        _roomsBar = GetNode<ProgressBar>("%RoomsBar");
        _wardFill = (StyleBoxFlat)_wardBar.GetThemeStylebox("fill").Duplicate();
        _wardBar.AddThemeStyleboxOverride("fill", _wardFill);
        _seed = GetNode<LineEdit>("%Seed");
        _sizes = GetNode<HBoxContainer>("%Sizes");
        _rest = GetNode<Button>("%Rest");
        _stairs = GetNode<Button>("%Stairs");
        GetNode<Button>("%Restart").Pressed += () =>
        {
            if (int.TryParse(_seed.Text, out int seed))
                RestartPressed?.Invoke(seed);
        };
        GetNode<Button>("%NewSeed").Pressed += () => RestartPressed?.Invoke((int)(GD.Randi() & 0x7fffffff));
        _rest.Pressed += () => RestPressed?.Invoke();
        _stairs.Pressed += () => StairsPressed?.Invoke();
        foreach (int n in new[]
        {
            12,
            14,
            16
        }

        )
        {
            var b = new Button
            {
                Text = $"{n} × {n}"};
            _sizes.AddChild(b);
            b.Pressed += () => SizePicked?.Invoke(n);
        }

        _layout = new Button();
        _sizes.AddChild(_layout);
        _layout.Pressed += () => LayoutPicked?.Invoke();
        _entry = new Button();
        _sizes.AddChild(_entry);
        _entry.Pressed += () => EntryPicked?.Invoke();
    }

    public void SetDevelopmentControlsVisible(bool visible)
    {
        _seed.Visible = visible;
        GetNode<Button>("%Restart").Visible = visible;
        GetNode<Button>("%NewSeed").Visible = visible;
    }

    public void Render(DungeonFloor floor, RunState state, DungeonPhase phase, int seed, bool comparison, int size, bool openLayout, DoorSide entry)
    {
        _floor = floor;
        _state = state;
        _seed.Text = seed.ToString();
        _sizes.Visible = comparison;
        _layout.Text = openLayout ? "Layout: Open" : "Layout: Furnished";
        _entry.Text = $"Entry: {entry}";
        bool fighting = phase is DungeonPhase.Combat or DungeonPhase.Results or DungeonPhase.Transition;
        _showRoomMap = !fighting;
        _status.Visible = !fighting;
        _expedition.Visible = !fighting;
        GetNode<VBoxContainer>("%Top").Position = new Vector2(24, fighting ? 45 : 16);
        _notice.Visible = !fighting;
        int id = state.CurrentNodeId ?? 0;
        var room = floor.Rooms[id];
        _status.Text = $"Floor {state.Stratum + 1} | {StationPlan.Name(room.Purpose)}    •    Party level {state.Party.Level}    •    {state.Gold} gold";
        var ward = state.Wardstone;
        _wardValue.Text = $"{ward.Ward} / {ward.Rules.MaxWard}";
        _wardBar.MaxValue = ward.Rules.MaxWard;
        _wardBar.Value = ward.Ward;
        var color = new Color(ward.Upshift switch { 0 => "80d8c6", 1 => "e6cd82", 2 => "edaa68", _ => "ef827b" });
        _wardFill.BgColor = color;
        _wardValue.Modulate = color;
        _wardDanger.Modulate = color;
        _wardDanger.Text = ward.IsSpent ? "EXHAUSTED · Expedition ends"
            : ward.Upshift == 0 ? "Danger: normal"
            : $"Danger: +{ward.Upshift} {(ward.Upshift == 1 ? "tier" : "tiers")}";
        _expedition.TooltipText = $"Each doorway costs {ward.Rules.NodeBurn} ward, including backtracking.\nShort rests cost {ward.Rules.ShortRestBurn} ward. Zero ward ends the expedition.\nEncounter danger rises below {ward.Rules.SteadyAbove}, {ward.Rules.FirstShiftAbove}, and {ward.Rules.SecondShiftAbove} ward.\nCleared rooms stay cleared when you return.";
        int cleared = floor.Rooms.Count(r => r.Completed);
        _roomProgress.Text = $"Rooms cleared  {cleared}/{floor.Rooms.Count}";
        _roomsBar.MaxValue = floor.Rooms.Count;
        _roomsBar.Value = cleared;
        _rest.Text = $"Short rest −{ward.Rules.ShortRestBurn} ward";
        _notice.Text = phase switch
        {
            DungeonPhase.Travel => $"Crossing…  −{state.Wardstone.Rules.NodeBurn} ward",
            DungeonPhase.Doors => $"Click a character for details. Click a doorway to travel ({state.Wardstone.Rules.NodeBurn} ward).",
            DungeonPhase.Combat => comparison ? $"Guard hall comparison: {size} × {size}. Same seed and enemies; compare movement and congestion." : "Resolve the encounter to open the doors.",
            DungeonPhase.End => state.Outcome == RunOutcome.Victory ? "Floor complete. The stairs lead onward." : "The expedition ends. Restart or try a new seed.",
            _ => ""
        };
        _rest.Visible = phase == DungeonPhase.Doors;
        if (phase == DungeonPhase.Doors && CharacterPromotion.HasPending(state.Party))
            _notice.Text = "Promotion available: " + string.Join(", ", state.Party.Living()
                .Where(c => CharacterPromotion.For(c).PendingLevels(c) > 0).Select(c => c.Name))
                + ". Click a character to open their sheet before the next encounter.";
        _rest.Disabled = !state.Wardstone.CanAffordShortRest;
        _stairs.Text = state.OnFinalStratum ? "Complete expedition" : $"Descend to floor {state.Stratum + 2}";
        _stairs.Visible = phase == DungeonPhase.Doors && room.Family == RoomFamily.Guardian && room.Completed;
        QueueRedraw();
    }

    public void ShowNotice(string text) => _notice.Text = text;
    public override void _Draw()
    {
        if (!_showRoomMap || _floor == null || _state == null)
            return;
        var origin = new Vector2(Size.X - 185, 120);
        const float step = 38;
        foreach (var room in _floor.Rooms.Where(r => r.Discovered))
        {
            var p = origin + new Vector2(room.X, room.Y) * step;
            foreach (var d in room.Doors.Where(d => d.A == room.Id && _floor.Rooms[d.B].Discovered))
            {
                var b = _floor.Rooms[d.B];
                DrawLine(p, origin + new Vector2(b.X, b.Y) * step, new Color("829083"), 3);
            }

            DrawCircle(p, 8, room.Id == _state.CurrentNodeId ? new Color("efc584") : new Color("668477"));
        }
    }
}
