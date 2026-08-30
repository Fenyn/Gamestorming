namespace Delve.Data;

/// <summary>
/// Mana Seed character sprite-sheet anatomy, used by the billboard sprite (<c>Delve.Combat.BillboardSpriteAnimator</c>).
/// Every baked page is 512x512, an 8x8 grid of 64x64 cells, and every page uses the SAME facing-row
/// order (S/N/E/W). A page swap is therefore a <c>Texture</c> write and nothing else: hframes and
/// vframes never change, and neither does the row arithmetic.
///
/// PAGE 1 — <see cref="WalkPage"/>, movement (the pack's "char_a_p1"):
///   rows 0-3   stand frame at column 0, facing S/N/E/W.
///              Columns 1-2 are a 2-frame push, 3-4 a 2-frame pull and 5-7 a 3-frame jump.
///              None of those are wired yet; the art is there when a use appears.
///   rows 4-7   6-frame walk cycle (columns 0-5) in the same direction order.
///              Columns 6-7 are run-cycle alternates: a run substitutes them for columns 2 and 5.
///
/// PAGE 2 — <see cref="AxePage"/>, work actions (the pack's "char_a_p2_wood"). Combat uses only its
/// overhead swing (rows 0-3, columns 0-3), which is <see cref="Chop"/>.
///
/// Frame timings below are the pack's own, from its "animation timing guide"; they are the artist's
/// calibration for this art and the place to tune if a swing ever reads too slow. Sheets are baked by
/// <c>G:\crocotile-mcp\examples\build_mana_seed_sheets.py</c>, which carries the per-character
/// paper-doll recipe (body + outfit + hair) and can prove it against page 1.
/// </summary>
public static class ManaSeedSheet
{
    public const int Columns = 8;
    public const int Rows = 8;
    public const int CellPx = 64;
    public const int WalkRowOffset = 4;
    public const int WalkFrames = 6;
    public const float WalkFrameTime = 0.135f;

    // Facing → sheet row (stand row; add WalkRowOffset for the walk cycle).
    public const int RowSouth = 0;
    public const int RowNorth = 1;
    public const int RowEast = 2;
    public const int RowWest = 3;

    // Portrait crop inside the south-facing stand cell (row RowSouth, column 0). Measured on the
    // baked pages: the figure's pixels sit at x 25-38, y 12-43 in every one of them. The box below
    // pads that to a 2:3 frame with a little head- and foot-room, so a card portrait scales by a
    // whole number instead of showing three quarters of an empty cell.
    public const int PortraitX = 20;
    public const int PortraitY = 10;
    public const int PortraitWidth = 24;
    public const int PortraitHeight = 36;

    /// <summary>Movement page: stand, walk, and the unwired push/pull/jump columns.</summary>
    public const string WalkPage = "p1";

    /// <summary>Work page whose swing quadrant draws an axe.</summary>
    public const string AxePage = "p2_wood";

    /// <summary>Resource path of one page, inside a character's sheet folder (see
    /// <c>HeroSpriteMap.FolderFor</c>).</summary>
    public static string SheetPath(string spriteFolder, string page) => $"{spriteFolder}/{page}.png";

    /// <summary>
    /// Axe swing: raise, swing, STRIKE, rest. The impact frame is the one the pack draws with dust and
    /// strike lines, so the blow lands when the axe visibly bites rather than on the press.
    /// </summary>
    public static readonly ManaSeedClip Chop = new()
    {
        Page = AxePage, RowOffset = 0, StartColumn = 0, ImpactFrame = 2,
        FrameTimes = new[] { 0.18f, 0.06f, 0.06f, 0.18f },
    };
}
