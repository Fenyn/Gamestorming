using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Flow;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class DungeonSpike
{
    private async Task CheckCharacterDetails(DungeonDirector host)
    {
        await WaitSeconds(0.4f);
        var rig = host.GetNode<OrbitCameraRig>("%ExploreCamera");
        var overlay = host.GetNode<CharacterDetailsOverlay>("%CharacterDetails");
        var tokens = host.GetNode<Node3D>("%TravelParty").GetChildren().OfType<UnitVisual3D>().ToArray();
        int ward = host.State.Wardstone.Ward, room = host.Current.Id;
        foreach (var token in tokens.Take(2))
        {
            Vector2? point = null;
            var center = rig.Camera.UnprojectPosition(token.GlobalPosition + Vector3.Up);
            for (int y = -60; y <= 60 && point == null; y += 2)
                for (int x = -40; x <= 40 && point == null; x += 2)
                {
                    var sample = center + new Vector2(x, y);
                    var origin = rig.Camera.ProjectRayOrigin(sample);
                    var direction = rig.Camera.ProjectRayNormal(sample);
                    var hits = tokens.Select(t => (Token: t, Hit: t.GetNode<UnitPickArea>("%PickArea")
                        .HitSprite(rig.Camera, origin, direction, out float d), Distance: d))
                        .Where(h => h.Hit).OrderBy(h => h.Distance);
                    if (hits.FirstOrDefault().Token == token) point = sample;
                }
            Check($"{token.Character.Name} has a visible clickable sprite", point != null);
            if (point is not { } screen) continue;
            GetViewport().PushInput(new InputEventMouseMotion { Position = screen, GlobalPosition = screen });
            await WaitSeconds(0.1f);
            var sprite = token.GetNode<BillboardSpriteAnimator>("%Sprite");
            Check("hover outlines only the clickable character", sprite.HoverHighlighted
                && tokens.Count(t => t.GetNode<BillboardSpriteAnimator>("%Sprite").HoverHighlighted) == 1);
            Check("hover uses the character's identity color", ((ShaderMaterial)sprite.MaterialOverlay)
                .GetShaderParameter("hover_color").AsColor() == UiColors.CharacterAccent(token.Character.Id));
            if (Capture) await Shot($"dungeon_hover_{token.Character.Id}.png");
            var away = new Vector2(10, 10);
            GetViewport().PushInput(new InputEventMouseMotion { Position = away, GlobalPosition = away });
            await WaitSeconds(0.1f);
            Check("leaving the character clears its outline", !sprite.HoverHighlighted);
            void Click(Vector2 release)
            {
                host._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = screen });
                host._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = release });
            }
            Click(screen + new Vector2(20, 0));
            await WaitSeconds(0.05f);
            Check("dragging past a character does not open details", !overlay.Visible);
            Click(screen);
            await WaitSeconds(0.1f);
            Check("sprite click opens that party member's sheet", overlay.Visible
                && overlay.GetNode<HeroSheet>("%Sheet").GetNode<Label>("%HeroName").Text == token.Character.Name);
            Check("opening details clears exploration outlines", tokens.All(t => !t.GetNode<BillboardSpriteAnimator>("%Sprite").HoverHighlighted));
            await host.Travel(host.Current.Doors[0].Side(room));
            Check("sheet blocks travel without spending ward", host.Current.Id == room
                && host.State.Wardstone.Ward == ward && host.Phase == DungeonPhase.Doors
                && rig.ProcessMode == ProcessModeEnum.Disabled);
            if (Capture) await Shot($"dungeon_details_{token.Character.Id}.png");
            overlay._Input(new InputEventAction { Action = InputNames.UiCancel, Pressed = true });
            Check("Escape returns to the same room and restores camera input", !overlay.Visible
                && host.Current.Id == room && rig.ProcessMode == ProcessModeEnum.Inherit);
        }
    }
}
