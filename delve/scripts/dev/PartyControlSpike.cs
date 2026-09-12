using System.Linq;
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

/// <summary>Control permissions, reaction routing, and the full-party manual control.</summary>
public partial class PartyControlSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        RunAnchorChecks.Run(Check);
        await CheckControl();
        await CheckFirstMemberDown(data);
    }

    private async Task CheckControl()
    {
        var firstMember = PresetCharacters.BuildElara(2);
        var companion = PresetCharacters.BuildPlayer(2);
        var guest = PresetCharacters.BuildRecruit(2);
        var enemy = PresetCharacters.BuildRecruit(2, teamId: 2);
        var setup = new CombatSetup
        {
            RngSeed = 17,
            Control = new PartyControlPolicy(),
        };
        setup.Party.Add((firstMember, new PF2eVec(2, 2)));
        setup.Party.Add((companion, new PF2eVec(3, 2)));
        setup.Party.Add((PresetCharacters.BuildTharr(2), new PF2eVec(4, 2)));
        setup.Party.Add((PresetCharacters.BuildFenwick(2), new PF2eVec(5, 2)));
        setup.Allies.Add((guest, new PF2eVec(6, 2)));
        setup.Enemies.Add((enemy, new PF2eVec(3, 3)));
        var session = new CombatSession();
        session.Setup(setup);
        try
        {
            Check("all four assembled members start under player control", setup.Party.All(entry => session.IsPlayerControlled(entry.Item1)));
            Check("second party member starts under player control",
                session.IsPlayerControlled(companion));
            Check("commanded member retains party membership", !session.IsAlly(companion));
            session.SetAiToggle(companion, false);
            Check("party member can return to manual control",
                session.IsPlayerControlled(companion));
            session.SetAiToggle(guest, false);
            Check("guest remains AI outside the assembled party", !session.IsPlayerControlled(guest));
            session.SetAiToggle(firstMember, true);
            session.SetAiToggle(firstMember, false);
            Check("firstMember can return from autoplay", session.IsPlayerControlled(firstMember));

            int prompts = 0;
            session.ReactionPromptHandler = _ => { prompts++; return Task.FromResult(true); };
            companion.Equipment!.RaiseShield(companion);
            await ReactionEvents.DeliverDamage(enemy, companion, new DamageResult
            {
                TotalDamage = 10,
                DamageType = DamageType.Slashing,
            });
            Check("commanded member reactions prompt", prompts == 1);
        }
        finally { session.Teardown(); }
    }

    private async Task CheckFirstMemberDown(DataManager data)
    {
        var party = Party.Build(PresetCharacters.PlayerId, new[]
            { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), 10);
        var firstMember = party.Members[0];
        var enemy = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        var setup = new CombatSetup { RngSeed = 42, Control = new PartyControlPolicy() };
        for (int i = 0; i < party.Members.Count; i++)
            setup.Party.Add((party.Members[i], new PF2eVec(3 + i, 4)));
        setup.Enemies.Add((enemy, new PF2eVec(5, 5)));
        var session = new CombatSession();
        session.Setup(setup);
        try
        {
            firstMember.Health!.TakeDamage(new DamageResult
            {
                TotalDamage = firstMember.Health.MaxHP * 10,
                DamageType = DamageType.Slashing,
            });
            Check("firstMember is down before companions fight", firstMember.Health.CurrentHP == 0);
            Check("all standing members retain manual control", party.Members.Skip(1).All(session.IsPlayerControlled));
            foreach (var member in party.Members) session.SetAiToggle(member, true);
            int playerTurns = 0;
            session.PlayerTurnStarted += _ => { playerTurns++; session.RequestEndPlayerTurn(); };
            BattleResult result = BattleResult.InProgress;
            session.EncounterFinished += value => result = value;
            using var timeout = new CancellationTokenSource(System.TimeSpan.FromSeconds(30));
            session.SetPresenter(_ => { timeout.Token.ThrowIfCancellationRequested(); return Task.CompletedTask; });
            await session.RunAsync(timeout.Token);
            Check("AI companions can win with the firstMember down", result == BattleResult.Team1Wins);
            Check("voluntary party autoplay runs without manual turns", playerTurns == 0);
            PartyRecovery.CompleteEncounter(party, result);
            Check("surviving party recovers the same firstMember", firstMember.Health.CurrentHP > 0
                && !firstMember.Health.IsDead && party.Find(firstMember.Id) == firstMember);
        }
        finally { session.Teardown(); }
    }
}
