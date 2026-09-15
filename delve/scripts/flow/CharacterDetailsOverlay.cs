using Delve.UI;
using Godot;
using PF2e.Core;
using Delve.Run;

namespace Delve.Flow;

/// <summary>Dismissible exploration wrapper around the shared character sheet.</summary>
public partial class CharacterDetailsOverlay : Control
{
    public event System.Action? Closed;
    public event System.Action? Promoted;
    private HeroSheet _sheet = null!;
    private Button _close = null!;
    private PromotionPanel _progression = null!;
    private PF2eCharacter? _character;
    private Texture2D? _portrait;
    private Color _accent;

    public override void _Ready()
    {
        _sheet = GetNode<HeroSheet>("%Sheet");
        _close = GetNode<Button>("%CloseDetails");
        _close.Pressed += Close;
        _progression = GetNode<PromotionPanel>("%Progression");
        GetNode<Button>("%OverviewTab").Pressed += () => ShowTab(false);
        GetNode<Button>("%ProgressionTab").Pressed += () => ShowTab(true);
        _progression.Promoted += () =>
        {
            if (_character == null) return;
            _sheet.Show(HeroSheetBuilder.Read(_character), _portrait, _accent);
            UpdateTabLabel();
            Promoted?.Invoke();
        };
        Hide();
    }

    public void Open(HeroSheetData data, Texture2D? portrait, Color accent)
    {
        _character = null;
        GetNode<Control>("%SheetTabs").Hide();
        ShowTab(false);
        _sheet.Show(data, portrait, accent);
        Show();
        _close.GrabFocus();
    }

    public void Open(PF2eCharacter character, Texture2D? portrait, Color accent)
    {
        Open(HeroSheetBuilder.Read(character), portrait, accent);
        _character = character;
        _portrait = portrait;
        _accent = accent;
        GetNode<Control>("%SheetTabs").Show();
        _progression.ShowCharacter(character);
        UpdateTabLabel();
        ShowTab(CharacterPromotion.For(character).HasChoice(character));
    }

    private void UpdateTabLabel()
    {
        if (_character == null) return;
        string status = CharacterPromotion.Status(_character);
        GetNode<Button>("%ProgressionTab").Text = status.Length > 0 ? $"Progression · {status}" : "Progression";
    }

    private void ShowTab(bool progression)
    {
        _sheet.HideTips();
        _sheet.Visible = !progression;
        _progression.Visible = progression;
    }

    public void Close()
    {
        if (!Visible) return;
        _sheet.HideTips();
        Hide();
        Closed?.Invoke();
    }

    public override void _Input(InputEvent e)
    {
        if (!IsVisibleInTree() || !e.IsActionPressed(InputNames.UiCancel)) return;
        Close();
        GetViewport().SetInputAsHandled();
    }
}
