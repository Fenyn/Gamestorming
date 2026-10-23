using Godot;
using System.Collections.Generic;
using System.Linq;

namespace Ungilded.UI;

/// <summary>The transient hero roll above the roll row. Centre stage: a big die, the modifier
/// counting into the total, "vs ?" and the outcome word. Degree track: a smaller die beside the
/// track, whose marker slides from the die face to the total. Both stages print the named modifiers
/// under their numbers when any applied. A hit with rolled damage adds the damage row under them:
/// one die per damage die, the flat, doubling, bonus, weakness and resistance chips, and the total
/// dealt. Display only; the
/// panel drives it.</summary>
public partial class DiceHeroView : Control
{
    [Export] public float CentreDieSize { get; set; } = 176;
    [Export] public float TrackDieSize { get; set; } = 128;
    /// <summary>Tumble tilt of the die outline per face step, in degrees.</summary>
    [Export] public float OutlineTilt { get; set; } = 9;
    /// <summary>How far the shade spreads past the content on each side.</summary>
    [Export] public Vector2 ShadeMargin { get; set; } = new(160, 72);

    private Control _content = null!;
    private Control _face = null!;
    private TextureRect _outline = null!;
    private Label _value = null!;
    private Control _centre = null!;
    private Control _chip = null!;
    private Label _chipText = null!;
    private Label _centreTotal = null!;
    private Label _centreWord = null!;
    private Control _trackColumn = null!;
    private Label _trackWord = null!;
    private Label _trackTotal = null!;
    private RichTextLabel _centreApplied = null!;
    private RichTextLabel _trackApplied = null!;
    private Control _damageRow = null!;
    private Control _damageDice = null!;
    private Label _damageTemplate = null!;
    private Control _damageFlat = null!;
    private Label _damageFlatText = null!;
    private Control _damageDouble = null!;
    private Control _damageExtra = null!;
    private Label _damageExtraText = null!;
    private Control _damageWeakness = null!;
    private Label _damageWeaknessText = null!;
    private Control _damageResist = null!;
    private Label _damageResistText = null!;
    private CanvasItem[] _damageChips = null!;
    private Label _damageTotal = null!;
    private readonly List<Label> _dice = new();
    private int _diceLanded;
    private CombatRoll? _roll;

    /// <summary>The damage the row shows, or null with no damage row.</summary>
    public DamageRoll? Damage { get; private set; }
    public IReadOnlyList<Label> DamageDice => _dice;
    public Label DamageTotal => _damageTotal;

    /// <summary>The named modifiers as drawn on the showing stage.</summary>
    public string AppliedText => DiceRollPanel.Plain((Stage == RollStage.CentreStage ? _centreApplied : _trackApplied).GetParsedText());

    public DegreeTrack Track { get; private set; } = null!;
    public RollStage Stage { get; private set; }
    public Control Face => _face;
    public Control Chip => _chip;
    public Label Word => Stage == RollStage.CentreStage ? _centreWord : _trackWord;
    public Label Total => Stage == RollStage.CentreStage ? _centreTotal : _trackTotal;
    public string FaceText => _value.Text;
    public string TargetText => GetNode<Label>("%Target").Text;

    public override void _Ready()
    {
        _content = GetNode<Control>("%Content");
        _face = GetNode<Control>("%Face");
        _outline = GetNode<TextureRect>("%Outline");
        _value = GetNode<Label>("%Value");
        _centre = GetNode<Control>("%Centre");
        _chip = GetNode<Control>("%Chip");
        _chipText = GetNode<Label>("%ChipText");
        _centreTotal = GetNode<Label>("%CentreTotal");
        _centreWord = GetNode<Label>("%CentreWord");
        _trackColumn = GetNode<Control>("%TrackColumn");
        _trackWord = GetNode<Label>("%TrackWord");
        _trackTotal = GetNode<Label>("%TrackTotal");
        _centreApplied = GetNode<RichTextLabel>("%CentreApplied");
        _trackApplied = GetNode<RichTextLabel>("%TrackApplied");
        Track = GetNode<DegreeTrack>("%Degree");
        _damageRow = GetNode<Control>("%DamageRow");
        _damageDice = GetNode<Control>("%DamageDice");
        _damageTemplate = GetNode<Label>("%DamageDieTemplate");
        _damageFlat = GetNode<Control>("%DamageFlat");
        _damageFlatText = GetNode<Label>("%DamageFlatText");
        _damageDouble = GetNode<Control>("%DamageDouble");
        _damageExtra = GetNode<Control>("%DamageExtra");
        _damageExtraText = GetNode<Label>("%DamageExtraText");
        _damageWeakness = GetNode<Control>("%DamageWeakness");
        _damageWeaknessText = GetNode<Label>("%DamageWeaknessText");
        _damageResist = GetNode<Control>("%DamageResist");
        _damageResistText = GetNode<Label>("%DamageResistText");
        _damageChips = new CanvasItem[] { _damageFlat, _damageDouble, _damageExtra, _damageWeakness, _damageResist };
        _damageTotal = GetNode<Label>("%DamageTotal");
        var shade = GetNode<Control>("%Shade");
        shade.OffsetLeft = -ShadeMargin.X;
        shade.OffsetRight = ShadeMargin.X;
        shade.OffsetTop = -ShadeMargin.Y;
        shade.OffsetBottom = ShadeMargin.Y;
    }

    /// <summary>Lay out the stage with every text in place but hidden, so the size never jumps.</summary>
    /// <param name="applied">The named modifiers as the roll row prints them, empty for none.</param>
    public void Begin(CombatRoll roll, RollStage stage, string applied = "")
    {
        _roll = roll;
        Stage = stage;
        bool centre = stage == RollStage.CentreStage;
        _centre.Visible = centre;
        _trackColumn.Visible = !centre;
        foreach (var label in new[] { _centreApplied, _trackApplied })
        {
            label.Text = applied;
            label.Visible = applied.Length > 0;
        }
        float die = centre ? CentreDieSize : TrackDieSize;
        _face.CustomMinimumSize = new Vector2(die, die);
        _value.Text = "";
        _value.RemoveThemeColorOverride("font_color");
        _chipText.Text = $"{roll.Total - roll.Die:+0;-0;+0}";
        Word.Text = roll.Outcome;
        RollTone.Paint(Word, RollTone.For(roll));
        Total.Text = roll.Total.ToString();
        RollTone.Paint(Total, RollTone.For(roll));
        if (!centre) Track.Configure(roll.DC, roll.IsAttack, roll.EnemyRoll);
        foreach (var node in new CanvasItem[] { _chip, Word, Total })
            node.Modulate = node.Modulate with { A = 0 };
        _outline.Rotation = 0;
        _face.Scale = Vector2.One;
        Word.Scale = Vector2.One;
        Scale = Vector2.One;
        Modulate = Modulate with { A = 1 };
        ClearDamage();
        Size = _content.GetCombinedMinimumSize();
        Visible = true;
    }

    /// <summary>Lay out the damage row hidden: a blank die per damage die, the chips that apply and
    /// the total. The hero takes its full size here, before the beat reaches the row.</summary>
    public void SetDamage(DamageRoll damage)
    {
        ClearDamage();
        Damage = damage;
        foreach (int _ in damage.Faces)
        {
            var die = (Label)_damageTemplate.Duplicate();
            die.UniqueNameInOwner = false;
            die.Visible = true;
            die.Text = "";
            _damageDice.AddChild(die);
            _dice.Add(die);
        }
        _damageFlatText.Text = $"{damage.Flat:+0;-0}";
        _damageFlat.Visible = damage.Flat != 0;
        _damageDouble.Visible = damage.Doubled;
        _damageExtraText.Text = string.Join("  ", damage.Extras.Select(e =>
            e.Label.Length > 0 ? $"{e.Label} {e.Value:+0;-0}" : $"{e.Value:+0;-0}"));
        _damageExtra.Visible = damage.Extras.Count > 0;
        _damageWeaknessText.Text = $"Weakness +{damage.Weakness}";
        _damageWeakness.Visible = damage.Weakness > 0;
        _damageResistText.Text = $"Resist -{damage.Resistance}";
        _damageResist.Visible = damage.Resistance > 0;
        _damageTotal.Text = damage.Total.ToString();
        RollTone.Paint(_damageTotal, Ungilded.Fx.DamageColors.For(damage.Type) ?? (damage.Doubled ? UiColors.PopupCrit : UiColors.Text));
        foreach (var node in _damageChips.Append<CanvasItem>(_damageRow).Append(_damageTotal))
            node.Modulate = node.Modulate with { A = 0 };
        _damageRow.Visible = true;
        Size = _content.GetCombinedMinimumSize();
    }

    public void ShowDamageRow() => _damageRow.Modulate = _damageRow.Modulate with { A = 1 };

    /// <summary>One tumble step: every die that has not landed shows a random face of its size.</summary>
    public void TumbleDamage(System.Random random)
    {
        if (Damage == null) return;
        for (int i = _diceLanded; i < _dice.Count; i++)
        {
            int face = random.Next(1, Mathf.Max(2, Damage.Sides) + 1);
            _dice[i].Text = face.ToString();
            _dice[i].PivotOffset = _dice[i].Size * 0.5f;
            _dice[i].RotationDegrees = (face % 5 - 2) * OutlineTilt;
        }
    }

    public void LandDamageDie(int index)
    {
        if (Damage == null || index >= _dice.Count) return;
        var die = _dice[index];
        die.Text = Damage.Faces[index].ToString();
        die.Rotation = 0;
        die.PivotOffset = die.Size * 0.5f;
        _diceLanded = index + 1;
    }

    /// <summary>The chips and the total appear, the total starting at the dice sum.</summary>
    public void ShowDamageChips()
    {
        if (Damage == null) return;
        _damageTotal.Text = Damage.DiceSum.ToString();
        _damageTotal.PivotOffset = _damageTotal.Size * 0.5f;
        foreach (var node in _damageChips.Append<CanvasItem>(_damageTotal))
            node.Modulate = node.Modulate with { A = 1 };
    }

    public void CountDamage(float value) => _damageTotal.Text = Mathf.RoundToInt(value).ToString();

    private void ClearDamage()
    {
        Damage = null;
        _diceLanded = 0;
        foreach (var die in _dice)
        {
            _damageDice.RemoveChild(die);
            die.QueueFree();
        }
        _dice.Clear();
        if (IsNodeReady()) _damageRow.Visible = false;
    }

    /// <summary>Centre above the roll row. The hero is top level, so this is canvas space.</summary>
    public void Place(Rect2 row, float gap)
        => GlobalPosition = new Vector2(row.GetCenter().X - Size.X / 2, row.Position.Y - gap - Size.Y);

    public void ShowFace(int face)
    {
        _value.Text = face.ToString();
        _outline.RotationDegrees = (face % 5 - 2) * OutlineTilt;
    }

    public void Land()
    {
        if (_roll == null) return;
        _outline.Rotation = 0;
        _value.Text = _roll.Die.ToString();
        RollTone.PaintFace(_value, _roll.Die);
        _face.PivotOffset = _face.Size * 0.5f;
        Total.Text = _roll.Die.ToString();
        if (Stage == RollStage.DegreeTrack) Track.MarkerValue = _roll.Die;
    }

    /// <summary>The count from the die face to the total: the number and, on the track, the marker.</summary>
    public void Count(float value)
    {
        Total.Text = Mathf.RoundToInt(value).ToString();
        if (Stage == RollStage.DegreeTrack) Track.MarkerValue = value;
    }

    /// <summary>The outcome word at its slam size, about to shrink onto its spot.</summary>
    public void ShowWord(float slamScale)
    {
        if (_roll == null) return;
        Count(_roll.Total);
        if (Stage == RollStage.DegreeTrack) Track.LitZone = _roll.DegreeIndex;
        // Scale about the text, not the label box, so the word lands where it rests.
        float text = Word.GetMinimumSize().X;
        float x = Word.HorizontalAlignment switch
        {
            HorizontalAlignment.Right => Word.Size.X - text / 2,
            HorizontalAlignment.Center => Word.Size.X / 2,
            _ => text / 2,
        };
        Word.PivotOffset = new Vector2(x, Word.Size.Y / 2);
        Word.Scale = Vector2.One * slamScale;
    }

    public void Clear()
    {
        _roll = null;
        ClearDamage();
        Visible = false;
    }
}
