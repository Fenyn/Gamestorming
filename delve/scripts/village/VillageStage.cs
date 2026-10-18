using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Village;

/// <summary>
/// The camp village in its own 3D viewport: shows the pieces built at the current town tier, sets the
/// light for the camp's time of day, and keeps the hearth fire burning.
/// </summary>
public partial class VillageStage : Control
{
    [Signal] public delegate void StationPressedEventHandler(string id);

    [Export] public SubViewport Viewport { get; set; } = null!;
    [Export] public VillageCamera Camera { get; set; } = null!;
    [Export] public DirectionalLight3D Sun { get; set; } = null!;
    [Export] public WorldEnvironment World { get; set; } = null!;
    [Export] public VillageGround Ground { get; set; } = null!;
    [Export] public Sprite3D Fire { get; set; } = null!;
    [Export] public OmniLight3D Firelight { get; set; } = null!;

    /// <summary>Parent of the village's <see cref="CameraStop"/> markers.</summary>
    [Export] public Node3D Stops { get; set; } = null!;
    [Export] public VillageResidents Residents { get; set; } = null!;
    [Export] public VillageLineup Lineup { get; set; } = null!;
    [Export] public VillageStation[] Stations { get; set; } = System.Array.Empty<VillageStation>();
    [Export] public StationTags Tags { get; set; } = null!;
    [Export] public VillageWalkable Walkable { get; set; } = null!;

    /// <summary>The stop the village opens on.</summary>
    [Export] public string HomeStop { get; set; } = "hearth";

    /// <summary>The trailhead view party assembly frames.</summary>
    [Export] public string AssemblyStop { get; set; } = "delve";

    /// <summary>Light per time of day, in <see cref="CampTimeOfDay"/> order.</summary>
    [Export] public CampLight[] Lights { get; set; } = System.Array.Empty<CampLight>();

    /// <summary>The shared window glass material; its texture swaps to the pack's lit window in the evening.</summary>
    [Export] public BaseMaterial3D? Glass { get; set; }
    [Export] public Texture2D? DayGlass { get; set; }
    [Export] public Texture2D? LitGlass { get; set; }

    [Export] public float FireFrameSeconds { get; set; } = 0.14f;

    /// <summary>How far past the framed stop's target the sun's shadow map reaches. A short reach keeps
    /// the small figure shadows crisp; the wide view needs it long.</summary>
    [Export] public float ShadowReach { get; set; } = 28f;

    /// <summary>Longest shadow a billboard casts, as a share of its height. A low sun is squashed down to it.</summary>
    [Export] public float ShadowLength { get; set; } = 0.9f;

    public TownTier Tier { get; private set; } = TownTier.Camp;
    public CampTimeOfDay Time { get; private set; } = CampTimeOfDay.Morning;

    private readonly LitBillboards _lighting = new();

    /// <summary>Everyone who walks the village: residents, picks and hens.</summary>
    public VillageCrowd Crowd { get; } = new();
    private float _fireEnergy = 1f;
    private float _clock;

    /// <summary>While false (an overlay is open, or the party is being assembled), Q and E do not move the
    /// camera and the station nameplates are hidden.</summary>
    public bool Browsing
    {
        get => Tags.Visible;
        set => Tags.Visible = value;
    }

    public CameraStop? StopFor(string id) => Stops.GetChildren().OfType<CameraStop>().FirstOrDefault(s => s.Id == id);

    public override void _Ready()
    {
        foreach (var station in Stations)
            station.Pressed += id => EmitSignal(SignalName.StationPressed, id);
        Residents.Lighting = _lighting;
        Lineup.Lighting = _lighting;
        Crowd.Keep = Walkable.Keep;
        Crowd.Clear = Walkable.Clear;
        Residents.Crowd = Crowd;
        Lineup.Crowd = Crowd;
        foreach (var node in GetTree().GetNodesInGroup(VillageChicken.Group))
            if (node is VillageChicken hen && IsAncestorOf(hen))
            {
                hen.Walkable = Walkable;
                hen.Crowd = Crowd;
                Crowd.Join(hen);
            }
        GoHome();
    }

    public void GoHome(bool ease = false)
    {
        if (StopFor(HomeStop) is { } home) FrameStop(home, ease);
    }

    /// <summary>Eases to a stop by id; false if there is no such stop.</summary>
    public bool GoTo(string stopId)
    {
        if (StopFor(stopId) is not { } stop) return false;
        FrameStop(stop, ease: true);
        return true;
    }

    /// <summary>Frames a stop, cutting or easing, with the sun's shadow reach fitted to it.</summary>
    public void FrameStop(CameraStop stop, bool ease = false)
    {
        Sun.DirectionalShadowMaxDistance = stop.Distance + ShadowReach;
        if (ease) Camera.EaseTo(stop);
        else Camera.Frame(stop);
    }

    /// <summary>Steps west (-1) or east (+1) along the ordered stops, stopping at the ends.</summary>
    public void StepStop(int direction)
    {
        var ordered = Stops.GetChildren().OfType<CameraStop>().Where(s => s.Order >= 0).OrderBy(s => s.Order).ToList();
        if (ordered.Count == 0) return;
        int at = Camera.Stop == null ? -1 : ordered.IndexOf(Camera.Stop);
        int next = at < 0 ? ordered.FindIndex(s => s.Id == HomeStop) : Mathf.Clamp(at + direction, 0, ordered.Count - 1);
        if (next >= 0 && ordered[next] != Camera.Stop) FrameStop(ordered[next], ease: true);
    }

    public override void _UnhandledInput(InputEvent input)
    {
        if (!Browsing || !IsVisibleInTree()) return;
        if (input.IsActionPressed(InputNames.MenuPrev)) StepStop(-1);
        else if (input.IsActionPressed(InputNames.MenuNext)) StepStop(1);
        else return;
        GetViewport().SetInputAsHandled();
    }

    public void ApplyTier(TownTier tier)
    {
        Tier = tier;
        GetTree().CallGroup(TierGate.Group, nameof(TierGate.ApplyTier), (int)tier);
        Ground.ApplyTier((int)tier);
        Walkable.Bake((int)tier);
    }

    public void ApplyTime(CampTimeOfDay time)
    {
        Time = time;
        if ((int)time >= Lights.Length) return;
        var light = Lights[(int)time];
        Sun.RotationDegrees = light.SunRotationDegrees;
        Sun.LightColor = light.SunColor;
        Sun.LightEnergy = light.SunEnergy;
        var environment = World.Environment;
        environment.AmbientLightColor = light.AmbientColor;
        environment.AmbientLightEnergy = light.AmbientEnergy;
        environment.TonemapExposure = light.Exposure;
        _fireEnergy = light.FireEnergy;
        GetTree().CallGroup(EveningLight.Group, nameof(EveningLight.SetEvening), light.Evening);
        GetTree().CallGroup(TierGate.Group, nameof(TierGate.SetEvening), light.Evening);
        if (Glass != null)
        {
            // Lit panes show the pack's lit-window art as drawn; the door lights do the glow.
            Glass.AlbedoTexture = light.Evening ? LitGlass : DayGlass;
            Glass.ShadingMode = light.Evening ? BaseMaterial3D.ShadingModeEnum.Unshaded : BaseMaterial3D.ShadingModeEnum.PerPixel;
        }
        var sun = SunShadows.Angle(Sun, ShadowLength, Mathf.DegToRad(Camera.YawDegrees));
        Residents.Sun = sun;
        Lineup.Sun = sun;
        foreach (var node in GetTree().GetNodesInGroup(SunShadows.BillboardGroup))
            if (node is Sprite3D sprite)
            {
                SunShadows.Sync(sprite, sun);
                _lighting.Apply(sprite);
            }
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        _clock += (float)delta;
        Fire.Frame = (int)(_clock / FireFrameSeconds) % Mathf.Max(1, Fire.Hframes);
        SunShadows.Follow(Fire);
        Firelight.LightEnergy = _fireEnergy + Mathf.Sin(_clock * 7.3f) * 0.13f + Mathf.Sin(_clock * 13.1f) * 0.07f;
    }
}
