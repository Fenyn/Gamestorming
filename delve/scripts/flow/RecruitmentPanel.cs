using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>The journal's unlocks page: a filtered grid of traveler tiles and the focused
/// traveler's page with their objectives.</summary>
public partial class RecruitmentPanel : HBoxContainer
{
    [Export] public PackedScene? EntryScene { get; set; }
    [Export] public PackedScene? StepScene { get; set; }

    /// <summary>The tallest the page portrait may draw, at a whole scale.</summary>
    [Export] public int PortraitHeight { get; set; } = 288;
    private GridContainer _entries = null!;
    private VBoxContainer _steps = null!;
    private OptionButton _filter = null!;
    private Button _stay = null!;
    private readonly List<RecruitmentEntry> _cards = new();
    private CampaignProgress? _campaign;
    private string? _selected;
    private static readonly string[] Filters = { "All travelers", "Undiscovered", "In progress", "Ready to join", "Joined" };
    public event Action<string>? StayRequested;
    public string? SelectedId => _selected;

    public override void _Ready()
    {
        _entries = GetNode<GridContainer>("%RecruitEntries");
        _steps = GetNode<VBoxContainer>("%JournalSteps");
        _filter = GetNode<OptionButton>("%JournalFilter");
        _stay = GetNode<Button>("%StayButton");
        foreach (string filter in Filters) _filter.AddItem(filter);
        _filter.ItemSelected += _ => RefreshIndex();
        _stay.Pressed += () =>
        {
            if (_selected != null && _campaign?.CanBindAtOutpost(_selected) == true)
                StayRequested?.Invoke(_selected);
        };
    }

    /// <summary>Rebuild the grid and focus the selected tile, or the filter when none is shown.</summary>
    public void Refresh()
    {
        RefreshIndex();
        // Deferred, and resolved then: a selection made before the grab lands must keep focus.
        Callable.From(() =>
        {
            if (!IsVisibleInTree()) return;
            ((Control?)_cards.FirstOrDefault(c => IsInstanceValid(c) && c.CharacterId == _selected) ?? _filter).GrabFocus();
        }).CallDeferred();
    }
    public void Setup(CampaignProgress campaign) { _campaign = campaign; RefreshIndex(); }
    public static string StatusFor(RecruitmentArc arc, CampaignProgress campaign) => Filters[Stage(arc, campaign)];
    private static int Stage(RecruitmentArc arc, CampaignProgress campaign) =>
        campaign.Unlocks.IsUnlocked(arc.CharacterId) ? 4 : campaign.CanBindAtOutpost(arc.CharacterId) ? 3
        : arc.Steps.Any(step => campaign.RecruitmentCount(arc.CharacterId, step.Id) > 0) ? 2 : 1;
    public void SelectFilter(int index) { _filter.Select(index); RefreshIndex(); }

    private void RefreshIndex()
    {
        if (_campaign == null || EntryScene == null) return;
        foreach (var card in _cards) { _entries.RemoveChild(card); card.QueueFree(); }
        _cards.Clear();
        for (int i = 0; i < Filters.Length; i++)
        {
            int count = RecruitmentCatalog.All.Count(arc => i == 0 || Stage(arc, _campaign) == i);
            _filter.SetItemText(i, $"{Filters[i]} ({count})");
        }
        int joined = RecruitmentCatalog.All.Count(arc => _campaign.Unlocks.IsUnlocked(arc.CharacterId));
        GetNode<Label>("%JournalSummary").Text = $"{joined} of {RecruitmentCatalog.All.Count} companions have joined. Progress carries between expeditions.";
        var arcs = RecruitmentCatalog.All.Where(arc => _filter.Selected == 0 || Stage(arc, _campaign) == _filter.Selected)
            .OrderBy(arc => Stage(arc, _campaign) switch { 3 => 0, 2 => 1, 1 => 2, _ => 3 }).ToArray();
        foreach (var arc in arcs)
        {
            var card = EntryScene.Instantiate<RecruitmentEntry>();
            _entries.AddChild(card);
            card.ShowProgress(arc, _campaign, Stage(arc, _campaign) != 1);
            card.Pressed += () => SelectCharacter(arc.CharacterId);
            card.FocusEntered += () => SelectCharacter(arc.CharacterId);
            _cards.Add(card);
        }
        GetNode<Label>("%JournalEmpty").Visible = arcs.Length == 0;
        if (!arcs.Any(arc => arc.CharacterId == _selected)) _selected = arcs.FirstOrDefault()?.CharacterId;
        RenderPage();
    }

    public void SelectCharacter(string id)
    {
        if (!_cards.Any(card => card.CharacterId == id)) return;
        _selected = id;
        RenderPage();
    }

    private void RenderPage()
    {
        foreach (var card in _cards) card.SetPressedNoSignal(card.CharacterId == _selected);
        foreach (Node step in _steps.GetChildren()) { _steps.RemoveChild(step); step.QueueFree(); }
        var arc = _selected == null ? null : RecruitmentCatalog.Find(_selected);
        GetNode<Control>("%JournalPage").Visible = arc != null;
        if (arc == null || _campaign == null || StepScene == null) return;
        var def = CharacterCatalog.Find(arc.CharacterId)!;
        Color accent = UiColors.CharacterAccent(def.Id);
        var title = GetNode<Label>("%RecruitTitle");
        title.Text = def.DisplayName;
        title.AddThemeColorOverride("font_color", accent);
        GetNode<Label>("%JournalRole").Text = def.Role;
        GetNode<Label>("%JournalArc").Text = arc.Title;
        GetNode<Label>("%JournalStatus").Text = StatusFor(arc, _campaign);
        bool known = Stage(arc, _campaign) != 1;
        bool joined = _campaign.Unlocks.IsUnlocked(def.Id);
        var portrait = GetNode<TextureRect>("%JournalPortrait");
        portrait.Texture = known ? HeroPortraits.For(def.Id) : null;
        portrait.CustomMinimumSize = portrait.Texture == null ? Vector2.Zero
            : portrait.Texture.GetSize() * BestiaryPanel.WholeScale(portrait.Texture, PortraitHeight);
        GetNode<Label>("%UnknownPortrait").Visible = !known;
        GetNode<Label>("%JournalStory").Text = known ? BulwarkWayfarers.Find(def.Id)?.Introduction ?? arc.Title
            : "An unfamiliar traveler may cross your path. Explore the dungeon to begin this journal entry.";
        var visibleSteps = known ? arc.Steps : arc.Steps.Take(1);
        foreach (var step in visibleSteps)
        {
            var row = StepScene.Instantiate<Control>();
            _steps.AddChild(row);
            // A joined companion has met every objective, however they joined.
            int count = joined ? step.Required : Math.Min(step.Required, _campaign.RecruitmentCount(def.Id, step.Id));
            row.GetNode<Label>("%ObjectiveText").Text = step.Description;
            row.GetNode<Label>("%ObjectiveCount").Text = count >= step.Required ? "Complete" : $"{count} / {step.Required}";
            var bar = row.GetNode<ProgressBar>("%ObjectiveProgress");
            bar.MaxValue = step.Required;
            bar.Value = count;
            var fill = (StyleBoxFlat)bar.GetThemeStylebox("fill").Duplicate();
            fill.BgColor = accent;
            bar.AddThemeStyleboxOverride("fill", fill);
        }
        _stay.Visible = !joined;
        _stay.Disabled = !_campaign.CanBindAtOutpost(def.Id);
        _stay.TooltipText = _stay.Disabled ? "Complete this traveler's objectives before inviting them to stay."
            : "An overnight stay makes this companion available for future expeditions.";
        GetNode<Label>("%JournalNext").Text = joined ? "At home in the outpost. Available for future expeditions."
            : !_stay.Disabled ? "Your bond is strong enough. Invite this companion to make the outpost their home."
            : known ? "Bring this companion into your party to continue their objectives." : "Further objectives appear after you meet.";
    }
}
