using System;
using System.Text;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive FRIENDSHIP screen: one row per befriendable, present character with heart pips (0–10),
/// talked-today / gifts-this-week indicators, and a birthday marker; plus the near-a-villager GIFT
/// flow — when the host says a villager is nearby, each carried stack gets a "Give" button that
/// raises <see cref="GiftRequested"/> (forwarded to GameState.GiveGift). Renders the
/// <see cref="FriendshipView"/> pushed via <see cref="Render"/> — no game rules, no engine types,
/// per CLAUDE.md. Toggled by the "toggle_friendship_panel" input action (F); Esc closes.
/// </summary>
public partial class FriendshipPanel : TogglePanel
{
    /// <summary>Intent: give one unit of an item to a character (charId, itemId).</summary>
    public event Action<string, string>? GiftRequested;

    private VBoxContainer _body = null!;

    public FriendshipPanel() => ToggleAction = "toggle_friendship_panel";

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        Visible = false;
    }

    /// <summary>
    /// Render a fresh friendship view. <paramref name="nearbyCharacterId"/> is the villager the
    /// player is standing beside (scene knowledge) — that character's row grows the gift flow.
    /// </summary>
    public void Render(FriendshipView view, string? nearbyCharacterId)
    {
        foreach (Node child in _body.GetChildren())
            child.QueueFree();

        if (view.Characters.Count == 0)
        {
            _body.AddChild(new Label
            {
                Text = "No one to befriend yet — companions appear here as they arrive.",
                ThemeTypeVariation = "HintLabel",
            });
            return;
        }

        foreach (var c in view.Characters)
            _body.AddChild(BuildCharacterCard(c, view, c.CharacterId == nearbyCharacterId));

        if (nearbyCharacterId == null)
        {
            _body.AddChild(new Label
            {
                Text = "Stand beside a villager to give a gift (E talks to them).",
                ThemeTypeVariation = "HintLabel",
                HorizontalAlignment = HorizontalAlignment.Center,
            });
        }
    }

    // ------------------------------------------------------------------ Character card

    private Control BuildCharacterCard(FriendshipCharacterView c, FriendshipView view, bool nearby)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 4);
        panel.AddChild(col);

        // Name row: name (+ birthday marker) left, heart pips right.
        var nameRow = new HBoxContainer();
        nameRow.AddThemeConstantOverride("separation", 10);
        col.AddChild(nameRow);

        string title = c.DisplayName;
        if (c.IsBirthdayToday)
            title += "  — Birthday today!";
        nameRow.AddChild(new Label
        {
            Text = title,
            ThemeTypeVariation = "TitleLabel",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
        });
        nameRow.AddChild(new Label { Text = HeartPips(c.Hearts, c.MaxHearts) });

        // Status row: points, gifts-this-week, talked-today.
        var status = new StringBuilder();
        status.Append($"{c.Points} pts");
        status.Append($"   ·   Gifts this week: {c.GiftsGivenThisWeek}/{c.GiftsPerWeek}");
        status.Append(c.TalkedToday ? "   ·   Talked today" : "   ·   Not talked today");
        if (c.Romanceable)
            status.Append("   ·   Romanceable");
        col.AddChild(new Label { Text = status.ToString(), ThemeTypeVariation = "HintLabel" });

        if (nearby)
            col.AddChild(BuildGiftSection(c, view));

        return panel;
    }

    private Control BuildGiftSection(FriendshipCharacterView c, FriendshipView view)
    {
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 4);

        bool cadenceLeft = c.GiftsGivenThisWeek < c.GiftsPerWeek;
        col.AddChild(new Label
        {
            Text = cadenceLeft
                ? $"Give {c.DisplayName} a gift:"
                : $"{c.DisplayName} has had enough gifts this week.",
            ThemeTypeVariation = "HintLabel",
        });

        if (!cadenceLeft)
            return col;

        if (view.GiftableItems.Count == 0)
        {
            col.AddChild(new Label { Text = "You are not carrying anything to give.", ThemeTypeVariation = "HintLabel" });
            return col;
        }

        foreach (var g in view.GiftableItems)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 10);
            row.AddChild(new Label
            {
                Text = $"{g.DisplayName} x{g.Count}",
                CustomMinimumSize = new Vector2(220, 0),
                SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            });

            string charId = c.CharacterId;
            string itemId = g.ItemId;
            var give = new Button { Text = "Give", ThemeTypeVariation = "ActionChip" };
            give.Pressed += () => GiftRequested?.Invoke(charId, itemId);
            row.AddChild(give);
            col.AddChild(row);
        }
        return col;
    }

    /// <summary>Heart pips as filled/empty glyphs, e.g. 3/10 → "♥♥♥♡♡♡♡♡♡♡".</summary>
    private static string HeartPips(int hearts, int maxHearts)
    {
        var sb = new StringBuilder(maxHearts);
        for (int i = 0; i < maxHearts; i++)
            sb.Append(i < hearts ? '♥' : '♡');
        return sb.ToString();
    }
}
