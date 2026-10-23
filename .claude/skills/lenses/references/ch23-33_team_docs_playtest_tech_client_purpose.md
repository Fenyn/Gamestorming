# Chapters 23 to 33: team, documents, playtesting, technology, client, pitch, profit, transformation, responsibility, purpose

Jesse Schell, The Art of Game Design, 1st edition (2008). Page numbers are PDF pages. Lenses 88 to 100 are listed at the end of each chapter section.

## Chapter 23. The designer usually works with a team (pp.403-411)

- Love of the game is the book's single secret of teamwork. It means everyone loving the game being made and the audience it is for, not liking each other. When that love is present, disagreements get set aside for the game (p.403).
  To apply: before a work session on a project, write one line on what the user and each agent role love about this game; if a line is blank, treat it as a project risk and report it.
- Love problem 1 is a member who cannot love any game. The book calls them dead weight that wastes time arguing, says managers and budget holders are the likeliest cases, and gives one cure, removal from the team (p.403).
  To apply: if a contributor (human or agent prompt) only optimises budget or schedule and never argues for the player, flag that its input should not settle design questions.
- Love problem 2 is a member who loves a different game, like an FPS level designer on an RPG. Work with them to find a part they can love or a new feature that takes the game somewhere new. In the Pirates example, animators who lost their characters fell for ship destruction effects (masts cracking, sails tearing) and quality rose (pp.403-404).
  To apply: when a cut removes someone's favourite element, propose the nearest element in the current design where the same craft can shine.
- Love problem 3, the most common, is a team in love with different visions of one game. Fix it by agreeing on the design early, hearing every view out, and stopping a meeting the moment someone does not buy in. No decision is final until the team agrees it is final (p.404).
  To apply: end each design decision record with "open objections"; a decision with an unresolved objection stays marked provisional.
- If the designer cannot love the game, the book gives three steps in order. First find one thing in it you love (a moment, a mechanic, an interface). Next treat it as a gift for the audience, as you would prepare a gift for someone you love, quoting the magician Thurston that you cannot fool the audience's heart. Last, pretend, by doing what someone who loved the game would do, until love starts to grow (pp.405-406).
  To apply: when deciding whether to shelve a project, check whether there is one element the user is proud of or a named audience they want to please; if neither exists, say so plainly in the recommendation.
- Including the team in design gives four gains. You get more ideas, you weed out flawed ones quickly, you see the game from many angles, and everyone feels they own the design (p.406).
- Shared understanding matters because hundreds of small decisions get made by programmers, artists and executives, not the designer. Avoid "over-fleshing" designs and leave uncertain detail open so the people closest to that part design it and feel ownership (p.407).
  To apply: in a design doc, mark which details are deliberately open and name who should settle them.
- The book gives a four-step design loop with a core design team. (1) Initial brainstorming with as much of the team as possible. (2) Independent design by core members. (3) Design discussion toward consensus. (4) Design presentation to the whole team for comment, which often starts the next brainstorm (p.407).
  To apply: run multi-agent design work in this order, with independent drafts before any shared discussion, then a presentation of the merged result back to the user.
- The nine keys to team communication come next (pp.407-408). Love is not one of the nine; it is the chapter's separate first secret.
- Objectivity comes first because it fails most often. Judge ideas by how well they solve the problem statement (Lens #12), name ideas by content ("the spaceship idea") not by owner, and phrase alternatives as questions ("What if we did B instead of A?") (p.408).
  To apply: in reviews, restate each proposal as the problem it solves and compare proposals against that problem, never by author.
- Clarity means checking that people understood, illustrating ideas, never pretending to understand, and making commitments concrete. "A 3-5 page description of the combat interface by Thursday 5 p.m." beats "I'll design combat by Thursday" (p.408).
  To apply: every deliverable an agent promises names its file, scope and size.
- Persistence means writing things down in every useful medium, keeping notes in every design meeting, and copying the whole team on design mail so no one is left out (p.409).
  To apply: record each decision and its reason in the project's design doc or memory file in the same session it is made.
- Comfort means a quiet, warm room with chairs and a big writing surface, and people who are not hungry, thirsty or overtired. Emotional comfort is the next key (p.409).
- Respect makes people speak freely. Treat others as you want to be treated, do not interrupt or roll your eyes, find something nice to say, repeat "What if I'm wrong?", and apologise rather than defend when you offend (p.409).
- Trust builds from the quantity of contact more than its quality, face to face. Who eats lunch together shows who trusts whom. Artists eating apart from programmers hints at pipeline problems, and one platform team eating apart from another hints at porting problems (pp.409-410).
- Honesty underpins trust. A reputation for dishonesty in any area makes others guarded (p.410).
- Privacy matters because people say painful truths one-on-one that they will not say in public. Private talks build trust, which builds more honesty (p.410).
- Unity is the final goal. Disagreement is healthy but the team must reach a decision all accept. Ask a stubborn member why the point matters, then ask "What would it take to bring you in?" Never ignore the holdout, since one unconvinced member works like a dead engine cylinder (pp.410-411).
  To apply: when the user rejects a proposal twice, ask what would make it acceptable instead of offering a third variant.
- People matter more than ideas. Ed Catmull is quoted saying a good group fixes a mediocre idea and a mediocre group ruins a good one (p.411).
- Lens #88, the Lens of Love. Do I love this project, and if not, how can I change that? Does everyone on the team love it, and if not, how can that change? (p.406)
- Lens #89, the Lens of the Team. Is this the right team for the project and why? Is it communicating objectively and clearly? Are members comfortable with each other? Is there trust and respect? Can the team unify around decisions? (p.411)

## Chapter 24. The team sometimes communicates through documents (pp.412-418)

- The idea of a perfect Game Design Document written alone and handed to a team is a myth. "The magic template does not exist." Documents matter but differ for every game and team (p.413).
  To apply: never start a doc set from a generic template; derive its sections from what this project must remember and communicate.
- Documents have two purposes only, memory and communication. Memory saves you from solving the same problem twice weeks later. Communication turns into dialogue, because once a decision is on paper someone finds a flaw or improvement (pp.413-414).
- Six groups (design, engineering, art, management, writing, players) each produce documents. Figure 24.2 maps the arrows between them (p.414).
  To apply: for a doc set, list for each document who writes it, who reads it and which of memory or communication it serves; cut any document with no reader.
- Game Design Overview is a few pages, written mainly for management to grasp what the game is and who it is for, and useful to the whole team for the big picture (p.414).
  To apply: keep a one-page overview at the top of each project's design doc, written for the user reading it cold.
- Detailed Design Document describes all mechanics and interfaces. It helps designers remember and tells engineers and artists what to build. It is usually messy, the thickest document, rarely kept current, and often abandoned halfway when the game itself holds the details (pp.414-415).
- Story Overview is a short note on settings, characters and events for writers, who are often contracted and far away. Their replies can change the whole design (p.415).
- Technical Design Document records how the engine, rendering and networking systems work, so newcomers to engineering can follow. It rarely stays current past halfway, but writing it gets the architecture going (p.415).
- Pipeline Overview is a short do-and-don't list from engineers to artists on getting art into the game. Simpler is better (p.415).
  To apply: for each art pipeline (Aseprite to Godot, Blender exports), keep the import rules in one short list the art agent reads first.
- System Limitations states limits not to cross, such as polygons on screen, network messages per second, or simultaneous explosions. Getting even rough limits in writing saves time and prompts creative workarounds (p.415).
- Art Bible holds guidelines for a consistent look, such as character sheets, environment samples, colour usage and interface examples (p.416).
- Concept Art Overview is concept images set in design context. They spread into the overview, detailed design and even technical documents (p.416).
- Game Budget is usually a spreadsheet listing all work with time estimates turned into money, built with every part of the team. It is often the first document, used to secure funding, and should evolve through the project (p.416).
- Project Schedule is the most often updated document on a well-run project. It lists tasks, durations, deadlines and owners, respects a 40-hour week and task dependencies, and can be a full-time job to maintain (p.416).
- Story Bible sets what is and is not possible in the story world, so engineers, artists and designers can propose story changes that fit (p.417).
  To apply: keep one lore record per project (as Zenith does with cast.md) and check new story proposals against it.
- Script holds NPC dialogue, separate from or appended to the detailed design. Designers must review all of it, since a line can contradict a game rule (p.417).
- Game Tutorial and Manual covers in-game tutorials, web pages and printed manuals. Someone must keep checking the text against the build until the last minute (p.417).
  To apply: after any rule change, search tutorial and hover text for the old rule in the same pass.
- Game Walkthrough is written by players. Reading what players write shows what they like, dislike, and find too hard or too easy, though usually too late to change this game (p.417).
  To apply: for a released build, collect player write-ups and feedback reports and sort them into likes, dislikes, too hard and too easy.
- To start, begin with a rough bullet list of ideas. Write down the questions that arise, since design work is mostly answering them. Record each answer and why you chose it, and let sections form on their own (p.418).
  To apply: keep an "open questions" list in each design doc and move each question to "decided" with its reason when answered.
- Lens #90, the Lens of Documentation. What do we need to remember while making this game? What needs to be communicated while making it? (p.418)

## Chapter 25. Good games are created through playtesting (pp.420-432)

- Four kinds of testing are kept apart (p.421). Focus groups interview potential players about likes; they help rank well-defined features but are often run to kill ideas management fears. QA testing hunts bugs and says nothing about enjoyment. Usability testing checks that interfaces are intuitive, which is necessary but not enough for fun. Playtesting checks whether the game produces the experience it was designed for (pp.421-422).
  To apply: label every test plan with which of the four it is, and do not answer an experience question with a QA or usability test.
- The designer's fear of playtesting is fear that people will dislike the game. It leads to delaying tests, skipping them and not watching. The only remedy is to get over it, because the point of a test is to show which comfortable decisions are wrong while there is time to fix them (pp.422-423).
- Every playtest is defined by five questions, why, who, where, what and how (p.423).
- Why comes first. A playtest is a prototype of the experience and must answer specific questions; "Is it fun?" is not enough. The book's examples include whether players understand how to play, want to play again, feel it is fair, are ever bored, confused or frustrated, find dominant strategies, which parts are most and least fun, which button should jump, whether level three is too long and whether a given puzzle is too hard. The lenses are a good source of questions (pp.423-424).
  To apply: open every playtest plan with a numbered list of specific questions, each tied to a screen, level or rule.
- Who depends on the questions. Developers are available and give long, informed feedback with no NDA, but they are too close, so take their views with salt. Friends and family are easy to reach but bend the truth and want to like it. Expert gamers compare precisely with similar games but are jaded, and overtuning for them spoils games for the broad audience. Tissue testers have never seen the game and catch usability and first-appeal problems, but testing only with them yields strong first sessions that bore on replay (pp.424-425).
  To apply: for each question, name the tester type that can answer it, and include repeat players for any replay or balance question.
- Where has trade-offs (pp.425-427). In your studio is convenient and lets the team watch, but testers feel uneasy, so give them comfort and let them bring friends. A playtesting lab has one-way mirrors, cameras and experts but is expensive. A public venue is cheap with many testers but they may be off-target and distracted. The tester's home shows the game in its natural setting with real social play, but few observers and few testers fit. The Internet gives volume, many machine configurations and load testing, but low insight per tester and poor secrecy. Choose by the why questions (p.427).
  To apply: pick remote builds for load, hardware and online questions, and in-person or screen-share sessions for feel and comprehension questions.
- What has two parts. The first is things you know you are looking for, from the why list. Make sure every question has a way to be answered, cut irrelevant parts with a special build, and split into mini-tests if needed. The second is things you don't know you are looking for. Hold expectations so that surprises stand out, then chase every surprise (a villain who gets laughs, an ignored feature that intrigues) and find out why (pp.427-428).
  To apply: before a test, write predictions next to each question; afterwards, list every place play differed from a prediction as a finding.
- On whether the designer should be there, some say developers infect testers with insider views. The book says be present if you can police yourself, because you learn far more in person than from surveys or video (p.428).
- On what to tell testers up front, often nothing. Any setup words can skew play; telling them to defeat a named villain makes them hunt for him and miss other things. Script the speech, give it identically, refine it across sessions, and use the polished speech as the basis of the in-game tutorial (p.428).
  To apply: write the tester briefing as fixed text in the plan, log every change to it, and feed the final version into the tutorial script.
- On where to look, watch players' faces more than the screen, since expressions show feeling that interviews miss. The author learned this as a street performer passing the hat. A split-screen recording of game, face and hands lets you compare all three later (pp.428-429).
- Collect other data by logging important events, automatically in digital games or by hand otherwise. Examples are time in the character creator, hits to beat the villain, average score and most-used weapons. MMO designers data-mine logs, a kind of "digital listening" (p.429).
  To apply: for each why question that can be counted, name the event to log and add the logging before the test.
- Disturbing players mid-game risks changing their play, while waiting loses their state of mind. Most designers interrupt only for truly surprising behaviour. The think-aloud protocol helps some players but makes others careful or silent under stress, and constant prompting can ruin a test. Use it only with players for whom it comes naturally (p.430).
- Surveys suit simple quantifiable questions (pp.430-431). Use pictures of the elements asked about. Online surveys save time. Use a labelled five-point scale (terrible, pretty bad, so-so, good, excellent) instead of 1 to 10. Keep it short. Give it right after play. Have someone available to clarify. Record age and gender. Do not treat the results as gospel, since testers make things up when unsure.
  To apply: draft post-test surveys with at most a handful of five-point labelled questions, each with an image of the thing rated.
- Interviews suit complex questions and show emotion (pp.431-432). Keep a script with space for answers and surprises. Interview privately first, then optionally in groups of friends. Give explicit permission to criticise ("This game has some real problems... please tell me"). Avoid memory tests, and ask about specific moments during play instead. Don't expect testers to be designers; ask "were any parts of level three boring?" not "should it be harder?", since players always say easier. Ask for more than you need ("your three least favourite parts") to get ranked data. Set your ego aside and answer criticism only with "Can you tell me more about that?"
  To apply: write interview questions as experience questions (boring, confusing, surprising parts), never as design proposals, and ask for the top three of each.
- Lens #91, the Lens of Playtesting. Why are we doing this playtest? Who should be there? Where should we hold it? What will we look for? How will we get the information we need? (p.432)

## Chapter 26. The team builds a game with technology (pp.434-444)

- The East of Eden epigraph has Tom design a spring-loaded gate opener that would cost more upkeep than twenty years of climbing down, and his father notes he does it because it is fun (p.435).
- Technology means the physical medium of the game, such as Monopoly's board and dice, hopscotch's chalk and pavement, or Tetris's computer and controller. It is the most volatile element of the tetrad, compared to a drunken billionaire at a party. Novelty pressure makes it easy to forget the goal is a great game. Walt Disney distrusted engineers who designed for themselves (pp.435-436).
- Foundational technology makes a new kind of experience possible, and decorational technology makes an existing one nicer. The cupcake is the image, with cake foundational and icing and cherry decorational (p.436).
  To apply: for each tech or tool choice in a design, write which experience it makes possible; if the answer is "it looks/sounds better", label it decorational and rank it below foundational work.
- Steamboat Willie is remembered as Mickey's first cartoon although Plane Crazy came earlier, because synchronised sound was foundational to it (animals played as instruments). Sound added later to Plane Crazy was decorational (p.437).
- Abalone used grooves that let one marble push a row, which made possible capture by shoving pieces off the board (pp.437-438).
- Sonic the Hedgehog was built around the Genesis's fast scrolling (p.438).
- Myst mixed decorational 3D art with foundational CD-ROM capacity. Cyan spent time making it run on every CD-ROM/PC combination rather than on a bigger ending, and it became the disc everyone bought (p.438).
- Journey (the arcade game) began as a camera for high-score photos. After players abused it the tech was kept as decoration (photo heads on cartoon bodies), and it could not save a dull game (p.439).
- Ragdoll physics is decorational in shooters (flopping bodies). Ico used the same algorithms foundationally, with the princess led by the hand responding to every tug, which made most puzzles possible (p.439).
- With any new technology, ask how you can make it foundational to your game (p.440).
- The Gartner Hype Cycle plots how much a technology is talked about over time in five phases. (1) The technology trigger. (2) The peak of inflated expectations, when more people talk about it than have used it. (3) The trough of disillusionment. (4) The slope of enlightenment, when real uses are found. (5) The plateau of productivity, whose height depends on how broadly useful it is (pp.440-441).
- Designers need the Hype Cycle for three reasons. Immunity means not risking your career on unseen tech. Inoculation means steering a hyped team away from a bad bet. Fundraising means funders at the peak may pay for the bandwagon, so get the money before the trough and make something great despite the tech (p.441).
  To apply: when a design leans on a new tool, engine feature or platform, state which phase it is in and what has been seen working first-hand.
- The innovator's dilemma (Christensen) says firms fail by listening to customers who call a new technology "not good enough" while it improves, until it crosses the line and customers jump. Examples are consoles overtaking retail PC games and the Wiimote making motion control good enough. Designing for foundational tech about to break through can catch a wave others miss (pp.441-442).
- The singularity is the idea that accelerating technology will make prediction impossible. Fast change is good news for designers, and virtual-world craft may become central to human experience (pp.442-443).
- Lens #92, the Lens of Technology. What technologies help deliver the intended experience? Are they used foundationally or decoratively? If not foundational, should they be used at all? Is the technology as cool as I think? Is there a disruptive technology to consider instead? (p.443)
- The crystal ball asks you to predict technology on purpose, because most people give up. The book's sample questions cover next console generations, download versus disc share, mobile phones as handhelds, MMO trends, what small and large studios and genres will look like in four years, and new genres. Discuss with others. The value lies in the scaffold of near-certain trends and history you build, not in the predictions themselves (pp.443-444).
  To apply: for a project expected to ship in a year or more, write two-, four- and ten-year guesses for its platform and genre, each with a reason, and note which design choices depend on them.
- Lens #93, the Lens of the Crystal Ball. What will this technology be like in two years, in four, in ten, and why, as concretely as possible? (p.444)

## Chapter 27. Your game will probably have a client (pp.446-452)

- The epigraphs read "form follows function" (Sullivan), "form follows fun" (Rosenthal) and "form follows funding" (Ferren) (p.447).
- A client may be a publisher, a franchise holder or a non-entertainment party, and usually pays. Clients hold strong opinions, sometimes wise and sometimes absurd. Happy designers are either rich or good at building compromises that please both sides; this skill predicts long-term happiness (pp.447-448).
- Facing a bad suggestion, a designer can respond three ways. (1) Agree out of fear, which harms client and game. (2) Explain at once why it is bad, which backfires. (3) Seek why they suggested it, the right answer. Bad suggestions are usually solutions to an unstated problem, so apply Lens #12, the Problem Statement (p.448).
- In the racing game example, the client said the cars needed more chrome. Asked why, he said the cars felt slow and chrome might make them look faster. The team raised car speed and lowered the camera on the spot. The magic words are "What problem are you trying to solve?" (pp.448-449)
  To apply: when the user asks for a specific surface change that looks wrong for the design, ask or infer the problem behind it and offer a fix for that problem alongside the literal change.
- "Bring me a rock" is the client who does not know what they want and rejects every offer. Ask what kind and what it is for (a house number by the driveway), then bring a few to choose from. Helping the client find what they want is design work and educates them (p.449).
  To apply: when a request is vague, ask what the result will be used for, then present two or three options as images or short descriptions.
- Do homework on the client personally and professionally. Find out whether they want quick money or slow reputation, a new market or an existing one, and what they think makes a good game (p.450).
- The three layers of desire are words, mind and heart. In the Rittenhouse example, her words ask for an algebra game for eighth graders, her mind wants a space geometry game she has planned, and her heart wants to be seen as creative rather than "the financial person." Taking only the words leads to strange resistance. Meeting all three can make a friend for life (p.450).
  To apply: for any brief (from the user or for a store page audience), write three lines for what they said, what they think they want, and what they want underneath, then check the plan serves all three.
- In Firenza, 1498, Michelangelo won the damaged marble with a wax prototype. When Mayor Soderini, standing too close, said David's nose was too big, Michelangelo had him climb up, faked chiselling with dropped marble dust, and Soderini declared it alive. The lesson is to let clients feel like creative partners without giving up the vision, since clients also bring connections, business knowledge and audience insight (pp.450-451).
- Lens #94, the Lens of the Client. What does the client say they want? What do they think they want? What do they want deep in their heart? (pp.451-452)

Note: no Starship Troopers example appears anywhere in the book text (a search found no hits). The chapter's client examples are the chrome cars, the rock, Rittenhouse and Michelangelo.

## Chapter 28. The designer gives the client a pitch (pp.454-463)

- The designer pitches because they know the game best. Pitches happen at every stage, from rough ideas to the team, concept to management for a prototype, prototype to publishers, mid-project changes to everyone, and the finished game to the press. Funding pitches carry the most pressure (p.455).
- Power is the ability to get what you want, and it has two parts. Knowing what you want matters as much as being able to get it. A pitch is a negotiation of power in which you get what you want by showing how the game gets them what they want, with three layers of desire on each side (p.455).
- The hierarchy of ideas runs from a plain idea ($0.083, a dime a dozen) through a cool idea ($5), a really cool idea, which is a cool idea shouted ($5), and a good idea someone can use ($100), up to a good idea at the right place and time sold convincingly ($1,000,000). Ideas are judged by usefulness to the listener now. Take a rejected good idea elsewhere or hold it for later (p.456).
  To apply: for a store page or pitch, state in one line why this game is useful to this audience or platform now, in addition to why it is cool.
- Tip 1 is to get in the door. Publishers ignore cold contact, and most deals come through a mutual contact (the back door), so build networks at GDC and IGDA meetings (pp.456-457).
- Tip 2 is to show you are serious. At Disney's Open Forum the author pitched two untested ideas and was asked why the panel should care if he hadn't tried them. Bring a working prototype plus evidence of thought on the game, its market and why it will sell. A design document gets weighed, not read (p.457).
- Tip 3 is to be organized. Have enough handouts, test projector, computer and network early, and confirm the meeting time. An organized designer looks lower-risk (pp.457-458).
- Tip 4 is to be passionate. Genuine excitement is infectious and signals commitment, and faked excitement shows (p.458).
- Tip 5 is to assume their point of view. Pitching means listening and solving their problem. Research them, drop pitches that don't fit, avoid jargon, test the pitch on outsiders, get to the point, and skip what bores them. Plan for the best case, where your fan must re-pitch internally. Give the idea short "handles" ("It's a bowling RPG!"), a professional report on the idea and your company (IGDA Game Submission Guide), copies of slides and docs, and short gameplay videos rather than a buggy build (pp.458-459).
  To apply: every store page and pitch gets a one-line handle, a short gameplay video or GIF plan, and wording tested on someone who has not seen the game.
- Tip 6 is to design the pitch. It is an experience, so give it accessibility, surprises and an interest curve (hook, build, tension and release, climax). Favour images over words, focus on what is unique, why it beats competitors and why it fits this listener, and plan every moment, including when to introduce teammates and show the prototype (p.459).
- Tip 7 is to know all the details (pp.459-460). Design details cover hours of play, level length and multiplayer. Schedule details cover milestones (design doc, first playable, alphas, beta, gold) and the fastest possible date, to which you will be held. Financial details cover cost, headcount, and a sales range from comparable titles whose minimum is still profitable. Risks cover technical, gameplay, aesthetic, marketing, financial and legal ones, each with a plan. Anticipate the questions. Joe Rohde answered "what is exciting about live animals?" by leading in a Bengal tiger.
  To apply: before any pitch or funding page, prepare a sheet of design, schedule, money and risk answers, with a plan next to each risk.
- Tip 8 is to exude confidence, which differs from passion. You sell yourself as well as the idea. Act as if impressive things were easy, answer as a team, say "Absolutely" to tough capability questions and then back it up, practise a firm handshake, and recall a past confident moment if nervous (pp.460-461).
- Tip 9 is to be flexible. Expect curveballs like a hated concept or a meeting cut to twenty minutes. When RoboRally was rejected as too big, Richard Garfield offered a small card game idea instead, which became Magic: The Gathering (p.461).
- Tip 10 is to rehearse. Give the pitch to anyone (your mother, coworkers, your dog) until the chain of ideas flows. Rehearse demos too, never pitch while playing yourself, have a colleague play, and don't make executives play (pp.461-462).
- Tip 11 is to get them to own it. Have an inside advocate, and work the client's earlier wishes (helicopters, giant rats) into the pitch, even on the fly (p.462).
- Tip 12 is to follow up. Silence often means busy, not no. Within days, follow up with a pretext such as an answer to a question they asked. Never nag for an answer, which invites a quick no. Keep pinging patiently, since a deal can surface six months later (pp.462-463).
- Lens #95, the Lens of the Pitch. Why pitch this game to this client? What counts as a successful pitch? What's in it for them? What do they need to know about the game? (p.463)

## Chapter 29. The designer and client want the game to make a profit (pp.464-470)

- Money fuels the industry, and "form follows funding." Business decisions such as a smaller budget, microtransactions instead of subscription, or in-game ads shape the design, and design shapes profit. The golden rule is that whoever has the gold makes the rules. Knowing enough business to argue that a feature earns money buys creative control (p.465).
- Know your business model by following the money (p.466). Of a $50 retail game, the retailer keeps $16, including a $3 markdown reserve, and buys the game for $37. From that $37 the platform holder takes $7, advertising $6, disc and box $3 and the developer $8, leaving the publisher $10.
- The book explains each share (pp.466-467). Platform holders sell consoles at a loss and tax each title. Retail is low-margin. Publishers carry the risk, buy back unsold stock and pay for flops. The markdown reserve covers later price cuts.
- Other models listed are Internet downloads, console downloads, mobile, board and card games, advergames, subscription MMOs and microtransaction MMOs. Each model's quirks shape the games sold through it. If confused, ask a money person to "show me where the money goes" (p.467).
  To apply: for each project, draw the money path for its sales channel (for example itch.io or Steam cut, price, refunds, payment fees) and note which design choices it rewards.
- Units sold is the measure of success and the basis for publisher forecasts. Find comparable titles' numbers (web, press, NPD) so you are not caught saying "a lot" (p.467).
- Breakeven is the number of units needed before the publisher recovers its outlay. A forecast of 200,000 against a 400,000 breakeven is trouble. Ask how the publisher calculates it (pp.467-468).
  To apply: before deciding to keep or shelve a commercial project, write price, net per unit, total cost, breakeven units and a comparable-title sales range, and say whether the low end clears breakeven.
- Know the top sellers. List last year's top ten from memory, check it, and study why you were wrong. Publishers study hits closely, and EEDAR analysed features against sales (p.468).
  To apply: list the top sellers in the project's genre and storefront and note what they share before positioning the game.
- Learn the language (pp.468-469). A SKU is one inventory item per platform and language. COGS is the cost per unit made. Burn rate is the monthly cost to keep a studio open. Sold in means sold to the store, sold through means sold to customers, and only sold through counts. NPV is net present value, where future money is worth less; the discount rate is typically 4 to 10%, and you can ask "at what discount rate?" Christmas is when 75% of US games sell.
- Lens #96, the Lens of Profit. Where does the money go in my business model, and why? What will it cost to produce, market and distribute, and why? How many units will it sell, and why do I think so? How many must sell to break even? (p.470)

## Chapter 30. Games transform their players (pp.472-483)

- Views on games range from harmless distraction, through dangerous (violence, addiction), to the cornerstone of education. The answer is changing society either way (p.473).
- Games help with emotional maintenance (p.473). Players use them to vent anger, cheer up, gain perspective, build confidence through mastery and relax, though this can backfire if the game frustrates.
- Games help people connect by acting as a social bridge. They give reasons to interact, show how others react, supply topics and common ground, and create shared memories (p.474).
- Games give reason for physical exercise, and their problem-solving offers mental exercise, which helps the elderly (p.474).
- School is itself a game, with assignments as goals, due dates as time limits, grades as score, the final as boss and the honour roll as leader board. It feels unlike one because it lacks surprise, projection, pleasure, community and a good interest curve. McLuhan is quoted that those who think education and entertainment differ know little of either (p.474).
- Educational games struggle in classrooms for four reasons. Play time is long and variable, games allow variable pacing while classes keep one pace, the educators in charge were born before 1965, and good educational games are hard to make across dozens of lessons. Games work best as tools, not whole systems (p.475).
- Games drill facts, a minor improvement over rote methods (p.475).
- Games suit problem solving, by the book's definition of a game. Simulations may become final exams for integrated skills such as rescue work, geology and architecture (pp.475-476).
- Games are best at teaching systems of relationships. In the Zen koan, the cook tips over the water vase to show it rather than describe it. Miller's pyramid runs knows, knows how, shows, does, and game learning sits at "does." Linear media struggle to convey systems such as circulation, city traffic, reactors, cells, ecologies and climate. Players learn by pushing simulations until they break, which gives permission to fail and shows why failures happen (pp.476-477).
- In Peacemaker, Israeli and Palestinian testers who played the other side found the conflict harder than they believed, first tried to provoke war and then tried for peace. Flawed simulations work best with an instructor, and their loopholes can teach by prompting "why doesn't this happen in reality?" (pp.477-478)
- Games create new insights, like the Groundhog Day loop, because they let you be someone else under new rules. The book suggests uses such as raising career aspirations or helping people leave abusive relationships or break addictions (p.478).
- On curiosity, the Internet widens a "curiosity gap" between curious and incurious learners. Play is "manipulation that indulges curiosity," so play-based education may build curiosity (pp.478-479).
  To apply: when a design claims to teach (Kotodama kanji drills, tutorials), state whether it teaches facts, problem solving or a system of relationships, and for systems let the player push the model until it breaks.
- On harms, traditional dangers such as injury, gambling ruin and obsession are known and handled. New game types worry parents who did not grow up with them. The two main fears are violence and addiction (p.479).
- On violence, moms in a focus group accepted Virtua Fighter but not Mortal Kombat because of blood. Death Race's "goblins" fooled no one because reckless driving is real. The Pirates cannon game, tested days after Columbine, raised no concern because it was far from reality (pp.479-480).
- The fear is desensitisation that makes real violence seem fun. Players see through aesthetics to mechanics and think about skills and goals, not murder, and most people compartmentalise fantasy and reality. Children are the open question. Gerard Jones (Killing Monsters) argues some violent play is healthy, but limits exist, so ratings are necessary. Designers must stay on guard, since tech may make more extreme play possible (pp.480-481).
  To apply: for violent content, note how close it sits to real-world harm (realistic gore, real targets) and confirm the age rating fits.
- Addiction means compulsive play that harms school, work, health or relationships, as opposed to the casual praise "so addictive." MMOs with social obligations and multi-year goals draw some into self-destructive play. Gambling is a special case of exogenous rewards. Earlier cases include college bridge players, the Hearts players in Stephen King's Hearts in Atlantis, D&D in the 1970s and World of Warcraft (p.481).
- Nicholas Yee finds that "problematic usage" has many causes, with the game pulling the player in, a real-life problem pushing them in, or both. Blaming designers for engaging games is like blaming bakers for tasty cake, yet designers must fit game structures into a balanced life. Miyamoto signs autographs with "On a sunny day, play outside." (pp.481-482)
  To apply: for any retention mechanic (daily rewards, streaks, social obligations, timers), write what it costs a player who wants to stop, and prefer structures with natural stopping points.
- Experiences are the only things that change people. Toontown's menu chat of polite phrases changed a Dark Age of Camelot player's habit of trash talk. Real violence is a desperate form of communication, so changing how people communicate matters (pp.482-483).
- Lens #97, the Lens of Transformation. How can my game change players for the better? How can it change them for the worse? (p.483)

## Chapter 31. Designers have certain responsibilities (pp.484-488)

- The chapter opens with Vasco Popa's "The Small Box" and Mister Rogers on using TV to nurture (p.485).
- The danger of obscurity is that designers get little respect or fame ("like that Grand Theft Auto?"), so no one asks them to answer for their work. Corporations have legal duty but no souls and so no ethical duty, and only individuals can take ethical responsibility (pp.485-486).
- On accountability, the most undeniable online danger is meeting dangerous strangers, not foul language. Anonymity can shelter predators. One-in-a-million odds across five million players means five incidents. Do not leave ethics to corporate lawyers, and if you won't take personal responsibility, don't make games. One team imagined the Time magazine cover for a child abducted through their game to keep the risk in mind (pp.486-487).
  To apply: for any online feature where strangers talk or trade, list how it could be misused against children and what safeguard covers each case before the feature ships.
- Your hidden agenda is that failing to do good when you could is close to doing harm. Companies only care about profit, so building good into games may have to be done quietly. A game good for people that no one plays (a broccoli smoothie) helps no one, so put the good into best-sellers. People love being cared for (p.487).
- The secret in plain sight is that games create experiences, and life is made of experiences. Childhood fantasy worlds become modern mythology and utopias. The medium people grow up in shapes how they think, so designers shape the next generation's thinking (pp.487-488).
- The Ring refers to Kipling's 1922 ritual that gives engineers an iron ring on the pinky, which guides the hand. The book offers an invisible ring of responsibility that does not come off (p.488).
- Lens #98, the Lens of Responsibility. Does my game help people, and how? (p.488)
  To apply: in a shelve-or-keep review, answer this lens and the two Lens #97 questions in writing for the project.

## Chapter 32. Each designer has a motivation (pp.490-492)

- The deepest theming is listening to yourself, the last kind of listening after audience, game, team and client. Time destroys everything and mocks like Poe's raven, so do the important work now (p.491).
- Lens #99, the Lens of the Raven. Is making this game worth my time? (p.491)
  To apply: when the user asks whether to keep, pause or shelve a project, put this question to them directly along with the profit, love and responsibility answers.
- Find your hidden purpose, which might be changing someone's life, sharing a wonderful experience, or preventing a harm you saw. Only you need to know it. Knowing it unites conscious and subconscious motives and gives the work focus and intensity (p.491).
- Lens #100, the Lens of Your Secret Purpose. Why am I doing this? (p.492)

## Chapter 33. Goodbye, endnotes, bibliography, index (pp.494-520)

- The goodbye asks the reader to keep the map, the ring and the lenses and to use them (p.495).
- The endnotes add a few points. The five-point survey scale is called a Likert scale (p.505). The $50 split comes from Kathy Schoback in Introduction to Game Development (p.505). "Problematic usage" is preferred over "addiction" because addiction has a medical definition (p.506). Yee's study is "Ariadne: Understanding MMORPG Addiction" (p.506). Some educators accept "engaging simulations" where they reject "entertaining games" (p.506).
- The bibliography (pp.508-510) and index (pp.512-520) hold no methods.
