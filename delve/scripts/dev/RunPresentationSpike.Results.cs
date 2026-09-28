using System.Linq;
using System.Threading.Tasks;
using Delve.Flow;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class RunPresentationSpike
{
    /// <summary>The victory screen as rows: title, the XP/level/ward pairs, one row per changed hero with
    /// Choose feat on pending promotions, then notes. No dropdown.</summary>
    private async Task CheckResultsRows(RunState state, VictoryBanner victory)
    {
        var party = state.Party;
        foreach (var member in party.Members) member.Health.SetCurrentHP(member.Health.MaxHP);
        var start = PartyChangeSummary.Capture(party);
        party.Members[0].Health.SetCurrentHP(party.Members[0].Health.MaxHP - 9);
        party.Members[1].Health.SetCurrentHP(1);
        int xpBefore = state.Xp, levelBefore = party.Level;
        PartyLeveling.Award(state, state.Leveling.XpPerLevel);
        var figures = CombatResults.Progress(xpBefore, state.Xp, levelBefore, party.Level, false);
        figures.Add(CombatResults.Ward(60, 100)!);
        victory.ShowResult("Victory", UiColors.Victory);
        victory.ShowRewards(new CombatResultsView
        {
            Figures = figures,
            Members = CombatResults.Members(party.Members, start),
            Notes = new[] { "Raven survived. Choose whether to swap a companion next." },
            Progress = 100.0 * state.Xp / state.Leveling.XpPerLevel,
            Party = party.Members,
        });
        await Capture("polish_rewards");

        var shown = victory.FigureLabels.Select(f => $"{f.CaptionText} {f.BeforeText}>{f.ValueText}").ToArray();
        Check($"results lead with the level pair and the ward pair ({string.Join(", ", shown)})",
            shown.Contains($"Level {levelBefore}>{party.Level}") && shown.Contains("Ward 60>100"));
        Check("a level-up drops the reset XP figure", victory.FigureLabels.All(f => f.CaptionText != "XP"));
        var rows = victory.MemberRows;
        var aldric = rows.FirstOrDefault(r => r.MemberName == party.Members[0].Name);
        var hp = aldric?.FigureLabels.FirstOrDefault(f => f.CaptionText == "HP");
        Check($"a hurt hero gets an HP pair row with the max ({hp?.BeforeText} → {hp?.ValueText} {hp?.MaxText})",
            hp != null && hp.BeforeText == party.Members[0].Health.MaxHP.ToString()
            && hp.ValueText == (party.Members[0].Health.MaxHP - 9).ToString()
            && hp.MaxText == $"/ {party.Members[0].Health.MaxHP}");
        Check($"every pending promotion row offers Choose feat ({rows.Count} rows)",
            rows.Count == party.Members.Count && rows.All(r => r.ChooseFeat.Visible));
        Check("notes come last and the dropdown is gone", victory.NotesText.Contains("Raven survived")
            && victory.GetNodeOrNull("%PartyMember") == null && victory.GetNodeOrNull("%DetailsButton") == null);
        rows[1].ChooseFeat.EmitSignal(Button.SignalName.Pressed);
        var details = victory.GetNode<CharacterDetailsOverlay>("%ResultDetails");
        Check("Choose feat opens that hero's promotion view", details.Visible && details.Character == party.Members[1]);
        details.Close();
    }
}
