using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Regression harness for TileSetBuilder pattern preservation. Runs in one of three modes selected
/// by a user command-line arg (after "--"): <c>add</c> injects a synthetic 2-cell pattern into
/// outpost_tileset.tres and saves; <c>verify</c> asserts the pattern survived (a builder run happens
/// between the two, orchestrated externally), prints SPIKE RESULT, then removes the synthetic
/// pattern and saves the tileset back to its clean state.
///
/// Full sequence (headless): run with "-- add" -> run tileset_builder.tscn -> run with "-- verify".
/// </summary>
public partial class PatternPreserveSpike : Node
{
    private const string TresPath = "res://assets/tilesets/outpost_tileset.tres";

    // Synthetic pattern: two cells from sources that always exist (10 = A5 ground, 11 = B walls).
    private static readonly Vector2I CellA = new(0, 0);
    private static readonly Vector2I CellB = new(1, 0);

    public override void _Ready()
    {
        string mode = "verify";
        foreach (string arg in OS.GetCmdlineUserArgs())
            if (arg is "add" or "verify") mode = arg;

        bool ok = mode == "add" ? RunAdd() : RunVerify();
        GD.Print($"SPIKE RESULT: {(ok ? "PASS" : "FAIL")}");
        GetTree().Quit(ok ? 0 : 1);
    }

    private static bool RunAdd()
    {
        GD.Print("==================== PATTERN PRESERVE SPIKE (add) ====================");
        var ts = ResourceLoader.Load<TileSet>(TresPath, cacheMode: ResourceLoader.CacheMode.Ignore);
        if (ts == null) { GD.PushError("[Spike] could not load tileset"); return false; }

        int baseline = ts.GetPatternsCount();
        var pattern = new TileMapPattern();
        pattern.SetCell(CellA, sourceId: 10, atlasCoords: new Vector2I(0, 0));
        pattern.SetCell(CellB, sourceId: 11, atlasCoords: new Vector2I(2, 2));
        ts.AddPattern(pattern);

        Error err = ResourceSaver.Save(ts, TresPath);
        GD.Print($"[Spike] baseline patterns={baseline}, added synthetic pattern, save err={err}");
        return err == Error.Ok && ts.GetPatternsCount() == baseline + 1;
    }

    private static bool RunVerify()
    {
        GD.Print("==================== PATTERN PRESERVE SPIKE (verify) ====================");
        var ts = ResourceLoader.Load<TileSet>(TresPath, cacheMode: ResourceLoader.CacheMode.Ignore);
        if (ts == null) { GD.PushError("[Spike] could not load tileset"); return false; }

        int count = ts.GetPatternsCount();
        bool found = false;
        int foundIndex = -1;
        for (int i = 0; i < count; i++)
        {
            TileMapPattern p = ts.GetPattern(i);
            if (p.GetUsedCells().Count == 2
                && p.HasCell(CellA) && p.GetCellSourceId(CellA) == 10
                && p.HasCell(CellB) && p.GetCellSourceId(CellB) == 11
                && p.GetCellAtlasCoords(CellB) == new Vector2I(2, 2))
            {
                found = true;
                foundIndex = i;
                break;
            }
        }

        GD.Print($"  [{(found ? "PASS" : "FAIL")}] synthetic pattern survived the builder run (patterns={count})");
        if (!found) return false;

        // Clean up: remove the synthetic pattern and restore the tileset.
        ts.RemovePattern(foundIndex);
        Error err = ResourceSaver.Save(ts, TresPath);
        bool clean = err == Error.Ok && ts.GetPatternsCount() == count - 1;
        GD.Print($"  [{(clean ? "PASS" : "FAIL")}] synthetic pattern removed, tileset restored (save err={err})");
        return clean;
    }
}
