using Godot;

namespace Delve.Flow;

/// <summary>The outpost diorama, its fire, and stable world-space places for the roster.</summary>
public partial class CampStage : Control
{
    [Export] public Vector3[] Seats { get; set; } = System.Array.Empty<Vector3>();
    [Export] public string[] SeatIds { get; set; } = System.Array.Empty<string>();
    [Export] public CampAppearance[] Appearances { get; set; } = System.Array.Empty<CampAppearance>();
    [Export] public float FireFrameSeconds { get; set; } = 0.14f;
    [Export] public float FireEnergy { get; set; } = 2.2f;
    [Export] public Vector3 LookTarget { get; set; }
    private Camera3D _camera = null!;
    private SubViewport _viewport = null!;
    private Sprite3D _fire = null!;
    private OmniLight3D _light = null!;
    private CampTerrain _terrain = null!;
    private float _time;

    public override void _Ready()
    {
        _camera = GetNode<Camera3D>("%CampCamera");
        _viewport = GetNode<SubViewport>("%CampViewport");
        _fire = GetNode<Sprite3D>("%Fire");
        _light = GetNode<OmniLight3D>("%Firelight");
        _terrain = GetNode<CampTerrain>("%CampTerrain");
        _camera.LookAt(LookTarget);
    }

    public Vector2 SeatPosition(int seat)
    {
        // Authored places keep existing residents still as the roster grows.
        var location = seat < Seats.Length ? Seats[seat]
            : new Vector3(-7 + (seat % 8) * 2, 0, -5 - (seat / 8) * 2);
        location.Y += _terrain.HeightAt(location);
        var point = _camera.UnprojectPosition(location);
        return point * Size / new Vector2(Mathf.Max(1, _viewport.Size.X), Mathf.Max(1, _viewport.Size.Y));
    }

    public int SeatFor(string id) => System.Array.IndexOf(SeatIds, id);

    public CampAppearance AppearanceFor(int seat) => Appearances[Mathf.Min(seat, Appearances.Length - 1)];

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        _time += (float)delta;
        _fire.Frame = (int)(_time / FireFrameSeconds) % _fire.Hframes;
        _light.LightEnergy = FireEnergy + Mathf.Sin(_time * 7.3f) * 0.13f + Mathf.Sin(_time * 13.1f) * 0.07f;
    }
}
