using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>One compact number: an 18 px caption beside a 27 px value, or a dim before value, an arrow and the after value.</summary>
public partial class FigureLabel : HBoxContainer
{
    private Label _caption = null!;
    private Label _before = null!;
    private Label _arrow = null!;
    private Label _value = null!;

    public string CaptionText => _caption.Text;
    public string BeforeText => _before.Visible ? _before.Text : "";
    public string ValueText => _value.Text;
    public string MaxText => _max.Visible ? _max.Text : "";
    private Label _max = null!;

    public override void _Ready()
    {
        _caption = GetNode<Label>("%Caption");
        _before = GetNode<Label>("%Before");
        _arrow = GetNode<Label>("%Arrow");
        _value = GetNode<Label>("%Value");
        _max = GetNode<Label>("%Max");
    }

    public void Render(FigureView figure)
    {
        _caption.Text = figure.Caption;
        _before.Text = figure.Before;
        _before.Visible = figure.IsChange;
        _arrow.Visible = figure.IsChange;
        _value.Text = figure.Value;
        _max.Text = $"/ {figure.Max}";
        _max.Visible = figure.Max.Length > 0;
    }
}
