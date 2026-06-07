using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public partial class CombatTestScene : Control
{
    private RichTextLabel _combatLog;
    private Label _resultLabel;
    private Label _statusLabel;
    private Button _fightButton;
    private Button _clearButton;
    private DataManager _dataManager;
    private CombatOrchestrator _orchestrator;
    private bool _fighting;

    public override void _Ready()
    {
        _dataManager = GetNode<DataManager>("/root/DataManager");

        BuildUI();

        _orchestrator = new CombatOrchestrator();

        if (_dataManager.IsLoaded)
            OnDataLoaded(_dataManager.AllCreatures.Count);
        else
            _dataManager.DataLoaded += OnDataLoaded;

        _dataManager.CombatLogReceived += OnCombatLogReceived;
    }

    private void BuildUI()
    {
        var margin = new MarginContainer();
        margin.SetAnchorsPreset(LayoutPreset.FullRect);
        margin.AddThemeConstantOverride("margin_left", 20);
        margin.AddThemeConstantOverride("margin_right", 20);
        margin.AddThemeConstantOverride("margin_top", 20);
        margin.AddThemeConstantOverride("margin_bottom", 20);
        AddChild(margin);

        var vbox = new VBoxContainer();
        vbox.AddThemeConstantOverride("separation", 10);
        margin.AddChild(vbox);

        var titleLabel = new Label();
        titleLabel.Text = "PF2e Autobattler — Combat Test";
        titleLabel.AddThemeColorOverride("font_color", new Color(1, 0.85f, 0.3f));
        titleLabel.AddThemeFontSizeOverride("font_size", 24);
        vbox.AddChild(titleLabel);

        _statusLabel = new Label();
        _statusLabel.Text = "Loading PF2e data...";
        vbox.AddChild(_statusLabel);

        var buttonRow = new HBoxContainer();
        buttonRow.AddThemeConstantOverride("separation", 10);
        vbox.AddChild(buttonRow);

        _fightButton = new Button();
        _fightButton.Text = "Fight! (3v3 Random)";
        _fightButton.Disabled = true;
        _fightButton.Pressed += OnFightPressed;
        buttonRow.AddChild(_fightButton);

        _clearButton = new Button();
        _clearButton.Text = "Clear Log";
        _clearButton.Pressed += () => _combatLog.Clear();
        buttonRow.AddChild(_clearButton);

        _resultLabel = new Label();
        _resultLabel.Text = "";
        _resultLabel.AddThemeFontSizeOverride("font_size", 20);
        vbox.AddChild(_resultLabel);

        _combatLog = new RichTextLabel();
        _combatLog.SizeFlagsVertical = SizeFlags.ExpandFill;
        _combatLog.BbcodeEnabled = true;
        _combatLog.ScrollFollowing = true;
        vbox.AddChild(_combatLog);
    }

    private void OnDataLoaded(int creatureCount)
    {
        _statusLabel.Text = $"Loaded {creatureCount} creatures. Ready to fight!";
        _fightButton.Disabled = false;

        foreach (var kvp in _dataManager.CreaturesByTier.OrderBy(k => k.Key))
        {
            var names = kvp.Value.Take(5).Select(d => d.CreatureName);
            AppendLog($"[color=gray]Tier {kvp.Key}: {kvp.Value.Count} creatures (e.g. {string.Join(", ", names)})[/color]");
        }
    }

    private void OnCombatLogReceived(string message, int severity)
    {
        string color = (CombatLogSeverity)severity switch
        {
            CombatLogSeverity.CriticalHit => "red",
            CombatLogSeverity.Hit => "orange",
            CombatLogSeverity.Miss => "gray",
            CombatLogSeverity.CriticalMiss => "dark_gray",
            CombatLogSeverity.Healing => "green",
            CombatLogSeverity.ConditionApplied => "yellow",
            CombatLogSeverity.ConditionRemoved => "cyan",
            CombatLogSeverity.ActionHeader => "white",
            CombatLogSeverity.Reaction => "purple",
            _ => "white"
        };
        AppendLog($"[color={color}]{message}[/color]");
    }

    private async void OnFightPressed()
    {
        if (_fighting) return;
        _fighting = true;
        _fightButton.Disabled = true;
        _resultLabel.Text = "Fighting...";
        _combatLog.Clear();

        var playerUnits = PickRandomTeam(teamId: 1, count: 3, maxTier: 2);
        var enemyUnits = PickRandomTeam(teamId: 2, count: 3, maxTier: 2);

        AppendLog("[color=lime]═══ PLAYER TEAM ═══[/color]");
        foreach (var (def, pos) in playerUnits)
            AppendLog($"  [color=cyan]{def.CreatureName}[/color] (Lv{def.StatBlock.CreatureLevel}) at ({pos.x},{pos.y})");

        AppendLog("[color=red]═══ ENEMY TEAM ═══[/color]");
        foreach (var (def, pos) in enemyUnits)
            AppendLog($"  [color=orange]{def.CreatureName}[/color] (Lv{def.StatBlock.CreatureLevel}) at ({pos.x},{pos.y})");

        AppendLog("[color=yellow]═══ COMBAT START ═══[/color]");

        BattleResult result = await _orchestrator.RunCombat(
            playerUnits, enemyUnits,
            presenter: null,
            seed: (int)(Time.GetTicksMsec() % int.MaxValue));

        string resultText = result switch
        {
            BattleResult.Team1Wins => "[color=lime]VICTORY![/color] Player wins!",
            BattleResult.Team2Wins => "[color=red]DEFEAT![/color] Enemy wins!",
            BattleResult.Draw => "[color=yellow]DRAW![/color]",
            _ => result.ToString()
        };

        AppendLog($"\n[color=yellow]═══ {resultText} ═══[/color]");
        AppendLog($"Surviving allies: {_orchestrator.CountSurvivingAllies()}/{playerUnits.Count}");
        AppendLog($"Surviving enemies: {_orchestrator.CountSurvivingEnemies()}/{enemyUnits.Count}");

        _resultLabel.Text = result switch
        {
            BattleResult.Team1Wins => "VICTORY! Player wins!",
            BattleResult.Team2Wins => "DEFEAT! Enemy wins!",
            BattleResult.Draw => "DRAW!",
            _ => result.ToString()
        };

        _fighting = false;
        _fightButton.Disabled = false;
    }

    private List<(EnemyDefinition def, PF2eVec position)> PickRandomTeam(int teamId, int count, int maxTier)
    {
        var rng = new System.Random();
        var pool = new List<EnemyDefinition>();
        for (int tier = 1; tier <= maxTier; tier++)
            pool.AddRange(_dataManager.GetCreaturesForTier(tier));

        if (pool.Count == 0)
        {
            GD.PushError("[CombatTest] No creatures available in pool!");
            return new List<(EnemyDefinition, PF2eVec)>();
        }

        var result = new List<(EnemyDefinition def, PF2eVec position)>();
        int startRow = teamId == 1 ? 0 : 6;

        for (int i = 0; i < count; i++)
        {
            var def = pool[rng.Next(pool.Count)];
            var pos = new PF2eVec(1 + i * 2, startRow + rng.Next(2));
            result.Add((def, pos));
        }

        return result;
    }

    private void AppendLog(string bbcodeText)
    {
        _combatLog.AppendText(bbcodeText + "\n");
    }
}
