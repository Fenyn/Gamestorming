using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public class GodotPresenter
{
    private readonly Dictionary<int, UnitVisual> _units = new();
    private readonly Node2D _boardContainer;
    private readonly Node2D _popupLayer;
    private float _speedMultiplier = 1.0f;

    private const float MoveDuration = 0.15f;
    private const float AttackDuration = 0.15f;
    private const float PauseDuration = 0.1f;

    public GodotPresenter(Node2D boardContainer, Node2D popupLayer)
    {
        _boardContainer = boardContainer;
        _popupLayer = popupLayer;
    }

    public void SetSpeed(float multiplier)
    {
        _speedMultiplier = Mathf.Max(0.1f, multiplier);
    }

    public void RegisterUnit(ICharacter character, UnitVisual visual)
    {
        _units[character.UniqueId] = visual;
    }

    public void Clear()
    {
        _units.Clear();
    }

    public async Task Present(BattleEvent evt)
    {
        float speed = _speedMultiplier;

        switch (evt.Type)
        {
            case BattleEventType.TurnStarted:
                if (TryGetVisual(evt.Source, out var turnUnit))
                    turnUnit.SetHighlighted(true);
                await Delay(PauseDuration / speed);
                break;

            case BattleEventType.TurnEnded:
                if (TryGetVisual(evt.Source, out var endUnit))
                    endUnit.SetHighlighted(false);
                break;

            case BattleEventType.MovementStarted:
                if (evt.Path != null && TryGetVisual(evt.Source, out var moveUnit))
                    await AnimateMovement(moveUnit, evt.Path, speed);
                break;

            case BattleEventType.MovementStep:
                break;

            case BattleEventType.MovementCompleted:
                if (TryGetVisual(evt.Source, out var movedUnit))
                    movedUnit.Position = GridVisual.GridToWorld(evt.Source.GridPosition);
                break;

            case BattleEventType.AttackRolled:
                if (TryGetVisual(evt.Source, out var attacker))
                    attacker.FlashAttack();
                if (evt.Degree.HasValue && evt.Degree.Value < DegreeOfSuccess.Success)
                {
                    if (TryGetVisual(evt.Target, out var missTarget))
                    {
                        var popup = DamagePopup.Create(0, null, evt.Degree);
                        popup.Position = missTarget.Position + new Vector2(16, -10);
                        _popupLayer.AddChild(popup);
                    }
                }
                await Delay(AttackDuration / speed);
                break;

            case BattleEventType.DamageDealt:
                if (TryGetVisual(evt.Target, out var hitUnit))
                {
                    hitUnit.FlashHit();
                    int dmg = evt.IntValue ?? 0;
                    hitUnit.UpdateHealthBar(
                        evt.Target.Health?.CurrentHP ?? 0,
                        evt.Target.Health?.MaxHP ?? 1);

                    var dmgPopup = DamagePopup.Create(dmg, evt.DamageType, evt.Degree);
                    dmgPopup.Position = hitUnit.Position + new Vector2(16, -10);
                    _popupLayer.AddChild(dmgPopup);
                }
                await Delay(PauseDuration / speed);
                break;

            case BattleEventType.Healed:
                if (TryGetVisual(evt.Target, out var healUnit))
                {
                    int heal = evt.IntValue ?? 0;
                    healUnit.UpdateHealthBar(
                        evt.Target.Health?.CurrentHP ?? 0,
                        evt.Target.Health?.MaxHP ?? 1);

                    var healPopup = DamagePopup.CreateHeal(heal);
                    healPopup.Position = healUnit.Position + new Vector2(16, -10);
                    _popupLayer.AddChild(healPopup);
                }
                await Delay(PauseDuration / speed);
                break;

            case BattleEventType.ConditionApplied:
                if (TryGetVisual(evt.Target, out var condUnit) && evt.Condition.HasValue)
                {
                    Color condColor = GetConditionColor(evt.Condition.Value);
                    condUnit.AddConditionDot(evt.Condition.Value.ToString(), condColor);
                }
                break;

            case BattleEventType.ConditionRemoved:
                if (TryGetVisual(evt.Target, out var removeCondUnit))
                    removeCondUnit.ClearConditionDots();
                break;

            case BattleEventType.ConditionValueChanged:
                break;

            case BattleEventType.SpellCast:
                if (TryGetVisual(evt.Source, out var caster))
                {
                    var spellPopup = new Label();
                    spellPopup.Text = evt.Description ?? "Spell";
                    spellPopup.AddThemeFontSizeOverride("font_size", 14);
                    spellPopup.AddThemeColorOverride("font_color", new Color(0.5f, 0.8f, 1f));
                    spellPopup.AddThemeColorOverride("font_shadow_color", Colors.Black);
                    spellPopup.AddThemeConstantOverride("shadow_offset_x", 1);
                    spellPopup.AddThemeConstantOverride("shadow_offset_y", 1);
                    spellPopup.Position = caster.Position + new Vector2(0, -30);
                    _popupLayer.AddChild(spellPopup);

                    var tween = spellPopup.CreateTween();
                    tween.TweenProperty(spellPopup, "modulate:a", 0f, 1.0f / speed);
                    tween.TweenCallback(Callable.From(spellPopup.QueueFree));
                }
                await Delay(0.3f / speed);
                break;

            case BattleEventType.ActionUsed:
                await Delay(PauseDuration / speed * 0.5f);
                break;

            case BattleEventType.CreatureDied:
                if (TryGetVisual(evt.Source, out var deadUnit))
                {
                    deadUnit.PlayDeath();
                    await Delay(0.5f / speed);
                }
                break;

            case BattleEventType.CreatureUnconscious:
                if (TryGetVisual(evt.Source, out var unconsciousUnit))
                    unconsciousUnit.GrayOut();
                break;

            case BattleEventType.ShieldRaised:
                break;

            case BattleEventType.ShieldBlocked:
                if (TryGetVisual(evt.Target, out var shieldUnit) && evt.IntValue.HasValue)
                {
                    var blockPopup = new Label();
                    blockPopup.Text = $"BLOCKED {evt.IntValue.Value}";
                    blockPopup.AddThemeFontSizeOverride("font_size", 12);
                    blockPopup.AddThemeColorOverride("font_color", new Color(0.6f, 0.8f, 1f));
                    blockPopup.Position = shieldUnit.Position + new Vector2(0, -10);
                    _popupLayer.AddChild(blockPopup);

                    var tween = blockPopup.CreateTween();
                    tween.TweenProperty(blockPopup, "modulate:a", 0f, 0.8f / speed);
                    tween.TweenCallback(Callable.From(blockPopup.QueueFree));
                }
                break;

            case BattleEventType.ReactionTriggered:
                if (TryGetVisual(evt.Source, out var reactUnit))
                {
                    var reactPopup = new Label();
                    reactPopup.Text = evt.Description ?? "Reaction!";
                    reactPopup.AddThemeFontSizeOverride("font_size", 12);
                    reactPopup.AddThemeColorOverride("font_color", new Color(1f, 0.6f, 0.2f));
                    reactPopup.Position = reactUnit.Position + new Vector2(0, -25);
                    _popupLayer.AddChild(reactPopup);

                    var tween = reactPopup.CreateTween();
                    tween.TweenProperty(reactPopup, "modulate:a", 0f, 0.8f / speed);
                    tween.TweenCallback(Callable.From(reactPopup.QueueFree));
                }
                await Delay(PauseDuration / speed);
                break;

            case BattleEventType.InitiativeRolled:
            case BattleEventType.RoundStarted:
            case BattleEventType.RoundEnded:
            case BattleEventType.EncounterStarted:
            case BattleEventType.EncounterEnded:
                break;
        }
    }

    private async Task AnimateMovement(UnitVisual unit, List<PF2eVec> path, float speed)
    {
        foreach (var step in path)
        {
            var worldPos = GridVisual.GridToWorld(step);
            var tween = unit.CreateTween();
            tween.TweenProperty(unit, "position", worldPos, MoveDuration / speed);

            var tcs = new TaskCompletionSource<bool>();
            tween.Finished += () => tcs.TrySetResult(true);
            await tcs.Task;
        }
    }

    private bool TryGetVisual(ICharacter character, out UnitVisual visual)
    {
        visual = null;
        if (character == null) return false;
        return _units.TryGetValue(character.UniqueId, out visual);
    }

    private static async Task Delay(float seconds)
    {
        if (seconds <= 0) return;
        await Task.Delay((int)(seconds * 1000));
    }

    private static Color GetConditionColor(PF2e.Conditions.Condition condition)
    {
        string name = condition.ToString().ToLower();

        if (name.Contains("frightened") || name.Contains("sickened") || name.Contains("stunned")
            || name.Contains("slowed") || name.Contains("confused"))
            return new Color(0.3f, 0.3f, 1f);

        if (name.Contains("persistent") || name.Contains("bleed") || name.Contains("dying"))
            return new Color(1f, 0.2f, 0.2f);

        if (name.Contains("haste") || name.Contains("quickened") || name.Contains("concealed"))
            return new Color(0.2f, 1f, 0.3f);

        if (name.Contains("immobilized") || name.Contains("grabbed") || name.Contains("restrained")
            || name.Contains("prone"))
            return new Color(1f, 0.8f, 0.1f);

        if (name.Contains("off-guard") || name.Contains("flat-footed"))
            return new Color(0.8f, 0.5f, 0.1f);

        return new Color(0.7f, 0.7f, 0.7f);
    }
}
