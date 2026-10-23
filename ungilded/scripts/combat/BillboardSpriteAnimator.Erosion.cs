using Godot;
using Ungilded.Fx;

namespace Ungilded.Combat;

/// <summary>The death erosion of the drawn body: lit_sprite.gdshader breaks the frozen frame on its own
/// texel grid as <see cref="ErosionProgress"/> runs from 0 to 1.</summary>
public partial class BillboardSpriteAnimator
{
    /// <summary>The erosion <see cref="BeginErosion"/> set up, or null.</summary>
    public SpriteErosion? Erosion { get; private set; }

    private float _erosionProgress;

    /// <summary>0 draws the body whole; 1 discards every texel.</summary>
    public float ErosionProgress
    {
        get => _erosionProgress;
        set
        {
            _erosionProgress = value;
            _lit?.SetShaderParameter(SpriteErosion.ProgressParameter, value);
        }
    }

    /// <summary>Freeze the frame on screen and set the material to erode it, the front moving along
    /// <paramref name="screenDirection"/> (x right, y down on screen). The see-through outline goes at
    /// once: it would keep the whole silhouette behind a wall. Null when the sprite has no lit material
    /// or no frame to read.</summary>
    public SpriteErosion? BeginErosion(Vector2 screenDirection, uint seed)
    {
        if (_lit == null || Texture == null) return null;
        Frozen = true;
        RefreshLighting();
        var read = ReadFrame();
        if (read == null) return null;
        var (frame, origin) = read.Value;
        // The frame is read as it lies in the page; FlipH mirrors it on screen.
        var direction = new Vector2(FlipH ? -screenDirection.X : screenDirection.X, screenDirection.Y);
        Erosion = new SpriteErosion(frame, _lit, direction, seed)
        {
            PixelSize = PixelSize,
            FlipH = FlipH,
            Offset = Offset,
            Centre = Position,
            Tint = Modulate,
        };
        Erosion.Apply(_lit, origin);
        _erosionProgress = 0f;
        RefreshSilhouette();
        return Erosion;
    }

    /// <summary>The frame on screen and its top-left texel in the page. A page the renderer cannot hand
    /// back (the headless dummy) is read from its source file.</summary>
    private (Image Frame, Vector2I Origin)? ReadFrame()
    {
        var page = Texture!.GetImage();
        if ((page == null || page.IsEmpty()) && !string.IsNullOrEmpty(Texture.ResourcePath))
            page = Image.LoadFromFile(ProjectSettings.GlobalizePath(Texture.ResourcePath));
        if (page == null || page.IsEmpty()) return null;
        if (page.IsCompressed()) page.Decompress();
        page.Convert(Image.Format.Rgba8);
        var region = RegionEnabled
            ? new Rect2I((Vector2I)RegionRect.Position, (Vector2I)RegionRect.Size)
            : new Rect2I(Vector2I.Zero, page.GetSize());
        var cell = new Vector2I(region.Size.X / Hframes, region.Size.Y / Vframes);
        var origin = region.Position + new Vector2I(Frame % Hframes * cell.X, Frame / Hframes * cell.Y);
        return (page.GetRegion(new Rect2I(origin, cell)), origin);
    }
}
