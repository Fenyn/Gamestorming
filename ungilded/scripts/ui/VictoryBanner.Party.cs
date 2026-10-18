using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Ungilded.UI;

public partial class VictoryBanner
{
    private CombatResultsView _view = new();

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

    public string NotesText => _notes.Visible ? _notes.Text : "";

    private void RenderRows(CombatResultsView view)
    {
        _view = view;
        foreach (var child in _figures.GetChildren()) { _figures.RemoveChild(child); child.QueueFree(); }
        if (FigureScene != null)
            foreach (var figure in view.Figures)
            {
                var label = FigureScene.Instantiate<FigureLabel>();
                _figures.AddChild(label);
                label.Render(figure);
            }
        _figures.Visible = view.Figures.Count > 0;
        _progress.Visible = view.Progress != null;
        _progress.Value = view.Progress ?? 0;
        _notes.Text = string.Join("\n", view.Notes);
        _notes.Visible = view.Notes.Count > 0;
        RenderMembers();
    }

    private void RenderMembers()
    {
        foreach (var child in _members.GetChildren()) { _members.RemoveChild(child); child.QueueFree(); }
        if (RowScene != null)
            foreach (var member in _view.Members)
            {
                if (member.Figures.All(f => !f.IsChange)) continue;
                if (_members.GetChildCount() > 0) _members.AddChild(RuledRows.Rule());
                var row = RowScene.Instantiate<ResultMemberRowView>();
                _members.AddChild(row);
                row.Render(member);
            }
        _members.Visible = _members.GetChildCount() > 0;
    }
}
