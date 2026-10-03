---
name: ivalice
description: Revise game dialogue, narration, barks or tutorial coaching into Ivalice-style prose (Final Fantasy Tactics War of the Lions / Ivalice Chronicles first, BlazBlue second) with lore continuity and human writing patterns, using the ivalice-writer agent. Use when the user asks to "ivalice" text, make lines read like FFT, polish dialogue so it reads as written by skilled humans, or rework a scene, lead-in or tutorial section.
---

# Ivalice a piece of text

The main agent gathers context and applies; the `ivalice-writer` agent (`.claude/agents/ivalice-writer.md`) writes.

## 1. Gather

- The exact text to revise, with its file, keys (lesson/beat, pair/slot) and speakers. If the user
  pasted a chunk, find it in the file.
- What the user wants from this chunk in their words (tone, beats to keep, lines they like).
- Limits the text must meet. For the Zenith tutorial: `zenith/tests/tutorial_tests.gd` (word cap,
  stop read time, punctuation, first-person Vale from lesson 3, "win"/"climb" lines, rings). For
  Zenith lead-ins: `zenith/tests/run_tests.gd` (`test_lead_in_*`: narration <= 120 chars, line <= 90).
- The lore record and the other files the same speakers appear in (`zenith/docs/cast.md`,
  `zenith/data/adventure/lead_ins.json`, `zenith/data/tutorial/lessons.json`).

## 2. Brief the agent

Launch `ivalice-writer` with the Agent tool. The prompt carries: the file and keys, the current
text verbatim, the user's request verbatim, the beats and lines that must stay, the limits, the
lore files to read, and a scratchpad path for its draft. Ask for alternatives on any line the user
singled out. For a large pass (a whole file), split it by section and run one agent per section
only if the sections share no speakers; otherwise one agent keeps the voices consistent.

## 3. Check

- Read the draft against the user's request and the lore record. Reject unmarked new facts.
- Count words and read times, or write the lines in and run the tests.

## 4. Show, then apply

- In the user-driven, section-by-section mode, show the revised chunk in the message (old → new
  only where it changed) with the agent's alternatives for the lines in question, and ask which to
  write. Write it in once the user picks, then run the tests.
- If the user asked for the whole thing applied, write it in, run the tests, and report.
- The tutorial's script is `zenith/data/tutorial/lessons.json` itself; `zenith/docs/tutorial_script.md`
  holds no lines, so text changes need no doc update.
- New lore the user approves goes into `zenith/docs/cast.md` in the same pass.

## House rules that always apply

Messages to the user follow the repo CLAUDE.md. Lore is the user's: workshop it before writing it.
Edit files with Edit/Write, not scripts.
