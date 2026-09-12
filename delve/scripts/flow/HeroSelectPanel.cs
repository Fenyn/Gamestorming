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

    private readonly List<string> _selected = new();

    private readonly List<CampResident> _cards = new();
    private readonly Dictionary<string, HeroSheetData> _sheets = new();

    private Control _list = null!;
    private Label _hint = null!;

    private Button _embark = null!;
    private Button _clearParty = null!;
    private CampStage _camp = null!;
    private Control _details = null!;
    private Label _previewName = null!;
    private readonly Dictionary<string, int> _seats = new();
    private Button _recruitmentButton = null!;
    private RecruitmentPanel _recruitment = null!;
    private CampaignProgress? _campaign;
    private HeroSheet _sheet = null!;

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
        _details = GetNode<Control>("%Details");
        _previewName = GetNode<Label>("%PreviewName");
        GetNode<Button>("%DetailsButton").Pressed += OpenDetails;
        GetNode<Button>("%CloseDetails").Pressed += CloseDetails;
        _recruitmentButton = GetNode<Button>("%RecruitmentButton");
        _recruitment = GetNode<RecruitmentPanel>("%Recruitment");
        _recruitmentButton.Pressed += _recruitment.Open;
        _recruitment.StayRequested += id => RecruitmentRequested?.Invoke(id);
        _sheet = GetNode<HeroSheet>("%Sheet");
        _embark.Pressed += Embark;
        _clearParty.Pressed += Unpick;
    }

    /// <summary>Build the roster. Safe to call again for a second run.</summary>
    public void Setup(UnlockState unlocks, CampaignProgress? campaign = null)
    {
        _unlocks = unlocks;
        _campaign = campaign;
        _recruitment.Hide();
        _details.Hide();
        _recruitmentButton.Disabled = campaign == null;
        _recruitmentButton.TooltipText = campaign == null ? "Unavailable: no campaign loaded" : "Review shared recruitment requirements";
        _selected.Clear();
        _hovered = null;

        BuildRoster();
        RefreshRecruitment();
    }

    public void RefreshRecruitment()
    {
        if (_campaign != null) _recruitment.Setup(_campaign);
        SyncResidents();
        Refresh();
    }

    /// <summary>
    /// Choose one character, exactly as a click on that card would. Public so the flow can be
    /// driven without synthetic input. Ignores an id the roster would not take.
    /// </summary>
    public void Pick(string id)
    {
        if (_recruitment.Visible || _details.Visible || !CanPick(id)) return;
        if (!_selected.Remove(id)) _selected.Add(id);
        _hovered = id;
        Refresh();
    }

    /// <summary>Clear the assembled party.</summary>
    public void Unpick()
    {
        if (_recruitment.Visible || _details.Visible) return;
        _selected.Clear();
        Refresh();
    }

    /// <summary>Whether a click on that card would do anything right now.</summary>
    public bool CanPick(string id) => GateFor(id) == null;

    /// <summary>Put one of the featured sheet's tooltips on screen with no pointer involved,
    /// addressed by its title. The rendered shot uses it; nothing in the game does.</summary>
    public bool ShowTipForTesting(string title) { OpenDetails(); return _sheet.ShowTipForTesting(title); }

    /// <summary>See <see cref="HeroSheet.ShowCardForTesting"/>.</summary>
    public bool ShowCardForTesting(SheetTip tip) { OpenDetails(); return _sheet.ShowCardForTesting(tip); }

    /// <summary>Signal a snapshot of the complete formation.</summary>
    public void Embark()
    {
        if (CanEmbark && !_recruitment.Visible && !_details.Visible) Confirmed?.Invoke(_selected.ToArray());
    }

    public override void _Input(InputEvent @event)
    {
        if (!IsVisibleInTree()) return;
        if (_details.Visible)
        {
            if (@event.IsActionPressed(InputNames.Decline))
            { CloseDetails(); GetViewport().SetInputAsHandled(); }
            return;
        }
        if (_recruitment.Visible)
        {
            if (@event.IsActionPressed(InputNames.Decline))
            {
                _recruitment.Hide();
                GetViewport().SetInputAsHandled();
            }
            return;
        }

        if (@event.IsActionPressed(InputNames.UiDown)) Step(1);
        else if (@event.IsActionPressed(InputNames.UiUp)) Step(-1);
        else if (@event.IsActionPressed(InputNames.Confirm))
        {
            if (_embark.HasFocus()) Embark();
            else if (_clearParty.HasFocus()) Unpick();
            else if (_recruitmentButton.HasFocus() && !_recruitmentButton.Disabled) _recruitment.Open();
            else if (GetNode<Button>("%DetailsButton").HasFocus()) OpenDetails();
            else if (_hovered != null) Pick(_hovered);
        }
        else if (@event.IsActionPressed(InputNames.Decline) && _selected.Count > 0) Unpick();
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
        _hint.Text = CanEmbark ? "Party ready. You control all four members."
            : $"Assemble your party ({_selected.Count}/{Party.MaxSize}). Select a resident to add or remove them.";
        _embark.Disabled = !CanEmbark;
        _embark.TooltipText = CanEmbark ? "" : "Unavailable: choose four party members";
        _clearParty.Disabled = _selected.Count == 0;
        _clearParty.TooltipText = "Clear the assembled party";
        RenderSheet();
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
        string? id = _hovered ?? (_selected.Count > 0 ? _selected[0] : null) ?? FirstSelectable();
        var def = id == null ? null : CharacterCatalog.Find(id);
        if (def == null) { _previewName.Text = "No companions at camp yet"; return; }
        _previewName.Text = $"{def.DisplayName}  /  {def.Role}";
        _sheet.Show(
            _sheets.TryGetValue(def.Id, out var sheet) ? sheet : HeroSheetData.Unknown(def.DisplayName),
            HeroPortraits.For(def.Id),
            Delve.UI.UiColors.CharacterAccent(def.Id));
    }

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

    /// <summary>Move the preview without changing formation. Confirm selects the preview.</summary>
    private void Step(int delta)
    {
        if (_cards.Count == 0) return;
        int start = _hovered == null ? -1 : _cards.FindIndex(c => c.Id == _hovered);
        for (int step = 1; step <= _cards.Count; step++)
        {
            int index = ((start + delta * step) % _cards.Count + _cards.Count) % _cards.Count;
            if (!CanPick(_cards[index].Id)) continue;
            _embark.ReleaseFocus();
            Preview(_cards[index].Id);
            _cards[index].GrabFocus();
            return;
        }
    }

    private string? FirstSelectable()
    {
        foreach (var card in _cards)
        {
            if (CanPick(card.Id)) return card.Id;
        }
        return _cards.Count > 0 ? _cards[0].Id : null;
    }
}
