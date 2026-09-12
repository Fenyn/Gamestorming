using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using PF2e;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>Real controller highlights, hover and clicks on a Large creature's non-anchor cell.</summary>
public partial class CreatureTargetSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        await Scenario(data, "strike");
        await Scenario(data, "fear");
        await Scenario(data, "trip");
        await Scenario(data, "heal");
    }

    private async Task Scenario(DataManager data, string action)
    {
        bool ally = action == "heal";
        ICharacter actor = action is "fear" or "heal"
            ? PresetCharacters.BuildTharr(level: 2, teamId: 1)
            : PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var wolf = CreatureFactory.Create(data.ResolveCreature(new CreatureRef
        {
            DisplayName = "Dire Wolf", Pack = "pathfinder-monster-core", Slug = "dire-wolf",
        }) ?? throw new InvalidOperationException("Missing Dire Wolf definition"), teamId: ally ? 1 : 2);
        var setup = new CombatSetup
        {
            GridWidth = 9, GridHeight = 8, RngSeed = 41,
            Party = new() { (actor, new PF2eVec(2, 3)) },
        };
        if (ally) setup.Allies.Add((wolf, new PF2eVec(3, 3)));
        else setup.Enemies.Add((wolf, new PF2eVec(3, 3)));
        var session = new CombatSession();
        session.Setup(setup);
        CombatantRegistry.Instance.Register(actor);
        CombatantRegistry.Instance.Register(wolf);
        BattleEvent? selectedEvent = null;
        session.SetPresenter(evt =>
        {
            if (evt.Target == wolf && (evt.Type is BattleEventType.AttackRolled
                or BattleEventType.SpellCast or BattleEventType.ActionUsed))
                selectedEvent = evt;
            return Task.CompletedTask;
        });
        var controller = new PlayerTurnController(session.PlayerActions);
        try
        {
            using var reactions = UsePassthroughReactions();
            actor.Actions.RefillActions();
            if (ally) wolf.Health.TakeDamage(new DamageResult { TotalDamage = 12, DamageType = DamageType.Slashing });
            int hpBefore = wolf.Health.CurrentHP;
            int actionsBefore = actor.Actions.TotalActionsRemaining;
            var highlighted = new HashSet<PF2eVec>();
            AttackPreviewView? preview = null;
            controller.HighlightsChanged += (tiles, _) => highlighted = new HashSet<PF2eVec>(tiles);
            controller.AttackPreviewChanged += p => preview = p;
            controller.BeginTurn(actor);
            switch (action)
            {
                case "strike": controller.BeginStrike(); break;
                case "fear": controller.BeginSpell(PresetSpells.FearId, -1); break;
                case "trip": controller.BeginSkill("trip"); break;
                case "heal": controller.BeginSpell(PresetSpells.HealId, 0); break;
            }
            bool allCovered = wolf.TileWidth == 2;
            for (int y = 3; y <= 4; y++)
                for (int x = 3; x <= 4; x++) allCovered &= highlighted.Contains(new PF2eVec(x, y));
            Check($"{action}: all four Large footprint cells highlighted", allCovered);
            var clicked = new PF2eVec(4, 4);
            Check($"{action}: non-anchor tile resolves actual Large creature",
                session.Grid.GetGroundOccupant(clicked) == wolf);
            Check($"{action}: empty adjacent tile is not a creature target",
                !highlighted.Contains(new PF2eVec(5, 4)));
            if (action == "strike")
            {
                controller.TileHovered(clicked);
                Check("strike: non-anchor hover produces attack preview", preview != null);
                controller.TileHovered(new PF2eVec(5, 4));
                Check("strike: empty-cell hover clears preview", preview == null);
            }

            // RunAction publishes once when it becomes busy and once when execution completes.
            var finished = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            int publishes = 0;
            controller.ButtonStateChanged += _ => { if (++publishes >= 2) finished.TrySetResult(true); };
            controller.TileClicked(clicked);
            bool completed = await Task.WhenAny(finished.Task, Task.Delay(2000)) == finished.Task;
            Check($"{action}: non-anchor click completes action", completed);
            Check($"{action}: emitted action targets the Large creature", selectedEvent?.Target == wolf);
            int expectedCost = action == "fear" ? 2 : 1;
            Check($"{action}: click spends normal action cost",
                actionsBefore - actor.Actions.TotalActionsRemaining == expectedCost);
            if (ally) Check("heal: non-anchor click heals the Large ally", wolf.Health.CurrentHP > hpBefore);
        }
        finally
        {
            controller.EndControl();
            session.Teardown();
        }
    }
}
