using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Turns the engine's awaitable <see cref="BattleEvent"/> stream into 3D board animations. Registered
/// as the <see cref="CombatSession"/> presenter; each <c>await Present(evt)</c> blocks until the
/// matching tween/delay finishes (the animation gate), so player and AI turns pace identically.
/// Same event switch as the old 2D GodotPresenter — only positions/tweens moved into world space via
/// <see cref="GridSpace"/>, plus facing is driven from per-step movement deltas.
/// </summary>
public sealed class GodotPresenter3D
{
    private const float MoveDuration = 0.14f;
    private const float AttackDuration = 0.14f;
    private const float PauseDuration = 0.08f;

    private readonly Dictionary<int, UnitVisual3D> _units = new();
    private readonly Node3D _popupLayer;

    public GodotPresenter3D(Node3D popupLayer) => _popupLayer = popupLayer;

    public void RegisterUnit(ICharacter character, UnitVisual3D visual) => _units[character.UniqueId] = visual;

    public async Task Present(BattleEvent evt)
    {
        switch (evt.Type)
        {
            case BattleEventType.TurnStarted:
                if (TryGet(evt.Source, out var turnUnit)) turnUnit.SetActive(true);
                await Delay(PauseDuration);
                break;

            case BattleEventType.TurnEnded:
                if (TryGet(evt.Source, out var endUnit)) endUnit.SetActive(false);
                break;

            case BattleEventType.MovementStarted:
                if (evt.Path != null && TryGet(evt.Source, out var moveUnit))
                    await AnimateMovement(moveUnit, evt.Path);
                break;

            case BattleEventType.MovementCompleted:
                if (TryGet(evt.Source, out var movedUnit))
                    movedUnit.Position = GridSpace.GridToWorld(evt.Source.GridPosition);
                break;

            case BattleEventType.AttackRolled:
                if (TryGet(evt.Source, out var attacker))
                {
                    FaceToward(attacker, evt.Source, evt.Target);
                    attacker.FlashAttack();
                }
                if (evt.Degree.HasValue && evt.Degree.Value < DegreeOfSuccess.Success
                    && TryGet(evt.Target, out var missTarget))
                    SpawnPopup(DamagePopup3D.Create(0, null, evt.Degree), missTarget);
                await Delay(AttackDuration);
                break;

            case BattleEventType.DamageDealt:
                if (TryGet(evt.Target, out var hitUnit))
                {
                    hitUnit.FlashHit();
                    hitUnit.UpdateHealthBar();
                    SpawnPopup(DamagePopup3D.Create(evt.IntValue ?? 0, evt.DamageType, evt.Degree), hitUnit);
                }
                await Delay(PauseDuration);
                break;

            case BattleEventType.Healed:
                if (TryGet(evt.Target, out var healUnit))
                {
                    healUnit.UpdateHealthBar();
                    SpawnPopup(DamagePopup3D.CreateHeal(evt.IntValue ?? 0), healUnit);
                }
                await Delay(PauseDuration);
                break;

            case BattleEventType.ShieldRaised:
                if (TryGet(evt.Source, out var shieldUnit)) shieldUnit.FlashShield();
                await Delay(PauseDuration);
                break;

            case BattleEventType.CreatureDied:
                if (TryGet(evt.Source, out var deadUnit))
                {
                    deadUnit.PlayDeath();
                    await Delay(0.4f);
                }
                break;

            case BattleEventType.SpellCast:
            case BattleEventType.ActionUsed:
                await Delay(PauseDuration);
                break;
        }
    }

    private async Task AnimateMovement(UnitVisual3D unit, List<PF2eVec> path)
    {
        for (int i = 1; i < path.Count; i++)
        {
            var from = path[i - 1];
            var to = path[i];
            unit.Facing = new Vector2(to.x - from.x, to.y - from.y);

            var target = GridSpace.GridToWorld(to);
            var tween = unit.CreateTween();
            tween.TweenProperty(unit, "position", target, MoveDuration);

            var tcs = new TaskCompletionSource<bool>();
            tween.Finished += () => tcs.TrySetResult(true);
            await tcs.Task;
        }
    }

    private static void FaceToward(UnitVisual3D unit, ICharacter? from, ICharacter? target)
    {
        if (from == null || target == null) return;
        var d = new Vector2(target.GridPosition.x - from.GridPosition.x, target.GridPosition.y - from.GridPosition.y);
        if (d.LengthSquared() > 0.0001f) unit.Facing = d;
    }

    private void SpawnPopup(DamagePopup3D popup, UnitVisual3D on)
    {
        popup.Position = on.Position + new Vector3(0f, 1.9f, 0f);
        _popupLayer.AddChild(popup);
    }

    private bool TryGet(ICharacter? character, out UnitVisual3D visual)
    {
        visual = null!;
        return character != null && _units.TryGetValue(character.UniqueId, out visual!);
    }

    private static async Task Delay(float seconds)
    {
        if (seconds <= 0) return;
        await Task.Delay((int)(seconds * 1000));
    }
}
