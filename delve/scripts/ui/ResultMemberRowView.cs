using System;
using System.Collections.Generic;
using Delve.Flow;
using Godot;

namespace Delve.UI;

/// <summary>One hero on the results screen: name, the pairs that changed, and "Choose feat".</summary>
public partial class ResultMemberRowView : HBoxContainer
{
    [Export] public PackedScene? FigureScene { get; set; }
    public event Action? ChooseFeatPressed;

    private Label _name = null!;
    private HBoxContainer _figures = null!;
    private Button _chooseFeat = null!;

    public string MemberName => _name.Text;
    public Button ChooseFeat => _chooseFeat;

    public IReadOnlyList<FigureLabel> FigureLabels
    {
        get
        {
            var labels = new List<FigureLabel>();
            foreach (var child in _figures.GetChildren())
                if (child is FigureLabel label) labels.Add(label);
            return labels;
        }
    }

    public override void _Ready()
    {
        _name = GetNode<Label>("%Name");
        _figures = GetNode<HBoxContainer>("%Figures");
        _chooseFeat = GetNode<Button>("%ChooseFeat");
        _chooseFeat.Pressed += () => ChooseFeatPressed?.Invoke();
    }

    public void Render(ResultMemberRow row, bool offerFeat = true)
    {
        _name.Text = row.Member.Name;
        GetNode<TextureRect>("%Face").Texture = HeroPortraits.Face(row.Member.Id);
        foreach (var child in _figures.GetChildren()) { _figures.RemoveChild(child); child.QueueFree(); }
        if (FigureScene != null)
            foreach (var figure in row.Figures)
            {
                var label = FigureScene.Instantiate<FigureLabel>();
                _figures.AddChild(label);
                label.Render(figure);
            }
        _chooseFeat.Visible = offerFeat && CombatResults.HasFeatChoice(row.Member);
    }
}
