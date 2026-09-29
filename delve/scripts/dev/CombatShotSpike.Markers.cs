using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>Condition markers on a five-hero-and-goblin cluster: the board shows only Dying, the
/// forecast and the roll row name the modifiers, the rail and chips keep the full lists.</summary>
public partial class CombatShotSpike
{
    private static readonly PF2eVec[] ClusterOffsets =
        { new(-1, 0), new(-1, 1), new(1, 0), new(1, 1), new(0, 0), new(0, 1) };

    private async Task CaptureMarkers(CombatScene scene, DataManager data)
    {
        var session = await StartCluster(scene, data);
        if (session?.CurrentActor is not { } actor)
        {
            Check("a player turn opens on the marker cluster", false);
            return;
        }
        var db = ConditionDatabase.Instance;
        var goblins = session.Team2.ToList();
        var target = goblins.FirstOrDefault(g => session.PlayerActions.GetStrikeTargets(actor).Contains(g)) ?? goblins[0];
        var grabbed = goblins.First(g => g != target);
        var others = session.Team1.Where(h => h != actor).ToList();
        var dying = others.FirstOrDefault(h => h.Name == "Elara") ?? others[0];
        target.Conditions.AddCondition(db.Prone);
        grabbed.Conditions.AddCondition(db.Grabbed);
        grabbed.Conditions.AddCondition(db.Frightened, value: 2);
        actor.Conditions.AddCondition(db.Frightened, value: 1);
        others.First(h => h != dying).Conditions.AddCondition(db.Sickened, value: 1);
        dying.Health.SetCurrentHP(0);
        dying.Conditions.AddCondition(db.Dying, value: 2);
        dying.Conditions.AddCondition(db.Unconscious);
        scene.ClearHover();
        await WaitSeconds(PoseSeconds);

        CheckMarkerTokens(scene, dying, "cluster idle");
        var rail = scene.GetNode<TurnOrderBar>("%TurnOrderBar");
        var icons = Tokens(scene)[0].Dying.Icons;
        var railIcons = rail.Row.GetChildren().Select(row => row.GetNodeOrNull("%Marks")).OfType<Node>()
            .SelectMany(marks => marks.GetChildren().OfType<TextureRect>()).Select(r => r.Texture).ToList();
        Check("the rail shows Grabbed and Dying as baked 22 px tiles", new[] { "Grabbed", "Dying" }.All(key =>
            icons.Tile(key) is { } icon && railIcons.Contains(icon) && icon.GetWidth() == 22 && icon.GetHeight() == 22));
        var badgeIcon = icons.Find(nameof(Condition.Dying));
        Check($"the board icon is the art region, one texel per cell at 1x ({badgeIcon?.GetWidth()} px, {badgeIcon?.GetType().Name})",
            badgeIcon is AtlasTexture { Region.Size.X: 484 } && badgeIcon.GetWidth() % 22 == 0);
        CheckChipMatchesRail(scene, rail, dying);
        var inspect = UnitInspectFactory.BuildInspectView(grabbed).Conditions;
        Check($"the hover card lists Grabbed and Immobilized ({string.Join(", ", inspect)})", inspect.Contains("Grabbed") && inspect.Contains("Immobilized"));
        int actorAc = PF2e.Utilities.StatsCalculator.CalculateAC(actor);
        string acText = UnitInspectFactory.BuildInspectView(actor).AcText;
        Check($"the frightened actor's card reads its AC as a before→after pair ('{acText}')",
            acText == $"AC {actorAc + 1} → {actorAc}");
        AssertZones(scene, "markers_cluster_idle.png");
        Capture("markers_cluster_idle.png");

        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var hover = typeof(CombatScene).GetMethod("OnTileHovered", BindingFlags.Instance | BindingFlags.NonPublic)!;
        bar._UnhandledInput(new InputEventAction { Action = InputNames.Action1, Pressed = true });
        hover.Invoke(scene, new object?[] { (PF2eVec?)target.GridPosition });
        await WaitSeconds(PoseSeconds);
        var texts = bar.Decision.ModifierTexts;
        Check($"the forecast names 'Off-guard (Prone) +2' and 'Frightened 1 -1' ({string.Join(", ", texts)})",
            bar.Decision.Card.Visible && texts.Contains("Off-guard (Prone) +2") && texts.Contains("Frightened 1 -1"));
        CheckMarkerTokens(scene, dying, "cluster targeting");
        AssertZones(scene, "markers_cluster_targeting.png");
        Capture("markers_cluster_targeting.png");
        hover.Invoke(scene, new object?[] { null });
        ((PlayerTurnController)typeof(CombatScene).GetField("_controller", BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(scene)!).Cancel();

        var dyingToken = Tokens(scene).First(t => t.Character == dying);
        var camera = scene.ActiveCamera;
        var pose = camera.GlobalTransform;
        // About 5 m across at the rig's narrow field of view: the dying hero, its neighbours and plates.
        camera.GlobalPosition = dyingToken.GlobalPosition + new Vector3(7f, 7.5f, 7f);
        camera.LookAt(dyingToken.GlobalPosition + Vector3.Up * 0.8f);
        await WaitSeconds(PoseSeconds);
        CheckMarkerTokens(scene, dying, "dying close-up");
        Capture("markers_dying_ally.png");
        camera.GlobalTransform = pose;
        await CaptureEnemyRoll(scene, session);
    }

    /// <summary>A fresh encounter on the forest map with the party packed around two goblins. Seeds
    /// are tried until a hero holds the first turn, so the cluster is still in place.</summary>
    private async Task<CombatSession?> StartCluster(CombatScene scene, DataManager data)
    {
        var layout = MapGenerator.GenerateValidated("forest", 20260804);
        var goblin = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var centre = layout == null ? new PF2eVec(6, 5) : DeploymentPlanner.GetAnchors(layout, teamId: 0, count: 1)[0] + new PF2eVec(3, 0);
        for (int seed = 1; seed <= 8; seed++)
        {
            var units = new ICharacter[]
            {
                PresetCharacters.BuildPlayer(level: 2, teamId: 1), PresetCharacters.BuildElara(level: 2, teamId: 1),
                PresetCharacters.BuildTharr(level: 2, teamId: 1), PresetCharacters.BuildFenwick(level: 2, teamId: 1),
                CreatureFactory.Create(goblin, teamId: 2), CreatureFactory.Create(goblin, teamId: 2),
            };
            var setup = layout == null ? new CombatSetup { GridWidth = 12, GridHeight = 10, RngSeed = seed }
                : new CombatSetup { Layout = layout, BiomeId = "forest", RngSeed = seed };
            for (int i = 0; i < units.Length; i++)
                (i < 4 ? setup.Party : setup.Enemies).Add((units[i], centre + ClusterOffsets[i]));
            scene.StartEncounter(setup);
            await WaitSeconds(BootSeconds);
            if (scene.IsPlayerTurn && Session(scene).Team2.All(g => g.Health?.IsAlive == true)) return Session(scene);
        }
        return null;
    }

    /// <summary>The timeline replaced the party column (FFT layout): a downed hero's tile leads its
    /// marks with Dying, and every hero has a tile.</summary>
    private void CheckChipMatchesRail(CombatScene scene, TurnOrderBar rail, ICharacter dying)
    {
        var icons = Tokens(scene)[0].Dying.Icons;
        Control? TileFor(ICharacter hero) => rail.Row.GetChildren().OfType<Control>()
            .FirstOrDefault(r => r.GetNodeOrNull<Label>("%Label")?.Text == hero.Name);
        var dyingTile = TileFor(dying);
        var firstMark = dyingTile?.GetNode("%Marks").GetChildren().OfType<TextureRect>().FirstOrDefault()?.Texture;
        Check("the downed hero's timeline tile leads its marks with Dying",
            firstMark != null && firstMark == icons.Tile(nameof(Condition.Dying)));
        var missing = Session(scene).Team1.Where(hero => TileFor(hero) == null).Select(hero => hero.Name).ToList();
        Check($"every hero has a timeline tile{(missing.Count > 0 ? $" (missing {string.Join(", ", missing)})" : "")}", missing.Count == 0);
    }

    private List<UnitVisual3D> Tokens(CombatScene scene)
        => scene.GetNode<Node3D>("%UnitLayer").GetChildren().OfType<UnitVisual3D>().ToList();

    /// <summary>No token draws a condition icon except the Dying badge, which sits right of its HP bar
    /// and clear of every name plate.</summary>
    private void CheckMarkerTokens(CombatScene scene, ICharacter dying, string state)
    {
        var camera = scene.ActiveCamera;
        var tokens = Tokens(scene);
        var icons = tokens[0].Dying.Icons;
        var dyingIcon = icons.Find(nameof(Condition.Dying));
        var stray = new List<string>();
        foreach (var token in tokens)
            foreach (var node in token.FindChildren("*", "", true, false))
            {
                var texture = node switch
                {
                    Sprite3D sprite when sprite.IsVisibleInTree() => sprite.Texture,
                    TextureRect rect when rect.IsVisibleInTree() => rect.Texture,
                    _ => null,
                };
                if (texture != null && icons.Owns(texture) && !(texture == dyingIcon && node.GetParent() == token.Dying))
                    stray.Add($"{token.Character.Name} {node.Name}");
            }
        Check($"{state}: no condition icon on any token except Dying ({string.Join(", ", stray)})", stray.Count == 0);
        var badged = tokens.Where(t => t.Dying.Visible).ToList();
        int value = dying.Conditions.GetConditionValue(Condition.Dying);
        Check($"{state}: only the dying ally shows a board mark, with its value ({string.Join(", ", badged.Select(t => $"{t.Character.Name} {t.Dying.Value}"))})",
            badged.Count == 1 && badged[0].Character == dying && badged[0].Dying.Value == value && value > 0);
        if (badged.Count != 1 || badged[0].Dying.ScreenRect(camera) is not { } badge) return;
        var bar = badged[0].GetNode<WorldHpBar>("%HpBar");
        var edge = camera.UnprojectPosition(bar.GlobalPosition) + new Vector2(bar.ScreenWidth / 2, 0);
        float drawn = camera.UnprojectPosition(bar.GlobalTransform * new Vector3(bar.ScreenWidth / 2, 0, 0)).X
            - camera.UnprojectPosition(bar.GlobalTransform * new Vector3(-bar.ScreenWidth / 2, 0, 0)).X;
        Check($"{state}: the HP bar keeps its {bar.ScreenWidth:0}x{bar.ScreenHeight:0} px screen size ({drawn:0.0} px wide)",
            Mathf.Abs(drawn - bar.ScreenWidth) <= 1);
        Check($"{state}: the Dying badge sits right of the HP bar, clear of the timeline number ({badge} vs bar edge {edge})",
            badge.Position.X >= edge.X - 0.5f && badge.Position.Y <= edge.Y && badge.End.Y >= edge.Y);
        CheckPlates(scene);
    }

    /// <summary>Ends hero turns until an enemy roll with named modifiers settles on the band.</summary>
    private async Task CaptureEnemyRoll(CombatScene scene, CombatSession session)
    {
        var dice = scene.GetNode<DiceRollPanel>("%DiceRoll");
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var original = session.ReactionPromptHandler;
        session.ReactionPromptHandler = _ => Task.FromResult(false);
        bool captured = false;
        for (float waited = 0; waited < 60f && !captured && !scene.GetNode<VictoryBanner>("%VictoryBanner").Visible; waited += 0.1f)
        {
            // A critical outcome word already widens the row past 600 px, so the capture waits for a plain degree.
            if (dice.Showing is { EnemyRoll: true, Breakdown.IsEmpty: false, Critical: false } roll && dice.Settled)
            {
                string detail = dice.DetailText;
                string defense = roll.IsAttack ? "AC" : "DC";
                var expected = roll.Breakdown.Roll.Select(m => m.IconKey.Length > 0 && !detail.Contains(m.Label) ? $"{m.Value:+0;-0}" : m.Text)
                    .Concat(roll.Breakdown.Defense.Select(m => $"{(m.IconKey.Length > 0 ? defense : $"{m.Label} {defense}")} {m.Value:+0;-0}")).ToList();
                Check($"an enemy roll lists the modifiers that applied within 600 px ('{detail.Replace("\n", " | ")}'; expected {string.Join(", ", expected)}; {dice.Size})",
                    expected.All(detail.Contains) && dice.Size.X <= 600.5f);
                var targetPlate = Tokens(scene).FirstOrDefault(t => t.Plate.PlateVisible && t.Plate.Lane == PlateLane.Foot);
                Check($"an enemy roll without a prompt labels its target: card and Foot plate ({targetPlate?.Character.Name ?? "no plate"})",
                    scene.GetNode<Control>("%TargetCard").Visible && targetPlate != null);
                AssertZones(scene, "markers_enemy_roll.png");
                Capture("markers_enemy_roll.png");
                captured = true;
                break;
            }
            if (scene.IsPlayerTurn && session.CurrentActor is { } actor && bar.ActorName == actor.Name)
                bar._UnhandledInput(new InputEventAction { Action = InputNames.EndTurn, Pressed = true });
            await WaitSeconds(0.1f);
        }
        Check("a non-critical enemy roll with named modifiers settled on the band", captured);
        session.ReactionPromptHandler = original;
    }
}
