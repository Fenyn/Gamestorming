using System.Collections.Generic;
using Delve.Combat;
using Delve.Data;
using Godot;

namespace Delve.Village;

/// <summary>
/// A resident's drawn body: a Mana Seed character standing, walking, working through a full clip,
/// or seated with a pixel-stepped breath and the authored rise into a stand. The facing row comes
/// from the camera. It knows nothing about schedules; <see cref="ResidentFigure"/> tells it what to show.
/// </summary>
public partial class ResidentSprite : Sprite3D, IShadowGround
{
    /// <summary>Pixels between the cell bottom and the feet on the baked pages.</summary>
    [Export] public int FootMarginPx { get; set; } = 20;
    [Export] public float BreathPeriod { get; set; } = 3.8f;
    [Export] public float RisePoseSeconds { get; set; } = 0.16f;

    public ResidentPose Pose { get; set; }
    public ManaSeedClip? Clip { get; set; }
    public int Cycle { get; set; }
    public Vector2 Facing { get; set; } = new(0, 1);

    /// <summary>The village's lit-billboard materials; the spawner hands it over.</summary>
    public LitBillboards? Lighting { get; set; }

    /// <summary>Seconds a full rise or settle takes with the poses this figure has.</summary>
    public float RiseSeconds => _seatPoses.Length * RisePoseSeconds;
    public bool CanSit => _seatPoses.Length > 0;

    /// <summary>The feet sit at the figure's origin, below the lifted cell centre.</summary>
    public float GroundLocalY => -Position.Y;

    private readonly Dictionary<string, Texture2D?> _pages = new();
    private string _folder = "";
    private Texture2D[] _seatPoses = System.Array.Empty<Texture2D>();
    private ResidentPose _shown = (ResidentPose)(-1);
    private int _shownCycle = -1;
    private float _clock;
    private float _breath;
    private Camera3D? _camera;

    /// <param name="seatPoses">Rest pose, rise frames, then the stand (CampAppearance.Poses); empty when the resident has no seated art.</param>
    public void Configure(string folder, Texture2D[] seatPoses, float phase)
    {
        _folder = folder;
        _seatPoses = seatPoses;
        _breath = phase;
        Offset = Vector2.Zero;
        Position = new Vector3(0, (ManaSeedSheet.CellPx * 0.5f - FootMarginPx) * PixelSize, 0);
        UseSheet(ManaSeedSheet.WalkPage);
    }

    public override void _Process(double delta)
    {
        float dt = (float)delta;
        _clock += dt;
        _breath += dt;
        if (Pose != _shown || (Pose == ResidentPose.Work && Cycle != _shownCycle))
        {
            _shown = Pose;
            _shownCycle = Cycle;
            _clock = 0;
        }
        _camera ??= GetViewport()?.GetCamera3D();
        int row = CameraFacing.Row(Facing, _camera);
        switch (Pose)
        {
            case ResidentPose.Walk:
                UseSheet(ManaSeedSheet.WalkPage);
                Frame = (ManaSeedSheet.WalkRowOffset + row) * ManaSeedSheet.Columns
                    + (int)(_clock / ManaSeedSheet.WalkFrameTime) % ManaSeedSheet.WalkFrames;
                break;
            case ResidentPose.Run:
                UseSheet(ManaSeedSheet.WalkPage);
                Frame = (ManaSeedSheet.WalkRowOffset + row) * ManaSeedSheet.Columns + RunColumn(_clock);
                break;
            case ResidentPose.Work when Clip != null:
                UseSheet(Clip.Page);
                Frame = Clip.SheetFrame(row, ClipFrame(Clip, _clock));
                break;
            case ResidentPose.Sit when CanSit:
                UsePose(0);
                // Pixel-stepped breathing, without distorting the art.
                Offset = new Vector2(0, Mathf.Sin(_breath * Mathf.Tau / BreathPeriod) > 0.7f ? 1 : 0);
                break;
            case ResidentPose.Rise when CanSit:
                UsePose(Mathf.Min((int)(_clock / RisePoseSeconds), _seatPoses.Length - 1));
                break;
            case ResidentPose.Settle when CanSit:
                UsePose(Mathf.Max(_seatPoses.Length - 1 - (int)(_clock / RisePoseSeconds), 0));
                break;
            default:
                UseSheet(ManaSeedSheet.WalkPage);
                Frame = row * ManaSeedSheet.Columns;
                break;
        }
        SunShadows.Follow(this);
    }

    /// <summary>The pack's run: walk frames 1, 2, 7, 4, 5, 8 at 80/55/125/80/55/125 ms.</summary>
    private static readonly int[] RunColumns = { 0, 1, 6, 3, 4, 7 };
    private static readonly float[] RunTimes = { 0.08f, 0.055f, 0.125f, 0.08f, 0.055f, 0.125f };

    private static int RunColumn(float time)
    {
        float cycle = 0;
        foreach (float t in RunTimes) cycle += t;
        time %= cycle;
        for (int i = 0; i < RunTimes.Length; i++)
        {
            time -= RunTimes[i];
            if (time < 0) return RunColumns[i];
        }
        return RunColumns[^1];
    }

    private static int ClipFrame(ManaSeedClip clip, float time)
    {
        for (int i = 0; i < clip.FrameCount; i++)
        {
            time -= clip.FrameTimes[i];
            if (time < 0) return i;
        }
        return clip.FrameCount - 1;
    }

    private void UseSheet(string page)
    {
        if (!_pages.TryGetValue(page, out var sheet))
        {
            string path = ManaSeedSheet.SheetPath(_folder, page);
            sheet = _pages[page] = ResourceLoader.Exists(path) ? GD.Load<Texture2D>(path) : null;
        }
        sheet ??= _pages.GetValueOrDefault(ManaSeedSheet.WalkPage);
        if (Texture != sheet)
        {
            Texture = sheet;
            Lighting?.Apply(this);
        }
        Hframes = ManaSeedSheet.Columns;
        Vframes = ManaSeedSheet.Rows;
        Offset = Vector2.Zero;
    }

    private void UsePose(int index)
    {
        Hframes = 1;
        Vframes = 1;
        Frame = 0;
        if (Texture != _seatPoses[index])
        {
            Texture = _seatPoses[index];
            Lighting?.Apply(this);
        }
        Offset = Vector2.Zero;
    }
}
