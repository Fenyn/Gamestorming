using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

public partial class HeroSelectPanel
{
    private const string DelveStation = "delve";
    private const string UnlocksStation = "unlocks";
    private const string BestiaryStation = "bestiary";

    private void SetupVillage()
    {
        var tier = TownTierOverride ?? _campaign?.TownTier ?? TownTier.Camp;
        var time = _campaign?.CampTime ?? CampTimeOfDay.Morning;
        Assembling = false;
        _village.Lineup.Clear();
        _village.ApplyTier(tier);
        _village.Residents.Place(Residents().ToList(), time, tier);
        _village.ApplyTime(time);
        _village.GoHome();
    }

    /// <summary>Walk the camera to the trailhead and open the four slots.</summary>
    public void EnterAssembly()
    {
        if (OverlayOpen || Assembling) return;
        Assembling = true;
        _village.Browsing = false;
        _village.GoTo(_village.AssemblyStop);
        Refresh();
        UiFocus.Grab(GetNode<Control>("%Squad").GetChildren().OfType<Control>().FirstOrDefault());
    }

    /// <summary>Back to the town view. The picks stay in their slots, as XCOM keeps a squad.</summary>
    public void LeaveAssembly()
    {
        if (!Assembling) return;
        Assembling = false;
        _picker.Close();
        _village.GoHome(ease: true);
        Refresh();
    }

    /// <summary>Open the roster on one slot: everyone free to take it.</summary>
    public void OpenPicker(int slot)
    {
        if (OverlayOpen || slot < 0 || slot >= _slots.Length) return;
        _pickerSlot = slot;
        var entries = Residents().Where(id => !_slots.Contains(id))
            .Select(id => new RosterPicker.Entry(id, CharacterCatalog.Find(id)!.DisplayName, ClassWord(id))).ToList();
        _picker.ShowVacate(_slots[slot] != null);
        _picker.Open(entries, slot, GetNode<Control>("%Squad").GetChild<Control>(slot));
    }

    /// <summary>The roster's choice takes the slot it was opened on, sending any occupant back to town.</summary>
    private void ChooseFromPicker(string id)
    {
        int slot = _pickerSlot;
        if (slot < 0) return;
        if (_slots[slot] != null) Vacate(slot);
        if (!CanPick(id)) return;
        Fill(slot, id);
        _hovered = id;
        _picker.Close();
        Refresh();
    }

    private void VacatePickerSlot()
    {
        if (_pickerSlot < 0) return;
        Vacate(_pickerSlot);
        _picker.Close();
        Refresh();
    }

    private void OnStation(string id)
    {
        if (OverlayOpen) return;
        switch (id)
        {
            case DelveStation: EnterAssembly(); break;
            case UnlocksStation: OpenJournal(JournalScreen.UnlocksPage); break;
            case BestiaryStation: OpenJournal(JournalScreen.BestiaryPage); break;
        }
    }

    /// <summary>
    /// Repaint the slots, the gate line and Embark from the one choice. Each disabled control names
    /// the gate that failed (design/ui_guidelines.md section 7).
    /// </summary>
    private void Refresh()
    {
        int count = SelectedIds.Count;
        GetNode<Label>("%PartyCount").Text = $"PARTY  {count} / {Party.MaxSize}";
        _assemble.Text = $"To the Delve  {count}/{Party.MaxSize}";
        _embark.Disabled = !CanEmbark;
        _embark.TooltipText = CanEmbark ? "" : "Unavailable: choose four party members";
        _clearParty.Disabled = count == 0;
        _clearParty.TooltipText = count == 0 ? "Unavailable: nobody is in the party" : "";
        _town.Visible = !Assembling;
        _assembly.Visible = Assembling;
        RenderSquad();
    }

    /// <summary>The four slots: each pick as a face tile, then empty slots; any tile opens the roster on its slot.</summary>
    private void RenderSquad()
    {
        var squad = GetNode<Control>("%Squad");
        foreach (var child in squad.GetChildren()) { squad.RemoveChild(child); child.QueueFree(); }
        if (SquadTileScene == null) return;
        for (int slot = 0; slot < _slots.Length; slot++)
        {
            var tile = SquadTileScene.Instantiate<MemberTile>();
            tile.ToggleMode = false;
            squad.AddChild(tile);
            if (_slots[slot] is { } id && CharacterCatalog.Find(id) is { } def)
                tile.Show(def.Id, def.DisplayName, ClassWord(def.Id), false);
            else tile.Show("", "Empty slot", "", false);
            int index = slot;
            tile.Pressed += () => OpenPicker(index);
        }
    }

    public override void _Input(InputEvent input)
    {
        if (!IsVisibleInTree() || OverlayOpen) return;
        if (input.IsActionPressed(InputNames.ExploreJournal)) OpenJournal(JournalScreen.BestiaryPage);
        else if (input.IsActionPressed(InputNames.ExploreDescend))
        {
            if (Assembling) Embark();
            else EnterAssembly();
        }
        else if (Assembling && input.IsActionPressed(InputNames.UiCancel)) LeaveAssembly();
        else return;
        GetViewport().SetInputAsHandled();
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        _village.Browsing = !Assembling && !OverlayOpen;
    }
}
