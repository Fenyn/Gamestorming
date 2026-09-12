using System.Threading.Tasks;
using System.Threading;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>Control permissions, reaction routing, and the future manual-companion seam.</summary>
public partial class PartyControlSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        await CheckControl(manualCompanions: false);
        await CheckControl(manualCompanions: true);
        await CheckLeaderDown(data);
    }

    private async Task CheckControl(bool manualCompanions)
    {
        var leader = PresetCharacters.BuildElara(2);
        var companion = PresetCharacters.BuildPlayer(2);
        var guest = PresetCharacters.BuildRecruit(2);
        var enemy = PresetCharacters.BuildRecruit(2, teamId: 2);
        var setup = new CombatSetup
        {
            RngSeed = 17,
            Control = new PartyControlPolicy(leader.Id, manualCompanions),
        };
        setup.Party.Add((leader, new PF2eVec(2, 2)));
        setup.Party.Add((companion, new PF2eVec(3, 2)));
        setup.Allies.Add((guest, new PF2eVec(4, 2)));
        setup.Enemies.Add((enemy, new PF2eVec(3, 3)));
        var session = new CombatSession();
        session.Setup(setup);
        try
        {
            Check("leader starts under player control", session.IsPlayerControlled(leader));
            Check("companion control follows campaign permission",
                session.IsPlayerControlled(companion) == manualCompanions);
            Check("AI companion retains party membership", !session.IsAlly(companion));
            session.SetAiToggle(companion, false);
            Check("manual toggle cannot bypass companion permission",
                session.IsPlayerControlled(companion) == manualCompanions);
            session.SetAiToggle(guest, false);
            Check("guest remains AI even with manual companions", !session.IsPlayerControlled(guest));
            session.SetAiToggle(leader, true);
            session.SetAiToggle(leader, false);
            Check("leader can return from autoplay", session.IsPlayerControlled(leader));

            int prompts = 0;
            session.ReactionPromptHandler = _ => { prompts++; return Task.FromResult(true); };
            companion.Equipment!.RaiseShield(companion);
            await ReactionEvents.DeliverDamage(enemy, companion, new DamageResult
            {
                TotalDamage = 10,
                DamageType = DamageType.Slashing,
            });
            Check("only manual companion reactions prompt", prompts == (manualCompanions ? 1 : 0));
        }
        finally { session.Teardown(); }
    }

    private async Task CheckLeaderDown(DataManager data)
    {
        var party = Party.Build(PresetCharacters.PlayerId, new[]
            { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), 10);
        var leader = party.Members[0];
        var enemy = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        var setup = new CombatSetup { RngSeed = 42, Control = new PartyControlPolicy(party.LeaderId) };
        for (int i = 0; i < party.Members.Count; i++)
            setup.Party.Add((party.Members[i], new PF2eVec(3 + i, 4)));
        setup.Enemies.Add((enemy, new PF2eVec(5, 5)));
        var session = new CombatSession();
        session.Setup(setup);
        try
        {
            leader.Health!.TakeDamage(new DamageResult
            {
                TotalDamage = leader.Health.MaxHP * 10,
                DamageType = DamageType.Slashing,
            });
            Check("leader is down before companions fight", leader.Health.CurrentHP == 0);
            int playerTurns = 0;
            session.PlayerTurnStarted += _ => { playerTurns++; session.RequestEndPlayerTurn(); };
            BattleResult result = BattleResult.InProgress;
            session.EncounterFinished += value => result = value;
            using var timeout = new CancellationTokenSource(System.TimeSpan.FromSeconds(30));
            session.SetPresenter(_ => { timeout.Token.ThrowIfCancellationRequested(); return Task.CompletedTask; });
            await session.RunAsync(timeout.Token);
            Check("AI companions can win with the leader down", result == BattleResult.Team1Wins);
            Check("a downed leader never hands manual control to companions", playerTurns == 0);
            PartyRecovery.CompleteEncounter(party, result);
            Check("surviving party recovers the same leader", leader.Health.CurrentHP > 0
                && !leader.Health.IsDead && party.LeaderId == leader.Id);
        }
        finally { session.Teardown(); }
    }
}
