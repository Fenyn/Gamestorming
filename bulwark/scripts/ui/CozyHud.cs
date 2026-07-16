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
        ("C·B·I·G·K·T·F·J·N", "Squad·Build·Bag·Smithy·Craft·Store·Bonds·Quests·Calendar"),
    };

    /// <summary>Intent: player pressed the HUD zoom-in (+) button. Host scene applies the camera zoom.</summary>
    public event Action? ZoomInRequested;

    /// <summary>Intent: player pressed the HUD zoom-out (−) button. Host scene applies the camera zoom.</summary>
    public event Action? ZoomOutRequested;

    /// <summary>Intent: player clicked the clock/date box. Host scene toggles the calendar panel.</summary>
    public event Action? ClockClicked;

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
    private Control _timeBox = null!;

    // --- Quest banner (top-center, below the clock row) ---
    private PanelContainer _questBannerPanel = null!;
    private Label _questBannerHeadline = null!;
    private Label _questBannerTitle = null!;
    private Tween? _questBannerTween;
    private readonly Queue<(string Headline, string Title)> _questBannerQueue = new();
    private bool _questBannerShowing;

    // --- Item pickup feed (bottom-left, stacking) ---
    private VBoxContainer _itemFeedList = null!;
    private readonly List<ItemFeedRow> _itemFeedRows = new();

    // --- Interaction prompt (above the hotbar) ---
    private PanelContainer _interactionPrompt = null!;
    private Label _interactionPromptLabel = null!;

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

        _timeBox = GetNode<Control>("%TimeBox");
        _timeBox.GuiInput += OnTimeBoxGuiInput;

        _questBannerPanel = GetNode<PanelContainer>("%QuestBannerPanel");
        _questBannerHeadline = GetNode<Label>("%QuestBannerHeadline");
        _questBannerTitle = GetNode<Label>("%QuestBannerTitleLabel");

        _itemFeedList = GetNode<VBoxContainer>("%ItemFeedList");

        _interactionPrompt = GetNode<PanelContainer>("%InteractionPrompt");
        _interactionPromptLabel = GetNode<Label>("%InteractionPromptLabel");

        GetNode<Button>("%ZoomInButton").Pressed += () => ZoomInRequested?.Invoke();
        GetNode<Button>("%ZoomOutButton").Pressed += () => ZoomOutRequested?.Invoke();

        _fade.Color = new Color(0f, 0f, 0f, 0f);
        _toastPanel.Visible = false;
        _inventoryPanel.Visible = false;
        _questBannerPanel.Visible = false;
        _interactionPrompt.Visible = false;
    }

    private void OnTimeBoxGuiInput(InputEvent @event)
    {
        if (@event is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left })
            ClockClicked?.Invoke();
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

    // ------------------------------------------------------------------ Quest banner

    private const float QuestBannerRestingOffsetTop = 16f;
    private const float QuestBannerSlideDistance = 24f;
    private const float QuestBannerFadeInSeconds = 0.3f;
    private const float QuestBannerHoldSeconds = 3.0f;
    private const float QuestBannerFadeOutSeconds = 0.4f;

    /// <summary>
    /// Flash the quest-lifecycle banner (headline + quest title) — a more prominent notice than
    /// <see cref="ShowToast"/> for "New Quest" / "Quest Complete". Slides + fades in, holds, fades
    /// out. A banner raised while one is already showing QUEUES behind it (FIFO) instead of
    /// interrupting, so two quest events landing close together both get their moment.
    /// </summary>
    public void ShowQuestBanner(string headline, string questTitle)
    {
        _questBannerQueue.Enqueue((headline, questTitle));
        if (!_questBannerShowing)
            PlayNextQuestBanner();
    }

    private void PlayNextQuestBanner()
    {
        if (_questBannerQueue.Count == 0)
        {
            _questBannerShowing = false;
            return;
        }

        _questBannerShowing = true;
        var (headline, title) = _questBannerQueue.Dequeue();
        _questBannerHeadline.Text = headline;
        _questBannerTitle.Text = title;
        _questBannerPanel.Visible = true;
        _questBannerPanel.Modulate = new Color(1f, 1f, 1f, 0f);
        _questBannerPanel.OffsetTop = QuestBannerRestingOffsetTop - QuestBannerSlideDistance;

        _questBannerTween?.Kill();
        _questBannerTween = CreateTween();
        _questBannerTween.SetParallel(true);
        _questBannerTween.TweenProperty(_questBannerPanel, "modulate:a", 1f, QuestBannerFadeInSeconds);
        _questBannerTween.TweenProperty(_questBannerPanel, "offset_top", QuestBannerRestingOffsetTop, QuestBannerFadeInSeconds);
        _questBannerTween.SetParallel(false);
        _questBannerTween.TweenInterval(QuestBannerHoldSeconds);
        _questBannerTween.TweenProperty(_questBannerPanel, "modulate:a", 0f, QuestBannerFadeOutSeconds);
        _questBannerTween.TweenCallback(Callable.From(() =>
        {
            _questBannerPanel.Visible = false;
            PlayNextQuestBanner();
        }));
    }

    // ------------------------------------------------------------------ Item pickup feed

    /// <summary>Gains of the same item within this window merge into the existing row (updated count,
    /// fade timer restarted) instead of spamming a new row per pickup.</summary>
    private const double ItemFeedAggregateWindowSeconds = 1.5;

    /// <summary>How long a row stays fully visible before it starts fading (restarted on every merge).</summary>
    private const float ItemFeedHoldSeconds = 2.2f;

    private const float ItemFeedFadeSeconds = 0.4f;

    /// <summary>At most this many rows are visible; the oldest fades out to make room for a new one.</summary>
    private const int ItemFeedMaxRows = 4;

    private sealed class ItemFeedRow
    {
        public PanelContainer Panel = null!;
        public Label Label = null!;
        public string DisplayName = "";
        public int Qty;
        public ulong LastUpdateMs;
        public Tween? FadeTween;
    }

    /// <summary>
    /// Stack an inventory-gain row into the bottom-left feed ("+3 Wood"). A gain of the same item
    /// within <see cref="ItemFeedAggregateWindowSeconds"/> of that row's last update merges into it
    /// (summed count, fade timer restarted) rather than adding a new line. Once more than
    /// <see cref="ItemFeedMaxRows"/> rows are showing, the oldest fades out.
    /// </summary>
    public void ShowItemGain(string displayName, int qty)
    {
        if (qty == 0)
            return;

        ulong now = Time.GetTicksMsec();
        ulong windowMs = (ulong)(ItemFeedAggregateWindowSeconds * 1000.0);
        foreach (var row in _itemFeedRows)
        {
            if (row.DisplayName != displayName || now - row.LastUpdateMs > windowMs)
                continue;
            row.Qty += qty;
            row.LastUpdateMs = now;
            row.Label.Text = $"+{row.Qty} {row.DisplayName}";
            RestartRowFade(row);
            return;
        }

        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var label = new Label { Text = $"+{qty} {displayName}" };
        label.AddThemeFontSizeOverride("font_size", 15);
        panel.AddChild(label);
        _itemFeedList.AddChild(panel);

        var newRow = new ItemFeedRow
        {
            Panel = panel,
            Label = label,
            DisplayName = displayName,
            Qty = qty,
            LastUpdateMs = now,
        };
        _itemFeedRows.Add(newRow);
        RestartRowFade(newRow);

        while (_itemFeedRows.Count > ItemFeedMaxRows)
        {
            var oldest = _itemFeedRows[0];
            _itemFeedRows.RemoveAt(0);
            FadeOutRow(oldest, ItemFeedFadeSeconds * 0.5f);
        }
    }

    private void RestartRowFade(ItemFeedRow row)
    {
        row.FadeTween?.Kill();
        row.Panel.Modulate = new Color(1f, 1f, 1f, 1f);
        row.FadeTween = CreateTween();
        row.FadeTween.TweenInterval(ItemFeedHoldSeconds);
        row.FadeTween.TweenProperty(row.Panel, "modulate:a", 0f, ItemFeedFadeSeconds);
        row.FadeTween.TweenCallback(Callable.From(() => RemoveItemFeedRow(row)));
    }

    private void FadeOutRow(ItemFeedRow row, float seconds)
    {
        row.FadeTween?.Kill();
        row.FadeTween = CreateTween();
        row.FadeTween.TweenProperty(row.Panel, "modulate:a", 0f, seconds);
        row.FadeTween.TweenCallback(Callable.From(() => RemoveItemFeedRow(row)));
    }

    private void RemoveItemFeedRow(ItemFeedRow row)
    {
        _itemFeedRows.Remove(row);
        if (GodotObject.IsInstanceValid(row.Panel))
            row.Panel.QueueFree();
    }

    // ------------------------------------------------------------------ Interaction prompt

    /// <summary>
    /// Floating "E — «hint»" prompt near the hotbar — what an interact press would do right now.
    /// Null/empty hides it. The host scene polls its (world-scene-specific) proximity checks on a
    /// modest cadence and pushes the result here; this Control stays passive.
    /// </summary>
    public void SetInteractionPrompt(string? hint)
    {
        if (string.IsNullOrEmpty(hint))
        {
            _interactionPrompt.Visible = false;
            return;
        }
        _interactionPromptLabel.Text = $"E — {hint}";
        _interactionPrompt.Visible = true;
    }
}
