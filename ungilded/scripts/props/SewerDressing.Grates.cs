using System.Linq;
using Godot;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>Drain grates go where water drains: in the wall where a channel runs into it, in the
/// floor two tiles down each passage and beside the end of a channel.</summary>
public partial class SewerDressing
{
    /// <summary>Drain grate set into a wall; its size is its width.</summary>
    [Export] public DecorSprite? WallGrate { get; set; }

    /// <summary>Drain grate laid in the floor.</summary>
    [Export] public DecorSprite? FloorGrate { get; set; }

    /// <summary>A passage's floor grate lies this many tiles off the board.</summary>
    [Export] public int PassageGrateRing { get; set; } = 2;

    /// <summary>A passage's floor grate steps out at most to this ring to clear a reserved tile.</summary>
    [Export] public int PassageGrateMaxRing { get; set; } = 4;

    /// <summary>No two grates, in a wall or the floor, closer than this many tiles (Chebyshev).</summary>
    [Export] public int GrateMinGap { get; set; } = 3;

    /// <summary>The tile a grate counts from for <see cref="GrateMinGap"/>: its wall tile for a wall
    /// grate, its own tile for a floor grate.</summary>
    public static Vector2I GrateCell(DressPlacement p) => p.Kind == DressKind.WallGrate ? p.Wall : p.Tile;

    private void PlaceGrates(Pass pass)
    {
        var layout = pass.Layout;
        if (WallGrate != null)
        {
            foreach (var (water, step) in SewerSites.ChannelEnds(pass.Context.Skirt, r => r == TileRole.Wall).OrderBy(e => e.Water.Y).ThenBy(e => e.Water.X))
            {
                var wall = water + step;
                var face = pass.Faces.FirstOrDefault(f => f.Wall.x == wall.X && f.Wall.y == wall.Y && f.Open.x == water.X && f.Open.y == water.Y);
                if (face == default || !GrateFits(pass.Board(wall))) continue;
                var at = face.Foot(pass.Margin) + WallProps.Out(face) * WallInset;
                if (Crowded(at, pass.Taken)) continue;
                SewerMarks.HangGrate(pass.Props, WallGrate, face, pass.Margin, pass.Shade(face.OpenRing));
                pass.Taken.Add(at);
                _ledger.Add(new DressPlacement(DressKind.WallGrate, pass.Board(water), pass.Board(wall), new Vector2(at.X, at.Z), "channel end"));
            }
        }
        if (FloorGrate == null) return;

        // Two tiles down the passage, or further out while the tile is reserved or taken.
        foreach (var mouth in Openings.Where(o => o.Kind == OpeningKind.Passage))
        {
            bool placed = false;
            for (int ring = PassageGrateRing; ring <= PassageGrateMaxRing && !placed; ring++)
                foreach (int index in new[] { (mouth.Width - 1) / 2, mouth.Width / 2 }.Distinct())
                    if (placed = TryFloorGrate(pass, mouth.At(index, ring), "passage")) break;
        }
    }

    /// <summary>A floor grate beside each channel end. Placed after the torches, so it keeps
    /// <see cref="WallPropGap"/> from the torch at a culvert's jamb.</summary>
    private void PlaceChannelEndGrates(Pass pass)
    {
        if (FloorGrate == null) return;
        foreach (var (water, step) in SewerSites.ChannelEnds(pass.Context.Skirt, r => r == TileRole.Ground)
                     .OrderBy(e => (e.Water + e.Step).Y).ThenBy(e => (e.Water + e.Step).X))
            TryFloorGrate(pass, water + step, "channel end");
    }

    private bool GrateFits(Vector2I cell)
        => _ledger.OfKind(DressKind.WallGrate, DressKind.FloorGrate).All(g => SewerSites.Chebyshev(GrateCell(g), cell) >= GrateMinGap);

    private bool TryFloorGrate(Pass pass, Vector2I tile, string reason)
    {
        var board = pass.Board(tile);
        if (SewerSites.Role(pass.Layout, tile) != TileRole.Ground || pass.Reserved.Contains(new PF2eVec(tile.X, tile.Y))
            || !_ledger.IsFree(board) || !GrateFits(board)) return false;
        var centre = new Vector3(board.X + 0.5f, pass.FloorY(tile), board.Y + 0.5f);
        if (_ledger.OfKind(DressKind.Torch).Any(t => t.At.DistanceTo(new Vector2(centre.X, centre.Z)) < WallPropGap)) return false;
        FloorClutter.AddDecal(_props!, FloorGrate!, centre, 0, pass.FloorShade(tile));
        pass.Taken.Add(centre);
        _ledger.Add(new DressPlacement(DressKind.FloorGrate, board, board, new Vector2(centre.X, centre.Z), reason));
        return true;
    }
}
