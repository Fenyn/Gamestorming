using System.Threading;
using System.Threading.Tasks;
using Godot;

namespace Delve.Combat;

/// <summary>A delay on a scene timer that stops while the tree is paused, so the pause menu freezes
/// combat pacing at once. The token still cancels it on scene exit.</summary>
internal static class PausableDelay
{
    internal static Task Wait(SceneTree? tree, float seconds, CancellationToken token)
    {
        if (seconds <= 0) return Task.CompletedTask;
        if (token.IsCancellationRequested) return Task.FromCanceled(token);
        if (tree == null) return Task.Delay(System.TimeSpan.FromSeconds(seconds), token);
        var done = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var timer = tree.CreateTimer(seconds, processAlways: false);
        var registration = token.Register(() => done.TrySetCanceled(token));
        timer.Timeout += () =>
        {
            registration.Dispose();
            done.TrySetResult();
        };
        return done.Task;
    }
}
