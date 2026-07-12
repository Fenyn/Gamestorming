namespace Bulwark.Data;

/// <summary>
/// Mana Seed character sprite-sheet anatomy ("page 1": 512x512, an 8x8 grid of 64x64 cells).
/// Rows 0-3 are the stand frames facing S/N/E/W (column 0); rows 4-7 are the 6-frame walk cycle
/// in the same direction order (columns 0-5; columns 6-7 are run-cycle alternates, unused).
/// ~135 ms per walk frame per the pack's guide. Single source for the cozy avatar
/// (PlayerController) and the combat token (UnitVisual3D) — each keeps its own frame-advance code.
/// </summary>
public static class ManaSeedSheet
{
    public const int Columns = 8;
    public const int CellPx = 64;
    public const int WalkRowOffset = 4;
    public const int WalkFrames = 6;
    public const float WalkFrameTime = 0.135f;

    // Facing → sheet row (stand row; add WalkRowOffset for the walk cycle).
    public const int RowSouth = 0;
    public const int RowNorth = 1;
    public const int RowEast = 2;
    public const int RowWest = 3;
}
