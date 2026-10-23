# Chapters 10 to 12: mechanics, balance, puzzles

Source is The Art of Game Design, 1st edition. Page numbers are PDF pages. Lenses 21 to 52.

## Chapter 10. Some elements are game mechanics

- Mechanics are the interactions and relationships left once aesthetics, technology and story are removed. Schell sorts them into six categories (space; objects, attributes and states; actions; rules; skill; chance) and warns that no taxonomy is complete (p.161).
  - To apply, strip the target to these six headings before judging it, and write one line per heading.

### Mechanic 1. Space

- A functional space is a mathematical model with visuals removed. It is discrete or continuous, has some number of dimensions, and has bounded areas that may or may not connect (p.161-162).
  - To apply, draw the target's space as nodes and links (discrete) or a bounded field (continuous) and count its dimensions.
- Tic-tac-toe is nine zero-dimensional cells joined in a 3 by 3 grid, where adjacency matters but position inside a cell does not (p.162-163).
  - To apply, mark which positions inside a tile or zone change the outcome. If none do, model the zone as one point.
- A Monopoly board looks two-dimensional but is a one-dimensional loop of 40 points. Fancy aesthetics can hide a simpler space (p.163).
  - To apply, check whether a floor map or board reduces to a line or loop, because that is the space players reason about.
- A pool table can be modelled as continuous 2D or 3D. Soccer can be modelled as 2D continuous, 3D continuous, or discrete zones, depending on the question being asked (p.164-165).
  - To apply, pick the model that fits the change you are testing (boundaries, heights, or play per zone) and switch models when the question changes.
- Nested spaces are spaces inside spaces, such as towns and caves entered from an RPG overworld through an icon. They match how people think about indoors and outdoors (p.165).
  - To apply, list each sub-space of a floor or map, its entry gateway, and whether it links to the parent space by anything other than that gateway.
- Zero dimensions. Twenty Questions can be modelled as the answerer's mind, the conversation space and the questioner's mind, because game state has to live somewhere (p.165-166).
  - To apply, for a game with no board, draw where each piece of state sits (each player's head, the table, the deck).
- Lens #21, Functional Space (p.166). Ask whether the space is discrete or continuous, how many dimensions it has, where its boundaries are, what sub-spaces exist and how they connect, and whether another abstract model would also be useful. Pair with Lens #8, Holographic Design.

### Mechanic 2. Objects, attributes and states

- Objects are the nouns. Attributes are categories of information on an object and each has a current state (car max speed 150, current speed 75). Attributes and states are the adjectives (p.167).
  - To apply, make a table per object with each attribute, its possible states, and whether it is static or dynamic.
- Static attributes never change (checker colour). Dynamic ones do (checker mode normal, king, captured; chess king free, in check, checkmated; Monopoly property houses 0 to hotel and mortgaged yes or no). Focus on dynamic ones (p.167).
  - To apply, drop static attributes from the analysis and list the dynamic ones first.
- Rule of thumb. Objects that behave the same should look the same, and objects that behave differently should look different. Some state changes are better hidden (p.167).
  - To apply, audit unit or card art against behaviour, and flag any pair that looks alike but acts differently.
- State diagrams. Draw each attribute's states, the transitions, and the event that triggers each one, as in the Pac-Man ghost diagram (in cage, chasing, blue, flashing, eyes). Coding them as state machines forbids illegal transitions. Diagrams can nest sub-states (p.167-168).
  - To apply, draw the diagram for a combat unit's status (ready, acting, stunned, downed, dead) with every trigger, and look for missing or illegal arrows.
- The same thing can be modelled more than one way, such as a poker hand as a zone holding five cards or as one object with five attributes. Use whichever is most useful at the moment (p.168).
  - To apply, try both models of an awkward element and keep the one that makes the rules shorter.
- Secrets. Who knows which state is a core decision. Chess is all public. Draw poker is all private. Stud poker mixes public and private and plays very differently. Battleship and Stratego are about guessing private state (p.168-169).
  - To apply, test a version of the target with one private attribute made public, or one public attribute hidden.
- Video games add state only the game knows. Schell's grandmother said the Intellivision poker game cheated because it knew every card. Virtual opponents count as knowers alongside players, and the game is a separate knower (p.169).
  - To apply, state what information the AI reads when deciding, and make sure it uses only what a human in its seat would know, or tell players otherwise.
- Hierarchy of knowers, a Venn diagram of God, the Game and each player. A is public. B is shared by some players. C is private to one player. D is known to the game only (Stay Alive, Touché, a game master). E is random and not yet generated (p.169-170).
  - To apply, fill an A to E table for every dynamic attribute in the target.
- Forcing players to track too many states (too many pieces, too many stats per character) confuses and overwhelms (p.170).
  - To apply, count the states a player must hold in mind in one turn and cut or display those that exceed what they can track.
- Lens #22, Dynamic State (p.171). List the objects, their attributes, each attribute's states and triggers, then which state only the game knows, which all players know, which some or one player knows, and whether changing who knows what would improve the game. Making private information suddenly public creates drama.

### Mechanic 3. Actions

- Operative actions are the base moves (checkers has three: move forward, jump, move back as a king). Resultant actions are strategic uses of those moves (protect a checker, force an unwanted jump, sacrifice, build a bridge, reach the king row) (p.171-172).
  - To apply, write both lists for a combat system. The operative list is the action bar. The resultant list is what good players do with it.
- The ratio of meaningful resultant actions to operative actions measures emergence. Few operative actions with many resultant ones is elegant. Emergence is like a garden, so recognise interesting resultant actions when they appear and protect them (p.172).
  - To apply, report the ratio for the target, and after each playtest add newly observed resultant actions to the list.
- Five ways to get emergence (p.172-173).
  - Add more verbs, but prefer one good verb over many mediocre ones, because the ratio matters more than the count.
  - Give verbs many objects. One "shoot" that hits locks, windows, tyres and food beats a gun that only hits enemies. Schell calls this possibly the strongest method.
  - Let goals be reached more than one way (shoot the boss, drop the chandelier, stop him without violence), while watching for a dominant option.
  - Give players many subjects. Resultant actions scale roughly with subjects times verbs times objects.
  - Give actions side effects that change constraints, as every checkers move changes what both sides threaten and can enter.
  - To apply, score the target on each of the five, then pick the weakest and propose one concrete change for it (for example a new target type for an existing ability).
- Lens #23, Emergence (p.174). Count the verbs, the objects each verb acts on, the ways to reach the goals, and the subjects controlled, and ask how side effects change constraints.
- Games feel derivative when they reuse an older game's actions and innovative when they add new operative or resultant actions (Donkey Kong jumping, Harvest Moon farming, Katamari rolling) (p.174).
  - To apply, compare the target's operative list with its nearest genre peer and name the action that is new.
- Text adventures offered hundreds of verbs but thousands more failed, so players lacked the freedom the interface implied. Schell suggests this frustration may explain the genre's decline (p.174-175).
  - To apply, check whether the interface suggests actions the game does not support, and either support them or stop suggesting them.
- Lens #24, Action (p.175). List the operational and resultant actions, the resultant actions you want and what change would allow them, whether the ratio satisfies you, and which actions players wish they had and how to enable them.

### Mechanic 4. Rules

- Rules define space, objects, actions, consequences, constraints and goals (p.175). Parlett's rule analysis, plus one addition (p.176-178).
  - Operational rules are what players do to play.
  - Foundational rules are the abstract maths beneath (power rises by a random 1 to 6). Boards, chips and health bars only track this state.
  - Behavioural rules are unwritten sportsmanship (do not tickle a thinking chess player), which shows a game is a social contract.
  - Written rules come with the game. Few people read them, and tutorials teach better. Every designer needs an answer to "How will players learn to play my game?" (p.177).
  - Laws are tournament rules, such as the 2005 Tekken 5 rules including "Mokujin is banned" because his stun move decided games.
  - Official rules merge written rules and laws over time, as saying "check" did in chess.
  - Advisory rules are strategy tips, not rules.
  - House rules are players' own tuning after play, the feedback arrow in Parlett's diagram.
  - To apply, write the target's foundational rules separately from its operational rules, list any player bans or house rules seen in testing, and write the one-line answer to how players learn the game.
- Modes. Rules can change completely between modes, as in Pitstop's tyre-change sub-game. Tell players which mode they are in, organise modes as one main mode with sub-modes, and follow Sid Meier's rule that a sub-game should never last long enough to make players forget the main game (p.178).
  - To apply, list each mode (map, combat, shop, dialogue), how the player knows they are in it, and its typical length against the main loop.
- The enforcer. Computers enforce rules so they become physical constraints, which allows complexity like Warcraft. Players must still be able to discover and understand the rules without memorising them (p.178-179).
  - To apply, mark which rules the code enforces silently and check each one can be learned by trying things.
- The most important rule is the object of the game, stated clearly, with any sequence of goals and how they relate. Chess becomes appealing when its goal is put as "capture your opponent's king" (p.179).
  - To apply, write the target's goal in under ten words and test it on someone new.
- Good goals are concrete (players can state them), achievable (players believe they can) and rewarding (worth it in itself, valued before it is reached, and not oversold). Balance short-term and long-term goals (p.179-180).
  - To apply, rate each goal in a run or floor on the three qualities and list which goals are short-term and which are long-term.
- Lens #25, Goals (p.180). Ask what the ultimate goal is, whether it is clear, whether a series of goals is understood, whether goals relate meaningfully, whether they are concrete, achievable and rewarding, whether short- and long-term goals are balanced, and whether players can set their own.
- Lens #26, Rules (p.181). Ask what the foundational rules are and how they differ from the operational ones, whether laws or house rules are forming and should be absorbed, whether the modes help, who enforces the rules, and whether confusion should be fixed by changing rules or explaining them. Rules emerge through experiment, and holes found in playtests must be written down or they return.

### Mechanic 5. Skill

- Skill shifts the focus to the player. Matching skill to difficulty keeps players in the flow channel. Skills fall into physical (strength, dexterity, endurance), mental (memory, observation, puzzle solving, decisions) and social (reading, fooling, coordinating) (p.181-182).
  - To apply, tag each challenge in the target as physical, mental or social.
- Real skill is what the player has. Virtual skill is the character's (sword fighting points), which can rise while the player's real skill does not. Virtual skill gives a feeling of power but feels hollow if overused. Find the right mix and keep the two distinct (p.182-183).
  - To apply, list what improves in the player and what improves in the character, and check that the run is not carried only by the second list.
- Enumerate skills, generally or very specifically. RC Pro Am needed the player to solve a grip problem (rolling the thumb from A to B) and then practise it, plus resource management, memorising tracks and reacting (p.183).
  - To apply, write the specific skill list for one encounter, including controller or interface skills.
- Designers often think a game is about one skill when another dominates, such as reaction games that turn out to be about memorising enemy timings (p.183).
  - To apply, watch a repeat player and note which skill actually wins, then compare it to the intended one.
- Lens #27, Skill (p.184). Ask which skills are required, which categories are missing, which dominate, whether they create the intended experience, whether skill gaps feel unfair, whether practice improves them, and whether the demand is right. Pair with Lens #1, Essential Experience.

### Mechanic 6. Chance

- Chance means uncertainty, which means surprise, a source of fun, but intuition about it is often wrong (p.184). The Chevalier de Méré thought "one six in four rolls" and "a double six in 24 rolls of two dice" had the same 66% odds. The first wins about 51.8%, the second about 49.1%. Pascal and Fermat founded probability on his question (p.185, p.190-191).
- Ten rules of probability (p.186-194).
  - Rule 1. Fractions, decimals and percents are the same number (1/2 = 0.5 = 50%) (p.186).
  - Rule 2. Probabilities run from 0 to 1. A result above 100% means the maths is wrong, as the Chevalier's would be for seven dice (p.186).
  - Rule 3. Probability is "looked for" outcomes divided by possible outcomes, if equally likely (face card 12/52) (p.186-187).
  - Rule 4. Enumerate. Three coins with at least two heads is 4 of 8. The first Chevalier game is 671 of 1296 (p.187).
  - Rule 5. OR means add, but only for mutually exclusive events. Face card or ace is 16/52. Ace or diamond is not 17/52 because of the ace of diamonds (p.187-188).
  - Rule 6. AND means multiply, for independent events. Two sixes is 1/36. Ace of diamonds is 4/52 times 13/52 (p.188-190).
  - Rule 7. One minus "does" equals "doesn't". The second Chevalier game is 1 minus (35/36) to the 24th, about 49% (p.191).
  - Rule 8. Summing linear random selections is not linear. Two dice favour 7. D&D's 3d6 stats cluster near 10 and 11, unlike a d20. Choose the distribution curve you want (p.191-192).
  - Rule 9. Roll the dice. Practical probability by repeated trials, the Monte Carlo method, catches what the maths misses, such as which Monopoly squares are landed on most (p.193).
  - Rule 10. Geeks love showing off (Gombauld's Law). Ask a maths person or a forum, framing the problem as probably too hard to solve (p.193-194).
  - To apply, for each random element in the target, write its distribution, check it with Rules 5 to 7, and run a short simulation when the maths gets long.
- Expected value is the sum of each outcome's chance times its value. A green space paying 1d6 averages 3.5. Two dice paying $5 on 7 or 11 and costing $1 otherwise has EV +$0.33. With only 7 winning it is $0.00, and with only 11 it is about -$0.86 (p.194-195).
  - To apply, compute the EV of every option the player chooses between (attacks, cards, shop rolls) in a table.
- Consider values carefully. Wind (100%, 4), Fireball (80%, 5) and Lightning (20%, 40) have EVs of 4, 4 and 8, but against a 15 HP enemy Lightning is worth 3 because damage beyond 15 is wasted. Count unusable benefits and hidden penalties (p.195-196).
  - To apply, recompute EV against the real targets in the encounter, capping at remaining HP or other limits.
- Perceived probability drives play. A player who misses Lightning a few times may decide it never hits (p.196).
  - To apply, decide which odds are shown to players and check what a new player believes after a few tries.
- Regret. Kahneman and Tversky found 82% chose a sure $2400 over a gamble worth $2409. People are conservative about gains and will gamble to avoid a sure loss. Estimates of causes of death inflate feared risks (accident estimated 32%, actual 5%) (p.196-197).
  - To apply, expect players to avoid options with a small chance of a total loss, and test whether a safe option is chosen even when its EV is lower.
- Lens #28, Expected Value (p.198). Ask the actual and perceived chance of each event, the value of the outcome and any intangible value, and whether each action's EV gives interesting choices without being too rewarding or too punishing. Put a guessed number on hard-to-quantify items like boots of speed and refine it through testing.
- Five ways skill and chance interact (p.198-200).
  - Estimating chance is a skill (blackjack, card counting).
  - Skills have a probability of success, so even chess and baseball involve risk that needs balancing.
  - Estimating an opponent's skill is a skill, including bluffing about your own.
  - Predicting pure chance is an imagined skill (lucky streak fallacy, gambler's fallacy) that designers can use.
  - Controlling pure chance is an imagined skill (dice rituals, lucky charms) that makes chance feel like skill.
  - To apply, list where the target asks players to estimate odds or read opponents, and where players act as if they control a random result.
- Lens #29, Chance (p.200). Ask what is truly random and what only feels random, whether randomness feels exciting or hopeless, whether a different distribution curve would help, whether there are interesting risks, and how chance and skill relate, including making randomness feel like skill and skill feel like risk. Chance appears wherever the player meets the unknown, and dice are one case of it.

## Chapter 11. Game mechanics must be in balance

- Balancing is adjusting elements until they give the intended experience. It is the most artful part of design, like setting the amounts in a recipe (p.203).

### Balance type 1. Fairness

- Symmetrical games give all players equal resources and best measure who is most skilled. The small first-move edge is settled at random, or given to the least skilled player, as in "youngest player goes first" (p.203-204).
  - To apply, find every remaining asymmetry in a symmetrical design (first turn, starting hand) and decide whether it goes to chance or to the weaker player.
- Five reasons for asymmetry. Simulate a real situation (WWII Axis and Allies). Let players explore the space (ten fighters make 100 pairings). Personalise to each player's skills. Level the field (Pac-Man's four ghosts, golf handicaps). Create interesting situations (Bhaga Chall, five tigers against twenty goats with different goals) (p.204-205).
  - To apply, state which of the five reasons each asymmetry in the target serves, and cut any that serves none.
- Value-sum method, the Biplane Battle example. Score attributes (Low 1, Medium 2, High 3) and total each side. Play showed the Sopwith Camel losing, so Firepower was weighted double. Raising the Camel's Firepower to High evened the totals at 8, and that theory must then be playtested (p.205-206).
  - To apply, put every unit, deck or class in a table with weighted attribute scores, compare totals to observed win rates, and reweight until the table predicts the results.
- The model informs the balance and the balance informs the model. Balancing starts only once the game is playable. The old rule of thumb is six months of balancing after a working version (p.206-207).
  - To apply, schedule balancing time after the build is playable and keep the model next to the test results.
- Rock, paper, scissors. Make sure anything with an advantage is beaten by something else, as fighting games do (p.207).
  - To apply, draw a "beats" graph of the target's options and look for any node with no incoming arrow.
- Lens #30, Fairness (p.207-208). Ask whether the game should be symmetrical or asymmetrical and why, whether it should measure skill reliably or challenge everyone, and how players of different skill can play together. Alien vs. Predator is unbalanced but accepted because it fits the story, and winning as an Alien is a point of pride.

### Balance type 2. Challenge versus success

- Keep players in the flow channel between anxiety and boredom (p.208). Five techniques (p.208-209).
  - Raise difficulty with each success, using a tense and release pattern.
  - Let skilled players get through easy parts fast.
  - Create layers of challenge, such as grades where C passes and A is optional.
  - Let players choose difficulty, at the cost of balancing several versions and arguments over which is "real".
  - Playtest with a mix of novices and experts.
  - To apply, mark which of the five the target uses and name a specific change for the missing ones.
- Decide what percentage of players should finish, and design for that, instead of making late levels so hard most quit (p.209).
  - To apply, write the target completion rate for the run and compare it with test data.
- Learning the controls and goals is itself a challenge, so early levels should be very simple and give early wins for confidence (p.209-210).
  - To apply, check the first encounter asks for nothing beyond learning the controls and the goal.
- Lens #31, Challenge (p.210). Ask what the challenges are, whether each is too easy or too hard, whether they suit many skill levels, how they rise with success, whether there is enough variety, and what the maximum challenge is.

### Balance type 3. Meaningful choices

- Meaningful choices change what happens next (where to go, how to spend, offence or defence, safe or risky) (p.210).
- Two traps. Choices that are all the same (50 cars that drive alike) and choices where one is clearly best. A clearly best option is a dominant strategy, and once found the game is solved. Hidden ones found by players are exploits (p.210-211).
  - To apply, for each choice point list the options and check that no two play the same and none wins in every case. If a fix leaves you unsure of the best play, Schell treats that as progress to study (p.211).
- Mateas's rule. More choices than desires overwhelms, fewer frustrates, and matching them gives freedom. A fork in the road wants two options, and a Sims clothes shop wants many (p.211).
  - To apply, estimate what the player wants at each choice point and size the option count to it.
- Lens #32, Meaningful Choices (p.212). Ask what choices are asked, whether and how they are meaningful, whether the number is right, and whether any dominant strategy exists.
- Triangularity is balanced asymmetric risk, where the player chooses between low risk with low reward and high risk with high reward. Schell finds it missing in about eight of ten prototypes that are "just not fun". In Space Invaders the saucer (100 to 300 points, hard and dangerous to hit) breaks up the routine of shooting near aliens (p.212-213).
  - To apply, find or add one high-risk, high-reward option at each major decision (an elite enemy, a gamble node, a greedy play).
- Lens #33, Triangularity (p.213). Ask whether the game has triangularity, how to add it, and whether rewards match the risks.
- Balance triangularity with expected value. In Qix, a slow rectangle has half the success chance of a fast one, so it pays double (200 against 100) to keep EV equal at 20. Estimate the chances and let testing correct the model (p.213-214).
  - To apply, set the risky option's payout so its EV equals the safe option's, then adjust from test data.

### Balance type 4. Skill versus chance

- Too much chance cancels skill and the reverse. Skill games act as judgments, chance games feel casual. Preference varies by audience (German board gamers prefer less chance). A common method is to alternate chance and skill, as in dealing cards then playing them, for tension and release (p.214).
  - To apply, map each step of a turn as chance or skill and check they alternate.
- Lens #34, Skill vs. Chance (p.215). Ask whether players come to be judged or to take risks, whether the game is serious or casual, whether tedious parts need chance, and whether too-random parts need skill or strategy.

### Balance type 5. Head versus hands

- Decide how much is physical dexterity and how much thinking, and say so clearly. Pac-Man 2 looked like a platformer but was a psychological puzzle game, so both audiences were let down. Games Magazine rated games from "fingers" to "brain" (p.215-216).
  - To apply, rate the target from 1 (all physical) to 10 (all mental) and check that the store page and first minutes signal the same number.
- Lens #35, Head and Hands (p.216). Ask whether players want action or thought, whether more puzzles would help, where players can rest their brains, whether dexterity and clever strategy can be alternative routes, and what the 1 to 10 score is. Pair with Lens #16, the Player.

### Balance type 6. Competition versus cooperation

- Both are basic urges, and games give a safe way to test how people act under stress. Joust alternates Team Waves (3000 each if both survive) with Gladiator Waves (3000 for the first kill on the other player). Team competition combines both (p.216-217).
  - To apply, list moments where players gain by helping each other and moments where they gain by beating each other, and decide the mix.
- Lens #36, Competition (p.217). Ask whether skill is measured fairly, whether and why people want to win, whether winning is a source of pride, whether novices and experts can both compete, and whether experts reliably beat novices.
- Lens #37, Cooperation (p.218). Ask whether players can communicate enough, whether they are friends or strangers who need an icebreaker, whether teamwork gives synergy (2+2=5) or antergy (2+2=3), whether roles differ, whether some tasks are impossible alone, and whether tasks force communication.
- Lens #38, Competition vs. Cooperation (p.218). Ask where the game sits from 1 (competition) to 10 (cooperation), whether players can choose, what the audience prefers, and whether team competition fits.

### Balance type 7. Short versus long

- Too short and strategies cannot develop. Too long and players get bored or avoid the time commitment. Win and lose conditions set the length. House-ruled Monopoly runs three hours instead of ninety minutes. Spy Hunter gave unlimited cars for the first ninety seconds. Minotaur's "Armageddon" moved survivors into a deadly room after twenty minutes so games end under 25 minutes with a winner (p.219).
  - To apply, measure session length in tests and change the end condition, not a timer, to move it.
- Lens #39, Time (p.220-221). Ask what sets the length, whether players are frustrated by early endings or bored by long ones, whether a time limit would help, and whether short rounds inside a larger round would help. Leave players wanting more.

### Balance type 8. Rewards

- Rewards tell players they did well and fulfil desires. Nine kinds (p.221-222).
  - Praise, through words, sounds or a character.
  - Points, often enough on a public high score list.
  - Prolonged play, such as extra lives or time.
  - A gateway to a new area, level or door.
  - Spectacle, such as Pac-Man's intermission, rarely enough alone.
  - Expression, such as clothes and decorations.
  - Powers that reach goals faster (kinging, Mario growing, Quake weapons).
  - Resources, or virtual money spent on the other kinds.
  - Completion of all goals.
  - To apply, tag every reward in a run with its kind and add a missing kind where it fits.
- Rewards combine (points to an extra life, an item that grants a power, a completion spectacle), and more reward types is generally better. Players acclimatise, so raise reward values as they progress. Variable rewards last longer than fixed ones at the same average (1/3 chance of 30 instead of a flat 10), like donuts on random days (p.222).
  - To apply, check reward size grows over a run, and convert one fixed payout into a variable one with the same EV.
- Lens #40, Reward (p.222). Ask what rewards exist and what others could, whether players are excited or bored by them, whether they understand them, whether they are too regular, how they connect to each other, and whether they build at the right speed. Expect "good enough" after trial and error.

### Balance type 9. Punishment

- Three reasons to punish. It creates endogenous value (Lens #5), risk is exciting, and it raises challenge (p.223).
- Kinds of punishment, mostly rewards reversed (p.223-224).
  - Shaming (a "Missed" message, sad sound).
  - Loss of points, which is rare because it cheapens earned points.
  - Shortened play (lose a life, time off the clock).
  - Terminated play (game over).
  - Setback to the level start or a checkpoint, with checkpoint placement as the balancing task.
  - Removal of powers, felt as unfair when permanent (Ultima Online's lost skill points) and fairer when temporary (bumper tanks spin for five seconds).
  - Resource depletion (money, ammo, shields, hit points).
  - To apply, list every failure consequence in the target by kind and check each against how much the player loses.
- Reward reinforces better than punishment. Diablo's hunger penalty felt like a chore, so food became a temporary boost instead (p.224).
  - To apply, for each punishment, write the reward version that encourages the same behaviour and compare.
- Toontown's sad state combined light setback, item loss, a shamed pose, thirty seconds of slow walking and an empty laff meter. Lighter made battles boring and harsher made players too cautious (p.224-225).
  - To apply, stack several small consequences and tune the stack between "no risk" and "too cautious" through tests.
- All punishment must be for things players understand and can prevent, or they call the game unfair. Ultima III erased the save on party death, so players switched off the computer to dodge it. Even hardcore players need to see how to avoid punishment (p.225).
  - To apply, for each punishment, name the player action that would have prevented it and check the player could have seen it coming.
- Lens #41, Punishment (p.225). Ask what the punishments are, why they exist, whether they feel fair, whether rewards could replace them, and whether strong punishments match strong rewards.

### Balance type 10. Freedom versus controlled experience

- Control over everything is more work and can be boring. Choose where to give freedom. In Aladdin's Magic Carpet VR, every tester flew straight to Jafar, so that scene took control of the flight and no tester noticed (p.226).
  - To apply, find scenes where testers all do the same thing and consider scripting them for a better result.

### Balance type 11. Simple versus complex

- Innate complexity comes from complex rules, often with exceptions, added for simulation or for balance. Emergent complexity comes from simple rules producing complex situations, as in Go, and is the kind that is praised. The aim is a simple ruleset that produces balanced surprises (p.226-227).
- Words that mark innate complexity are "unless", "except", "exception", "but" and "even if". The chess pawn rule has some, but it produces rich pawn structures, so it pays for itself (p.227).
  - To apply, search the rules text for those words and check whether each exception creates emergent play or only patches a problem.
- Lens #42, Simplicity/Complexity (p.227-228). Ask what innate complexity exists, whether it could become emergent, whether emergent complexity arises and if not why, and what is too simple.
- Natural balancing comes from interactions. Artificial balancing adds rules. Space Invaders has one rule (fewer invaders move faster) that makes the game start slow, speed up and get harder to hit as the player succeeds (p.228).
  - To apply, before adding a balancing rule, look for an existing rule whose side effect would produce the same curve.
- Elegance is a simple system that works in complex situations. Rate an element by counting its purposes. Pac-Man's dots give a short-term goal, a long-term goal, triangularity by slowing the player, points, and extra lives (p.228-229).
- The Hollywood rule says a line serving fewer than two purposes should be cut. Ask what to remove before what to add, and merge single-purpose elements. The Pirates of the Caribbean ride merged the tutorial host and the final villain into one character (p.229).
  - To apply, list every element of a screen or system with its purposes, then merge or cut those with only one.
- Lens #43, Elegance (p.229). List the elements and count each one's purposes as an elegance rating, then combine or remove those with one or two, and see whether those with several can take on more.
- Character balances elegance. The Leaning Tower of Pisa, Monopoly's tokens and Mario as a plumber are pointless quirks that give character (p.229-230).
  - To apply, before cutting a single-purpose element, ask whether players talk about it fondly.
- Lens #44, Character (p.230). Ask whether players talk excitedly about something strange in the game, whether it has funny qualities that make it unique, and whether it has flaws players like.

### Balance type 12. Detail versus imagination

- Games leave part of the model to the player's mind. Five tips (p.230-231).
  - Only detail what you can do well. Subtitles beat robotic speech synthesis because players imagine a better voice.
  - Give details the imagination can use. Chess pieces as a medieval court help players remember how they move.
  - Familiar worlds such as streets and houses need little detail, while unfamiliar places being taught need much.
  - Use the binocular effect. A close-up at the start lets players imagine detail on a tiny sprite later.
  - Give details that inspire imagination, such as commanding a royal army, tied to reality by a thin thread.
  - To apply, list each asset or line the target shows, mark any that falls below what players would imagine, and replace it with a lighter cue or an early close-up.
- Lens #45, Imagination (p.232). Ask what players must understand to play, whether imagination can help, what high-quality detail can be given, what low-quality detail imagination could replace, what detail the imagination can reuse, and which details inspire or stifle imagination.

### Balancing methodologies

- Designers differ and some methods conflict, so experiment (p.232). Use the Lens of the Problem Statement before jumping to fixes (p.232).
  - To apply, write the imbalance as one problem sentence before changing any number.
- Doubling and halving, from Sid Meier through Brian Reynolds. Change a value by double or half instead of small steps, then bisect (rocket damage 100 to 50, then 75). Push further than intuition says so the effect is felt and not confused with random noise (p.232-233).
  - To apply, for an overtuned value, halve it in the next test build, then try the midpoint.
- Train intuition by guessing exactly (13.8 feet per second, 1:32 in the microwave), then test the guess (p.233).
  - To apply, write an exact target number before each tuning test and record how far off it was.
- Document your model of how the balanced things relate (p.233).
  - To apply, keep a short file of the assumed formulas and weights next to the data.
- Tune your model as you tune the game, noting whether each experiment matched the model (p.233).
  - To apply, after each test, mark the result as matching or not matching the model and update the model.
- Plan to balance by exposing expected tuning values, ideally editable while the game runs (p.233-234).
  - To apply, move every tuning number into data files or live-editable resources before testing.
- Let the players do it is a warning. Players want challenge but also an easy win, so they overpower themselves, get bored, and then find normal balance dull (Free Parking jackpots). Difficulty levels are the usual exception (p.234).
  - To apply, leave tuning to designers and offer only difficulty settings to players.

### Balancing game economies

- An economy is two meaningful choices, how to earn money and how to spend it. Money is anything tradeable, such as skill points. Spending usually feeds earning in a loop (p.234).
  - To apply, list every earn source and spend sink in the target and draw the loop between them.
- An economy balances many types at once. Fairness (unfair purchases or earning), challenge (buying the game too easy, earning too hard), choices (enough ways to earn and spend), chance (skill or luck earnings), cooperation (pooling, collusion holes), time (earning speed), rewards (earning and spending feel good), punishment (effect on earning and spending), freedom (buy and earn as wished). Tools include controlling how much money the game creates (p.235).
  - To apply, answer the nine checks for the target's currency and flag any with no answer.
- Lens #46, Economy (p.235). Ask how players earn and whether there should be more ways, what they can buy and why, whether money is too easy or hard to get, whether earn and spend choices are meaningful, and whether one universal currency or several specialised ones fits.
- Dynamic difficulty adjustment has three problems. It spoils the reality of fixed opponents, it can be exploited by playing badly on purpose, and it removes the pleasure of improving through practice (The Incredible Hulk weakened enemies after repeated deaths). Schell expects good solutions to be clever and counterintuitive (p.236).
  - To apply, if the target adapts difficulty, check whether players can see it, exploit it, or lose a mastery goal to it.
- Lens #47, Balance (p.236). Ask whether the game feels right and why or why not.

## Chapter 12. Game mechanics support puzzles

- Puzzles make the player stop and think, on the head side of Lens #35 (p.239). Scott Kim says a puzzle is fun and has a right answer. Puzzles are not replayable once solved. Schell defines a puzzle as a game with a dominant strategy, a miniature game whose goal is to find that strategy, like a penguin as a bird that cannot fly (p.239-240).
  - To apply, mark which parts of the target stop being interesting once a known answer exists, and treat those as puzzles.
- Puzzles are not dead. They became implicit and woven into the environment. The 7th Guest's cans, chessboard and planets were incongruous, while Wind Waker's lava, switch and light-paralysis puzzles serve the avatar's own goals and serve more purposes under Lens #43. Fighting, racing and shooter decisions are puzzles too (p.240-241).
  - To apply, check each puzzle's goal is the character's goal in that place, and rewrite any that is a detached minigame.

### Ten puzzle principles

- 1. Make the goal easily understood. The disk-on-shaft puzzle shows its goal at a glance where the Eibe puzzle does not. Hasbro's Nemesis Factor did not sell because the goal was unclear for each of its 100 puzzles. Working out the goal suits only diehard fans. Use Lens #25 (p.242-243).
  - To apply, show the puzzle to a new player and ask them to state its goal within a few seconds.
- 2. Make it easy to get started. The 15 Puzzle shows how to begin, while the letter-digit sum puzzle does not. Scott Kim says to build a good toy first, and a Rubik's Cube invites handling (Lens #15) (p.243-244).
  - To apply, check the player knows their first two moves and wants to touch the pieces.
- Lens #48, Accessibility (p.244). Ask how players will know how to begin and whether it must be explained, whether it resembles something familiar and how to point that out (or how to explain what is new), and whether it makes people want to touch it.
- 3. Give a sense of progress. A riddle is a stone wall, while a puzzle lets players feel closer step by step. Twenty Questions turns a riddle into a puzzle because 2 to the 20th exceeds a million. Completing one face of a Rubik's Cube shows progress (p.244-245).
  - To apply, add visible interim states (a lit rune, a filled slot) between the start and the answer.
- Lens #49, Visible Progress (p.245). Ask what progress means here, whether there are enough interim steps, and what hidden progress could be revealed.
- 4. Give a sense of solvability. Visible progress helps, as does stating an answer exists. A Rubik's Cube is sold solved and scrambled by the player, so it is clearly solvable (p.245).
  - To apply, show the solved state first, or let the player create the scramble.
- 5. Increase difficulty gradually across the steps of one puzzle. Jigsaws go from flipping pieces to corners, edges, frame, sorting colour, obvious sections, then the rest. One Tough Puzzle removes the easy steps and is only a novelty. Let players choose the order of steps, as in crosswords, which is called parallelism (p.246-247).
  - To apply, list the steps of the solution in order with a difficulty note each, and add easier opening steps if the first one is hard.
- 6. Parallelism lets the player rest. Several related puzzles at once mean a stuck player can switch and return refreshed ("a change is as good as a rest"), as in crosswords, Sudoku and most RPGs (p.247).
  - To apply, make sure a floor offers at least two open challenges when the player could get stuck.
- Lens #50, Parallelism (p.247). Ask where bottlenecks block progress and whether parallel challenges can be added, whether parallel challenges differ enough to give variety, and whether progress on one can ease the others.
- 7. Pyramid structure extends interest. Small puzzles feed clues to one larger puzzle, as Jumble's four words supply letters to the cartoon's punch line, combining short- and long-term goals (p.247-248).
  - To apply, make each side challenge on a floor yield a piece of the floor's final challenge.
- Lens #51, the Pyramid (p.248). Ask whether all pieces can feed one final challenge, whether small pyramids can build into larger ones, and whether the top challenge is interesting, compelling and clear enough to work toward.
- 8. Hints extend interest. A timed hint can restore hope. Nemesis Factor had a hint button giving a cryptic one- or two-word clue, then a plainer one, with a small points cost. A hint is better than a walkthrough (p.248-249).
  - To apply, add tiered hints, cryptic first then plainer, with a small cost.
- 9. Give the answer. The "Aha!" comes from seeing the answer after real thought, as in mystery novels. Offer stuck players the answer inside the game (p.249).
  - To apply, add an in-game reveal for a player who has tried for a set time.
- 10. Perceptual shifts are a double-edged sword. The six-matchstick, four-triangle puzzle gives either a big reward or nothing, with no progress or gradual difficulty. Use such puzzles sparingly where players expect steady progress (p.249-250).
  - To apply, flag any puzzle that is solved only by one leap of insight and give it partial steps or make it optional.
- Lens #52, the Puzzle (p.250). Ask what the puzzles are, whether there should be more or fewer and why, which of the ten principles apply to each, and whether any are incongruous and how to integrate them (with Lens #43).
