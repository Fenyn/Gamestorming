using Godot;

namespace Delve.UI;

/// <summary>The transient hero roll above the roll row. Centre stage: a big die, the modifier
/// counting into the total, "vs ?" and the outcome word. Degree track: a smaller die beside the
/// track, whose marker slides from the die face to the total. Both stages print the named modifiers
/// under their numbers when any applied. Display only; the panel drives it.</summary>
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
    private CombatRoll? _roll;

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
        Size = _content.GetCombinedMinimumSize();
        Visible = true;
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

    public void ShowWord()
    {
        if (_roll == null) return;
        Count(_roll.Total);
        if (Stage == RollStage.DegreeTrack) Track.LitZone = _roll.DegreeIndex;
        Word.PivotOffset = Word.Size * 0.5f;
        Word.Scale = Vector2.One * 0.7f;
    }

    /// <summary>Jump to the finished frame.</summary>
    public void Finish()
    {
        Land();
        ShowWord();
        foreach (var node in new CanvasItem[] { _chip, Word, Total })
            node.Modulate = node.Modulate with { A = 1 };
        Word.Scale = Vector2.One;
    }

    public void Clear()
    {
        _roll = null;
        Visible = false;
    }
}
