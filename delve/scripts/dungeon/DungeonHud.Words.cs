namespace Delve.Dungeon;

public partial class DungeonHud
{
    private static readonly string[] SmallWords = { "of", "the", "and", "a", "an", "in", "on", "to" };

    /// <summary>"receiving hall" → "Receiving Hall"; small words stay lower case after the first.</summary>
    private static string TitleCase(string text)
    {
        var words = text.Split(' ');
        for (int i = 0; i < words.Length; i++)
            if (words[i].Length > 0 && (i == 0 || !System.Linq.Enumerable.Contains(SmallWords, words[i])))
                words[i] = char.ToUpperInvariant(words[i][0]) + words[i][1..];
        return string.Join(' ', words);
    }

    private CrawlWords _words = CrawlWordsTable.For("station");
    private string _floorName = "";

    /// <summary>Speak in this floor's words: goal, progress, notices and the exit row.</summary>
    public void SetWords(CrawlWords words, string floorName)
    {
        _words = words;
        _floorName = floorName;
        _floorPlan.Words = words;
    }

    /// <summary>The floor's objective as the party knows it: find the guardian's place, beat it, leave.</summary>
    public string Goal(DungeonFloor floor)
    {
        var chamber = floor.Rooms[floor.GuardianId];
        return chamber.Completed ? _words.GoalLeave : chamber.Discovered ? _words.GoalDefeat : _words.GoalFind;
    }

    public string FloorCompleteNotice => _words.FloorComplete;
}
