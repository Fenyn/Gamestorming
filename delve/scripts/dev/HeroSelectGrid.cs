using System;
using Delve.Flow;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Measures camp viewport bounds and the retained character-details layout.
/// </summary>
public static class HeroSelectGrid
{
    /// <summary>The gutter between two boxes inside a band, half the page's own.</summary>
    private const float BoxGutter = 12f;

    /// <summary>Container rounding costs a pixel here and there; anything wider is a real gap.</summary>
    private const float Slop = 1.5f;

    /// <summary>
    /// Measure the laid-out page and report every shared edge. <paramref name="check"/> takes the
    /// same (message, passed) pair the spike's own assertions do.
    /// </summary>
    public static void Report(HeroSelectPanel panel, Vector2 canvas, Action<string, bool> check)
    {
        var stage = panel.GetNode<CampStage>("%CampStage");
        bool spaced = true;
        for (int i = 0; i < stage.Seats.Length; i++)
        {
            var footprint = new Rect2(stage.SeatPosition(i) - new Vector2(65, 125), new Vector2(130, 170));
            spaced &= footprint.Position.Y > 140 && footprint.End.Y < panel.Size.Y - 160;
            spaced &= footprint.Position.X > 32 && footprint.End.X < panel.Size.X - 32;
            for (int j = 0; j < i; j++)
                spaced &= !footprint.Intersects(new Rect2(stage.SeatPosition(j) - new Vector2(65, 125), new Vector2(130, 170)));
        }
        check("full cast has clear sprite and label space between header and footer", spaced);
        var page = new Rect2(Vector2.Zero, canvas);
        var camp = Rect(panel, "%CampStage");
        var sheet = Rect(panel, "%Sheet");
        var embark = Rect(panel, "%EmbarkButton");
        check("camp fills the selection viewport", camp.Size.IsEqualApprox(canvas));
        check("embark stays inside the screen", page.Encloses(embark));
        check("opened details fit inside the screen", page.Encloses(sheet));
        check("camp residents stay inside the selection viewport",
            HeroSelectChecks.Cards(panel).TrueForAll(c => page.Encloses(c.GetGlobalRect())));
    }

    /// <summary>
    /// The two boxed groups: a headline band across the top of the header, and a rail of ability
    /// boxes under the plinth. The headline box outweighs a rail box, the rail is two even columns
    /// of one gutter, and that gutter is the headline band's - one rhythm, not two grids.
    /// </summary>
    public static void Bands(HeroSelectPanel panel, Action<string, bool> check)
    {
        var sheetNode = panel.GetNode<Control>("%Sheet");
        var headlines = sheetNode.GetNode<HBoxContainer>("%HeadlineRow");
        var rail = sheetNode.GetNode<GridContainer>("%AbilityGrid");

        var headline = headlines.GetChildOrNull<Control>(0);
        var first = rail.GetChildOrNull<Control>(0);
        var second = rail.GetChildOrNull<Control>(1);
        if (headline == null || first == null || second == null)
        {
            check("(8) both boxed groups are populated", false);
            return;
        }

        check($"(8) a headline box outweighs a rail box " +
              $"({headline.Size.Y:0} px over {first.Size.Y:0} px)",
            headline.Size.Y > first.Size.Y);

        check($"(8) the rail is two even columns " +
              $"({first.Size.X:0} / {second.Size.X:0} in {rail.Size.X:0} px)",
            rail.Columns == 2 && Same(first.Size.X, second.Size.X)
            && Same(first.Size.X + second.Size.X + BoxGutter, rail.Size.X));

        check($"(8) both boxed groups share one {BoxGutter:0} px gutter " +
              $"({headlines.GetThemeConstant("separation")} / {rail.GetThemeConstant("h_separation")})",
            headlines.GetThemeConstant("separation") == BoxGutter
            && rail.GetThemeConstant("h_separation") == BoxGutter);
    }

    private static Rect2 Rect(Node from, string unique) =>
        from.GetNode<Control>(unique).GetGlobalRect();

    private static bool Same(float a, float b) => Mathf.Abs(a - b) <= Slop;

    private static string Say(Rect2 r) =>
        $"[{r.Position.X:0},{r.Position.Y:0} {r.Size.X:0}x{r.Size.Y:0}]";
}
