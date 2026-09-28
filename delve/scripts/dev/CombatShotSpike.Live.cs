using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatShotSpike
{
    /// <summary>Seconds the live enemy-strike capture may wait for a real Shield Block prompt.</summary>
    [Export] public float PromptWaitSeconds { get; set; } = 60f;

    private static CombatSession Session(CombatScene scene)
        => (CombatSession)typeof(CombatScene).GetField("_session", BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(scene)!;

    /// <summary>A live player turn with the whole board framed: the hovered enemy fills the card slot and shows its badge.</summary>
    private async Task CapturePlayerTurnWithEnemies(CombatScene scene)
    {
        var session = Session(scene);
        var rig = Rig();
        if (!scene.IsPlayerTurn || rig == null)
        {
            Check("a player turn is up for the enemies-in-frame capture", false);
            return;
        }
        // The signature fixtures left a fake state on the bar; Cancel republishes the live one.
        var controller = (PlayerTurnController)typeof(CombatScene).GetField("_controller", BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(scene)!;
        controller.Cancel();
        rig.ToggleOverview();
        await WaitSeconds(0.8f);
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        bool striking = !bar.GetNode<Button>("%StrikeButton").Disabled;
        if (striking) bar._UnhandledInput(new InputEventAction { Action = InputNames.Action1, Pressed = true });
        var enemy = session.Team2.FirstOrDefault(e => e.Health?.IsAlive == true
            && (!striking || session.PlayerActions.GetStrikeTargets(session.CurrentActor!).Contains(e)));
        if (enemy != null)
            typeof(CombatScene).GetMethod("OnTileHovered", BindingFlags.Instance | BindingFlags.NonPublic)!
                .Invoke(scene, new object?[] { (PF2e.Vector2Int?)enemy.GridPosition });
        await WaitSeconds(PoseSeconds);
        if (striking)
            Check($"a live strike forecast fills the decision slot ({string.Join(", ", bar.Decision.FigureLabels.Select(f => $"{f.CaptionText} {f.ValueText}"))})",
                bar.Decision.Card.Visible && bar.Decision.FigureLabels.Count >= 2);
        var inspect = scene.GetNode<UnitInspectPanel>("%UnitInspect");
        string letter = enemy == null ? "" : session.Letters.LetterFor(enemy);
        string occupant = enemy == null ? "none" : session.Grid.GetGroundOccupant(enemy.GridPosition)?.Name ?? "nobody";
        Check($"hovered enemy fills the card slot with its letter ({letter}; {enemy?.Name} at {enemy?.GridPosition}, tile holds {occupant})",
            inspect.Visible && inspect.GetNode<Label>("%BadgeLabel").Text == letter && letter.Length > 0);
        var token = scene.GetNode<Node3D>("%UnitLayer").GetChildren().OfType<UnitVisual3D>()
            .FirstOrDefault(u => u.Character == enemy);
        Check(striking ? "the targeted enemy shows its name plate" : "the hovered enemy shows its letter badge and no plate",
            token != null && (striking ? token.Plate.PlateVisible : token.Plate.BadgeVisible && !token.Plate.PlateVisible));
        var actorToken = scene.GetNode<Node3D>("%UnitLayer").GetChildren().OfType<UnitVisual3D>()
            .FirstOrDefault(u => u.Character == session.CurrentActor);
        Check("the actor shows its name plate", actorToken?.Plate.PlateVisible == true);
        int plates = scene.GetNode<Node3D>("%UnitLayer").GetChildren().OfType<UnitVisual3D>().Count(u => u.Plate.PlateVisible);
        Check($"name plates show only for the actor, target and reactor ({plates})", plates <= 2);
        CheckPlates(scene);
        Check("the Current Turn panel is gone on player turns", scene.GetNodeOrNull("%ActiveCharacter") == null);
        Check("the action bar prints no name, HP or AC", bar.GetNodeOrNull("%ActorLabel") == null && bar.GetNodeOrNull("%VitalsLabel") == null);
        AssertZones(scene, "combat_player_turn_enemies.png");
        Capture("combat_player_turn_enemies.png");
        typeof(CombatScene).GetMethod("OnTileHovered", BindingFlags.Instance | BindingFlags.NonPublic)!
            .Invoke(scene, new object?[] { null });
        controller.Cancel();
        rig.ToggleOverview();
        await WaitSeconds(0.5f);
    }

    /// <summary>
    /// Plays turns until an enemy strike raises a real Shield Block prompt, then photographs it.
    /// Every hero raises a shield when it can and ends the turn.
    /// </summary>
    private async Task CaptureEnemyStrikePrompt(CombatScene scene)
    {
        var session = Session(scene);
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var prompt = scene.GetNode<ReactionPromptPanel>("%ReactionPrompt");
        var original = session.ReactionPromptHandler;
        if (original == null) { Check("the scene installs a reaction prompt handler", false); return; }
        bool captured = false, strikeCaptured = false, staged = false, capturing = false;
        session.ReactionPromptHandler = async view =>
        {
            bool block = view.Figures.Any(f => f.IsChange);
            // A staged Shield Block runs beside the enemy's own turn; a second prompt would replace it mid-capture.
            if (capturing && !block) return false;
            if (block && !captured) capturing = true;
            var choice = original(view);
            for (int i = 0; i < 50 && !(prompt.Visible && prompt.TitleText == view.Title); i++) await WaitSeconds(0.1f);
            if (block ? !captured : !strikeCaptured)
            {
                if (block) await EnsureBandRoll(scene);
                await WaitSeconds(0.3f);
                string shot = !block ? "combat_reaction_strike.png"
                    : staged ? "shield_block_staged.png" : "combat_reaction_prompt.png";
                if (block) captured = true; else strikeCaptured = true;
                CheckPrompt(scene, prompt, bar, view, liveRoll: !staged);
                AssertZones(scene, shot);
                CheckBudget(scene, $"enemy turn with prompt ({shot})", EnemyBudgetPercent, RollClearBox);
                Capture(shot);
            }
            // Skip every other reaction so the reaction is still up when a strike lands on a raised shield.
            prompt._Input(new InputEventAction { Action = block ? InputNames.Confirm : InputNames.Decline, Pressed = true });
            capturing = false;
            return await choice;
        };

        float waited = 0;
        while (!captured && waited < PromptWaitSeconds && !scene.GetNode<VictoryBanner>("%VictoryBanner").Visible)
        {
            await WaitSeconds(0.3f);
            waited += 0.3f;
            if (!scene.IsPlayerTurn || session.CurrentActor is not { } actor || bar.ActorName != actor.Name) continue;
            bool raise = actor.Equipment?.IsShieldRaised != true && actor.Equipment?.CanRaiseShield() == true
                && actor.Actions?.TotalActionsRemaining > 0;
            bar._UnhandledInput(new InputEventAction { Action = raise ? InputNames.Action2 : InputNames.EndTurn, Pressed = true });
        }
        bool live = captured;
        if (!captured)
        {
            staged = true;
            await StageShieldBlock(scene, session, () => captured);
        }
        Check("a Shield Block prompt opened on an enemy turn", captured);
        GD.Print(live
            ? $"  [INFO] the Shield Block prompt came from live play after {waited:0} s (combat_reaction_prompt.png)"
            : $"  [INFO] the Shield Block prompt was staged: live play raised none in {waited:0} s (shield_block_staged.png)");
        session.ReactionPromptHandler = original;
    }

    /// <summary>
    /// Fallback when live play lands no hit on a raised shield: at the start of an enemy turn, the
    /// acting enemy's damage goes through the engine's real reaction path, so the scene's own handler
    /// opens the prompt. No strike roll is made, so the log and the dice slot show none.
    /// </summary>
    private async Task StageShieldBlock(CombatScene scene, CombatSession session, System.Func<bool> captured)
    {
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        for (float waited = 0; waited < 60f; waited += 0.2f)
        {
            if (session.CurrentActor is { TeamId: 2 } enemy && enemy.Health?.IsAlive == true)
            {
                var hero = session.Team1.FirstOrDefault(h => h.Equipment?.EquippedShield != null && h.Health?.IsAlive == true
                    && h.Actions?.ReactionAvailable == true);
                if (hero == null) { Check("a shield bearer with a reaction is up for the staged strike", false); return; }
                if (!hero.Equipment!.IsShieldRaised) hero.Equipment.RaiseShield(hero);
                _ =PF2e.Events.ReactionEvents.DeliverDamage(enemy, hero,
                    new PF2e.Data.DamageResult { TotalDamage = 9, DamageType = PF2e.Data.DamageType.Piercing });
                for (int i = 0; i < 100 && !captured(); i++) await WaitSeconds(0.1f);
                return;
            }
            if (scene.IsPlayerTurn && session.CurrentActor is { } actor && bar.ActorName == actor.Name)
                bar._UnhandledInput(new InputEventAction { Action = InputNames.EndTurn, Pressed = true });
            await WaitSeconds(0.2f);
        }
    }

    private void CheckPrompt(CombatScene scene, ReactionPromptPanel prompt, ActionBar bar, ReactionPromptView view, bool liveRoll)
    {
        var dock = prompt.Dock.GetGlobalRect();
        Check($"prompt docks at the bottom centre, 600 px wide on the 1064 baseline ({dock})",
            Mathf.Abs(dock.End.Y - 1064) <= 1 && Mathf.Abs(dock.GetCenter().X - 960) <= 1 && Mathf.Abs(dock.Size.X - 600) <= 1);
        var actorCard = scene.GetNode<Control>("%ActorCard").GetGlobalRect();
        var targetCard = scene.GetNode<Control>("%TargetCard").GetGlobalRect();
        Check($"the attacker and target cards sit 16 px either side of the prompt on the baseline ({actorCard}, {targetCard})",
            scene.GetNode<Control>("%ActorCard").Visible && scene.GetNode<Control>("%TargetCard").Visible
            && Mathf.Abs(dock.Position.X - actorCard.End.X - 16) <= 1 && Mathf.Abs(targetCard.Position.X - dock.End.X - 16) <= 1
            && Mathf.Abs(actorCard.End.Y - 1064) <= 1 && Mathf.Abs(targetCard.End.Y - 1064) <= 1);
        Check($"the band cards share one height ({actorCard.Size.Y}, {targetCard.Size.Y})", Mathf.Abs(actorCard.Size.Y - targetCard.Size.Y) <= 0.5f);
        Check("the action bar hides while the prompt holds the bottom", !bar.IsVisibleInTree());
        Check($"prompt title reads '{prompt.TitleText}'", prompt.TitleText == view.Title && view.Title.EndsWith("?"));
        var figures = prompt.FigureLabels;
        Check($"prompt shows {figures.Count} compact figures ({string.Join(", ", figures.Select(f => $"{f.CaptionText} {f.BeforeText}→{f.ValueText}"))})",
            figures.Count == view.Figures.Count && figures.Count is > 0 and <= 2);
        var reactor = scene.GetNode<SquadPanel>("%SquadPanel").Chips.FirstOrDefault(c => c.MemberId == view.ReactorId);
        Check("the reactor's party chip takes the bone frame", reactor?.Framed == true);
        var dice = scene.GetNode<DiceRollPanel>("%DiceRoll");
        if (dice.Visible)
        {
            var roll = dice.GetGlobalRect();
            Check($"the roll row sits 8 px above the prompt, 600 px wide on x 960 ('{dice.Context}' {roll})",
                Mathf.Abs(dock.Position.Y - roll.End.Y - 8) <= 1 && Mathf.Abs(roll.Size.X - 600) <= 1
                && Mathf.Abs(roll.GetCenter().X - 960) <= 1);
        }
        else if (liveRoll && view.Figures.Any(f => f.IsChange))
            Check("the strike roll shows above the Shield Block prompt", false);
        var backdrop = prompt.GetNode<Control>("%Backdrop");
        Check("a transparent backdrop still catches board clicks", backdrop.MouseFilter == Control.MouseFilterEnum.Stop
            && backdrop.ThemeTypeVariation == "ModalVignette");
        CheckPlates(scene);
    }

    private void CheckPlates(CombatScene scene)
    {
        var camera = scene.ActiveCamera;
        var tokens = scene.GetNode<Node3D>("%UnitLayer").GetChildren().OfType<UnitVisual3D>().ToList();
        var plates = tokens.Where(t => t.Plate.PlateVisible)
            .Select(t => (Name: $"{t.Character.Name} plate ({t.Plate.Lane})", Rect: t.Plate.PlateRect(camera))).ToList();
        var rows = tokens.Select(t => (Name: $"{t.Character.Name} Dying badge", Rect: t.Dying.ScreenRect(camera)))
            .Where(r => r.Rect.HasValue).Select(r => (r.Name, Rect: r.Rect!.Value)).ToList();
        var clashes = new List<string>();
        for (int i = 0; i < plates.Count; i++)
            foreach (var other in plates.Skip(i + 1).Concat(rows))
                if (other.Rect.Intersects(plates[i].Rect)) clashes.Add($"{plates[i].Name} {plates[i].Rect} x {other.Name} {other.Rect}");
        Check($"{plates.Count} name plates clear each other and {rows.Count} Dying badges{(clashes.Count > 0 ? $" ({string.Join("; ", clashes)})" : "")}",
            clashes.Count == 0);
    }
}
