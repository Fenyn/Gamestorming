using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Equipment;
using Ungilded.Combat;
using Ungilded.Story;
using Ungilded.UI;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>The player stand-in: it advances the story overlays, dismisses rule tips, follows step
/// tips without dismissing them, accepts the reaction prompt and plays each hero turn from the
/// tutorial's restrictions, then takes the rendered captures. Under a step tip every click and
/// command it gives must get through the tip layer: inside the cutout of a dimmed tip, off the box
/// of an undimmed one.</summary>
public partial class PrologueRunSpike
{
    private const string RecallKnowledge = "recall-knowledge";
    private const string TipFolder = "tips";

    private static readonly BombDefinition Flask = AlchemicalItems.AcidFlaskLesser();
    private static readonly string FlaskEntry = $"Throw {Flask.Name}";
    private static readonly string FlaskId = BombActions.IdFor(Flask);

    private readonly HashSet<string> _captured = new();
    private readonly HashSet<TipRecord> _tipsSeen = new();
    private readonly List<string> _ordersOutsideCutout = new();
    private int _ordersUnderStepTips;
    private bool _wrongTileTried;
    private bool _wrongTilePassed;
    private float _cooldown;
    private bool _previewChecked, _previewHeld, _previewOnHover, _previewAfterHover;
    private readonly List<string> _promptsAstray = new();
    private int _promptsChecked;
    private readonly HashSet<string> _menuOnEnemyTurns = new();

    /// <summary>The tip that points at the attack preview while the first Strike aims.</summary>
    private const string PreviewTipId = "e1_05_preview";

    private async Task PlayThrough()
    {
        float report = 0;
        for (float waited = 0; waited < TimeoutSeconds; waited += PollSeconds)
        {
            if (GetTree().CurrentScene is TitleScreen) return;
            await Step();
            await WaitSeconds(PollSeconds);
            if ((report += PollSeconds) >= StatusSeconds)
            {
                report = 0;
                GD.Print($"[PrologueRun] {Status()}");
            }
        }
        Check("the Prologue finished before the timeout", false);
    }

    /// <summary>Seconds between progress lines in the output.</summary>
    [Export] public float StatusSeconds { get; set; } = 10f;

    private string Status()
    {
        var scene = _runner.Scene;
        var session = scene?.Session;
        var actor = session?.CurrentActor;
        return $"E{_runner.CurrentEncounter}/{_runner.CurrentAttempt} round {session?.RoundNumber} actor {actor?.Name} "
            + $"actions {actor?.Actions?.TotalActionsRemaining} playerTurn {scene?.IsPlayerTurn} mode {scene?.Controller?.Mode} "
            + $"busy {scene?.Controller?.Busy} accept {scene?.Controller?.CanAcceptOrders} rule {_director.Popup.IsShowing} "
            + $"step {_director.Popup.Current?.Id} "
            + $"dialogue {_director.Dialogue.IsShowing} narration {_director.Narration.IsWaiting} fade {_director.Fade.IsOpaque} "
            + $"restricted {_runner.Hooks.CommandsRestricted} gold {_runner.Hooks.MoveTiles?.Count} popups {_runner.PopupLog.Count}";
    }

    private async Task Step()
    {
        if (_director.Narration.IsWaiting)
        {
            _director.Narration.Advance();
            return;
        }
        var scene = _runner.Scene;
        var popup = _director.Popup;
        if (popup.IsShowing)
        {
            NoteModal(scene);
            if (popup.Current is { } rule) await CaptureTip(scene, rule);
            popup.Dismiss();
            return;
        }
        if (_director.Dialogue.IsShowing)
        {
            _director.Dialogue.Advance();
            return;
        }
        if (scene?.Session == null) return;
        var actor = scene.Session.CurrentActor;
        if (scene.CommandBar.Visible && (actor is not { TeamId: 1 } || actor.Health?.IsAlive != true
            || scene.Session.CurrentTurnRemoved || scene.ReactionPromptOpen))
            _menuOnEnemyTurns.Add($"E{_runner.CurrentEncounter} {actor?.Name ?? "none"} removed {scene.Session.CurrentTurnRemoved} prompt {scene.ReactionPromptOpen}");
        if (scene.ReactionPromptOpen)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            NotePromptPlacement(scene);
            if (_runner.CurrentEncounter == 1) await Capture("prologue_e1_reactive_strike.png");
            scene.ChooseReaction(true);
            return;
        }
        if (popup.StepShowing && popup.Current is { } step && !_tipsSeen.Contains(step))
        {
            NoteGuidedTurnStart(scene, step.Id);
            await CaptureTip(scene, step);
            return;
        }
        if (!_previewChecked && popup.Current?.Id == PreviewTipId &&scene.Controller?.Mode == PlayerTurnMode.SelectingStrike)
        {
            _previewChecked = true;
            await CheckHeldPreview(scene);
            return;
        }
        if (_cooldown > 0)
        {
            _cooldown -= PollSeconds;
            return;
        }
        // At 0 actions the controller takes no orders, but End Turn still answers.
        if (!scene.IsPlayerTurn || scene.Controller is not { Busy: false } controller) return;
        if (controller.Mode == PlayerTurnMode.Moving)
        {
            // The board with Move chosen: gold tiles alone on a guided move, the blue bands on a free one.
            if (_runner.Hooks.MoveTiles is { Count: > 0 }) await Capture(GuidedMoveShot);
            else if (_freeMoveBegun)
            {
                await Capture(FreeMoveShot);
                controller.Cancel();
                return;
            }
        }
        if (Act(scene, controller)) _cooldown = ActionSettleSeconds;
    }

    private const string GuidedMoveShot = "prologue_move_guided.png";
    private const string FreeMoveShot = "prologue_move_free.png";
    private bool _freeMoveBegun;

    /// <summary>One order, as the restrictions allow it: Move then the gold tile, the allowed skill,
    /// bomb or Strike on the one allowed target, else End Turn. With no restriction the bot ends the turn.</summary>
    private bool Act(CombatScene scene, PlayerTurnController controller)
    {
        var hooks = _runner.Hooks;
        var bar = scene.CommandBar;
        var session = scene.Session!;
        if (!hooks.CommandsRestricted && _runner.CurrentEncounter == 3 && session.RoundNumber >= 3)
            return PlayFreeTurn(scene, controller, session);
        if (!hooks.CommandsRestricted)
        {
            // Once, rendered: open a free move so the bands can be captured, then end the turn.
            if (!Headless && !_freeMoveBegun && bar.IsCommandEnabled("Move"))
            {
                _freeMoveBegun = true;
                controller.BeginMove();
                return true;
            }
            controller.EndTurn();
            return true;
        }
        if (hooks.MoveTiles is { Count: > 0 } gold && bar.IsCommandEnabled("Move"))
        {
            if (controller.Mode != PlayerTurnMode.Moving)
            {
                Press(scene, "Move");
                controller.BeginMove();
                return true;
            }
            var goal = gold.OrderBy(t => t.x).ThenBy(t => t.y).First();
            if (_runner.CurrentEncounter == 1 && !_wrongTileTried)
            {
                _wrongTileTried = true;
                var actor = session.CurrentActor!;
                var wrong = session.PlayerActions.GetReachableTiles(actor).Where(t => !gold.Contains(t))
                    .OrderBy(t => t.x).ThenBy(t => t.y).Cast<PF2eVec?>().FirstOrDefault();
                if (wrong is { } tile)
                {
                    // The undimmed Stride tip lets a click off the gold tiles reach the board, and
                    // the move filter refuses it with the wrong-tile tip.
                    if (scene.TileScreenPoint(tile) is { } point)
                        _wrongTilePassed = _director.Popup.StepShowing && !_director.Popup.CutoutContains(point)
                            && _director.Popup.PassesClick(point);
                    scene.ClickTile(tile);
                    return true;
                }
            }
            Click(scene, goal);
            return true;
        }
        // A target pick comes on the poll after the order is chosen, once the menu has closed.
        if (controller.Mode is PlayerTurnMode.SelectingStrike or PlayerTurnMode.SelectingSkillTarget
            or PlayerTurnMode.SelectingBombTarget)
            return ClickTarget(scene, controller, session);
        if (bar.IsChipEnabled("Recall Knowledge"))
        {
            Press(scene, "Abilities");
            controller.BeginSkill(RecallKnowledge);
            return true;
        }
        if (bar.IsChipEnabled(FlaskEntry))
        {
            Press(scene, "Abilities");
            controller.BeginSkill(FlaskId);
            return true;
        }
        if (bar.IsCommandEnabled("Strike"))
        {
            Press(scene, "Strike");
            controller.BeginStrike();
            return true;
        }
        if (bar.IsCommandEnabled("End Turn"))
        {
            Press(scene, "End Turn");
            controller.EndTurn();
            return true;
        }
        return false;
    }

    private bool ClickTarget(CombatScene scene, PlayerTurnController controller, CombatSession session,
        ICharacter? prefer = null)
    {
        var target = session.Team2.Where(c => c.Health?.IsAlive == true)
            .OrderBy(c => ReferenceEquals(c, prefer) ? 0 : 1)
            .Select(c => (PF2eVec?)c.GridPosition).FirstOrDefault(t => controller.CanStageOrder(t!.Value));
        if (target is not { } tile)
        {
            controller.Cancel();
            return false;
        }
        Click(scene, tile);
        return true;
    }

    /// <summary>A board click, checked against the step tip first.</summary>
    private void Click(CombatScene scene, PF2eVec tile)
    {
        if (_director.Popup.StepShowing && scene.TileScreenPoint(tile) is { } point)
            NoteOrder($"click {tile.x},{tile.y}", point);
        scene.ClickTile(tile);
    }

    /// <summary>A menu press, checked against the step tip. The bot drives the controller directly,
    /// so the press only checks where the entry is.</summary>
    private void Press(CombatScene scene, string command)
    {
        if (!_director.Popup.StepShowing || scene.CommandBar.CommandParts(command).FirstOrDefault() is not { } entry) return;
        NoteOrder(command, entry.GetGlobalRect().GetCenter());
    }

    /// <summary>The order counts when the tip layer lets its click through: inside the cutout of a
    /// dimmed step tip, anywhere off the box of an undimmed one.</summary>
    private void NoteOrder(string order, Vector2 point)
    {
        _ordersUnderStepTips++;
        if (!_director.Popup.PassesClick(point))
            _ordersOutsideCutout.Add($"{_director.Popup.Current?.Id}: {order} at {point}");
    }

    /// <summary>Under the preview tip, once Strike aims: the preview card shows and sits in the
    /// cutout with no hover, while the rat is hovered, and after the hover leaves.</summary>
    private async Task CheckHeldPreview(CombatScene scene)
    {
        var card = scene.CommandBar.Decision.Card;
        await Frames(2);
        _previewHeld = PreviewInCutout(card);
        GD.Print($"[PrologueRun] e1_05 preview:{card.TooltipText.Replace('\n', ' ')}");
        if (scene.Session!.Team2.FirstOrDefault(c => c.Health?.IsAlive == true) is { } rat)
        {
            scene.HoverTile(rat.GridPosition);
            await Frames(2);
            _previewOnHover = PreviewInCutout(card);
            scene.HoverTile(null);
            await Frames(2);
            _previewAfterHover = PreviewInCutout(card);
        }
        await Capture($"{TipFolder}/e1_05_preview_held.png");
    }

    private bool PreviewInCutout(Control card)
        => card.IsVisibleInTree() && _director.Popup.CutoutContains(card.GetGlobalRect().GetCenter());

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    /// <summary>The open reaction prompt sits on screen beside its trigger, off the trigger, within
    /// the placement's reach, and under no tip box.</summary>
    private void NotePromptPlacement(CombatScene scene)
    {
        _promptsChecked++;
        var box = scene.ReactionPromptRect;
        string where = $"E{_runner.CurrentEncounter} box {box}";
        if (scene.ReactionTriggerRect is not { } trigger || !scene.ReactionPromptPointing)
        {
            _promptsAstray.Add($"{where}: docked");
            return;
        }
        float gap = RectGap(box, trigger);
        if (!scene.ReactionPromptOnScreen || box.Intersects(trigger) || gap > scene.ReactionPromptReach)
            _promptsAstray.Add($"{where} trigger {trigger} gap {gap:0}");
        if (scene.ReactionReactorRect is { } reactor && box.Intersects(reactor))
            _promptsAstray.Add($"{where} over the reactor {reactor}");
        if (_director.Popup.Current is { } tip && tip.LastBox.Intersects(box))
            _promptsAstray.Add($"{where} under tip {tip.Id}");
    }

    /// <summary>Pixels between two rects along the axis that separates them; 0 when they touch.</summary>
    private static float RectGap(Rect2 a, Rect2 b)
    {
        float x = Mathf.Max(b.Position.X - a.End.X, a.Position.X - b.End.X);
        float y = Mathf.Max(b.Position.Y - a.End.Y, a.Position.Y - b.End.Y);
        return Mathf.Max(0, Mathf.Max(x, y));
    }

    private void NoteModal(CombatScene? scene)
    {
        if (scene?.Session == null || !scene.HudVisible) return;
        _modalChecked = true;
        if (HudRoot.Find(this)?.ModalActive == true) _modalHeldDuringPopup = true;
    }

    // ---------------------------------------------------------------- Captures

    /// <summary>One capture per tip id under tips/, plus the four named captures.</summary>
    private async Task CaptureTip(CombatScene? scene, TipRecord tip)
    {
        _tipsSeen.Add(tip);
        if (tip.Id.Length == 0) return;
        await Capture($"{TipFolder}/{tip.Id}.png");
        string? named = tip.Id switch
        {
            "e2_08_ac" => "prologue_e2_recall.png",
            "e3_11_crit" => "prologue_e3_flank_crit.png",
            "e4_03_weak" => "prologue_e4_boss.png",
            _ => null,
        };
        if (named != null && scene?.Session != null) await Capture(named, 0f);
    }

    /// <summary>Seconds into the pulse the rendered capture is taken: the row is near the focus colour.</summary>
    [Export] public float PulseCaptureSeconds { get; set; } = 0.2f;

    private async void OnHiddenAbilityPulsed(ICharacter creature)
    {
        _pulses.Add((_runner.CurrentEncounter, creature));
        if (_runner.CurrentEncounter == 3) await Capture("prologue_e3_hidden_pulse.png", PulseCaptureSeconds);
    }

    private async Task Capture(string file, float? settleSeconds = null)
    {
        if (Headless || ShotDirectory.Length == 0 || !_captured.Add(file)) return;
        if (settleSeconds is not 0f) await WaitSeconds(settleSeconds ?? CaptureSettleSeconds);
        // The parked mouse hovers a tile: its frame, path preview and height readout are not part
        // of the shot. The board keeps the cleared hover until the pointer or the camera moves.
        if (_runner.Scene?.Session != null)
        {
            _runner.Scene.HoverTile(null);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        string path = ShotDirectory.PathJoin(file);
        DirAccess.MakeDirRecursiveAbsolute(path.GetBaseDir());
        Check($"{file} saved", SaveViewportCapture(path, ShotSize) == Error.Ok);
    }
}
