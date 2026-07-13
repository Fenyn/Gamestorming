using System;
using System.Collections.Generic;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive cozy-mode HUD. Renders only the strings/values fed to it via the setter methods below —
/// it never touches <see cref="Bulwark.Autoload.GameState"/>, the systems, or engine game types.
/// The outpost scene subscribes to the state-change events and pushes view-model data here, keeping
/// this Control free of game rules per CLAUDE.md. Also owns the sleep fade + wake toast overlay.
/// Layout: clock/date box top-right, tool hotbar bottom-center (Stardew-style slot row), inventory
/// readout bottom-right, centered toast panel for day-transition and event notices.
/// </summary>
public partial class CozyHud : CanvasLayer
{
    /// <summary>
    /// Upper-left controls legend rows — render data only, mirroring the cozy bindings in
    /// project.godot's input map + <see cref="Bulwark.Cozy.PlayerController"/> mouse handling.
    /// </summary>
    private static readonly (string Keys, string Action)[] LegendRows =
    {
        ("WASD", "Move"),
        ("LMB / RMB / E", "Use tool · Interact"),
        ("1-6 / Tab / Wheel", "Select tool"),
        ("Q", "Cycle seed"),
        ("C·B·I·G·K·T", "Squad·Build·Bag·Smithy·Craft·Store"),
    };

    /// <summary>Intent: player pressed the HUD zoom-in (+) button. Host scene applies the camera zoom.</summary>
    public event Action? ZoomInRequested;

    /// <summary>Intent: player pressed the HUD zoom-out (−) button. Host scene applies the camera zoom.</summary>
    public event Action? ZoomOutRequested;

    private Label _time = null!;
    private Label _date = null!;
    private Label _tool = null!;
    private Label _seed = null!;
    private Label _inventory = null!;
    private PanelContainer _inventoryPanel = null!;
    private ColorRect _fade = null!;
    private Label _toast = null!;
    private PanelContainer _toastPanel = null!;
    private readonly PanelContainer[] _slots = new PanelContainer[6];
    private InputLegend _legend = null!;
    private Tween? _toastTween;

    public override void _Ready()
    {
        _time = GetNode<Label>("%TimeLabel");
        _date = GetNode<Label>("%DateLabel");
        _tool = GetNode<Label>("%ToolLabel");
        _seed = GetNode<Label>("%SeedLabel");
        _inventory = GetNode<Label>("%InventoryLabel");
        _inventoryPanel = GetNode<PanelContainer>("%InventoryPanel");
        _fade = GetNode<ColorRect>("%FadeRect");
        _toast = GetNode<Label>("%ToastLabel");
        _toastPanel = GetNode<PanelContainer>("%ToastPanel");
        for (int i = 0; i < _slots.Length; i++)
            _slots[i] = GetNode<PanelContainer>($"%Slot{i}");

        _legend = GetNode<InputLegend>("%ControlsLegend");
        _legend.SetRows(LegendRows);

        GetNode<Button>("%ZoomInButton").Pressed += () => ZoomInRequested?.Invoke();
        GetNode<Button>("%ZoomOutButton").Pressed += () => ZoomOutRequested?.Invoke();

        _fade.Color = new Color(0f, 0f, 0f, 0f);
        _toastPanel.Visible = false;
        _inventoryPanel.Visible = false;
    }

    /// <summary>Show/hide the upper-left controls legend (default visible).</summary>
    public void SetLegendVisible(bool visible) => _legend.Visible = visible;

    /// <summary>Top-right time-of-day and calendar date.</summary>
    public void SetTimeDate(string time, string date)
    {
        _time.Text = time;
        _date.Text = date;
    }

    /// <summary>
    /// Highlight the hotbar slot at <paramref name="activeSlot"/> (ToolBelt hotbar order — the host
    /// scene feeds <c>Tools.CurrentIndex</c>) and (for the Seeds tool) show the selected seed + held
    /// count in the caption under the bar.
    /// </summary>
    public void SetTool(int activeSlot, string toolName, string? seedName, int seedCount)
    {
        for (int i = 0; i < _slots.Length; i++)
            _slots[i].ThemeTypeVariation = i == activeSlot ? "HotbarSlotSelected" : "HotbarSlot";

        _tool.Text = toolName;
        bool hasSeed = seedName != null;
        _seed.Visible = hasSeed;
        _seed.Text = hasSeed ? $"— {seedName} x{seedCount}" : string.Empty;
    }

    /// <summary>Bottom-right inventory readout (one "name xN" line per non-zero stack).</summary>
    public void SetInventory(IReadOnlyList<(string Name, int Count)> items)
    {
        if (items.Count == 0)
        {
            _inventory.Text = string.Empty;
            _inventoryPanel.Visible = false;
            return;
        }

        var parts = new List<string>(items.Count);
        foreach (var it in items)
            parts.Add($"{it.Name} x{it.Count}");
        _inventory.Text = string.Join("\n", parts);
        _inventoryPanel.Visible = true;
    }

    /// <summary>
    /// Flash a transient center-screen toast (travel notices, harvest results, encounter starts,
    /// defeat wake summaries). A newer toast replaces a still-visible one.
    /// </summary>
    public void ShowToast(string text, float seconds = 2.5f)
    {
        _toastTween?.Kill();
        _toast.Text = text;
        _toastPanel.Visible = true;

        _toastTween = CreateTween();
        _toastTween.TweenInterval(seconds);
        _toastTween.TweenCallback(Callable.From(() => _toastPanel.Visible = false));
    }

    /// <summary>
    /// Fade to black, run <paramref name="atBlack"/> at the darkest point (the caller mutates state
    /// there — e.g. GameState.Sleep), then fade back in while flashing a wake toast whose text is
    /// pulled after the mutation via <paramref name="wakeText"/>. Purely presentational.
    /// </summary>
    public void PlaySleepTransition(Action atBlack, Func<string> wakeText)
    {
        _toastTween?.Kill(); // a lingering ShowToast must not hide the wake text mid-flash
        _toastPanel.Visible = false;

        Tween tween = CreateTween();
        tween.TweenProperty(_fade, "color", new Color(0f, 0f, 0f, 1f), 0.5f);
        tween.TweenCallback(Callable.From(() =>
        {
            atBlack?.Invoke();
            _toast.Text = wakeText?.Invoke() ?? string.Empty;
            _toastPanel.Visible = true;
        }));
        tween.TweenInterval(0.7);
        tween.TweenProperty(_fade, "color", new Color(0f, 0f, 0f, 0f), 0.6f);
        tween.TweenInterval(0.9);
        tween.TweenCallback(Callable.From(() => _toastPanel.Visible = false));
    }
}
