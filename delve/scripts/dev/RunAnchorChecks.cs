using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Presets;
using Delve.Run;

namespace Delve.Dev;

internal static class RunAnchorChecks
{
    internal static void Run(Action<string, bool> check)
    {
        string[] ids = { PresetCharacters.PlayerId, PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId };
        var unlocks = new UnlockState();
        var party = Party.Build(ids, unlocks, Party.DefaultLevel);
        var reversed = Party.Build(Enumerable.Reverse(ids).ToArray(), unlocks, Party.DefaultLevel);
        var seen = new HashSet<string>();
        bool stable = true, independent = true, contained = true;
        for (int seed = 1; seed <= 32; seed++)
        {
            var state = RunState.Start(seed, party, new RunMapConfig());
            var other = RunState.Start(seed, reversed, new RunMapConfig());
            string id = state.StoryCharacterId;
            seen.Add(id);
            stable &= id == state.StoryCharacterId;
            independent &= id == other.StoryCharacterId;
            contained &= ids.Contains(id) && ids.Contains(state.PresentationCharacterId);
        }
        check("random anchors only name assembled members", contained);
        check("random anchors remain stable on repeat reads", stable);
        check("selection order gives no member priority", independent);
        check("different run seeds can anchor every party member", seen.Count == Party.MaxSize);
        var run = RunState.Start(91, party, new RunMapConfig());
        string outgoing = run.StoryCharacterId;
        var guest = PresetCharacters.BuildRaven(party.Level);
        check("a story anchor has no protection against replacement", party.ReplaceCompanion(outgoing, guest.Id, guest));
        check("random anchors follow the current assembled party", run.StoryCharacterId != outgoing && party.Find(run.StoryCharacterId) != null);
        foreach (var member in party.Members) member.Health!.SetCurrentHP(0);
        check("no standing member gives no event actor", run.RandomMember("event-actor", livingOnly: true) == null);
        guest.Health!.SetCurrentHP(1);
        check("event fallback excludes downed members", run.RandomMember("event-actor", livingOnly: true) == guest);
    }
}

