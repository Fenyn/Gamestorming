using System.Collections.Generic;
using Godot;

namespace Ungilded.UI;

/// <summary>One hero on the results screen: name and the pairs that changed.</summary>
public partial class ResultMemberRowView : HBoxContainer
{
    [Export] public PackedScene? FigureScene { get; set; }

    private Label _name = null!;
    private HBoxContainer _figures = null!;

    public string MemberName => _name.Text;

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
    }

    public void Render(ResultMemberRow row)
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
    }
}
