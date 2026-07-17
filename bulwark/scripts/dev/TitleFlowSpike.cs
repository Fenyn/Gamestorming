using System;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Intro;
using Bulwark.UI;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless integration proof of the PRODUCTION front-end flow through the REAL SceneRouter wiring
/// (the deferred title/name-entry hookups added alongside StartNewGame's reset):
///  (1) No save → GoToTitleScreen: title is current, the deferred hookup fired, Continue is HIDDEN.
///  (2) New Game button → router routes to the name-entry screen (proves the title hookup landed
///      AFTER the scene swap — the load-bearing deferred-ordering check).
///  (3) Confirm name → router calls StartNewGame(name) and routes to the intro road scene, on a
///      CLEAN flag state (intro_complete clear so the intro actually plays), clock paused.
///  (4) With a save present → GoToTitleScreen shows Continue; Continue button → ContinueGame +
///      GoToOutpost lands on the outpost.
/// Uses the autoload SceneRouter/GameState; the user's slot0.json is backed up and restored, and the
/// slot is toggled to drive both the no-save and has-save branches. The spike scene is the initial
/// scene; since the first transition frees it, a driver copy re-homes under /root to survive swaps.
/// </summary>
public partial class TitleFlowSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string BackupPath = "user://save/slot0.json.bak";

    private bool _isDriver;
    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        if (_isDriver)
        {
            _ = RunAsync();
            return;
        }

        // This node is the initial CurrentScene and the first SceneRouter transition frees it.
        // Re-launch as a plain /root child that survives every scene swap the flow drives.
        var driver = new TitleFlowSpike { _isDriver = true, Name = "TitleFlowDriver" };
        GetTree().Root.CallDeferred(Node.MethodName.AddChild, driver);
    }

    private async Task RunAsync()
    {
        GD.Print("==================== TITLE FLOW SPIKE ====================");

        var gs = GameState.Instance;
        var router = SceneRouter.Instance;
        if (gs == null || router == null)
        {
            AbortFail("[TitleFlowSpike] GameState / SceneRouter autoload missing — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            await RunScenario(gs, router);
        }
        catch (Exception e)
        {
            GD.PushError($"[TitleFlowSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("TitleFlowSpike");
    }

    private async Task RunScenario(GameState gs, SceneRouter router)
    {
        var tree = GetTree();

        // ── (1) No save → title, Continue hidden ──
        GD.Print("-------------------- (1) Boot -> title (no save) --------------------");
        ClearSlot();
        router.GoToTitleScreen();
        Check("(1) GoToTitleScreen → current scene is the title screen",
            await WaitUntil(() => tree.CurrentScene is TitleScreen, 10));
        var title = tree.CurrentScene as TitleScreen;
        Check("(1) day clock paused on the title screen", gs.Clock.IsPaused);
        Check("(1) Continue hidden when no save exists",
            title != null && title.GetNode<Button>("%ContinueButton").Visible == false);

        // ── (2) New Game → name entry (proves the deferred title hookup fired) ──
        GD.Print("-------------------- (2) New Game -> name entry --------------------");
        title!.GetNode<Button>("%NewGameButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(2) New Game routed to the name-entry screen",
            await WaitUntil(() => tree.CurrentScene is NameEntryScreen, 10));

        // ── (3) Confirm name → StartNewGame + intro on a clean flag state ──
        GD.Print("-------------------- (3) Confirm name -> intro --------------------");
        var entry = tree.CurrentScene as NameEntryScreen;
        entry!.GetNode<LineEdit>("%NameInput").Text = "Hero";
        entry.GetNode<Button>("%ConfirmButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(3) confirm routed to the intro road scene",
            await WaitUntil(() => tree.CurrentScene is RoadScene, 10));
        Check("(3) StartNewGame applied the chosen name", gs.PlayerName == "Hero");
        Check("(3) intro flags are clear (the intro will actually play)",
            !gs.HasStoryFlag("intro_complete") && !gs.HasStoryFlag("intro_scene_0"));
        Check("(3) clock paused for the intro", gs.Clock.IsPaused);
        Check("(3) new game starts on Day 1", gs.Clock.Day == 1);

        // ── (4) Has save (intro finished) → title shows Continue → outpost ──
        GD.Print("-------------------- (4) Continue -> outpost --------------------");
        // Mark the intro complete so this is a normal post-intro save: Continue's resume router
        // (SceneRouter.ResumeRoute) sends a finished-intro save to the outpost. A save still mid-intro
        // resumes to the road instead — covered headless by intro_spike section (I). SetStoryFlag also
        // persists the save, so SaveExists() is true below.
        gs.SetStoryFlag("intro_complete");
        Check("(4) precondition: a save now exists", gs.SaveExists());

        router.GoToTitleScreen();
        Check("(4) back at the title screen",
            await WaitUntil(() => tree.CurrentScene is TitleScreen, 10));
        title = tree.CurrentScene as TitleScreen;
        Check("(4) Continue visible when a save exists",
            title != null && title.GetNode<Button>("%ContinueButton").Visible);

        title!.GetNode<Button>("%ContinueButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(4) Continue routed to the outpost",
            await WaitUntil(() => tree.CurrentScene is OutpostScene, 10));
        Check("(4) day clock unpaused at the outpost", !gs.Clock.IsPaused);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private async Task<bool> WaitUntil(Func<bool> condition, double timeoutSeconds)
    {
        ulong deadline = Time.GetTicksMsec() + (ulong)(timeoutSeconds * 1000.0);
        while (!condition())
        {
            if (Time.GetTicksMsec() >= deadline)
                return condition();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        return true;
    }

    // ─────────────────────────── Save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;
        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read);
        _slot0Backup = file?.GetAsText();
    }

    private static void ClearSlot()
    {
        foreach (var path in new[] { SavePath, BackupPath })
            if (Godot.FileAccess.FileExists(path))
                DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(path));
    }

    private void RestoreSlot0()
    {
        ClearSlot();
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
        }
    }
}
