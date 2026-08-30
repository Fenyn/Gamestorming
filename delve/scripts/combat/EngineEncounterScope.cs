using System;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Grid;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Owns the engine globals that one encounter claims: the TurnManager / CombatantRegistry
/// singletons, the grid's tile delegates, the spatial (flanking / cover / line) delegates, the
/// ReactionManager and its two static policies, the forced-movement executor, and Step destination
/// validation. The constructor claims them all and remembers each instance it installed.
///
/// <para><b>Why ownership is tracked.</b> Every one of these is a process-wide static, and a new
/// encounter overwrites all of them. A scope that is disposed AFTER a newer scope started must
/// therefore release nothing it no longer owns — anything else would strip the live encounter's
/// wiring and break the fight in progress. The newest scope is <see cref="_live"/>, and
/// <see cref="Dispose"/> releases the shared statics only while this scope is still it.</para>
///
/// <para>Delegate identity alone cannot decide ownership: the compiler caches the delegate it builds
/// for a static method group or a closure-free lambda, so two encounters that wire the same code get
/// the SAME delegate instance. The reference checks below stay as a second guard for globals set
/// outside a scope, but <see cref="_live"/> is what makes a stale dispose safe.</para>
/// </summary>
public sealed class EngineEncounterScope : IDisposable
{
    /// <summary>This encounter's turn manager (also installed as TurnManager.Instance).</summary>
    public TurnManager Turns { get; }

    /// <summary>This encounter's combatant registry (also installed as CombatantRegistry.Instance).</summary>
    public CombatantRegistry Registry { get; }

    /// <summary>This encounter's reaction manager, already subscribed to the reaction events.</summary>
    public ReactionManager Reactions { get; }

    private readonly BattleGrid _grid;
    private readonly IDisposable _spatial;
    private readonly Func<ICharacter, bool> _isPlayerControlled;
    private readonly Func<ReactionPromptContext, Task<bool>> _reactionPolicy;
    private readonly Func<ICharacter, PF2eVec, string?> _validateStep;

    // Grid delegates: BattleGrid.WireDelegates builds closures over the grid internally, so the scope
    // reads back what it installed instead of building them itself.
    private readonly Func<PF2eVec, int> _tileElevation;
    private readonly Func<ICharacter, int> _characterAltitude;
    private readonly Func<PF2eVec, int> _movementCost;
    private readonly Func<PF2eVec, bool> _blockedByZone;
    private readonly Func<PF2eVec, int> _concealmentDc;
    private readonly Func<PF2eVec, int> _balanceDc;

    private bool _disposed;

    /// <summary>
    /// The scope that currently owns the engine globals: the most recent one constructed. Static,
    /// because the globals it guards are static — there is exactly one owner per process.
    /// </summary>
    private static EngineEncounterScope? _live;

    /// <param name="grid">The encounter's grid. Tile, spatial and forced-movement globals point at it.</param>
    /// <param name="isPlayerControlled">Reaction ownership test (ReactionManager.IsPlayerControlled).</param>
    /// <param name="reactionPolicy">Player reaction decision (ReactionManager.PlayerReactionPolicy).</param>
    /// <param name="validateStep">Step destination legality (StepAction.ValidateDestination).</param>
    public EngineEncounterScope(
        BattleGrid grid,
        Func<ICharacter, bool> isPlayerControlled,
        Func<ReactionPromptContext, Task<bool>> reactionPolicy,
        Func<ICharacter, PF2eVec, string?> validateStep)
    {
        _grid = grid;

        // Engine singletons (mirrors BattleSimulator's constructor).
        Turns = new TurnManager();
        TurnManager.Instance = Turns;
        Registry = new CombatantRegistry();
        CombatantRegistry.Instance = Registry;

        grid.WireDelegates();
        _tileElevation = AreaCalculator.GetTileElevation;
        _characterAltitude = AreaCalculator.GetCharacterAltitudeFeet;
        _movementCost = TileEffectRules.TileMovementCostModifier;
        _blockedByZone = TileEffectRules.TileBlockedByZone;
        _concealmentDc = TileEffectRules.TileConcealmentDC;
        _balanceDc = TileEffectRules.TileBalanceDC;

        _spatial = SpatialDelegates.Wire(grid);

        // Reactions: a subscribed ReactionManager OWNS damage delivery (its damage handler runs
        // reactions then calls the applyDamage continuation). It replaces the old pass-through — never
        // both, or the multicast event would deliver damage twice.
        Reactions = new ReactionManager();
        Reactions.Subscribe();
        _isPlayerControlled = isPlayerControlled;
        ReactionManager.IsPlayerControlled = _isPlayerControlled;
        _reactionPolicy = reactionPolicy;
        ReactionManager.PlayerReactionPolicy = _reactionPolicy;

        // Forced movement (Shove push/follow, Tumble Through exit-move, push-strike riders) resolves
        // against this grid. Install() routes push-rider events so rider displacement moves creatures.
        ForcedMovementExecutor.Grid = grid;
        ForcedMovementExecutor.Install();

        _validateStep = validateStep;
        // The engine field is un-annotated; the delegate legally returns null for "legal step".
        StepAction.ValidateDestination = _validateStep!;

        // Claimed last: from here on this scope is the owner, and an older scope's Dispose is a no-op
        // for every shared static below.
        _live = this;
    }

    /// <summary>Release every global this scope still owns. Idempotent; safe on a stale scope.</summary>
    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        // Instance-scoped work runs whatever the ownership: Unsubscribe detaches only THIS manager's
        // handlers, and the two singleton clears below identity-check their own instances.
        Reactions.Unsubscribe();
        // Unsubscribe also clears the shared reaction-strike bridge, which it matches by STATIC method
        // identity — so a stale scope strips it from a manager that is still live. Put it back.
        if (ReactionManager.Instance != null && ReactionStrikeBridge.Execute == null)
            ReactionStrikeBridge.Execute = ReactionStrikeResolver.Execute;

        if (ReferenceEquals(TurnManager.Instance, Turns))
            TurnManager.Instance = null!;
        if (ReferenceEquals(CombatantRegistry.Instance, Registry))
            CombatantRegistry.Instance = null!;

        // Everything below is a shared static that a newer scope may already have overwritten. Only
        // the live owner releases it.
        if (!ReferenceEquals(_live, this))
            return;
        _live = null;

        if (ReferenceEquals(ReactionManager.IsPlayerControlled, _isPlayerControlled))
            ReactionManager.IsPlayerControlled = null;
        if (ReferenceEquals(ReactionManager.PlayerReactionPolicy, _reactionPolicy))
            ReactionManager.PlayerReactionPolicy = null;

        if (ReferenceEquals(StepAction.ValidateDestination, _validateStep))
            StepAction.ValidateDestination = null;

        _spatial.Dispose();

        if (ReferenceEquals(ForcedMovementExecutor.Grid, _grid))
        {
            ForcedMovementExecutor.Uninstall();
            ForcedMovementExecutor.Grid = null;
        }

        if (ReferenceEquals(AreaCalculator.GetTileElevation, _tileElevation))
            AreaCalculator.GetTileElevation = null;
        if (ReferenceEquals(AreaCalculator.GetCharacterAltitudeFeet, _characterAltitude))
            AreaCalculator.GetCharacterAltitudeFeet = null;
        if (ReferenceEquals(TileEffectRules.TileMovementCostModifier, _movementCost))
            TileEffectRules.TileMovementCostModifier = null;
        if (ReferenceEquals(TileEffectRules.TileBlockedByZone, _blockedByZone))
            TileEffectRules.TileBlockedByZone = null;
        if (ReferenceEquals(TileEffectRules.TileConcealmentDC, _concealmentDc))
            TileEffectRules.TileConcealmentDC = null;
        if (ReferenceEquals(TileEffectRules.TileBalanceDC, _balanceDc))
            TileEffectRules.TileBalanceDC = null;
    }
}
