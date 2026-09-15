using System.Linq;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>Live condition badges above a token. Values and removals update without a combat event.</summary>
public partial class UnitConditions : Node3D
{
    [Export] public ConditionIconSet Icons { get; set; } = null!;
    [Export] public int IconSize { get; set; } = 32;
    private ICharacter? _character;
    private HBoxContainer _row = null!;
    private string _signature = "";

    public void Configure(ICharacter character) => _character = character;

    public override void _Ready()
    {
        _row = new HBoxContainer { MouseFilter = Control.MouseFilterEnum.Ignore };
        _row.AddThemeConstantOverride("separation", 2);
        AddChild(_row);
    }

    public override void _Process(double delta)
    {
        var camera = GetViewport().GetCamera3D();
        _row.Visible = IsVisibleInTree() && camera != null && !camera.IsPositionBehind(GlobalPosition);
        if (!_row.Visible || _character == null) return;
        var conditions = _character.Conditions?.GetAllConditions();
        var active = conditions?.GroupBy(c => (c.Definition.Condition, c.PersistentDamage?.DamageType))
            .Select(g => g.OrderByDescending(c => c.Value).First())
            .OrderBy(c => c.Definition.DisplayName).ToArray();
        string signature = active == null ? "" : string.Join("|", active.Select(c => $"{c.Definition.Condition}:{c.PersistentDamage?.DamageType}:{c.Value}:{c.Duration}"));
        var classStatus = _character == null ? "" : string.Join(" / ", Delve.Rules.ClassStatus.Active(_character));
        signature += classStatus;
        if (signature != _signature)
        {
            _signature = signature;
            foreach (var child in _row.GetChildren()) { _row.RemoveChild(child); child.QueueFree(); }
            if (active != null)
                foreach (var condition in active)
                {
                    var def = condition.Definition;
                    string label = condition.DisplayLabel + (def.HasValue && condition.PersistentDamage == null ? $" {condition.Value}" : "");
                    var icon = new TextureRect
                    {
                        TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
                        Texture = Icons.Find(condition.PersistentDamage?.DamageType.ToString() ?? def.Condition.ToString()),
                        CustomMinimumSize = new Vector2(IconSize, IconSize),
                        ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                        StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                        MouseFilter = Control.MouseFilterEnum.Pass,
                        TooltipText = label + "\n" + def.Description,
                    };
                    if (def.HasValue)
                    {
                        var value = new Label { Text = condition.Value.ToString(), MouseFilter = Control.MouseFilterEnum.Ignore };
                        value.AddThemeFontSizeOverride("font_size", 14);
                        value.AddThemeConstantOverride("outline_size", 4);
                        value.Position = new Vector2(IconSize - 10, 8);
                        icon.AddChild(value);
                    }
                    _row.AddChild(icon);
                }
            if (classStatus.Length > 0)
            {
                var label = new Label { Text = classStatus, MouseFilter = Control.MouseFilterEnum.Ignore };
                label.AddThemeFontSizeOverride("font_size",12);
                label.AddThemeConstantOverride("outline_size",4);
                _row.AddChild(label);
            }
            _row.ResetSize();
        }
        _row.Position = camera!.UnprojectPosition(GlobalPosition) - new Vector2(_row.Size.X / 2, IconSize);
    }
}
