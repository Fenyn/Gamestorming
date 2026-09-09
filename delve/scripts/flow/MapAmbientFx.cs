using System;
using System.Collections.Generic;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>Sparse cosmetic motion on its own canvas, so trees never redraw for particles.</summary>
public partial class MapAmbientFx : Control
{
    [Export] public int MoteCount { get; set; } = 48;
    [Export] public float DriftSpeed { get; set; } = 3f;
    [Export] public float MoteOpacity { get; set; } = 0.24f;
    [Export] public float FireflyRadius { get; set; } = 170f;
    [Export] public float EmberRise { get; set; } = 18f;
    private readonly List<(Vector2 Position, float Phase)> _motes = new();
    private readonly List<Vector2> _camps = new();
    private Control? _map;
    private Color _mist, _ward;
    private float _time, _strength;
    private Vector2 _light;

    public void SetLight(Vector2 localPosition) => _light = localPosition;

    public void Configure(RunState state, Control map, IReadOnlyDictionary<int, Vector2> centers, Color fog)
    {
        _map = map;
        _time = 0;
        _mist = fog.Lerp(Colors.White, 0.3f);
        _ward = UiColors.CharacterAccent(state.Party.LeaderId).Lerp(Colors.White, 0.35f);
        _strength = (float)state.Wardstone.Ward / Math.Max(1, state.Wardstone.Rules.MaxWard);
        _motes.Clear();
        _camps.Clear();
        var rng = new Random(RunRng.StableSeed(state.Seed, state.Stratum, "ambient-motes"));
        for (int i = 0; i < MoteCount; i++)
            _motes.Add((new Vector2((float)rng.NextDouble(), (float)rng.NextDouble()),
                (float)rng.NextDouble() * Mathf.Tau));
        foreach (var node in state.Map.Nodes)
            if (node.Kind == NodeKind.Rest) _camps.Add(centers[node.Id]);
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        _time += (float)delta;
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_map == null || Size.X <= 0 || Size.Y <= 0) return;
        foreach (var (position, phase) in _motes)
        {
            float life = Mathf.PosMod(_time * 0.055f + phase / Mathf.Tau, 1f);
            float fade = Mathf.Sin(life * Mathf.Pi);
            fade *= fade;
            var p = new Vector2(
                Mathf.PosMod(position.X * Size.X + _time * DriftSpeed + Mathf.Sin(_time * 0.3f + phase) * 7, Size.X),
                Mathf.PosMod(position.Y * Size.Y - life * 30 + Mathf.Sin(_time * 0.2f + phase) * 5, Size.Y));
            float nearWard = 1 - Mathf.Clamp(p.DistanceTo(_light) / FireflyRadius, 0, 1);
            float glimmer = Mathf.Pow(Mathf.Max(0, Mathf.Sin(_time * 1.1f + phase)), 4) * nearWard * _strength;
            DrawCircle(p, 1.1f, _mist with { A = fade * MoteOpacity });
            if (glimmer > 0.03f)
            {
                DrawCircle(p, 5f, _ward with { A = glimmer * 0.045f });
                DrawCircle(p, 1.5f, _ward with { A = glimmer * 0.65f });
            }
        }
        var transform = GetGlobalTransform().AffineInverse() * _map.GetGlobalTransform();
        var ember = UiColors.NodeKindColor(NodeKind.Rest);
        for (int i = 0; i < _camps.Count; i++)
        {
            var hearth = transform * _camps[i] + new Vector2(-22, 33);
            float flicker = 0.65f + Mathf.Sin(_time * 4.3f + i * 2.7f) * 0.12f
                + Mathf.Sin(_time * 7.1f + i) * 0.07f;
            DrawCircle(hearth, 9f, ember with { A = flicker * 0.07f });
            DrawCircle(hearth, 2.5f, ember with { A = flicker * 0.45f });
            for (int j = 0; j < 2; j++)
            {
                float life = Mathf.PosMod(_time * 0.28f + i * 0.37f + j * 0.5f, 1f);
                var p = hearth + new Vector2(Mathf.Sin(life * 5 + i + j) * 3, -life * EmberRise);
                DrawCircle(p, 0.9f, ember with { A = Mathf.Sin(life * Mathf.Pi) * 0.4f });
            }
        }
    }
}
