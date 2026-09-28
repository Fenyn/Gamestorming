using System.Collections.Generic;
using Delve.Flow;
using Godot;

namespace Delve.UI;

public partial class SheetTooltip
{
    /// <summary>Before→after pairs under the title ("Ward 35 → 30"). Assigned in sheet_tooltip.tscn.</summary>
    [Export] public PackedScene? FigureScene { get; set; }

    public IReadOnlyList<FigureLabel> FigureLabels
    {
        get
        {
            var labels = new List<FigureLabel>();
            foreach (var child in GetNode<Control>("%Figures").GetChildren())
                if (child is FigureLabel label) labels.Add(label);
            return labels;
        }
    }

    /// <summary>The body paragraphs as printed, for spike checks.</summary>
    public string BodyText => string.Join("\n", Paragraphs());

    public string TitleText => _title.Text;
    public string SubtitleText => _subtitle.Visible ? _subtitle.Text : "";

    private IEnumerable<string> Paragraphs()
    {
        foreach (var child in _body.GetChildren())
            if (child is Label label) yield return label.Text.Replace("\n", " ");
    }

    private static bool SameContent(SheetTip a, SheetTip b)
        => a with { Figures = null } == b with { Figures = null }
           && System.Linq.Enumerable.SequenceEqual(a.Figures ?? System.Array.Empty<Delve.Combat.FigureView>(),
               b.Figures ?? System.Array.Empty<Delve.Combat.FigureView>());

    private void RenderFigures(SheetTip tip)
    {
        var host = GetNode<Control>("%Figures");
        Clear(host);
        if (FigureScene != null)
            foreach (var figure in tip.Figures ?? System.Array.Empty<Delve.Combat.FigureView>())
            {
                var label = FigureScene.Instantiate<FigureLabel>();
                host.AddChild(label);
                label.Render(figure);
            }
        host.Visible = host.GetChildCount() > 0;
    }
}
