using System;
using System.Collections.Generic;
using Delve.Run;
using Godot;

namespace Delve.Flow;

/// <summary>Save-wide recruitment requirements. Requests stays without changing campaign state.</summary>
public partial class RecruitmentPanel : Control
{
    [Export] public PackedScene? EntryScene { get; set; }
    private VBoxContainer _entries = null!;
    private readonly List<RecruitmentEntry> _rows = new();
    public event Action<string>? StayRequested;

    public override void _Ready()
    {
        _entries = GetNode<VBoxContainer>("%RecruitEntries");
        GetNode<Button>("%CloseRecruitment").Pressed += Hide;
    }

    public void Open()
    {
        Show();
        GetNode<Button>("%CloseRecruitment").GrabFocus();
    }

    public void Setup(CampaignProgress campaign)
    {
        foreach (var row in _rows)
        {
            _entries.RemoveChild(row);
            row.QueueFree();
        }
        _rows.Clear();
        if (EntryScene == null) { GD.PushError("[Recruitment] EntryScene is not assigned."); return; }
        foreach (var arc in RecruitmentCatalog.All)
        {
            var row = EntryScene.Instantiate<RecruitmentEntry>();
            _entries.AddChild(row);
            row.ShowProgress(arc, campaign);
            row.StayRequested += id => StayRequested?.Invoke(id);
            _rows.Add(row);
        }
    }
}
