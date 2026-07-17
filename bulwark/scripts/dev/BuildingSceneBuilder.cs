using System;
using System.Collections.Generic;
using Godot;
using Bulwark.Cozy;

namespace Bulwark.Dev;

/// <summary>
/// One-shot headless painter that authors the four staged building scenes
/// (command_post / trading_post / tavern / farmhouse) in code and saves each via
/// PackedScene.Pack — the proven blockout pattern (see <see cref="OutpostBlockoutBuilder"/>): build
/// nodes + SetCell tiles through the TileMapLayer API, never hand-roll tile_map_data bytes.
///
/// Each building follows the BuildingInstance authoring contract (design/building_authoring_guide.md):
///   root Node2D (BuildingInstance) → %Stages (Stage0..N in order = stage index) / %Scaffold /
///   %Footprint (StaticBody2D + uniquely-sized CollisionShape2D) / %Interact. Stage count per
///   building == its max StageIndex in Buildings.cs + 1 (Stage0 = the pre-commission ruin). Every
///   building TileMapLayer has collision_enabled = false (tileset wall tiles carry physics polygons;
///   a hidden stage's layer would still collide — %Footprint owns ALL blocking).
///
/// Identity is carried by silhouette + dressing painted from surveyed outpost_tileset atlas coords:
///   • Command Post — ashlar stone (source 11) crenellated hall + round keep tower, military
///     banners (source 80 handprint standard), a mounted crest, brazier lamps at the resurrection tier.
///   • Trading Post — plank store, market carts + crates + hanging goods (source 12), a coin shop
///     sign (source 20), a wide door; ruin Stage0 is a collapsed storefront.
///   • Tavern — thatch cook-house anchored by a SMOKING chimney (source 75) at every restored stage,
///     an instanced flickering fireplace hearth (scenes/props/fireplace.tscn), warm windows + food
///     barrels; ruin Stage0 has a toppled chimney.
///   • Farmhouse — half-timber homestead (source 204 material 30) contrasting the CP's stone, thatch
///     roof, hay/logs/fence dressing; the tier-4 greenhouse stage adds a glass annex read.
///
/// GUARD: refuses to run (exit 1) if any target scene already exists, UNLESS the only pre-existing
/// target is the known ColorRect placeholder farmhouse.tscn — which is deleted + regenerated in this
/// run. After a successful run every target exists, so a re-run is fully refused (never clobbers user
/// polish). Run via scenes/dev/building_scene_builder.tscn.
/// </summary>
public partial class BuildingSceneBuilder : Node
{
    private const string TilesetPath = "res://assets/tilesets/outpost_tileset.tres";
    private const string OutDir = "res://scenes/buildings";
    private const int Cell = 48;

    // ── Source ids (assets/tilesets/README.md) ───────────────────────────────────────────────
    private const int SrcB = 11;          // fantasy_outside_b  — architecture (stone keep, windows)
    private const int SrcC = 12;          // fantasy_outside_c  — decor (crates/barrels/carts/well/hay/cloth)
    private const int SrcD = 13;          // fantasy_outside_d  — rocks/logs (ruin debris)
    private const int SrcSigns = 20;      // signs              — hanging shop signs
    private const int SrcBDes = 31;       // fantasy_outside_b_destroyed — ruins
    private const int SrcChimney = 75;    // fantasy_chimney    — smoking chimneys
    private const int SrcBanner = 80;     // flags_banner       — banners / standards
    private const int SrcA3 = 204;        // a3_walls           — roofs (mat 0-15) + walls (mat 16-31)

    // ── a3_walls materials (center-fill = ((m%4)*4+1, (m/4)*4+1)) ─────────────────────────────
    private const int MatRedTileRoof = 3;
    private const int MatGreenRoof = 6;
    private const int MatThatch = 11;
    private const int MatSlate = 12;      // dark slate — command-post-grade
    private const int MatPlankWall = 16;  // smooth brown plank wall
    private const int MatGoldThatch = 19;
    private const int MatLogCabin = 24;
    private const int MatHalfTimber = 30; // diagonal half-timber + stone base — farmhouse timber
    private const int MatTealPlaster = 31;

    // ── Scene targets ─────────────────────────────────────────────────────────────────────────
    private static readonly string[] TargetIds = { "command_post", "trading_post", "tavern", "farmhouse" };

    private TileSet _ts = null!;
    private readonly List<string> _log = new();

    public override void _Ready()
    {
        try
        {
            if (!GuardOk())
            {
                GetTree().Quit(1);
                return;
            }

            _ts = GD.Load<TileSet>(TilesetPath) ?? throw new InvalidOperationException($"missing tileset {TilesetPath}");

            SaveScene("command_post", BuildCommandPost());
            SaveScene("trading_post", BuildTradingPost());
            SaveScene("tavern", BuildTavern());
            SaveScene("farmhouse", BuildFarmhouse());

            GD.Print("[BuildingSceneBuilder] DONE");
            foreach (string l in _log) GD.Print("  " + l);
        }
        catch (Exception e)
        {
            GD.PushError($"[BuildingSceneBuilder] FAILED: {e}");
            GD.Print($"[BuildingSceneBuilder] FAILED: {e.Message}\n{e.StackTrace}");
            GetTree().Quit(1);
            return;
        }
        GetTree().Quit(0);
    }

    // ── Guard ─────────────────────────────────────────────────────────────────────────────────

    private bool GuardOk()
    {
        var blocked = new List<string>();
        foreach (string id in TargetIds)
        {
            string res = $"{OutDir}/{id}.tscn";
            if (!Godot.FileAccess.FileExists(res))
                continue;

            // The one allowed pre-existing target: the ColorRect placeholder farmhouse (regenerated here).
            if (id == "farmhouse" && IsColorRectPlaceholder(res))
            {
                GD.Print($"[BuildingSceneBuilder] farmhouse.tscn is the ColorRect placeholder — regenerating it.");
                DeleteScene(res);
                continue;
            }
            blocked.Add($"{id}.tscn");
        }

        if (blocked.Count > 0)
        {
            GD.PushError("[BuildingSceneBuilder] REFUSING to run — target scene(s) already exist (never clobber " +
                         $"user polish): {string.Join(", ", blocked)}. Delete them by hand to regenerate.");
            GD.Print("[BuildingSceneBuilder] GUARD: refused (existing targets: " + string.Join(", ", blocked) + ")");
            return false;
        }
        return true;
    }

    private static bool IsColorRectPlaceholder(string res)
    {
        using var f = Godot.FileAccess.Open(res, Godot.FileAccess.ModeFlags.Read);
        if (f == null) return false;
        string text = f.GetAsText();
        return text.Contains("type=\"ColorRect\"") && text.Contains("name=\"Farmhouse\"");
    }

    private static void DeleteScene(string res)
    {
        string abs = ProjectSettings.GlobalizePath(res);
        if (System.IO.File.Exists(abs)) System.IO.File.Delete(abs);
        if (System.IO.File.Exists(abs + ".uid")) System.IO.File.Delete(abs + ".uid");
    }

    private void SaveScene(string id, BuildingInstance root)
    {
        var packed = new PackedScene();
        Error perr = packed.Pack(root);
        if (perr != Error.Ok) throw new InvalidOperationException($"pack {id} failed: {perr}");
        string res = $"{OutDir}/{id}.tscn";
        Error serr = ResourceSaver.Save(packed, res);
        if (serr != Error.Ok) throw new InvalidOperationException($"save {id} failed: {serr}");
        _log.Add($"saved {res}");
        root.QueueFree();
    }

    // ══════════════════════════════ Command Post ══════════════════════════════
    // Buildings.cs: tiers 1-4 → StageIndex 1-4, so Stage0..Stage4 (5 children).

    private BuildingInstance BuildCommandPost()
    {
        var (root, stages) = NewBuilding("CommandPost");

        // Stage0 — collapsed keep: cracked tower, broken battlements, crumbled ashlar + ivy + fallen banner.
        {
            var (s, st, dr) = NewStage(root, stages, "Stage0", 0);
            PutBlock(st, SrcBDes, 8, 0, 3, 1, -3, -4);   // broken crenellation
            PutBlock(st, SrcBDes, 8, 1, 3, 2, -3, -3);   // crumbled wall below (rows 1-2)
            PutBlock(st, SrcBDes, 13, 2, 2, 3, 2, -4);   // cracked round tower (row2 has the hole)
            PutBlock(st, SrcBDes, 2, 10, 3, 1, -2, -1);  // rubble wall course at the base
            PutBlock(dr, SrcBDes, 0, 12, 2, 2, -3, -3);  // ivy overgrowth
            Debris(s, root, "res://assets/tilesets/winlu_destroyed/fantasy_outside_b_destroyed.png",
                new Rect2(0 * Cell, 6 * Cell, Cell, Cell), new Vector2(-24, -8), -18f); // fallen standard
        }

        // Stage1 — patched hall + planning table (start state, tier 1).
        BuildCommandHall(root, stages, "Stage1", 1, wingLeft: false, annex: false, ritual: false, banners: 1);
        // Stage2 — war-room wing (Elderwood).
        BuildCommandHall(root, stages, "Stage2", 2, wingLeft: true, annex: false, ritual: false, banners: 2);
        // Stage3 — expedition annex (Sunken Reach): supply crates/barrels + a third banner.
        BuildCommandHall(root, stages, "Stage3", 3, wingLeft: true, annex: true, ritual: false, banners: 3);
        // Stage4 — resurrection dais: brazier lamps + crest + ritual banners.
        BuildCommandHall(root, stages, "Stage4", 4, wingLeft: true, annex: true, ritual: true, banners: 3);

        AddFootprint(root, width: 6 * Cell, cx: 0);
        AddInteract(root);
        AddScaffold(root, halfWidthTiles: 4);
        return root;
    }

    private void BuildCommandHall(BuildingInstance root, Node2D stages, string name, int idx,
        bool wingLeft, bool annex, bool ritual, int banners)
    {
        var (s, st, dr) = NewStage(root, stages, name, idx);

        int x0 = wingLeft ? -4 : -3;      // extend the hall left for the war-room wing
        int x1 = 2;
        // Crenellated ashlar hall (pure stone = "sturdiest construction").
        FillTile(st, SrcB, new Vector2I(11, 4), x0, x1, -2, -1);   // ashlar wall body (2 rows)
        FillTile(st, SrcB, new Vector2I(9, 1), x0, x1, -3, -3);    // stone course
        FillTile(st, SrcB, new Vector2I(9, 0), x0, x1, -4, -4);    // crenellation (merlons)
        // Round keep tower on the right (2 wide, 6 tall).
        PutBlock(st, SrcB, 13, 1, 2, 6, 3, -6);
        // Warm-lit windows flanking the entrance.
        Put(st, SrcB, new Vector2I(2, 0), x0 + 1, -2);
        Put(st, SrcB, new Vector2I(2, 0), 1, -2);
        // Mounted crest above the door.
        Put(dr, SrcB, new Vector2I(12, 4), 0, -3);

        // Banners (handprint standard) hung along the wall.
        int[] bx = { x0, x1, -1 };
        for (int i = 0; i < banners && i < bx.Length; i++)
            PutBlock(dr, SrcBanner, 0, 6, 1, 2, bx[i], -3);

        if (annex)
        {
            // Expedition supply annex: stacked crates + a cart out front (left of the hall).
            PutBlock(dr, SrcC, 3, 4, 1, 2, x0 - 1, -2);   // tall crate
            PutBlock(dr, SrcC, 10, 6, 2, 2, x0 - 3, -2);  // supply cart
        }

        // Heavy iron-ring keep door.
        AddProp(s, root, "res://scenes/props/door.tscn", "Door", new Vector2(-24, 0),
            styleFrames: "res://assets/props/door_ext_ring.tres");

        if (ritual)
        {
            // Resurrection dais: brazier lamps flanking the door + an extra ritual banner.
            AddProp(s, root, "res://scenes/props/lamp.tscn", "BrazierL", new Vector2(-24 - 2 * Cell, 0));
            AddProp(s, root, "res://scenes/props/lamp.tscn", "BrazierR", new Vector2(-24 + 2 * Cell, 0));
            PutBlock(dr, SrcBanner, 3, 4, 1, 2, 0, -3);   // gold-lion heraldic banner over the dais
        }
    }

    // ══════════════════════════════ Trading Post ══════════════════════════════
    // Buildings.cs: tiers 1-2 → StageIndex 1-2, so Stage0..Stage2 (3 children).

    private BuildingInstance BuildTradingPost()
    {
        var (root, stages) = NewBuilding("TradingPost");

        // Stage0 — broken storefront: collapsed frame, smashed stall, weeds, tilted crate debris.
        {
            var (s, st, dr) = NewStage(root, stages, "Stage0", 0);
            PutBlock(st, SrcBDes, 8, 10, 3, 1, -3, -2);  // collapsed wood frame
            Put(st, SrcBDes, new Vector2I(5, 0), -1, -3); // broken shop window
            PutBlock(st, SrcBDes, 2, 10, 2, 1, 0, -1);   // rubble at the base
            PutBlock(dr, SrcBDes, 0, 12, 1, 2, -3, -3);  // weeds/ivy
            Debris(s, root, "res://assets/tilesets/winlu_exterior/fantasy_outside_c.png",
                new Rect2(3 * Cell, 5 * Cell, Cell, Cell), new Vector2(48, -10), 22f);  // smashed crate
        }

        // Stage1 — tidy general store: plank walls, red-tile roof, coin sign, crates + barrels, door.
        {
            var (s, st, dr) = NewStage(root, stages, "Stage1", 1);
            RoofedBox(st, MatPlankWall, MatRedTileRoof, -3, 2, wallRows: 2, roofRows: 2);
            Put(st, SrcB, new Vector2I(2, 0), -2, -2);   // warm shop window
            Put(st, SrcB, new Vector2I(2, 0), 1, -2);
            PutBlock(dr, SrcSigns, 6, 0, 1, 1, 0, -3);   // hanging coin shop sign
            PutBlock(dr, SrcC, 3, 4, 1, 2, -3, -2);      // crate stack (goods out front)
            PutBlock(dr, SrcC, 10, 6, 2, 2, 2, -2);      // market cart
            AddProp(s, root, "res://scenes/props/door.tscn", "Door", new Vector2(-24, 0),
                styleFrames: "res://assets/props/door_ext_plank.tres");
        }

        // Stage2 — expanded store: widened frontage, awning of hanging goods, second stall, more crates.
        {
            var (s, st, dr) = NewStage(root, stages, "Stage2", 2);
            RoofedBox(st, MatPlankWall, MatRedTileRoof, -4, 3, wallRows: 2, roofRows: 2);
            Put(st, SrcB, new Vector2I(6, 0), -3, -2);   // lattice shop windows
            Put(st, SrcB, new Vector2I(6, 0), 2, -2);
            PutBlock(dr, SrcSigns, 6, 0, 1, 1, 0, -3);   // coin sign
            PutBlock(dr, SrcSigns, 9, 0, 1, 1, -2, -3);  // scroll sign (ledger)
            // Awning of hanging goods (display cloth line) across the frontage.
            PutBlock(dr, SrcC, 10, 13, 4, 1, -2, -3);
            PutBlock(dr, SrcC, 3, 4, 1, 2, -4, -2);      // crate stack left
            PutBlock(dr, SrcC, 10, 6, 2, 2, 3, -2);      // market cart right
            PutBlock(dr, SrcC, 11, 8, 2, 2, 1, -2);      // second stall / sack cart
            AddProp(s, root, "res://scenes/props/door.tscn", "Door", new Vector2(-24, 0),
                styleFrames: "res://assets/props/door_ext_white.tres");
            AddProp(s, root, "res://scenes/props/lamp.tscn", "Lamp", new Vector2(3 * Cell, 0));
        }

        AddFootprint(root, width: 6 * Cell, cx: 0);
        AddInteract(root);
        AddScaffold(root, halfWidthTiles: 4);   // required: wood-frame beams over the site
        return root;
    }

    // ══════════════════════════════ Tavern ══════════════════════════════
    // Buildings.cs: tiers 1-3 → StageIndex 1-3, so Stage0..Stage3 (4 children).

    private BuildingInstance BuildTavern()
    {
        var (root, stages) = NewBuilding("Tavern");

        // Stage0 — cold collapsed cookhouse with a TOPPLED chimney.
        {
            var (s, st, dr) = NewStage(root, stages, "Stage0", 0);
            PutBlock(st, SrcBDes, 8, 10, 3, 1, -2, -2);  // collapsed frame
            Put(st, SrcBDes, new Vector2I(2, 0), -1, -3); // broken window (dark, cold)
            PutBlock(st, SrcBDes, 2, 10, 2, 1, -1, -1);  // rubble
            // Toppled chimney: the cold stone stack lying on its side (rotated debris).
            Debris(s, root, "res://assets/tilesets/winlu_exterior/fantasy_chimney.png",
                new Rect2(0 * Cell, 2 * Cell, 2 * Cell, Cell), new Vector2(48, -12), 74f);
            PutBlock(dr, SrcBDes, 0, 12, 1, 2, -2, -3);  // weeds
        }

        // Stage1 — working kitchen: thatch cookhouse, SMOKING chimney, flickering hearth, warm window, food.
        BuildTavernStage(root, stages, "Stage1", 1, tavern: false);
        // Stage2 — performances tier: same hearth, add barrels/produce, a mug sign (tavern hint).
        BuildTavernStage(root, stages, "Stage2", 2, tavern: false, mugSign: true);
        // Stage3 — tavern-scale hearth hall: wider, gold thatch, twin chimney, feast dressing, lamp.
        BuildTavernStage(root, stages, "Stage3", 3, tavern: true, mugSign: true);

        AddFootprint(root, width: 5 * Cell, cx: 0);
        AddInteract(root);
        AddScaffold(root, halfWidthTiles: 3);
        return root;
    }

    private void BuildTavernStage(BuildingInstance root, Node2D stages, string name, int idx,
        bool tavern, bool mugSign = false)
    {
        var (s, st, dr) = NewStage(root, stages, name, idx);

        int x0 = tavern ? -3 : -2;
        int x1 = tavern ? 2 : 2;
        int roofMat = tavern ? MatGoldThatch : MatThatch;
        RoofedBox(st, MatPlankWall, roofMat, x0, x1, wallRows: 2, roofRows: 2);
        Put(st, SrcB, new Vector2I(2, 0), x0 + 1, -2);   // warm window
        Put(st, SrcB, new Vector2I(2, 0), x1, -2);

        // The identity anchor: a smoking chimney at the roofline (present at every restored stage).
        PutBlock(dr, SrcChimney, 0, 0, 2, 4, x1 - 1, -6);
        if (tavern)
            PutBlock(dr, SrcChimney, 6, 0, 2, 4, x0, -6);  // twin brick flue for the hearth hall

        // Flickering hearth (instanced fireplace prop — the hearth actually flickers).
        AddProp(s, root, "res://scenes/props/fireplace.tscn", "Hearth", new Vector2(-1 * Cell, 0),
            styleFrames: "res://assets/props/fireplace_cauldron.tres");
        // Food barrels / produce out front.
        PutBlock(dr, SrcC, 3, 4, 1, 2, x0, -2);          // crate of provisions
        PutBlock(dr, SrcC, 13, 10, 2, 2, x1, -2);        // haystack-scale produce pile

        if (mugSign)
            PutBlock(dr, SrcSigns, 7, 0, 1, 1, 0, -3);   // hanging beer-mug sign

        AddProp(s, root, "res://scenes/props/door.tscn", "Door", new Vector2(-24, 0),
            styleFrames: "res://assets/props/door_ext_plank.tres");
        if (tavern)
            AddProp(s, root, "res://scenes/props/lamp.tscn", "Lamp", new Vector2(x1 * Cell, 0));
    }

    // ══════════════════════════════ Farmhouse ══════════════════════════════
    // Buildings.cs: tiers 1-4 → StageIndex 1-4, so Stage0..Stage4 (5 children).

    private BuildingInstance BuildFarmhouse()
    {
        var (root, stages) = NewBuilding("Farmhouse");

        // Stage0 — collapsed homestead: broken timber, fallen fence, rubble, scattered hay.
        {
            var (s, st, dr) = NewStage(root, stages, "Stage0", 0);
            PutBlock(st, SrcBDes, 8, 4, 3, 2, -3, -3);   // broken timber A-frame beams
            PutBlock(st, SrcBDes, 2, 10, 2, 1, 0, -1);   // rubble base
            PutBlock(dr, SrcBDes, 0, 12, 1, 2, -3, -3);  // weeds
            Debris(s, root, "res://assets/tilesets/winlu_exterior/fantasy_outside_c.png",
                new Rect2(13 * Cell, 12 * Cell, Cell, Cell), new Vector2(48, -8), 8f);  // scattered hay
        }

        // Restored homestead: half-timber (contrasts CP stone) + thatch, rustic dressing.
        BuildFarmStage(root, stages, "Stage1", 1, greenhouse: false, barn: false);
        BuildFarmStage(root, stages, "Stage2", 2, greenhouse: false, barn: false, coop: true);
        BuildFarmStage(root, stages, "Stage3", 3, greenhouse: false, barn: true, coop: true);
        // Tier 4 = Greenhouse (Buildings.cs) → glass/annex read.
        BuildFarmStage(root, stages, "Stage4", 4, greenhouse: true, barn: true, coop: true);

        AddFootprint(root, width: 5 * Cell, cx: 0);
        AddInteract(root);
        AddScaffold(root, halfWidthTiles: 3);
        return root;
    }

    private void BuildFarmStage(BuildingInstance root, Node2D stages, string name, int idx,
        bool greenhouse, bool barn, bool coop = false)
    {
        var (s, st, dr) = NewStage(root, stages, name, idx);

        RoofedBox(st, MatHalfTimber, MatThatch, -3, 1, wallRows: 2, roofRows: 2);
        Put(st, SrcB, new Vector2I(2, 0), -2, -2);       // warm window
        Put(st, SrcB, new Vector2I(2, 0), 0, -2);

        // Rustic dressing: hay, logs, fence stubs, crates.
        PutBlock(dr, SrcC, 13, 10, 2, 2, 2, -2);         // big haystack
        PutBlock(dr, SrcC, 8, 4, 2, 2, -3, -2);          // fence / palisade stubs
        PutBlock(dr, SrcC, 3, 4, 1, 2, 1, -2);           // crate

        if (coop)
            PutBlock(dr, SrcC, 5, 2, 3, 1, -2, -3);      // planted vegetable rows (husbandry/coop)
        if (barn)
            PutBlock(dr, SrcC, 10, 8, 2, 2, 3, -2);      // hay wagon (barn expansion)

        if (greenhouse)
        {
            // Greenhouse annex: a glass-lattice window wall + lit lattice panes read as a glasshouse.
            FillTile(st, SrcB, new Vector2I(6, 0), 2, 4, -2, -1);  // lit lattice glazing
            FillTile(st, SrcB, new Vector2I(6, 4), 2, 4, -3, -3);  // arched glass tops
        }

        AddProp(s, root, "res://scenes/props/door.tscn", "Door", new Vector2(-24, 0),
            styleFrames: "res://assets/props/door_ext_plank.tres");
        AddProp(s, root, "res://scenes/props/lamp.tscn", "Lamp", new Vector2(-3 * Cell, 0));
    }

    // ══════════════════════════════ Node/paint helpers ══════════════════════════════

    private (BuildingInstance root, Node2D stages) NewBuilding(string name)
    {
        var root = new BuildingInstance { Name = name };
        var stages = new Node2D { Name = "Stages", UniqueNameInOwner = true };
        root.AddChild(stages);
        stages.Owner = root;
        return (root, stages);
    }

    /// <summary>A stage Node2D with a Structure + Dressing TileMapLayer (both collision-disabled).
    /// Stage 0 saves visible; all others save hidden (loader overrides at runtime).</summary>
    private (Node2D stage, TileMapLayer structure, TileMapLayer dressing) NewStage(
        BuildingInstance root, Node2D stages, string name, int idx)
    {
        var stage = new Node2D { Name = name, Visible = idx == 0 };
        stages.AddChild(stage);
        stage.Owner = root;
        var structure = MakeLayer(stage, root, "Structure", zIndex: 0);
        var dressing = MakeLayer(stage, root, "Dressing", zIndex: 1);
        return (stage, structure, dressing);
    }

    private TileMapLayer MakeLayer(Node2D parent, Node root, string name, int zIndex)
    {
        var layer = new TileMapLayer
        {
            Name = name,
            TileSet = _ts,
            ZIndex = zIndex,
            CollisionEnabled = false,   // CONTRACT: %Footprint owns ALL blocking; hidden layers must never collide
            TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
        };
        parent.AddChild(layer);
        layer.Owner = root;
        return layer;
    }

    /// <summary>Walls + a slightly-overhanging roof from a3_walls (source 204) material center-fills.
    /// Tile columns tx0..tx1 inclusive; walls occupy the bottom <paramref name="wallRows"/> rows,
    /// the roof the <paramref name="roofRows"/> rows above (overhanging one tile each side).</summary>
    private void RoofedBox(TileMapLayer st, int wallMat, int roofMat, int tx0, int tx1, int wallRows, int roofRows)
    {
        Vector2I wall = A3Fill(wallMat);
        Vector2I roof = A3Fill(roofMat);
        for (int r = 0; r < wallRows; r++)
            for (int x = tx0; x <= tx1; x++)
                Put(st, SrcA3, wall, x, -1 - r);
        int roofBase = -1 - wallRows;
        for (int r = 0; r < roofRows; r++)
            for (int x = tx0 - 1; x <= tx1 + 1; x++)   // overhang
                Put(st, SrcA3, roof, x, roofBase - r);
    }

    /// <summary>Fill a tile rectangle (inclusive) with one atlas tile.</summary>
    private void FillTile(TileMapLayer layer, int src, Vector2I atlas, int tx0, int tx1, int ty0, int ty1)
    {
        for (int y = ty0; y <= ty1; y++)
            for (int x = tx0; x <= tx1; x++)
                Put(layer, src, atlas, x, y);
    }

    /// <summary>Copy a w×h block from the source sheet to dest, preserving relative layout.</summary>
    private void PutBlock(TileMapLayer layer, int src, int sx, int sy, int w, int h, int dtx, int dty)
    {
        for (int j = 0; j < h; j++)
            for (int i = 0; i < w; i++)
                Put(layer, src, new Vector2I(sx + i, sy + j), dtx + i, dty + j);
    }

    /// <summary>SetCell guarded by HasTile — plain sources only create non-empty cells, so an
    /// off-survey coord is skipped + logged rather than throwing a Godot tile error.</summary>
    private void Put(TileMapLayer layer, int src, Vector2I atlas, int tx, int ty)
    {
        if (_ts.GetSource(src) is not TileSetAtlasSource s || !s.HasTile(atlas))
        {
            _log.Add($"skip missing tile src={src} atlas={atlas}");
            return;
        }
        layer.SetCell(new Vector2I(tx, ty), src, atlas);
    }

    /// <summary>a3_walls material center-fill tile (fully-surrounded), with a block scan fallback.</summary>
    private Vector2I A3Fill(int mat)
    {
        var center = new Vector2I((mat % 4) * 4 + 1, (mat / 4) * 4 + 1);
        if (_ts.GetSource(SrcA3) is not TileSetAtlasSource s)
            return center;
        if (s.HasTile(center)) return center;
        int bx = (mat % 4) * 4, by = (mat / 4) * 4;
        for (int y = by; y < by + 4; y++)
            for (int x = bx; x < bx + 4; x++)
                if (s.HasTile(new Vector2I(x, y))) return new Vector2I(x, y);
        return center;
    }

    private void AddFootprint(BuildingInstance root, int width, int cx)
    {
        var body = new StaticBody2D { Name = "Footprint", UniqueNameInOwner = true };
        root.AddChild(body);
        body.Owner = root;
        var shape = new CollisionShape2D
        {
            Name = "CollisionShape2D",
            Position = new Vector2(cx, -Cell / 2f),                        // covers the wall base row
            Shape = new RectangleShape2D { Size = new Vector2(width, Cell) }, // unique per building
        };
        body.AddChild(shape);
        shape.Owner = root;
    }

    private void AddInteract(BuildingInstance root)
    {
        var m = new Marker2D { Name = "Interact", Position = new Vector2(0, 16), UniqueNameInOwner = true };
        root.AddChild(m);
        m.Owner = root;
    }

    /// <summary>Wood-frame scaffold shown while the building is under construction. Its own collision
    /// is disabled under a hidden scaffold by BuildingInstance.Apply.</summary>
    private void AddScaffold(BuildingInstance root, int halfWidthTiles)
    {
        var scaffold = new Node2D { Name = "Scaffold", UniqueNameInOwner = true, Visible = false };
        root.AddChild(scaffold);
        scaffold.Owner = root;
        var layer = MakeLayer(scaffold, root, "Beams", zIndex: 2);
        // Half-timber beam frame over the site (source 204 material 30 — the diagonal timber frame).
        Vector2I beam = A3Fill(MatHalfTimber);
        for (int x = -halfWidthTiles; x <= halfWidthTiles; x++)
        {
            Put(layer, SrcA3, beam, x, -1);
            Put(layer, SrcA3, beam, x, -2);
        }
    }

    /// <summary>Instance a prop scene (door/lamp/fireplace) and optionally override its %Sprite
    /// SpriteFrames style. Only the instance root gets Owner = building root (interior nodes keep
    /// their sub-scene ownership) so Pack stores it as an instanced scene with property overrides.</summary>
    private void AddProp(Node2D parent, Node root, string scenePath, string name, Vector2 pos,
        string? styleFrames = null)
    {
        var ps = GD.Load<PackedScene>(scenePath);
        if (ps == null) { _log.Add($"skip missing prop {scenePath}"); return; }
        var inst = ps.Instantiate<Node2D>();
        inst.Name = name;
        inst.Position = pos;
        parent.AddChild(inst);
        inst.Owner = root;
        if (styleFrames != null && inst.GetNodeOrNull<AnimatedSprite2D>("%Sprite") is { } spr)
        {
            var frames = GD.Load<SpriteFrames>(styleFrames);
            if (frames != null)
            {
                spr.SpriteFrames = frames;
                // Own the interior sprite so Pack persists this style override on the instanced prop
                // (an editable-instance override — the interior node must belong to the packed root).
                spr.Owner = root;
            }
            else _log.Add($"skip missing frames {styleFrames}");
        }
    }

    /// <summary>An off-grid, slightly-rotated Sprite2D from a sheet region — sells ruin collapse.</summary>
    private void Debris(Node2D parent, Node root, string sheet, Rect2 region, Vector2 pos, float rotDeg)
    {
        var tex = GD.Load<Texture2D>(sheet);
        if (tex == null) { _log.Add($"skip missing debris sheet {sheet}"); return; }
        var spr = new Sprite2D
        {
            Name = "Debris",
            Texture = tex,
            RegionEnabled = true,
            RegionRect = region,
            Position = pos,
            RotationDegrees = rotDeg,
            TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
        };
        parent.AddChild(spr);
        spr.Owner = root;
    }
}
