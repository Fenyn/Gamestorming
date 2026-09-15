using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Core;

namespace Delve.Dev;
/// <summary>Fast actual engine battles, with metrics for the room-size comparison.</summary>
public partial class DungeonCombatSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        var rows = new List<string>
        {
            "seed,size,layout,entry,enemies,rounds,first_attack_round,opening_movement_only_turns,result"
        };
        foreach (int seed in new[]
        {
            137,
            4711
        }

        )
            foreach (int size in new[]
            {
                12,
                14,
                16
            }

            )
                foreach (bool open in new[]
                {
                    true,
                    false
                }

                )
                    foreach (var entry in Enum.GetValues<DoorSide>())
                    {
                        var floor = DungeonFloor.Generate(seed);
                        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
                        var state = RunState.StartOnMap(seed, party, floor.Map);
                        state.Advance(0);
                        var room = new DungeonRoom
                        {
                            Id = 0,
                            X = 0,
                            Y = 0,
                            Seed = floor.Rooms[0].Seed,
                            Family = RoomFamily.GuardHall
                        };
                        var generated = RoomGeneration.Generate(room.Family, room.Seed, size, Enum.GetValues<DoorSide>(), open);
                        var setup = DungeonEncounters.Build(state, room, generated, entry, data.ResolveCreature);
                        Check($"{seed}/{size}/{open}: deployment builds", setup != null);
                        if (setup == null)
                            continue;
                        Check($"{seed}/{size}/{open}: prepared footprint placement is stable", setup.Normalize().Count == 0);
                        var session = new CombatSession();
                        var result = BattleResult.InProgress;
                        int firstAttack = 0, openingMovementOnly = 0;
                        bool moved = false, acted = false;
                        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
                        try
                        {
                            session.Setup(setup);
                            session.EncounterFinished += r => result = r;
                            foreach (var actor in session.Team1)
                                session.SetAiToggle(actor, true);
                            session.SetPresenter(evt =>
                            {
                                timeout.Token.ThrowIfCancellationRequested();
                                if (session.RoundNumber > 50)
                                    throw new OperationCanceledException();
                                if (evt.Type == BattleEventType.TurnStarted)
                                {
                                    moved = false;
                                    acted = false;
                                }

                                if (evt.Type == BattleEventType.MovementStep)
                                    moved = true;
                                if (evt.Type is BattleEventType.AttackRolled or BattleEventType.SpellCast)
                                {
                                    acted = true;
                                    if (firstAttack == 0)
                                        firstAttack = session.RoundNumber;
                                }

                                if (evt.Type == BattleEventType.TurnEnded && session.RoundNumber <= 2 && moved && !acted)
                                    openingMovementOnly++;
                                return Task.CompletedTask;
                            });
                            await session.RunAsync(timeout.Token);
                            Check($"{seed}/{size}/{open}: combat reaches a result", result != BattleResult.InProgress);
                            Check($"{seed}/{size}/{open}: combat engages by round two", firstAttack is> 0 and <= 2);
                            rows.Add($"{seed},{size},{(open ? "open" : "pillared")},{entry},{setup.Enemies.Count},{session.RoundNumber},{firstAttack},{openingMovementOnly},{result}");
                        }
                        finally
                        {
                            session.Teardown();
                        }
                    }

        System.IO.File.WriteAllLines(ProjectSettings.GlobalizePath("res://.godot/dungeon-comparison.csv"), rows);
        foreach (var row in rows)
            GD.Print("[DungeonComparison] " + row);
        var bear = data.FindCreature("Grizzly Bear");
        Check("large-creature deployment fixture is available", bear != null);
        if (bear != null)
            foreach (int size in new[]
            {
                12,
                14,
                16
            }

            )
                foreach (var side in Enum.GetValues<DoorSide>())
                {
                    var generated = RoomGeneration.Generate(RoomFamily.GuardHall, 137, size, Enum.GetValues<DoorSide>());
                    generated.Layout.DeploymentZones = RoomGeneration.Zones(size + 2, side);
                    var setup = new CombatSetup
                    {
                        Layout = generated.Layout
                    };
                    var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
                    var allies = PF2e.MapGen.DeploymentPlanner.GetAnchors(generated.Layout, 0, 4);
                    var enemies = PF2e.MapGen.DeploymentPlanner.GetAnchors(generated.Layout, 1, 8);
                    for (int i = 0; i < 4; i++)
                        setup.Party.Add((party.Members[i], EncounterSpawner.AnchorAt(allies, i)));
                    for (int i = 0; i < 8; i++)
                        setup.Enemies.Add((CreatureFactory.Create(bear, 2), EncounterSpawner.AnchorAt(enemies, i)));
                    setup.Normalize();
                    Check($"{size}/{side}: four heroes and eight large enemies fit without overlaps", setup.Normalize().Count == 0 && setup.Enemies.All(e => e.Unit.TileWidth >= 2));
                }
    }
}
