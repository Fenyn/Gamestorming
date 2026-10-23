# The Art of Game Design: lens index

Jesse Schell, A Book of Lenses, 1st edition (2008). The user's copy is `docs/Art of Game Design.pdf`
(git-ignored). Read it with `.claude/skills/lenses/scripts/book.py`; never paste book text into
repo files. Pages here are PDF pages. Book page = PDF page - 31.

Every lens is a short list of questions the designer asks about their own game. The one-liners
below say what each lens tests so you can pick lenses; read the real questions with
`python book.py lens N` before applying one.

## Method notes

Paraphrased notes on the book's lists, steps and examples, with a "To apply" step for each and
PDF page cites. Read the file for the chapters the target touches before running a procedure.

- `ch01-05_experience_and_elements.md`: designer skills, listening, introspection and its perils, the definition chain, tetrad, skin and skeleton, theme, resonance.
- `ch06-09_ideas_iteration_player_mind.md`: problem statement, the subconscious, 15 brainstorming tips, eight filters, rule of the loop, Boehm spiral, 8 prototyping tips, Cerny, age brackets, gender lists, LeBlanc, Bartle, flow, Maslow, judgment.
- `ch10-12_mechanics_balance_puzzles.md`: six mechanics, ten probability rules, expected value, twelve balance types, seven balancing methods, economies, ten puzzle principles.
- `ch13-16_interface_interest_story_control.md`: six-arrow interface table, 0.1 s rule, juiciness, four channel steps, modes, 8 interface tips, interest curve, three interest factors, string of pearls, story machine, 8 story tips, hero's journey, six indirect control methods, collusion.
- `ch17-22_worlds_characters_spaces_players.md`: transmedia worlds, avatar, 9 character tips, five space organisations, Alexander's 15 properties, scale, aesthetics, five reasons to play together, 10 community tips, griefing.
- `ch23-33_team_docs_playtest_tech_client_purpose.md`: love, team communication, 14 document types, five playtest questions, technology, the client's three layers, 12 pitch tips, profit, transformation, responsibility, the raven.

## Chapters

| Ch | PDF | Title | What it holds |
|---|---|---|---|
| 1 | 33-40 | The Designer | skills a designer needs, listening |
| 2 | 41-54 | The Designer Creates an Experience | experience over game, introspection, lens 1 |
| 3 | 55-70 | The Experience Rises Out of a Game | definitions of fun, play, toy, game; lenses 2-6 |
| 4 | 71-78 | The Game Consists of Elements | elemental tetrad (mechanics, story, aesthetics, technology), skin vs skeleton |
| 5 | 79-88 | The Elements Support a Theme | unifying theme, resonance |
| 6 | 89-106 | The Game Begins with an Idea | problem statement, subconscious, 15 brainstorming tips |
| 7 | 107-128 | The Game Improves Through Iteration | rule of the loop, eight filters, risk, 8 prototyping tips, spiral |
| 8 | 129-144 | The Game Is Made for a Player | demographics, gender, Bartle types, LeBlanc's 8 pleasures |
| 9 | 145-160 | The Experience Is in the Player's Mind | modelling, focus, flow, empathy, imagination, Maslow, judgment |
| 10 | 161-202 | Some Elements Are Game Mechanics | space, objects/attributes/state, actions, rules, skill, chance |
| 11 | 203-238 | Game Mechanics Must Be in Balance | 12 balance types, balancing methods, economies |
| 12 | 239-252 | Game Mechanics Support Puzzles | 10 puzzle principles |
| 13 | 253-276 | Players Play Games Through an Interface | interface loop, juiciness, channels, modes, 8 interface tips |
| 14 | 277-292 | Interest Curves | the curve shape, inherent interest, poetry of presentation, projection |
| 15 | 293-314 | The Story | string of pearls, story machine, 8 story tips, hero's journey |
| 16 | 315-330 | Indirect Control | constraints, goals, interface, visual design, characters, music, collusion |
| 17 | 331-340 | Worlds | transmedia worlds, what makes one strong |
| 18 | 341-360 | Characters | avatar, 8 character tips, circumplex, web, status, transformation |
| 19 | 361-376 | Spaces | architecture, Alexander's 15 properties, level design |
| 20 | 377-384 | Aesthetics | why beauty matters, art direction notes |
| 21 | 385-388 | Other Players | why we play together |
| 22 | 389-402 | Communities | friendship, expression, community, griefing |
| 23 | 403-412 | The Team | love, team communication |
| 24 | 413-420 | Documents | the document list a game needs |
| 25 | 421-434 | Playtesting | who, where, what, how; formal and informal |
| 26 | 435-446 | Technology | foundational vs decorational, hype curve, crystal ball |
| 27 | 447-454 | The Client | what they want vs say |
| 28 | 455-464 | The Pitch | 12 pitch tips |
| 29 | 465-472 | Profit | business models, numbers |
| 30 | 473-484 | Transformation | games that change players, violence, flow and addiction |
| 31 | 485-490 | Responsibility | |
| 32 | 491-493 | Motivation | the raven, secret purpose |

## Frameworks that are not lenses

Use `python book.py find "<phrase>"` to land on the page.

- Elemental tetrad (PDF 72-74): every game is mechanics, story, aesthetics, technology; check all four reinforce one theme.
- Eight filters (PDF 107-109): artistic impulse, demographics, experience design, innovation, business, engineering, social/community, playtesting. A design is done when it passes all eight unchanged.
- Rule of the loop and prototyping tips (PDF 110-120): the more you test and improve, the better the game; prototype the riskiest thing first, fast and loose, in parallel, on paper where you can.
- Bartle types and LeBlanc's pleasures (PDF 136-143): achievers, explorers, socialisers, killers; sensation, fantasy, narrative, challenge, fellowship, discovery, expression, submission.
- Flow (PDF 150-153): clear goals, no distractions, direct feedback, continuous challenge.
- The six mechanics (ch 10): space; objects, attributes and states; actions (operative vs resultant); rules (Parlett's types plus house rules); skill; chance.
- Twelve balance types (ch 11): fairness, challenge vs success, meaningful choices, skill vs chance, head vs hands, competition vs cooperation, short vs long, rewards, punishment, freedom vs controlled experience, simple vs complex, detail vs imagination.
- Ten puzzle principles (ch 12): make the goal easily understood, easy to get started, sense of progress, solvable, difficulty gradual, parallelism, pyramid, hints, give the answer, perceptual shifts are double-edged.
- Interface loop (PDF 255-262): physical input, virtual interface, world, virtual interface, physical output, player; feedback loops at each step.
- Interest curve (PDF 278-285): a hook, rising peaks, a climax, a short close; nested curves per level and per session.
- Indirect control (ch 16): constraints, goals, interface, visual design, characters, music, collusion.

## The 100 lenses

Format: number, name, PDF page, what it tests.

### Experience, fun, theme (ch 2-5)
1. Essential Experience, 52: the experience you want, what is essential to it, how the game captures that.
2. Surprise, 57: where the surprises are, in story, rules, art, technology.
3. Fun, 58: which parts are fun and why, which need to be.
4. Curiosity, 61: the questions the game puts in the player's head and why they care.
5. Endogenous Value, 63: what players value inside the game and how it ties to their motives.
6. Problem Solving, 68: the problems the game sets, hidden ones, how it keeps generating them.
7. The Elemental Tetrad, 74: are all four element types present, in harmony, serving one theme.
8. Holographic Design, 77: elements and experience seen together; what helps, what hurts.
9. Unification, 84: the theme, and whether every element reinforces it.
10. Resonance, 87: what feels powerful; what gets people excited when you describe it; what drives your instincts.

### Ideas and iteration (ch 6-7)
11. Infinite Inspiration, 90: an experience from your own life worth sharing, captured in some small way.
12. The Problem Statement, 93: what problem the game solves; hidden assumptions; is a game the best answer; how you will know.
13. The Eight Filters, 109: does the design pass all eight tests without a change.
14. Risk Mitigation, 117: what could keep the game from being great, and how to stop it.
15. The Toy, 121: is it fun to play with before any goal is added.

### The player (ch 8-9)
16. The Player, 137: what they like, dislike, expect, and would want from this game.
17. Pleasure, 143: which pleasures the game gives, which are missing.
18. Flow, 153: clear goals, distractions, a steady stream of right-sized challenge, skill growth.
19. Needs, 158: which Maslow levels it serves, and whether it delivers on them.
20. Judgment, 159: what the game judges, how it says so, fairness, whether players care and want to improve.

### Mechanics (ch 10)
21. Functional Space, 166: discrete or continuous, dimensions, boundaries, sub-spaces, other useful models.
22. Dynamic State, 171: objects, attributes, states, triggers; who knows what; would changing that help.
23. Emergence, 174: verbs, objects per verb, ways to a goal, subjects controlled, side effects.
24. Action, 175: operational vs resultant actions; the ratio; what players wish they could do.
25. Goals, 180: ultimate goal, clarity, chain of goals, concrete and rewarding, short vs long, player-set goals.
26. Rules, 181: foundational vs operational, house rules forming, modes, enforcement, confusion.
27. Skill, 184: which skills are asked, which dominate, missing categories, fairness, practice, right level.
28. Expected Value, 198: real vs perceived odds, value of outcomes, whether choices stay interesting.
29. Chance, 200: what is random vs feels random, excitement vs hopelessness, distributions, risk-taking, chance vs skill.

### Balance (ch 11)
30. Fairness, 207: symmetry, skill measure vs interesting challenge, mixed skill levels.
31. Challenge, 210: the challenges, their difficulty, range, growth, variety, maximum.
32. Meaningful Choices, 212: what choices, are they meaningful, the right number, dominant strategies.
33. Triangularity, 213: safe low reward vs risky high reward; rewards sized to the risk.
34. Skill vs. Chance, 215: judged or taking risks; serious or casual; tedium fixed by chance, randomness fixed by skill.
35. Head and Hands, 216: thinking vs doing; places to relax; a 1 to 10 score.
36. Competition, 217: fair skill measure, wanting to win, pride, novices and experts.
37. Cooperation, 218: communication, strangers, synergy, roles, tasks no one can do alone.
38. Competition vs. Cooperation, 218: the 1 to 10 mix, player choice, team competition.
39. Time, 220: what sets length, too short, too long, time limits, nested rounds.
40. Reward, 222: which rewards, excitement, understanding, variability, relation, build-up.
41. Punishment, 225: what and why, fairness, punishments that could be rewards, balance against rewards.
42. Simplicity/Complexity, 227: innate complexity vs emergent complexity from simple rules.
43. Elegance, 229: elements and their purposes; combine or cut single-purpose elements.
44. Character, 230: the strange, funny, lovable quirks players talk about.
45. Imagination, 232: what the player must understand, which details to give, which to leave to imagination.
46. Economy, 235: how money is earned and spent, scarcity, meaningful choices, one currency or several.
47. Balance, 236: does the game feel right, and why.

### Puzzles (ch 12)
48. Accessibility, 244: how players know where to start; what it resembles; does it invite touch.
49. Visible Progress, 245: what progress means, enough interim steps, hidden progress revealed.
50. Parallelism, 247: bottlenecks, parallel challenges, variety, connections between them.
51. The Pyramid, 248: pieces feeding one final challenge; a hierarchy; a compelling top.
52. The Puzzle, 250: which puzzles, more or fewer, which principles apply, incongruous ones.

### Interface (ch 13)
53. Control, 253: does the interface do what is expected; do players feel powerful.
54. Physical Interface, 257: what is touched, the mapping to game actions, the metaphor.
55. Virtual Interface, 257: what information the world does not show, when it is needed, how to show it without getting in the way.
56. Transparency, 258: desires met, usable without thinking, intuitive to new players, edge cases.
57. Feedback, 261: at each moment, what players need, want, should feel, and their goal.
58. Juiciness, 264: continuous feedback, second-order motion, rewards given many ways at once.
59. Channels and Dimensions, 269: which data, which channels, which dimensions.
60. Modes, 271: which modes, collapse or combine, overlap, how a mode change is shown.

### Interest and story (ch 14-16)
61. The Interest Curve, 283: sketch the curve; hook, rising peaks, climax; fix the dips.
62. Inherent Interest, 285: what grabs at once, never-before-seen, base and higher instincts, dramatic change.
63. Beauty, 286: each element more beautiful; beauty in combination; what beauty means here.
64. Projection, 288: what players relate to, want to visit, be, meet, do; activities they keep doing.
65. The Story Machine, 297: choices, conflicts, personalisation, interest curve of play stories, who to tell.
66. The Obstacle, 302: character and goal, obstacles, antagonist, escalation, transformation.
67. Simplicity and Transcendence, 303: world simpler than real; player more powerful than real.
68. The Hero's Journey, 306: heroic elements, fit to the structure, more archetypes, or hackneyed.
69. The Weirdest Thing, 310: the weirdest thing, whether it confuses, coalesce the weird things.
70. Story, 311: does the game need a story; why would players care.
71. Freedom, 315: when players feel free, constrained, overwhelmed.
72. Indirect Control, 324: what you want players to do; constraints, goals, interface, visuals, characters, music.
73. Collusion, 329: characters serving the designer's aim without breaking their own goals.

### Worlds, characters, spaces (ch 17-19)
74. The World, 338: better than the real world; multiple gateways; one story or many.
75. The Avatar, 345: ideal form; iconic enough to project into.
76. Character Function, 347: roles needed, characters imagined, mapping, doubling up, gaps.
77. Character Traits, 348: defining traits shown in words, actions, appearance.
78. The Interpersonal Circumplex, 350: hostile/friendly by submissive/dominant; gaps and extremes.
79. The Character Web, 352: how each feels about each other; missing or repeated links.
80. Status, 354: relative status and its behaviours.
81. Character Transformation, 358: how each changes, how it is shown, enough, surprising, believable.
82. Inner Contradiction, 366: purpose of game and subsystems; anything that defeats them.
83. The Nameless Quality, 368: which parts feel alive, which feel dead.

### Players together (ch 21-22)
84. Friendship, 392: what friendships players seek, ice-breaking, chances to talk, keeping friends.
85. Expression, 394: how players express themselves, what is missing, pride in identity.
86. Community, 398: the central conflict, architecture, three levels of experience, events, need for each other.
87. Griefing, 401: easy-to-grief systems, making griefing boring, loopholes.

### Team, documents, testing, technology (ch 23-26)
88. Love, 406: do you and the team love the project.
89. The Team, 411: right team, objective and clear communication, trust, unity.
90. Documentation, 418: what must be remembered, what must be communicated.
91. Playtesting, 432: why, who, where, what to look for, how to collect it.
92. Technology, 443: which technologies serve the experience; foundational or decorational; disruptive options.
93. The Crystal Ball, 444: what a technology looks like in two, four, ten years.

### Client, pitch, profit, purpose (ch 27-32)
94. The Client, 451: what they say, what they think, what they really want.
95. The Pitch, 463: why this client, what success means, what is in it for them, what they must know.
96. Profit, 470: where the money goes, cost, units, break-even.
97. Transformation, 483: how the game changes players for better or worse.
98. Responsibility, 488: does the game help people.
99. The Raven, 491: is this game worth your time.
100. Your Secret Purpose, 492: why am I doing this.

## Lens sets for this repo's targets

Start from the set, then add or drop lenses for the specific target. Keep a pass to 6 to 10 lenses.

| Target | Lenses |
|---|---|
| New prototype or core concept (`designs/*.md`) | 1, 9, 10, 12, 13, 14, 15, 16, 62, 99 |
| Combat or core mechanic (Delve combat, Zenith duel, Ungilded encounter) | 6, 22, 23, 24, 25, 26, 27, 32, 43, 47 |
| Balance, economy, rewards | 28, 29, 30, 31, 32, 33, 40, 41, 42, 46 |
| Run structure, roguelite progression, unlocks | 18, 25, 31, 39, 40, 49, 50, 51, 61, 65 |
| A screen, HUD or interface | 48, 53, 55, 56, 57, 58, 59, 60 |
| Tutorial or onboarding | 18, 25, 26, 45, 48, 56, 57, 72 |
| Encounter, floor or puzzle design | 31, 48, 49, 50, 51, 52 |
| Story beat, scene, lead-in, dialogue | 61, 62, 64, 66, 67, 69, 70, 71, 72, 73 |
| Cast and characters | 75, 76, 77, 78, 79, 80, 81 |
| World, setting, lore | 9, 10, 67, 74, 82, 83 |
| Multiplayer, online, community | 30, 36, 37, 38, 84, 85, 86, 87 |
| Art direction, audio, feel | 7, 9, 45, 58, 63 |
| Store page, pitch, itch kit | 10, 16, 62, 95, 96 |
| Playtest plan | 14, 90, 91 |
| Whether to keep working on a project | 88, 97, 98, 99, 100 |
