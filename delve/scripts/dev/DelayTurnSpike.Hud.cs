using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

public partial class DelayTurnSpike
{
    /// <summary>The last actor of a round Delays into the next round: every offered row sits below
    /// the round divider, and the ally resumes right after the chosen early actor next round.</summary>
    private async Task RunLastActorCase(CombatScene scene, ActionBar bar, Button delayBtn, BoxContainer row,
        PF2e.Data.EnemyDefinition goblinDef)
    {
        string? ally = null;
        int startRound = 0;
        for (int seed = 1; seed <= 12 && ally == null; seed++)
        {
            scene.StartEncounter(new CombatSetup
            {
                GridWidth = 60, GridHeight = 10, RngSeed = seed,
                Party =
                {
                    (PresetCharacters.BuildFenwick(level: 2, teamId: 1), new PF2eVec(3, 5)),
                    (PresetCharacters.BuildElara(level: 2, teamId: 1), new PF2eVec(3, 3)),
                },
                Enemies = { (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(57, 5)) },
            });
            await WaitForPlayerTurn(scene);
            var last = Session(scene)?.TurnOrder?[^1].Character;
            if (last is not { TeamId: 1 }) continue;
            startRound = Session(scene)!.RoundNumber;
            await WaitForAllyTurn(scene, bar, last.Name);
            if (ActorName(scene) == last.Name) ally = last.Name;
        }
        Check($"[last actor] {ally} acts last in round {startRound} and can Delay ('{delayBtn.TooltipText}')",
            ally != null && scene.IsPlayerTurn && !delayBtn.Disabled);
        if (ally == null || delayBtn.Disabled) return;

        bar._UnhandledInput(new InputEventAction { Action = InputNames.Delay, Pressed = true });
        await Frames(2);
        var picks = PickableChips(row);
        Check($"[last actor] every offered row is a next-round row below the divider (chips: {ChipNames(row)})",
            picks.Count > 0 && AllAfterDivider(row));
        if (picks.Count == 0) return;
        string anchorName = ChipName(picks[0]);
        Click(picks[0].GetGlobalRect().GetCenter());
        await WaitSeconds(0.5f);
        int anchorIndex = ChipIndex(row, anchorName);
        int waitingIndex = ChipIndex(row, "~ " + ally);
        Check($"[last actor] the waiting chip sits right after {anchorName} (chips: {ChipNames(row)})",
            waitingIndex >= 0 && waitingIndex == anchorIndex + 1);

        await WaitForAllyTurn(scene, bar, ally);
        int activeIndex = ActiveIndex(row);
        int round = Session(scene)?.RoundNumber ?? 0;
        Check($"[last actor] {ally} returns in round {round} right after {anchorName} (chips: {ChipNames(row)})",
            round == startRound + 1 && activeIndex >= 0 && PreviousChipName(row, activeIndex) == anchorName);
        Check($"[last actor] the resumed turn cannot Delay again ('{delayBtn.TooltipText}')",
            delayBtn.Disabled && delayBtn.TooltipText.Contains(CombatSession.ResumedTurnReason));
    }

    private static bool AllAfterDivider(BoxContainer row)
    {
        bool passedDivider = false;
        foreach (var child in row.GetChildren())
        {
            if (child is not Control chip) continue;
            if (IsDivider(chip)) { passedDivider = true; continue; }
            if (chip.MouseFilter == Control.MouseFilterEnum.Stop && !passedDivider) return false;
        }
        return passedDivider;
    }

    private static CombatSession? Session(CombatScene scene)
        => typeof(CombatScene).GetField("_session", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!
            .GetValue(scene) as CombatSession;

    /// <summary>Wait for <paramref name="ally"/>'s turn, ending every other ally's turn on the way
    /// (nobody else is pressing End Turn in a headless run).</summary>
    private async Task WaitForAllyTurn(CombatScene scene, ActionBar bar, string ally)
    {
        float waited = 0f;
        while (!(scene.IsPlayerTurn && ActorName(scene) == ally && bar.ActorName == ally) && waited < TurnWaitSeconds)
        {
            await WaitSeconds(0.25f);
            waited += 0.25f;
            if (scene.IsPlayerTurn && ActorName(scene) != ally && bar.ActorName == ActorName(scene))
                bar._UnhandledInput(new InputEventAction { Action = InputNames.EndTurn, Pressed = true });
        }
        await WaitSeconds(0.5f);
    }

    private static string? ActorName(CombatScene scene) => Session(scene)?.CurrentActor?.Name;

    private async Task WaitForPlayerTurn(CombatScene scene)
    {
        await WaitSeconds(0.5f);
        float waited = 0f;
        while (!scene.IsPlayerTurn && waited < TurnWaitSeconds)
        {
            await WaitSeconds(0.25f);
            waited += 0.25f;
        }
    }

    private static List<Control> PickableChips(BoxContainer row)
    {
        var picks = new List<Control>();
        foreach (var child in row.GetChildren())
            if (child is Control chip && chip.MouseFilter == Control.MouseFilterEnum.Stop) picks.Add(chip);
        return picks;
    }

    private static bool AllAfterActive(BoxContainer row)
    {
        bool passedActive = false;
        foreach (var child in row.GetChildren())
        {
            if (child is not Control chip) continue;
            if (IsActive(chip)) { passedActive = true; continue; }
            if (chip.MouseFilter == Control.MouseFilterEnum.Stop && !passedActive) return false;
        }
        return passedActive;
    }

    private static string ChipName(Node chip) => chip.GetNode<Label>("%Label").Text;

    private static bool IsActive(Control chip) => chip.ThemeTypeVariation == ThemeNames.TurnChipActive;

    private static bool IsDivider(Node chip) => ChipName(chip).StartsWith("Round ");

    private static int ActiveIndex(BoxContainer row)
    {
        for (int i = 0; i < row.GetChildCount(); i++)
            if (row.GetChild(i) is Control chip && IsActive(chip)) return i;
        return -1;
    }

    /// <summary>The combatant before <paramref name="index"/> in turn order: the strip starts at the
    /// actor, so the one before the first chip is the last chip.</summary>
    private static string PreviousChipName(BoxContainer row, int index)
    {
        int count = row.GetChildCount();
        for (int step = 1; step < count; step++)
        {
            var chip = row.GetChild(((index - step) % count + count) % count);
            if (!IsDivider(chip)) return ChipName(chip);
        }
        return "";
    }

    private static int ChipIndex(BoxContainer row, string name)
    {
        int i = 0;
        foreach (var child in row.GetChildren())
        {
            if (ChipName(child) == name) return i;
            i++;
        }
        return -1;
    }

    private static string ChipNames(BoxContainer row)
    {
        var names = new List<string>();
        foreach (var child in row.GetChildren()) names.Add(ChipName(child));
        return string.Join(" | ", names);
    }

    private void Click(Vector2 screen)
    {
        Push(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = screen, GlobalPosition = screen });
        Push(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = screen, GlobalPosition = screen });
    }

    /// <summary>Local coordinates: the headless window's stretch transform would otherwise rescale
    /// the event off-screen.</summary>
    private void Push(InputEvent @event) => GetViewport().PushInput(@event, inLocalCoords: true);

    /// <summary>Saves the frame when a renderer is up. A headless run has no viewport texture, so
    /// it only notes the skip: run without --headless to refresh the picture.</summary>
    private void Capture(string file)
    {
        if (DisplayServer.GetName() == "headless")
        {
            GD.Print($"[DelayTurn] {file}: skipped (headless, no viewport texture)");
            return;
        }
        Check($"{file} saved", SaveViewportCapture($"{OutputDirectory}/{file}", new Vector2I(1280, 720)) == Error.Ok);
    }
}
