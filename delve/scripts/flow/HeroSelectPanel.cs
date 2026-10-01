using System;
using System.Collections.Generic;
using Delve.Autoload;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// Party formation at the outpost: choose four party members from residents in camp.
/// Detailed sheets open on demand. Selection stays editable until embark.
///
/// Reads the roster from <see cref="CharacterCatalog"/> and the <see cref="UnlockState"/> handed to
/// <see cref="Setup"/>, and signals the pick outward: it builds no party and starts no run.
/// </summary>
public partial class HeroSelectPanel : Control
{
    /// <summary>The selectable camp resident. Assigned in hero_select.tscn.</summary>
    [Export] public PackedScene? CardScene { get; set; }

    /// <summary>One slot of the squad strip over Embark: the picks as face tiles, XCOM style.</summary>
    [Export] public PackedScene? SquadTileScene { get; set; }

    private readonly List<string> _selected = new();

    private readonly List<CampResident> _cards = new();
    private readonly Dictionary<string, HeroSheetData> _sheets = new();

    private Control _list = null!;
    private Label _hint = null!;

    private Button _embark = null!;
    private Button _clearParty = null!;
    private CampStage _camp = null!;
    private CharacterDetailsOverlay _details = null!;
    private Label _previewName = null!;
    private readonly Dictionary<string, int> _seats = new();
    private Button _recruitmentButton = null!;
    private CampaignProgress? _campaign;

    private UnlockState _unlocks = new();

    private string? _hovered;

    /// <summary>The four distinct members selected for this run.</summary>
    public event Action<IReadOnlyList<string>>? Confirmed;
    public event Action<string>? RecruitmentRequested;

    public IReadOnlyList<string> SelectedIds => _selected.AsReadOnly();
    public bool CanEmbark => _selected.Count == Party.MaxSize;

    /// <summary>The gate line under the title - what the screen is waiting for.</summary>
    public string HintText => _hint.Text;

    public override void _Ready()
    {
        _list = GetNode<Control>("%RosterList");
        _hint = GetNode<Label>("%HintLabel");
        _embark = GetNode<Button>("%EmbarkButton");
        _clearParty = GetNode<Button>("%ClearPartyButton");
        _camp = GetNode<CampStage>("%CampStage");
        _details = GetNode<CharacterDetailsOverlay>("%Details");
        _details.PickRequested += id =>
        {
            TogglePick(id);
            _details.RefreshRoster();
        };
        _previewName = GetNode<Label>("%PreviewName");
        GetNode<Button>("%DetailsButton").Pressed += () => OpenDetails();
        _recruitmentButton = GetNode<Button>("%RecruitmentButton");
        ReadyJournal();
        _embark.Pressed += Embark;
        _clearParty.Pressed += Unpick;
        // Esc with picks gives one back first; with none it reaches the pause menu and its Quit.
        AddToGroup(PauseMenu.HostGroup);
    }

    /// <summary>Build the roster. Safe to call again for a second run.</summary>
    public void Setup(UnlockState unlocks, CampaignProgress? campaign = null)
    {
        _unlocks = unlocks;
        _campaign = campaign;
        _details.Close();
        SetupJournal(campaign);
        _selected.Clear();
        _hovered = null;

        BuildRoster();
        RefreshRecruitment();
    }

    public void RefreshRecruitment()
    {
        if (_campaign != null)
        {
            _journal.Unlocks.Setup(_campaign);
            int ready = System.Linq.Enumerable.Count(RecruitmentCatalog.All, arc => _campaign.CanBindAtOutpost(arc.CharacterId));
            _recruitmentButton.Text = ready > 0 ? $"Unlocks  {ready} ready" : "Unlocks";
        }
        SyncResidents();
        Refresh();
    }

    /// <summary>
    /// Choose one character, exactly as a click on that card would. Public so the flow can be
    /// driven without synthetic input. Ignores an id the roster would not take.
    /// </summary>
    public void Pick(string id)
    {
        if (OverlayOpen) return;
        TogglePick(id);
    }

    private void TogglePick(string id)
    {
        if (!CanPick(id)) return;
        if (!_selected.Remove(id)) _selected.Add(id);
        _hovered = id;
        Refresh();
    }

    /// <summary>Clear the assembled party.</summary>
    public void Unpick()
    {
        if (OverlayOpen) return;
        _selected.Clear();
        Refresh();
    }

    /// <summary>Whether a click on that card would do anything right now.</summary>
    public bool CanPick(string id) => GateFor(id) == null;

    /// <summary>Put one of the featured sheet's tooltips on screen with no pointer involved,
    /// addressed by its title. The rendered shot uses it; nothing in the game does.</summary>
    public bool ShowTipForTesting(string title) { InspectShown(); return Sheet.ShowTipForTesting(title); }

    /// <summary>See <see cref="HeroSheet.ShowCardForTesting"/>.</summary>
    public bool ShowCardForTesting(SheetTip tip) { InspectShown(); return Sheet.ShowCardForTesting(tip); }

    /// <summary>Open the party screen on the resident the camp card shows, or turn it to them.</summary>
    private void InspectShown()
    {
        if (!_details.Visible) OpenDetails();
        else if (ShownId() is { } id && id != _details.CurrentId) { CloseDetails(); OpenDetails(id); }
    }

    /// <summary>Signal a snapshot of the complete formation.</summary>
    public void Embark()
    {
        if (CanEmbark && !OverlayOpen) Confirmed?.Invoke(_selected.ToArray());
    }

    public override void _Input(InputEvent @event)
    {
        if (!IsVisibleInTree()) return;
        if (OverlayOpen) return;

        if (@event.IsActionPressed(InputNames.ExploreJournal)) OpenJournal(JournalScreen.BestiaryPage);
        else if (@event.IsActionPressed(InputNames.UiDown)) Step(1);
        else if (@event.IsActionPressed(InputNames.UiUp)) Step(-1);
        else if (@event.IsActionPressed(InputNames.Confirm))
        {
            if (_embark.HasFocus()) Embark();
            else if (_clearParty.HasFocus()) Unpick();
            else if (_recruitmentButton.HasFocus() && !_recruitmentButton.Disabled) OpenJournal(JournalScreen.UnlocksPage);
            else if (_bestiaryButton.HasFocus() && !_bestiaryButton.Disabled) OpenJournal(JournalScreen.BestiaryPage);
            else if (GetNode<Button>("%DetailsButton").HasFocus()) OpenDetails();
            else if (_hovered != null) Pick(_hovered);
        }
        else if (@event.IsActionPressed(InputNames.Decline) && _selected.Count > 0) Pick(_selected[^1]);
        else return;

        GetViewport().SetInputAsHandled();
    }

    // ---------------------------------------------------------------- Build

    private void BuildRoster()
    {
        foreach (var card in _cards)
        {
            _list.RemoveChild(card);
            card.QueueFree();
        }
        _cards.Clear();
        if (CardScene == null)
        {
            GD.PushError("[HeroSelect] CardScene is not assigned.");
            return;
        }

        _seats.Clear();
        SyncResidents();
    }

    private void SyncResidents()
    {
        bool dataReady = DataManager.Instance is { IsLoaded: true };
        for (int seat = 0; seat < CharacterCatalog.All.Count; seat++)
        {
            var def = CharacterCatalog.All[seat];
            if (!_sheets.ContainsKey(def.Id)) _sheets[def.Id] = ReadSheet(def, dataReady);
            if (!_unlocks.IsUnlocked(def.Id) || _seats.ContainsKey(def.Id)) continue;
            var resident = CardScene!.Instantiate<CampResident>();
            _list.AddChild(resident);
            int place = _camp.SeatFor(def.Id);
            if (place < 0) place = seat;
            resident.Setup(def, _camp.AppearanceFor(place), place);
            resident.Clicked += Pick;
            resident.Hovered += Preview;
            _cards.Add(resident);
            _seats[def.Id] = place;
        }
    }

    /// <summary>
    /// Assemble one roster entry at the run's start level and read its sheet. Building a preset
    /// needs the equipment packs, so the panel owns the "is the data pack loaded" question and a
    /// build that throws yields an empty sheet rather than taking the screen down with it.
    /// </summary>
    private static HeroSheetData ReadSheet(CharacterDef def, bool dataReady)
    {
        if (!dataReady) return HeroSheetData.Unknown(def.DisplayName);
        try
        {
            return HeroSheetBuilder.Read(def.Builder(Party.DefaultLevel));
        }
        catch (Exception e)
        {
            GD.PushWarning($"[HeroSelect] Could not build '{def.Id}': {e.Message}");
            return HeroSheetData.Unknown(def.DisplayName);
        }
    }

    // ---------------------------------------------------------------- Render

    /// <summary>
    /// Repaint every card, the featured sheet and the Embark gate from the one choice. Each
    /// disabled control names the gate that failed (design/ui_guidelines.md section 7).
    /// </summary>
    private void Refresh()
    {
        foreach (var card in _cards)
            card.SetState(_selected.Contains(card.Id), GateFor(card.Id));
        _hint.Text = CanEmbark ? "Your companions are ready for the road."
            : "Gather four companions around the fire.";
        GetNode<Label>("%PartyCount").Text = $"PARTY  {_selected.Count} / {Party.MaxSize}";
        _embark.Disabled = !CanEmbark;
        _embark.TooltipText = CanEmbark ? "" : "Unavailable: choose four party members";
        _clearParty.Disabled = _selected.Count == 0;
        _clearParty.TooltipText = "Clear the assembled party";
        RenderSheet();
        RenderSquad();
    }
    /// <summary>Why a click on that card would do nothing, or null when it would work.</summary>
    private string? GateFor(string id)
    {
        var def = CharacterCatalog.Find(id);
        if (def == null) return "not on the roster";
        if (!_unlocks.IsUnlocked(id)) return "locked";
        if (_selected.Contains(id)) return null;
        return CanEmbark ? "remove a party member to make room" : null;
    }

    /// <summary>The sheet reads the hovered card, falls back to the choice, then to the first
    /// character the player could take - the frame is never without a hero in it.</summary>
    private void RenderSheet()
    {
        var def = ShownId() is { } id ? CharacterCatalog.Find(id) : null;
        if (def == null) { _previewName.Text = "No companions at camp yet"; return; }
        _previewName.Text = def.DisplayName;
        GetNode<Label>("%PreviewRole").Text = def.Role;
    }

    /// <summary>The resident the camp card shows: the hovered one, then the first pick, then the
    /// first one the player could take.</summary>
    private string? ShownId() => _hovered ?? (_selected.Count > 0 ? _selected[0] : null) ?? FirstSelectable();

    /// <summary>
    /// Feature one character's sheet without choosing them - what hovering a roster card does.
    /// Null gives the frame back to the choice. Public so the sheet can be read without synthetic
    /// input; the roster wires its own hover straight to it.
    /// </summary>
    public void Preview(string? id)
    {
        // Retain the last resident while the pointer travels to Character details.
        if (id == _hovered) return;
        _hovered = id;
        RenderSheet();
    }
}
