using System;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Presets;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Grid;
using PF2e.Utilities;

namespace Delve.Rules;

/// <summary>Encounter-owned manifestation. It occupies a real tile but receives no extra turn.</summary>
public sealed class EidolonLink : IDisposable
{
    private static readonly ConditionalWeakTable<ICharacter, EidolonLink> Links = new();
    public static EidolonLink? For(ICharacter owner) => Links.TryGetValue(owner,out var link) ? link : null;
    public ICharacter Owner { get; }
    public PF2eCharacter Eidolon { get; }
    private readonly BattleGrid _grid;
    private readonly MovementActions _movement;
    public bool CanAct => Owner.Health.IsAlive && Owner.Conditions?.HasCondition(PF2e.Conditions.Condition.Unconscious) != true;

    public EidolonLink(PF2eCharacter owner, BattleGrid grid, BattleRunner runner)
    {
        Owner=owner; _grid=grid; _movement=new MovementActions(grid,new BattleEventEmitter(runner)); Eidolon=PresetCharacters.BuildEarthEidolon(owner);
        var origin=owner.GridPosition;
        PF2e.Vector2Int? spot=null;
        for (int radius=1;radius<=3 && spot==null;radius++)
            for (int dx=-radius;dx<=radius && spot==null;dx++)
                for (int dy=-radius;dy<=radius && spot==null;dy++)
                {
                    var pos=origin+new PF2e.Vector2Int(dx,dy);
                    if (grid.CanCreatureFit(pos,1) && grid.GetGroundOccupant(pos)==null) spot=pos;
                }
        if (spot==null) throw new InvalidOperationException("No legal tile for Hilde's earth eidolon.");
        grid.PlaceCreature(Eidolon,spot.Value);
        Links.Remove(owner); Links.Add(owner,this);
    }
    public bool CanStrike(ICharacter? target) => CanAct && (target==null ||
        FlankingCalculator.IsWithinReach(Eidolon.GridPosition,1,target.GridPosition,target.TileWidth,1));
    public Task Strike(ICharacter target,BaseAction action) => StrikeResolver.ExecuteStrike(Eidolon,target,action);
    public async Task Advance(ICharacter target)
    {
        var reachable=Pathfinder.FindReachableTiles(_grid,MovementActions.BuildRequest(Eidolon,MovementActions.SpeedInTiles(Eidolon)));
        var candidates=reachable.Keys.Where(p=>_grid.CanCreatureFit(p,1,ignore:Eidolon));
        int Distance(PF2e.Vector2Int p) => Math.Max(Math.Abs(p.x-target.GridPosition.x),Math.Abs(p.y-target.GridPosition.y));
        var destination=candidates.OrderBy(Distance).FirstOrDefault(Eidolon.GridPosition);
        await _movement.ExecuteStride(Eidolon,destination);
    }
    private int _surgeUntil;
    public void Tick() { if (WayfarerFeature.State(Owner).Turns>=_surgeUntil) Eidolon.Modifiers.RemoveModifier(_surge); }
    private readonly Guid _surge = Guid.NewGuid();
    public void Surge()
    {
        _surgeUntil=WayfarerFeature.State(Owner).Turns+10;
        Eidolon.Modifiers.RemoveModifier(_surge);
        Eidolon.Modifiers.AddModifier(new PF2e.Conditions.ConditionModifier { Source="Evolution Surge",SourceInstanceId=_surge,
            TargetStat=PF2e.Conditions.StatType.Speed,Type=PF2e.Conditions.ModifierType.Status,Value=20 });
    }
    public void Dispose()
    {
        if (For(Owner)==this) Links.Remove(Owner);
        _grid.RemoveCreature(Eidolon);
    }
}
