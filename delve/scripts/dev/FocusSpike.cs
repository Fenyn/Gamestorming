using System;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.Run.Events;
using Godot;

namespace Delve.Dev;

/// <summary>Opens each keyboard-driven screen and checks that focus lands on a visible, enabled
/// button inside it, so Enter and the arrow keys work without a mouse click first.</summary>
public partial class FocusSpike : SpikeBase
{
    [Export] public PackedScene EventScene { get; set; } = null!;
    [Export] public PackedScene ShortRestScene { get; set; } = null!;
    [Export] public PackedScene MeetupScene { get; set; } = null!;
    [Export] public PackedScene RunEndScene { get; set; } = null!;
    [Export] public PackedScene PromotionScene { get; set; } = null!;
    [Export] public Theme UiTheme { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId,
            PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
        var state = RunState.Start(2718, party, new RunMapConfig());

        await Expect<EventPanel>(EventScene, panel => panel.Show(EventCatalog.CollapsedPassage, state));
        await Expect<ShortRestPanel>(ShortRestScene, panel => panel.Show(state));
        await Expect<MeetupPanel>(MeetupScene, panel => panel.Show(party, PresetCharacters.BuildRaven(party.Level)));
        state.Outcome = RunOutcome.Defeat;
        await Expect<RunEndPanel>(RunEndScene, panel => panel.Show(state, true));
        PartyLeveling.Award(state, state.Leveling.XpPerLevel);
        await Expect<PromotionPanel>(PromotionScene, panel => panel.ShowCharacter(party.Members[0]));
    }

    private async Task Expect<T>(PackedScene scene, Action<T> open) where T : Control
    {
        var layer = new CanvasLayer();
        AddChild(layer);
        var surface = new Control { Theme = UiTheme };
        surface.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        layer.AddChild(surface);
        var panel = scene.Instantiate<T>();
        surface.AddChild(panel);
        open(panel);
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var owner = GetViewport().GuiGetFocusOwner();
        bool ok = owner is BaseButton { Disabled: false } button && button.IsVisibleInTree() && panel.IsAncestorOf(button);
        Check($"{typeof(T).Name} opens with focus on a visible, enabled button inside it ({Describe(owner)})", ok);
        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private static string Describe(Control? owner) => owner switch
    {
        null => "no focus owner",
        Button button => $"{button.Name} '{button.Text.Split('\n')[0]}'",
        _ => owner.Name,
    };
}
