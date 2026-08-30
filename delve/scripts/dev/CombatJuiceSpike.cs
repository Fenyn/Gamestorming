using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Fx;
using Delve.Presets;
using Godot;
using PF2e.Core;
using PF2e.Data;
// Pf2e.Core's own PF2e.Vector2Int/Vector3 collide with Godot's, so the namespace is never imported
// wholesale here (CLAUDE.md's bridge-file rule) — only the one type this spike needs, aliased.
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless proof for the combat hit-feedback pass: the crit degree that weapon strikes were dropping,
/// the presenter's per-event FX spawns, the swing clip's impact gate, the per-unit popup height, and
/// the camera shake's trauma decay. No GameState is touched (a presenter plus two tokens is the whole
/// fixture), so no SaveIsolation is needed.
///
/// What each block proves, and why it is the check that would have caught the bug:
///  - CRIT DEGREE: a real Veteran-vs-goblins fight is run with a recording presenter, and every
///    DamageDealt that follows an AttackRolled must carry that roll's degree. Strikes used to emit
///    Degree = null unconditionally (only the spell path passed it), which silently disabled
///    DamagePopup3D's crit styling for every weapon hit in the game.
///  - FX SPAWNS: each event is presented against live tokens and the one-shot FX group is counted
///    before and after. A miss must spawn NOTHING (a whiff has no impact to spark).
///  - SWING GATE: the hero clip's time-to-impact is what the presenter holds AttackRolled open for, so
///    the damage number lands on the strike frame; enemies (no swing art) must refuse the clip.
///  - POPUP HEIGHT: a rat's number has to sit over a rat, not at the fixed height a hero's bar used.
///  - SHAKE: trauma decays to exactly zero and the pivot returns to exactly the origin.
///
/// Run: Godot_v4.6.2-stable_mono_win64_console.exe --headless --path delve
///      res://scenes/dev/combat_juice_spike.tscn
/// </summary>
public partial class CombatJuiceSpike : SpikeBase
{
    private static readonly PackedScene UnitTokenScene =
        GD.Load<PackedScene>("res://scenes/combat/unit_token.tscn");

    protected override string Banner => "==================== COMBAT JUICE SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        // Settle burn-in: the frame after the synchronous content load reports an inflated delta,
        // which would hand any Tween created in it a false head start.
        for (int i = 0; i < 60; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        await RunCritDegree(data);
        await RunPresenterFx(data);
        await RunTokenJuice(data);
        RunPopupStyling();
        await RunShake();
    }

    // ─────────────────────── crit degree on weapon strikes ───────────────────────

    private async Task RunCritDegree(DataManager data)
    {
        GD.Print("-------------------- strike degree --------------------");

        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var g1 = CreatureFactory.Create(goblinDef, teamId: 2);
        var g2 = CreatureFactory.Create(goblinDef, teamId: 2);

        var session = new CombatSession();
        session.Setup(new CombatSetup
        {
            GridWidth = 12,
            GridHeight = 10,
            RngSeed = 99,
            Party = { (veteran, new PF2eVec(1, 4)) },
            Enemies = { (g1, new PF2eVec(6, 3)), (g2, new PF2eVec(6, 5)) },
        });

        // Record the stream instead of animating it: this block is about what the executors EMIT.
        var events = new List<(BattleEventType Type, DegreeOfSuccess? Degree, bool FromStrike)>();
        bool lastWasAttackRoll = false;
        session.SetPresenter(evt =>
        {
            if (evt.Type is BattleEventType.DamageDealt or BattleEventType.AttackRolled)
                events.Add((evt.Type, evt.Degree, lastWasAttackRoll));
            lastWasAttackRoll = evt.Type == BattleEventType.AttackRolled;
            return Task.CompletedTask;
        });
        session.PlayerTurnStarted += ch => { _ = DrivePlayerTurn(ch, session); };

        await session.RunAsync();
        session.Teardown();

        int attacks = 0, damages = 0, damageAfterRoll = 0, degreeless = 0, crits = 0;
        foreach (var e in events)
        {
            if (e.Type == BattleEventType.AttackRolled) { attacks++; continue; }
            damages++;
            if (!e.FromStrike) continue;
            damageAfterRoll++;
            if (!e.Degree.HasValue) degreeless++;
            else if (e.Degree.Value == DegreeOfSuccess.CriticalSuccess) crits++;
        }

        GD.Print($"[juice] {attacks} attack rolls, {damages} damage events "
                 + $"({damageAfterRoll} straight off a roll, {crits} critical)");
        Check("the fight actually rolled attacks and dealt damage", attacks > 0 && damageAfterRoll > 0);
        Check("every strike's DamageDealt carries the roll's degree (0 degreeless)", degreeless == 0);
        // Not asserted as a hard requirement — a seeded fight need not contain a crit — but a run that
        // finds one has proven the whole chain end to end, so say which happened.
        GD.Print(crits > 0
            ? $"[juice] {crits} critical hit(s) reached the view with Degree.CriticalSuccess"
            : "[juice] no crit rolled this seed; the degreeless count above is the load-bearing check");
    }

    /// <summary>Minimal turn driver — strike whatever is in reach, else close the distance. Mirrors
    /// PlayerTurnSpike's, trimmed to what this spike needs (no MAP assertions).</summary>
    private static async Task DrivePlayerTurn(ICharacter c, CombatSession session)
    {
        var exec = session.PlayerActions;
        while ((c.Actions?.TotalActionsRemaining ?? 0) > 0)
        {
            var targets = exec.GetStrikeTargets(c);
            if (targets.Count > 0)
            {
                if (!await exec.ExecuteStrike(c, targets[0])) break;
                continue;
            }
            var dest = ClosestApproach(exec, c);
            if (dest == null || !await exec.ExecuteStride(c, dest.Value)) break;
        }
        session.RequestEndPlayerTurn();
    }

    private static PF2eVec? ClosestApproach(PlayerActionExecutor exec, ICharacter c)
    {
        var reachable = exec.GetReachableTiles(c);
        if (reachable.Count == 0) return null;

        var enemies = new List<PF2eVec>();
        foreach (var e in CombatantRegistry.Instance.All)
            if (e.TeamId != c.TeamId && e.Health?.IsAlive == true)
                enemies.Add(e.GridPosition);
        if (enemies.Count == 0) return null;

        PF2eVec? best = null;
        int bestDist = int.MaxValue;
        foreach (var tile in reachable)
        {
            int d = int.MaxValue;
            foreach (var e in enemies)
                d = Math.Min(d, Math.Max(Math.Abs(tile.x - e.x), Math.Abs(tile.y - e.y)));
            if (d < bestDist) { bestDist = d; best = tile; }
        }
        return best;
    }

    // ─────────────────────── presenter FX spawns ───────────────────────

    private async Task RunPresenterFx(DataManager data)
    {
        GD.Print("-------------------- presenter FX --------------------");

        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        hero.GridPosition = new PF2eVec(2, 2);
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var enemy = CreatureFactory.Create(goblinDef, teamId: 2);
        enemy.GridPosition = new PF2eVec(3, 2);

        var popupLayer = new Node3D { Name = "PopupLayer" };
        AddChild(popupLayer);
        var heroToken = AddToken(hero, null);
        var enemyToken = AddToken(enemy, EnemySpriteMap.FolderForCreature(enemy.Name, enemy.CreatureStats.Size));

        var shake = new ShakePivot { Name = "ShakePivot" };
        AddChild(shake);

        var presenter = new GodotPresenter3D(popupLayer, Delve.Terrain.TerrainHeightMap.Flat)
        {
            Shake = shake,
        };
        presenter.RegisterUnit(hero, heroToken);
        presenter.RegisterUnit(enemy, enemyToken);

        // --- swing clip: heroes have the art, enemies do not ---
        Check("hero swing gate matches the chop clip's time to impact "
              + $"({UnitVisual3D.SwingImpactDelay:0.###}s)",
            Mathf.IsEqualApprox(UnitVisual3D.SwingImpactDelay, ManaSeedSheet.Chop.TimeToImpact));
        Check("the chop clip's impact really is mid-swing, not on the press",
            UnitVisual3D.SwingImpactDelay > 0f
            && UnitVisual3D.SwingImpactDelay < ManaSeedSheet.Chop.Duration);
        Check("a hero token starts the swing clip", heroToken.PlaySwing());
        Check("an enemy token refuses it (no swing art)", !enemyToken.PlaySwing());
        // Let the clip run itself out so it cannot bleed into the event presentation below.
        await WaitSeconds(ManaSeedSheet.Chop.Duration + 0.1f);

        // Every effect in scripts/fx frees ITSELF once its lifetime elapses, so a before/after diff
        // spanning an awaited event gate would silently net a departing effect against an arriving one.
        // Each measurement below therefore starts from a genuinely empty board.

        // --- a landed hit sparks; a miss does not ---
        await SettleFx();
        await presenter.Present(Damage(hero, enemy, 7, DegreeOfSuccess.Success));
        Check($"DamageDealt spawns a hit spark ({FxCount()} Fx)", FxCount() == 1);
        // The struck unit's own number, captured while it is still alive (popups self-free too).
        float enemyPopupY = FindPopupAbove(popupLayer, enemyToken)?.Position.Y ?? float.NaN;

        await SettleFx();
        await presenter.Present(new BattleEvent
        {
            Type = BattleEventType.AttackRolled,
            Source = enemy,
            Target = hero,
            Degree = DegreeOfSuccess.Failure,
        });
        Check("a missed AttackRolled spawns no FX (the defender ducks instead)", FxCount() == 0);

        // --- heal / shield each get their own effect ---
        await SettleFx();
        await presenter.Present(new BattleEvent
        {
            Type = BattleEventType.Healed, Source = hero, Target = hero, IntValue = 4,
        });
        Check($"Healed spawns heal motes ({FxCount()} Fx)", FxCount() == 1);
        float heroPopupY = FindPopupAbove(popupLayer, heroToken)?.Position.Y ?? float.NaN;

        await SettleFx();
        await presenter.Present(new BattleEvent { Type = BattleEventType.ShieldRaised, Source = hero });
        Check($"ShieldRaised spawns a shield flash ({FxCount()} Fx)", FxCount() == 1);

        // --- trauma reaches the camera ---
        // Read the moment Present yields, not after awaiting it: the trauma is added synchronously at
        // the top of each case and has fully decayed again by the time that event's gate closes, which
        // is exactly the behaviour wanted in play (the board settles before the next actor moves).
        await SettleFx();
        var critTask = presenter.Present(Damage(hero, enemy, 14, DegreeOfSuccess.CriticalSuccess));
        float critTrauma = shake.Trauma;
        await critTask;
        Check($"a critical hit kicks the camera ({critTrauma:0.###} trauma)", critTrauma > 0f);
        Check("and the kick is spent by the time the hit's gate closes", shake.Trauma < critTrauma);

        await SettleFx();
        var deathTask = presenter.Present(new BattleEvent
        {
            Type = BattleEventType.CreatureDied, Source = enemy,
        });
        float deathTrauma = shake.Trauma;
        Check($"CreatureDied spawns a death poof ({FxCount()} Fx)", FxCount() == 1);
        await deathTask;
        Check($"a death kicks the camera harder than a crit ({deathTrauma:0.###} vs {critTrauma:0.###})",
            deathTrauma > critTrauma);

        // --- popup height follows each unit's own silhouette ---
        Check("a hero's HP bar sits higher than a rat-scaled enemy's",
            heroToken.HpBarHeight > enemyToken.HpBarHeight);
        Check("a popup spawned over each unit",
            !float.IsNaN(heroPopupY) && !float.IsNaN(enemyPopupY));
        Check("each popup clears its OWN unit's HP bar, not a fixed height",
            heroPopupY > heroToken.Position.Y + heroToken.HpBarHeight
            && enemyPopupY > enemyToken.Position.Y + enemyToken.HpBarHeight);
        Check($"a rat's number therefore floats lower than a hero's ({enemyPopupY:0.##} < {heroPopupY:0.##})",
            enemyPopupY < heroPopupY);

        popupLayer.QueueFree();
        heroToken.QueueFree();
        enemyToken.QueueFree();
        shake.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private static BattleEvent Damage(ICharacter source, ICharacter target, int amount, DegreeOfSuccess degree)
        => new()
        {
            Type = BattleEventType.DamageDealt,
            Source = source,
            Target = target,
            IntValue = amount,
            DamageType = PF2e.Data.DamageType.Slashing,
            Degree = degree,
        };

    private UnitVisual3D AddToken(ICharacter character, string? enemyFolder)
    {
        var token = UnitVisual3D.Spawn(UnitTokenScene, character, enemyFolder);
        token.Position = new Vector3(character.GridPosition.x + 0.5f, 0f, character.GridPosition.y + 0.5f);
        AddChild(token);
        return token;
    }

    /// <summary>The most recent popup standing over a given token (popups are spawned on the token's
    /// own XZ, so matching on that is unambiguous).</summary>
    private static DamagePopup3D? FindPopupAbove(Node layer, UnitVisual3D token)
    {
        DamagePopup3D? found = null;
        foreach (Node child in layer.GetChildren())
            if (child is DamagePopup3D popup
                && Mathf.IsEqualApprox(popup.Position.X, token.Position.X)
                && Mathf.IsEqualApprox(popup.Position.Z, token.Position.Z))
                found = popup;
        return found;
    }

    private int FxCount() => GetTree().GetNodesInGroup(OneShotFx.FxGroup).Count;

    /// <summary>Wait until no one-shot effect is left alive, so the next spawn can be counted absolutely
    /// rather than as a diff. Capped so a hypothetical effect that never frees itself fails the count
    /// it was measuring instead of hanging the spike.</summary>
    private async Task SettleFx()
    {
        const float cap = 2f; // comfortably past the longest Lifetime in scripts/fx (HealMotes, 0.9 s)
        float waited = 0f;
        while (FxCount() > 0 && waited < cap)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            waited += 1f / 60f;
        }
    }

    // ─────────────────────── token-local juice ───────────────────────

    /// <summary>
    /// The bits of feedback that live on the token itself and leave no spawned node behind: the hurt
    /// flinch, the dodge lean, the travelling HP bar and the active-turn ring. Each is checked the same
    /// way — that it MOVES (so it is not a no-op) and that it comes back to rest (so a flurry cannot
    /// accumulate an offset, which is the failure mode the single-tween-handle rule exists to prevent).
    /// </summary>
    private async Task RunTokenJuice(DataManager data)
    {
        GD.Print("-------------------- token juice --------------------");

        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        hero.GridPosition = new PF2eVec(1, 1);
        var token = AddToken(hero, null);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        var sprite = token.GetNode<BillboardSpriteAnimator>("%Sprite").Sprite;
        var ring = token.GetNode<MeshInstance3D>("%Ring");
        var fill = token.GetNode<WorldHpBar>("%HpBar").Fill;
        Vector3 spriteRest = sprite.Position;

        // --- hurt flinch ---
        token.PlayHurtShake();
        await WaitSeconds(0.04f);
        Check("a hit flinches the target's sprite", sprite.Position != spriteRest);
        await WaitSeconds(0.25f);
        Check("and the flinch returns it to rest", sprite.Position.IsEqualApprox(spriteRest));

        // --- dodge lean, away from the attacker ---
        token.PlayDodgeLean(new Vector3(1f, 0f, 0f));
        await WaitSeconds(0.05f);
        Check("a whiffed attack leans the defender away from it",
            sprite.Position.X > spriteRest.X + 0.01f);
        await WaitSeconds(0.3f);
        Check("and the lean springs back to rest", sprite.Position.IsEqualApprox(spriteRest));

        // --- HP bar travels rather than snapping ---
        float fullWidth = fill.Scale.X;
        hero.Health.SetCurrentHP(hero.Health.MaxHP / 4);
        token.UpdateHealthBar();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("the HP bar is still on its way down a frame after the hit (it tweens, not snaps)",
            fill.Scale.X < fullWidth && fill.Scale.X > 0.3f);
        await WaitSeconds(0.3f);
        Check($"and it arrives at the new value ({fill.Scale.X:0.##} of {fullWidth:0.##})",
            Mathf.IsEqualApprox(fill.Scale.X, 0.25f, 0.02f));

        // --- active-turn ring ---
        Vector3 ringRest = ring.Scale;
        token.SetActive(true);
        await WaitSeconds(0.09f);
        float popped = ring.Scale.X;
        Check($"the active ring pops in past its resting size ({popped:0.##})", popped > ringRest.X);
        // Past the pop and into the loop: the breath keeps it moving instead of parking on one size.
        await WaitSeconds(0.5f);
        float pulseA = ring.Scale.X;
        await WaitSeconds(0.35f);
        Check($"and then breathes continuously ({pulseA:0.###} -> {ring.Scale.X:0.###})",
            !Mathf.IsEqualApprox(pulseA, ring.Scale.X));

        token.SetActive(false);
        Check("deactivating kills the pulse and snaps the ring back", ring.Scale.IsEqualApprox(ringRest));
        await WaitSeconds(0.4f);
        Check("and nothing re-grows it afterwards", ring.Scale.IsEqualApprox(ringRest));

        token.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    // ─────────────────────── popup styling ───────────────────────

    private void RunPopupStyling()
    {
        GD.Print("-------------------- popup styling --------------------");

        var ordinary = DamagePopup3D.Create(7, null, DegreeOfSuccess.Success);
        var crit = DamagePopup3D.Create(14, null, DegreeOfSuccess.CriticalSuccess);
        var miss = DamagePopup3D.Create(0, null, DegreeOfSuccess.Failure);

        Check($"a crit's number is bigger than an ordinary hit's ({crit.FontSize} vs {ordinary.FontSize})",
            crit.FontSize > ordinary.FontSize);
        Check("a crit's number is red where an ordinary hit's is white",
            crit.Modulate.R > crit.Modulate.G && ordinary.Modulate.IsEqualApprox(Colors.White));
        Check("a miss reads MISS", miss.Text == "MISS");

        ordinary.QueueFree();
        crit.QueueFree();
        miss.QueueFree();
    }

    // ─────────────────────── camera shake ───────────────────────

    private async Task RunShake()
    {
        GD.Print("-------------------- camera shake --------------------");

        var shake = new ShakePivot { Name = "ShakeProbe" };
        AddChild(shake);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        shake.AddTrauma(1.5f);
        Check("trauma clamps to 1", Mathf.IsEqualApprox(shake.Trauma, 1f));

        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        float offset = shake.Position.Length();
        Check($"a traumatised pivot actually displaces the camera ({offset:0.###} m)", offset > 0f);
        Check("and never further than its authored maximum", offset <= shake.MaxOffset * 1.74f);

        float traumaEarly = shake.Trauma;
        await WaitSeconds(0.2f);
        Check($"trauma decays ({traumaEarly:0.##} -> {shake.Trauma:0.##})", shake.Trauma < traumaEarly);

        // Full decay from trauma 1 at 1.5/s takes ~0.67 s; wait past it plus a frame to settle.
        await WaitSeconds(1f / shake.DecayPerSecond + 0.2f);
        Check("trauma reaches exactly zero", shake.Trauma == 0f);
        Check("and the pivot returns to exactly the origin", shake.Position == Vector3.Zero);

        shake.QueueFree();
    }

    // ─────────────────────── harness ───────────────────────

    private async Task WaitSeconds(float seconds)
    {
        if (seconds <= 0f)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            return;
        }
        var timer = GetTree().CreateTimer(seconds);
        await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
    }
}
