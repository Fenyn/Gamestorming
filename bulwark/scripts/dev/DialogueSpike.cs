using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Bulwark.Cozy;
using Bulwark.Data.Dialogues;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification for the DIALOGUE and CUTSCENE framework (design/dialogue.md). Exercises
/// the data model (JSON deserialization), condition evaluation, the DialogueRunner state machine
/// (linear, choice branching, staging commands, effects), the DialogueDatabase (load + query),
/// and seen-dialogue tracking. Uses SYNTHETIC JSON — no real dialogue content files.
/// </summary>
public partial class DialogueSpike : SpikeBase
{
    private string? _tempDir;

    public override void _Ready()
    {
        GD.Print("==================== DIALOGUE SPIKE ====================");

        try
        {
            _tempDir = Path.Combine(Path.GetTempPath(), $"bulwark_dialogue_spike_{Guid.NewGuid():N}");
            Directory.CreateDirectory(_tempDir);

            RunDataModelSequence();       // (A)
            RunDataModelTalkPool();       // (B)
            RunConditionEvaluation();     // (C)
            RunLinearSequence();          // (D)
            RunChoiceBranching();         // (E)
            RunStagingCommands();         // (F)
            RunEffects();                 // (G)
            RunDatabaseLoadAndQuery();    // (H)
            RunSeenTracking();            // (I)
            RunConditionGating();         // (J)
        }
        catch (Exception e)
        {
            GD.PushError($"[DialogueSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            CleanupTemp();
        }

        FinishAndQuit("DialogueSpike");
    }

    // ─────────────────────────── (A) Data model: sequence deserialization ───────────────────────────

    private void RunDataModelSequence()
    {
        GD.Print("-------------------- (A) Data model: sequence deserialization --------------------");

        string json = @"{
            ""id"": ""test_seq"",
            ""type"": ""Sequence"",
            ""once"": true,
            ""conditions"": {
                ""hearts"": { ""tharr"": 2 },
                ""flags_required"": [""flag_a""],
                ""flags_blocked"": [""flag_b""]
            },
            ""steps"": [
                { ""type"": ""line"", ""speaker"": ""tharr"", ""text"": ""Hello there."", ""emotion"": ""happy"" },
                { ""type"": ""fade"", ""direction"": ""out"", ""duration"": 0.5 },
                { ""type"": ""fade"", ""direction"": ""in"", ""duration"": 0.5 },
                {
                    ""type"": ""choice"",
                    ""speaker"": ""tharr"",
                    ""text"": ""What do you think?"",
                    ""options"": [
                        {
                            ""text"": ""Option A"",
                            ""effects"": [{ ""type"": ""friendship"", ""character"": ""tharr"", ""amount"": 20 }],
                            ""steps"": [
                                { ""type"": ""line"", ""speaker"": ""tharr"", ""text"": ""Good choice."" }
                            ]
                        },
                        {
                            ""text"": ""Option B"",
                            ""next_id"": ""test_seq_b""
                        }
                    ]
                },
                { ""type"": ""flag"", ""set"": ""test_flag"" },
                { ""type"": ""exit"", ""actor"": ""tharr"" }
            ]
        }";

        var opts = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
        };
        var file = JsonSerializer.Deserialize<DialogueFile>(json, opts);

        Check("(A) deserializes non-null", file != null);
        Check("(A) id = test_seq", file!.Id == "test_seq");
        Check("(A) type = Sequence", file.Type == DialogueType.Sequence);
        Check("(A) once = true", file.Once);
        Check("(A) conditions non-null", file.Conditions != null);
        Check("(A) hearts gate: tharr >= 2", file.Conditions!.Hearts != null && file.Conditions.Hearts["tharr"] == 2);
        Check("(A) flags_required: [flag_a]",
            file.Conditions.FlagsRequired != null && file.Conditions.FlagsRequired.Count == 1
            && file.Conditions.FlagsRequired[0] == "flag_a");
        Check("(A) flags_blocked: [flag_b]",
            file.Conditions.FlagsBlocked != null && file.Conditions.FlagsBlocked.Count == 1
            && file.Conditions.FlagsBlocked[0] == "flag_b");
        Check("(A) step count = 6", file.Steps != null && file.Steps.Count == 6);
        Check("(A) step 0 = line", file.Steps![0].Type == "line" && file.Steps[0].Speaker == "tharr");
        Check("(A) step 0 emotion = happy", file.Steps[0].Emotion == "happy");
        Check("(A) step 1 = fade out", file.Steps[1].Type == "fade" && file.Steps[1].Direction == "out");
        Check("(A) step 3 = choice with 2 options",
            file.Steps[3].Type == "choice" && file.Steps[3].Options != null && file.Steps[3].Options.Count == 2);
        Check("(A) choice option 0 has effects",
            file.Steps[3].Options![0].Effects != null && file.Steps[3].Options[0].Effects!.Count == 1
            && file.Steps[3].Options[0].Effects[0].Type == "friendship"
            && file.Steps[3].Options[0].Effects[0].Character == "tharr"
            && file.Steps[3].Options[0].Effects[0].Amount == 20);
        Check("(A) choice option 0 has inline steps",
            file.Steps[3].Options[0].Steps != null && file.Steps[3].Options[0].Steps!.Count == 1);
        Check("(A) choice option 1 has next_id",
            file.Steps[3].Options[1].NextId == "test_seq_b");
        Check("(A) step 4 = flag set", file.Steps[4].Type == "flag" && file.Steps[4].Set == "test_flag");
        Check("(A) step 5 = exit actor", file.Steps[5].Type == "exit" && file.Steps[5].Actor == "tharr");
    }

    // ─────────────────────────── (B) Data model: talk pool deserialization ───────────────────────────

    private void RunDataModelTalkPool()
    {
        GD.Print("-------------------- (B) Data model: talk pool deserialization --------------------");

        string json = @"{
            ""id"": ""test_talk"",
            ""type"": ""TalkPool"",
            ""character"": ""tharr"",
            ""entries"": [
                {
                    ""priority"": 0,
                    ""conditions"": {},
                    ""lines"": [
                        { ""speaker"": ""tharr"", ""text"": ""Default line."", ""emotion"": ""neutral"" }
                    ]
                },
                {
                    ""priority"": 10,
                    ""conditions"": { ""hearts"": { ""tharr"": 4 }, ""season"": ""summer"" },
                    ""lines"": [
                        { ""speaker"": ""tharr"", ""text"": ""Summer line 1."", ""emotion"": ""amused"" },
                        { ""speaker"": ""tharr"", ""text"": ""Summer line 2."" }
                    ]
                }
            ]
        }";

        var opts = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
        };
        var file = JsonSerializer.Deserialize<DialogueFile>(json, opts);

        Check("(B) deserializes non-null", file != null);
        Check("(B) type = TalkPool", file!.Type == DialogueType.TalkPool);
        Check("(B) character = tharr", file.Character == "tharr");
        Check("(B) entries count = 2", file.Entries != null && file.Entries.Count == 2);
        Check("(B) entry 0 priority = 0", file.Entries![0].Priority == 0);
        Check("(B) entry 0 has 1 line", file.Entries[0].Lines.Count == 1);
        Check("(B) entry 0 line speaker", file.Entries[0].Lines[0].Speaker == "tharr");
        Check("(B) entry 0 line text", file.Entries[0].Lines[0].Text == "Default line.");
        Check("(B) entry 1 priority = 10", file.Entries[1].Priority == 10);
        Check("(B) entry 1 conditions: hearts tharr >= 4",
            file.Entries[1].Conditions != null && file.Entries[1].Conditions!.Hearts != null
            && file.Entries[1].Conditions.Hearts["tharr"] == 4);
        Check("(B) entry 1 conditions: season = summer",
            file.Entries[1].Conditions!.Season == "summer");
        Check("(B) entry 1 has 2 lines", file.Entries[1].Lines.Count == 2);
        Check("(B) entry 1 line 1 emotion absent (null)", file.Entries[1].Lines[1].Emotion == null);
    }

    // ─────────────────────────── (C) Condition evaluation ───────────────────────────

    private void RunConditionEvaluation()
    {
        GD.Print("-------------------- (C) DialogueConditionContext: condition evaluation --------------------");

        var flags = new HashSet<string> { "flag_a", "flag_c" };
        var hearts = new Dictionary<string, int> { ["tharr"] = 3, ["elara"] = 1 };
        var seen = new HashSet<string> { "seen_seq" };

        var ctx = new DialogueConditionContext
        {
            HasFlag = flags.Contains,
            GetHearts = id => hearts.TryGetValue(id, out var h) ? h : 0,
            CurrentSeason = "summer",
            HasSeenDialogue = seen.Contains,
        };

        // Null condition always passes
        Check("(C) null condition passes", DialogueConditionContext.EvaluateCondition(null, ctx));

        // Empty condition passes
        Check("(C) empty condition passes",
            DialogueConditionContext.EvaluateCondition(new DialogueCondition(), ctx));

        // Hearts gate
        Check("(C) hearts tharr >= 2 passes (has 3)",
            DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { Hearts = new Dictionary<string, int> { ["tharr"] = 2 } }, ctx));
        Check("(C) hearts tharr >= 5 fails (has 3)",
            !DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { Hearts = new Dictionary<string, int> { ["tharr"] = 5 } }, ctx));
        Check("(C) hearts unknown char >= 1 fails (has 0)",
            !DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { Hearts = new Dictionary<string, int> { ["nobody"] = 1 } }, ctx));

        // Flags required
        Check("(C) flags_required [flag_a] passes",
            DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { FlagsRequired = new List<string> { "flag_a" } }, ctx));
        Check("(C) flags_required [flag_a, flag_c] passes (both set)",
            DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { FlagsRequired = new List<string> { "flag_a", "flag_c" } }, ctx));
        Check("(C) flags_required [flag_b] fails (not set)",
            !DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { FlagsRequired = new List<string> { "flag_b" } }, ctx));

        // Flags blocked
        Check("(C) flags_blocked [flag_b] passes (flag_b not set)",
            DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { FlagsBlocked = new List<string> { "flag_b" } }, ctx));
        Check("(C) flags_blocked [flag_a] fails (flag_a IS set)",
            !DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { FlagsBlocked = new List<string> { "flag_a" } }, ctx));

        // Season
        Check("(C) season = summer passes",
            DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { Season = "summer" }, ctx));
        Check("(C) season = winter fails",
            !DialogueConditionContext.EvaluateCondition(
                new DialogueCondition { Season = "winter" }, ctx));

        // Seen check (via the context)
        Check("(C) HasSeenDialogue returns true for seen id", ctx.HasSeenDialogue("seen_seq"));
        Check("(C) HasSeenDialogue returns false for unseen id", !ctx.HasSeenDialogue("unseen_seq"));
    }

    // ─────────────────────────── (D) DialogueRunner: linear sequence ───────────────────────────

    private void RunLinearSequence()
    {
        GD.Print("-------------------- (D) DialogueRunner: linear sequence --------------------");

        var steps = new List<DialogueStep>
        {
            new() { Type = "line", Speaker = "alice", Text = "Line one.", Emotion = "happy" },
            new() { Type = "line", Speaker = "bob", Text = "Line two." },
            new() { Type = "line", Speaker = "alice", Text = "Line three.", Emotion = "sad" },
        };

        var handler = new StubEffectHandler();
        var runner = new DialogueRunner(steps, handler);

        var lines = new List<(string Speaker, string Text, string Emotion)>();
        bool ended = false;
        runner.LineReady += (s, t, e, _) => lines.Add((s, t, e));
        runner.SequenceEnded += () => ended = true;

        runner.Start();
        Check("(D) after Start: running", runner.IsRunning);
        Check("(D) after Start: waiting for advance", runner.IsWaitingForAdvance);
        Check("(D) line 1 fired", lines.Count == 1 && lines[0].Speaker == "alice" && lines[0].Text == "Line one.");
        Check("(D) line 1 emotion = happy", lines[0].Emotion == "happy");

        runner.Advance();
        Check("(D) line 2 fired", lines.Count == 2 && lines[1].Speaker == "bob" && lines[1].Text == "Line two.");
        Check("(D) line 2 emotion defaults to neutral", lines[1].Emotion == "neutral");

        runner.Advance();
        Check("(D) line 3 fired", lines.Count == 3 && lines[2].Speaker == "alice");

        runner.Advance();
        Check("(D) SequenceEnded fired", ended);
        Check("(D) runner no longer running", !runner.IsRunning);
    }

    // ─────────────────────────── (E) DialogueRunner: choice branching ───────────────────────────

    private void RunChoiceBranching()
    {
        GD.Print("-------------------- (E) DialogueRunner: choice branching --------------------");

        var steps = new List<DialogueStep>
        {
            new() { Type = "line", Speaker = "npc", Text = "Before choice." },
            new()
            {
                Type = "choice",
                Speaker = "npc",
                Text = "Pick one.",
                Options = new List<DialogueOption>
                {
                    new()
                    {
                        Text = "Option A",
                        Steps = new List<DialogueStep>
                        {
                            new() { Type = "line", Speaker = "npc", Text = "You picked A." },
                        },
                    },
                    new()
                    {
                        Text = "Option B",
                        Steps = new List<DialogueStep>
                        {
                            new() { Type = "line", Speaker = "npc", Text = "You picked B." },
                        },
                    },
                },
            },
            new() { Type = "line", Speaker = "npc", Text = "After choice." },
        };

        var handler = new StubEffectHandler();
        var runner = new DialogueRunner(steps, handler);

        var lines = new List<string>();
        List<string>? choiceLabels = null;
        bool ended = false;
        runner.LineReady += (_, t, _, _) => lines.Add(t);
        runner.ChoicesReady += opts => choiceLabels = opts;
        runner.SequenceEnded += () => ended = true;

        runner.Start();
        Check("(E) line 1: Before choice", lines.Count == 1 && lines[0] == "Before choice.");

        runner.Advance();
        Check("(E) choice prompt fires LineReady", lines.Count == 2 && lines[1] == "Pick one.");
        Check("(E) ChoicesReady fires with 2 options",
            choiceLabels != null && choiceLabels.Count == 2
            && choiceLabels[0] == "Option A" && choiceLabels[1] == "Option B");
        Check("(E) runner is waiting for choice", runner.IsWaitingForChoice);

        runner.SelectChoice(0); // Pick Option A
        Check("(E) inline step: You picked A", lines.Count == 3 && lines[2] == "You picked A.");

        runner.Advance();
        Check("(E) after inline: After choice", lines.Count == 4 && lines[3] == "After choice.");

        runner.Advance();
        Check("(E) sequence ends", ended);

        // Test next_id jump
        var jumpSteps = new List<DialogueStep>
        {
            new()
            {
                Type = "choice",
                Speaker = "npc",
                Text = "Jump?",
                Options = new List<DialogueOption>
                {
                    new() { Text = "Jump", NextId = "other_seq" },
                },
            },
        };
        var jumpRunner = new DialogueRunner(jumpSteps, handler);
        string? jumpTarget = null;
        jumpRunner.SequenceJumpRequested += id => jumpTarget = id;
        jumpRunner.Start();
        jumpRunner.SelectChoice(0);
        Check("(E) next_id fires SequenceJumpRequested", jumpTarget == "other_seq");
    }

    // ─────────────────────────── (F) DialogueRunner: staging commands ───────────────────────────

    private void RunStagingCommands()
    {
        GD.Print("-------------------- (F) DialogueRunner: staging commands --------------------");

        var steps = new List<DialogueStep>
        {
            new() { Type = "line", Speaker = "npc", Text = "Before staging." },
            new() { Type = "fade", Direction = "out", Duration = 0.5f },
            new() { Type = "wait", Seconds = 1.0f },
            new() { Type = "enter", Actor = "npc", Marker = "door" },
            new() { Type = "move", Actor = "npc", Marker = "table", Speed = 80f },
            new() { Type = "camera", Marker = "table", Duration = 1.0f },
            new() { Type = "exit", Actor = "npc" },
            new() { Type = "emote", Actor = "npc", Emotion = "happy" },
            new() { Type = "line", Speaker = "npc", Text = "After staging." },
        };

        var handler = new StubEffectHandler();
        var runner = new DialogueRunner(steps, handler);

        var stageCommands = new List<string>();
        var lines = new List<string>();
        bool ended = false;
        runner.LineReady += (_, t, _, _) => lines.Add(t);
        runner.StageCommand += step => stageCommands.Add(step.Type);
        runner.SequenceEnded += () => ended = true;

        runner.Start();
        Check("(F) line 1 fires first", lines.Count == 1 && lines[0] == "Before staging.");

        runner.Advance();
        Check("(F) fade command fires StageCommand", stageCommands.Count == 1 && stageCommands[0] == "fade");

        runner.StagingComplete();
        Check("(F) wait command fires after fade completes", stageCommands.Count == 2 && stageCommands[1] == "wait");

        runner.StagingComplete();
        Check("(F) enter command fires", stageCommands.Count == 3 && stageCommands[2] == "enter");

        runner.StagingComplete();
        Check("(F) move command fires", stageCommands.Count == 4 && stageCommands[3] == "move");

        runner.StagingComplete();
        Check("(F) camera command fires", stageCommands.Count == 5 && stageCommands[4] == "camera");

        runner.StagingComplete();
        Check("(F) exit command fires", stageCommands.Count == 6 && stageCommands[5] == "exit");

        runner.StagingComplete();
        Check("(F) emote command fires", stageCommands.Count == 7 && stageCommands[6] == "emote");

        runner.StagingComplete();
        Check("(F) line 2 fires after staging", lines.Count == 2 && lines[1] == "After staging.");

        runner.Advance();
        Check("(F) sequence ends", ended);
    }

    // ─────────────────────────── (G) DialogueRunner: effects ───────────────────────────

    private void RunEffects()
    {
        GD.Print("-------------------- (G) DialogueRunner: effects (flag/friendship) --------------------");

        var steps = new List<DialogueStep>
        {
            new() { Type = "flag", Set = "talked_to_npc" },
            new() { Type = "friendship", Character = "tharr", Amount = 50 },
            new() { Type = "line", Speaker = "npc", Text = "Done." },
        };

        var handler = new StubEffectHandler();
        var runner = new DialogueRunner(steps, handler);

        var lines = new List<string>();
        runner.LineReady += (_, t, _, _) => lines.Add(t);

        runner.Start();
        // flag and friendship are immediate — the runner processes them and advances to the line
        Check("(G) flag effect invoked handler", handler.FlagsSet.Contains("talked_to_npc"));
        Check("(G) friendship effect invoked handler",
            handler.FriendshipAwarded.Count == 1
            && handler.FriendshipAwarded[0].CharId == "tharr"
            && handler.FriendshipAwarded[0].Amount == 50);
        Check("(G) line fires after effects", lines.Count == 1 && lines[0] == "Done.");

        // Choice with effects
        var choiceSteps = new List<DialogueStep>
        {
            new()
            {
                Type = "choice",
                Speaker = "npc",
                Text = "Choose.",
                Options = new List<DialogueOption>
                {
                    new()
                    {
                        Text = "With effects",
                        Effects = new List<StepEffect>
                        {
                            new() { Type = "friendship", Character = "elara", Amount = 30 },
                            new() { Type = "flag", Set = "chose_wisely" },
                            new() { Type = "item", ItemId = "wood", Quantity = 5 },
                        },
                    },
                },
            },
        };

        var handler2 = new StubEffectHandler();
        var runner2 = new DialogueRunner(choiceSteps, handler2);
        runner2.LineReady += (_, _, _, _) => { };
        runner2.ChoicesReady += _ => { };

        runner2.Start();
        runner2.SelectChoice(0);
        Check("(G) choice effect: friendship", handler2.FriendshipAwarded.Count == 1
            && handler2.FriendshipAwarded[0].CharId == "elara" && handler2.FriendshipAwarded[0].Amount == 30);
        Check("(G) choice effect: flag", handler2.FlagsSet.Contains("chose_wisely"));
        Check("(G) choice effect: item", handler2.ItemsGiven.Count == 1
            && handler2.ItemsGiven[0].ItemId == "wood" && handler2.ItemsGiven[0].Quantity == 5);
    }

    // ─────────────────────────── (H) DialogueDatabase: load + query ───────────────────────────

    private void RunDatabaseLoadAndQuery()
    {
        GD.Print("-------------------- (H) DialogueDatabase: load from temp dir, query --------------------");

        // Write synthetic JSON files
        string seqJson = @"{
            ""id"": ""spike_seq"",
            ""type"": ""Sequence"",
            ""once"": false,
            ""steps"": [
                { ""type"": ""line"", ""speaker"": ""alice"", ""text"": ""Hello from sequence."" }
            ]
        }";

        string talkJson = @"{
            ""id"": ""spike_talk"",
            ""type"": ""TalkPool"",
            ""character"": ""alice"",
            ""entries"": [
                {
                    ""priority"": 0,
                    ""lines"": [{ ""speaker"": ""alice"", ""text"": ""Default talk."" }]
                },
                {
                    ""priority"": 10,
                    ""conditions"": { ""hearts"": { ""alice"": 3 } },
                    ""lines"": [{ ""speaker"": ""alice"", ""text"": ""High hearts talk."" }]
                }
            ]
        }";

        string subDir = Path.Combine(_tempDir!, "sub");
        Directory.CreateDirectory(subDir);
        File.WriteAllText(Path.Combine(_tempDir!, "seq.json"), seqJson);
        File.WriteAllText(Path.Combine(subDir, "talk.json"), talkJson);

        var db = new DialogueDatabase(_tempDir!);

        Check("(H) loaded 2 files", db.Count == 2);
        Check("(H) AllIds contains spike_seq", db.AllIds.Contains("spike_seq"));
        Check("(H) AllIds contains spike_talk", db.AllIds.Contains("spike_talk"));

        Check("(H) TryGetSequence finds spike_seq",
            db.TryGetSequence("spike_seq", out var seq) && seq.Steps != null && seq.Steps.Count == 1);
        Check("(H) TryGetSequence rejects spike_talk (wrong type)", !db.TryGetSequence("spike_talk", out _));
        Check("(H) TryGetSequence rejects unknown id", !db.TryGetSequence("no_such", out _));

        // Talk pool query with low hearts (should get default)
        var ctxLow = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var linesLow = db.GetTalkLines("alice", ctxLow);
        Check("(H) talk pool low hearts: gets default line",
            linesLow != null && linesLow.Count == 1 && linesLow[0].Text == "Default talk.");

        // Talk pool query with high hearts (should get priority 10 entry)
        var ctxHigh = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = id => id == "alice" ? 5 : 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var linesHigh = db.GetTalkLines("alice", ctxHigh);
        Check("(H) talk pool high hearts: gets priority-10 line",
            linesHigh != null && linesHigh.Count == 1 && linesHigh[0].Text == "High hearts talk.");

        // Talk pool query for unknown character
        Check("(H) talk pool unknown character returns null", db.GetTalkLines("nobody", ctxLow) == null);

        // HasTalkPool
        Check("(H) HasTalkPool(alice) = true", db.HasTalkPool("alice"));
        Check("(H) HasTalkPool(nobody) = false", !db.HasTalkPool("nobody"));

        // Empty database (missing dir)
        var emptyDb = new DialogueDatabase(Path.Combine(_tempDir!, "nonexistent"));
        Check("(H) empty database: count = 0", emptyDb.Count == 0);
    }

    // ─────────────────────────── (I) Seen tracking ───────────────────────────

    private void RunSeenTracking()
    {
        GD.Print("-------------------- (I) Seen tracking: once=true marks seen, second attempt rejected --------------------");

        // Write a once-only sequence
        string json = @"{
            ""id"": ""once_seq"",
            ""type"": ""Sequence"",
            ""once"": true,
            ""steps"": [
                { ""type"": ""line"", ""speaker"": ""npc"", ""text"": ""One time only."" }
            ]
        }";
        File.WriteAllText(Path.Combine(_tempDir!, "once.json"), json);

        var db = new DialogueDatabase(_tempDir!);
        var seen = new HashSet<string>();

        var ctx = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = seen.Contains,
        };

        Check("(I) once-only sequence is available before seen", db.IsAvailable("once_seq", ctx));

        // Simulate playing it: the runner marks seen via the handler
        var handler = new StubEffectHandler();
        handler.SeenCallback = id => seen.Add(id);

        db.TryGetSequence("once_seq", out var seq);
        var runner = new DialogueRunner(seq.Steps!, handler, "once_seq", once: true);
        bool ended = false;
        runner.LineReady += (_, _, _, _) => { };
        runner.SequenceEnded += () => ended = true;
        runner.Start();
        runner.Advance();
        Check("(I) sequence plays and ends", ended);
        Check("(I) handler.MarkSeen was called", seen.Contains("once_seq"));

        // Now it should be unavailable
        Check("(I) once-only sequence NOT available after seen", !db.IsAvailable("once_seq", ctx));

        // A non-once sequence stays available after seen
        Check("(I) non-once sequence (spike_seq) stays available after seen (no once flag)",
            db.IsAvailable("spike_seq", ctx));
    }

    // ─────────────────────────── (J) Condition gating ───────────────────────────

    private void RunConditionGating()
    {
        GD.Print("-------------------- (J) Condition gating: IsAvailable changes with context --------------------");

        // Write a gated sequence
        string json = @"{
            ""id"": ""gated_seq"",
            ""type"": ""Sequence"",
            ""once"": false,
            ""conditions"": {
                ""hearts"": { ""npc"": 3 },
                ""flags_required"": [""quest_done""],
                ""season"": ""summer""
            },
            ""steps"": [
                { ""type"": ""line"", ""speaker"": ""npc"", ""text"": ""Gated line."" }
            ]
        }";
        File.WriteAllText(Path.Combine(_tempDir!, "gated.json"), json);

        var db = new DialogueDatabase(_tempDir!);

        // Context that fails all conditions
        var ctxFail = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = _ => 0,
            CurrentSeason = "winter",
            HasSeenDialogue = _ => false,
        };
        Check("(J) gated seq NOT available: wrong hearts, missing flag, wrong season",
            !db.IsAvailable("gated_seq", ctxFail));

        // Context that passes hearts but fails flag
        var ctxHeartsOnly = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = id => id == "npc" ? 5 : 0,
            CurrentSeason = "summer",
            HasSeenDialogue = _ => false,
        };
        Check("(J) gated seq NOT available: hearts pass but flag missing",
            !db.IsAvailable("gated_seq", ctxHeartsOnly));

        // Context that passes everything
        var ctxPass = new DialogueConditionContext
        {
            HasFlag = f => f == "quest_done",
            GetHearts = id => id == "npc" ? 3 : 0,
            CurrentSeason = "summer",
            HasSeenDialogue = _ => false,
        };
        Check("(J) gated seq IS available when all conditions pass",
            db.IsAvailable("gated_seq", ctxPass));

        // Unknown id
        Check("(J) unknown id is never available", !db.IsAvailable("no_such_seq", ctxPass));
    }

    // ─────────────────────────── Helpers ───────────────────────────

    private void CleanupTemp()
    {
        if (_tempDir != null && Directory.Exists(_tempDir))
        {
            try { Directory.Delete(_tempDir, recursive: true); }
            catch { /* best effort */ }
        }
    }

    /// <summary>Stub effect handler that records calls without touching GameState.</summary>
    private sealed class StubEffectHandler : IDialogueEffectHandler
    {
        public readonly HashSet<string> FlagsSet = new();
        public readonly List<(string CharId, int Amount)> FriendshipAwarded = new();
        public readonly List<(string ItemId, int Quantity)> ItemsGiven = new();
        public readonly HashSet<string> Seen = new();
        public Action<string>? SeenCallback;

        public void SetFlag(string flagId) => FlagsSet.Add(flagId);
        public void AddFriendship(string charId, int amount) => FriendshipAwarded.Add((charId, amount));
        public void GiveItem(string itemId, int quantity) => ItemsGiven.Add((itemId, quantity));
        public void MarkSeen(string dialogueId)
        {
            Seen.Add(dialogueId);
            SeenCallback?.Invoke(dialogueId);
        }
    }
}
