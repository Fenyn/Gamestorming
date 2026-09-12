using System.Threading.Tasks;
using System.Linq;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Godot;
using PF2e.Data;

namespace Delve.Dev;

public partial class EnemySpriteSpike : SpikeBase
{
    protected override Task RunSpikeAsync(DataManager data)
    {
        var library = new SpriteFrames();
        library.AddAnimation("amble");
        library.SetAnimationSpeed("amble", 4);
        library.SetAnimationLoop("amble", true);
        var a = new GradientTexture2D { Width = 12, Height = 24 };
        var b = new GradientTexture2D { Width = 12, Height = 24 };
        library.AddFrame("amble", a, 1);
        library.AddFrame("amble", b, 2);
        library.AddAnimation("blink");
        library.SetAnimationSpeed("blink", 10);
        library.SetAnimationLoop("blink", false);
        library.AddFrame("blink", b);
        library.AddFrame("blink", a);
        library.AddAnimation("still");
        library.AddFrame("still", a);
        library.AddAnimation("empty");
        var player = new EnemyAnimationPlayer();
        Check("custom animation names load", player.Play(library, "amble"));
        player.Tick(0.25);
        Check("authored FPS advances first frame", player.Texture == b);
        player.Tick(0.4);
        Check("relative duration holds second frame", player.Texture == b);
        player.Tick(0.11);
        Check("authored loop wraps", player.Texture == a);
        player.Tick(750.25);
        Check("large delta retains frame remainder", player.Texture == b);
        Check("missing and empty clips reject without losing state",
            !player.Play(library, "absent") && !player.Play(library, "empty") && player.Texture == b);
        player.Play(library, "blink"); player.Tick(100);
        Check("non-looping clip holds last frame", !player.Playing && player.Texture == a);
        player.Play(library, "still"); player.Tick(100);
        Check("single-frame idle remains valid", player.Playing && player.Texture == a);
        library.SetAnimationSpeed("still", 0); player.Tick(100);
        Check("zero FPS holds frame", player.Texture == a);

        var sprite = new BillboardSpriteAnimator(); AddChild(sprite);
        var definition = new EnemySpriteDefinition
        {
            Frames = library, IdleAnimation = "still", MoveAnimation = "amble",
            PixelSize = 0.03f, FootMarginPixels = 5, FacesRight = false,
        };
        sprite.ConfigureEnemy(definition);
        Check("placement comes from the sprite resource",
            Mathf.IsEqualApprox(sprite.Position.Y, 0.21f) && Mathf.IsEqualApprox(sprite.BodyHeight, 0.57f));
        sprite.SetMoving(true); sprite._Process(0.25);
        Check("movement selects configured clip", sprite.Texture == b);
        sprite.Frozen = true; sprite._Process(1);
        Check("freeze stops enemy animation clock", sprite.Texture == b);
        sprite.Frozen = false; sprite._Process(0.1);
        Check("unfreeze resumes rather than catching up", sprite.Texture == b);
        sprite.Position += Vector3.Right * 0.1f;
        Vector3 shaken = sprite.Position;
        sprite._Process(0.5);
        Check("frame changes preserve presenter position effects", sprite.Position == shaken);
        sprite.Facing = Vector2.Right; sprite.ApplyFacing();
        Check("authored left-facing art flips correctly", sprite.FlipH);
        sprite.SetMoving(false);
        Check("stopping restores authored idle", sprite.Texture == a);
        sprite.PlayEnemyAnimation("absent");
        Check("missing optional animation falls back to idle", sprite.Texture == a);

        definition.AttackAnimation = "blink";
        definition.AttackImpactFrame = 1;
        sprite.ConfigureEnemy(definition);
        Check("attack uses configured clip and contact timing",
            sprite.PlayAttack(out float impact) && Mathf.IsEqualApprox(impact, 0.1f) && sprite.Texture == b);
        sprite.SetMoving(true);
        Check("movement cannot interrupt attack", sprite.Texture == b);
        sprite.Frozen = true; sprite._Process(1);
        Check("frozen attack holds its pose", sprite.Texture == b);
        sprite.Frozen = false; sprite._Process(0.11);
        Check("attack advances to contact frame", sprite.Texture == a);
        sprite.PlayAttack(out _);
        Check("consecutive attack restarts wind-up", sprite.Texture == b);
        sprite.Position += Vector3.Right * 0.1f;
        shaken = sprite.Position;
        sprite._Process(0.3);
        Check("recovery restores movement and preserves effects", sprite.Texture == a && sprite.Position == shaken);
        sprite.SetMoving(false); sprite.PlayAttack(out _); sprite._Process(0.3);
        Check("stationary attack returns to idle", sprite.Texture == a);
        definition.AttackAnimation = "absent";
        Check("missing attack retains fallback", !sprite.PlayAttack(out _));
        definition.AttackAnimation = "amble";
        Check("looping attack is rejected", !sprite.PlayAttack(out _));

        foreach (string folder in new[] { "rat_v1", "rat_v2", "rat_v3", "placeholder_small", "placeholder_medium", "placeholder_large", "goblin_base", "kobold_base", "wolf_base", "viper_base", "spider_base", "boar_base", "giant_viper_base", "giant_monitor_lizard_base", "dire_wolf_base", "grizzly_bear_base", "giant_stag_beetle_base" })
        {
            var resource = GD.Load<EnemySpriteDefinition>($"res://assets/sprites/enemies/{folder}/sprite.tres");
            Check($"{folder} has a playable authored idle", resource?.Frames != null
                && player.Play(resource.Frames, resource.IdleAnimation) && player.Texture != null);
            if (folder.EndsWith("_base") && resource?.Frames != null)
            {
                int count = resource.Frames.GetFrameCount(resource.IdleAnimation);
                bool grounded = count > 1;
                for (int i = 0; i < count; i++)
                {
                    var texture = resource.Frames.GetFrameTexture(resource.IdleAnimation, i);
                    var bounds = texture.GetImage().GetUsedRect();
                    grounded &= texture.GetHeight() - bounds.End.Y == resource.FootMarginPixels;
                }
                Check($"{folder} animated idle keeps its feet at the authored origin", grounded);
                sprite.ConfigureEnemy(resource);
                Check($"{folder} has a timed attack", sprite.PlayAttack(out impact) && impact > 0);
                sprite._Process(2);
                Check($"{folder} attack recovers to idle",
                    sprite.Texture == resource.Frames.GetFrameTexture(resource.IdleAnimation, 0));
                if (folder.StartsWith("giant_") || folder is "dire_wolf_base" or "grizzly_bear_base")
                    CheckNewCreatureFrames(folder, resource);
            }
        }
        foreach (string name in new[] { "Goblin Warrior", "Goblin Commando", "Goblin War Chanter", "Kobold Warrior", "Kobold Scout", "Wolf", "Viper", "Hunting Spider", "Boar", "Giant Viper", "Giant Monitor Lizard", "Dire Wolf", "Grizzly Bear", "Giant Stag Beetle" })
        {
            string folder = EnemySpriteMap.FolderForCreature(name, CreatureSize.Small);
            Check($"{name} and adjusted variants use base art", folder.EndsWith("_base")
                && EnemySpriteMap.FolderForCreature("Elite " + name, CreatureSize.Small) == folder
                && EnemySpriteMap.FolderForCreature("Weak " + name, CreatureSize.Small) == folder);
        }
        Check("unmapped creatures keep size fallback",
            EnemySpriteMap.FolderForCreature("Ogre Warrior", CreatureSize.Large) == EnemySpriteMap.PlaceholderFolder(CreatureSize.Large));
        foreach (var creature in FloorThemes.ForStratum(0).Roster)
            Check($"Fringe {creature.DisplayName} has art",
                !EnemySpriteMap.FolderForCreature(creature.DisplayName, CreatureSize.Large).Contains("placeholder"));
        sprite.QueueFree();
        return Task.CompletedTask;
    }

    private void CheckNewCreatureFrames(string folder, EnemySpriteDefinition definition)
    {
        var frames = definition.Frames!;
        var idle = frames.GetFrameTexture(definition.IdleAnimation, 0).GetImage();
        bool pixelsValid = true;
        bool dimensionsMatch = true;
        foreach (var clip in new[] { definition.IdleAnimation, definition.AttackAnimation })
        {
            for (int frame = 0; frame < frames.GetFrameCount(clip); frame++)
            {
                var image = frames.GetFrameTexture(clip, frame).GetImage();
                dimensionsMatch &= image.GetSize() == idle.GetSize();
                for (int y = 0; y < image.GetHeight(); y++)
                    for (int x = 0; x < image.GetWidth(); x++)
                    {
                        float alpha = image.GetPixel(x, y).A;
                        pixelsValid &= alpha == 0 || alpha == 1;
                    }
            }
        }
        int lastAttack = frames.GetFrameCount(definition.AttackAnimation) - 1;
        var recovery = frames.GetFrameTexture(definition.AttackAnimation, lastAttack).GetImage();
        Check($"{folder} uses a fixed canvas and binary alpha", dimensionsMatch && pixelsValid);
        Check($"{folder} final attack pose exactly restores base", idle.GetData().SequenceEqual(recovery.GetData()));
        float expectedScale = folder.EndsWith("giant_monitor_lizard_base") ? 0.018f
            : folder.EndsWith("giant_stag_beetle_base") ? 0.025f : 0.02f;
        Check($"{folder} uses its reviewed world scale", Mathf.IsEqualApprox(definition.PixelSize, expectedScale));
    }
}
