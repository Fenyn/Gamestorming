using Bulwark.Autoload;
using Godot;

namespace Bulwark;

/// <summary>
/// Minimal boot node on the main scene. Defers a jump into the outpost so the autoloads (and this
/// scene) finish initializing before the scene swap.
/// </summary>
public partial class BootScene : Node
{
    public override void _Ready()
    {
        Callable.From(() => SceneRouter.Instance.GoToOutpost()).CallDeferred();
    }
}
