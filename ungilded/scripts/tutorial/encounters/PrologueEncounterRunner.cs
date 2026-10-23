using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Equipment;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Knowledge;
using Ungilded.Story;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// The Prologue's <see cref="IEncounterRunner"/>: one <see cref="CombatScene"/> for all four
/// encounters, the two heroes kept across them, one creature journal, and an
/// <see cref="EncounterScript"/> per encounter. <see cref="Prepare"/> builds the board with the HUD
/// hidden and holds the first turn; <see cref="Run"/> shows the HUD and plays the script;
/// <see cref="Release"/> tears the fight down. HP carries from fight to fight; the Friend's flasks
/// go back to two each fight. Each script sets whether a hero's turn ends at 0 actions. While the story box
/// or a rule tip shows, the HUD takes no input; a step tip leaves it live. Each Prepare and each
/// accessory cue lights the hero tokens' glow from the dialogue box's <see cref="Wardrobe"/>.
/// </summary>
public partial class PrologueEncounterRunner : Node, IEncounterRunner
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export] public DialogueSequence? FriendStrikeLines { get; set; }
    [Export] public DialogueSequence? HalfHpLines { get; set; }
    [Export] public DialogueSequence? QuarterHpLines { get; set; }
    [Export] public DialogueSequence? VictoryLines { get; set; }
    [Export] public DialogueSequence? ClosingLines { get; set; }

    /// <summary>Seconds Prepare waits for the first turn before it reports an error.</summary>
    [Export] public float FirstTurnTimeoutSeconds { get; set; } = 30f;

    /// <summary>Fires after each Prepare, once the first turn is held.</summary>
    public event Action<int>? Prepared;

    public TutorialHooks Hooks { get; } = new();
    public MonsterJournal Journal { get; private set; } = new();
    public CombatScene? Scene { get; private set; }
    public PF2eCharacter? Player { get; private set; }
    public PF2eCharacter? Friend { get; private set; }

    /// <summary>Plain text of every tutorial popup the runner showed, in order.</summary>
    public List<string> PopupLog { get; } = new();

    /// <summary>The prepared encounter (1 to 4), or 0 between encounters.</summary>
    public int CurrentEncounter => _stage?.Index ?? 0;

    /// <summary>How many times the prepared encounter has been prepared, retries included.</summary>
    public int CurrentAttempt => _stage?.Attempt ?? 0;

    private TutorialPopup _popup = null!;
    private DialogueBox _dialogue = null!;
    private EncounterStage? _stage;
    private EncounterScript? _script;
    private readonly Dictionary<int, int> _attempts = new();
    private bool _refusalShowing;

    /// <summary>True between Run and Release, when the fight's HUD is meant to show.</summary>
    private bool _fightHudShown;

    public override void _Ready()
    {
        _popup = GetNode<TutorialPopup>("%Popup");
        _dialogue = GetNode<DialogueBox>("%Dialogue");
        _popup.ShowingChanged += _ => SyncStoryModal();
        _popup.AnyTipChanged += showing => { if (Scene != null) Scene.TutorialTipShowing = showing; };
        _dialogue.ShowingChanged += _ => SyncStoryModal();
        _dialogue.WardrobeChanged += ShowWardrobe;
        Hooks.MoveRefused += _ => ShowRefusal();
    }

    public override void _ExitTree() => _stage?.Cancel();

    // ---------------------------------------------------------------- IEncounterRunner

    public async Task Prepare(int index)
    {
        var scene = EnsureScene();
        int attempt = _attempts[index] = _attempts.GetValueOrDefault(index) + 1;
        PrepareHeroes();

        var battle = PrologueMaps.Encounter(index);
        var enemies = battle.CreateEnemies();
        _script = CreateScript(index);
        var setup = _script.Configure(battle.ToSetup(Player!, Friend!, enemies));

        ResetHooks();
        _stage = new EncounterStage(this)
        {
            Index = index,
            Attempt = attempt,
            Scene = scene,
            Hooks = Hooks,
            Popup = _popup,
            Dialogue = _dialogue,
            Battle = battle,
            Player = Player!,
            Friend = Friend!,
            Enemies = enemies,
            Lines = new PrologueLines(FriendStrikeLines, HalfHpLines, QuarterHpLines, VictoryLines, ClosingLines),
            PopupLog = PopupLog,
        };
        var stage = _stage;
        Hooks.OnTurnStarted(stage.OnTurnStarted);
        Hooks.OnEncounterFinished(result => { stage.NoteResult(result); return Task.CompletedTask; });
        _script.Arm(stage);

        scene.Tutorial = Hooks;
        scene.Journal = Journal;
        scene.TargetFilter = null;
        scene.AutoEndTurn = _script.AutoEndTurn;
        scene.SetPresentationVisible(true);
        scene.StartEncounter(setup);
        scene.SetHudVisible(false);

        for (float waited = 0; !stage.HasHeldTurn && !stage.Finished; waited += (float)GetProcessDeltaTime())
        {
            if (waited > FirstTurnTimeoutSeconds)
            {
                GD.PushError($"[PrologueRunner] encounter {index} never reached its first turn.");
                break;
            }
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        ShowWardrobe();
        Prepared?.Invoke(index);
    }

    public async Task<EncounterOutcome> Run(int index)
    {
        if (_stage == null || _script == null || _stage.Index != index)
            throw new InvalidOperationException($"[PrologueRunner] encounter {index} was not prepared.");
        var stage = _stage;
        Scene!.SetHudVisible(true);
        _fightHudShown = true;
        SyncStoryModal();
        try
        {
            return await _script.Play();
        }
        catch (OperationCanceledException)
        {
            return EncounterOutcome.Defeat;
        }
        catch (Exception e)
        {
            // A script fault must not strand the player: open the fight and let it finish.
            GD.PushError($"[PrologueRunner] encounter {index} script failed: {e}");
            stage.Unlock();
            stage.LetTurnsRun();
            await stage.WaitResult();
            return stage.Won ? EncounterOutcome.Victory : EncounterOutcome.Defeat;
        }
    }

    public void Release(int index)
    {
        _fightHudShown = false;
        _stage?.Cancel();
        Scene?.EndHostedEncounter();
        ResetHooks();
        if (Scene != null)
        {
            Scene.TargetFilter = null;
            Scene.SetStoryModal(false);
        }
        _stage = null;
        _script = null;
    }

    // ---------------------------------------------------------------- Setup

    private CombatScene EnsureScene()
    {
        if (Scene != null) return Scene;
        if (CombatScene == null) throw new InvalidOperationException("[PrologueRunner] CombatScene is not assigned.");
        Scene = CombatScene.Instantiate<CombatScene>();
        Scene.EncounterIntroEnabled = false;
        Scene.ResultBannerEnabled = false;
        Scene.BeforePlayerCommand = order => _stage?.OnCommit(order);
        AddChild(Scene);
        return Scene;
    }

    private static EncounterScript CreateScript(int index) => index switch
    {
        1 => new Encounter1Script(),
        2 => new Encounter2Script(),
        3 => new Encounter3Script(),
        4 => new Encounter4Script(),
        _ => throw new ArgumentOutOfRangeException(nameof(index), index, "The Prologue has encounters 1 to 4."),
    };

    /// <summary>Build the heroes once. Every fight clears their conditions and resets the Friend's
    /// flasks; HP carries over, except that a fallen party or a hero at 0 HP starts full.</summary>
    private void PrepareHeroes()
    {
        Player ??= PrologueCast.BuildPlayer();
        Friend ??= PrologueCast.BuildFriend();
        bool fallen = Player.Health.CurrentHP <= 0 && Friend.Health.CurrentHP <= 0;
        foreach (var hero in new[] { Player, Friend })
        {
            hero.Health.ClearPermanentDeath();
            hero.Conditions?.RemoveAllConditions();
            if (fallen || hero.Health.CurrentHP <= 0) hero.Health.RestoreToFull();
        }
        Friend.Equipment.Consumables.SetCount(AlchemicalItems.AcidFlaskLesserId, PrologueCast.FriendAcidFlasks);
    }

    private void ResetHooks()
    {
        Hooks.ClearCallbacks();
        Hooks.ClearCommandRestriction();
        Hooks.ClearMoveRestriction();
        Hooks.ShowHiddenFieldsCallout(false);
        Hooks.ClearForcedDice();
        if (Player != null) Hooks.ClearAutoPass(Player);
        if (Friend != null) Hooks.ClearAutoPass(Friend);
    }

    // ---------------------------------------------------------------- Wardrobe

    /// <summary>Light the glow on each hero token whose speaker carries or wears an accessory in the
    /// dialogue box's wardrobe, and put out the others. Nothing happens between encounters.</summary>
    private void ShowWardrobe()
    {
        if (_stage == null) return;
        foreach (var hero in new ICharacter?[] { Player, Friend })
            if (hero != null && TokenOf(hero.Name) is { } token)
                token.ShowAccessory(_dialogue.Wardrobe.ShownOn(hero.Name));
    }

    /// <summary>The prepared board's token of the hero named <paramref name="name"/> (a speaker name), or null.</summary>
    public UnitVisual3D? TokenOf(string name)
    {
        var hero = Player?.Name == name ? Player : Friend?.Name == name ? Friend : null;
        return hero == null ? null : Scene?.UnitVisual(hero);
    }

    // ---------------------------------------------------------------- Story overlays

    /// <summary>Hold the HUD's input while a story overlay shows. During a fight the HUD also hides
    /// while the dialogue box is open; popups keep it, since they point at HUD parts.</summary>
    private void SyncStoryModal()
    {
        if (Scene == null) return;
        Scene.SetStoryModal(_popup.IsShowing || _dialogue.IsShowing);
        if (_fightHudShown) Scene.SetHudVisible(!_dialogue.IsShowing);
    }

    /// <summary>A move to a tile off the gold set: a step tip on the gold tiles repeats the step's
    /// instruction until the move restriction changes.</summary>
    private async void ShowRefusal()
    {
        if (_refusalShowing || _stage == null || Hooks.MoveHint is not { } hint) return;
        _refusalShowing = true;
        var stage = _stage;
        var tiles = Hooks.MoveTiles;
        try
        {
            // The box sits off the move bands, next to the gold tiles it points at.
            using (stage.Step(WrongTileTip, (TutorialFocus.GuideTiles + TutorialFocus.MoveBand.AsContext()).Undimmed(), hint))
                while (ReferenceEquals(Hooks.MoveTiles, tiles) && !stage.Finished) await stage.NextFrame();
        }
        catch (OperationCanceledException) { }
        finally { _refusalShowing = false; }
    }

    /// <summary>The wrong-tile tip's id.</summary>
    internal const string WrongTileTip = "wrong_tile";
}
