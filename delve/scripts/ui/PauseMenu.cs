using System.Linq;
using Delve.Autoload;
using Delve.Settings;
using Godot;

namespace Delve.UI;

/// <summary>
/// Esc menu for exploration and combat: Resume, Controls, Options and Quit. Autoloaded, so it
/// receives Esc only after every scene node has passed on it: a flyout, a targeting cancel, a
/// modal or a tooltip always closes first. Pauses the tree while open and holds the modal stack.
/// </summary>
public partial class PauseMenu : CanvasLayer
{
    /// <summary>Nodes in this group mark a screen where Esc may pause (dungeon HUD, combat HUD).</summary>
    public const string HostGroup = "pause_host";

    public static PauseMenu? Instance { get; private set; }

    [Export] public string SettingsPath { get; set; } = "";

    private Control _main = null!, _controls = null!, _options = null!, _quitConfirm = null!;
    private Button _resume = null!, _fullscreen = null!, _dice = null!;

    public bool IsOpen => Visible;

    public override void _EnterTree() => Instance = this;

    public override void _ExitTree()
    {
        if (!Visible) return;
        GetTree().Paused = false;
        ModalStack.Instance?.Pop(this);
    }

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        _main = GetNode<Control>("%MainPage");
        _controls = GetNode<Control>("%ControlsPage");
        _options = GetNode<Control>("%OptionsPage");
        _quitConfirm = GetNode<Control>("%QuitPage");
        _resume = GetNode<Button>("%Resume");
        _fullscreen = GetNode<Button>("%Fullscreen");
        _dice = GetNode<Button>("%DiceReveal");
        _resume.Pressed += Close;
        GetNode<Button>("%Controls").Pressed += () => ShowPage(_controls, GetNode<Button>("%ControlsBack"));
        GetNode<Button>("%Options").Pressed += () => ShowPage(_options, _fullscreen);
        GetNode<Button>("%Quit").Pressed += () => ShowPage(_quitConfirm, GetNode<Button>("%QuitCancel"));
        GetNode<Button>("%ControlsBack").Pressed += Back;
        GetNode<Button>("%OptionsBack").Pressed += Back;
        GetNode<Button>("%QuitCancel").Pressed += Back;
        GetNode<Button>("%QuitConfirm").Pressed += () => GetTree().Quit();
        _fullscreen.Toggled += on => { UserSettings.Fullscreen = on; UserSettings.Save(); };
        _dice.Toggled += on => { UserSettings.DiceReveal = on; UserSettings.Save(); };
        UserSettings.Changed += ApplyWindowMode;
        if (SettingsPath.Length > 0) UserSettings.Load(SettingsPath);
        ApplyWindowMode();
        Hide();
    }

    private static void ApplyWindowMode()
    {
        if (DisplayServer.GetName() == "headless") return;
        var want = UserSettings.Fullscreen ? DisplayServer.WindowMode.Fullscreen : DisplayServer.WindowMode.Windowed;
        bool full = DisplayServer.WindowGetMode() is DisplayServer.WindowMode.Fullscreen or DisplayServer.WindowMode.ExclusiveFullscreen;
        if (full != UserSettings.Fullscreen) DisplayServer.WindowSetMode(want);
    }

    /// <summary>True when a pause host is showing and no other modal holds the screen.</summary>
    public bool CanOpen()
        => !Visible && !GetTree().Paused && ModalStack.Instance?.IsOpenFor(this) != true
           && GetTree().GetNodesInGroup(HostGroup).Any(Shown);

    public void Open()
    {
        if (Visible) return;
        _fullscreen.SetPressedNoSignal(UserSettings.Fullscreen);
        _dice.SetPressedNoSignal(UserSettings.DiceReveal);
        ModalStack.Instance?.Push(this);
        GetTree().Paused = true;
        Show();
        ShowPage(_main, _resume);
    }

    public void Close()
    {
        if (!Visible) return;
        Hide();
        GetTree().Paused = false;
        ModalStack.Instance?.Pop(this);
    }

    private void ShowPage(Control page, Control focus)
    {
        foreach (var each in new[] { _main, _controls, _options, _quitConfirm }) each.Visible = each == page;
        UiFocus.Grab(focus);
    }

    private void Back()
    {
        var from = _options.Visible ? GetNode<Button>("%Options")
            : _controls.Visible ? GetNode<Button>("%Controls") : GetNode<Button>("%Quit");
        ShowPage(_main, from);
    }

    public override void _Input(InputEvent e)
    {
        if (!Visible || !e.IsActionPressed(InputNames.UiCancel)) return;
        if (_main.Visible) Close();
        else Back();
        GetViewport().SetInputAsHandled();
    }

    public override void _UnhandledInput(InputEvent e)
    {
        if (!e.IsActionPressed(InputNames.UiCancel) || !CanOpen()) return;
        Open();
        GetViewport().SetInputAsHandled();
    }

    /// <summary>Visible through every ancestor, canvas layers and 3D parents included.</summary>
    private static bool Shown(Node node)
    {
        for (Node? n = node; n != null; n = n.GetParent())
        {
            if (n is CanvasItem { Visible: false } or CanvasLayer { Visible: false } or Node3D { Visible: false }) return false;
            if (n.ProcessMode == ProcessModeEnum.Disabled) return false;
        }
        return node.IsInsideTree();
    }
}
