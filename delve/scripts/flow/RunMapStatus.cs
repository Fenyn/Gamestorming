using System;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>Wardstone and party condition, separate from route rendering.</summary>
public partial class RunMapStatus : VBoxContainer
{
    [Export] public PackedScene MemberScene { get; set; } = null!;
    private Label _wardValue = null!;
    private Label _wardHint = null!;
    private ProgressBar _wardBar = null!;
    private Control _restSegment = null!;
    private VBoxContainer _party = null!;
    private Label _level = null!;
    private RunMapRecovery _recovery = null!;
    private Wardstone? _ward;
    public event Action? RestPressed;
    public override void _Ready()
    {
        _wardValue = GetNode<Label>("%WardValue");
        _wardHint = GetNode<Label>("%WardHint");
        _wardBar = GetNode<ProgressBar>("%WardBar");
        _restSegment = GetNode<Control>("%RestSegment");
        _party = GetNode<VBoxContainer>("%PartyStatus");
        _level = GetNode<Label>("%PartyLevel");
        _recovery = GetNode<RunMapRecovery>("%Recovery");
        _recovery.RestPressed += () => RestPressed?.Invoke();
        _recovery.RestPreviewChanged += ShowRestPreview;
    }

    public void Render(RunState state)
    {
        var ward = state.Wardstone;
        _ward = ward;
        _recovery.Render(state);
        _wardValue.TooltipText = WardLines.RestPreview(ward);
        _wardBar.MaxValue = Math.Max(1, ward.Rules.MaxWard);
        _wardBar.Value = ward.Ward;
        _restSegment.AnchorLeft = (float)(ward.WardAfterShortRest / _wardBar.MaxValue);
        _restSegment.AnchorRight = (float)(ward.Ward / _wardBar.MaxValue);
        _wardBar.TooltipText = WardLines.RestPreview(ward);
        _wardHint.Text = ward.Upshift == 0 ? "The ward holds."
            : $"Encounter threat +{ward.Upshift} {(ward.Upshift == 1 ? "tier" : "tiers")}.";
        _wardHint.TooltipText = "As ward falls, skirmishes and lairs become more dangerous.\n"
            + "Boss fights are unaffected. Defeating a floor boss fully restores ward.";
        _level.Text = $"Level {state.Party.Level}  ·  {state.Party.Members.Count} / {Party.MaxSize} members";
        _level.TooltipText = $"Party experience: {state.Xp} / {state.Leveling.XpPerLevel}";
        foreach (var child in _party.GetChildren())
        {
            _party.RemoveChild(child);
            child.QueueFree();
        }
        foreach (var member in state.Party.Members)
        {
            var row = MemberScene.Instantiate<MapPartyMember>();
            _party.AddChild(row);
            row.Render(member);
        }

    }

    private void ShowRestPreview(bool preview)
    {
        if (_ward == null) return;
        preview &= _ward.CanAffordShortRest;
        _wardValue.Text = $"{(preview ? _ward.WardAfterShortRest : _ward.Ward)} / {_ward.Rules.MaxWard}";
        _wardValue.ThemeTypeVariation = preview ? "MapWardPreviewValue" : "MapWardValue";
        _restSegment.Visible = preview;
    }
}
