using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Autoload;
using Delve.Run;
using Delve.UI;
using Delve.Village;
using Godot;

namespace Delve.Flow;

/// <summary>
/// The outpost: the village at its town tier and time of day, with the unlocked residents at their
/// day's work. Clicking the Delve trail (or G) enters party assembly, XCOM style: four slots at the
/// trailhead, each filled from a roster, the pick walking in from offscreen. Esc goes back to town
/// and keeps the picks. Selection stays editable until embark.
///
/// Reads the roster from <see cref="CharacterCatalog"/> and the <see cref="UnlockState"/> handed to
/// <see cref="Setup"/>, and signals the pick outward: it builds no party and starts no run.
/// </summary>
public partial class HeroSelectPanel : Control
{
    /// <summary>One party slot tile in assembly. Assigned in hero_select.tscn.</summary>
    [Export] public PackedScene? SquadTileScene { get; set; }

    private readonly string?[] _slots = new string?[Party.MaxSize];
    private readonly Dictionary<string, HeroSheetData> _sheets = new();

    private Button _embark = null!;
    private Button _clearParty = null!;
    private Button _assemble = null!;
    private Button _backToTown = null!;
    private Control _assembly = null!;
    private Control _town = null!;
    private VillageStage _village = null!;
    private RosterPicker _picker = null!;
    private CharacterDetailsOverlay _details = null!;
    private Button _recruitmentButton = null!;
    private CampaignProgress? _campaign;

    private UnlockState _unlocks = new();
    private string? _hovered;
    private int _pickerSlot = -1;

    /// <summary>The four distinct members selected for this run.</summary>
    public event Action<IReadOnlyList<string>>? Confirmed;
    public event Action<string>? RecruitmentRequested;

    /// <summary>The picks in slot order.</summary>
    public IReadOnlyList<string> SelectedIds => _slots.OfType<string>().ToList();
    public bool CanEmbark => _slots.All(s => s != null);

    /// <summary>True while the party is being assembled at the trailhead.</summary>
    public bool Assembling { get; private set; }

    /// <summary>Session-only town tier for testing the larger village; never saved.</summary>
    public TownTier? TownTierOverride { get; set; }

    public VillageStage Village => _village;
    public RosterPicker Picker => _picker;

    public override void _Ready()
    {
        _embark = GetNode<Button>("%EmbarkButton");
        _clearParty = GetNode<Button>("%ClearPartyButton");
        _assemble = GetNode<Button>("%AssembleButton");
        _backToTown = GetNode<Button>("%BackToTownButton");
        _assembly = GetNode<Control>("%Assembly");
        _town = GetNode<Control>("%Town");
        _village = GetNode<VillageStage>("%Village");
        _picker = GetNode<RosterPicker>("%Picker");
        _details = GetNode<CharacterDetailsOverlay>("%Details");
        _details.PickRequested += id =>
        {
            TogglePick(id);
            _details.RefreshRoster();
        };
        _recruitmentButton = GetNode<Button>("%RecruitmentButton");
        ReadyJournal();
        _embark.Pressed += Embark;
        _clearParty.Pressed += Unpick;
        _assemble.Pressed += EnterAssembly;
        _backToTown.Pressed += LeaveAssembly;
        _picker.Chosen += ChooseFromPicker;
        _picker.DetailsRequested += id => OpenDetails(id);
        _picker.VacateRequested += VacatePickerSlot;
        _picker.Closed += () => _pickerSlot = -1;
        _village.StationPressed += OnStation;
        // Esc in town reaches the pause menu and its Quit; in assembly it goes back to town.
        AddToGroup(PauseMenu.HostGroup);
    }

    /// <summary>Build the village and the roster. Safe to call again for a second run.</summary>
    public void Setup(UnlockState unlocks, CampaignProgress? campaign = null)
    {
        _unlocks = unlocks;
        _campaign = campaign;
        _details.Close();
        _picker.Close();
        SetupJournal(campaign);
        Array.Fill(_slots, null);
        _hovered = null;
        ReadSheets();
        SetupVillage();
        RefreshRecruitment();
    }

    public void RefreshRecruitment()
    {
        if (_campaign != null)
        {
            _journal.Unlocks.Setup(_campaign);
            int ready = RecruitmentCatalog.All.Count(arc => _campaign.CanBindAtOutpost(arc.CharacterId));
            _recruitmentButton.Text = ready > 0 ? $"Unlocks  {ready} ready" : "Unlocks";
        }
        // Someone who just joined the outpost moves in.
        foreach (string id in Residents())
            if (!_slots.Contains(id) && _village.Residents.Figures.All(f => f.Id != id)) _village.Residents.Admit(id);
        Refresh();
    }

    /// <summary>
    /// Choose one character, as picking them from the roster would: into the open slot the roster
    /// was opened for, else the first empty slot. Choosing someone already in the party takes them
    /// out. Public so the flow can be driven without synthetic input; ignores an id the roster would not take.
    /// </summary>
    public void Pick(string id)
    {
        if (OverlayOpen) return;
        TogglePick(id);
    }

    private void TogglePick(string id)
    {
        if (!CanPick(id)) return;
        int slot = Array.IndexOf(_slots, id);
        if (slot >= 0) Vacate(slot);
        else Fill(_pickerSlot >= 0 && _slots[_pickerSlot] == null ? _pickerSlot : Array.IndexOf(_slots, null), id);
        _hovered = id;
        Refresh();
    }

    /// <summary>Clear the assembled party.</summary>
    public void Unpick()
    {
        if (OverlayOpen) return;
        for (int slot = 0; slot < _slots.Length; slot++)
            if (_slots[slot] != null) Vacate(slot);
        Refresh();
    }

    /// <summary>Whether choosing that character would do anything right now.</summary>
    public bool CanPick(string id) => GateFor(id) == null;

    /// <summary>Signal a snapshot of the complete formation.</summary>
    public void Embark()
    {
        if (CanEmbark && !OverlayOpen) Confirmed?.Invoke(SelectedIds.ToArray());
    }

    // ---------------------------------------------------------------- Slots

    private void Fill(int slot, string id)
    {
        if (slot < 0) return;
        _slots[slot] = id;
        _village.Residents.Release(id);
        _village.Lineup.Call(id, slot, walk: Assembling && IsVisibleInTree());
    }

    private void Vacate(int slot)
    {
        if (_slots[slot] is not { } id) return;
        _slots[slot] = null;
        _village.Lineup.Dismiss(id, walk: Assembling && IsVisibleInTree());
        _village.Residents.Admit(id);
    }

    /// <summary>Why choosing that character would do nothing, or null when it would work.</summary>
    private string? GateFor(string id)
    {
        if (CharacterCatalog.Find(id) == null) return "not on the roster";
        if (!_unlocks.IsUnlocked(id)) return "locked";
        if (_slots.Contains(id)) return null;
        return CanEmbark ? "remove a party member to make room" : null;
    }

    /// <summary>Unlocked roster members, in catalog order.</summary>
    private IEnumerable<string> Residents() =>
        CharacterCatalog.All.Where(def => _unlocks.IsUnlocked(def.Id)).Select(def => def.Id);

    // ---------------------------------------------------------------- Sheets

    private void ReadSheets()
    {
        bool dataReady = DataManager.Instance is { IsLoaded: true };
        foreach (var def in CharacterCatalog.All)
            if (!_sheets.ContainsKey(def.Id)) _sheets[def.Id] = ReadSheet(def, dataReady);
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

    /// <summary>
    /// Feature one character without choosing them: the resident Character details opens on.
    /// Public so the flow can be driven without synthetic input.
    /// </summary>
    public void Preview(string? id) => _hovered = id;

    /// <summary>The resident Character details opens on: the previewed one, then the first pick,
    /// then the first one the player could take.</summary>
    private string? ShownId() => _hovered ?? SelectedIds.FirstOrDefault() ?? Residents().FirstOrDefault(CanPick) ?? Residents().FirstOrDefault();
}
