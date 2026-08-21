namespace Delve.Data;

/// <summary>
/// Mana Seed character sprite-sheet anatomy. Every baked page is 512x512, an 8x8 grid of 64x64
/// cells, and every page uses the SAME facing-row order (S/N/E/W) — so a page swap is a
/// <c>Texture</c> write and nothing else: hframes/vframes never change, and neither does the
/// row arithmetic. Single source for the cozy avatar (PlayerController), the villagers
/// (VillagerNpc), the cutscene puppets (CutsceneActor) and the combat token (UnitVisual3D).
///
/// PAGE 1 — <see cref="WalkPage"/>, movement (the pack's "char_a_p1"):
///   rows 0-3   stand frame at column 0, facing S/N/E/W.
///              Columns 1-2 are a 2-frame push, 3-4 a 2-frame pull and 5-7 a 3-frame jump.
///              None of those are wired yet; the art is there when a use appears.
///   rows 4-7   6-frame walk cycle (columns 0-5) in the same direction order.
///              Columns 6-7 are run-cycle alternates: a run substitutes them for columns 2 and 5.
///
/// PAGE 2 — <see cref="ToolPage"/> / <see cref="PickPage"/> / <see cref="AxePage"/>, work actions
/// (the pack's "char_a_p2"). Four 4-frame animations, one per quadrant, each in four facings:
///   rows 0-3, cols 0-3   overhead swing   — <see cref="Till"/> / <see cref="Mine"/> / <see cref="Chop"/>
///   rows 0-3, cols 4-7   scatter seed     — <see cref="Seed"/>
///   rows 4-7, cols 0-3   water            — <see cref="Water"/>
///   rows 4-7, cols 4-7   pull up / harvest— <see cref="Harvest"/>
/// The three page-2 variants differ ONLY in the swing quadrant, where the pack's tool layer draws
/// a hoe, a pickaxe or an axe over identical body art. That is why the swing clip is one clip
/// pointed at three pages rather than three clips.
///
/// Frame timings below are the pack's own, from its "animation timing guide"; they are the
/// artist's calibration for this art and the place to tune if a swing ever reads too slow.
/// Sheets are baked by <c>G:\crocotile-mcp\examples\build_mana_seed_sheets.py</c>, which carries
/// the per-character paper-doll recipe (body + outfit + hair) and can prove it against page 1.
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

    /// <summary>Folder root for Mana Seed hero sheets — a character's sheets live under
    /// <c>{SpriteRoot}{CharacterProfile.SpriteId}/</c> (folder name = SpriteId).</summary>
    public const string SpriteRoot = "res://assets/sprites/heroes/";

    /// <summary>Fallback hero sheet folder for an id/SpriteId that fails to resolve, so a puppet or NPC
    /// is always visible rather than blank.</summary>
    public const string DefaultSpriteFolder = "veteran";

    // ---------------------------------------------------------------- pages

    /// <summary>Movement page: stand, walk, and the unwired push/pull/jump columns.</summary>
    public const string WalkPage = "p1";

    /// <summary>Work page carrying the hoe swing, plus seed/water/harvest (which are tool-agnostic
    /// and therefore live only here, not on the pickaxe/axe variants).</summary>
    public const string ToolPage = "p2";

    /// <summary>Work page whose swing quadrant draws a pickaxe. Identical to <see cref="ToolPage"/>
    /// everywhere else.</summary>
    public const string PickPage = "p2_mine";

    /// <summary>Work page whose swing quadrant draws an axe. Identical to <see cref="ToolPage"/>
    /// everywhere else.</summary>
    public const string AxePage = "p2_wood";

    /// <summary>Resource path of one page of one character's sheet set.</summary>
    public static string SheetPath(string spriteFolder, string page) =>
        $"{SpriteRoot}{spriteFolder}/{page}.png";

    /// <summary>Recover the sheet FOLDER from a loaded page's resource path, so a node that was handed
    /// its sheet by the .tscn (the cozy avatar) can find that character's other pages without also
    /// being told its SpriteId. Returns null for a path outside <see cref="SpriteRoot"/>.</summary>
    public static string? FolderFromSheetPath(string? resourcePath)
    {
        if (string.IsNullOrEmpty(resourcePath) || !resourcePath.StartsWith(SpriteRoot))
            return null;
        string rest = resourcePath.Substring(SpriteRoot.Length);
        int slash = rest.IndexOf('/');
        return slash <= 0 ? null : rest.Substring(0, slash);
    }

    // ---------------------------------------------------------------- clips

    /// <summary>
    /// Hoe swing: raise, swing, STRIKE, rest. The impact frame is the one the pack draws with
    /// dust and strike lines, so the till lands when the hoe visibly bites rather than on the press.
    /// </summary>
    public static readonly ManaSeedClip Till = new()
    {
        Page = ToolPage, RowOffset = 0, StartColumn = 0, ImpactFrame = 2,
        FrameTimes = new[] { 0.18f, 0.06f, 0.06f, 0.18f },
    };

    /// <summary>Pickaxe swing — the same body animation as <see cref="Till"/> on the pickaxe page.</summary>
    public static readonly ManaSeedClip Mine = Till with { Page = PickPage };

    /// <summary>Axe swing — the same body animation as <see cref="Till"/> on the axe page.</summary>
    public static readonly ManaSeedClip Chop = Till with { Page = AxePage };

    /// <summary>Scatter seed: stand, sweep low across the ground, rise, settle. The seed leaves the
    /// hand on frame 1.</summary>
    public static readonly ManaSeedClip Seed = new()
    {
        Page = ToolPage, RowOffset = 0, StartColumn = 4, ImpactFrame = 1,
        FrameTimes = new[] { 0.30f, 0.10f, 0.10f, 0.10f },
    };

    /// <summary>Water: hold the can, tip it, pour, pour. Water first leaves the spout on frame 1.</summary>
    public static readonly ManaSeedClip Water = new()
    {
        Page = ToolPage, RowOffset = WalkRowOffset, StartColumn = 0, ImpactFrame = 1,
        FrameTimes = new[] { 0.40f, 0.24f, 0.18f, 0.30f },
    };

    /// <summary>Pull up: crouch, tug, LIFT, hold overhead. The crop comes free on the lift, which is
    /// where the yield should enter the inventory.</summary>
    public static readonly ManaSeedClip Harvest = new()
    {
        Page = ToolPage, RowOffset = WalkRowOffset, StartColumn = 4, ImpactFrame = 2,
        FrameTimes = new[] { 0.40f, 0.24f, 0.18f, 0.30f },
    };
}
