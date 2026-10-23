---
name: lenses
description: Apply Jesse Schell's lenses (The Art of Game Design) to a design doc, screen, mechanic, run structure, economy, story beat, cast or store page, using the lens-designer agent and the user's own copy of the book. Use when the user asks to "run the lenses", "lens review", "what would Schell say", "which lens applies", to check a design against the book, or to look up a lens, chapter or framework from the book.
---

# Run the lenses on a target

The main agent gathers context, picks lenses, briefs `lens-designer`
(`.claude/agents/lens-designer.md`), checks the pass and relays it. The agent runs the book's
own procedure for the target type (six-mechanic strip, twelve balance types, six-arrow
interface table, interest curve, character web, and so on) before the lenses. The book is read
through `.claude/skills/lenses/scripts/book.py`; paraphrased method notes with page cites live
in `references/ch*.md`; no book text goes into repo files.

## Modes

- `review <target>` is the default: a full pass with 6 to 10 lenses, scored, through the agent.
- `pick <question>` needs no agent. Read `references/lens_index.md`, name the 3 to 5 lenses that
  bear on the question, run `book.py lens N` for each so the answer carries the real questions,
  adapted to the project in one line each, and add the "To apply" step from the method notes
  that fits.
- `lookup <lens | chapter | phrase>` needs no agent. Run `book.py lens N`, `chapter N`,
  `find "..."` or `render A B` for a figure, then answer from the page. Cite the PDF page.

## 1. Gather (review mode)

- The target and its files. Design docs live in `designs/*.md`, `delve/design/*.md`,
  `zenith/docs/*.md`, `ungilded/`; screens are `.tscn` plus their scripts. List, never guess.
- The user's question in their words. A pass with no question drifts; ask for one if none was
  given and the target is large.
- The user rules the proposals must respect: project CLAUDE.md, the memory entries for that
  project (palette, UI standard, number display, locked decisions), and anything the user has
  rejected before.
- Evidence where it exists: screenshots, test output, balance numbers, playtest notes.

## 2. Pick the procedure and the lenses

Name the target type in the brief so the agent runs the matching procedure: new idea, mechanic,
balance or economy, screen or interface, run or progression or tutorial, story or scene, cast,
world or space, multiplayer, playtest or pitch or documents. Then start from the lens set in
`references/lens_index.md` for that type and adjust to the question. Six to ten lenses per
pass, named by number. If the user named lenses, use theirs.

## 3. Brief the agent

Launch `lens-designer` with the Agent tool, `model: opus`. The prompt carries:
- the target, its file list and the evidence paths;
- the user's question verbatim;
- the lens numbers to apply;
- the user rules and rejected ideas;
- a scratchpad path outside the repo, for example `%TEMP%\lens_review\<target>\pass1.md`;
- "Do not edit repo files. Do not run git."

One agent per pass. Split only when two targets share nothing.

## 4. Check

Read the pass file. Drop any proposal that breaks a user rule or a locked decision. Check that
every finding points at something in the files; send back a finding that argues from the book
alone.

## 5. Report

Message rules from the repo CLAUDE.md apply. Result first: the lowest scores and the two or
three changes that matter most, each as "what changes, to what". Group the rest by lens with the
score. Keep the agent's guesses and gaps. Do not paste the pass file. Put the decisions the user
owns last, one question per line.

Build nothing from a lens pass until the user picks. When they do, "design X" means the design
doc first, then code, per the core rules.

## Re-scoring

If the user asks to loop, resume the same agent with SendMessage after the changes land, with
the new evidence, and ask it to re-score the same lenses. Report scores per round. Stop when
every applied lens is at 7 or above, or the user stops it.

## Inside an adversarial review

When an `adversarial-review` target is a design or system, `lens-designer` can take the
"domain design" seat. Give it the same brief.md and the lens numbers; it writes its reviews to
the review files like the other seats and scores on its lenses.
