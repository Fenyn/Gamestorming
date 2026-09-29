namespace Delve.Dungeon;

public partial class DungeonHud
{
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
