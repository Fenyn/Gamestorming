# Chapters 13 to 16: interface, interest curves, story, indirect control

Source is Schell, The Art of Game Design, 1st edition. PDF pages 252 to 329, lenses 53 to 73. Every cite is a PDF page. These are paraphrases, so read the page before quoting anything.

Edition notes. This edition has eight interface tips and eight story tips. It has no tip called "design around a physical interface" (that idea is Lens 54, p.257), no tip "if it looks different it should act different" (the nearest line is about game objects in chapter 10, p.167), and no story tip "make it real".

## Chapter 13. Players play games through an interface (p.252-275)

### Purpose of an interface

- The interface is the thin layer where player and game meet, and when it fails the experience stops. Its goal is to make players feel in control of their experience, ahead of looking nice or feeling fluid (p.253).
  - To apply, play the target screen and write down each moment where an input did something other than what you expected.
- Lens 53, Control (p.253-254). Does the interface do what players expect; is it easy or hard to master; do players feel they strongly influence the outcome; do they feel powerful, and could they feel more so?

### Breaking the interface down

- Start with a player and a world. Physical input is what the player touches to change the world (board pieces, a pad, keyboard and mouse). Physical output is how they perceive the world (the board, a screen, audio) (p.254-255).
- The virtual interface is a conceptual layer between physical input/output and the world. It has input elements such as a selection menu and output elements such as a score display, floating damage numbers, or the camera view into a 3D world. It can be almost absent or very dense (p.255).
- Mapping. Each arrow in the diagram is a transformation written in code, and the six arrows together define the interface (p.255-256).
  - Arrow 1, physical input to world. How fast the avatar runs, how quickly it stops, whether pressure, acceleration over time or a double tap changes the result (p.256).
  - Arrow 2, world to physical output. Which part of the world the player can see and how it is shown (p.256).
  - Arrow 3, physical input to virtual interface. What click, double click and drag do in menus (p.256).
  - Arrow 4, virtual interface to world. What a menu choice does to the world and whether it takes effect at once or after a delay (p.256).
  - Arrow 5, world to virtual interface. When scores and bars change, and whether world events open pop-ups, menus or mode changes such as battle menus (p.256).
  - Arrow 6, virtual interface to physical output. Which data appear, where, in what colour and font, and whether low hit points pulse or sound (p.256).
  - To apply, make a six-row table for the target HUD or screen, write one sentence per arrow describing its current mapping, and mark any row nobody chose on purpose.
- Two more arrows run into and out of the player's imagination. An immersed player describes play as actions ("I ran up the hill, threw my grappling hook") instead of button presses, and this only happens once the interface is second nature (p.258).
  - To apply, after a playtest ask the player to retell what happened and note every point where they mention buttons, menus or the camera instead of what their character did.
- Lens 54, Physical Interface (p.257). What does the player touch and can it be more pleasing; how does it map to world actions and can the mapping be more direct; if the hardware is fixed, what metaphor maps input to the world; how does it fare under the Lens of the Toy; how does the player see, hear and touch the world, and could an output device make it feel more real? The book notes that custom controllers such as the DDR mat, Guitar Hero guitar and Wiimote revived old mechanics (p.257).
- Lens 55, Virtual Interface (p.257-258). What must the player know that the world does not show; when do they need it (always, sometimes, end of level); how can it reach them without getting in the way; is anything easier to handle through a virtual control than directly; which virtual interface fits the physical one (pop-up menus suit a gamepad poorly)?
- Lens 56, Transparency (p.258-259). Does the interface let players do what they want; can practised players use it without thinking; do new players find it intuitive, and would custom controls help or hurt; does it misbehave in edge cases such as corners or high speed; does it hold up under stress; on which of the six arrows does any confusion happen? Figure 13.6 is a Penny Arcade parody of a non-transparent controller (p.259).

### The loop of interaction and feedback

- Information circles from player to game and back, and what the game returns (feedback) shapes what the player does next (p.259).
- The basketball net changes nothing in the rules but slows the ball so everyone sees it went in (p.259).
- The Swiffer case. Read through Lens 12 Problem Statement, the broom and dustpan have five stated problems (dust left behind, awkward posture, poor pickup, dirty hands, spills on transfer) and the Swiffer answers each (p.260). It also answers an unstated sixth problem, no feedback on how clean the floor is, by showing the dirt on the cloth. That gives the pleasures of usefulness, purification and secret knowledge, and users come to anticipate it (p.261).
  - To apply, list the target's unstated problems, including "the player cannot tell whether this action made a difference", and give each effort a visible residue the player can look at afterwards.
- Lens 57, Feedback (p.261). At each moment, what do players need to know, what do they want to know, what do you want them to feel and what feedback creates that, what do they want to feel and can they create a situation that gives it, and what is their goal and what feedback helps them reach it? The book says feedback serves as judgment, reward, instruction, encouragement and challenge, and must be checked moment by moment.
- The crosswalk case. A US walk button gives no sign it registered, so people press repeatedly and watch the lights anxiously. Some UK crossings light a WAIT sign as soon as the button is pressed, which turns frustration into confidence (p.262).
- Tenth-of-a-second rule. If the interface does not respond within 0.1 s, players feel something is wrong. A jump animation with a quarter- to half-second crouch before leaving the ground is the typical breach (p.262-263).
  - To apply, time input-to-visible-response for every action on the target, and give anything slower than 100 ms an immediate acknowledgement (sound, flash, pose) even when the result arrives later.

### Juiciness

- Problem 7 for the broom is that sweeping is boring, which breaks down into repetitive motion and attention spent on something with no surprises (p.263). The Swiffer's hinged head swings a long way from a small wrist turn, which makes it fun to use (p.264).
- Second-order motion is motion derived from the player's action. A system with a lot of easily controlled second-order motion that gives power and reward is juicy: a little interaction yields a steady flow of reward. An interface with little feedback is called dry (p.264).
  - To apply, take the target's main action and list everything that moves, sounds or changes because of one input. If only the direct result moves, add derived motion the player steers (trailing particles, recoil, objects knocked aside) and count the separate rewards a single success gives.
- Lens 58, Juiciness (p.264). Does the interface give continuous feedback; does the player's action create powerful, interesting second-order motion; when you reward the player, how many ways do you reward them at once, and can you add more?
- Feedback this strong can turn work into play. A dry, painful interface in front of a fun game contradicts itself. Fun is pleasure with surprises, so the interface should give both (p.264-265).

### Channels of information

- Four steps for presenting information, mostly on arrows 5 and 6 (p.265).
- Step 1, list and prioritise. The Zelda example lists nine items (rubies, keys, health, immediate surroundings, distant surroundings, other inventory, current weapon, current treasure, bombs) and sorts them into needed every moment (immediate surroundings), glanced at from time to time (the other seven), and needed occasionally (other inventory) (p.265-266).
- Step 2, list channels. A channel is any route for a stream of data, for example top centre of the screen, bottom right, the avatar, sound effects, music, the screen border, an approaching enemy's chest, a word balloon. Zelda uses a main display and a top dashboard, plus a Select-button mode with an auxiliary display and a bottom dashboard (p.266).
- Step 3, map information to channels. This is done partly by instinct and experience and mostly by trial and error with many sketches. Zelda puts surroundings in the main display, the seven glance items on the dashboard, and other inventory in the auxiliary display (p.267). The dashboard shows on both screens; health takes nearly a third of it; rubies, keys and bombs sit together because each is a two-digit number; weapon and treasure get boxes labelled with their A and B buttons; spare room on the inventory screen carries instructions (p.268).
- Step 4, review dimensions. A channel has dimensions. Damage numbers that fly from an enemy have the value, colour, size and font (p.268). You can reinforce one fact across dimensions (under 50 small and white, 50 to 99 medium and yellow, over 100 large, red and in a special font), or put a different fact on each (colour for friend or foe, size for how close the target is to defeat) so one number carries three facts. The cost of the second approach is teaching players what each dimension means (p.269).
  - To apply, for the target HUD write the full information list, sort it into every-moment, glance and occasional, list every channel available (screen regions, the character, sound, music, world objects), assign each item a channel, then for each channel write down which dimensions (value, colour, size, position, motion, sound) carry meaning and whether they reinforce one fact or carry several.
- Lens 59, Channels and Dimensions (p.269). What data travel to and from the player; which matter most; what channels exist; which channel suits which data, and why; what dimensions each channel has; how should those dimensions be used?

### Modes

- A mode is a change in one of the six mappings. Pressing B so the stick aims a water hose instead of moving the avatar changes arrow 1 (p.269-270). Modes add variety but confuse players who miss the change (p.270).
- Mode tip 1, use as few modes as possible, because each one is something new to learn (p.270).
- Mode tip 2, avoid overlapping modes. Inputs are channels too. With walking, throwing and driving all on one stick, throwing while driving would make the stick steer and aim at once; moving aim to a second stick avoids it. If modes must overlap, put them on different input channels, for example the stick switching between walking and flying while a button switches between fireball and lightning (p.270).
- Mode tip 3, make different modes look as different as possible, checked with the Lenses of Feedback and Transparency. The Unix editor vi started in a command mode that looked identical to its insert mode and gave no sign of which one was active (p.270-271). Ways to show a mode change: change something large on screen (weapon swaps in Halo 2, with ammo shown on the back of the gun), change what the avatar is doing (Jungle King's swing to swim, plus a hair colour change), change the on-screen data (combat menus in Final Fantasy VII), change the camera perspective (p.271).
  - To apply, list every mode on the target with the mapping it changes, merge any two that can be merged, move overlapping ones onto separate inputs, and give each remaining mode at least two visible signals from that list of four.
- Lens 60, Modes (p.271). Which modes do I need, and why; can any be collapsed or combined; do any overlap, and can they move to different input channels; how does the player know the mode changed, and can that be communicated more than one way?

### Interface tips (eight in this edition)

- Tip 1, steal (the top-down approach). Start from a successful interface in the same genre and change it to fit what is new in your game. It saves time and feels familiar; it risks a clone, though one change often leads to others (p.272).
  - To apply, pick the closest shipped game in the genre, copy its HUD layout as a sketch, then list each place your mechanics differ and change only those parts.
- Tip 2, customise (the bottom-up approach). Build the interface from scratch through the information, channel and dimension lists. It may be the only route for novel play and can turn up a new way to play even a familiar genre (p.272).
  - To apply, run the four channel steps on a blank page before looking at any reference game, then compare the result with the stolen layout from tip 1.
- Tip 3, theme your interface. Interface art is often made by a different artist from the world art; check every part of it with Lens 9 Unification so it ties into the rest of the experience (p.272).
  - To apply, put a screenshot of every panel, button and font next to world art and list any element that could belong to a different game.
- Tip 4, sound maps to touch. People readily read sound as touch, and virtual interfaces give almost no touch feedback, so decide what the interface would feel like if it were physical and pick sounds that create that feeling (p.272-273).
  - To apply, for each control write the physical object it would be (a heavy lever, a soft card, a latch), then choose a click, slide or thud that fits that object.
- Tip 5, balance options and simplicity with layers. Players want many options and a simple interface; layer modes and sub-modes using your priority list, as when inventory and configuration sit under Select (p.273).
  - To apply, use the Step 1 priority list and move every occasional item behind one button or sub-screen, keeping the every-moment items on the top layer.
- Tip 6, use metaphors. Resemble something players know. In Toytopia, a network delay between command and toy confused players until a visible radio signal and transmission sound explained it, which also fit the radio-controlled toy theme (p.273-274).
  - To apply, for each rule players find confusing on the target, look for a familiar object or process that behaves the same way and show it on screen.
- Tip 7, test, test, test. Nobody gets an interface right first time. Test early and often, prototype the interface before the game is playable, use paper and cardboard mock-ups players act out, and watch players like an anthropologist to learn their moment-to-moment intentions (p.274).
  - To apply, mock the target screen on paper or as a static image, ask someone to say aloud what they would do at each step, and note where they hesitate.
- Tip 8, break the rules to help your player. Genre rules of thumb get copied without thought. Children's PC games often disable the right mouse button, but small hands press it by mistake, so map both buttons to the same action in any game that needs only one (p.274-275).
  - To apply, list the conventions the target follows, and for each ask whether it helps these particular players; drop the ones that cause errors for them.

## Chapter 14. Experiences can be judged by their interest curves (p.276-291)

- The juggling show. The first version ran balancing, rings, clubs, club passing, then five-ball juggling as the finale, and the end fell flat. Mark Tripp sketched its shape and the shape audiences prefer: open with a bang, ease off so they can relax and get to know you, build with bigger routines, finish with a finale beyond expectations. Reordering alone, with rings first and club passing last, roughly doubled the response despite more drops. Seeing this takes stepping back from the details to view the whole as the audience does (p.277-278).
- An interest curve plots a guest's interest over the course of an experience. The quality of an entertainment experience is how well its sequence of events holds interest (p.278-279).
- Parts of a good curve, Figure 14.3 (p.279).
  - A, entry. Guests arrive with interest set by expectations from packaging, ads and friends. High is good, but overinflated expectations lower the overall experience.
  - B, the hook. Something that grabs the guest early (an opening number, the guitar riff in Revolution, the ghost in Hamlet, an intro movie). It hints at what is coming and carries the guest through the slow opening.
  - C to F, rising peaks. Interest climbs with temporary peaks (C, E) and dips (D, F) that exist only to rise again.
  - G, climax.
  - H, close. The story resolves and the guest leaves with interest left over, the meaning of "leave them wanting more".
- A bad curve, Figure 14.4 (p.280). The guest is disappointed straight away with no hook (a), a brief peak fades (b), interest crosses the interest threshold where they quit (c), a later peak comes too late (d), and the experience peters out with no climax (e).
- Uses of the curve. Chart expected interest to expose trouble spots, compare observed interest with what you predicted, and draw separate curves for different demographics (p.280).
  - To apply, list the beats of the target in order (a tutorial's steps, a run's floors, a scene's moments), score each for expected interest, plot it, mark the hook, the peaks and dips, the climax and the close, and flag any flat stretch, missing hook, or climax that is not the highest point.
- Patterns inside patterns. The same shape appears in three-act films, pop song structure (intro, verse, chorus, verse, chorus, bridge, big finish), Aristotle's complication and denouement, the comedian's rule of three, a teen magazine's "High Dive Horror" anecdote, and a rollercoaster track (p.280-281).
- Aladdin's Magic Carpet example. Drawing the curve exposed a flat stretch. Adding interest there risked dulling what came later, so cutting it was the first idea; the show director added a shortcut tent instead, and operators began telling players to fly into it (p.281-282).
- Half-Life 2 Episode 1 deaths per map, at three difficulties over an average 5 h 39 min, follow the same shape, if deaths are taken as a sign of challenge (p.282).
- Fractal curves. Each long peak can contain the whole pattern in miniature, as many layers deep as needed (p.282-283). Typical games have three levels: the whole game (intro movie, levels of rising interest, final climax), each level (new aesthetics or challenge at the start, rising challenges, often a boss), and each challenge (an introduction and stepped rises). Multiplayer games need a still larger structure, covered in chapter 22 (p.283).
  - To apply, draw one curve for the whole run, one for a single floor or level inside it, and one for a single encounter or tutorial step, and check that each has its own hook, rise and peak.
- Lens 61, Interest Curve (p.283-284). What shape is my curve; does it have a hook; does interest rise gradually with rests; is there a grand finale above everything else; what changes would improve it; is there a fractal structure, and should there be; do my predictions match what players show, and what curve do playtesters draw when asked? Pair it with Lens 16 Player and draw one curve per player type (p.284).

### What comprises interest

- Interest has no units, and only relative change matters. Judge it with empathy and imagination. It breaks into three factors (p.284).
- Factor 1, inherent interest. Some events simply interest people more: risk over safety, fancy over plain, unusual over ordinary, a man wrestling an alligator over a man eating a cheese sandwich. Lens 4 Curiosity helps here (p.284-285).
  - To apply, list the target's events and mark which ones involve risk, spectacle or something unusual; any stretch with none needs one or needs to be shorter.
- Lens 62, Inherent Interest (p.285). What grabs players at once; does the game show or let them do something new to them; which base instincts and which higher instincts does it appeal to, and can it reach more; does dramatic change happen, or the anticipation of it, and can it be more dramatic?
- Events build on one another into a story arc, and some dull events exist to set up interesting ones. In Goldilocks, porridge, chairs and a nap set up the bears finding the intruder (p.285).
- Factor 2, poetry of presentation. The aesthetics of the experience: the more beautiful the writing, music, dance, acting, cinematography or graphic design, the more compelling it is, and best of all on an inherently interesting event. Chapter 20 continues this (p.285).
  - To apply, for each beat on the target note which craft carries it (art, sound, animation, writing) and where the presentation is placeholder or plain.
- Lens 63, Beauty (p.286). What elements make up the game, and how can each be more beautiful; how can elements that are not beautiful alone be combined so they are; what does beauty mean in this game?
- Factor 3, projection. How far the guest uses empathy and imagination to place themselves in the experience (p.286).
  - Lottery example, Figure 14.8. A stranger winning interests you a little, a friend more, yourself most (p.286).
  - Empathy. Characters begin as strangers, become like friends as you get to know them, and at the peak you put yourself in their place (p.287).
  - Imagination. The experience's world need not be realistic but must be internally consistent; a consistent, compelling world immerses the guest, and one contradiction breaks the suspension of disbelief (p.287).
  - Episodic forms build projection through persistent characters and worlds, and one out-of-character episode can spoil the whole series from that point on (p.287).
  - Offering several ways into a world (toys and games from a film) lengthens time spent there and deepens projection, covered in chapter 17 (p.287-288).
  - In interactive work the guest is the main character and perception overlaps imagination, so games with little inherent interest or poetry can still hold players through projection; chapter 18 continues this (p.288).
  - To apply, list what on the target a player can relate to, imagine themselves as, or want to do that they cannot do in life, and find any moment where a character acts out of character or the world contradicts itself.
- Lens 64, Projection (p.288). What can players relate to, and what can be added; what captures their imagination; are there places they have always wanted to visit; can they be a character they could imagine being; are there characters they would like to meet or spy on; can they do things they want to do in real life but cannot; is there an activity that is hard to stop once started?
- Interest factor examples (p.289-290). Chainsaw juggling is high in inherent interest, low in poetry, with some projection that grows in person (Figure 14.9). A violin concerto relies on poetry, with inherent interest from good structure and projection from feeling transported or empathising with the player (Figure 14.10). Tetris has little inherent interest or poetry and intense projection because the guest makes every decision (Figure 14.11).
- Putting it together. You can stack the three factors under the curve to see which one holds interest at each point (Figure 14.12). Drawing a curve keeps you from losing the whole in the details. Games are non-linear, which the next two chapters address (p.290-291).
  - To apply, shade each segment of the target's curve by the factor carrying it and look for long stretches carried by one factor alone.

## Chapter 15. One kind of experience is the story (p.292-312)

- Story/game duality. Like wave-particle duality, story and game appear together; most games have some story, from Final Fantasy's epics to chess's thin layer of warring kingdoms, and children playing abstract Liar's Dice decided they were pirates playing for their souls. Bob Bates likens story and gameplay to oil and vinegar. Both are machines for producing experiences (p.293-294).
- The myth of passive entertainment. The claim that story audiences are passive is false: a listener keeps deciding what will happen and what the hero should do. The only difference is the ability to act, so interactive storytelling is harder but not a different art, and traditional technique applies (p.294-295).
- The dream of a fully free interactive story that feels like the greatest film is attractive and nobody has achieved it (p.295).
- Method 1, string of pearls (also "rivers and lakes"), Figure 15.2. A non-interactive story segment (the string) leads to a period of free play with a fixed goal (the pearl); reaching the goal plays the next segment. The reward for success is more story and a new challenge. Critics call it not really interactive, but players enjoy it and it balances story and play (p.295-296).
  - To apply, lay out the target as a list of strings and pearls, write the fixed goal of each pearl, and check that each string is short and pays off the pearl before it.
- Method 2, story machine. A story is a sequence of events someone tells someone else. A good game generates event sequences interesting enough that players retell them, as baseball, golf, The Sims and RollerCoaster Tycoon do. The more prescripting, the fewer stories the game produces. Having no author does not weaken the experience (p.296).
  - To apply, write three stories a player might tell a friend after a session of the target, then list which rules produced each; if you cannot write three, the system is not generating stories.
- Lens 65, Story Machine (p.297). How can I add more choices about how to reach goals; how can more kinds of conflict arise; how can players personalise characters and setting so they care about outcomes; do my rules produce stories with good interest curves; who can players tell their stories to who will care?
- The two methods are opposites (one needs a story written ahead, the other as little as possible) and cover about 99% of games. The branching-tree dream fails because of five problems (p.297).
- Problem 1, good stories have unity. The problem set up early drives the story to its end; an interactive Cinderella who quits to become an administrative assistant is no longer Cinderella. One beginning that perfectly suits twenty endings is very hard, so branching stories feel watery and disconnected (p.297-298).
- Problem 2, the combinatorial explosion. Ten choices of three with unique outcomes need 88,573 outcomes; twenty need 5,230,176,601. Fusing branches back together (Figure 15.3) makes choices lead to the same place, so they lose meaning, and many scenes still go unseen (p.298-299).
- Problem 3, multiple endings disappoint. Players ask "is this the real ending?" and start thinking about what they should have done instead of experiencing the story; the string of pearls avoids this because the player is always on the right path. They also ask whether they must replay everything to see another ending, which means repeated content that fails Lens 2 Surprise. Psychic Detective filmed several versions of its bottleneck scenes and replay was still tedious. Knights of the Old Republic's light and dark paths work because they are two whole stories (p.299-300).
- Problem 4, not enough verbs. Game characters run, shoot, jump, climb, throw, cast, punch and fly; film characters talk, ask, negotiate, convince, argue, shout, plead and complain. Games cannot yet support much "above the neck", and Chris Swain expects real conversation with characters to change games as talking pictures changed film (p.300).
- Problem 5, time travel makes tragedy obsolete. Freedom costs inevitability. Tragedy needs a doom the audience cannot stop, but every game protagonist can undo what went wrong, as the Prince of Persia narrator's "that's not what really happened" shows; Romeo and Juliet's ending cannot be the "real" ending of a game (p.300-301).
- The dream reborn. Even a human-run Dungeons and Dragons game does not solve all five. The dream fails because it fixes on story instead of experience; aim instead for meaningful experiences that mix story and game structures in new ways (p.301).

### Story tips (eight in this edition)

- Tip 1, goals, obstacles and conflicts. A story needs a character with a goal and obstacles in the way; conflict comes when another character has an opposing goal. This yields problem solving, surprise from unpredictable conflicts, and dramatic change in proportion to the obstacle. In a game the character's goal becomes the player's goal and the obstacles become the challenges, and a challenge that is not an obstacle for the character weakens the experience (p.301-302).
  - To apply, write the main character's goal, list each challenge in the target, and next to each write which obstacle to that goal it represents; rework or reskin any challenge with no answer.
- Lens 66, Obstacle (p.302). What ties the main character to the goal and why do they care; what obstacles stand between them; is an antagonist behind the obstacles, and what is their relationship to the protagonist; do obstacles grow in difficulty; are they big enough, and can they be bigger; how does the protagonist transform to overcome them?
- Tip 2, provide simplicity and transcendence. Game worlds are simpler than the real one and make the player more powerful (p.302-303). Medieval worlds have primitive technology plus magic. Futuristic worlds are usually post-apocalyptic or frontier worlds with technology that works like magic. War suspends normal rules and gives godlike weapons. Modern settings are rare unless the player gains unusual power, as through crime in Grand Theft Auto or the dollhouse life and godlike control of The Sims (p.303).
  - To apply, write one line on how the target's world is simpler than reality and one on what power the player has there that they lack in life, and check that the power does not erase the challenge.
- Lens 67, Simplicity and Transcendence (p.303-304). How is my world simpler than the real one, and can it be simpler in other ways; what transcendent power does the player get, and how can I give more without removing challenge; is the combination contrived, or real wish fulfilment for my players?
- Tip 3, consider the hero's journey. Campbell's monomyth (1949) underlies many myths and shaped Star Wars; Vogler's The Writer's Journey (1992) is the practical version, reportedly used for The Matrix, and is criticised as formulaic (p.304). Vogler's twelve steps (p.304-305):
  1. Ordinary world, where the hero lives a regular life.
  2. Call to adventure, a challenge that disrupts it.
  3. Refusal of the call, the hero's excuses.
  4. Meeting with the mentor, who gives advice, training or aid.
  5. Crossing the threshold into the adventure world, often under pressure.
  6. Tests, allies, enemies, as the hero learns how that world works.
  7. Approach to the cave, setbacks that demand something new.
  8. The ordeal, a life-or-death peak.
  9. The reward, survival and the prize.
  10. The road back to the ordinary world with problems unsolved.
  11. Resurrection, a greater crisis that uses everything learned.
  12. Return with the elixir, the hero's success improving the ordinary world.
  - Steps can be dropped, added or reordered, and the journey traced with Lens 61 looks like an interest curve. It is a skeleton that stories share, not a recipe. Bob Bates calls it a circuit tester for finding where a story lacks mythic current. Write the story first, then check it against the journey (p.305).
  - To apply, map the target's finished story beats onto the twelve steps and note which steps are missing, then decide for each whether adding it would help or make the story predictable.
- Lens 68, Hero's Journey (p.306). Is my story heroic; how does it line up with the journey; would more archetypal elements improve it; does it follow the form so closely it feels hackneyed?
- Tip 4, put your story to work. Story is the most pliable tetrad element: a few words can change it, while gameplay takes weeks and technology months (p.306). A flight game could only render green fog to hide terrain pop-in, so the story made it toxic gas released by invading aliens. In Mordak's Revenge, collecting keys to open the wizard's castle became collecting summoning stones that pull Mordak to wherever the player stands, which made the better mechanic fit (p.306-307).
  - To apply, list each technical limit or desired mechanic on the target that the fiction currently fights, and write a story change that explains it.
- Tip 5, keep your story world consistent. The French saying about a spoonful of sewage spoiling a barrel of wine applies: one inconsistency breaks the world for good, as "jumping the shark" did for Happy Days. If pockets hold a microwave oven, they must not refuse an ironing board as too big (p.307).
  - To apply, write the target world's rules as a list (what fits in a pocket, who can be talked to, what kills) and check every scene and item against it.
- Tip 6, make your story world accessible. Verne sent his travellers to the moon by cannon though rockets existed, because rockets had barely improved from Congreve (1812) to Hale (1840) while cannon shells grew tenfold from Dahlgren's 100-pound gun (1855) to Rodman's 1000-pound Columbiad (1860); what the audience believes matters more than accuracy (p.308). In the Pirates of the Caribbean game the ship speed was raised to feel right, every ship had the wind behind it so players could steer like a car or motorboat, and the mast flags were turned to match how flags look on car antennas once players kept asking (p.308-309). When something strange is unavoidable, call attention to it and explain it, as students did with "Hamster Cannons on sale" signs in their pet shop opening (p.309-310).
  - To apply, mark every element on the target that players will judge against their own experience, adjust any that feel wrong even if accurate, and introduce each truly strange element visibly before the player needs to use it.
- Lens 69, Weirdest Thing (p.310). What is the weirdest thing in my story; how do I keep it from confusing or alienating players; if there are several, should some go or merge; if nothing is weird, is the story still interesting?
- Tip 7, use cliches judiciously. Cliches are familiar and so understandable; successful games tend to combine something familiar with something new, as a lonely, incompetent, canine or robotic ninja, or a third-grader secretly a ninja, would. Overusing cliches and banning them are both errors (p.310-311).
  - To apply, name the cliche the target rests on and the one twist that makes it new; if there is no twist, or no familiar anchor, add one.
- Tip 8, sometimes a map brings a story to life. Stevenson drew an island map on a rainy holiday and Treasure Island grew from it. Sketching the place a game happens in forces questions about who lives there, what they do and why (p.311).
  - To apply, sketch a map of the target's location and write one line per area on who is there and why.
- Lens 70, Story (p.311-312). Does my game need a story, and why; why will players care about it; how does it support aesthetics, technology and gameplay, and can it do better; how do they support it, and can they do better; how can the story be better?

## Chapter 16. Story and game structures can be merged with indirect control (p.314-329)

- The story and gameplay conflict is about freedom, which gives players the feeling of control and makes projection easy (p.315).
- Lens 71, Freedom (p.315). When do players have freedom of action, and do they feel free then; when are they constrained, and do they feel it; where could they feel freer; where does too much freedom overwhelm them?
- Players need the feeling of freedom, not true freedom. A designer who makes players feel free with few or no real choices gets both that feeling and an ideal interest curve and set of events. The designer cannot control players directly but can steer them indirectly, and six methods do most of the work (p.315).
- Method 1, constraints. "Pick a colour" allows millions of answers; "pick red, blue or green" allows three and still feels like a choice, and some people prefer it (p.316). At a candy stand with sixty flavours, reciting the list overwhelmed customers and "name any flavour" left them stuck; "we have nearly everything, and the most popular are these six" sold well, and the list was rotated to move old stock (p.316). An empty room with two doors means the player takes one of them; an open field or a mall does not (p.316-317).
  - To apply, for each open choice on the target (a shop, a map, a build screen) offer a short featured set inside the full set and track which items players pick.
- Method 2, goals. Given the goal "find all the bananas", players head for the door with bananas behind it. Sculpt the world around the goals; a racing game that marks the fastest route needs only a few side streets for a sense of freedom, and content players never see wastes resources (p.317). The fly etched in the Schiphol airport urinals is an implicit goal that cut cleaning costs without removing any freedom (p.317).
  - To apply, write where you want players to go next on the target, and place the item or objective that serves their current goal there; cut any built content that no goal leads to.
- Method 3, interface. Players set expectations from the interface. A plastic guitar means nobody tries to stage dive; on the ship's wheel and heavy cannons of the pirates attraction nobody asked to sword fight. The avatar sets expectations too: Lara Croft, a dragonfly, an elephant and a Sherman tank each suggest different actions (p.317-318).
  - To apply, list the actions the target's controls and avatar suggest at a glance, and remove or change any suggestion the game cannot honour.
- Method 4, visual design. Control where players look and you control where they go. Figure 16.2 draws the eye to the centre and Figure 16.3 pushes it to the edges and beyond; quilt designers keep the eye moving (p.318-319). The Disneyland castle pulls arriving guests to the hub, where landmarks pull them outward in different directions; Walt called such a landmark a "weenie", after the hot dog trainers wave to steer a dog's gaze (p.320). Good level design pulls the player through by the eye (p.320).
  - Aladdin throne room. Players on flying carpets ignored the Sultan and flew round the pillars and ceiling; the team was about to take control and drag them over when the art director painted a single red line on the floor to the throne. Over 90% followed it and waited for the Sultan, and in interviews asked "What red line?" The line was dominant enough that players stopped noticing the columns and chandeliers that had suggested flying around (p.320-322). In the four-player version the line pulled everyone to the throne, so it was split into three branches, and most groups divided two to the throne, one left, one right (p.322).
  - To apply, take a screenshot of the target scene, mark the single most eye-catching element, and check that it sits on the path you want; if players must split, give them several landmarks of similar weight.
- Method 5, characters. If players care about characters enough to obey, protect, help or destroy them, characters steer what players try. Animal Crossing's Happy Room Academy scores your house and players work to avoid an imagined disapproving look; in Ico, spirits dragging the princess toward a hole make the player rush to her even though she is not yet hurt. Players must care first (p.323).
  - To apply, pick the action you want on the target and give it a character who asks for it, needs it, or will be let down without it, after a scene that makes players care about that character.
- Method 6, music. Restaurants play fast music at lunch rush to speed eating and slow music in quiet hours to make diners linger, and diners feel fully free (p.323). Music can make players search for something hidden, smash everything without slowing, sense they are going the wrong way, move slowly and carefully, worry about hurting bystanders, or go as far and fast as possible without looking back (p.323-324).
  - To apply, write the behaviour wanted in each section of the target and choose tempo and mood to push it, then check in a playtest whether pace changes with the track.
- Lens 72, Indirect Control (p.324). Ideally what would I like players to do; can constraints, goals, the interface, visual design, characters, or music and sound get them to do it; is there another method that steers them toward it without impinging on their feeling of freedom?

### Collusion and the Pirates ride

- Pirates of the Caribbean: Battle for the Buccaneer Gold had to deliver a five-minute experience with an excellent curve (a family of four might pay $20) while feeling free (p.324). In early prototypes players fought ships in open ocean and lost interest after about two minutes twenty seconds (p.325). Islands with scenarios visible from a distance (pirates besieging a burning town, a mine on a volcano, a navy gold fort with fireball catapults) were added to draw players, but players ignored them because their goal was sinking pirate ships with bright white sails, and the volcano was barely visible and had nothing to do with that goal (p.325).
- The fix. Enemy ships stopped acting in their own interest: they attacked, then fled, and were timed to sink as they reached a randomly chosen island. Players chasing them looked up at a scenario, fought there, were attacked by new ships that fled to an unvisited island, and so on, giving battle, scenario, battle, scenario with a feeling of total freedom. Shortly after the fourth minute a fog rolled in and ghost pirates brought the finale to wherever the players were (p.326).
- Collusion is giving characters two simultaneous goals: their own in the world and the designer's aim of keeping the experience at its best. It combines goals, characters and visual design (p.326).
  - To apply, for each enemy or companion in the target write its in-world goal and the designer goal it can also serve (lead players to a place, raise or drop tension, bring the climax to the player), then change its behaviour so it does both.
- Facade (Stern and Mateas). Grace and Trip are AI characters driven by goals, behaviours and sensors (Figure 16.10), and a play-through hears about 10% of the recorded dialogue. They also pick actions that match an authored tension curve over time (Figure 16.11), so their behaviour stays in character while following an interest curve (p.327-328).
- Lens 73, Collusion (p.329). What do I want the player to experience; how can characters help deliver it without breaking their own goals in the world?
- The chapter closes on Lao Tzu: when the best leader's work is done, the people say they did it themselves (p.329).
