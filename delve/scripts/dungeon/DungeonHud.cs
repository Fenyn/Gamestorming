using System;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;
public partial class DungeonHud : Control
{
    public event Action? RestPressed, CampPressed, PotionPressed, StairsPressed, LayoutPicked, EntryPicked;
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
    private Control _partyMenu = null!;
    private CaptionButton _travelHint = null!;

    /// <summary>Keycap text on the Travel row: travel is a click on a doorway, not a key.</summary>
    [Export] public string TravelKey { get; set; } = "LMB";

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
        _partyMenu = GetNode<Control>("%PartyMenu");
        _travelHint = GetNode<CaptionButton>("%TravelHint");
        if (_travelHint.KeyLabel != null) _travelHint.KeyLabel.Text = TravelKey;
        HideRoomCard();
        _seed = GetNode<LineEdit>("%Seed");
        _sizes = GetNode<HBoxContainer>("%Sizes");
        _rest = GetNode<CaptionButton>("%Rest");
        _stairs = GetNode<CaptionButton>("%Stairs");
        _rest.TooltipText = "Ten minutes for the whole party: Treat Wounds, Refocus or Repair Shield.";
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
        _expedition.Visible = !fighting;
        _notice.Visible = !fighting;
        RenderParty(state, fighting);
        ApplyOverlay();
        int id = state.CurrentNodeId ?? 0;
        var room = floor.Rooms[id];
        int wardNow = state.Wardstone.Ward;
        _travelHint.SetActionText($"Travel · Ward {wardNow} → {Math.Max(0, wardNow - state.Wardstone.Rules.NodeBurn)}");
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
        _expedition.TooltipText = $"Ward {ward.Ward} of {ward.Rules.MaxWard}.\nEach {_words.CrossingNoun} costs {ward.Rules.NodeBurn} ward, including backtracking.\nShort rests cost {ward.Rules.ShortRestBurn} ward. Zero ward ends the expedition.\nEncounter danger rises below {ward.Rules.SteadyAbove}, {ward.Rules.FirstShiftAbove}, and {ward.Rules.SecondShiftAbove} ward.\nCleared places stay cleared when you return.";
        int cleared = floor.Rooms.Count(r => r.Completed);
        _roomProgress.Text = $"{_words.ProgressLabel} {cleared} of {floor.Rooms.Count}  ·  {state.Gold} gold";
        bool guardianDown = floor.Rooms[floor.GuardianId].Completed;
        _notice.Text = phase switch
        {
            DungeonPhase.Travel => $"Crossing…  −{state.Wardstone.Rules.NodeBurn} ward",
            DungeonPhase.Doors when guardianDown => _words.FloorComplete,
            DungeonPhase.Combat => comparison ? $"Guard hall comparison: {size} × {size}. Same seed and enemies; compare movement and congestion." : "Resolve the encounter to open the doors.",
            DungeonPhase.End => state.Outcome == RunOutcome.Victory ? _words.FloorComplete : "The expedition ends. Restart or try a new seed.",
            _ => ""
        };
        if (phase == DungeonPhase.Doors && CharacterPromotion.HasPending(state.Party))
            _notice.Text = "Promotion available: " + string.Join(", ", state.Party.Living()
                .Where(c => CharacterPromotion.For(c).PendingLevels(c) > 0).Select(c => c.Name))
                + ". Click a character to open their sheet before the next encounter.";
        // FFT keeps every command in the menu and greys the ones not open now; the hover says why.
        bool doors = phase == DungeonPhase.Doors;
        _rest.Visible = doors;
        _rest.SetEnabled(state.Wardstone.CanAffordShortRest || state.FreeRests > 0);
        _rest.SetActionText(state.FreeRests > 0 ? $"Short rest · Free ({state.FreeRests})"
            : $"Short rest · Ward {ward.Ward} → {ward.WardAfterShortRest}");
        bool canCamp = room.Family == RoomFamily.Camp && !room.Resolved;
        int campWard = Math.Min(ward.Rules.MaxWard, ward.Ward + ward.Rules.CampsiteRefill);
        _camp.Visible = doors;
        _camp.SetEnabled(canCamp);
        _camp.SetActionText(canCamp ? $"Make camp · Ward {ward.Ward} → {campWard}" : "Make camp");
        _camp.TooltipText = canCamp
            ? "Rest until morning, once per refuge. Recovers HP, clears Wounded, restores spell slots and focus, and starts a new day."
            : "Unavailable: only in a refuge you have not rested in.";
        bool hurt = state.Party.Living().Any(m => m.Health.CurrentHP < m.Health.MaxHP);
        _potion.Visible = doors;
        _potion.SetEnabled(state.Potions > 0 && hurt);
        _potion.SetActionText($"Drink potion · {state.Potions} left");
        _potion.TooltipText = state.Potions == 0 ? "Unavailable: no potions."
            : !hurt ? "Unavailable: nobody is hurt."
            : "The most wounded hero drinks a healing potion of the party's level.";
        bool canDescend = room.Family == RoomFamily.Guardian && room.Completed;
        _stairs.Visible = doors;
        _stairs.SetEnabled(canDescend);
        _stairs.SetActionText(state.OnFinalStratum ? "Complete expedition" : string.Format(_words.ExitAction, state.Stratum + 2));
        _stairs.TooltipText = canDescend ? _words.ExitTip
            : _words.ExitBlockedTip;
    }


    /// <summary>Slides the bar to the new ward and pulses the panel. The first value of a run snaps.</summary>
    private void ShowWard(int ward)
    {
        if (ward == _shownWard) return;
        bool snap = _shownWard < 0 || Instant;
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

    private void HideRoomCard() => _roomCard.Modulate = _roomCard.Modulate with { A = 0 };

    private static readonly string[] SmallWords = { "of", "the", "and", "a", "an", "in", "on", "to" };

    /// <summary>"receiving hall" → "Receiving Hall"; small words stay lower case after the first.</summary>
    private static string TitleCase(string text)
    {
        var words = text.Split(' ');
        for (int i = 0; i < words.Length; i++)
            if (words[i].Length > 0 && (i == 0 || !SmallWords.Contains(words[i])))
                words[i] = char.ToUpperInvariant(words[i][0]) + words[i][1..];
        return string.Join(' ', words);
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
