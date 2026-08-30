using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Presets;
using Delve.Run;
using Delve.Run.Events;
using Godot;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using RunState = Delve.Run.RunState;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the event layer. Resolves the placeholder "Collapsed passage" at a forced
/// DC 0 (critical success: the acting member heals) and a forced DC 99 (critical failure: damage plus
/// Wounded, floored at 1 HP), then takes the checkless option and asserts nothing moves.
/// </summary>
public partial class RunEventSpike : SpikeBase
{
    private const int PartyLevel = 2;
    private const int RunSeed = 4242;

    protected override string Banner => "==================== RUN EVENT SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        // The d20 behind every check comes from the engine's global Rng; a natural 1 at DC 0 would
        // downgrade a forced success, so the roll is pinned.
        Rng.Seed(1234);

        var definition = EventCatalog.CollapsedPassage;
        Check("the catalog holds the placeholder event", definition.Options.Count == 2);
        Check("option 0 carries an Athletics check",
            definition.Options[0].Check != null && definition.Options[0].Check!.Skill == Skill.Athletics);
        Check("option 1 carries no check", definition.Options[1].Check == null);

        // (1) Forced critical success: the climber heals a tenth of its maximum HP.
        GD.Print("-------------------- (1) Option 0 at DC 0 --------------------");
        var lucky = NewRun();
        var climber = lucky.Party.Members[0];
        climber.Health.SetCurrentHP(climber.Health.MaxHP / 2);
        int before = climber.Health.CurrentHP;

        var crit = EventResolver.Resolve(lucky, definition, 0, climber, dcOverride: 0);
        PrintLines(crit);

        Check("(1) the option resolved", crit.Resolved);
        Check($"(1) DC 0 forces a critical success ({crit.Degree})", crit.Degree == DegreeOfSuccess.CriticalSuccess);
        Check("(1) the chosen actor was used", ReferenceEquals(crit.Actor, climber));
        Check($"(1) the climber healed ({before} -> {climber.Health.CurrentHP})",
            climber.Health.CurrentHP > before);

        // (2) Forced critical failure: damage plus Wounded, never below 1 HP.
        GD.Print("-------------------- (2) Option 0 at DC 99 --------------------");
        var unlucky = NewRun();
        var faller = unlucky.Party.Members[0];
        int fullHp = faller.Health.CurrentHP;

        var botch = EventResolver.Resolve(unlucky, definition, 0, faller, dcOverride: 99);
        PrintLines(botch);

        Check("(2) the option resolved", botch.Resolved);
        Check($"(2) DC 99 forces a critical failure ({botch.Degree})",
            botch.Degree == DegreeOfSuccess.CriticalFailure);
        Check($"(2) the faller took damage ({fullHp} -> {faller.Health.CurrentHP})",
            faller.Health.CurrentHP < fullHp);
        Check($"(2) the faller is Wounded ({Wounded(faller)})", Wounded(faller) >= 1);
        Check("(2) the faller is alive and above 0 HP",
            !faller.Health.IsDead && faller.Health.CurrentHP >= 1);

        // The damage floor holds even when the effect is larger than the member's remaining HP.
        var sliver = NewRun();
        var last = sliver.Party.Members[0];
        last.Health.SetCurrentHP(1);
        EventResolver.Resolve(sliver, definition, 0, last, dcOverride: 99);
        Check("(2) event damage never drops a member below 1 HP", last.Health.CurrentHP == 1);

        // (3) The checkless option changes nothing.
        GD.Print("-------------------- (3) Option 1 --------------------");
        var quiet = NewRun();
        var walker = quiet.Party.Members[0];
        int hpBefore = walker.Health.CurrentHP;
        int goldBefore = quiet.Gold;

        var around = EventResolver.Resolve(quiet, definition, 1, null, dcOverride: null);
        PrintLines(around);

        Check("(3) the option resolved", around.Resolved);
        Check("(3) no check was rolled", around.Degree == null);
        Check("(3) nothing changed", walker.Health.CurrentHP == hpBefore
                                     && quiet.Gold == goldBefore
                                     && Wounded(walker) == 0);
        Check("(3) it still produced a line to show", around.Lines.Count > 0);

        // (4) An index outside the option list is refused, not thrown.
        var refused = EventResolver.Resolve(quiet, definition, 7, null);
        Check("(4) an unknown option index is refused", !refused.Resolved && refused.Reason != null);

        return Task.CompletedTask;
    }

    private static RunState NewRun()
    {
        var party = Party.Build(
            PresetCharacters.PlayerId,
            new List<string> { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId },
            new UnlockState(),
            PartyLevel);
        return RunState.Start(RunSeed, party, new RunMapConfig());
    }

    private static void PrintLines(EventResult result)
    {
        foreach (string line in result.Lines)
            GD.Print($"    {line}");
    }

    private static int Wounded(PF2eCharacter member)
    {
        var wounded = ConditionDatabase.Instance?.Wounded;
        return wounded == null ? 0 : member.Conditions.GetConditionValue(wounded);
    }
}
