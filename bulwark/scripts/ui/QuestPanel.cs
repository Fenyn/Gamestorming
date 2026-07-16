using System;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

public partial class QuestPanel : CanvasLayer
{
    public event Action<bool>? Toggled;

    private VBoxContainer _body = null!;

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        Visible = false;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("toggle_quest_panel"))
        {
            SetOpen(!Visible);
            GetViewport().SetInputAsHandled();
        }
        else if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            SetOpen(false);
            GetViewport().SetInputAsHandled();
        }
    }

    public void Close() => SetOpen(false);

    public void Render(QuestView view)
    {
        foreach (Node child in _body.GetChildren())
            child.QueueFree();

        if (view.Active.Count == 0 && view.Completed.Count == 0)
        {
            _body.AddChild(new Label
            {
                Text = "No quests yet.",
                ThemeTypeVariation = "HintLabel",
            });
            return;
        }

        if (view.Active.Count > 0)
        {
            _body.AddChild(new Label
            {
                Text = "Active Quests",
                ThemeTypeVariation = "TitleLabel",
            });

            foreach (var quest in view.Active)
                _body.AddChild(BuildQuestCard(quest, false));
        }

        if (view.Completed.Count > 0)
        {
            _body.AddChild(new Label
            {
                Text = "Completed",
                ThemeTypeVariation = "TitleLabel",
                Modulate = new Color(0.6f, 0.6f, 0.6f),
            });

            foreach (var quest in view.Completed)
                _body.AddChild(BuildQuestCard(quest, true));
        }
    }

    private static Control BuildQuestCard(QuestEntryView quest, bool completed)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        if (completed)
            panel.Modulate = new Color(0.6f, 0.6f, 0.6f);

        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 4);
        panel.AddChild(col);

        col.AddChild(new Label
        {
            Text = completed ? $"{quest.Title} (Complete)" : quest.Title,
            ThemeTypeVariation = "TitleLabel",
        });

        foreach (var obj in quest.Objectives)
        {
            string check = obj.Done ? "[x]" : "[ ]";
            string progress = obj.Target > 1
                ? $"{check} {obj.Description}: {obj.Progress}/{obj.Target}"
                : $"{check} {obj.Description}";
            col.AddChild(new Label
            {
                Text = progress,
                ThemeTypeVariation = "HintLabel",
            });
        }

        return panel;
    }

    private void SetOpen(bool open)
    {
        if (Visible == open)
            return;
        Visible = open;
        Toggled?.Invoke(open);
    }
}
