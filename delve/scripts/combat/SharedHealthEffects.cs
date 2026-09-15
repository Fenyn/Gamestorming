using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Rules;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Contexts;

namespace Delve.Combat;

/// <summary>Encounter-owned spell bookkeeping for linked bodies. This observer never calls the
/// damage continuation; ReactionManager remains the single damage-delivery owner.</summary>
public sealed class SharedHealthEffects : IDisposable, IRuleEventHandler<DamageMitigationContext>
{
    private readonly Func<bool> _isLive;
    private readonly List<EidolonLink> _links = new();
    private readonly Dictionary<DamageResult,ICharacter> _spellTargets = new();
    private readonly Dictionary<DamageResult,ICharacter> _damageBodies = new();
    private readonly Dictionary<ICharacter,int> _bodyDamage = new();
    private readonly Dictionary<EidolonLink,int> _applied = new();
    private readonly Dictionary<EidolonLink,int> _initialHp = new();
    private ICharacter? _caster;
    public SharedHealthEffects(Func<bool> isLive)
    {
        _isLive=isLive;
        ReactionEvents.OnDamageReactionCheck+=ObserveDamage;
        SpellCastAction.OnSpellCasted+=Begin;
        SpellCastAction.OnSpellResolved+=End;
    }
    public void Register(EidolonLink link)
    {
        _links.Add(link);
        link.Owner.RuleEvents.Subscribe<DamageMitigationContext>(this,RuleEventPriority.Final);
    }
    private void Begin(ICharacter caster)
    {
        if (!_isLive()) return;
        _caster=caster; _spellTargets.Clear(); _bodyDamage.Clear(); _applied.Clear(); _initialHp.Clear();
        foreach (var link in _links) _initialHp[link]=link.Owner.Health.CurrentHP;
    }
    private Task ObserveDamage(ICharacter source,ICharacter target,DamageResult damage,Action applyDamage)
    {
        if (_isLive() && _links.Any(l=>l.Owner==target || l.Eidolon==target)) _damageBodies[damage]=target;
        if (_isLive() && _caster!=null && source==_caster)
        {
            _spellTargets[damage]=target;
            if (WayfarerFeature.Find(target)?.Class=="Oracle") WayfarerFeature.State(target).ExposedToSpell=true;
        }
        return Task.CompletedTask;
    }
    public void HandleEvent(DamageMitigationContext ctx)
    {
        if (!_isLive()) return;
        if (_damageBodies.Remove(ctx.DamageResult,out var actualBody))
        {
            var reinforced=_links.FirstOrDefault(l=>l.Eidolon==actualBody && FeatEncounter.State(l.Owner).Reinforced);
            if (reinforced!=null) ctx.DamageReduction=Math.Max(ctx.DamageReduction,(reinforced.Owner.StatProvider.Level+1)/4);
        }
        if (!_spellTargets.TryGetValue(ctx.DamageResult,out var body)) return;
        var link=_links.FirstOrDefault(l=>l.Owner==body || l.Eidolon==body);
        if (link==null) return;
        int incoming=ctx.IsImmune?0:Math.Max(0,ctx.DamageResult.TotalDamage-ctx.DamageReduction+ctx.DamageIncrease);
        _bodyDamage[body]=_bodyDamage.GetValueOrDefault(body)+incoming;
        int greatest=Math.Max(_bodyDamage.GetValueOrDefault(link.Owner),_bodyDamage.GetValueOrDefault(link.Eidolon));
        int delta=greatest-_applied.GetValueOrDefault(link);
        _applied[link]=greatest;
        ctx.DamageReduction=ctx.DamageResult.TotalDamage+ctx.DamageIncrease-delta;
    }
    private void End(SpellCompletionEvent completed)
    {
        if (!_isLive() || completed.Caster!=_caster) return;
        // Healing has no pre-delivery reaction seam. Resolve simultaneous healing from the pool
        // before the spell and the greatest body result, avoiding an artificial second heal.
        foreach (var link in _links)
        {
            var hits=completed.Context.TargetResults.Where(r=>r.Target==link.Owner || r.Target==link.Eidolon).ToArray();
            if (hits.Select(r=>r.Target).Distinct().Count()<2 || hits.All(r=>r.HealingApplied==0)) continue;
            int heal=hits.GroupBy(r=>r.Target).Max(g=>g.Sum(r=>r.HealingApplied));
            if (_initialHp.TryGetValue(link,out int start)) link.Owner.Health.SetCurrentHP(Math.Min(link.Owner.Health.MaxHP,start+heal));
        }
        _caster=null; _spellTargets.Clear();
    }
    public void Dispose()
    {
        ReactionEvents.OnDamageReactionCheck-=ObserveDamage;
        SpellCastAction.OnSpellCasted-=Begin;
        SpellCastAction.OnSpellResolved-=End;
        foreach (var link in _links) link.Owner.RuleEvents.Unsubscribe<DamageMitigationContext>(this);
        _links.Clear(); _spellTargets.Clear(); _damageBodies.Clear(); _caster=null;
    }
}
