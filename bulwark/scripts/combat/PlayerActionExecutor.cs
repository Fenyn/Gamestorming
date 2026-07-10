using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Data;
using PF2e.Actions;
using PF2e.Actions.SkillActions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.Spellcasting;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Executes and previews the four M1 player actions (Stride, Step, Strike, Raise a Shield).
/// The command side mirrors <c>AITurnExecutor</c>'s BattleEvent emission exactly so player and AI
/// turns animate identically through the shared <see cref="BattleRunner"/>. The query side feeds
/// the UI/controller (reachable tiles, targets, previews) with no side effects.
///
/// Plain C#: the only Godot-free dependency is the engine. Consumes actions from
/// <c>ICharacter.Actions</c> so the action bar stays in sync.
/// </summary>
public sealed class PlayerActionExecutor
{
    private const int FeetPerTile = 5;

    private readonly BattleRunner _runner;
    private readonly BattleGrid _grid;
    private readonly RaiseShieldAction _raiseShield = new();
    private readonly StepAction _step = new();

    public PlayerActionExecutor(BattleRunner runner, BattleGrid grid)
    {
        _runner = runner;
        _grid = grid;
    }

    // ---------------------------------------------------------------- Queries

    /// <summary>Tiles reachable with a single Stride (unoccupied, creature fits).</summary>
    public HashSet<PF2eVec> GetReachableTiles(ICharacter character)
    {
        var result = new HashSet<PF2eVec>();
        int speed = SpeedInTiles(character);
        if (speed <= 0 || character.Actions == null || character.Actions.TotalActionsRemaining <= 0)
            return result;

        var map = Pathfinder.FindReachableTiles(_grid, BuildRequest(character, speed));
        foreach (var kvp in map)
        {
            var tile = kvp.Key;
            if (tile == character.GridPosition) continue;
            if (kvp.Value.Cost <= 0) continue;
            if (!_grid.CanCreatureFit(tile, character.TileWidth, ignore: character)) continue;
            result.Add(tile);
        }
        return result;
    }

    /// <summary>Adjacent tiles a Step can legally land on (unoccupied, fits).</summary>
    public HashSet<PF2eVec> GetStepTiles(ICharacter character)
    {
        var result = new HashSet<PF2eVec>();
        if (character.Actions == null || character.Actions.TotalActionsRemaining <= 0)
            return result;

        foreach (var neighbor in _grid.GetNeighbors(character.GridPosition))
        {
            var tile = _grid.GetTile(neighbor);
            if (tile == null || tile.IsBlocked) continue;
            if (!_grid.CanCreatureFit(neighbor, character.TileWidth, ignore: character)) continue;
            result.Add(neighbor);
        }
        return result;
    }

    /// <summary>Living enemies within the character's weapon reach.</summary>
    public List<ICharacter> GetStrikeTargets(ICharacter character)
    {
        var targets = new List<ICharacter>();
        var registry = CombatantRegistry.Instance;
        if (registry == null) return targets;

        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        int reach = weapon.GetRangeInTiles();

        foreach (var other in registry.All)
        {
            if (other.TeamId == character.TeamId) continue;
            if (other.Health == null || other.Health.IsDead) continue;
            if (FlankingCalculator.IsWithinReach(
                character.GridPosition, character.TileWidth,
                other.GridPosition, other.TileWidth, reach))
                targets.Add(other);
        }
        return targets;
    }

    public List<PF2eVec>? GetPathTo(ICharacter character, PF2eVec dest)
    {
        int speed = SpeedInTiles(character);
        if (speed <= 0) return null;
        return Pathfinder.FindPath(_grid, character.GridPosition, dest, BuildRequest(character, speed));
    }

    public AttackPreviewData? GetAttackPreview(ICharacter attacker, ICharacter target)
    {
        if (attacker == null || target == null) return null;
        return CombatPreviewCalculator.CalculateAttackPreview(attacker, target);
    }

    /// <summary>Current MAP the character would suffer on their next Strike (0 / -4/-5 / -8/-10).</summary>
    public int GetCurrentMap(ICharacter character)
    {
        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        return character.Combat?.GetCurrentMAP(weapon.IsAgile) ?? 0;
    }

    // ---------------------------------------------------------------- Commands

    /// <summary>Stride to <paramref name="dest"/> (1 action). Mirrors AITurnExecutor.ExecuteMove.</summary>
    public async Task<bool> ExecuteStride(ICharacter character, PF2eVec dest)
    {
        int speed = SpeedInTiles(character);
        if (speed <= 0) return false;

        var path = Pathfinder.FindPath(_grid, character.GridPosition, dest, BuildRequest(character, speed));
        if (path == null || path.Count < 2) return false;

        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.MovementStarted,
            Source = character,
            Path = path,
            Description = $"{character.Name} Strides to ({dest.x}, {dest.y})"
        });

        for (int i = 1; i < path.Count; i++)
        {
            var from = path[i - 1];
            var to = path[i];

            var args = new BeforeMoveEventArgs(character, from, to, path.Count, path.Count * FeetPerTile);
            MovementEvents.FireBeforeMove(args);

            if (args.Cancelled)
            {
                _grid.MoveCreature(character, from);
                await _runner.Emit(BattleEventType.MovementCompleted, source: character,
                    description: $"{character.Name} movement interrupted!");
                return true;
            }

            _grid.MoveCreature(character, to);

            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.MovementStep,
                Source = character
            });
        }

        await _runner.Emit(BattleEventType.MovementCompleted, source: character);
        return true;
    }

    /// <summary>Step to an adjacent tile (1 action, no reactions).</summary>
    public async Task<bool> ExecuteStep(ICharacter character, PF2eVec dest)
    {
        var from = character.GridPosition;
        _step.Destination = dest;
        if (!_step.CanPerform(character))
            return false;

        // Execute consumes the action and sets GridPosition, but does NOT update grid occupancy.
        _step.Execute(character);

        // Rewind GridPosition so MoveCreature clears the *old* tile before occupying the new one.
        character.GridPosition = from;
        _grid.MoveCreature(character, dest);

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.MovementStarted,
            Source = character,
            Path = new List<PF2eVec> { from, dest },
            Description = $"{character.Name} Steps"
        });
        await _runner.Emit(BattleEventType.MovementCompleted, source: character);
        return true;
    }

    /// <summary>Strike a target (1 action). Mirrors AITurnExecutor's equipped-weapon branch.</summary>
    public async Task<bool> ExecuteStrike(ICharacter character, ICharacter target)
    {
        if (target?.Health == null || target.Health.IsDead) return false;

        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        if (!FlankingCalculator.IsWithinReach(
            character.GridPosition, character.TileWidth,
            target.GridPosition, target.TileWidth, weapon.GetRangeInTiles()))
            return false;

        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        // StrikeResolver runs its callbacks synchronously, so strikeCtx is fully resolved on return.
        StrikeContext? strikeCtx = null;
        StrikeResolver.ExecuteStrike(character, target, sourceAction: null,
            onComplete: ctx => strikeCtx = ctx);

        if (strikeCtx == null) return true;

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.AttackRolled,
            Source = character,
            Target = target,
            Degree = strikeCtx.Degree,
            Description = $"{character.Name} Strikes {target.Name} with {strikeCtx.WeaponName}: " +
                $"d20({strikeCtx.D20Roll})+{strikeCtx.EffectiveBonus}={strikeCtx.Total} vs AC {strikeCtx.TargetAC} → {strikeCtx.Degree}"
        });

        if (strikeCtx.Hit && strikeCtx.DamageResult != null)
        {
            int damage = strikeCtx.DamageResult.TotalDamage;

            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.DamageDealt,
                Source = character,
                Target = target,
                IntValue = damage,
                DamageType = strikeCtx.DamageResult.DamageType,
                Description = $"{target.Name} takes {damage} {strikeCtx.DamageResult.DamageType} damage"
            });

            if (strikeCtx.TargetKilled || target.Health.IsDead)
            {
                await _runner.Emit(new BattleEvent
                {
                    Type = BattleEventType.CreatureDied,
                    Source = target,
                    Description = $"{target.Name} is slain!"
                });
            }
        }

        return true;
    }

    /// <summary>Raise a Shield (1 action). Emits a ShieldRaised battle event on success.</summary>
    public async Task<bool> ExecuteRaiseShield(ICharacter character)
    {
        if (!_raiseShield.CanPerform(character))
            return false;

        _raiseShield.Execute(character);

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.ShieldRaised,
            Source = character,
            Description = $"{character.Name} raises a shield"
        });
        return true;
    }

    // ================================================================ Spells
    //
    // Query + command surface for the preset spell layer. The command side mirrors
    // AITurnExecutor.ExecuteSpell EXACTLY (SpellCast event before the cast, subscribe
    // SpellCastAction.OnSpellResolved for the duration, emit DamageDealt/CreatureDied/Healed from the
    // resolved per-target outcomes) so player and AI casts animate identically. The rules never run
    // twice — the SpellCastAction owns cost + slot consumption.

    /// <summary>Every castable spell / cost-variant for the action bar, with UI-facing text + gating.</summary>
    public List<SpellEntryView> GetSpellEntries(ICharacter character)
    {
        var list = new List<SpellEntryView>();
        var sc = character.Spellcasting;
        if (sc == null) return list;

        foreach (var cantrip in sc.GetUniqueCantrips())
            AppendSpellEntries(list, character, cantrip as SpellCastAction, isCantrip: true);
        foreach (var leveled in sc.GetUniqueLeveledSpells())
            AppendSpellEntries(list, character, leveled as SpellCastAction, isCantrip: false);

        return list;
    }

    private void AppendSpellEntries(List<SpellEntryView> list, ICharacter c, SpellCastAction? spell, bool isCantrip)
    {
        if (spell?.Spell == null || string.IsNullOrEmpty(spell.SpellId)) return;

        int actions = c.Actions?.TotalActionsRemaining ?? 0;
        string slotsText = isCantrip ? "cantrip" : $"x{c.Spellcasting?.GetPreparedCount(spell) ?? 0}";
        bool baseCan = spell.CanPerform(c);

        if (spell.Spell.HasCostVariants)
        {
            var variants = spell.Spell.CostVariants;
            for (int i = 0; i < variants.Count; i++)
            {
                var v = variants[i];
                list.Add(new SpellEntryView
                {
                    SpellId = spell.SpellId,
                    VariantIndex = i,
                    Name = $"{spell.ActionName} ({v.Label})",
                    Rank = spell.Spell.SpellLevel,
                    CostText = $"{v.ActionCost}a",
                    SlotsText = slotsText,
                    Targeting = KindOf(spell, v),
                    Castable = baseCan && actions >= v.ActionCost,
                });
            }
        }
        else
        {
            list.Add(new SpellEntryView
            {
                SpellId = spell.SpellId,
                VariantIndex = -1,
                Name = spell.ActionName,
                Rank = spell.Spell.SpellLevel,
                CostText = $"{spell.ActionCostCount}a",
                SlotsText = slotsText,
                Targeting = KindOf(spell, null),
                Castable = baseCan && actions >= spell.ActionCostCount,
            });
        }
    }

    /// <summary>The tiles a spell (variant) may be aimed at, plus how the interaction should behave.</summary>
    public TargetingPlan GetSpellTargets(ICharacter caster, string spellId, int variantIndex)
    {
        var spell = PresetSpells.Get(spellId);
        var variant = ResolveVariant(spell, variantIndex);
        var kind = KindOf(spell, variant);
        var plan = new TargetingPlan { Kind = kind };

        switch (kind)
        {
            case TargetingKind.SingleEnemy:
            case TargetingKind.MultiEnemy:
                foreach (var t in TargetsInRange(caster, RangeTiles(spell, variant), enemies: true))
                    plan.Tiles.Add(t.GridPosition);
                break;

            case TargetingKind.SingleAlly:
                foreach (var t in TargetsInRange(caster, RangeTiles(spell, variant), enemies: false))
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
    public List<PF2eVec> GetAreaOriginTiles(ICharacter caster, string spellId)
    {
        var spell = PresetSpells.Get(spellId);
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
    public List<PF2eVec> GetAreaTemplateTiles(ICharacter caster, string spellId, PF2eVec origin)
    {
        var spell = PresetSpells.Get(spellId);
        if (spell?.Area == null || !spell.Area.HasArea) return new List<PF2eVec>();
        return AreaCalculator.GetAreaTiles(caster.GridPosition, origin, spell.Area, caster.TileWidth);
    }

    /// <summary>
    /// Cast a preset spell. <paramref name="aim"/> is the clicked target tile (single/multi), the area
    /// origin (AreaAim), or null (SelfArea). Mirrors AITurnExecutor.ExecuteSpell's emission pattern.
    /// </summary>
    public async Task<bool> ExecuteCast(ICharacter caster, string spellId, int variantIndex, PF2eVec? aim)
    {
        var spell = PresetSpells.Get(spellId);
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

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.SpellCast,
            Source = caster,
            Target = primary,
            Description = $"{caster.Name} casts {spell.ActionName}"
        });

        SpellContext? resolved = null;
        void Capture(SpellCompletionEvent e) { if (e.Caster == caster) resolved = e.Context; }
        SpellCastAction.OnSpellResolved += Capture;
        try
        {
            switch (kind)
            {
                case TargetingKind.SelfArea:
                    spell.Execute(caster, null); // self-centered emanation resolves inside Execute
                    break;

                case TargetingKind.MultiEnemy:
                    spell.ExecuteMultiTarget(caster, BuildMultiTargetList(caster, spell, variant, primary));
                    break;

                case TargetingKind.AreaAim:
                    spell.ExecuteArea(caster, BuildAreaResult(caster, spell, aim!.Value));
                    break;

                default: // SingleEnemy / SingleAlly
                    spell.Execute(caster, primary);
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
                await _runner.Emit(new BattleEvent
                {
                    Type = BattleEventType.DamageDealt,
                    Source = caster,
                    Target = target,
                    IntValue = tr.DamageResult.TotalDamage,
                    DamageType = tr.DamageResult.DamageType,
                    Degree = tr.Degree,
                    Description = $"{target.Name} takes {tr.DamageResult.TotalDamage} {tr.DamageResult.DamageType} ({tr.Degree})"
                });

                if (target.Health != null && target.Health.IsDead)
                {
                    await _runner.Emit(new BattleEvent
                    {
                        Type = BattleEventType.CreatureDied,
                        Source = target,
                        Description = $"{target.Name} is slain!"
                    });
                }
            }

            if (tr.HealingApplied > 0)
            {
                await _runner.Emit(new BattleEvent
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
        var candidates = new List<ICharacter>(TargetsInRange(caster, range, enemies: true));
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

    private static TargetingKind KindOf(SpellCastAction spell, SpellCostVariant? variant)
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
        int tiles = feet / FeetPerTile;
        return tiles <= 0 ? 1 : tiles; // 0 ft = touch/adjacent
    }

    private IEnumerable<ICharacter> TargetsInRange(ICharacter caster, int rangeTiles, bool enemies)
    {
        var registry = CombatantRegistry.Instance;
        if (registry == null) yield break;

        foreach (var other in registry.All)
        {
            if (other.Health == null || other.Health.IsDead) continue;
            bool sameTeam = other.TeamId == caster.TeamId;
            if (enemies && sameTeam) continue;
            if (!enemies && !sameTeam) continue;

            int dist = AreaCalculator.GetPF2eDistance(
                caster.GridPosition, caster.TileWidth, other.GridPosition, other.TileWidth);
            if (dist <= rangeTiles)
                yield return other;
        }
    }

    // ================================================================ Skill actions

    /// <summary>The three placeholder skill actions (Trip, Demoralize, Battle Medicine) with gating.</summary>
    public List<SkillEntryView> GetSkillEntries(ICharacter character)
    {
        var list = new List<SkillEntryView>();
        foreach (var id in new[] { "trip", "demoralize", "battle-medicine" })
        {
            var action = MakeSkillAction(id);
            if (action == null) continue;
            bool hasTargets = GetSkillTargets(character, id).Tiles.Count > 0;
            list.Add(new SkillEntryView
            {
                ActionId = id,
                Name = action.ActionName,
                CostText = "1a",
                Targeting = id == "battle-medicine" ? TargetingKind.SingleAlly : TargetingKind.SingleEnemy,
                Castable = action.CanPerform(character) && hasTargets,
            });
        }
        return list;
    }

    /// <summary>Legal target tiles for a skill action.</summary>
    public TargetingPlan GetSkillTargets(ICharacter actor, string actionId)
    {
        var plan = new TargetingPlan
        {
            Kind = actionId == "battle-medicine" ? TargetingKind.SingleAlly : TargetingKind.SingleEnemy
        };

        switch (actionId)
        {
            case "trip":
                foreach (var t in TargetsInRange(actor, 1, enemies: true))
                    plan.Tiles.Add(t.GridPosition);
                break;

            case "demoralize":
                foreach (var t in TargetsInRange(actor, 6, enemies: true)) // 30 ft
                    plan.Tiles.Add(t.GridPosition);
                break;

            case "battle-medicine":
                foreach (var t in TargetsInRange(actor, 1, enemies: false))
                {
                    if (BattleMedicineAction.IsImmune(actor.UniqueId, t.UniqueId)) continue;
                    plan.Tiles.Add(t.GridPosition);
                }
                break;
        }
        return plan;
    }

    /// <summary>
    /// Perform a skill action against the target on <paramref name="tile"/>. SkillActionBase resolves
    /// synchronously and applies its own damage/healing/conditions (Prone, Frightened flow to the log
    /// via CombatLog). We emit an ActionUsed event plus HP-delta-derived Damage/Heal/Died events so the
    /// board animates without re-implementing any rules.
    /// </summary>
    public async Task<bool> ExecuteSkillAction(ICharacter actor, string actionId, PF2eVec tile)
    {
        var action = MakeSkillAction(actionId);
        if (action == null) return false;

        var target = _grid.GetGroundOccupant(tile);
        if (target == null || target.Health == null || target.Health.IsDead) return false;
        if (!action.CanPerform(actor, target)) return false;

        int preHp = target.Health.CurrentHP;
        action.Execute(actor, target);

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.ActionUsed,
            Source = actor,
            Target = target,
            Description = $"{actor.Name} uses {action.ActionName} on {target.Name}"
        });

        int delta = preHp - target.Health.CurrentHP;
        if (delta > 0)
        {
            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.DamageDealt,
                Source = actor,
                Target = target,
                IntValue = delta,
                Description = $"{target.Name} takes {delta} damage"
            });
            if (target.Health.IsDead)
                await _runner.Emit(new BattleEvent
                {
                    Type = BattleEventType.CreatureDied,
                    Source = target,
                    Description = $"{target.Name} is slain!"
                });
        }
        else if (delta < 0)
        {
            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.Healed,
                Source = actor,
                Target = target,
                IntValue = -delta,
                Description = $"{target.Name} heals {-delta} HP"
            });
        }
        return true;
    }

    /// <summary>
    /// Construct a per-call skill-action instance. These SkillActionBase subclasses ship WITHOUT
    /// cost/target metadata (it's a construction-site concern), so we configure it here: all cost 1;
    /// Trip/Demoralize target enemies; Battle Medicine targets allies including self.
    /// </summary>
    private static BaseAction? MakeSkillAction(string actionId) => actionId switch
    {
        "trip" => new TripAction
        {
            ActionName = "Trip", ActionCostCount = 1,
            RequiresTarget = true, TargetMode = TargetMode.Enemies
        },
        "demoralize" => new DemoralizeAction
        {
            ActionName = "Demoralize", ActionCostCount = 1,
            RequiresTarget = true, TargetMode = TargetMode.Enemies
        },
        "battle-medicine" => new BattleMedicineAction
        {
            ActionName = "Battle Medicine", ActionCostCount = 1,
            RequiresTarget = true, TargetMode = TargetMode.Allies, CanTargetSelf = true
        },
        _ => null
    };

    // ---------------------------------------------------------------- Helpers

    private PathfindingRequest BuildRequest(ICharacter character, int maxDistance) => new()
    {
        Origin = character.GridPosition,
        MaxDistance = maxDistance,
        TileWidth = character.TileWidth,
        MaxStepUpElevations = 1,
        OriginTeamId = character.TeamId
    };

    private static int SpeedInTiles(ICharacter character)
    {
        int feet = character.StatProvider?.BaseSpeedInFeet
                   ?? character.CreatureStats?.BaseSpeedInFeet
                   ?? 25;
        return feet / FeetPerTile;
    }
}
