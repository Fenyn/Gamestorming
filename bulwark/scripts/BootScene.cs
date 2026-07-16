using Bulwark.Autoload;
using Bulwark.Cozy;
using Godot;

namespace Bulwark;

/// <summary>
/// Minimal boot node on the main scene. Applies the persisted view/audio settings, then defers a
/// jump into the title screen so the autoloads (and this scene) finish initializing before the
/// scene swap.
/// </summary>
public partial class BootScene : Node
{
    public override void _Ready()
    {
        SettingsApplier.ApplyAll();
        Callable.From(() => SceneRouter.Instance.GoToTitleScreen()).CallDeferred();
    }
}
