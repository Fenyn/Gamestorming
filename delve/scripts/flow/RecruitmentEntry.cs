using System;
using System.Linq;
using Delve.Run;
using Godot;

namespace Delve.Flow;

/// <summary>One recruitment arc and its explicit outpost stay action.</summary>
public partial class RecruitmentEntry : VBoxContainer
{
    private Label _title = null!;
    private Label _steps = null!;
    private Button _stay = null!;
    private string _id = "";

    public event Action<string>? StayRequested;

    public override void _Ready()
    {
        _title = GetNode<Label>("%RecruitTitle");
        _steps = GetNode<Label>("%RecruitSteps");
        _stay = GetNode<Button>("%StayButton");
        _stay.Pressed += () => StayRequested?.Invoke(_id);
    }

    public void ShowProgress(RecruitmentArc arc, CampaignProgress campaign)
    {
        _id = arc.CharacterId;
        _title.Text = $"{CharacterCatalog.Find(_id)?.DisplayName}: {arc.Title}";
        bool unlocked = campaign.Unlocks.IsUnlocked(_id);
        _steps.Text = unlocked ? "Permanently available for future expeditions."
            : string.Join("\n", arc.Steps.Select(step =>
                $"{campaign.RecruitmentCount(_id, step.Id)}/{step.Required}  {step.Description}"));
        _stay.Visible = !unlocked;
        _stay.Disabled = !campaign.CanBindAtOutpost(_id);
        _stay.TooltipText = _stay.Disabled ? "Unavailable: complete the recruitment requirements first"
            : "An overnight stay at the outpost makes this character permanently available";
    }
}
