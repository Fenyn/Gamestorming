using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Contexts;
using PF2e.TurnManagement;

namespace Delve.Rules;

/// <summary>Native class features for the authored recruits. Runtime state belongs to each
/// character; the encounter explicitly binds and releases turn events.</summary>
public sealed class WayfarerFeature : CharacterFeature
{
    public string Class { get; }
    private static readonly ConditionalWeakTable<ICharacter, WayfarerState> States = new();
    public static WayfarerState State(ICharacter c) => States.GetValue(c, _ => new());
    public static WayfarerFeature? Find(ICharacter c) => c.Features?.ActiveFeatures.OfType<WayfarerFeature>().FirstOrDefault();
    private readonly Dictionary<ICharacter, DamageHandler> _handlers = new();

    public WayfarerFeature(string name, string specialty)
    {
        Class = name; FeatureId = $"{name.ToLowerInvariant()}-identity"; DisplayName = specialty;
        Description = ClassActions.Description(name); Category = FeatureCategory.ClassFeature; LevelRequirement = 1;
        GrantedActions = ClassActions.For(name).Where(a=>a.Id!="life-boost").Select(a => (BaseAction)new ClassAction(a)).ToList();
    }

    public override void OnGranted(ICharacter c, RuleEventBus bus)
    {
        if (_handlers.ContainsKey(c)) return;
        var handler = new DamageHandler(c, Class);
        _handlers[c] = handler;
        bus.Subscribe<DamageRollContext>(handler, RuleEventPriority.Bonus);
        bus.Subscribe<AttackRollContext>(handler, RuleEventPriority.Bonus);
        bus.Subscribe<SkillCheckContext>(handler, RuleEventPriority.Bonus);
        bus.Subscribe<SavingThrowContext>(handler, RuleEventPriority.Bonus);
        bus.Subscribe<DamageMitigationContext>(handler, RuleEventPriority.Bonus);
        if (c.Spellcasting != null && c.Spellcasting.MaxFocusPoints == 0)
            c.Spellcasting.IncrementMaxFocusPoints(Class == "Psychic" ? 2 : 1);
    }

    public override void OnRevoked(ICharacter c, RuleEventBus bus)
    {
        if (!_handlers.Remove(c, out var handler)) return;
        bus.Unsubscribe<DamageRollContext>(handler);
        bus.Unsubscribe<AttackRollContext>(handler);
        bus.Unsubscribe<SkillCheckContext>(handler);
        bus.Unsubscribe<SavingThrowContext>(handler);
        bus.Unsubscribe<DamageMitigationContext>(handler);
    }

    public static IDisposable Bind(ICharacter c, TurnManager turns)
    {
        var feature = Find(c);
        if (feature == null) return new Binding(() => { });
        var s = State(c);
        SetPanache(c,false);
        s.ResetEncounter();
        var bindingId=s.BindingId=Guid.NewGuid();
        void Start(ICharacter current)
        {
            if (s.BindingId!=bindingId) return;
            foreach (var heal in s.Regeneration.ToArray())
            {
                if (heal.Target != current) continue;
                if (!current.Health.IsDead) current.Health.Heal(heal.Amount);
                if (--heal.Turns == 0) s.Regeneration.Remove(heal);
            }
            if (current != c) return;
            s.CastLastTurn = s.SpellCastThisTurn; s.SpellCastThisTurn = false;
            if (s.BuffsExpireAt<=s.Turns+1) s.ClearBuffs();
            s.LingeringUsed=false; s.ActTogetherUsed=false;
            s.PrecisionUsed = false; s.HexUsed = false; s.FinisherUsed = false;
            s.Turns++;
            EidolonLink.For(c)?.Tick();
            if (s.WeaponTrance && s.Turns >= s.TranceUntil)
            { s.WeaponTrance=false; c.Stats.CharacterClass.MartialWeaponProficiency=ProficiencyLevel.Untrained; }
            if (s.PsycheTurns > 0 && --s.PsycheTurns == 0)
            {
                s.PsycheRecovery = 2;
                c.Conditions?.AddCondition(ConditionDatabase.Instance.Stupefied, value:2, duration:2, source:c);
            }
            else if (s.PsycheRecovery > 0) s.PsycheRecovery--;
            if (feature.Class == "Barbarian" && s.Turns == 1) ClassAction.EnterRage(c);
        }
        void Resolved(SpellCompletionEvent _) { s.ExposedToSpell=false; }
        SpellCastAction.OnSpellResolved += Resolved;
        void Cast(ICharacter actor) { if (actor == c) s.SpellCastThisTurn = true; }
        SpellCastAction.OnSpellCasted += Cast;
        turns.OnTurnStart += Start;
        return new Binding(() => { turns.OnTurnStart -= Start; SpellCastAction.OnSpellCasted -= Cast; SpellCastAction.OnSpellResolved -= Resolved; if (s.BindingId!=bindingId) return; SetPanache(c,false); s.ResetEncounter(); if (feature.Class=="Oracle") c.Stats.CharacterClass.MartialWeaponProficiency=ProficiencyLevel.Untrained; c.Health?.ClearTempHP(s); });
    }

    public static void SetPanache(ICharacter c,bool active)
    {
        var s=State(c); s.Panache=active;
        c.Modifiers.RemoveModifier(s.PanacheModifier);
        if (!active) return;
        c.Modifiers.AddModifier(new ConditionModifier { Source="Panache",SourceInstanceId=s.PanacheModifier,
            TargetStat=StatType.Speed,Type=ModifierType.Status,Value=5 });
    }

    public static void PrepareEncounter(IReadOnlyList<ICharacter> allies)
    {
        foreach (var oracle in allies.Where(c=>Find(c)?.Class=="Oracle"))
        {
            var s=State(oracle);
            if (s.Cursebound>=2) continue;
            foreach (var ally in allies.Where(c=>c!=oracle && PF2e.Utilities.AreaCalculator.GetPF2eDistance(oracle.GridPosition,oracle.TileWidth,c.GridPosition,c.TileWidth)<=4))
            {
                s.Buff(ally,"Oracular Warning",StatType.Initiative,2);
                ally.Health.GrantTempHP(oracle.StatProvider.Level/2,s,10);
            }
            s.Cursebound++;
        }
    }

    private sealed class Binding(Action release) : IDisposable
    {
        private Action? _release = release;
        public void Dispose() { _release?.Invoke(); _release = null; }
    }

    private sealed class DamageHandler(ICharacter owner, string name) : IRuleEventHandler<DamageRollContext>, IRuleEventHandler<AttackRollContext>, IRuleEventHandler<SavingThrowContext>, IRuleEventHandler<DamageMitigationContext>, IRuleEventHandler<SkillCheckContext>
    {
        public void HandleEvent(SkillCheckContext ctx)
        {
            if (name=="Swashbuckler" && ctx.Actor==owner &&
                (ctx.SourceAction is PF2e.Actions.SkillActions.DemoralizeAction || ctx.SourceAction?.ActionName=="Tumble Through"))
                ctx.Modifiers.Add(ModifierType.Circumstance,1);
        }
        public void HandleEvent(AttackRollContext ctx)
        {
            if (name=="Oracle" && ctx.Defender==owner && ctx.SourceAction is SpellAction) State(owner).ExposedToSpell=true;
            if (ctx.Attacker != owner) return;
            // A finisher closes the attack lane for the rest of this turn.
            if (State(owner).FinisherUsed && !State(owner).ResolvingFinisher) ctx.Cancelled = true;
        }
        public void HandleEvent(SavingThrowContext ctx)
        {
            if (name!="Oracle" || ctx.Saver!=owner || ctx.SourceAction is not SpellAction) return;
            var s=State(owner); s.ExposedToSpell=true;
            if (s.Cursebound>=2) ctx.Modifiers.Add(ModifierType.Status,-1);
        }
        public void HandleEvent(DamageMitigationContext ctx)
        {
            var s=State(owner);
            if (name=="Oracle" && ctx.Target==owner && s.Cursebound>0 && s.ExposedToSpell)
                ctx.DamageIncrease=Math.Max(ctx.DamageIncrease,2);
        }
        public void HandleEvent(DamageRollContext ctx)
        {
            if (ctx.Attacker != owner || ctx.Target == null) return;
            var s = State(owner);
            int level = owner.StatProvider.Level;
            void Bonus(string label, int flat, DamageType type = DamageType.Untyped, DiceFormula? dice = null, bool doubles = true)
                => ctx.BonusDamage.Add(new BonusDamage { Source = label, FlatBonus = flat, Dice = dice, Type = type, DoublesOnCrit = doubles });
            if (name == "Barbarian" && s.Raging && ctx.GetAttackType() == AttackType.Melee)
                Bonus("Fury Rage", level >= 7 ? 7 : 3);
            if (name == "Ranger" && s.Prey == ctx.Target && !s.PrecisionUsed)
            {
                Bonus("Precision edge", 0, DamageType.Precision, new DiceFormula(1,8,0));
                if (!ctx.IsPreview) s.PrecisionUsed = true;
            }
            if (name == "Thaumaturge")
            {
                Bonus("Implement's empowerment", 2 * (ctx.Weapon?.WeaponDef.DamageDice.NumberOfDice ?? 1));
                if (FeatEncounter.SameAntithesis(owner,ctx.Target)) Bonus("Personal antithesis", 2 + level / 2, doubles:false);
            }
            bool precise = ctx.StrikeHasTrait("agile") || ctx.StrikeHasTrait("finesse");
            if (name == "Swashbuckler" && precise && ctx.GetAttackType()==AttackType.Melee)
                Bonus(s.ResolvingFinisher ? "Confident finisher" : "Precise strike", s.ResolvingFinisher ? 0 : level >= 9 ? 4 : level >= 5 ? 3 : 2,
                    DamageType.Precision, s.ResolvingFinisher ? new DiceFormula(2 + (level >= 5 ? 1 : 0) + (level >= 9 ? 1 : 0),6,0) : null);
            if (name == "Magus" && s.Spellstriking)
                Bonus("Spellstrike: Ignition", 0, DamageType.Fire, new DiceFormula((level + 1) / 2 + 1,6,0));
            if (name == "Magus" && s.Cascade && ctx.GetAttackType()==AttackType.Melee) Bonus("Arcane cascade", level >= 7 ? 2 : 1, DamageType.Fire);
            if (level >= 7 && name is "Barbarian" or "Champion" or "Monk" or "Ranger" or "Magus" or "Thaumaturge" or "Swashbuckler")
                Bonus("Weapon specialization", 2);
        }
    }
}

public sealed class WayfarerState
{
    public ICharacter? Prey;
    public bool Raging, Panache, Cascade, Spellstriking, ResolvingFinisher, FinisherUsed, PrecisionUsed, HexUsed;
    public bool SpellstrikeReady = true, CastLastTurn, SpellCastThisTurn;
    public readonly Guid PanacheModifier=Guid.NewGuid();
    public Guid BindingId;
    public int Turns, PsycheTurns, PsycheRecovery, Cursebound;
    public Dictionary<Guid,string> ActiveBuffs = new();
    public bool ChaliceDrained, WeaponTrance, ExposedToSpell;
    public int TranceUntil, BuffsExpireAt;
    public bool LingeringUsed, ActTogetherUsed;
    public int NextAnthemRounds=1;
    public List<RegenerationEffect> Regeneration = new();
    private readonly List<(ICharacter Target, FearSave Handler)> _fearBuffs = new();
    private readonly List<(ICharacter Target, Guid Id)> _buffs = new();
    public void Buff(ICharacter target, string source, StatType stat, int value, ModifierType type = ModifierType.Status)
    {
        var id = Guid.NewGuid();
        target.Modifiers.AddModifier(new ConditionModifier { Source = source, SourceInstanceId = id, TargetStat = stat, Value = value, Type = type });
        _buffs.Add((target,id));
        WayfarerFeature.State(target).ActiveBuffs[id] = source;
    }
    public void FearSaves(ICharacter target)
    {
        var handler=new FearSave(); target.RuleEvents.Subscribe<SavingThrowContext>(handler,RuleEventPriority.Bonus);
        _fearBuffs.Add((target,handler));
    }
    private sealed class FearSave : IRuleEventHandler<SavingThrowContext>
    {
        public void HandleEvent(SavingThrowContext ctx)
        {
            if (ctx.SourceAction?.Traits?.HasTraitById("fear")==true || ctx.SourceAction is SpellAction { SpellId: var id } && id.StartsWith("preset-fear"))
                ctx.Modifiers.Add(ModifierType.Status,1);
        }
    }
    public void ClearBuffs()
    {
        foreach (var (target,handler) in _fearBuffs) target.RuleEvents.Unsubscribe<SavingThrowContext>(handler);
        _fearBuffs.Clear();
        foreach (var (target,id) in _buffs) { target.Modifiers.RemoveModifier(id); WayfarerFeature.State(target).ActiveBuffs.Remove(id); }
        _buffs.Clear();
    }
    public void ResetEncounter()
    {
        ClearBuffs(); BuffsExpireAt=0; NextAnthemRounds=1; LingeringUsed=false; ActTogetherUsed=false; Regeneration.Clear(); Prey = null; Raging = Panache = Cascade = Spellstriking = ResolvingFinisher = FinisherUsed = PrecisionUsed = HexUsed = false;
        ExposedToSpell=false; WeaponTrance=false; TranceUntil=0; SpellstrikeReady = true; Turns = PsycheTurns = PsycheRecovery = 0;
        CastLastTurn = SpellCastThisTurn = false;
        // Cursebound and the drained chalice persist until Refocus / ten-minute recovery.
    }
}

public sealed class RegenerationEffect(ICharacter target, int amount, int turns)
{
    public ICharacter Target = target;
    public int Amount = amount;
    public int Turns = turns;
}
