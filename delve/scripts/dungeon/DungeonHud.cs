using System;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;
public partial class DungeonHud : Control
{
    public event Action? RestPressed, CampPressed, PotionPressed, StairsPressed, JournalPressed, PartyPressed, LayoutPicked, EntryPicked;
    public event Action<int>? RestartPressed, SizePicked;

    /// <summary>Time the ward bar takes to slide to a new value.</summary>
    [Export] public double WardTweenSeconds { get; set; } = 0.4;

    /// <summary>Scale the Wardstone panel pulses to when the ward changes.</summary>
    [Export] public float WardPulseScale { get; set; } = 1.04f;

    [Export] public double WardPulseSeconds { get; set; } = 0.2;

    /// <summary>Room name card: fade in, hold, fade out.</summary>
    [Export] public double RoomCardIn { get; set; } = 0.25;

    [Export] public double RoomCardHold { get; set; } = 1.2;
    [Export] public double RoomCardOut { get; set; } = 0.4;

    /// <summary>Hold for a card with a detail line, long enough to read three sentences.</summary>
    [Export] public double RoomCardDetailHold { get; set; } = 6;

    /// <summary>Plays HUD beats at zero length, for spikes and autoplay.</summary>
    public bool Instant { get; set; }

    private ThresholdTicks _wardTicks = null!;
    private Control _roomCard = null!;
    private Label _roomCardTitle = null!, _roomCardDetail = null!, _roomCardKicker = null!;
    private Tween? _wardTween, _cardTween;
    private int _shownWard = -1;
    private Label _notice = null!;
    private Control _expedition = null!;
    private Label _wardValue = null!, _wardDanger = null!, _roomProgress = null!;
    private ProgressBar _wardBar = null!;
    private StyleBoxFlat _wardFill = null!;
    private LineEdit _seed = null!;
    private HBoxContainer _sizes = null!;
    private CaptionButton _rest = null!, _camp = null!, _potion = null!, _stairs = null!;
    private Button _layout = null!, _entry = null!;
    private DungeonFloor? _floor;
    private RunState? _state;
    private FloorPlan _floorPlan = null!;
    private Control _plan = null!;
    private Label _planTitle = null!, _planGoal = null!;
    private Control _prompts = null!, _menuBar = null!, _pack = null!;
    private Label _goldValue = null!;

    public override void _Ready()
    {
        _notice = GetNode<Label>("%Notice");
        _expedition = GetNode<Control>("%Expedition");
        _wardValue = GetNode<Label>("%WardValue");
        _wardDanger = GetNode<Label>("%WardDanger");
        _roomProgress = GetNode<Label>("%RoomProgress");
        _wardBar = GetNode<ProgressBar>("%WardBar");
        _wardFill = (StyleBoxFlat)_wardBar.GetThemeStylebox("fill").Duplicate();
        _wardBar.AddThemeStyleboxOverride("fill", _wardFill);
        _wardTicks = GetNode<ThresholdTicks>("%WardTicks");
        _roomCard = GetNode<Control>("%RoomCard");
        _roomCardTitle = GetNode<Label>("%RoomCardTitle");
        _roomCardDetail = GetNode<Label>("%RoomCardDetail");
        _roomCardKicker = GetNode<Label>("%RoomCardKicker");
        _floorPlan = GetNode<FloorPlan>("%FloorPlan");
        _plan = GetNode<Control>("%Plan");
        _planTitle = GetNode<Label>("%PlanTitle");
        _planGoal = GetNode<Label>("%PlanGoal");
        _prompts = GetNode<Control>("%Prompts");
        _menuBar = GetNode<Control>("%MenuBar");
        _pack = GetNode<Control>("%Pack");
        _goldValue = GetNode<Label>("%GoldValue");
        HideRoomCard();
        _seed = GetNode<LineEdit>("%Seed");
        _sizes = GetNode<HBoxContainer>("%Sizes");
        _rest = GetNode<CaptionButton>("%Rest");
        _stairs = GetNode<CaptionButton>("%Stairs");
        GetNode<Button>("%Restart").Pressed += () =>
        {
            if (int.TryParse(_seed.Text, out int seed))
                RestartPressed?.Invoke(seed);
        };
        GetNode<Button>("%NewSeed").Pressed += () => RestartPressed?.Invoke((int)(GD.Randi() & 0x7fffffff));
        _rest.Pressed += () => RestPressed?.Invoke();
        _camp = GetNode<CaptionButton>("%Camp");
        _camp.Pressed += () => CampPressed?.Invoke();
        _potion = GetNode<CaptionButton>("%Potion");
        _potion.Pressed += () => PotionPressed?.Invoke();
        _stairs.Pressed += () => StairsPressed?.Invoke();
        GetNode<Button>("%JournalRow").Pressed += () => JournalPressed?.Invoke();
        GetNode<Button>("%PartyRow").Pressed += () => PartyPressed?.Invoke();
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
        ReadyParty();
    }

    public void SetDevelopmentControlsVisible(bool visible)
    {
        _seed.Visible = visible;
        GetNode<Button>("%Restart").Visible = visible;
        GetNode<Button>("%NewSeed").Visible = visible;
    }

    public void Render(DungeonFloor floor, RunState state, DungeonPhase phase, int seed, bool comparison, int size, bool openLayout, DoorSide entry)
    {
        if (!ReferenceEquals(state, _state)) _shownWard = -1;
        _floor = floor;
        _state = state;
        _seed.Text = seed.ToString();
        _sizes.Visible = comparison;
        _layout.Text = openLayout ? "Layout: Open" : "Layout: Furnished";
        _entry.Text = $"Entry: {entry}";
        bool fighting = phase is DungeonPhase.Combat or DungeonPhase.Results or DungeonPhase.Transition;
        _fighting = fighting;
        _choosingDoor = phase == DungeonPhase.Doors;
        RenderParty(state, fighting);
        ApplyOverlay();
        int id = state.CurrentNodeId ?? 0;
        var room = floor.Rooms[id];
        _planTitle.Text = $"{_floorName}, floor {state.Stratum + 1} of {Delve.Data.FloorThemes.Count}";
        _planGoal.Text = Goal(floor);
        _floorPlan.Render(floor, state);
        var ward = state.Wardstone;
        _wardValue.Text = ward.Ward.ToString();
        _wardBar.MaxValue = ward.Rules.MaxWard;
        ShowWard(ward.Ward);
        _wardTicks.SetFractions(new[] { ward.Rules.SteadyAbove, ward.Rules.FirstShiftAbove, ward.Rules.SecondShiftAbove }
            .Select(t => (float)t / ward.Rules.MaxWard).ToArray());
        var color = UiColors.WardTier(ward.Upshift);
        _wardFill.BgColor = color;
        _wardValue.Modulate = color;
        _wardDanger.Modulate = color;
        _wardDanger.Text = ward.IsSpent ? "EXHAUSTED · Expedition ends"
            : ward.Upshift == 0 ? "Danger: normal"
            : $"Danger: +{ward.Upshift} {(ward.Upshift == 1 ? "tier" : "tiers")}";
        // Normal danger needs no line; the readout speaks up only when fights get harder.
        _wardDanger.Visible = ward.IsSpent || ward.Upshift > 0;
        _expedition.TooltipText = $"Each {_words.CrossingNoun}, including backtracking, costs {ward.Rules.NodeBurn} ward, a short rest costs {ward.Rules.ShortRestBurn}, and the expedition ends at 0.\nFights get harder below {ward.Rules.SteadyAbove}, {ward.Rules.FirstShiftAbove} and {ward.Rules.SecondShiftAbove} ward.";
        int cleared = floor.Rooms.Count(r => r.Completed);
        _roomProgress.Text = $"{_words.ProgressLabel} {cleared} of {floor.Rooms.Count}";
        _goldValue.Text = state.Gold.ToString();
        bool guardianDown = floor.Rooms[floor.GuardianId].Completed;
        _notice.Text = phase switch
        {
            DungeonPhase.Travel => $"Crossing…  −{state.Wardstone.Rules.NodeBurn} ward",
            DungeonPhase.Doors when guardianDown => _words.FloorComplete,
            DungeonPhase.Combat => comparison ? $"Guard hall comparison: {size} × {size}. Same seed and enemies; compare movement and congestion." : "",
            DungeonPhase.End => state.Outcome == RunOutcome.Victory ? _words.FloorComplete : "Expedition over",
            _ => ""
        };
        if (phase == DungeonPhase.Doors && CharacterPromotion.HasPending(state.Party))
            _notice.Text = "Promotion available: " + string.Join(", ", state.Party.Living()
                .Where(c => CharacterPromotion.For(c).PendingLevels(c) > 0).Select(c => c.Name));
        // Mutant Year Zero shows a room's verbs only while they are open. Short rest is open in every
        // room, so it stays and greys when the ward cannot pay; the hover says why.
        _rest.SetEnabled(state.Wardstone.CanAffordShortRest || state.FreeRests > 0);
        _rest.SetActionText(state.FreeRests > 0 ? $"Short rest · Free ({state.FreeRests})"
            : $"Short rest · Ward {ward.Ward} → {ward.WardAfterShortRest}");
        _rest.TooltipText = _rest.Disabled ? $"Unavailable: a short rest costs {ward.Rules.ShortRestBurn} ward." : "";
        bool canCamp = room.Family == RoomFamily.Camp && !room.Resolved;
        int campWard = Math.Min(ward.Rules.MaxWard, ward.Ward + ward.Rules.CampsiteRefill);
        // A prompt counts as opening only while the party picks a door, so its swell is seen.
        bool doors = phase == DungeonPhase.Doors;
        ShowPrompt(_camp, canCamp && doors);
        _camp.SetActionText($"Make camp · Ward {ward.Ward} → {campWard}");
        _camp.TooltipText = "Restores HP, spell slots and focus, and clears Wounded. Once per refuge.";
        bool hurt = state.Party.Living().Any(m => m.Health.CurrentHP < m.Health.MaxHP);
        _potion.SetEnabled(state.Potions > 0 && hurt);
        _potion.SetActionText($"Potion {state.Potions}");
        _potion.TooltipText = state.Potions == 0 ? ""
            : !hurt ? "Unavailable: nobody is hurt"
            : "The most wounded hero drinks a healing potion of the party's level.";
        bool canDescend = room.Family == RoomFamily.Guardian && room.Completed;
        ShowPrompt(_stairs, canDescend && doors);
        _stairs.SetActionText(state.OnFinalStratum ? "Complete expedition" : string.Format(_words.ExitAction, state.Stratum + 2));
    }


    /// <summary>Slides the bar to the new ward and pulses the panel. The first value of a run snaps.</summary>
    private void ShowWard(int ward)
    {
        if (ward == _shownWard) return;
        bool snap = _shownWard < 0 || Instant;
        if (!snap) FloatWardChange(ward - _shownWard);
        _shownWard = ward;
        _wardTween?.Kill();
        _expedition.Scale = Vector2.One;
        if (snap)
        {
            _wardBar.Value = ward;
            return;
        }
        _expedition.PivotOffset = _expedition.Size / 2;
        _wardTween = CreateTween().SetParallel(true);
        _wardTween.TweenProperty(_wardBar, "value", (double)ward, WardTweenSeconds)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _wardTween.TweenProperty(_expedition, "scale", Vector2.One * WardPulseScale, WardPulseSeconds / 2)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _wardTween.Chain().TweenProperty(_expedition, "scale", Vector2.One, WardPulseSeconds / 2)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
    }

    /// <summary>The room's name over the scene. It never takes input, so doors stay usable.</summary>
    /// <summary>The MYZ-style arrival banner: a small kicker ("New room"), the room's name in title
    /// case and at most one short detail line. Longer prose belongs in a hover.</summary>
    public void ShowRoomCard(string title, string detail = "", string kicker = "")
    {
        _cardTween?.Kill();
        _roomCardKicker.Text = kicker;
        _roomCardKicker.Visible = kicker.Length > 0;
        _roomCardTitle.Text = TitleCase(title);
        _roomCardDetail.Text = detail;
        _roomCardDetail.Visible = detail.Length > 0;
        HideRoomCard();
        if (Instant) return;
        _cardTween = CreateTween();
        _cardTween.TweenProperty(_roomCard, "modulate:a", 1.0, RoomCardIn);
        _cardTween.TweenInterval(detail.Length > 0 ? RoomCardDetailHold : RoomCardHold);
        _cardTween.TweenProperty(_roomCard, "modulate:a", 0.0, RoomCardOut);
    }

    /// <summary>Stops the HUD's own beats and shows their end state. Called when a floor resets.</summary>
    public void CancelBeats()
    {
        _cardTween?.Kill();
        HideRoomCard();
        _wardTween?.Kill();
        _expedition.Scale = Vector2.One;
        if (_state != null) _wardBar.Value = _shownWard = _state.Wardstone.Ward;
    }

    /// <summary>Drop the banner at once: a room that opens its own panel must not keep the last room's name up.</summary>
    public void ClearRoomCard()
    {
        _cardTween?.Kill();
        HideRoomCard();
    }

    private void HideRoomCard()
    {
        _cardTween?.Kill();
        _roomCard.Modulate = _roomCard.Modulate with { A = 0 };
    }

    public string RoomCardText => _roomCardTitle.Text;
    public string RoomCardKicker => _roomCardKicker.Text;
    public bool RoomCardShown => _roomCard.Modulate.A > 0 || _cardTween?.IsRunning() == true;

    /// <summary>"Floor 1 of 3", as the floor plan titles it.</summary>
    public string FloorLabel => _planTitle.Text;

    /// <summary>The station's history, read on the floor plan's hover.</summary>
    public void SetFloorHistory(string history) => _plan.TooltipText = history;
    public string FloorHistory => _plan.TooltipText;
    public string RoomCardDetail => _roomCardDetail.Text;

    public void ShowNotice(string text) => _notice.Text = text;
    public string NoticeText => _notice.Text;
    public FloorPlan Plan => _floorPlan;
}
