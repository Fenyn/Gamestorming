using Bulwark.Cozy;
using Godot;

using Bulwark.Quests;
namespace Bulwark.UI;

public partial class QuestPanel : TogglePanel
{
    private VBoxContainer _body = null!;

    public QuestPanel() => ToggleAction = "toggle_quest_panel";

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        Visible = false;
    }

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
}
