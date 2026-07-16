using System;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive calendar modal: renders the current season's 28 days in a 7×4 grid from a
/// <see cref="CalendarView"/> pushed via <see cref="Render"/>. Today's cell gets the hotbar's gold
/// "selected" styling reused as a highlight border; each day's marks (birthdays, construction
/// completions) render as small clipped lines under the day number. Same modal CanvasLayer pattern
/// as QuestPanel/BuildPanel — toggled by the "toggle_calendar_panel" hotkey (N) or by the host
/// forwarding the HUD's clock-click (<see cref="CozyHud.ClockClicked"/>); Esc closes.
/// </summary>
public partial class CalendarPanel : CanvasLayer
{
    public event Action<bool>? Toggled;

    private Label _titleLabel = null!;
    private GridContainer _grid = null!;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("%TitleLabel");
        _grid = GetNode<GridContainer>("%DayGrid");
        Visible = false;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("toggle_calendar_panel"))
        {
            Toggle();
            GetViewport().SetInputAsHandled();
        }
        else if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            Close();
            GetViewport().SetInputAsHandled();
        }
    }

    public void Open()
    {
        if (Visible)
            return;
        Visible = true;
        Toggled?.Invoke(true);
    }

    /// <summary>Host command: close the panel if open (fires Toggled(false) so the host unfreezes).</summary>
    public void Close()
    {
        if (!Visible)
            return;
        Visible = false;
        Toggled?.Invoke(false);
    }

    /// <summary>Flip open/closed — the seam the HUD's clock-click drives (as opposed to the panel's
    /// own hotkey, which always means "open the way I want it").</summary>
    public void Toggle()
    {
        if (Visible)
            Close();
        else
            Open();
    }

    /// <summary>Render a fresh calendar view — rebuilds all 28 day cells from the view-model.</summary>
    public void Render(CalendarView view)
    {
        _titleLabel.Text = $"Calendar — {view.Season}, Year {view.Year}";

        foreach (Node child in _grid.GetChildren())
            child.QueueFree();

        foreach (var day in view.Days)
            _grid.AddChild(BuildDayCell(day));
    }

    // ------------------------------------------------------------------ Cell construction (view only)

    private static Control BuildDayCell(CalendarDayView day)
    {
        var panel = new PanelContainer
        {
            ThemeTypeVariation = day.IsToday ? "HotbarSlotSelected" : "InnerPanel",
            CustomMinimumSize = new Vector2(84, 64),
        };

        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 2);
        panel.AddChild(col);

        col.AddChild(new Label
        {
            Text = day.Day.ToString(),
            HorizontalAlignment = HorizontalAlignment.Center,
            ThemeTypeVariation = "TitleLabel",
        });

        foreach (string mark in day.Marks)
        {
            col.AddChild(new Label
            {
                Text = mark,
                ThemeTypeVariation = "HintLabel",
                HorizontalAlignment = HorizontalAlignment.Center,
                ClipText = true,
                TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis,
                AutowrapMode = TextServer.AutowrapMode.Off,
            });
        }

        return panel;
    }
}
