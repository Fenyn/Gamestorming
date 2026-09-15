using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Run;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Presets;

internal static class WayfarerCasting
{
    internal static SpellcastingSource? Source(string name, int level)
    {
        if (name is "Barbarian" or "Monk" or "Ranger" or "Thaumaturge" or "Swashbuckler") return null;
        bool prepared = name is "Witch" or "Druid" or "Magus" or "Champion";
        return new SpellcastingSource
        {
            SourceName = $"{name} spellcasting", CastingType = prepared ? SpellcastingType.Prepared : SpellcastingType.Spontaneous,
            KnowledgeType = name == "Druid" ? SpellKnowledgeType.TraditionList : prepared ? SpellKnowledgeType.Spellbook : SpellKnowledgeType.Repertoire,
            Tradition = name switch
            {
                "Witch" or "Druid" or "Summoner" or "Sorcerer" => SpellcastingTradition.Primal,
                "Champion" or "Oracle" => SpellcastingTradition.Divine,
                "Magus" => SpellcastingTradition.Arcane, _ => SpellcastingTradition.Occult,
            },
            SpellcastingAbility = name switch
            {
                "Witch" or "Magus" or "Psychic" => AbilityScore.Intelligence,
                "Druid" => AbilityScore.Wisdom, _ => AbilityScore.Charisma,
            },
            ProgressionFormula = SpellProgressionFormula.Explicit, ExplicitSlotsByRank = Slots(name, level),
            CantripsKnown = name == "Champion" ? 0 : 5,
        };
    }

    internal static int[] Slots(string name, int level)
    {
        int top = Math.Min(9, (Math.Max(1, level) + 1) / 2);
        var slots = new int[11];
        if (name == "Champion") return slots;
        for (int rank = 1; rank <= top; rank++)
        {
            bool unlocking = level == rank * 2 - 1;
            slots[rank] = name switch
            {
                "Magus" or "Summoner" => rank < top - 1 ? 0 : level == 1 ? 1 : 2,
                "Psychic" => unlocking ? 1 : 2,
                "Oracle" or "Sorcerer" => unlocking ? 3 : 4,
                _ => unlocking ? 2 : 3,
            };
        }
        return slots;
    }

    internal static void Configure(PF2eCharacter c, WayfarerSpec spec, bool fresh, bool keepPreparations = false)
    {
        var casting = c.Spellcasting;
        if (casting == null) return;
        casting.Sources[0].ExplicitSlotsByRank = Slots(spec.IntendedClass, c.Stats.Level);
        casting.RecalculateMaxSlots();
        foreach (var id in spec.Cantrips)
        {
            var spell = PresetSpells.Get(id);
            if (spell != null && !casting.Cantrips.Any(s=>s.SpellId==spell.SpellId)) casting.Cantrips.Add(spell);
        }
        var known = spec.Spells.Distinct().Select(PresetSpells.Get).Where(s => s != null).Cast<SpellCastAction>().ToArray();
        if (casting.IsPreparedCaster)
        {
            var preparations = new List<SpellAction>();
            for (int rank = 1; rank <= 9; rank++)
            {
                var candidates = known.Where(s => s.Spell.SpellLevel <= rank).ToArray();
                if (candidates.Length == 0) continue;
                for (int slot = 0; slot < casting.GetMaxSlots(rank); slot++)
                {
                    var spell = PresetSpells.AtRank(candidates[slot % candidates.Length], rank);
                    casting.LearnSpell(spell);
                    preparations.Add(spell);
                }
            }
            if (!keepPreparations) casting.PrepareSpells(preparations);
        }
        else
        {
            casting.LeveledSpells.Clear();
            foreach (var spell in known.Where(s => s.Spell.SpellLevel <= casting.HighestSlotRank))
            {
                casting.LearnSpell(spell);
                casting.LeveledSpells.Add(spell);
            }
        }
        if (spec.IntendedClass is "Sorcerer" or "Psychic")
        {
            for (int i=0;i<casting.LeveledSpells.Count;i++)
                if (casting.LeveledSpells[i] is SpellCastAction spell && spell is not Delve.Rules.NativeSpell)
                    casting.LeveledSpells[i] = new Delve.Rules.NativeSpell(spell,spec.IntendedClass);
            for (int i=0;i<casting.Cantrips.Count;i++)
                if (casting.Cantrips[i] is SpellCastAction spell && spell is not Delve.Rules.NativeSpell)
                    casting.Cantrips[i] = new Delve.Rules.NativeSpell(spell,spec.IntendedClass);
        }
        if (!fresh) return;
        Delve.Rules.WayfarerFeature.State(c).Cursebound=0;
        casting.RefillSlots();
        casting.RefillFocusPoints();
    }
}
