using System;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;

namespace Ungilded.Combat;

/// <summary>Controls a story host uses around a fight: the HUD on its own, the story modal, the
/// result banner, a target filter, the turn end at 0 actions, log lines and a heal beat.</summary>
public partial class CombatScene
{
    /// <summary>False skips the Victory and Defeat banners; the host shows its own beat.</summary>
    [Export] public bool ResultBannerEnabled { get; set; } = true;

    private Func<ICharacter, bool>? _targetFilter;
    private bool _autoEndTurn = true;
    private bool _storyModal;

    /// <summary>False drops a creature from Strike, skill and bomb target sets. Applies to the
    /// running encounter and every later one until it is cleared.</summary>
    public Func<ICharacter, bool>? TargetFilter
    {
        get => _targetFilter;
        set
        {
            _targetFilter = value;
            if (_controller != null) _controller.TargetFilter = value;
        }
    }

    /// <summary>False keeps a hero's turn open at 0 actions until End Turn is chosen.</summary>
    public bool AutoEndTurn
    {
        get => _autoEndTurn;
        set
        {
            _autoEndTurn = value;
            if (_controller != null) _controller.AutoEndTurn = value;
        }
    }

    private Action<PlayerOrder>? _beforePlayerCommand;

    /// <summary>Runs as the player commits an order: an action starts, End Turn, or an accepted
    /// reaction prompt. Every hover preview of that order has already run. The order names its
    /// target for a Strike, a bomb and a reaction.</summary>
    public Action<PlayerOrder>? BeforePlayerCommand
    {
        get => _beforePlayerCommand;
        set
        {
            _beforePlayerCommand = value;
            if (_controller != null) _controller.BeforeCommand = value;
        }
    }

    /// <summary>The combatant with this engine id in the running encounter, or null.</summary>
    private ICharacter? CombatantById(int? id)
        => id is not { } wanted || _session == null ? null
            : _session.Team1.Concat(_session.Team2).FirstOrDefault(c => c.UniqueId == wanted);

    private void ApplyHostControls()
    {
        _controller.TargetFilter = _targetFilter;
        _controller.AutoEndTurn = _autoEndTurn;
        _controller.BeforeCommand = _beforePlayerCommand;
    }

    /// <summary>Show or hide the HUD only; the board stays.</summary>
    public void SetHudVisible(bool visible) => _hud.Visible = visible;

    public bool HudVisible => _hud.Visible;

    /// <summary>Hold the HUD's modal state while a story box or popup covers the fight, so the
    /// board, the menu and the hotkeys take no input.</summary>
    public void SetStoryModal(bool open)
    {
        if (_storyModal == open) return;
        _storyModal = open;
        if (open) _tacticalHud.PushModal();
        else _tacticalHud.PopModal();
    }

    /// <summary>One combat log row with no roll behind it.</summary>
    public void AppendLog(string message, bool isDetail = false)
        => _log.AppendEntry(message, (int)CombatLogSeverity.Info, isDetail);

    /// <summary>One combat log row the dice panel reads as a check ("Medicine: 14 + 4 = 18 vs DC 15 → Success").</summary>
    public void AppendCheckLog(string message) => _log.AppendEntry(message, (int)CombatLogSeverity.Info, true);

    /// <summary>The Treat Wounds wrap, the +N floater and the HP bar for healing applied outside an
    /// action. The session's journal recorded the heal; claiming it keeps a later flush from playing
    /// it a second time.</summary>
    public Task PresentHeal(ICharacter healer, ICharacter target, int amount)
    {
        if (_presenter == null || amount <= 0) return Task.CompletedTask;
        var heal = new BattleEvent
        {
            Type = BattleEventType.Healed,
            Source = healer,
            Target = target,
            IntValue = amount,
        };
        _session?.ClaimPresented(heal);
        return _presenter.Present(heal);
    }

    /// <summary>Dev use: true while the reaction prompt waits for a choice.</summary>
    public bool ReactionPromptOpen => _promptOpen;

    /// <summary>Dev use: answer the open reaction prompt as its buttons do.</summary>
    public void ChooseReaction(bool use) => _reactionPrompt.Choose(use);
}
