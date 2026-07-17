using System.Collections.Generic;
using System.Threading;
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

    /// <summary>
    /// The encounter's cancellation token, set by <see cref="CombatScene"/> from the same source it
    /// cancels in <c>_ExitTree</c>. Every paced <c>Task.Delay</c> and tween wait below observes it so a
    /// mid-animation scene exit unblocks the pipeline (a <c>Task.Delay</c> throws OperationCanceled up
    /// through the loop; a tween wait — whose Finished never fires once the tween is freed — is released
    /// by the registration) instead of parking a continuation that later resumes on disposed nodes.
    /// Defaults to None so a headless / standalone presenter behaves exactly as before.
    /// </summary>
    public CancellationToken CancellationToken { get; set; } = CancellationToken.None;

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
                // Two roles, distinguished by whether a Path rides along:
                //  • Stride/Fly CUE (no Path): the walk is animated one tile at a time by the
                //    MovementStep events that follow, so per-tile Reactive-Strike reactions resolve
                //    BETWEEN segments. Here we only raise the walk-animation state; MovementCompleted
                //    lowers it. Animating the whole path here would race ahead of the reaction prompts.
                //  • Slide (2-point Path): Step / forced-move / charge re-sync — a single reaction-free
                //    hop. Animate it immediately, exactly as before (SetMoving is bracketed inside).
                if (TryGet(evt.Source, out var moveUnit))
                {
                    if (evt.Path is { Count: >= 2 })
                        await AnimateMovement(moveUnit, evt.Path);
                    else
                        moveUnit.SetMoving(true);
                }
                break;

            case BattleEventType.MovementStep:
                // One stride segment (from -> to). The tile-exit reaction check already resolved in the
                // executor before this was emitted (the prompt appeared while the token still sat on
                // `from`); now walk the single tile. Walk state stays raised across the whole stride.
                if (evt.Path is { Count: >= 2 } && TryGet(evt.Source, out var stepUnit))
                    await AnimateSegment(stepUnit, evt.Path[0], evt.Path[1]);
                break;

            case BattleEventType.MovementCompleted:
                // Reconcile-only: the per-segment walk (or the slide) already placed the token, so
                // snapping to the authoritative GridPosition is a no-op — even on a reaction-cancelled
                // stride, where the token stopped on the tile the rules left it on (no teleport back).
                if (TryGet(evt.Source, out var movedUnit))
                {
                    movedUnit.SetMoving(false);
                    movedUnit.Position = GridSpace.GridToWorld(evt.Source.GridPosition);
                }
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

    // A multi-tile slide (Step / forced-move / charge re-sync): brackets the walk state and animates
    // every segment back-to-back. Strides do NOT use this — they walk one AnimateSegment per
    // MovementStep so reactions resolve between tiles (walk state bracketed by Started/Completed).
    private async Task AnimateMovement(UnitVisual3D unit, List<PF2eVec> path)
    {
        if (!GodotObject.IsInstanceValid(unit)) return;
        unit.SetMoving(true);
        try
        {
            for (int i = 1; i < path.Count; i++)
                await AnimateSegment(unit, path[i - 1], path[i]);
        }
        finally
        {
            if (GodotObject.IsInstanceValid(unit))
                unit.SetMoving(false);
        }
    }

    // Tween the unit across a single tile (from -> to), facing the direction of travel. Does NOT touch
    // the walk-animation state — callers bracket that (AnimateMovement for a slide; the presenter's
    // MovementStarted/MovementCompleted for a segment-by-segment stride).
    private async Task AnimateSegment(UnitVisual3D unit, PF2eVec from, PF2eVec to)
    {
        // The unit (or the whole scene) can be freed mid-walk on scene exit; creating a tween on — or
        // setting a property of — a disposed node throws. Bail the instant it's gone.
        if (!GodotObject.IsInstanceValid(unit)) return;

        unit.Facing = new Vector2(to.x - from.x, to.y - from.y);

        var target = GridSpace.GridToWorld(to);
        var tween = unit.CreateTween();
        tween.TweenProperty(unit, "position", target, MoveDuration);

        var tcs = new TaskCompletionSource<bool>();
        tween.Finished += () => tcs.TrySetResult(true);
        // On scene exit the tween is freed and its Finished never fires — this await would hang forever,
        // parking the whole combat pipeline. Cancellation completes the wait so the loop unwinds; the
        // IsInstanceValid check at the top of the next segment stops the walk.
        using (CancellationToken.Register(
            static t => ((TaskCompletionSource<bool>)t!).TrySetResult(false), tcs))
            await tcs.Task;
    }

    private static void FaceToward(UnitVisual3D unit, ICharacter? from, ICharacter? target)
    {
        if (from == null || target == null) return;
        var d = new Vector2(target.GridPosition.x - from.GridPosition.x, target.GridPosition.y - from.GridPosition.y);
        if (d.LengthSquared() > 0.0001f) unit.Facing = d;
    }

    private void SpawnPopup(DamagePopup3D popup, UnitVisual3D on)
    {
        // A continuation can reach here just as the scene tears down; reading a freed unit's position
        // or adding a child to a freed popup layer throws. Drop the orphan popup if either side is gone.
        if (!GodotObject.IsInstanceValid(_popupLayer) || !GodotObject.IsInstanceValid(on))
        {
            popup.QueueFree();
            return;
        }
        popup.Position = on.Position + new Vector3(0f, 1.9f, 0f);
        _popupLayer.AddChild(popup);
    }

    private bool TryGet(ICharacter? character, out UnitVisual3D visual)
    {
        visual = null!;
        return character != null && _units.TryGetValue(character.UniqueId, out visual!);
    }

    private async Task Delay(float seconds)
    {
        if (seconds <= 0) return;
        // The token lets a scene exit interrupt the pace-delay: Task.Delay throws OperationCanceled,
        // which propagates up through the AI plan / Emit chain to the turn loop's cancellation handler.
        await Task.Delay((int)(seconds * 1000), CancellationToken);
    }
}
