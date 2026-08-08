using System.Collections.Generic;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// PSX post-process grade spike (scenes/dev/psx_spike.tscn). Instances the REAL outpost scene (same
/// pattern as OutpostShotSpike) and layers assets/shaders/psx_post.gdshader over it via the %Post
/// ColorRect authored in the scene, then steps through a fixed sequence of settings x framings,
/// writing one PNG per combination to the scratchpad for eyeball comparison. Nothing about the
/// outpost scene, its textures, or project settings is touched — the grade is a pure screen-space
/// overlay on a CanvasLayer, applied/removed entirely by toggling shader uniforms.
///
/// Framings (matching OutpostShotSpike's naming):
///   follow     - the gameplay follow camera the outpost scene establishes on its own (town-centre
///                plaza, %PlayerSpawn).
///   gate_plaza - a spike-owned static camera inside the walls looking south at the gate opening,
///                the same framing OutpostShotSpike.cs uses for outpost_3d_gate_plaza.png.
///
/// Settings per framing:
///   a_baseline    - grade fully off (pass-through), the control shot.
///   b_grade       - crush (5 bits/channel) + ordered dither, full render resolution.
///   b_grade_4bit  - bonus: same as b_grade but 4 bits/channel, in case 5-bit reads as no visible
///                   change against the Winlu art's already-limited palette (see the shader's header).
///   c_360p        - b_grade + resolution drop to a 360p virtual grid.
///   d_240p        - b_grade + resolution drop to a 240p virtual grid.
///
/// gate_plaza also gets a `_v2` fidelity-proof sequence: psx_gate_plaza_nopost_v2.png (the %Post
/// ColorRect hidden entirely, i.e. no shader in the pipeline) captured back-to-back with
/// psx_gate_plaza_a_baseline_v2.png (grade fully off) to prove the two are a bit-exact match, followed
/// by the b_grade_4bit/c_360p/d_240p judgment shots re-rendered with the same `_v2` suffix.
///
/// Must run rendered (not --headless):
///   Godot_v4.6.2-stable_mono_win64.exe --path bulwark res://scenes/dev/psx_spike.tscn
/// </summary>
public partial class PsxSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\2bd27b51-0eee-4938-8f02-f94cf931795f\scratchpad";

    private const float StepDelay = 0.4f;          // settle time between same-framing captures
    private const float FramingSwitchDelay = 0.8f; // extra settle time right after a camera swap

    private struct Step
    {
        public string File;
        public bool CrushEnabled;
        public int Bits;
        public bool DitherEnabled;
        public bool ResDropEnabled;
        public float TargetVRes;
        public bool SwitchToGatePlaza; // true only on the first step of the second framing
        public bool HidePost;          // true: hide the %Post ColorRect entirely (no shader in the pipeline at all)
        public float SettleOverride;   // >0 overrides the normal StepDelay/FramingSwitchDelay settle time
    }

    private Node3D? _outpost;
    private Camera3D? _gatePlazaCamera;
    private ShaderMaterial? _material;
    private ColorRect? _post;

    private readonly List<Step> _steps = new();
    private int _index = -1;
    private double _timer;
    private bool _waiting;

    public override void _Ready()
    {
        _outpost = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn").Instantiate<Node3D>();
        AddChild(_outpost);

        _gatePlazaCamera = new Camera3D { Name = "GatePlazaCamera", Fov = 60f };
        AddChild(_gatePlazaCamera);
        _gatePlazaCamera.GlobalPosition = new Vector3(48f, 20f, 55f);
        _gatePlazaCamera.LookAt(new Vector3(48f, 3f, 92f), Vector3.Up);

        _post = GetNode<ColorRect>("%Post");
        _material = _post.Material as ShaderMaterial;

        BuildSteps();

        GD.Print($"[psxspike] spike ready, {_steps.Count} capture steps queued");
    }

    private void BuildSteps()
    {
        void AddFramingSteps(string framing, bool switchCamera)
        {
            _steps.Add(new Step { File = $"psx_{framing}_a_baseline.png", SwitchToGatePlaza = switchCamera });
            _steps.Add(new Step
            {
                File = $"psx_{framing}_b_grade.png",
                CrushEnabled = true, Bits = 5, DitherEnabled = true,
            });
            _steps.Add(new Step
            {
                File = $"psx_{framing}_b_grade_4bit.png",
                CrushEnabled = true, Bits = 4, DitherEnabled = true,
            });
            _steps.Add(new Step
            {
                File = $"psx_{framing}_c_360p.png",
                CrushEnabled = true, Bits = 5, DitherEnabled = true,
                ResDropEnabled = true, TargetVRes = 360f,
            });
            _steps.Add(new Step
            {
                File = $"psx_{framing}_d_240p.png",
                CrushEnabled = true, Bits = 5, DitherEnabled = true,
                ResDropEnabled = true, TargetVRes = 240f,
            });
        }

        AddFramingSteps("follow", switchCamera: false);

        // gate_plaza fidelity fix verification (v2): a same-run, back-to-back pair proving the fixed
        // shader's all-off path is a bit-exact passthrough against the post layer being entirely
        // absent, followed by the judgment set the grade is actually evaluated on.
        _steps.Add(new Step
        {
            File = "psx_gate_plaza_nopost_v2.png",
            SwitchToGatePlaza = true,
            HidePost = true,
        });
        _steps.Add(new Step
        {
            File = "psx_gate_plaza_a_baseline_v2.png",
            SettleOverride = 0.001f, // capture the very next frame so nothing in the scene has time to animate
        });
        _steps.Add(new Step
        {
            File = "psx_gate_plaza_b_grade_4bit_v2.png",
            CrushEnabled = true, Bits = 4, DitherEnabled = true,
        });
        _steps.Add(new Step
        {
            File = "psx_gate_plaza_c_360p_v2.png",
            CrushEnabled = true, Bits = 5, DitherEnabled = true,
            ResDropEnabled = true, TargetVRes = 360f,
        });
        _steps.Add(new Step
        {
            File = "psx_gate_plaza_d_240p_v2.png",
            CrushEnabled = true, Bits = 5, DitherEnabled = true,
            ResDropEnabled = true, TargetVRes = 240f,
        });
    }

    public override void _Process(double delta)
    {
        _timer += delta;

        if (_index < 0)
        {
            // initial settle: let the outpost's own loaders spawn the player/camera before capturing.
            if (_timer > 2.0)
                Advance();
            return;
        }

        if (_waiting)
        {
            Step current = _steps[_index];
            float delay = current.SettleOverride > 0f
                ? current.SettleOverride
                : (current.SwitchToGatePlaza ? FramingSwitchDelay : StepDelay);
            if (_timer > delay)
            {
                Capture(_steps[_index].File);
                Advance();
            }
        }
    }

    private void Advance()
    {
        _index++;
        _timer = 0;

        if (_index >= _steps.Count)
        {
            GD.Print("[psxspike] done, quitting");
            GetTree().Quit(0);
            return;
        }

        Step step = _steps[_index];

        if (step.SwitchToGatePlaza && _gatePlazaCamera != null)
            _gatePlazaCamera.Current = true;

        if (_post != null)
            _post.Visible = !step.HidePost;

        if (_material != null)
        {
            _material.SetShaderParameter("enable_crush", step.CrushEnabled);
            _material.SetShaderParameter("bits_per_channel", step.Bits == 0 ? 5 : step.Bits);
            _material.SetShaderParameter("enable_dither", step.DitherEnabled);
            _material.SetShaderParameter("dither_strength", 1.0f);
            _material.SetShaderParameter("enable_resolution_drop", step.ResDropEnabled);
            _material.SetShaderParameter("target_vertical_resolution", step.TargetVRes == 0f ? 240f : step.TargetVRes);
            _material.SetShaderParameter("enable_color_lift", false);
        }

        _waiting = true;
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        img.SavePng($"{OutDir}\\{file}");
        GD.Print($"[psxspike] saved {file}");
    }
}
