using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Delve.Combat.Map;
using Delve.Fx;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Turns the engine's awaitable <see cref="BattleEvent"/> stream into 3D board animations. Registered
/// as the <see cref="CombatSession"/> presenter; each <c>await Present(evt)</c> blocks until the
/// matching tween/delay finishes (the animation gate), so player and AI turns pace identically.
/// Positions/tweens live in world space via
/// <see cref="GridSpace"/>, and facing is driven from per-step movement deltas.
/// </summary>
public sealed class GodotPresenter3D
{
    private const float MoveDuration = 0.14f;
    private const float AttackDuration = 0.14f;
    private const float PauseDuration = 0.08f;

    /// <summary>Gate held on CreatureDied. Kept short because <see cref="DeathPoof"/> covers
    /// the beat: the poof outlives the gate on its own tween, so the pipeline does not have to wait
    /// out the whole fade before the next unit acts.</summary>
    private const float DeathDuration = 0.3f;

    /// <summary>Fraction of a unit's HP-bar height at which a blow is judged to land — the spark's
    /// origin. Reading it off the bar is what makes one number work for a 1.75 m hero and a 0.9 m rat.</summary>
    private const float ImpactHeightFraction = 0.6f;

    /// <summary>Height above a unit's own HP bar at which its damage number spawns, clearing the bar
    /// and the name label (which sits 0.22 m over the bar).</summary>
    private const float PopupClearance = 0.45f;

    // A hero's swing art already carries the strike, so its root lunge shrinks to a lean that drifts
    // forward across the wind-up and recovers after — the old 0.2 m hop fought the planted-feet pose.
    // Enemies (no swing art) keep the original hop, which is all the attack read they have.
    private const float HeroLungeDistance = 0.09f;
    private const float HeroLungeRecovery = 0.16f;

    // One-shot effect blockouts (scenes/fx/*.tscn) — each is configured before AddChild and frees itself.
    private static readonly PackedScene HitSparkScene = GD.Load<PackedScene>("res://scenes/fx/hit_spark.tscn");
    private static readonly PackedScene HealMotesScene = GD.Load<PackedScene>("res://scenes/fx/heal_motes.tscn");
    private static readonly PackedScene ShieldFlashScene = GD.Load<PackedScene>("res://scenes/fx/shield_flash.tscn");
    private static readonly PackedScene DeathPoofScene = GD.Load<PackedScene>("res://scenes/fx/death_poof.tscn");

    private readonly Dictionary<int, UnitVisual3D> _units = new();
    private readonly Node3D _popupLayer;

    /// <summary>
    /// Camera trauma sink for the punchy beats (crits, deaths). Optional: a headless or standalone
    /// presenter has no camera rig, and combat simply plays without shake.
    /// </summary>
    public ShakePivot? Shake { get; set; }

    /// <summary>
    /// Where the board's surface is. Tokens are tweened to — and snapped to — the tile centre height
    /// from here. <see cref="TerrainHeightMap.Flat"/> reproduces the flat board exactly (every Y is 0).
    /// </summary>
    private readonly TerrainHeightMap _height;

    /// <summary>
    /// The encounter's cancellation token, set by <see cref="CombatScene"/> from the same source it
    /// cancels in <c>_ExitTree</c>. Every paced <c>Task.Delay</c> and tween wait below observes it so a
    /// mid-animation scene exit unblocks the pipeline (a <c>Task.Delay</c> throws OperationCanceled up
    /// through the loop; a tween wait — whose Finished never fires once the tween is freed — is released
    /// by the registration) instead of parking a continuation that later resumes on disposed nodes.
    /// Defaults to None so a headless / standalone presenter behaves exactly as before.
    /// </summary>
    public CancellationToken CancellationToken { get; set; } = CancellationToken.None;

    /// <param name="heightMap">Board surface heights; pass <see cref="TerrainHeightMap.Flat"/> for a flat board.</param>
    public GodotPresenter3D(Node3D popupLayer, TerrainHeightMap heightMap)
    {
        _popupLayer = popupLayer;
        _height = heightMap;
    }

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
                    movedUnit.Position = GridSpace.GridToWorld(evt.Source.GridPosition, _height);
                }
                break;

            case BattleEventType.AttackRolled:
            {
                // The gate is normally a beat for the lunge, but a hero's swing clip stretches it to
                // the clip's STRIKE frame — so the DamageDealt that follows spawns its spark and its
                // number exactly as the axe bites, instead of ahead of the animation that caused them.
                float gate = AttackDuration;
                if (TryGet(evt.Source, out var attacker))
                {
                    FaceToward(attacker, evt.Source, evt.Target);
                    if (attacker.PlaySwing())
                    {
                        gate = UnitVisual3D.SwingImpactDelay;
                        attacker.FlashAttack(HeroLungeDistance, gate, HeroLungeRecovery);
                    }
                    else
                    {
                        attacker.FlashAttack();
                    }
                }
                await Delay(gate);

                // A whiff gets no spark — nothing connected. The defender ducks away on the frame the
                // blow arrives and takes the MISS/FUMBLE callout instead.
                if (evt.Degree.HasValue && evt.Degree.Value < DegreeOfSuccess.Success
                    && TryGet(evt.Target, out var missTarget))
                {
                    missTarget.PlayDodgeLean(HorizontalDirection(evt.Source, evt.Target));
                    SpawnPopup(DamagePopup3D.Create(0, null, evt.Degree), missTarget);
                }
                break;
            }

            case BattleEventType.DamageDealt:
                if (TryGet(evt.Target, out var hitUnit))
                {
                    bool crit = evt.Degree == DegreeOfSuccess.CriticalSuccess;
                    SpawnHitSpark(hitUnit, HorizontalDirection(evt.Source, evt.Target), evt.DamageType, crit);
                    hitUnit.FlashHit();
                    // A killing blow skips the flinch: the CreatureDied that follows immediately owns
                    // that beat, and a corpse jittering into its own death fade reads as a glitch.
                    if (hitUnit.Character.Health?.IsDead != true) hitUnit.PlayHurtShake();
                    hitUnit.UpdateHealthBar();
                    SpawnPopup(DamagePopup3D.Create(evt.IntValue ?? 0, evt.DamageType, evt.Degree), hitUnit);
                    if (crit) Shake?.AddTrauma(ShakePivot.CritTrauma);
                }
                await Delay(PauseDuration);
                break;

            case BattleEventType.Healed:
                if (TryGet(evt.Target, out var healUnit))
                {
                    SpawnFx(HealMotesScene.Instantiate<HealMotes>(), healUnit.Position);
                    healUnit.UpdateHealthBar();
                    SpawnPopup(DamagePopup3D.CreateHeal(evt.IntValue ?? 0), healUnit);
                }
                await Delay(PauseDuration);
                break;

            // NOTE: BattleEventType.ShieldBlocked exists in the engine's enum but NOTHING emits it as a
            // BattleEvent — the absorbed amount only ever surfaces through ShieldManager.OnShieldBlocked,
            // a static C# event no view is subscribed to. Wiring a ShieldFlash sized by the absorbed
            // damage is a one-liner here the day that event is emitted; until then a block reads through
            // the Raise Shield flash below plus the reduced damage number.
            case BattleEventType.ShieldRaised:
                if (TryGet(evt.Source, out var shieldUnit))
                {
                    var flash = ShieldFlashScene.Instantiate<ShieldFlash>();
                    // Under ShieldFlash's third-ring threshold on purpose: raising a shield is a ward
                    // going up, not a blow being turned — the bigger read is reserved for an actual block.
                    flash.BlockStrength = 0.45f;
                    SpawnFx(flash, shieldUnit.Position);
                    shieldUnit.FlashShield();
                }
                await Delay(PauseDuration);
                break;

            case BattleEventType.CreatureDied:
                if (TryGet(evt.Source, out var deadUnit))
                {
                    var poof = DeathPoofScene.Instantiate<DeathPoof>();
                    // DeathPoof's table is authored for a ~1.6 m hero; scale it by how tall THIS unit
                    // is so a rat dissolves into a rat-sized puff instead of a hero-sized one.
                    poof.PoofScale = UnitSizeFactor(deadUnit);
                    SpawnFx(poof, deadUnit.Position);
                    deadUnit.PlayDeath();
                    Shake?.AddTrauma(ShakePivot.DeathTrauma);
                    await Delay(DeathDuration);
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

        // Y is interpolated linearly with X/Z across the segment, so a step onto a ramp walks up it and
        // a hop off a ledge cuts the corner diagonally. Accepted for v1 — a two-stage tween (out, then
        // down) is the polish pass if cliff hops read badly in play.
        var target = GridSpace.GridToWorld(to, _height);
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

    /// <summary>Normalized horizontal direction FROM one combatant TOWARD another (grid space is world
    /// XZ), or zero when either side is missing. Drives the spark's outward bias and the defender's
    /// duck, both of which have to know which way the blow came from.</summary>
    private static Vector3 HorizontalDirection(ICharacter? from, ICharacter? to)
    {
        if (from == null || to == null) return Vector3.Zero;
        var d = new Vector3(to.GridPosition.x - from.GridPosition.x, 0f, to.GridPosition.y - from.GridPosition.y);
        return d.LengthSquared() > 0.0001f ? d.Normalized() : Vector3.Zero;
    }

    /// <summary>
    /// How big an effect authored for a hero should be on THIS unit, taken from its HP-bar height
    /// (1.0 for a hero, ~0.51 for a rat). Floored so a small unit still gets an effect that reads:
    /// scaling a burst all the way down with the creature makes a rat's death a puff of nothing.
    /// </summary>
    private static float UnitSizeFactor(UnitVisual3D unit) =>
        Mathf.Max(0.66f, unit.HpBarHeight / UnitVisual3D.HeroHpBarY);

    /// <summary>Burst a <see cref="HitSpark"/> at the struck unit's impact point — up its own
    /// silhouette, tinted for the damage type, thrown away from the attacker, doubled on a crit.</summary>
    private void SpawnHitSpark(UnitVisual3D on, Vector3 impactDirection, DamageType? damageType, bool crit)
    {
        if (!GodotObject.IsInstanceValid(on)) return;
        var spark = HitSparkScene.Instantiate<HitSpark>();
        spark.Tint = HitSpark.TintFor(damageType);
        spark.ImpactDirection = impactDirection;
        spark.Crit = crit;
        // HitSpark's shard table is authored against a hero silhouette; at that size a burst on a
        // 0.7 m rat is wider than the rat and swallows it whole (the first render pass proved it), so
        // the burst is scaled to the unit the same way the death poof is.
        spark.SparkScale = UnitSizeFactor(on);
        SpawnFx(spark, on.Position + new Vector3(0f, on.HpBarHeight * ImpactHeightFraction, 0f));
    }

    /// <summary>Place a configured one-shot effect and let it run. Position is set BEFORE AddChild —
    /// every effect in scripts/fx builds its geometry off its own transform in _Ready, so a node added
    /// at the origin and moved after would burst in the wrong place for one frame.</summary>
    private void SpawnFx(Node3D fx, Vector3 position)
    {
        // A continuation can reach here just as the scene tears down; adding a child to a freed popup
        // layer throws. Drop the orphan effect.
        if (!GodotObject.IsInstanceValid(_popupLayer))
        {
            fx.QueueFree();
            return;
        }
        fx.Position = position;
        _popupLayer.AddChild(fx);
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
        // Just above THIS unit's own HP bar rather than a fixed height: a rat's bar sits at 0.9 m, so
        // the old constant 1.9 left its numbers floating a metre over its head.
        popup.Position = on.Position + new Vector3(0f, on.HpBarHeight + PopupClearance, 0f);
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
