using System;
using System.Collections.Generic;
using Delve.Autoload;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// First screen of a run: one featured character filling the left of the frame and the roster down
/// the right. The player picks exactly one starting character - companions join during the run -
/// so the whole screen is a single choice, and the featured sheet is where that choice is argued.
///
/// Reads the roster from <see cref="CharacterCatalog"/> and the <see cref="UnlockState"/> handed to
/// <see cref="Setup"/>, and signals the pick outward: it builds no party and starts no run.
/// </summary>
public partial class HeroSelectPanel : Control
{
    /// <summary>The roster card. Assigned in hero_select.tscn.</summary>
    [Export] public PackedScene? CardScene { get; set; }

    private static readonly string[] NoCompanions = Array.Empty<string>();

    private readonly List<RosterCard> _cards = new();
    private readonly Dictionary<string, HeroSheetData> _sheets = new();

    private VBoxContainer _list = null!;
    private Label _hint = null!;
    private Button _embark = null!;
    private HeroSheet _sheet = null!;

    private UnlockState _unlocks = new();
    private string? _chosen;
    private string? _hovered;

    /// <summary>The starting character, and the companions already in the party - none, for now.</summary>
    public event Action<string, IReadOnlyList<string>>? Confirmed;

    /// <summary>Catalog id of the starting character, or null.</summary>
    public string? Chosen => _chosen;

    /// <summary>True once a character is chosen.</summary>
    public bool CanEmbark => _chosen != null;

    /// <summary>The gate line under the title - what the screen is waiting for.</summary>
    public string HintText => _hint.Text;

    public override void _Ready()
    {
        _list = GetNode<VBoxContainer>("%RosterList");
        _hint = GetNode<Label>("%HintLabel");
        _embark = GetNode<Button>("%EmbarkButton");
        _sheet = GetNode<HeroSheet>("%Sheet");
        _embark.Pressed += Embark;
    }

    /// <summary>Build the roster. Safe to call again for a second run.</summary>
    public void Setup(UnlockState unlocks)
    {
        _unlocks = unlocks;
        _chosen = null;
        _hovered = null;

        BuildRoster();
        Refresh();
    }

    /// <summary>
    /// Choose one character, exactly as a click on that card would. Public so the flow can be
    /// driven without synthetic input. Ignores an id the roster would not take.
    /// </summary>
    public void Pick(string id)
    {
        if (!CanPick(id)) return;
        _chosen = id;
        Refresh();
    }

    /// <summary>Give the choice back. Esc is the only undo this screen needs - there is nothing
    /// behind the first screen of a run to go back to.</summary>
    public void Unpick()
    {
        _chosen = null;
        Refresh();
    }

    /// <summary>Whether a click on that card would do anything right now.</summary>
    public bool CanPick(string id) => GateFor(id) == null;

    /// <summary>Put one of the featured sheet's tooltips on screen with no pointer involved,
    /// addressed by its title. The rendered shot uses it; nothing in the game does.</summary>
    public bool ShowTipForTesting(string title) => _sheet.ShowTipForTesting(title);

    /// <summary>See <see cref="HeroSheet.ShowCardForTesting"/>.</summary>
    public bool ShowCardForTesting(SheetTip tip) => _sheet.ShowCardForTesting(tip);

    /// <summary>Signal the choice. Does nothing until a character is chosen.</summary>
    public void Embark()
    {
        if (_chosen != null) Confirmed?.Invoke(_chosen, NoCompanions);
    }

    public override void _Input(InputEvent @event)
    {
        if (!Visible) return;

        if (@event.IsActionPressed(InputNames.UiDown)) Step(1);
        else if (@event.IsActionPressed(InputNames.UiUp)) Step(-1);
        else if (@event.IsActionPressed(InputNames.Confirm) && CanEmbark) Embark();
        else if (@event.IsActionPressed(InputNames.Decline) && _chosen != null) Unpick();
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

        bool dataReady = DataManager.Instance is { IsLoaded: true };
        foreach (var def in CharacterCatalog.All)
        {
            if (!_sheets.ContainsKey(def.Id)) _sheets[def.Id] = ReadSheet(def, dataReady);

            var card = CardScene.Instantiate<RosterCard>();
            _list.AddChild(card);
            card.Setup(def, HeroPortraits.For(def.Id));
            card.Clicked += Pick;
            card.Hovered += Preview;
            _cards.Add(card);
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
        {
            bool unlocked = _unlocks.IsUnlocked(card.Id);
            card.SetState(new RosterCardState(
                card.Id == _chosen, GateFor(card.Id), Locked: !unlocked));
        }

        _hint.Text = _chosen == null
            ? "Pick who enters the depths alone — companions join along the way."
            : "Ready to delve.";
        _embark.Disabled = _chosen == null;
        _embark.TooltipText = _chosen == null ? "Unavailable: no character chosen" : "";
        if (_chosen != null) _embark.GrabFocus();

        RenderSheet();
    }

    /// <summary>Why a click on that card would do nothing, or null when it would work.</summary>
    private string? GateFor(string id)
    {
        var def = CharacterCatalog.Find(id);
        if (def == null) return "not on the roster";
        if (!_unlocks.IsUnlocked(id)) return "locked";
        return def.CanLead ? null : "cannot lead a run";
    }

    /// <summary>The sheet reads the hovered card, falls back to the choice, then to the first
    /// character the player could take - the frame is never without a hero in it.</summary>
    private void RenderSheet()
    {
        string? id = _hovered ?? _chosen ?? FirstSelectable();
        var def = id == null ? null : CharacterCatalog.Find(id);
        if (def == null) return;
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
        // A pointer leaving one card and arriving on the next fires exit then enter; only the exit
        // of the card actually being read should fall back to the choice.
        if (id == null && _hovered == null) return;
        _hovered = id;
        RenderSheet();
    }

    /// <summary>Move the choice up or down the roster, skipping entries that cannot be taken.</summary>
    private void Step(int delta)
    {
        if (_cards.Count == 0) return;
        int start = _chosen == null ? -1 : _cards.FindIndex(c => c.Id == _chosen);
        for (int step = 1; step <= _cards.Count; step++)
        {
            int index = ((start + delta * step) % _cards.Count + _cards.Count) % _cards.Count;
            if (!CanPick(_cards[index].Id)) continue;
            _chosen = _cards[index].Id;
            Refresh();
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
