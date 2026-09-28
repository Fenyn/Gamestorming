using System.Collections.Generic;
using Delve.Combat;
using Delve.Flow;
using Godot;

namespace Delve.UI;

/// <summary>A result in pair style: party figures on one row ("Ward 85 → 70"), then one row per
/// changed hero ("Elara  HP 1 → 14"). Shared by the rest and morning reports.</summary>
public partial class PairReport : VBoxContainer
{
    [Export] public PackedScene? FigureScene { get; set; }
    [Export] public PackedScene? RowScene { get; set; }

    private HBoxContainer _figures = null!;
    private VBoxContainer _members = null!;

    public override void _Ready()
    {
        _figures = GetNode<HBoxContainer>("%ReportFigures");
        _members = GetNode<VBoxContainer>("%ReportMembers");
    }

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

    public IReadOnlyList<ResultMemberRowView> MemberRows
    {
        get
        {
            var rows = new List<ResultMemberRowView>();
            foreach (var child in _members.GetChildren())
                if (child is ResultMemberRowView row) rows.Add(row);
            return rows;
        }
    }

    public void Render(IReadOnlyList<FigureView> figures, IReadOnlyList<ResultMemberRow> rows)
    {
        Clear(_figures);
        Clear(_members);
        if (FigureScene != null)
            foreach (var figure in figures)
            {
                var label = FigureScene.Instantiate<FigureLabel>();
                _figures.AddChild(label);
                label.Render(figure);
            }
        if (RowScene != null)
            foreach (var row in rows)
            {
                var view = RowScene.Instantiate<ResultMemberRowView>();
                _members.AddChild(view);
                view.Render(row, offerFeat: false);
            }
        _figures.Visible = figures.Count > 0;
        _members.Visible = rows.Count > 0;
        Visible = true;
    }

    private static void Clear(Node host)
    {
        foreach (var child in host.GetChildren()) { host.RemoveChild(child); child.QueueFree(); }
    }
}
