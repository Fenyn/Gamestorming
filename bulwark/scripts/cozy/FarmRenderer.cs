using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Passive renderer of the farm plots. Subscribes to <see cref="GameState.PlotChanged"/> and
/// hydrates from <see cref="FarmSystem.AllPlots"/>, then draws the plot state three ways:
///  - <b>tilled soil</b> — a dark-soil tile painted onto the outpost's GroundDecor TileMapLayer
///    (A5 source, see <see cref="TilledSoilAtlas"/>);
///  - <b>watered</b> — a translucent dark overlay drawn over the cell;
///  - <b>crop</b> — a procedural placeholder sprout (stem + leaves, a fruit dot when mature), scaled
///    by growth and gold-tinted at maturity.
/// Holds no rules; every value comes from the authoritative <see cref="FarmSystem"/> state.
/// </summary>
public partial class FarmRenderer : Node2D
{
    private const int TileSize = 48;

    /// <summary>Atlas source id of the A5 ground sheet carrying soil cells (see tileset README).</summary>
    [Export] public int SoilSourceId { get; set; } = 10;

    /// <summary>
    /// Atlas coords of the dark-soil cell painted on tilled plots. Default (6, 12) is a farmable
    /// tilled-earth cell in the A5 soil block (cols 5-7, rows 9-13). Auto-falls back to the first
    /// farmable cell found in the source if this coord is missing/not-farmable.
    /// </summary>
    [Export] public Vector2I TilledSoilAtlas { get; set; } = new(6, 12);

    private OutpostScene? _outpost;
    private TileMapLayer? _soilLayer;
    private readonly HashSet<Vector2I> _soilCells = new();

    /// <summary>Injected by <see cref="OutpostScene"/> once the blockout accessors are ready.</summary>
    public void Bind(OutpostScene outpost)
    {
        _outpost = outpost;
        _soilLayer = outpost.GroundDecor;
        ResolveSoilTile();

        var gs = GameState.Instance;
        if (gs != null)
        {
            gs.PlotChanged += OnPlotChanged;
            gs.GameLoaded += HydrateAll;
        }
        HydrateAll();
    }

    public override void _ExitTree()
    {
        var gs = GameState.Instance;
        if (gs != null)
        {
            gs.PlotChanged -= OnPlotChanged;
            gs.GameLoaded -= HydrateAll;
        }
    }

    // ------------------------------------------------------------------ Soil tile (tilemap)

    private void ResolveSoilTile()
    {
        TileSet? ts = _soilLayer?.TileSet;
        if (ts == null || ts.GetSource(SoilSourceId) is not TileSetAtlasSource src)
            return;

        if (src.HasTile(TilledSoilAtlas) && IsFarmableTile(src, TilledSoilAtlas))
            return;

        // Fall back to the first farmable soil cell defined in the source.
        for (int i = 0; i < src.GetTilesCount(); i++)
        {
            Vector2I coords = src.GetTileId(i);
            if (IsFarmableTile(src, coords))
            {
                TilledSoilAtlas = coords;
                return;
            }
        }
    }

    private static bool IsFarmableTile(TileSetAtlasSource src, Vector2I coords)
    {
        TileData? td = src.GetTileData(coords, 0);
        return td != null && td.GetCustomData("farmable").AsBool();
    }

    private void OnPlotChanged(Vector2I tile)
    {
        UpdateSoil(tile);
        QueueRedraw();
    }

    private void HydrateAll()
    {
        foreach (Vector2I c in _soilCells)
            _soilLayer?.EraseCell(c);
        _soilCells.Clear();

        var gs = GameState.Instance;
        if (gs != null)
            foreach (Plot plot in gs.Farm.AllPlots)
                UpdateSoil(plot.Tile);

        QueueRedraw();
    }

    private void UpdateSoil(Vector2I tile)
    {
        if (_soilLayer == null)
            return;

        Plot? plot = GameState.Instance?.Farm.GetPlot(tile);
        bool tilled = plot != null && plot.Stage != PlotStage.Untilled;

        if (tilled)
        {
            _soilLayer.SetCell(tile, SoilSourceId, TilledSoilAtlas);
            _soilCells.Add(tile);
        }
        else if (_soilCells.Remove(tile))
        {
            _soilLayer.EraseCell(tile);
        }
    }

    // ------------------------------------------------------------------ Water + crop (drawn)

    public override void _Draw()
    {
        var gs = GameState.Instance;
        if (_outpost == null || gs == null)
            return;

        foreach (Plot plot in gs.Farm.AllPlots)
        {
            Vector2 center = ToLocal(_outpost.CellToWorld(plot.Tile));

            if (plot.WateredToday)
            {
                var rect = new Rect2(center - new Vector2(TileSize / 2f, TileSize / 2f),
                    new Vector2(TileSize, TileSize));
                DrawRect(rect, new Color(0.12f, 0.18f, 0.32f, 0.34f), filled: true);
            }

            if (plot.CropId != null)
                DrawSprout(center, plot);
        }
    }

    private void DrawSprout(Vector2 center, Plot plot)
    {
        bool mature = plot.Stage == PlotStage.Mature;

        float t = 0.15f;
        if (Crops.TryGet(plot.CropId!, out CropDefinition crop) && crop.GrowthDays > 0)
            t = Mathf.Clamp((float)plot.DaysGrown / crop.GrowthDays, 0f, 1f);
        if (mature)
            t = 1f;
        t = Mathf.Max(t, 0.15f);

        float height = Mathf.Lerp(9f, 32f, t);
        Vector2 basePt = center + new Vector2(0f, 16f);   // planted near the tile's lower edge
        Vector2 topPt = basePt + new Vector2(0f, -height);

        Color stem = mature ? new Color(0.5f, 0.55f, 0.2f) : new Color(0.3f, 0.55f, 0.25f);
        Color leaf = mature ? new Color(0.85f, 0.72f, 0.2f) : new Color(0.4f, 0.72f, 0.32f);

        DrawLine(basePt, topPt, stem, 3f);

        Vector2 mid = basePt + new Vector2(0f, -height * 0.55f);
        float lw = Mathf.Lerp(3f, 9f, t);
        DrawColoredPolygon(new[] { mid, mid + new Vector2(-lw, -lw * 0.6f), mid + new Vector2(-lw * 0.25f, -lw) }, leaf);
        DrawColoredPolygon(new[] { mid, mid + new Vector2(lw, -lw * 0.6f), mid + new Vector2(lw * 0.25f, -lw) }, leaf);

        if (mature)
            DrawCircle(topPt + new Vector2(0f, -2f), 4.5f, new Color(0.9f, 0.55f, 0.2f));
    }
}
