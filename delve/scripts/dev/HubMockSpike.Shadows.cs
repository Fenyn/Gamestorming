using System.Linq;
using Godot;

namespace Delve.Dev;

/// <summary>
/// HD-2D sprite shadows. A billboard casts its shadow from the quad turned to the camera, so a sun
/// from the side sees it edge-on and draws a hairline. Each billboard instead gets a shadow-only
/// twin that shows the same frame, stands upright and turns square to the sun; the visible sprite
/// casts nothing.
/// </summary>
public partial class HubMockSpike
{
    private const string TwinName = "ShadowTwin";

    private void SyncShadows()
    {
        var light = -_outpost.GetNode<DirectionalLight3D>("Moonlight").GlobalBasis.Z;
        float yaw = Mathf.Atan2(light.X, light.Z);
        foreach (var sprite in _outpost.FindChildren("*", nameof(Sprite3D), true, false).OfType<Sprite3D>())
        {
            if (sprite.Name == TwinName || sprite.Billboard == BaseMaterial3D.BillboardModeEnum.Disabled) continue;
            sprite.CastShadow = GeometryInstance3D.ShadowCastingSetting.Off;
            if (sprite.GetNodeOrNull<Sprite3D>(TwinName) is not { } twin)
            {
                twin = new Sprite3D { Name = TwinName, CastShadow = GeometryInstance3D.ShadowCastingSetting.ShadowsOnly };
                sprite.AddChild(twin);
            }
            twin.Texture = sprite.Texture;
            twin.Hframes = sprite.Hframes;
            twin.Vframes = sprite.Vframes;
            twin.Frame = sprite.Frame;
            twin.RegionEnabled = sprite.RegionEnabled;
            twin.RegionRect = sprite.RegionRect;
            twin.PixelSize = sprite.PixelSize;
            twin.Centered = sprite.Centered;
            twin.Offset = sprite.Offset;
            twin.FlipH = sprite.FlipH;
            twin.AlphaCut = SpriteBase3D.AlphaCutMode.Discard;
            twin.TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest;
            twin.GlobalRotation = new Vector3(0, yaw, 0);
        }
    }
}
