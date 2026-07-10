using System;
using System.Collections.Generic;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive cozy-mode HUD. Renders only the strings/values fed to it via the setter methods below —
/// it never touches <see cref="Bulwark.Autoload.GameState"/>, the systems, or engine game types.
/// The outpost scene subscribes to the state-change events and pushes view-model data here, keeping
/// this Control free of game rules per CLAUDE.md. Also owns the sleep fade + wake toast overlay.
/// </summary>
public partial class CozyHud : CanvasLayer
{
    private Label _time = null!;
    private Label _date = null!;
    private Label _tool = null!;
    private Label _seed = null!;
    private Label _inventory = null!;
    private ColorRect _fade = null!;
    private Label _toast = null!;

    public override void _Ready()
    {
        _time = GetNode<Label>("%TimeLabel");
        _date = GetNode<Label>("%DateLabel");
        _tool = GetNode<Label>("%ToolLabel");
        _seed = GetNode<Label>("%SeedLabel");
        _inventory = GetNode<Label>("%InventoryLabel");
        _fade = GetNode<ColorRect>("%FadeRect");
        _toast = GetNode<Label>("%ToastLabel");

        _fade.Color = new Color(0f, 0f, 0f, 0f);
        _toast.Visible = false;
    }

    /// <summary>Top-right time-of-day and calendar date.</summary>
    public void SetTimeDate(string time, string date)
    {
        _time.Text = time;
        _date.Text = date;
    }

    /// <summary>Bottom-left active tool and (for the Seeds tool) the selected seed + held count.</summary>
    public void SetTool(string toolName, string? seedName, int seedCount)
    {
        _tool.Text = $"Tool: {toolName}";
        bool hasSeed = seedName != null;
        _seed.Visible = hasSeed;
        _seed.Text = hasSeed ? $"Seed: {seedName} x{seedCount}" : string.Empty;
    }

    /// <summary>Bottom inventory readout (name xN per non-zero stack).</summary>
    public void SetInventory(IReadOnlyList<(string Name, int Count)> items)
    {
        if (items.Count == 0)
        {
            _inventory.Text = string.Empty;
            return;
        }

        var parts = new List<string>(items.Count);
        foreach (var it in items)
            parts.Add($"{it.Name} x{it.Count}");
        _inventory.Text = string.Join("     ", parts);
    }

    /// <summary>
    /// Fade to black, run <paramref name="atBlack"/> at the darkest point (the caller mutates state
    /// there — e.g. GameState.Sleep), then fade back in while flashing a wake toast whose text is
    /// pulled after the mutation via <paramref name="wakeText"/>. Purely presentational.
    /// </summary>
    public void PlaySleepTransition(Action atBlack, Func<string> wakeText)
    {
        _toast.Visible = false;

        Tween tween = CreateTween();
        tween.TweenProperty(_fade, "color", new Color(0f, 0f, 0f, 1f), 0.5f);
        tween.TweenCallback(Callable.From(() =>
        {
            atBlack?.Invoke();
            _toast.Text = wakeText?.Invoke() ?? string.Empty;
            _toast.Visible = true;
        }));
        tween.TweenInterval(0.7);
        tween.TweenProperty(_fade, "color", new Color(0f, 0f, 0f, 0f), 0.6f);
        tween.TweenInterval(0.9);
        tween.TweenCallback(Callable.From(() => _toast.Visible = false));
    }
}
