using System;
using System.Collections.Generic;
using PF2e.Core;
using PF2e.RuleEvents.Reactions;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>Translates the engine's reaction context into the compact prompt view. Read-only.</summary>
internal static class ReactionPromptBuilder
{
    internal static ReactionPromptView Build(ReactionPromptContext ctx)
    {
        string description = ctx.PromptInfo.Description ?? "";
        var figures = new List<FigureView>();
        string accept = "Use";

        if (string.IsNullOrEmpty(description))
        {
            switch (ctx.Trigger)
            {
                case ReactionTrigger.Damage:
                    description = ShieldBlock(ctx, figures);
                    if (figures.Count > 0) accept = "Block";
                    break;
                case ReactionTrigger.Movement:
                    description = $"Strike {ctx.Source?.Name ?? "the enemy"} as they leave your reach.";
                    accept = "Strike";
                    AddStrikeFigures(ctx, figures);
                    break;
                case ReactionTrigger.Action:
                    description = $"Strike {ctx.Source?.Name ?? "the enemy"} as they act within your reach.";
                    accept = "Strike";
                    AddStrikeFigures(ctx, figures);
                    break;
                default:
                    description = $"Spend your reaction to use {ctx.ReactionName}.";
                    break;
            }
        }
        else if (ctx.PromptInfo.Style == ReactionPromptStyle.AttackPreview)
        {
            accept = "Strike";
            AddStrikeFigures(ctx, figures);
        }

        return new ReactionPromptView
        {
            ReactorName = ctx.Reactor.Name,
            ReactorId = ctx.Reactor.UniqueId,
            SourceId = ctx.Source?.UniqueId,
            ReactionName = ctx.ReactionName,
            Title = $"{ctx.ReactionName}?",
            AcceptLabel = accept,
            Figures = figures,
            Trigger = Trigger(ctx),
            Description = description,
        };
    }

    /// <summary>What set the reaction off, in one sentence, so the prompt says why it appeared.</summary>
    private static string Trigger(ReactionPromptContext ctx)
    {
        string source = ctx.Source?.Name ?? "An enemy";
        string reactor = ctx.Reactor.Name;
        return ctx.Trigger switch
        {
            ReactionTrigger.Damage => $"{source} hits {(ctx.ProtectedAlly ?? ctx.Reactor).Name} for {ctx.Damage?.TotalDamage ?? 0}.",
            ReactionTrigger.Movement => $"{source} leaves {reactor}'s reach.",
            ReactionTrigger.Action => $"{source} acts within {reactor}'s reach.",
            _ => "",
        };
    }

    private static string ShieldBlock(ReactionPromptContext ctx, List<FigureView> figures)
    {
        int incoming = ctx.Damage?.TotalDamage ?? 0;
        var shield = ctx.Reactor.Equipment?.EquippedShield;
        int absorbed = Math.Min(shield?.Hardness ?? 0, incoming);
        int rest = incoming - absorbed;
        string target = (ctx.ProtectedAlly ?? ctx.Reactor).Name;
        string attacker = ctx.Source?.Name ?? "An enemy";
        string description = $"{attacker} hits {target} for {incoming} damage.\n"
            + $"Blocking stops {absorbed}. {target} and the shield each take {rest}.";
        if (shield == null) return description;

        int after = Math.Max(0, shield.CurrentHP - rest);
        bool broken = after <= shield.BrokenThreshold;
        description += after == 0 ? " The shield is destroyed."
            : broken ? $" The shield breaks ({after} of {shield.MaxHP} HP)."
            : $" The shield drops to {after} of {shield.MaxHP} HP.";
        figures.Add(new FigureView(target, rest.ToString()) { Before = incoming.ToString() });
        figures.Add(new FigureView(after == 0 ? "Shield destroyed" : broken ? "Shield breaks" : "Shield",
            after.ToString()) { Before = shield.CurrentHP.ToString() });
        return description;
    }

    private static void AddStrikeFigures(ReactionPromptContext ctx, List<FigureView> figures)
    {
        if (ctx.Source == null) return;
        AttackPreviewView preview;
        try
        {
            preview = ActionBarStateBuilder.BuildPreview(
                CombatPreviewCalculator.CalculateAttackPreview(ctx.Reactor, ctx.Source, mapOverride: 0));
        }
        catch (Exception e)
        {
            Godot.GD.PushWarning($"[ReactionPrompt] {ctx.ReactionName} forecast failed, so the prompt shows no hit chance: {e.Message}");
            return;
        }
        // The forecast's lead figure: "Hit 75%", or "Attack +7" while the target's AC is masked.
        if (preview.Figures.Count > 0) figures.Add(preview.Figures[0]);
        if (preview.DamageFormula.Length > 0) figures.Add(new FigureView("Damage", preview.DamageFormula));
    }
}
