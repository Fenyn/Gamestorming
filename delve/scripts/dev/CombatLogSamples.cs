using Delve.UI;

namespace Delve.Dev;

internal static class CombatLogSamples
{
    internal static void Fill(CombatLogPanel log)
    {
        log.ClearLog();
        log.SetActors(new[] { ("Aldric", UiColors.LogAlly), ("Fenwick", UiColors.LogAlly),
            ("Hunting Spider", UiColors.LogEnemy), ("Cave Rat", UiColors.LogEnemy) });
        log.BeginTurn("Hunting Spider");
        log.AppendEntry("Hunting Spider Strikes Aldric with Fangs", 8, false);
        log.AppendEntry("d20(7)+8=15 vs AC 19 → Failure", 3, true);
        log.BeginTurn("Aldric");
        log.AppendEntry("Aldric Strikes Hunting Spider with Longsword", 8, false);
        log.AppendEntry("d20(19)+10=29 vs AC 17 → CriticalSuccess", 2, true);
        log.AppendEntry("Hunting Spider takes 18 slashing damage.", 0, true);
        log.AppendEntry("Aldric raises their Steel Shield (+2 AC)", 8, false);
        log.AppendEntry("Shield raised until the start of Aldric's next turn.", 0, true);
        log.BeginTurn("Fenwick");
        log.AppendEntry("Fenwick casts Breathe Fire", 8, false);
        log.AppendEntry("Hunting Spider fails the save (Reflex).", 4, true);
        log.AppendEntry("Hunting Spider takes 9 fire damage.", 0, true);
        log.AppendEntry("Cave Rat saves (Reflex).", 1, true);
        log.AppendEntry("Cave Rat takes 4 fire damage.", 0, true);
    }
}
