using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Passive hover-inspect card: unit name (team-tinted accent), HP bar, AC, and active condition
/// labels. Docked bottom-left of the combat HUD. Shown whenever the cursor hovers an occupied
/// tile in ANY mode (idle or targeting); hidden over empty tiles. Renders from
/// <see cref="UnitInspectView"/> only — no engine types, no rules; the AC/HP lines arrive already
/// masked for what the bestiary knows about that species, and the HP bar always fills to the real
/// ratio (board-visible information).
/// </summary>
public partial class UnitInspectPanel : PanelContainer
{
    private ColorRect _accent = null!;
    private Label _nameLabel = null!;
    private Label _acLabel = null!;
    private ProgressBar _hpBar = null!;
    private Label _hpLabel = null!;
    private Label _conditionsLabel = null!;

    public override void _Ready()
    {
        _accent = GetNode<ColorRect>("%Accent");
        _nameLabel = GetNode<Label>("%NameLabel");
        _acLabel = GetNode<Label>("%AcLabel");
        _hpBar = GetNode<ProgressBar>("%HpBar");
        _hpLabel = GetNode<Label>("%HpLabel");
        _conditionsLabel = GetNode<Label>("%ConditionsLabel");
        Visible = false;
    }

    /// <summary>Render the hovered unit, or hide when null (empty tile).</summary>
    public void Render(UnitInspectView? view)
    {
        Visible = view != null;
        if (view == null) return;

        _accent.Color = view.TeamId == 1 ? UiPalette.AllyGreen : UiPalette.EnemyRed;
        _nameLabel.Text = view.Name;
        // Pre-masked by the query (bestiary knowledge) — this Control never decides what is hidden.
        _acLabel.Text = view.AcText;

        int maxHp = System.Math.Max(1, view.MaxHp);
        _hpBar.MaxValue = maxHp;
        _hpBar.Value = System.Math.Clamp(view.Hp, 0, maxHp);
        if (_hpBar.GetThemeStylebox("fill") is StyleBoxFlat fill)
        {
            var dup = (StyleBoxFlat)fill.Duplicate();
            dup.BgColor = UiPalette.HpFillColor(view.MaxHp > 0 ? (float)view.Hp / view.MaxHp : 0f);
            _hpBar.AddThemeStyleboxOverride("fill", dup);
        }
        _hpLabel.Text = view.HpText;

        _conditionsLabel.Visible = view.Conditions.Count > 0;
        _conditionsLabel.Text = string.Join("   ", view.Conditions);
    }
}
