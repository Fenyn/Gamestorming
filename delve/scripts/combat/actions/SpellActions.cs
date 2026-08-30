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
/// Query + command surface for the preset spell layer. The command side mirrors
/// AITurnExecutor.ExecuteSpell EXACTLY (SpellCast event before the cast, subscribe
/// SpellCastAction.OnSpellResolved for the duration, emit DamageDealt/CreatureDied/Healed from the
/// resolved per-target outcomes) so player and AI casts animate identically. The rules never run
/// twice — the SpellCastAction owns cost + slot consumption.
/// </summary>
internal sealed class SpellActions
{
    private readonly BattleGrid _grid;
    private readonly BattleEventEmitter _events;

    /// <summary>
    /// Spell lookup by id. Injected so the executor never names a content source: today
    /// <c>CombatSession</c> hands it <c>PresetSpells.Get</c>; a later content pack or a test double
    /// supplies its own without a change here. Null ids and unknown ids return null.
    /// </summary>
    private readonly Func<string, SpellCastAction?> _resolveSpell;

    internal SpellActions(
        BattleGrid grid, BattleEventEmitter events, Func<string, SpellCastAction?> resolveSpell)
    {
        _grid = grid;
        _events = events;
        _resolveSpell = resolveSpell;
    }

    // ---------------------------------------------------------------- Queries

    /// <summary>Every castable spell / cost-variant for the action bar, with UI-facing text + gating.</summary>
    internal List<SpellEntryView> GetSpellEntries(ICharacter character)
        => SpellEntryFactory.GetSpellEntries(character);

    /// <summary>The tiles a spell (variant) may be aimed at, plus how the interaction should behave.</summary>
    internal TargetingPlan GetSpellTargets(ICharacter caster, string spellId, int variantIndex)
    {
        var spell = _resolveSpell(spellId);
        if (spell == null) return new TargetingPlan();

        var variant = ResolveVariant(spell, variantIndex);
        var kind = KindOf(spell, variant);
        var plan = new TargetingPlan { Kind = kind };

        switch (kind)
        {
            case TargetingKind.SingleEnemy:
            case TargetingKind.MultiEnemy:
                foreach (var t in CombatantQuery.TargetsInRange(
                    caster, RangeTiles(spell, variant), enemies: true))
                    plan.Tiles.Add(t.GridPosition);
                break;

            case TargetingKind.SingleAlly:
                foreach (var t in CombatantQuery.TargetsInRange(
                    caster, RangeTiles(spell, variant), enemies: false))
                    plan.Tiles.Add(t.GridPosition);
                break;

            case TargetingKind.AreaAim:
                foreach (var t in GetAreaOriginTiles(caster, spellId))
                    plan.Tiles.Add(t);
                break;

            case TargetingKind.SelfArea:
                break; // cast fires immediately, no tile selection
        }
        return plan;
    }

    /// <summary>Candidate origin tiles the player can aim an area template at (board tiles near the caster).</summary>
    internal List<PF2eVec> GetAreaOriginTiles(ICharacter caster, string spellId)
    {
        var spell = _resolveSpell(spellId);
        var result = new List<PF2eVec>();
        if (spell?.Area == null) return result;

        int reach = System.Math.Max(spell.Area.SizeInTiles, 3) + 1;
        var origin = caster.GridPosition;
        for (int dx = -reach; dx <= reach; dx++)
        for (int dy = -reach; dy <= reach; dy++)
        {
            if (dx == 0 && dy == 0) continue;
            var tile = new PF2eVec(origin.x + dx, origin.y + dy);
            if (_grid.GetTile(tile) != null)
                result.Add(tile);
        }
        return result;
    }

    /// <summary>The tiles an area template covers when aimed at <paramref name="origin"/> (for hover preview).</summary>
    internal List<PF2eVec> GetAreaTemplateTiles(ICharacter caster, string spellId, PF2eVec origin)
    {
        var spell = _resolveSpell(spellId);
        if (spell?.Area == null || !spell.Area.HasArea) return new List<PF2eVec>();
        return AreaCalculator.GetAreaTiles(caster.GridPosition, origin, spell.Area, caster.TileWidth);
    }

    // ---------------------------------------------------------------- Commands

    /// <summary>
    /// Cast a preset spell. <paramref name="aim"/> is the clicked target tile (single/multi), the area
    /// origin (AreaAim), or null (SelfArea). Mirrors AITurnExecutor.ExecuteSpell's emission pattern.
    /// </summary>
    internal async Task<bool> ExecuteCast(ICharacter caster, string spellId, int variantIndex, PF2eVec? aim)
    {
        var spell = _resolveSpell(spellId);
        if (spell?.Spell == null) return false;

        var variant = ResolveVariant(spell, variantIndex);
        if (variant != null) spell.ApplyVariant(variant);

        var kind = KindOf(spell, variant);

        // Resolve the primary target character for validation + the SpellCast event.
        ICharacter? primary = aim.HasValue && (kind == TargetingKind.SingleEnemy
            || kind == TargetingKind.SingleAlly || kind == TargetingKind.MultiEnemy)
            ? _grid.GetGroundOccupant(aim.Value)
            : null;

        if (!spell.CanPerform(caster, primary))
        {
            spell.ClearVariant();
            return false;
        }

        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.SpellCast,
            Source = caster,
            Target = primary,
            Description = $"{caster.Name} casts {spell.ActionName}"
        });

        // Awaited ExecuteAsync variants: a save-reaction / Shield Block prompt may suspend the cast.
        SpellContext? resolved = null;
        void Capture(SpellCompletionEvent e) { if (e.Caster == caster) resolved = e.Context; }
        SpellCastAction.OnSpellResolved += Capture;
        try
        {
            switch (kind)
            {
                case TargetingKind.SelfArea:
                    await spell.ExecuteAsync(caster, null); // self-centered emanation resolves inside
                    break;

                case TargetingKind.MultiEnemy:
                    await spell.ExecuteMultiTargetAsync(caster, BuildMultiTargetList(caster, spell, variant, primary));
                    break;

                case TargetingKind.AreaAim:
                    await spell.ExecuteAreaAsync(caster, BuildAreaResult(caster, spell, aim!.Value));
                    break;

                default: // SingleEnemy / SingleAlly
                    await spell.ExecuteAsync(caster, primary);
                    break;
            }
        }
        finally
        {
            SpellCastAction.OnSpellResolved -= Capture;
        }

        await EmitSpellOutcomes(caster, resolved);
        return true;
    }

    private async Task EmitSpellOutcomes(ICharacter caster, SpellContext? resolved)
    {
        if (resolved?.TargetResults == null) return;

        foreach (var tr in resolved.TargetResults)
        {
            var target = tr.Target;
            if (target == null) continue;

            if (tr.DamageResult != null && tr.DamageResult.TotalDamage > 0)
            {
                await _events.EmitDamageAndDeath(caster, target, tr.DamageResult.TotalDamage,
                    type: tr.DamageResult.DamageType,
                    degree: tr.Degree,
                    description: $"{target.Name} takes {tr.DamageResult.TotalDamage} {tr.DamageResult.DamageType} ({tr.Degree})");
            }

            if (tr.HealingApplied > 0)
            {
                await _events.Emit(new BattleEvent
                {
                    Type = BattleEventType.Healed,
                    Source = caster,
                    Target = target,
                    IntValue = tr.HealingApplied,
                    Description = $"{target.Name} heals {tr.HealingApplied} HP"
                });
            }
        }
    }

    private List<ICharacter> BuildMultiTargetList(ICharacter caster, SpellCastAction spell,
        SpellCostVariant? variant, ICharacter? primary)
    {
        int max = spell.EffectiveMaxTargets > 0 ? spell.EffectiveMaxTargets : 1;
        int range = RangeTiles(spell, variant);
        var list = new List<ICharacter>();
        if (primary != null) list.Add(primary);

        var anchor = primary?.GridPosition ?? caster.GridPosition;
        var candidates = new List<ICharacter>(
            CombatantQuery.TargetsInRange(caster, range, enemies: true));
        candidates.Sort((a, b) =>
            AreaCalculator.GetPF2eDistance(anchor, 1, a.GridPosition, a.TileWidth)
            .CompareTo(AreaCalculator.GetPF2eDistance(anchor, 1, b.GridPosition, b.TileWidth)));

        foreach (var cand in candidates)
        {
            if (list.Count >= max) break;
            if (!list.Contains(cand)) list.Add(cand);
        }
        return list;
    }

    private AreaTargetResult BuildAreaResult(ICharacter caster, SpellCastAction spell, PF2eVec origin)
    {
        var tiles = AreaCalculator.GetAreaTiles(caster.GridPosition, origin, spell.Area, caster.TileWidth);
        var result = new AreaTargetResult { Origin = origin, AffectedTiles = tiles, AreaType = spell.Area.Type };
        var seen = new HashSet<ICharacter>();
        foreach (var tile in tiles)
        {
            var occ = _grid.GetGroundOccupant(tile);
            if (occ != null && occ.Health != null && !occ.Health.IsDead && seen.Add(occ))
                result.AffectedCharacters.Add(occ);
        }
        return result;
    }

    // ---------------------------------------------------------------- Spell helpers

    private static SpellCostVariant? ResolveVariant(SpellCastAction? spell, int variantIndex)
    {
        if (spell?.Spell?.CostVariants == null || variantIndex < 0
            || variantIndex >= spell.Spell.CostVariants.Count)
            return null;
        return spell.Spell.CostVariants[variantIndex];
    }

    /// <summary>How a spell (variant) selects what it affects. Shared with SpellEntryFactory.</summary>
    internal static TargetingKind KindOf(SpellCastAction spell, SpellCostVariant? variant)
    {
        bool area = spell.RequiresAreaTarget || (variant?.IsAreaEffect ?? false);
        bool selfCentered = variant?.IsSelfCentered ?? false;
        if (area && selfCentered) return TargetingKind.SelfArea;
        if (area) return TargetingKind.AreaAim;

        TargetMode mode = variant?.TargetMode ?? spell.TargetMode;
        if (mode == TargetMode.Allies) return TargetingKind.SingleAlly;

        int max = variant?.MaxTargets > 0 ? variant.MaxTargets : spell.MaxTargets;
        return max > 1 ? TargetingKind.MultiEnemy : TargetingKind.SingleEnemy;
    }

    private static int RangeTiles(SpellCastAction spell, SpellCostVariant? variant)
    {
        int feet = variant?.RangeInFeet ?? spell.Area?.RangeInFeet ?? 0;
        int tiles = feet / MovementActions.FeetPerTile;
        return tiles <= 0 ? 1 : tiles; // 0 ft = touch/adjacent
    }
}
