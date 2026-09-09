using System;
using System.Threading.Tasks;
using Godot;

namespace Delve.Flow;

/// <summary>A cancellable ward-light journey. Completion authorizes the selected destination.</summary>
public partial class MapTravelLight : Control
{
    [Export] public float TravelSeconds { get; set; } = 0.65f;
    [Export] public float ArrivalSeconds { get; set; } = 0.18f;
    public event Action<Vector2>? LightMoved;
    private TaskCompletionSource<bool>? _completion;
    private Control? _map;
    private Vector2 _from, _to, _position;
    private Color _accent;
    private float _elapsed;
    public bool Traveling => _completion != null;

    public override void _Ready() => VisibilityChanged += () => { if (!IsVisibleInTree()) Cancel(); };
    public override void _ExitTree() => Cancel();

    public Task<bool> Play(Control map, Vector2 from, Vector2 to, Color accent)
    {
        if (Traveling) return Task.FromResult(false);
        _map = map;
        _from = from;
        _to = to;
        _position = from;
        _accent = accent;
        _elapsed = 0;
        _completion = new TaskCompletionSource<bool>();
        QueueRedraw();
        return _completion.Task;
    }

    public void Cancel() => Finish(false);

    private void Finish(bool arrived)
    {
        var completion = _completion;
        _completion = null;
        QueueRedraw();
        completion?.TrySetResult(arrived);
    }

    public override void _Process(double delta)
    {
        if (!Traveling) return;
        _elapsed += (float)delta;
        float t = Mathf.Clamp(_elapsed / TravelSeconds, 0, 1);
        t = t * t * (3 - 2 * t);
        _position = _from.Lerp(_to, t);
        LightMoved?.Invoke(_position);
        QueueRedraw();
        if (_elapsed >= TravelSeconds + ArrivalSeconds) Finish(true);
    }

    public override void _Draw()
    {
        if (!Traveling || _map == null) return;
        var transform = GetGlobalTransform().AffineInverse() * _map.GetGlobalTransform();
        var point = transform * _position;
        DrawLine(transform * _from, point, _accent with { A = 0.22f }, 5, true);
        for (int i = 5; i > 0; i--)
            DrawCircle(point, i * 5f, _accent with { A = 0.035f });
        DrawCircle(point, 4f, _accent.Lerp(Colors.White, 0.7f));
        DrawLine(point + new Vector2(0, -10), point + new Vector2(0, 10), _accent, 1, true);
        if (_elapsed > TravelSeconds)
        {
            float t = (_elapsed - TravelSeconds) / ArrivalSeconds;
            DrawArc(point, 12 + t * 35, 0, Mathf.Tau, 48, _accent with { A = 1 - t }, 2, true);
        }
    }
}
