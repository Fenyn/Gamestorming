using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.CharacterComponents;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.RuleEvents.Features;
using PF2e.Utilities;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Data;
using Ungilded.Knowledge;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// Checks the Prologue content: the two pregens, the sewer bestiary, the four authored maps, and
/// Encounter 4 started in the combat scene (acid weakness live, journal masks the Tyrant's AC).
/// Rendered, it also saves the Encounter 3 and 4 boards with units placed.
/// </summary>
public partial class PrologueContentSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export] public string ShotE3Path { get; set; } = "";
    [Export] public string ShotE4Path { get; set; } = "";
    [Export] public Vector2I ShotSize { get; set; } = new(1600, 900);
    [Export] public int CombatSeed { get; set; } = 7;
    [Export] public float TurnWaitSeconds { get; set; } = 30f;
    [Export] public float SettleSeconds { get; set; } = 2f;
    [Export] public float PollSeconds { get; set; } = 0.1f;

    protected override string Banner => "==================== PROLOGUE CONTENT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        CheckHeroes();
        CheckBestiary();
        for (int n = 1; n <= 4; n++) CheckMap(n);
        if (CombatScene == null) { Check("CombatScene is assigned", false); return; }
        CheckEncounter4InScene();
        if (!Headless)
        {
            await Capture(PrologueMaps.Encounter3(), ShotE3Path);
            await Capture(PrologueMaps.Encounter4(), ShotE4Path);
        }
    }

    // ───────────────────────────── Heroes ─────────────────────────────

    private void CheckHeroes()
    {
        var player = PrologueCast.BuildPlayer();
        var friend = PrologueCast.BuildFriend();
        PrintHero(player);
        PrintHero(friend);

        Check("Player id, name and level", player.Id == "player" && player.Name == "The Player" && player.Stats.Level == 1);
        Check("Friend id, name and level", friend.Id == "friend" && friend.Name == "The Friend" && friend.Stats.Level == 1);
        Check("Player scores Str 18 Dex 12 Con 12 Int 10 Wis 10 Cha 16",
            Scores(player) == "18 12 12 10 10 16");
        Check("Friend scores Str 10 Dex 16 Con 12 Int 18 Wis 12 Cha 10",
            Scores(friend) == "10 16 12 18 12 10");
        Check($"Player HP 19 (got {player.Health.MaxHP})", player.Health.MaxHP == 19);
        Check($"Friend HP 17 (got {friend.Health.MaxHP})", friend.Health.MaxHP == 17);
        Check($"Player AC 17 (got {StatsCalculator.CalculateAC(player)})", StatsCalculator.CalculateAC(player) == 17);
        Check($"Friend AC 17 (got {StatsCalculator.CalculateAC(friend)})", StatsCalculator.CalculateAC(friend) == 17);
        Check($"Player Speed 25 ft (got {StatsCalculator.GetEffectiveSpeed(player)})", StatsCalculator.GetEffectiveSpeed(player) == 25);
        Check("both are Human, Wintertouched", new[] { player, friend }.All(h =>
            h.Stats.Ancestry?.AncestryName == "Human" && h.Stats.Heritage?.HeritageName == "Wintertouched Human"));
        Check("both resist cold 1", player.DefenseProfile.GetResistance(DamageType.Cold) == 1
            && friend.DefenseProfile.GetResistance(DamageType.Cold) == 1);
        Check("backgrounds Guard and Criminal",
            player.Stats.Background?.BackgroundName == "Guard" && friend.Stats.Background?.BackgroundName == "Criminal");

        Check("Player is a Fighter with Reactive Strike, Shield Block and Sudden Charge",
            player.Stats.CharacterClass.ClassName == "Fighter"
            && HasAll(player, "reactive-strike", "shield-block", "sudden-charge"));
        Check("Player has General Training and Quick Coercion", HasAll(player, "general-training", "quick-coercion"));
        Check("Intimidating Prowess is rejected at level 1 and Intimidating Glare replaces it",
            !PrologueOrigins.IntimidatingProwess().MeetsPrerequisites(player)
            && HasAll(player, PrologueOrigins.IntimidatingGlareId)
            && player.Features.GetFeatureById(PrologueOrigins.IntimidatingProwessId) == null);
        Check("Player trains Athletics, Intimidation, Medicine, Acrobatics, Survival and Warfare Lore",
            Trained(player, Skill.Athletics, Skill.Intimidation, Skill.Medicine, Skill.Acrobatics, Skill.Survival)
            && player.Skills.GetSpecificLoreProficiency(PrologueOrigins.WarfareLore) == ProficiencyLevel.Trained);
        Check("Player wields a longsword, scale mail and a steel shield",
            player.Equipment.MainHandWeapon?.WeaponDef?.ItemName == "Longsword"
            && player.Equipment.WornArmorDef?.ItemName == "Scale Mail"
            && player.Equipment.EquippedShield != null);

        Check("Friend is an Alchemist (Bomber)", friend.Stats.CharacterClass.ClassName == "Alchemist"
            && HasAll(friend, AlchemistClass.BomberFeatureId, AlchemistClass.QuickAlchemyFeatureId));
        var sneak = friend.Features.FindFeatureAs<CreatureSneakAttackFeature>();
        Check("Friend has Sneak Attack 1d6", sneak != null && sneak.BonusDice.NumberOfDice == 1 && sneak.BonusDice.DieSize == 6);
        Check("Friend has General Training, Incredible Initiative and Experienced Smuggler",
            HasAll(friend, "general-training", "incredible-initiative", "experienced-smuggler"));
        Check("Friend trains Crafting, Stealth, Medicine and Alchemy Lore",
            Trained(friend, Skill.Crafting, Skill.Stealth, Skill.Medicine, Skill.Nature, Skill.Acrobatics,
                Skill.Arcana, Skill.Deception, Skill.Intimidation, Skill.Society)
            && friend.Skills.GetSpecificLoreProficiency(PrologueOrigins.AlchemyLore) == ProficiencyLevel.Trained);
        Check("Friend wields a dagger in leather armour",
            friend.Equipment.MainHandWeapon?.WeaponDef?.ItemName == "Dagger"
            && friend.Equipment.WornArmorDef?.ItemName == "Leather Armor");
        Check($"Friend carries 2 lesser acid flasks (got {friend.Equipment.Consumables.GetCount(AlchemicalItems.AcidFlaskLesserId)})",
            friend.Equipment.Consumables.GetCount(AlchemicalItems.AcidFlaskLesserId) == 2
            && friend.Equipment.Consumables.GetCount(AlchemicalItems.VersatileVialId) == 0);
        Check("Friend's formula book holds the acid flask", friend.BuildChoices.FormulaBook?.Find(AlchemicalItems.AcidFlaskLesserId) != null);
    }

    private static void PrintHero(PF2eCharacter c)
    {
        var weapon = WeaponAttackCalculator.ResolveWeapon(c);
        GD.Print($"[Prologue] {c.Name} ({c.Id}): {c.Stats.Ancestry?.AncestryName} {c.Stats.CharacterClass.ClassName} "
            + $"L{c.Stats.Level}  HP {c.Health.MaxHP}  AC {StatsCalculator.CalculateAC(c)}  "
            + $"Speed {StatsCalculator.GetEffectiveSpeed(c)} ft  Str/Dex/Con/Int/Wis/Cha {Scores(c)}");
        GD.Print($"[Prologue]   Fort {Signed(StatsCalculator.CalculateSave(c, SavingThrow.Fortitude))}  "
            + $"Ref {Signed(StatsCalculator.CalculateSave(c, SavingThrow.Reflex))}  "
            + $"Will {Signed(StatsCalculator.CalculateSave(c, SavingThrow.Will))}  "
            + $"Perception {Signed(StatsCalculator.CalculatePerception(c.Stats))}  "
            + $"{weapon?.WeaponDef?.ItemName} {Signed(WeaponAttackCalculator.CalculateAttackBonus(c, weapon!))}");
        GD.Print($"[Prologue]   Features: {string.Join(", ", c.Features.ActiveFeatures.Select(f => f.DisplayName))}");
        var trained = Enum.GetValues<Skill>().Where(s => c.Skills.GetProficiency(s) >= ProficiencyLevel.Trained).Select(s => s.ToString())
            .Concat(c.Skills.SpecificLores.Select(l => l.LoreName));
        GD.Print($"[Prologue]   Trained: {string.Join(", ", trained)}");
    }

    // ───────────────────────────── Bestiary ─────────────────────────────

    private void CheckBestiary()
    {
        var rat = PrologueBestiary.Create(PrologueBestiary.SewerRatId);
        var vicious = PrologueBestiary.Create(PrologueBestiary.ViciousSewerRatId);
        var dire = PrologueBestiary.Create(PrologueBestiary.DireSewerRatId);
        var tyrant = PrologueBestiary.Create(PrologueBestiary.SewerTyrantId);

        Check("Sewer Rat AC 15 HP 8 level -1", Block(rat, ac: 15, hp: 8, level: -1));
        Check("Vicious Sewer Rat matches the Sewer Rat block", Block(vicious, ac: 15, hp: 8, level: -1));
        Check("Dire Sewer Rat AC 16 HP 16 level 0", Block(dire, ac: 16, hp: 16, level: 0));
        Check("Sewer Tyrant AC 17 HP 35 level 1 Medium", Block(tyrant, ac: 17, hp: 35, level: 1)
            && tyrant.CreatureStats.Size == CreatureSize.Medium);
        Check("Sewer Tyrant has weakness acid 3", tyrant.DefenseProfile.GetWeakness(DamageType.Acid) == 3
            && tyrant.DefenseProfile.GetWeakness(DamageType.Bludgeoning) == 0);
        Check("only the Tyrant has a weakness", new[] { rat, vicious, dire }.All(c => c.DefenseProfile.GetWeakness(DamageType.Acid) == 0));
        Check("Vicious Sewer Rat carries Vicious Bite (1d4 bleed on Jaws)",
            vicious.Features.FindFeatureAs<ViciousBiteFeature>() is { StrikeName: "Jaws", PersistentType: DamageType.Bleed } bite
            && bite.BleedDice.DieSize == 4 && rat.Features.FindFeatureAs<ViciousBiteFeature>() == null);
        Check("Sewer Rat Jaws +7 1d6+1 agile finesse", Jaws(rat) is { AttackBonus: 7, IsAgile: true, IsFinesse: true } j1
            && j1.DamageDice.DieSize == 6 && j1.DamageDice.Modifier == 1);
        Check("Dire Sewer Rat Jaws +8 1d8+2 finesse", Jaws(dire) is { AttackBonus: 8, IsAgile: false, IsFinesse: true } j2
            && j2.DamageDice.DieSize == 8 && j2.DamageDice.Modifier == 2);
        Check("Sewer Tyrant Jaws +9 1d10+3", Jaws(tyrant) is { AttackBonus: 9, IsAgile: false, IsFinesse: false } j3
            && j3.DamageDice.DieSize == 10 && j3.DamageDice.Modifier == 3);
        Check("every creature has scent 30 ft and low-light vision", new[] { rat, dire, tyrant }.All(c =>
            SenseHelper.GetEffectiveSenses(c).Any(s => s.SenseType == Sense.Scent && s.RangeFeet == 30)
            && c.CreatureStats.Data.Vision == VisionType.LowLight));
        Check("rats climb 10 ft, the Tyrant does not", rat.CreatureStats.ClimbSpeedInFeet == 10
            && dire.CreatureStats.ClimbSpeedInFeet == 10 && tyrant.CreatureStats.ClimbSpeedInFeet == 0);
        Check("Jaws strikes are usable", new[] { rat, dire, tyrant }.All(c => WeaponAttackCalculator.IsCreatureStrikeWeaponReady(c, 0)));

        Check("sprites: rats rat_v1, Dire rat_v3, Tyrant rat_v2",
            Folder(rat).EndsWith("rat_v1") && Folder(vicious).EndsWith("rat_v1")
            && Folder(dire).EndsWith("rat_v3") && Folder(tyrant).EndsWith("rat_v2"));

        var tyrantStats = tyrant.CreatureStats;
        var masked = CreatureFacts.Facts(tyrantStats.SourceDefinition, tyrantStats.Data, _ => false);
        var known = CreatureFacts.Facts(tyrantStats.SourceDefinition, tyrantStats.Data, _ => true);
        GD.Print($"[Prologue] Tyrant journal masked: {string.Join("  ", masked.Select(f => f.Text))}");
        GD.Print($"[Prologue] Tyrant journal known:  {string.Join("  ", known.Select(f => f.Text))}");
        Check("the journal masks every Tyrant field until revealed", masked.All(f => !f.Known && f.Text.EndsWith(CreatureFacts.Unknown)));
        Check("the revealed journal reads AC 17 and Weak acid 3",
            known.Any(f => f.Text == "AC 17") && known.Any(f => f.Text == "Weak acid 3"));
    }

    private static bool Block(PF2eCharacter c, int ac, int hp, int level)
        => StatsCalculator.CalculateAC(c) == ac && c.Health.MaxHP == hp && c.CreatureStats.Level == level;

    private static CreatureStrike Jaws(PF2eCharacter c) => c.CreatureStats.GetStrike(0)!.Value;

    private static string Folder(PF2eCharacter c) => EnemySpriteMap.FolderForCreature(c.Name, c.CreatureStats.Size);

    // ───────────────────────────── Maps ─────────────────────────────

    private static readonly (int W, int H, int Walls, int Sludge)[] Expected =
    {
        (6, 6, 0, 0), (8, 8, 0, 0), (10, 10, 8, 0), (12, 12, 8, 36),
    };

    private void CheckMap(int number)
    {
        var battle = PrologueMaps.Encounter(number);
        var layout = battle.Layout;
        var grid = MapLayoutGridBuilder.Build(layout);
        var expect = Expected[number - 1];
        string tag = $"E{number}";

        Check($"{tag} is {expect.W}x{expect.H} sewer", layout.Width == expect.W && layout.Height == expect.H && battle.BiomeId == "sewer");

        var walls = Tiles(layout, TileRole.Wall);
        Check($"{tag} has {expect.Walls} pillar tiles and each blocks movement",
            walls.Count == expect.Walls && walls.All(p => grid.GetTile(p)?.IsBlocked == true));
        // Half wall height: low enough to see over from the camera, high above a creature's eye line.
        int pillarTop = PF2e.MapGen.Biomes.MapGenRegistry.GetBiome("sewer").WallHeight / 2;
        Check($"{tag} pillars are {pillarTop} units tall, above eye height, and still give cover",
            walls.All(p => grid.GetTile(p) is { ProvidesCover: true } t && t.CornerHeights.MaxHeight == pillarTop
                && pillarTop > TerrainSpatial.CreatureEyeHeight + 1));

        var sludge = Tiles(layout, TileRole.DifficultTerrain);
        Check($"{tag} has {expect.Sludge} sludge tiles and each costs 2", sludge.Count == expect.Sludge
            && sludge.All(p => grid.GetTile(p)?.EffectiveMovementCost == 2 && layout.GetSurface(p.x, p.y) == SurfaceType.Mud));

        bool standable = battle.Anchors.Values.All(p => layout.GetTile(p.x, p.y) is TileRole.Ground or TileRole.DifficultTerrain
            && grid.GetTile(p) is { IsBlocked: false, Water: false });
        Check($"{tag} anchors are standable ({battle.Anchors.Count})", standable);
        Check($"{tag} enemy anchors are distinct and named",
            battle.Enemies.Select(e => battle.Anchor(e.Anchor)).Distinct().Count() == battle.Enemies.Count);

        var from = battle.Anchor(PrologueBattle.PlayerAnchor);
        var reach = Pathfinder.FindReachableTiles(grid, new PathfindingRequest
        {
            Origin = from, MaxDistance = 400, TileWidth = 1, OriginTeamId = 1, BypassOpposingUnits = true,
        });
        Check($"{tag} every enemy is reachable from the Player",
            battle.Enemies.All(e => reach.ContainsKey(battle.Anchor(e.Anchor))));
        Check($"{tag} the Friend is reachable from the Player", reach.ContainsKey(battle.Anchor(PrologueBattle.FriendAnchor)));

        if (number == 4)
        {
            var tyrant = battle.Anchor(PrologueMaps.TyrantAnchor);
            int straight = Math.Max(Math.Abs(tyrant.x - from.x), Math.Abs(tyrant.y - from.y));
            int cost = reach[tyrant].Cost;
            Check($"E4 crossing the sludge costs extra movement (cost {cost}, distance {straight})", cost >= straight + 3);
        }
        if (number == 1)
        {
            var rat = battle.Anchor(PrologueMaps.RatAnchor);
            Check("E1 rat stands 3 tiles from the Player", Math.Abs(rat.x - from.x) == 3 && rat.y == from.y);
        }
        if (number == 3)
        {
            // Pillar (3..4, 1..2): a line straight through it is blocked, the open row below is not,
            // and a rat beside it stands next to terrain cover.
            var spatial = new TerrainSpatial(grid);
            var beside = PrologueBestiary.Create(PrologueBestiary.SewerRatId);
            beside.GridPosition = new PF2eVec(2, 2);
            Check("E3 a low pillar still blocks line of effect and gives cover",
                !spatial.HasLineOfEffect(new PF2eVec(6, 1), new PF2eVec(1, 1))
                && spatial.HasLineOfEffect(new PF2eVec(6, 4), new PF2eVec(1, 4))
                && spatial.IsAdjacentToTerrainCover(beside));
            var rat3 = battle.Anchor(PrologueMaps.RatAnchorN(3));
            var nextToRat3 = Enumerable.Range(1, 5).Where(n => n != 3)
                .Where(n => Chebyshev(battle.Anchor(PrologueMaps.RatAnchorN(n)), rat3) == 1).ToList();
            Check("E3 an acid flask on Rat 3 splashes Rat 4 only", nextToRat3.SequenceEqual(new[] { 4 }));
            var rat1 = battle.Anchor(PrologueMaps.RatAnchorN(1));
            var p = battle.Anchor(PrologueMaps.PlayerFlankRat1Mark);
            var f = battle.Anchor(PrologueMaps.FriendFlankRat1Mark);
            Check("E3 the two flank marks sit on opposite sides of Rat 1",
                p.x + f.x == 2 * rat1.x && p.y + f.y == 2 * rat1.y && Chebyshev(p, rat1) == 1);
        }

        var setup = battle.BuildSetup();
        var corrections = setup.Normalize();
        Check($"{tag} setup needs no placement corrections", corrections.Count == 0);
        foreach (var line in corrections) GD.Print($"[Prologue]   {line}");
    }

    private static int Chebyshev(PF2eVec a, PF2eVec b) => Math.Max(Math.Abs(a.x - b.x), Math.Abs(a.y - b.y));

    private static List<PF2eVec> Tiles(MapLayout layout, TileRole role)
    {
        var tiles = new List<PF2eVec>();
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
                if (layout.GetTile(x, y) == role) tiles.Add(new PF2eVec(x, y));
        return tiles;
    }

    // ───────────────────────────── Encounter 4 in the combat scene ─────────────────────────────

    private void CheckEncounter4InScene()
    {
        var previous = CreatureKnowledgeLocator.Instance;
        var journal = new MonsterJournal();
        CreatureKnowledgeLocator.Instance = journal;
        var scene = CombatScene!.Instantiate<CombatScene>();
        AddChild(scene);
        try
        {
            scene.Journal = journal;
            scene.StartEncounter(PrologueMaps.Encounter4().BuildSetup(CombatSeed));
            var session = scene.Session;
            Check("E4 starts a session with 2 heroes and 3 enemies", session != null
                && session.Team1.Count == 2 && session.Team2.Count == 3);
            if (session == null) return;

            var tyrant = session.Team2.FirstOrDefault(c => c.CreatureStats?.CreatureId == PrologueBestiary.SewerTyrantId);
            Check("the Sewer Tyrant is on the board at its anchor", tyrant != null
                && tyrant.GridPosition == PrologueMaps.Encounter4().Anchor(PrologueMaps.TyrantAnchor));
            if (tyrant == null) return;
            Check("the Tyrant's acid weakness is live", tyrant.DefenseProfile.GetWeakness(DamageType.Acid) == 3
                && tyrant.Health.MaxHP == 35 && tyrant.Health.CurrentHP == 35);
            Check("the journal lists the Tyrant", journal.IsEncountered(PrologueBestiary.SewerTyrantId));

            var inspect = UnitInspectFactory.BuildInspectView(tyrant);
            var rows = CombatJournalRows.Build(session.Team2, session.Letters);
            var tyrantRow = rows.FirstOrDefault(r => r.Name == "Sewer Tyrant");
            GD.Print($"[Prologue] E4 inspect: {inspect.AcText}  HP {inspect.HpText}; journal: {string.Join("  ", tyrantRow?.Facts.Select(f => f.Text) ?? Array.Empty<string>())}");
            Check("before any reveal the Tyrant's AC reads ? on the card and in the journal",
                inspect.AcText == $"AC {CreatureFacts.Unknown}"
                && tyrantRow?.Facts.Any(f => f.Text == $"AC {CreatureFacts.Unknown}") == true);

            journal.Reveal(PrologueBestiary.SewerTyrantId, DegreeOfSuccess.CriticalSuccess, tyrant.Name);
            var after = CombatJournalRows.Build(session.Team2, session.Letters).First(r => r.Name == "Sewer Tyrant");
            Check("a critical Recall Knowledge reveals AC 17 then Weak acid 3",
                UnitInspectFactory.BuildInspectView(tyrant).AcText == "AC 17"
                && after.Facts.Any(f => f.Text == "AC 17") && after.Facts.Any(f => f.Text == "Weak acid 3"));
        }
        finally
        {
            scene.EndHostedEncounter();
            scene.QueueFree();
            CreatureKnowledgeLocator.Instance = previous;
        }
    }

    // ───────────────────────────── Rendered captures ─────────────────────────────

    private async Task Capture(PrologueBattle battle, string path)
    {
        if (path.Length == 0) return;
        var scene = CombatScene!.Instantiate<CombatScene>();
        AddChild(scene);
        scene.StartEncounter(battle.BuildSetup(CombatSeed));
        var session = scene.Session!;
        for (float waited = 0; !scene.IsPlayerTurn && waited < TurnWaitSeconds; waited += PollSeconds)
            await WaitSeconds(PollSeconds);
        Check($"{battle.Id} reached a hero turn", scene.IsPlayerTurn);
        bool unmoved = session.Team2.Select((c, i) => c.GridPosition == battle.Anchor(battle.Enemies[i].Anchor)).All(b => b);
        GD.Print($"[Prologue] {battle.Id}: enemies {(unmoved ? "still on their anchors" : "moved before the first hero turn")}.");
        // The turn start frames the active hero; the overview shows the whole board.
        Node? rig = GetViewport().GetCamera3D();
        while (rig != null && rig is not OrbitCameraRig) rig = rig.GetParent();
        (rig as OrbitCameraRig)?.ToggleOverview();
        await WaitSeconds(SettleSeconds);
        Check($"{battle.Id} capture saved", SaveViewportCapture(path, ShotSize) == Error.Ok);
        scene.EndHostedEncounter();
        scene.QueueFree();
        await WaitSeconds(PollSeconds);
    }

    // ───────────────────────────── Helpers ─────────────────────────────

    private static bool HasAll(ICharacter c, params string[] ids) => ids.All(id => c.Features.GetFeatureById(id) != null);

    private static bool Trained(ICharacter c, params Skill[] skills)
        => skills.All(s => c.Skills.GetProficiency(s) >= ProficiencyLevel.Trained);

    private static string Scores(PF2eCharacter c)
        => $"{c.Stats.Strength} {c.Stats.Dexterity} {c.Stats.Constitution} {c.Stats.Intelligence} {c.Stats.Wisdom} {c.Stats.Charisma}";

    private static string Signed(int value) => value.ToString("+0;-0;0");
}
