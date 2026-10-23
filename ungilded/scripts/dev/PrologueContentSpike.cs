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
        CheckHeroSprites();
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

    private void CheckHeroSprites()
    {
        foreach (var id in new[] { PrologueCast.PlayerId, PrologueCast.FriendId })
        {
            string folder = HeroSpriteMap.FolderFor(id);
            var def = HeroSpriteMap.IsAuthored(folder)
                ? EnemySpriteMap.Definition(folder) : null;
            var frames = def?.Frames;
            Check($"{id} sprite: authored sprite.tres in {folder}", def != null && frames != null);
            if (def == null || frames == null) continue;
            var idle = def.IdleAnimation;
            var move = def.MoveAnimation;
            var attack = def.AttackAnimation;
            Check($"{id} sprite: idle clip has frames",
                frames.HasAnimation(idle) && frames.GetFrameCount(idle) > 0);
            Check($"{id} sprite: move clip loops when present",
                move.IsEmpty || (frames.HasAnimation(move) && frames.GetAnimationLoop(move) && frames.GetFrameCount(move) > 0));
            Check($"{id} sprite: attack clip plays once with its impact frame inside when present",
                attack.IsEmpty || (frames.HasAnimation(attack) && !frames.GetAnimationLoop(attack)
                && def.AttackImpactFrame >= 0 && def.AttackImpactFrame < frames.GetFrameCount(attack)));
            var size = frames.GetFrameTexture(idle, 0).GetSize();
            bool sameSize = new[] { idle, move, attack }.Where(frames.HasAnimation).All(clip => Enumerable.Range(0, frames.GetFrameCount(clip))
                .All(i => frames.GetFrameTexture(clip, i).GetSize() == size));
            Check($"{id} sprite: every frame is {size.X}x{size.Y}", sameSize);
            Check($"{id} sprite: party portrait and face crops exist",
                Ungilded.UI.HeroPortraits.For(id) != null && Ungilded.UI.HeroPortraits.Face(id) != null);
        }
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
        Check("Sewer Tyrant AC 17 HP 35 level 1 Large", Block(tyrant, ac: 17, hp: 35, level: 1)
            && tyrant.CreatureStats.Size == CreatureSize.Large);
        Check($"Sewer Tyrant takes a 2x2 space and Jaws reach 5 ft (width {tyrant.TileWidth}, reach {Jaws(tyrant).MeleeReachTiles})",
            tyrant.TileWidth == 2 && Jaws(tyrant).MeleeReachTiles == 1);
        Check($"Sewer Tyrant has weakness acid {PrologueBestiary.TyrantAcidWeakness}",
            tyrant.DefenseProfile.GetWeakness(DamageType.Acid) == PrologueBestiary.TyrantAcidWeakness
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
        Check($"the revealed journal reads AC 17 and Weakness acid {PrologueBestiary.TyrantAcidWeakness}",
            known.Any(f => f.Text == "AC 17") && known.Any(f => f.Text == $"Weakness acid {PrologueBestiary.TyrantAcidWeakness}"));
    }

    private static bool Block(PF2eCharacter c, int ac, int hp, int level)
        => StatsCalculator.CalculateAC(c) == ac && c.Health.MaxHP == hp && c.CreatureStats.Level == level;

    private static CreatureStrike Jaws(PF2eCharacter c) => c.CreatureStats.GetStrike(0)!.Value;

    private static string Folder(PF2eCharacter c) => EnemySpriteMap.FolderForCreature(c.Name, c.CreatureStats.Size);

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
            var space = CreatureSizeHelper.GetOccupiedTiles(tyrant.GridPosition, tyrant.TileWidth);
            Check($"the Tyrant holds all {space.Count} tiles of its space on the board",
                space.Count == 4 && space.All(t => ReferenceEquals(session.Grid.GetGroundOccupant(t), tyrant)));
            Check("the Tyrant's acid weakness is live",
                tyrant.DefenseProfile.GetWeakness(DamageType.Acid) == PrologueBestiary.TyrantAcidWeakness
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
            Check($"a critical Recall Knowledge reveals AC 17 then Weakness acid {PrologueBestiary.TyrantAcidWeakness}",
                UnitInspectFactory.BuildInspectView(tyrant).AcText == "AC 17"
                && after.Facts.Any(f => f.Text == "AC 17")
                && after.Facts.Any(f => f.Text == $"Weakness acid {PrologueBestiary.TyrantAcidWeakness}"));
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
