using System;
using Delve.Flow;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The hero-select page read as a grid: one outer margin, one gutter, and a small set of shared
/// edges the whole screen hangs off. Sizes drift a pixel at a time and a screenshot cannot tell
/// 4 px of slop from intent, so the edges are measured off the laid-out tree and asserted rather
/// than eyeballed.
///
/// Pure measurement - it reads rects and reports; it changes nothing and owns no state.
/// </summary>
public static class HeroSelectGrid
{
    /// <summary>The page's one outer margin, and the one gutter between the sheet and the roster.
    /// Both are authored in hero_select.tscn; this is what the layout is checked against.</summary>
    private const float Margin = 32f;
    private const float Gutter = 24f;

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
        var page = new Rect2(Vector2.Zero, canvas);
        var sheet = Rect(panel, "%Sheet");
        var list = Rect(panel, "%RosterList");
        var title = Rect(panel, "%TitleLabel");
        var heading = Rect(panel, "%RosterHeading");
        var embark = Rect(panel, "%EmbarkButton");

        var sheetNode = panel.GetNode<Control>("%Sheet");
        var headlines = Rect(sheetNode, "%HeadlineRow");
        var plinth = Rect(sheetNode, "%PortraitFrame");
        var rail = Rect(sheetNode, "%AbilityGrid");
        var rows = Rect(sheetNode, "%Columns");
        var last = LastCard(panel);

        GD.Print(
            $"[grid] sheet {Say(sheet)}  roster {Say(list)}  headlines {Say(headlines)}  " +
            $"plinth {Say(plinth)}  rail {Say(rail)}  rows {Say(rows)}  embark {Say(embark)}");

        check($"(8) the page keeps one {Margin:0} px outer margin (l {sheet.Position.X:0}, " +
              $"t {title.Position.Y:0}, r {page.End.X - list.End.X:0}, b {page.End.Y - embark.End.Y:0})",
            Same(sheet.Position.X, Margin) && Same(title.Position.Y, Margin)
            && Same(page.End.X - list.End.X, Margin) && Same(page.End.Y - embark.End.Y, Margin));

        check($"(8) the sheet and the roster keep one {Gutter:0} px gutter " +
              $"({list.Position.X - sheet.End.X:0} px)",
            Same(list.Position.X - sheet.End.X, Gutter));

        check($"(8) the title starts on the sheet's left edge ({title.Position.X:0} / {sheet.Position.X:0})",
            Same(title.Position.X, sheet.Position.X));

        check($"(8) the roster heading sits one gutter above the sheet's top edge " +
              $"({sheet.Position.Y - heading.End.Y:0} px)",
            Same(sheet.Position.Y - heading.End.Y, Gutter));

        check($"(8) the headline band and the overview end on one right edge " +
              $"({headlines.End.X:0} / {rows.End.X:0})",
            Same(headlines.End.X, rows.End.X));

        check($"(8) the ability rail runs under the plinth on both edges " +
              $"(l {rail.Position.X:0} / {plinth.Position.X:0}, r {rail.End.X:0} / {plinth.End.X:0})",
            Same(rail.Position.X, plinth.Position.X) && Same(rail.End.X, plinth.End.X));

        check($"(8) the overview starts one {Gutter:0} px gutter past the rail " +
              $"({rows.Position.X - rail.End.X:0} px)",
            Same(rows.Position.X - rail.End.X, Gutter));

        // The 3 px character-accent strip sits flush under the plinth, inside the gap.
        check($"(8) the rail hangs one gap under the plinth and its accent strip " +
              $"({rail.Position.Y - plinth.End.Y:0} px)",
            Same(rail.Position.Y - plinth.End.Y, Gutter + 3));

        check($"(8) the columns hang under the headline band " +
              $"({rows.Position.Y - headlines.End.Y:0} px)",
            rows.Position.Y > headlines.End.Y);

        check($"(8) the roster column and Embark end on one right edge " +
              $"({list.End.X:0} / {embark.End.X:0})",
            Same(list.End.X, embark.End.X));

        check($"(8) the roster list spans the sheet's height " +
              $"(top {list.Position.Y:0} / {sheet.Position.Y:0}, bottom {last.End.Y:0} / {sheet.End.Y:0})",
            Same(list.Position.Y, sheet.Position.Y) && Same(last.End.Y, sheet.End.Y));
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

    private static Rect2 LastCard(HeroSelectPanel panel)
    {
        var list = panel.GetNode<Control>("%RosterList");
        int count = list.GetChildCount();
        return count == 0 ? new Rect2() : list.GetChild<Control>(count - 1).GetGlobalRect();
    }

    private static bool Same(float a, float b) => Mathf.Abs(a - b) <= Slop;

    private static string Say(Rect2 r) =>
        $"[{r.Position.X:0},{r.Position.Y:0} {r.Size.X:0}x{r.Size.Y:0}]";
}
