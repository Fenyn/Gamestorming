---
name: lens-ideate
description: Start a new game, feature or system by the formal loop in The Art of Game Design chapters 6 and 7: problem statement, brainstorm by tetrad lists, commit to one direction, eight filters, Boehm risk list, prototypes that each answer one question, Cerny's two-level check. Uses the lens-designer agent and the user's copy of the book. Use when the user has a new idea, asks "how should I start this", wants directions for a feature, or asks for a problem statement, filters, a risk list or a prototype plan.
---

# Start an idea with the book's loop

Schell's formal loop (p.122): state the problem, brainstorm solutions, choose one, list its
risks, build prototypes to mitigate them, test them and stop if good enough, otherwise state the
new problems and go round again. The main agent holds steps 1 and 3 with the user;
`lens-designer` (`.claude/agents/lens-designer.md`) does steps 2, 4 and 5. Method notes:
`.claude/skills/lenses/references/ch06-09_ideas_iteration_player_mind.md`.

## 1. Problem statement (with the user)

Settle these in one short round, in plain language:
- The problem sentence in the book's form, "How can I make [constraint] that [goal]?"
  (p.91-92). Strike every word that names a solution rather than a need; "game" is often one.
- The essential experience in one line (Lens 1, p.51-52).
- Which tetrad elements are already fixed (engine, art rules, locked decisions) and which are
  free (p.92).
- What the user has ruled out.

If the user already gave all four, state them back in the brief and skip the round. If the idea
is a change to an existing system, the problem sentence must name what is wrong now with a value
or an observation from play.

## 2. Brainstorm and filter (agent)

Launch `lens-designer` with the Agent tool, `model: opus`. The brief carries the four answers
verbatim, the project files that matter (`designs/<project>.md`, the project CLAUDE.md, the
memory rules for that project), a scratchpad path outside the repo, and "Do not edit repo files.
Do not run git." Ask for, in this order:
- Numbered idea lists, one per free tetrad element, then at least three cross-list
  combinations (brainstorming tips 11 to 13, p.102-104). Irrational ideas stay for one round
  (p.95-96).
- At least three directions, each in five lines: the core loop, the essential experience it
  delivers, the toy at its centre (Lens 15, p.121), what is new (Lens 62), what it removes as
  well as adds (Lens 43).
- An eight-filters table, one row per direction, pass / change / fail with evidence, unknowns
  marked as risks (p.107-109).
- For the direction it rates best, the Boehm step 2 risk list ranked, each risk with the
  cheapest test or decision that settles it, prototype or not (p.113-116).
- The prototype plan: each prototype answers one stated question, ranked by risk and by what
  could void the others, paper where possible, toy before game (prototyping tips, p.117-121).
  Say what result sends the idea back to step 1.

## 3. Choose (with the user)

Message rules from the repo CLAUDE.md apply. Lead with the directions, each in two or three
lines. Then the filter table. Then the risks and the prototype plan for the best one. Keep the
agent's guesses. Put the decision last: which direction, or none.

Commit fast and reverse without sentiment (p.107). A picked direction becomes a design doc
(`designs/<name>.md`, concise, bullets) before any code, per the core rules. The prototype is
built after the doc is approved. The first prototype answers the biggest risk, and nothing else
is built until it has.

## 4. Loop

After a prototype is tested, write the new problem statement it produced and run the steps
again. Problem statements get more specific each loop (p.122-125). Until one shippable slice
with every feature exists, schedule claims are guesses (Cerny, p.125-126).
