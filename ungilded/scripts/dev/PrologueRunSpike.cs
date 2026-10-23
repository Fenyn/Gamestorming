using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using Ungilded.Autoload;
using Ungilded.Content;
using Ungilded.Story;
using Ungilded.Tutorial;
using Ungilded.Tutorial.Encounters;
using Ungilded.UI;

namespace Ungilded.Dev;

/// <summary>
/// Plays the whole Prologue from the title: presses Prologue, advances every narration page,
/// dialogue line and popup, and plays each hero turn by following the tutorial's restrictions (the
/// allowed command, the gold tiles, the one allowed target), as a player would. Encounter 4's first
/// attempt is forced to a wipe; the retry runs both heroes on AI with high d20s for the party and
/// low ones for the enemies. Checks every scripted beat of the four encounters, the threshold and
/// victory lines, the Defeat and fresh Prepare, and the return to the title. Rendered, it saves
/// four captures to <see cref="ShotDirectory"/>.
/// </summary>
public partial class PrologueRunSpike : SpikeBase
{
    [Export] public PackedScene? TitleScene { get; set; }
    [Export(PropertyHint.Dir)] public string ShotDirectory { get; set; } = "";
    [Export] public Vector2I ShotSize { get; set; } = new(1600, 900);

    /// <summary>The canvas both modes play on; a headless run sets its window to it.</summary>
    [Export] public Vector2I ViewportSize { get; set; } = new(1920, 1080);
    [Export] public float QuickFadeSeconds { get; set; } = 0.05f;
    [Export] public float TimeoutSeconds { get; set; } = 900f;
    [Export] public float PollSeconds { get; set; } = 0.05f;

    /// <summary>Seconds a rendered capture waits for the board and the popup to settle.</summary>
    [Export] public float CaptureSettleSeconds { get; set; } = 1.2f;

    /// <summary>Seconds the bot waits after an action for the script to update the restrictions.</summary>
    [Export] public float ActionSettleSeconds { get; set; } = 0.3f;

    protected override string Banner => "==================== PROLOGUE RUN SPIKE ====================";

    private PrologueDirector _director = null!;
    private PrologueEncounterRunner _runner = null!;

    private readonly List<(int Encounter, StrikeInfo Strike)> _strikes = new();
    private readonly List<(int Encounter, ICharacter Creature, CreatureKnowledgeField Field)> _reveals = new();
    private readonly List<(int Encounter, ICharacter Unit, Condition Condition)> _conditions = new();
    private readonly List<(int Encounter, ICharacter Unit, int Hp)> _damage = new();
    private readonly Dictionary<int, BattleResult> _results = new();
    private readonly Dictionary<int, string> _logs = new();
    private readonly Dictionary<int, int> _prepares = new();
    private readonly HashSet<string> _linesShown = new();
    private int _boardLines, _boardLinesOverHud;
    private int _fightLines, _fightLinesOverHud;
    private string _firstBossLog = "";
    private bool _pulseWatched;
    private readonly List<(int Encounter, ICharacter Creature)> _pulses = new();
    private bool _friendBleedingAtE3End = true;
    private bool _allRatsDownAtE3End;
    private bool _modalHeldDuringPopup, _modalChecked;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        // The headless display reports a 64x64 window, which the expand stretch turns into a square
        // 1920x1920 canvas: the camera then frames a different board and the HUD sits elsewhere.
        else GetWindow().Size = ViewportSize;
        var viewport = (Vector2I)GetViewport().GetVisibleRect().Size;
        Check($"the viewport is {ViewportSize.X}x{ViewportSize.Y} ({viewport.X}x{viewport.Y})", viewport == ViewportSize);
        if (TitleScene == null) { AbortFail("[PrologueRun] TitleScene not assigned."); return; }

        // The root is still adding the spike scene; the title goes in on the next frame.
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var title = TitleScene.Instantiate<TitleScreen>();
        GetTree().Root.AddChild(title);
        GetTree().CurrentScene = title;
        await WaitSeconds(PollSeconds);
        title.StartPrologue();

        if (!await WaitForDirector()) return;
        WatchStory();
        WatchFx();
        WatchFlaskThrows();
        await PlayThrough();
        CheckBeats();
    }

    private async Task<bool> WaitForDirector()
    {
        for (float waited = 0; waited < 10f; waited += PollSeconds)
        {
            if (GetTree().CurrentScene is PrologueDirector director)
            {
                _director = director;
                break;
            }
            await WaitSeconds(PollSeconds);
        }
        Check("the title's Prologue button loads the Prologue", _director != null);
        if (_director == null) return false;
        _director.BoardRevealSeconds = QuickFadeSeconds;
        _director.BlackoutSeconds = QuickFadeSeconds;
        _director.Narration.FadeSeconds = QuickFadeSeconds;
        _runner = (_director.Runner as PrologueEncounterRunner)!;
        Check("the Prologue runs the encounters through PrologueEncounterRunner", _runner != null);
        return _runner != null;
    }

    private void WatchStory()
    {
        _runner.Prepared += OnPrepared;
        PrologueBeat? current = null;
        _director.Dialogue.LineStarted += line =>
        {
            _linesShown.Add(line.Text);
            if (current?.Kind == BeatKind.Encounter)
            {
                _fightLines++;
                if (_runner.Scene?.HudVisible != false) _fightLinesOverHud++;
                return;
            }
            if (current?.Sequence?.Backdrop != DialogueBackdrop.Board) return;
            _boardLines++;
            if (_runner.Scene?.HudVisible != false) _boardLinesOverHud++;
        };
        _director.BeatStarted += (_, beat) =>
        {
            current = beat;
            SnapshotLogs();
        };
        _director.Finished += SnapshotLogs;
    }

    /// <summary>Keep each won encounter's log before the next encounter clears it.</summary>
    private void SnapshotLogs()
    {
        if (_runner.Scene == null) return;
        foreach (var (index, result) in _results)
            if (result == BattleResult.Team1Wins && !_logs.ContainsKey(index)) _logs[index] = _runner.Scene.LogText;
    }

    // ---------------------------------------------------------------- Observers

    private void OnPrepared(int index)
    {
        int attempt = _prepares[index] = _prepares.GetValueOrDefault(index) + 1;
        var hooks = _runner.Hooks;
        if (!_pulseWatched)
        {
            _pulseWatched = true;
            _runner.Scene!.HiddenAbilityPulsed += OnHiddenAbilityPulsed;
        }
        hooks.AfterStrikeResolved(s =>
        {
            _strikes.Add((index, s));
            if (index == 3) NoteRoundThreeStrike(s);
            return Task.CompletedTask;
        });
        hooks.OnKnowledgeRevealed((c, f) => { _reveals.Add((index, c, f)); return Task.CompletedTask; });
        hooks.OnConditionGained((u, c) => { _conditions.Add((index, u, c)); return Task.CompletedTask; });
        hooks.OnDamageTaken((u, hp) => { _damage.Add((index, u, hp)); return Task.CompletedTask; });
        hooks.OnEncounterFinished(result =>
        {
            _results[index] = result;
            if (index == 3) NoteEncounter3End();
            if (index == 4 && attempt == 1) _firstBossLog = _runner.Scene!.LogText;
            return Task.CompletedTask;
        });
        if (index == 4 && attempt == 1)
        {
            NoteHeroHp(_hpAtE4);
            hooks.OnDamageTaken((u, hp) => { NoteTyrantHp(u, hp); return Task.CompletedTask; });
            hooks.OnTurnStarted(ForceWipe);
        }
        if (index == 4 && attempt == 2)
        {
            _runner.Scene!.SetAllPlayerAi(true);
            hooks.OnTurnStarted(StackDice);
            WatchTyrantTick();
        }
        WatchLateHeals(index);
        WatchAcidTicks();
    }

    private void NoteEncounter3End()
    {
        var friend = _runner.Friend!;
        _friendBleedingAtE3End = friend.Conditions?.HasCondition(Condition.PersistentDamage) == true;
        _allRatsDownAtE3End = _runner.Scene!.Session!.Team2.All(r => r.Health.IsDead);
        NoteHeroHp(_hpAtE3End);
    }

    /// <summary>Encounter 4, first attempt: once the opening steps are done, the first enemy turn
    /// drops both heroes and ends at once.</summary>
    private Task ForceWipe(ICharacter unit)
    {
        if (unit.TeamId == 1) return Task.CompletedTask;
        foreach (var hero in new ICharacter[] { _runner.Player!, _runner.Friend! }) hero.Health.SetCurrentHP(0);
        _runner.Hooks.ScriptEnemyTurn(unit, _runner.Scene!.Session!.RoundNumber, new ScriptedTurn().EndTurn());
        return Task.CompletedTask;
    }

    /// <summary>Encounter 4 retry: the party rolls 19s, the enemies 2s.</summary>
    private Task StackDice(ICharacter unit)
    {
        var hooks = _runner.Hooks;
        hooks.ClearForcedDice();
        hooks.ForceNextD20(Enumerable.Repeat(unit.TeamId == 1 ? 19 : 2, 12).ToArray());
        return Task.CompletedTask;
    }

    // ---------------------------------------------------------------- Checks

    private void CheckBeats()
    {
        Check("the Prologue returned to the title", GetTree().CurrentScene is TitleScreen);
        Check("no story or combat modal is left open", ModalStack.Instance?.Count == 0);
        Check($"each encounter was prepared (E4 twice) ({Prepares()})",
            _prepares.GetValueOrDefault(1) == 1 && _prepares.GetValueOrDefault(2) == 1
            && _prepares.GetValueOrDefault(3) == 1 && _prepares.GetValueOrDefault(4) == 2);
        Check($"the HUD was hidden behind the board lead-in lines ({_boardLines} lines, {_boardLinesOverHud} over the HUD)",
            _boardLines > 0 && _boardLinesOverHud == 0);
        Check($"the HUD hid behind mid-fight lines ({_fightLines} lines, {_fightLinesOverHud} over the HUD)",
            _fightLines > 0 && _fightLinesOverHud == 0);
        Check("a rule tip held the HUD modal", _modalChecked && _modalHeldDuringPopup);
        CheckTips();
        CheckEncounter1();
        CheckEncounter2();
        CheckEncounter3();
        CheckEncounter4();
        CheckTyrantTick();
        CheckPacing();
        StopWatchingFx();
        StopWatchingFlaskThrows();
        CheckAcidSplashes();
        CheckFlaskThrows();
        CheckTreatWounds();
        CheckDeathDust();
    }

    /// <summary>Every focused tip cut out something on screen and kept its box on screen and off the
    /// cutout; the move tips and the first Strike tip showed no dim; every step tip closed; every
    /// order under a step tip got through the tip layer; every reaction prompt sat by its trigger.</summary>
    private void CheckTips()
    {
        var tips = _director.Popup.Records;
        foreach (var tip in tips)
            GD.Print($"[PrologueRun] tip {tip.Id,-22} {(tip.Step ? "step" : "rule")} focused {tip.Focused} dimmed {tip.Dimmed} frames {tip.FramesShown} "
                + $"resolved {tip.FramesResolved} unresolved {tip.FramesUnresolved} offscreen {tip.FramesOffScreen} "
                + $"overlap {tip.FramesOverlap} panel {tip.FramesPanelOverlap}/{tip.MostPanelOverlap:0}px² closed {tip.Closed} "
                + $"cutout {tip.LastCutout} box {tip.LastBox}");
        var focused = tips.Where(t => t.Focused && t.FramesShown > 0).ToArray();
        Check($"tips opened ({tips.Count}, {focused.Length} focused)", focused.Length > 20);
        CheckWith("every focused tip resolved a cutout inside the viewport",
            focused.All(Resolved), Names(focused.Where(t => !Resolved(t))));
        CheckWith("every focused tip kept its box on screen",
            focused.All(t => t.FramesOffScreen == 0), Names(focused.Where(t => t.FramesOffScreen > 0)));
        CheckWith("no tip box covered its cutout",
            focused.All(t => t.FramesOverlap == 0), Names(focused.Where(t => t.FramesOverlap > 0)));
        var e1 = tips.Select(t => t.Id).Where(id => id.StartsWith("e1_") || id == PrologueEncounterRunner.WrongTileTip).ToArray();
        string[] e1Expected = { "e1_01_actions", "e1_02_move", PrologueEncounterRunner.WrongTileTip, "e1_04_strike",
            "e1_05_preview", "e1_06_map", "e1_07_end_turn", "e1_08_flee", "e1_08_reaction" };
        Check($"E1 tips run in order, one tip for the whole Stride ({string.Join(", ", e1)})", e1.SequenceEqual(e1Expected));
        Check("E1: the Stride tip lets a click on a tile off the gold set through to the board, and the wrong-tile tip shows",
            _wrongTilePassed && e1.Contains(PrologueEncounterRunner.WrongTileTip));
        var undimmed = UndimmedTips.Where(id => tips.Any(t => t.Id == id)).ToArray();
        var dimWrong = tips.Where(t => UndimmedTips.Contains(t.Id) == t.Dimmed).ToArray();
        CheckWith($"the move tips and the first Strike and preview tips show no dim, every other tip keeps it ({undimmed.Length} of {UndimmedTips.Length} seen)",
            undimmed.Length == UndimmedTips.Length && dimWrong.Length == 0, Names(dimWrong));
        Check($"E1: the preview tip's cutout holds the attack preview once Strike aims (held {_previewHeld}, "
            + $"on hover {_previewOnHover}, after hover {_previewAfterHover})", _previewHeld && _previewOnHover && _previewAfterHover);
        CheckWith($"every reaction prompt sat on screen beside its trigger ({_promptsChecked} prompts)",
            _promptsChecked > 0 && _promptsAstray.Count == 0, string.Join("; ", _promptsAstray));
        CheckWith("the command menu stayed hidden on enemy turns, a reaction kill included",
            _menuOnEnemyTurns.Count == 0, string.Join(", ", _menuOnEnemyTurns));
        var onPanels = tips.Where(t => t.FramesPanelOverlap > 0).ToArray();
        CheckWith("no tip box covered a HUD panel (unit cards, timeline, command menu)", onPanels.Length == 0,
            string.Join(", ", onPanels.Select(t => $"{t.Id} {t.MostPanelOverlap:0}px²")));
        CheckWith("every step tip closed after its step",
            tips.Where(t => t.Step).All(t => t.Closed), Names(tips.Where(t => t.Step && !t.Closed)));
        CheckWith($"every order under a step tip got through the tip layer ({_ordersUnderStepTips} orders)",
            _ordersUnderStepTips > 0 && _ordersOutsideCutout.Count == 0, string.Join("; ", _ordersOutsideCutout));
    }

    /// <summary>The step tips that outline their focus with no dim: every Stride, the first Strike
    /// and its preview tip.</summary>
    private static readonly string[] UndimmedTips =
    {
        "e1_02_move", PrologueEncounterRunner.WrongTileTip, "e1_04_strike", "e1_05_preview", "e2_03_move", "e3_02_move", "e3_07_flank",
        "e3_16_flank", "e3_20_free", "e3_24_free",
    };

    /// <summary>The cutout showed, and went empty for no longer than the layout's settle frames
    /// (the frame a menu closes before the tip moves to the board).</summary>
    private bool Resolved(Story.TipRecord tip)
        => tip.FramesResolved > 0 && tip.FramesUnresolved <= _director.Popup.SettleFrames;

    private void CheckWith(string label, bool ok, string failures)
        => Check(ok || failures.Length == 0 ? label : $"{label} ({failures})", ok);

    private static string Names(IEnumerable<Story.TipRecord> tips) => string.Join(", ", tips.Select(t => t.Id).Distinct());

    private string Prepares() => string.Join(", ", _prepares.OrderBy(p => p.Key).Select(p => $"E{p.Key} x{p.Value}"));

    private IEnumerable<StrikeInfo> Strikes(int encounter) => _strikes.Where(s => s.Encounter == encounter).Select(s => s.Strike);

    private static string Describe(IEnumerable<StrikeInfo> strikes)
        => string.Join("; ", strikes.Select(s => $"{s.Attacker.Name}>{s.Target.Name} d20 {s.D20} {s.Degree} {s.Damage}{(s.Killed ? " kill" : "")}{(s.IsReaction ? " R" : "")}"));

    private void CheckEncounter1()
    {
        var strikes = Strikes(1).Where(s => s.Attacker == _runner.Player).ToArray();
        GD.Print($"[PrologueRun] E1 strikes: {Describe(Strikes(1))}");
        Check("E1: Strike hits, Strike misses, Reactive Strike kills the fleeing rat",
            strikes.Length == 3
            && !strikes[0].IsReaction && strikes[0].Degree == DegreeOfSuccess.Success && strikes[0].Damage == 8
            && !strikes[1].IsReaction && strikes[1].Degree == DegreeOfSuccess.Failure
            && strikes[2].IsReaction && strikes[2].Degree == DegreeOfSuccess.Success && strikes[2].Killed);
        Check("E1: the flee popup played before the Reactive Strike prompt", _runner.PopupLog.Contains(Encounter1Script.FleePopup));
        int flee = _runner.PopupLog.IndexOf(Encounter1Script.FleeEvent);
        Check("E1: the flee event played just before the flee popup",
            flee >= 0 && flee + 1 < _runner.PopupLog.Count && _runner.PopupLog[flee + 1] == Encounter1Script.FleePopup);
        string strikeTip = Encounter1Script.StrikeTip(_runner.Player!);
        Check($"E1: the Strike tip names the Player's attack bonus ({strikeTip})", _runner.PopupLog.Contains(strikeTip));
        Check("E1: a wrong tile repeated the gold-tile instruction", _runner.PopupLog.Contains(Encounter1Script.WrongTile));
        Check("E1: the Friend held back", Log(1).Contains(Encounter1Script.FriendHoldsBack));
        Check("E1: won", _results.GetValueOrDefault(1) == BattleResult.Team1Wins);
    }

    private void CheckEncounter2()
    {
        var fields = _reveals.Where(r => r.Encounter == 2).Select(r => r.Field).ToArray();
        Check($"E2: Recall Knowledge revealed Abilities, then AC ({string.Join(", ", fields)})",
            fields.SequenceEqual(new[] { CreatureKnowledgeField.Strikes, CreatureKnowledgeField.AC }));
        GD.Print($"[PrologueRun] E2 strikes: {Describe(Strikes(2))}");
        var bite = Strikes(2).FirstOrDefault(s => s.Target == _runner.Player);
        int maxHp = _runner.Player!.Health.MaxHP;
        Check($"E2: the rat's bite took about a quarter of the Player's HP ({bite?.Damage} of {maxHp})",
            bite != null && bite.Degree == DegreeOfSuccess.Success && Math.Abs(bite.Damage - maxHp / 4f) <= 1.5f);
        var heal = Regex.Match(Log(2), @"The Player HP (\d+) → (\d+)");
        Check($"E2: Treat Wounds healed the Player ({heal.Value})",
            heal.Success && int.Parse(heal.Groups[2].Value) > int.Parse(heal.Groups[1].Value)
            && Regex.IsMatch(Log(2), @"SUCCESS\s+Medicine: \d+\s*\+\s*\d+ = \d+ vs DC 15"));
        Check("E2: won", _results.GetValueOrDefault(2) == BattleResult.Team1Wins);
        GD.Print($"[PrologueRun] E2 log tail:\n{Tail(Log(2), 8)}");
    }

    private void CheckEncounter3()
    {
        var strikes = Strikes(3).ToArray();
        GD.Print($"[PrologueRun] E3 strikes: {Describe(strikes)}");
        var player = _runner.Player!;
        var friend = _runner.Friend!;
        Check("E3: the Player critically hit the flanked front rat",
            strikes.Any(s => s.Attacker == player && s.Degree == DegreeOfSuccess.CriticalSuccess && s.Killed));
        Check("E3: the Player critically missed at -5 MAP",
            strikes.Any(s => s.Attacker == player && s.Degree == DegreeOfSuccess.CriticalFailure));
        Check("E3: the Friend's dagger dealt Sneak Attack damage twice (above the d4)",
            strikes.Count(s => s.Attacker == friend && s.Degree == DegreeOfSuccess.Success && s.Damage > 4) >= 2);
        int flask = _runner.PopupLog.IndexOf(Encounter3Script.FlaskTip(AlchemicalItems.AcidFlaskLesser()));
        string splashTip = flask >= 0 && flask + 1 < _runner.PopupLog.Count ? _runner.PopupLog[flask + 1] : "";
        Check($"E3: the splash tip followed the first flask tip ({splashTip})",
            Regex.IsMatch(splashTip, @"^The flask hit .+ for \d+ acid damage and splashed .+ for \d+\.$"));
        Check("E3: two acid flasks hit Rat 3, direct and splash", Regex.Matches(Log(3), @"acid damage: direct 1, splash 1").Count >= 2);
        Check("E3: each splash reached the rat beside the target", Regex.Matches(Log(3), @"takes 1 acid damage: splash 1\.").Count >= 2);
        Check("E3: the Friend gained persistent bleed",
            _conditions.Any(c => c.Encounter == 3 && c.Unit == friend && c.Condition == Condition.PersistentDamage));
        Check("E3: the bleed ticked and the recovery check ended it", !_friendBleedingAtE3End);
        var pulses = _pulses.Where(p => p.Encounter == 3).ToArray();
        Check($"E3: Vicious Bite pulsed the biting rat's Abilities row once ({pulses.Length})",
            pulses.Length == 1 && pulses[0].Creature.CreatureStats?.CreatureId == PrologueBestiary.ViciousSewerRatId);
        Check("E3: the log never names Vicious Bite", !Log(3).Contains("Vicious", StringComparison.OrdinalIgnoreCase));
        var bleed = new[] { @"The Friend  Persistent bleed 1d4", @"The Friend  Bleed 2  HP \d+ → \d+", @"The Friend  Recovery \d+ vs 15  Bleed ends" }
            .Select(p => Regex.Match(Log(3), $@"[^\n]*{p}[^\n]*")).ToArray();
        GD.Print($"[PrologueRun] E3 bleed rows:\n{string.Join("\n", bleed.Select(m => m.Value))}");
        Check("E3: the log shows the bleed gained, its tick and its recovery", bleed.All(m => m.Success));
        Check("E3: all five rats are down", _allRatsDownAtE3End);
        Check("E3: won", _results.GetValueOrDefault(3) == BattleResult.Team1Wins);
    }

    private void CheckEncounter4()
    {
        var fields = _reveals.Where(r => r.Encounter == 4).Select(r => r.Field).ToArray();
        Check($"E4: the critical Recall Knowledge revealed AC and Weakness ({string.Join(", ", fields)})",
            fields.Take(2).SequenceEqual(new[] { CreatureKnowledgeField.AC, CreatureKnowledgeField.Weaknesses }));
        Check("E4: the wipe showed the post-mortem popup", _runner.PopupLog.Contains(Encounter4Script.PostMortem));
        Check("E4: the weakness popup played", _runner.PopupLog.Contains(Encounter4Script.WeaknessPopup));
        var flask = Regex.Match(_firstBossLog,
            $@"Sewer Tyrant( [A-Z])? takes \d+ acid damage: [^\n]*weakness {PrologueBestiary.TyrantAcidWeakness}");
        Check($"E4: the flask's log line shows the weakness ({flask.Value})", flask.Success);
        if (!flask.Success) GD.Print($"[PrologueRun] E4 first attempt log:\n{Tail(_firstBossLog, 30)}");
        Check("E4: the threshold log lines fired", Log(4).Contains(Encounter4Script.HalfLog) && Log(4).Contains(Encounter4Script.QuarterLog));
        foreach (var sequence in new[] { _runner.HalfHpLines, _runner.QuarterHpLines, _runner.VictoryLines, _runner.ClosingLines })
            Check($"E4: {sequence?.Id} played", sequence != null && sequence.Lines.All(l => _linesShown.Contains(l.Text)));
        Check("E4: won on the retry", _results.GetValueOrDefault(4) == BattleResult.Team1Wins);
    }

    private string Log(int encounter) => _logs.GetValueOrDefault(encounter, "");

    private static string Tail(string text, int lines) => string.Join("\n", text.Split('\n').TakeLast(lines));
}
