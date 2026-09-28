using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>Rendered guest-sheet and replacement-button layout check.</summary>
public partial class MeetupShotSpike : SpikeBase
{
    [Export] public PackedScene? PanelScene { get; set; }
    [Export] public string OutputPath { get; set; } = "";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        string captureDirectory = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        string outputPath = string.IsNullOrWhiteSpace(captureDirectory) ? OutputPath : captureDirectory.PathJoin("meetup.png");
        if (PanelScene == null) { AbortFail("Meetup panel scene is missing."); return; }
        var layer = new CanvasLayer();
        AddChild(layer);
        var panel = PanelScene.Instantiate<MeetupPanel>();
        layer.AddChild(panel);
        var party = Party.Build(PresetCharacters.PlayerId,
            new[] { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
        var guest = PresetCharacters.BuildRaven(party.Level);
        guest.Health!.SetCurrentHP(7);
        panel.Show(party, guest);
        for (int i = 0; i < 5; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var bounds = panel.GetGlobalRect();
        foreach (string name in new[] { "%GuestSheet", "%Summary", "%SlotOne", "%SlotTwo", "%SlotThree", "%SlotFour", "%DeclineButton" })
            Check($"{name} fits within screen", bounds.Encloses(panel.GetNode<Control>(name).GetGlobalRect()));
        string? outgoing = null;
        int declined = 0;
        panel.CompanionPicked += id => outgoing = id;
        panel.Declined += () => declined++;
        panel.GetNode<Button>("%SlotOne").EmitSignal(BaseButton.SignalName.Pressed);
        panel.GetNode<Button>("%DeclineButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("slot button names first party member", outgoing == PresetCharacters.PlayerId);
        panel.GetNode<Button>("%SlotFour").EmitSignal(BaseButton.SignalName.Pressed);
        Check("fourth member can also be replaced", outgoing == PresetCharacters.FenwickId);
        Check("decline emits once without party mutation", declined == 1 && party.Find(PresetCharacters.ElaraId) != null);
        if (DisplayServer.GetName() == "headless" || string.IsNullOrWhiteSpace(outputPath)) return;
        Check("meetup screenshot saved", SaveViewportCapture(outputPath) == Error.Ok);
    }
}
