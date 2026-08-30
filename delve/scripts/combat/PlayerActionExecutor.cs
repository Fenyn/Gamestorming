using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Spellcasting;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Executes and previews the player actions: the core four (Stride, Step, Strike, Raise a Shield)
/// plus spells, skill/maneuver/feat actions, and consumables.
///
/// This type is a facade. It builds the collaborators once and forwards every call:
/// <see cref="Movement"/> (Stride/Step + pathfinding), <see cref="Strikes"/> (Strike, Raise a
/// Shield), <see cref="Spells"/> (the preset spell layer) and <see cref="Skills"/> (the
/// catalog-driven skill chips). New code may depend on one collaborator instead of the whole
/// surface; the facade stays for the controller, the session and the spikes.
///
/// Plain C#: the only Godot-free dependency is the engine. Consumes actions from
/// <c>ICharacter.Actions</c> so the action bar stays in sync.
/// </summary>
public sealed class PlayerActionExecutor
{
    private readonly MovementActions _movement;
    private readonly StrikeActions _strikes;
    private readonly SpellActions _spells;
    private readonly SkillActions _skills;
    private readonly BattleGrid _grid;

    /// <param name="resolveSpell">Spell lookup by id, injected so this type never names a content
    /// source. Null ids and unknown ids return null.</param>
    public PlayerActionExecutor(
        BattleRunner runner, BattleGrid grid, Func<string, SpellCastAction?> resolveSpell)
    {
        _grid = grid;
        var events = new BattleEventEmitter(runner);
        _movement = new MovementActions(grid, events);
        _strikes = new StrikeActions(events);
        _spells = new SpellActions(grid, events, resolveSpell);
        _skills = new SkillActions(grid, events, _movement);
    }

    /// <summary>Stride, Step and the pathfinding queries the UI highlights them with.</summary>
    internal MovementActions Movement => _movement;

    /// <summary>Strike, Raise a Shield and their previews.</summary>
    internal StrikeActions Strikes => _strikes;

    /// <summary>The preset spell layer: entries, targeting and casting.</summary>
    internal SpellActions Spells => _spells;

    /// <summary>The skill / maneuver / feat-action chips, driven by SkillActionCatalog.</summary>
    internal SkillActions Skills => _skills;

    // ---------------------------------------------------------------- Movement

    /// <summary>Tiles reachable with a single Stride (unoccupied, creature fits).</summary>
    public HashSet<PF2eVec> GetReachableTiles(ICharacter character)
        => _movement.GetReachableTiles(character);

    /// <summary>Adjacent tiles a Step can legally land on (unoccupied, fits).</summary>
    public HashSet<PF2eVec> GetStepTiles(ICharacter character)
        => _movement.GetStepTiles(character);

    /// <summary>Why a Step to <paramref name="dest"/> is illegal, or null when it is legal.</summary>
    public string? StepBlockedReason(ICharacter actor, PF2eVec dest)
        => _movement.StepBlockedReason(actor, dest);

    public List<PF2eVec>? GetPathTo(ICharacter character, PF2eVec dest)
        => _movement.GetPathTo(character, dest);

    /// <summary>Stride to <paramref name="dest"/> (1 action).</summary>
    public Task<bool> ExecuteStride(ICharacter character, PF2eVec dest, bool triggersReactions = true)
        => _movement.ExecuteStride(character, dest, triggersReactions);

    /// <summary>Step to an adjacent tile (1 action, no reactions).</summary>
    public Task<bool> ExecuteStep(ICharacter character, PF2eVec dest)
        => _movement.ExecuteStep(character, dest);

    // ---------------------------------------------------------------- Strikes

    /// <summary>Living enemies within the character's weapon reach.</summary>
    public List<ICharacter> GetStrikeTargets(ICharacter character)
        => _strikes.GetStrikeTargets(character);

    public AttackPreviewData? GetAttackPreview(ICharacter attacker, ICharacter target)
        => _strikes.GetAttackPreview(attacker, target);

    /// <summary>Current MAP the character would suffer on their next Strike (0 / -4/-5 / -8/-10).</summary>
    public int GetCurrentMap(ICharacter character)
        => _strikes.GetCurrentMap(character);

    /// <summary>Why Raise a Shield is disabled right now, or null when it can be performed.</summary>
    public string? GetRaiseShieldDisabledReason(ICharacter character)
        => _strikes.GetRaiseShieldDisabledReason(character);

    /// <summary>Strike a target (1 action).</summary>
    public Task<bool> ExecuteStrike(ICharacter character, ICharacter target)
        => _strikes.ExecuteStrike(character, target);

    /// <summary>Raise a Shield (1 action). Emits a ShieldRaised battle event on success.</summary>
    public Task<bool> ExecuteRaiseShield(ICharacter character)
        => _strikes.ExecuteRaiseShield(character);

    // ---------------------------------------------------------------- Spells

    /// <summary>Every castable spell / cost-variant for the action bar, with UI-facing text + gating.</summary>
    public List<SpellEntryView> GetSpellEntries(ICharacter character)
        => _spells.GetSpellEntries(character);

    /// <summary>The tiles a spell (variant) may be aimed at, plus how the interaction should behave.</summary>
    public TargetingPlan GetSpellTargets(ICharacter caster, string spellId, int variantIndex)
        => _spells.GetSpellTargets(caster, spellId, variantIndex);

    /// <summary>Candidate origin tiles the player can aim an area template at.</summary>
    public List<PF2eVec> GetAreaOriginTiles(ICharacter caster, string spellId)
        => _spells.GetAreaOriginTiles(caster, spellId);

    /// <summary>The tiles an area template covers when aimed at <paramref name="origin"/>.</summary>
    public List<PF2eVec> GetAreaTemplateTiles(ICharacter caster, string spellId, PF2eVec origin)
        => _spells.GetAreaTemplateTiles(caster, spellId, origin);

    /// <summary>Cast a preset spell at the clicked tile, area origin, or nothing (SelfArea).</summary>
    public Task<bool> ExecuteCast(ICharacter caster, string spellId, int variantIndex, PF2eVec? aim)
        => _spells.ExecuteCast(caster, spellId, variantIndex, aim);

    // ---------------------------------------------------------------- Skill actions

    /// <summary>
    /// Injected per-encounter gate: has (actor, creature slug) already spent its Recall Knowledge
    /// attempt this fight? Owned by <see cref="CombatSession"/>; null = unwired, nothing filtered.
    /// </summary>
    public Func<int, string, bool>? HasRecallAttempted
    {
        get => _skills.HasRecallAttempted;
        set => _skills.HasRecallAttempted = value;
    }

    /// <summary>Self-actions (no target) that execute immediately when their chip is pressed.</summary>
    public static bool IsSelfSkill(string id)
        => SkillActionCatalog.Get(id)?.Mode == SkillExecutionMode.Self;

    /// <summary>Move-mode chips (enter tile selection, not a target-a-creature flow).</summary>
    public static bool IsMoveSkill(string id)
        => SkillActionCatalog.Get(id)?.Mode == SkillExecutionMode.MoveTile;

    /// <summary>Every basic + feat-granted action chip for the action bar, with UI text and gating.</summary>
    public List<SkillEntryView> GetSkillEntries(ICharacter character)
        => _skills.GetSkillEntries(character);

    /// <summary>Legal target tiles for a skill / maneuver / feat action.</summary>
    public TargetingPlan GetSkillTargets(ICharacter actor, string actionId)
        => _skills.GetSkillTargets(actor, actionId);

    /// <summary>Tiles a Shielded Stride may reach: a normal Stride capped at half Speed.</summary>
    public HashSet<PF2eVec> GetShieldedStrideTiles(ICharacter character)
        => _skills.GetShieldedStrideTiles(character);

    /// <summary>Perform a skill action against the target on <paramref name="tile"/>.</summary>
    public Task<bool> ExecuteSkillAction(ICharacter actor, string actionId, PF2eVec tile)
        => _skills.ExecuteSkillAction(actor, actionId, tile);

    /// <summary>Execute a self-targeted action that fires immediately (Parry, Reload).</summary>
    public Task<bool> ExecuteSelfSkill(ICharacter actor, string actionId)
        => _skills.ExecuteSelfSkill(actor, actionId);

    /// <summary>Shielded Stride (feat move token, reaction-free, half-Speed cap).</summary>
    public Task<bool> ExecuteShieldedStride(ICharacter actor, PF2eVec dest)
        => _skills.ExecuteShieldedStride(actor, dest);

    /// <summary>Sudden Charge against the foe occupying <paramref name="tile"/>.</summary>
    public Task<bool> ExecuteSuddenChargeTile(ICharacter actor, PF2eVec tile)
        => _skills.ExecuteSuddenChargeTile(actor, tile);

    /// <summary>Sudden Charge (2 actions, Flourish): Stride twice, then Strike a foe in reach.</summary>
    public Task<bool> ExecuteSuddenCharge(ICharacter actor, ICharacter target)
        => _skills.ExecuteSuddenCharge(actor, target);

    // ---------------------------------------------------------------- Inspect

    /// <summary>
    /// Compact inspection snapshot of the unit occupying <paramref name="tile"/>, or null when the
    /// tile is empty. Read-only — feeds the hover-inspect panel.
    /// </summary>
    public UnitInspectView? GetUnitInspect(PF2eVec tile)
        => UnitInspectFactory.GetUnitInspect(_grid, tile);

    /// <summary>Whether a creature's stat-block <paramref name="field"/> is known to the player.</summary>
    public static bool IsCreatureFieldKnown(string? creatureId, CreatureKnowledgeField field)
        => UnitInspectFactory.IsCreatureFieldKnown(creatureId, field);
}
