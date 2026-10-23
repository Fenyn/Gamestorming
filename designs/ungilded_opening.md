# Ungilded opening (Prologue) - port reference

Source: Unity project `F:\UnityNVME\Projects\P2eCombatSim\Tactics` (game "Ungilded", Cursehound Games) and the script PDF `F:\UnityNVME\Art\_P2eGame\Draft 3 Ungilded Tutorial Script.pdf` ("Ungilded Opening Draft 3").

Where the Unity data and the PDF disagree, this document records the Unity version as the build and lists the PDF version next to it. Scenes 8 to 10 exist only in the PDF.

Paths below are relative to `Assets/` in the Unity project unless they start with a drive letter.

---

## 1. Overview

### Premise

The Kingdom of Aurenthal lost its king, Lanric, 150 years ago. The Guilds and the High Nobility now run a walled Capital, and the poor live in the lower wards. Two 17-year-old boys go into the Capital's sewers looking for a "chamber" described in the Player's father's writings. They carry a pair of spectacles stolen from the Guild masters. They fight rats, find a dead "truth-seeker" with a journal and a dagger forged by the Player's father, kill a mutated rat boss in front of a carved sigil, and (PDF only) use the spectacles to open a hidden portal that leads to the Meadows of Aveline outside the Capital.

### Characters

| Name in data | Role | Class | Notes |
|---|---|---|---|
| The Player | Main character | Fighter (longsword, scale mail, steel shield) | Confident, curious. Son of a smith. Speaker name "The Player". |
| The Friend | Party member | Alchemist (dagger, leather armor, Acid Flasks) | Cautious, witty. Swears by Aveline. Speaker name "The Friend". |
| Mysterious Glowing Woman | NPC, PDF scene 10 only | n/a | White hair, white dress, green amulet. Knows the Player's father. |

The PDF calls the Player "The MC" and the Friend "Current Party Member". Both are referred to as boys.

### Sequence (as built in Unity)

1. Narrative intro (narration over black).
2. Scene 1, sewer banter (over black).
3. Fade in to the combat map. Scene 2, rat lead-in (over the map).
4. Encounter 1, "The 3-Action System".
5. Fade to black. Scene 3a, post-Encounter 1 dialogue (over black). Scene reload.
6. Fade in. Scene 3b, "rats appear" lead-in with the spectacles (over the map).
7. Encounter 2, "Recall Knowledge".
8. Fade to black. Scene 4, the dead truth-seeker (over black). Scene reload.
9. Scene 5, flanking banter (over black), then fade in.
10. Encounter 3, "Fight Together".
11. Fade to black. Scene 6, the journal and the dagger (over black). Scene reload.
12. Scene 7, boss chamber (over black), then fade in.
13. Encounter 4, "The Capstone". Mid-fight lines at boss HP thresholds.
14. Victory lines and one closing narration line. The Unity build stops here.
15. Scenes 8 to 10 (script only, not built in Unity): carcass, map, Examine the sigil with the spectacles, portal, Meadows of Aveline, the glowing woman, the shambling creature cliffhanger.

The PDF continues past scene 10 (Scene 12 with Encounter 5 at night in the Meadows, Scenes 13 to 16 in a court, a tavern and a holding cell). There is no Scene 11 heading in the PDF. Those scenes are outside this document.

### Where the Unity build and the PDF differ

| Beat | PDF | Unity build |
|---|---|---|
| Narrative intro | 5 long paragraphs | Shortened to 5 lines. Trade routes, the High Nobility and the "price of defying the noble heel" paragraphs are cut. |
| Encounter 1 map | About 6x6, flat, no cover | Procedural Sewer biome map, hazards cleared in a strip around the fight |
| Encounter 1 Friend line | "You've struck it deep. Finish it!" after the first hit | Not present |
| Encounter 1 Reaction | Three popups (rat flees, what a Reaction is, Reactive Strike), then prompt | One combined popup before the rat moves |
| Encounter 2 Recall Knowledge | Round 1 RK reveals Name; Round 2 RK reveals AC | One RK in round 1. The popup claims Name and AC. No second RK. |
| Treat Wounds after Encounter 2 | Friend uses Treat Wounds (Medicine), scripted Success | Not built. The script restores party HP to full. The scene reload rebuilds the party at full HP anyway. |
| Encounter 3 | 10x10, two pillars, five rats, Acid Flask, Critical Miss, Vicious Bite bleed, recovery check, three rounds | Procedural map, three rats, no bomb, no Critical Miss, no bleed, two rounds |
| Index/Glossary journal beat (Scene 6) | Player is prompted to open the Index/Glossary to read the journal entries | Not built. Entries are shown as narration lines. |
| Journal entry 1 | Ends "...present this to the High Council. It is secured with me at the tavern." | The last sentence is cut |
| Encounter 4 map | About 12x12, two pillars, 3-tile sludge band of difficult terrain | Procedural Sewer biome map. The script clears difficult terrain in a box around the party. |
| Encounter 4 Acid Flasks | Two fresh flasks | 3 uses per encounter |
| Encounter 4 25% trigger | When the last Dire Sewer Rat falls or the Tyrant reaches 25%, whichever is first | Only the Tyrant HP check |
| Encounter 4 fail state | Party wipe reloads the encounter and shows a post-mortem popup | Not built |
| Victory line | "Aveline protects us." | "Aveline protect us." |
| Closing line | none | Narration: "The chamber lies open. What waits beyond, no map can show." |
| Scenes 8 to 10 | Written | Not built |

---

## 2. Dialogue

### Conventions

- Dialogue data: `ScriptableObjects/Tutorial/Dialogue/*.asset` (`PF2e.Data.DialogueSequence`). Each line has `Speaker`, `Text`, `Portrait` (a sprite), `Emotion`.
- Emotion enum (`Scripts/PF2e/Data/DialogueSequence.cs`): `0 Neutral, 1 Angry, 2 Tired, 3 Amused, 4 Sad`.
- `DialogueBoxUI` (`Scripts/GameFlow/OutpostUI/DialogueBoxUI.cs`) does not read `Emotion`. The portrait shown is the `Portrait` sprite on the line. The emotion value and the sprite name often disagree (for example Emotion 3 Amused with `FriendAngry`). Both are listed so the port can choose.
- Narration lines have an empty speaker and no portrait. The dialogue box hides the name plate and the portrait panel for them. Most narration text is wrapped in `<i>` in the asset.
- `//` below marks a paragraph break (`\n\n` in the asset).
- Format: `Speaker [Emotion, portrait sprite]: text`. Narration is written `*Narration:* text`.

### Narrative intro (`Tutorial_NarrativeIntro`, over black)

All five lines are narration with no `<i>` tag.

1. *Narration:* The Kingdom of Aurenthal is spoken of, in legend, as the glory of its age. // Its sprawling empire stood as a fortress unbreachable, held fast by the iron hand and golden heart of the Great King Lanric.
2. *Narration:* Yet, a century and a half has passed since that light was extinguished. // With the sudden and unexplained disappearance of King Lanric, the sun did set upon Aurenthal, leaving a hollow throne and a kingdom in disarray.
3. *Narration:* The Guilds, once the engine of progress, grew bloated and corrupt. // The Capital was shuttered behind iron and its gates opened only to those bearing the mark of privilege, while the masses were cast into the squalor of the lower wards.
4. *Narration:* What was once a prospering realm stands now a gilded cage, its bars forged of greed and its floors slick with the rot of its own shame. // And yet... hope is a persistent weed.
5. *Narration:* In the lightless depths of the Capital's sewers, two young explorers shall soon stumble upon a secret that will stir the embers of their dying kingdom and alter the tapestry of fate forever.

PDF full text of the intro, for reference (paragraphs cut from Unity are 1, 3 and 4 in part):

> The Kingdom of Aurenthal is spoken of, in legend, as the glory of its age. Its sprawling empire stood as a fortress unbreachable, held fast by the iron hand and golden heart of the Great King Lanric. Under his sovereignty, the trade routes ran thick with prosperity, the Guilds flourished in the light of peace, and whence the king rode forth, his people would line the streets for naught more than a fleeting glimpse of the crown.
>
> Yet, a century and a half has passed since that light was extinguished. With the sudden and unexplained disappearance of King Lanric, the sun did set upon Aurenthal, leaving a hollow throne and a kingdom in disarray.
>
> The ruin was swift, and the rot deep. The trade routes, once teeming with life, withered to dust. The Guilds, once the engine of progress, grew bloated and corrupt, casting long shadows that eclipsed the very sun. The absence of a rightful heir created a vacuum of power, and the High Nobility were quick to sharpen their talons, decreeing laws fashioned only to their own favor.
>
> The once expansive economy devolved into a hierarchy of wealth, with the high nobility controlling almost every penny that was left in the capital as well any political power that could be conjured up. The Capital was shuttered behind iron and its gates opened only to those bearing the mark of privilege, while the masses were cast into the squalor of the lower wards.
>
> What was once a prospering realm stands now a gilded cage, its bars forged of greed and its floors slick with the rot of its own shame. The price of defying the noble heel is death, and yet, hope is a persistent weed. In the lightless depths of the Capital's sewers, two young explorers shall soon stumble upon a secret that will stir the embers of their dying kingdom and alter the tapestry of fate forever.

### Scene 1: Sewer banter (`Tutorial_Scene1_SewerBanter`, over black)

PDF heading: SCENE 1: INT. CAPITAL SEWERS - DAY.

1. *Narration:* Two boys pause to catch their breath in the dripping dark. Behind them, the echoes of pursuit have faded. Ahead, the passage stretches into shadow.
2. The Friend [3 Amused, FriendAngry]: Truly? Again? Must every one of your "grand designs" find its end in a sewer?
3. The Player [3 Amused, PlayerSmile]: Peace, friend. A little damp never soured a man's spirit. Besides, I'd thought you would find the stench of trouble quite a comfort by now.
4. The Friend [2 Tired, FriendNervous]: These passages are foreign to me. We have never ventured so deep.
5. *Narration:* The Player unfurls a map, its edges worn and stained.
6. The Player [0 Neutral, PlayerConcerned]: Nor had he, and it seems our ink grows timid. The cartography ends here.
7. The Friend [2 Tired, FriendNervous]: If your father catches wind of this, he'll have our hides for leather.
8. The Player [0 Neutral, PlayerConcerned]: The old man is too busy trying to turn rusted horseshoes to coin. He is sure to have no idea until twilight. We'll have found this "chamber" by then. That aside, do you still hold fast our prize?
9. The Friend [1 Angry, FriendAngry]: Aye, I have it secure. But why risk our heads for two circles of glass and a bit of wire? // You swore this was going to be like that time we borrowed tools from the smithing guild. "In and out," you said. "Quiet as a moth."
10. The Player [3 Amused, PlayerGrin]: Father wrote of them as though they were the key to every door the Guild has sealed shut. // And since we already have them and the Guild masters are none the wiser, the precise manner of their return is simply a puzzle for tomorrow's version of us to solve.
11. The Friend [3 Amused, FriendNervous]: By Aveline's light, I swear you shall be the architect of our shared grave.
12. The Player [3 Amused, PlayerSmile]: Come now. Before our pursuers find their nerve, let us find what lies ahead.
13. The Friend [0 Neutral, FriendNervous]: Naught but vermin and shadow, I'd wager.
14. The Player [0 Neutral, PlayerConcerned]: The dark thickens ahead. Keep to my heel.
15. *Narration:* The two boys press deeper into the sewers.

### Scene 2: Rat lead-in (`Tutorial_Scene2_RatEncounter`, over the map after the fade-in)

1. *Narration:* A large rat blocks the passage ahead, hissing through bared teeth.
2. The Player [3 Amused, PlayerBrave]: It appears you are a prophet in the making! Shall we put your reagents to the test, or must my blade speak first?
3. The Friend [0 Neutral, FriendSmirk]: The honor is entirely yours. My hands are meant for precise measures, not the crude butchery of sewer-kin.
4. The Player [3 Amused, PlayerDetermined]: Fair enough. I've a mind to warm the steel.

Encounter 1 follows.

### Scene 3a: After Encounter 1 (`Tutorial_Scene3_PostEnc1`, over black, end of Encounter 1)

1. *Narration:* The boys press onward through the dripping corridors.
2. The Friend [0 Neutral, FriendSmirk]: How many more of these vermin must we wade through before we find this chamber of yours?
3. The Player [3 Amused, PlayerSmile]: There is naught down here that my steel cannot answer.
4. The Friend [4 Sad, FriendNervous]: And what if we rouse the thousands of dead that rot beneath these stones? They will not share your confidence.
5. The Player [0 Neutral, PlayerConcerned]: You place stock in such tales?
6. The Friend [1 Angry, FriendSmile]: We were taught as much by your Father, if I recall.
7. The Player [0 Neutral, PlayerConcerned]: I trust what is placed before me, not what I am told.
8. The Friend [4 Sad, FriendNervous]: I would sooner retreat and live to greet the dawn than defy our elders' counsel and perish where the sun will never reach.
9. *Narration:* Two more rats emerge from the shadows ahead, blocking the passage.
10. The Player [0 Neutral, PlayerConcerned]: We shall turn back if the danger proves too great. This I promise you.
11. *Narration:* As the boys raise their guard, a faint glow pulses from the Friend's satchel. The stolen spectacles tremble against the cloth, their lenses catching a light that has no source.

PDF wording differences: line 4 is "Or perhaps we shall rouse the thousands of dead..."; line 7 is "I trust what I uncover, not what I am told."

### Scene 3b: Rats appear, the spectacles (`Tutorial_Scene3_RatsAppear`, over the map, start of Encounter 2)

The PDF calls this the Encounter 2 "LEAD-IN DIALOGUE".

1. *Narration:* The rats hold their ground ahead, but the Friend's attention is elsewhere. He draws the spectacles from his satchel, the glow still faintly pulsing within the glass. He turns them over in his hands, then raises them to his eyes.
2. The Friend [2 Tired, FriendNervous]: The lenses... they are warm to the touch. And there is something behind the glass, like a whisper pressing against the other side.
3. *Narration:* The Friend pulls them away, unsettled. He holds them out at arm's length.
4. The Friend [2 Tired, FriendNervous]: Here. Your Father sought them, not I. Whatever stirs within, it is yours to reckon with.
5. *Narration:* The Player takes the spectacles and raises them to the light. The glow steadies, as though the glass has found what it was searching for.
6. The Player [3 Amused, PlayerSmile]: Father's writings spoke true. There is power within, I can feel it.
7. The Friend [0 Neutral, FriendNervous]: My delight shall be complete once these are returned to the Guild masters' chest before they mark them missing.
8. The Player [0 Neutral, PlayerConcerned]: Then let us find this chamber before the dawn betrays our absence.
9. *Narration:* The Player dons the spectacles and turns to face the waiting rats.

PDF wording difference: line 6 is "There is power in this glass, I can feel it."

### Scene 4: The dead truth-seeker (`Tutorial_Scene4_Spectacles`, DialogueId `tutorial_scene4_dead_truthseeker`, over black, end of Encounter 2)

The asset file is named "Spectacles" but holds the skeleton scene.

1. *Narration:* The tunnel narrows. The air thickens with a smell that has nothing to do with the damp.
2. The Friend [2 Tired, FriendNervous]: There is a foulness here beyond the damp. Do you not taste it?
3. The Player [3 Amused, PlayerSmile]: We stand in a sewer, Friend. Foulness is the foundation.
4. The Friend [4 Sad, FriendNervous]: This is different. Tread carefully.
5. The Player [0 Neutral, PlayerConcerned]: There, against the stone. A figure.
6. The Friend [4 Sad, FriendNervous]: That is no living soul. The smell betrays it.
7. The Player [0 Neutral, PlayerConcerned]: ...Let us be certain.
8. *Narration:* They draw closer. The silhouette resolves into a skeleton, slumped against the tunnel wall. Both boys freeze.
9. The Friend [4 Sad, FriendNervous]: By the name of Aveline! We must go. At once!
10. The Player [0 Neutral, PlayerConcerned]: Hold. There is something at their side.
11. *Narration:* The Player kneels and lifts a scrap of parchment. The words are spelled out in dried blood: DANGER AHEAD
12. The Friend [1 Angry, FriendSmile]: You gave your word. You promised we would turn back if the danger proved too great.
13. The Player [0 Neutral, PlayerConcerned]: It is but bones. They could have lain here for an age.
14. The Friend [1 Angry, FriendSmile]: Bones that scrawled a warning in their own blood.
15. The Player [0 Neutral, PlayerConcerned]: Why would this soul have come so far alone? What drew them to the same path Father marked? The chamber holds the answer, and we are upon its threshold.
16. The Friend [4 Sad, FriendNervous]: I have followed you through every foolish scheme you have ever devised. Every one. But a corpse with a warning written in blood? This is where my courage finds its floor.
17. The Player [0 Neutral, PlayerConcerned]: Then I shall go alone. Though I would rather not.
18. *Narration:* The Friend hesitates. Looks at the skeleton. Looks at the Player.
19. The Friend [0 Neutral, FriendSmirk]: Aveline guide us.
20. *Narration:* The Friend moves forward, pauses at the remains, and gathers something from beside the body. They press on.

PDF stage directions not in Unity: "The Player stops them in their tracks." (after line 2) and "The Friend grabs the Player." (before line 12).

### Scene 5: Flanking banter (`Tutorial_Scene5_Flanking`, over black, start of Encounter 3)

1. *Narration:* The passage opens into a wider chamber. The Friend clutches the journal taken from the corpse, but before either can open it, skittering erupts from all sides. Rats pour from the drainage grates, cutting off retreat.
2. The Friend [4 Sad, FriendNervous]: They are upon us! There is no path back!
3. The Player [3 Amused, PlayerSmile]: Then we go through them. Do you recall the afternoons we spent perched in the rafters above the Adventurers' Guild?
4. The Friend [0 Neutral, FriendNervous]: I recall the imminent threat of the City Watch's lash, but the tactical application of such memories escapes me.
5. The Player [3 Amused, PlayerSmile]: Flanking! If we divide their attention and strike from the periphery, we turn the advantage in our favor.
6. The Friend [1 Angry, FriendNervous]: In theory, perhaps. But theory rarely survives contact with a half-dozen starving sewer-kin!
7. The Player [3 Amused, PlayerSmile]: Then abandon your theory and place your faith in my steel. Follow my lead!
8. The Friend [3 Amused, FriendNervous]: You shall be the architect of our shared funeral, I am certain of it.
9. *Narration:* They draw their weapons and turn to face the swarm.

### Scene 6: The journal and the dagger (`Tutorial_Scene6_PostEnc3`, over black, end of Encounter 3)

1. *Narration:* The swarm lies still. The two boys catch their breath in the aftermath. The Friend draws out the journal and dagger taken from the corpse.
2. The Friend [0 Neutral, FriendSmirk]: I took these from beside the remains. A journal, and a blade.
3. *Narration:* The Player takes the dagger, turns it in their hands. Their expression shifts.
4. The Player [0 Neutral, PlayerConcerned]: This steel... I know its temper. This is my Father's craft.
5. The Friend [2 Tired, FriendNervous]: Your Father forged a blade for one who perished in a sewer?
6. The Player [0 Neutral, PlayerConcerned]: Which means he knew. He knew of this place, and of whoever bore this blade into the dark.
7. *Narration:* The Player opens the journal.
8. *Narration:* "I am uncertain of my chances. Fellow truth-seeker, if I am no longer of this world, please search for M, their descendant, or bearer of their will. The Guild hides something down here. The chamber must hold a secret that I failed to uncover. Find it. Please. For a world with no more shadows."
9. The Player [0 Neutral, PlayerConcerned]: M... I have seen this mark among Father's letters.
10. The Friend [3 Amused, FriendSmile]: You have been through his archives.
11. *Narration:* A second entry, in a different hand.
12. *Narration:* "The whispers we shared bear truth, and the proof rests in my hands. I have unearthed a relic capable of shifting the very foundations of this Kingdom. I beg of you, M. Heed your conscience and present this to the High Council."
13. The Friend [0 Neutral, FriendNervous]: The foundations of the Kingdom. What manner of secret bears such weight?
14. The Player [0 Neutral, PlayerConcerned]: One that someone perished to uncover. And one that Father has kept from us. The chamber lies ahead. I shall not leave without answers.
15. The Friend [0 Neutral, FriendSmirk]: Lead the way.
16. *Narration:* They press on. The tunnel slopes downward, the air growing colder with each step.

PDF version of lines 7 to 12: "The Player opens the journal. The Player is prompted on how to access information via the Index/Glossary, which leads to them reading the journal entry." Line 8 is labelled "Index/Glossary Entry 2". Line 11 is "A new entry appears." Line 12 is labelled "Index/Glossary Entry 1" and ends with "It is secured with me at the tavern."

### Scene 7: Boss chamber (`Tutorial_Scene7_BossChamber`, over black, start of Encounter 4)

1. *Narration:* The passage opens into a vast, echoing chamber. A strange, ancient symbol is etched deeply into the far wall. As the boys approach the sigil, the shadows stir. Two enormous sewer-kin slink forward, flanked by a towering, grotesquely mutated rat.
2. The Player [0 Neutral, PlayerConcerned]: The stonework matches the cipher. The chamber is ahead.
3. The Friend [4 Sad, FriendNervous]: Those beasts... could they be what slew the one whose bones we found?
4. The Player [3 Amused, PlayerSmile]: They guard the path, and they shall answer for it. Blades ready. We avenge the fallen, and then we claim what they could not reach.

In the PDF the Player's line 2 comes before "As the two boys approach the sigil, the shadows stir..."

### Encounter 4 runtime lines (built in code in `TutorialEncounter4.cs`)

These lines have no portrait and Emotion 0. Each threshold also posts an italic combat log line.

At Tyrant HP at or below 50% (once):
- Combat log: *The Sewer Tyrant's hide splits; something beneath it convulses.*
- The Friend: What fresh horror is this? Its very flesh tears itself apart!

At Tyrant HP at or below 25% (once):
- Combat log: *The Sewer Tyrant staggers. Its movements grow desperate.*
- The Friend: Its vitality wanes! We have it on the brink!
- The Player: Then let our steel cast the final judgement!

On Tyrant death (after a 1 second wait):
- The Friend: Aveline protect us. By every probability, that should have been our tomb.
- The Player: Probability does not carry a blade, my friend. We fought as one!
- *Narration:* The chamber lies open. What waits beyond, no map can show.

### Scene 8 (script only, not built in Unity)

PDF heading: SCENE 8: INT. CAPITAL SEWERS - DAY. The Player and The Friend are in the large room with the symbol on the wall after Encounter 4.

1. THE PLAYER: Search every stone.
2. THE FRIEND: Halt. Come look at this foul beast.
3. *Narration:* The boys crouch down to inspect the creature's massive carcass.
4. THE FRIEND: Look at the bone structure... the corruption bleeds deep into the marrow. I know not what malady plagues it, but its flesh is entirely warped.
5. THE PLAYER: Is there naught in your texts that makes sense of the matter?
6. THE FRIEND: There is naught. Whatever the explanation, it is clear the answer will not show itself by staring at this corpse.
7. *Narration:* The two boys leave the body and walk towards the symbol on the wall.
8. THE PLAYER: Come, look upon this stonework.
9. *Narration:* The Player produces the map and unfurls it between them. This prompts the Player to view the map.
10. *Map screen:* MAP OF CAPITAL SEWERS: Features the same symbol as the one that's currently on the wall.
11. THE FRIEND: The crests... they are identical.
12. THE PLAYER: Exactly. Which means our true prize must be hidden right here.
13. THE FRIEND: I wonder... might these spectacles pierce the veil of what is hidden?
14. *Interaction:* The Player is prompted to use the "Examine" mechanic on the symbol. The Player uses the spectacles to reveal a door.
15. THE PLAYER: By the will of Aveline...
16. THE FRIEND: What is it? What has been unveiled?
17. THE PLAYER: It is... beautiful.
18. THE FRIEND: Spare me the vague and speak plainly. What do you see?
19. THE PLAYER: A... doorway. Forged of light and energy. These patterns are no simple marks.
20. THE FRIEND: You are staring at bare stone with the grin of a madman. There is nothing but-
21. THE PLAYER: Then watch as I walk through stone! Stay on my heels!
22. *Narration:* The Player disappears through the portal. The Friend pauses for a moment in confusion.
23. THE FRIEND: ...
24. *Narration:* The Friend edges forwards towards the invisible portal, and creeps through.

### Scene 9 (script only, not built in Unity)

PDF heading: SCENE 9: EXT. MEADOWS OF AVELINE - DAY.

1. *Narration:* The Player exits the portal into a small tunnel with a light at the end of it.
2. THE PLAYER: Where... am I?
3. *Narration:* The Player slowly moves out of the tunnel and into the light. They exit into broad daylight, green fields and flowers blossoming underneath trees. The air is warm and wind is fresh. The blue skies are endless.
4. *Narration:* The Player stumbles around being overwhelmed by their new surroundings.
5. THE FRIEND (O.S.): You were right! By the stars and the sky, you were right!
6. *Narration:* The Player is dumbfounded by where the voice is coming from, momentarily overwhelmed by their new surroundings. The Friend suddenly appears back on the screen and tackles The Player to the ground in a tangle of limbs and laughter.
7. THE FRIEND: Look at the light, brother! No smog, no soot... 'tis pure gold!
8. *Narration:* The Player who was still in a daze, finally comes to.
9. THE PLAYER: I felt it in the marrow. I knew the world held more than iron's bite and ashen shroud.
10. THE FRIEND: Vindicated? You've struck the very boundaries of the world and found them brittle!
11. THE PLAYER (Shouting at the sky): DO YOU HEAR THAT, AURENTHAL? YOUR STAIN CANNOT REACH THIS FAR!
12. THE FRIEND (shaking head in disbelief): It's true. It's all true.
13. *Narration:* They lie there for a moment, simply enjoying the fresh air. Slowly, they sit up, and their celebration tapers off as they look toward the horizon. In the far distance, shrouded in a permanent grey haze, they can see the jagged iron spires and black smoke of the Capital. Their home looks like a festering wound on the face of this beautiful world, and the frame holds here for a moment to watch the columns of smoke billowing upward from the city.
14. THE FRIEND (CONT'D) (His tone shifting to a hushed, dangerous gravity): We have to go back. Immediately. Every soul in the lower wards must know of this. The High Council... the Guilds... they've built a cage and called it the world. There are no monsters out here.
15. THE PLAYER: I agree, but... should we not see for ourselves first?
16. THE FRIEND: Once again, your curiosity invites a reckoning. But... very well. Lead on, explorer.
17. *Narration:* The two boys continue into their new surroundings.

### Scene 10 (script only, not built in Unity)

PDF heading: SCENE 10: EXT. MEADOWS OF AVELINE - DAY. Text is copied as written, including its typos.

1. *Narration:* The two boys continue down the path until they see something under the tree. It's a white glowing figure sitting on a swing. The two boys get closer and interact with it. The figure is a young woman with flowing white hair. She's dressed in a long white dress that stretches from head to toe, with a bright green amulet around her neck.
2. THE PLAYER: Hello?
3. MYSTERIOUS GLOWING WOMAN: Oh, hello. ...You've come a long way.
4. THE PLAYER: Do I know you?
5. MYSTERIOUS GLOWING WOMAN: No, I suppose not. But none treads these grounds with neither your garbs nor your curiosity. Terrible horrors wanders about.
6. THE PLAYER: Or so I've heard. What kind?
7. MYSTERIOUS GLOWING WOMAN: Too many to list.
8. THE FRIEND: How do you get here... Fair Lady?
9. MYSTERIOUS GLOWING WOMAN: I've always been here. Did you cross through the gates?
10. THE PLAYER: The glowing one? We did.
11. MYSTERIOUS GLOWING WOMAN: So... his ventures bore fruits. I'm glad to hear.
12. THE PLAYER: Who is he?
13. MYSTERIOUS GLOWING WOMAN: ...Did you receive maps, and notes from a smith?
14. THE PLAYER: ...You know my father.
15. MYSTERIOUS GLOWING WOMAN: ...
16. MYSTERIOUS GLOWING WOMAN: My time is running short... and, one has latched onto your scent. You should go. Now.
17. THE FRIEND (hurriedly): What do you mean?
18. MYSTERIOUS GLOWING WOMAN (Slowly fades out): We will meet again. I'm sure of it. Keep searching, there is an answer to all of your questions.
19. *Narration:* The Mysterious Glowing Woman disappears.
20. THE PLAYER: Wait-!
21. *Narration:* The two friends stand there dumbfounded. Footsteps coming from the bushes.
22. THE FRIEND (CONT'D): What is it?
23. *Narration:* A silhouette shambles forward out of the foliage, limping, It's limbs are crooked with missing parts, and is dripping with blood.
24. THE FRIEND (CONT'D) (whispering in horror): The Cleric's tales. They're...
25. THE PLAYER: ...
26. *Narration:* The two boys freeze as the creature lets out a low, wet rasp, its fingers twitching with a hunger that defies the grave. Further behind, more silhouettes visible between the foliage. The player draws their sword.
27. THE FRIEND: We have to flee!
28. THE PLAYER: No. We can handle it.
29. THE FRIEND: Are you insane?! We are no match for these... demons!
30. THE PLAYER: Time to find out, whether the tales were true, or exaggerated.

---

## 3. Encounters

### Shared tutorial mechanics (all four encounters)

**Scene and loading.** All four encounters run in one scene, `Scenes/TutorialCombat.unity`. `TutorialEncounterActivator` enables the controller whose index is `completed + 1`, where `completed` is the PlayerPrefs value `Ungilded_TutorialProgress_Slot{n}` (default -1). `TutorialCombatProvider` supplies the matching `EncounterDefinition` from `ScriptableObjects/Tutorial/Encounters/Tutorial_Encounter1..4.asset` and builds the party from the two pregens each time the scene loads (full HP, fresh ability uses, empty Creature Compendium).

**Map.** No encounter sets `CombatMapId`. The map is generated from the Sewer biome (`ScriptableObjects/Expedition/Biomes/Sewer.asset`): size between 10x12 and 20x18 (default params 14x14), macro shapes SewerTunnel_Basic, SewerTunnel_Drainage, SewerTunnel_Full, SewerChamber_Open (2 to 3 pillars), SewerChamber_Full (4 to 6 pillars), setpieces SewerGrate and CollapsedCeiling, debris patches SewerSlime, BrokenPipe, StandingWater, SewerDebris, DrainGrate. Cover 3%, water 2%, difficult terrain 4%, walls 5%. There is no authored pillar or sludge layout in Unity.

**Placement.** Each script calls `FindMapCenter()`: the walkable, unoccupied tile nearest to 30% of the map width from the left edge, vertically centred. Call it P. Enemies are placed toward +x. Coordinates below are offsets from P. `ClearTileHazards` then sets a box of tiles to plain ground (balance DC 0, movement cost 1, no plant terrain).

**Pipeline.** `TutorialEncounterController.MasterPipeline`:
1. Subclass builds a fixed initiative order and teleports units.
2. Every combatant is flagged player-controlled so the enemy AI does not run. The script drives every turn.
3. One frame wait, then `StartEncounterWithFixedOrder`. The Player's turn starts at once.
4. The loading screen fades out over the black narrative backdrop.
5. The subclass script runs.

**Popups.** `TutorialPopupUI` shows each popup in the same dialogue box as story dialogue, speaker name "TUTORIAL", typewriter reveal at 40 characters per second (DialogueBoxUI default), click to advance. Popups queue if the box is busy. The script waits for dismissal before continuing. In the source, highlighted words are wrapped in `<color=#FFD666>`; the tables below show the plain text and list the gold words separately.

**Input restriction.** `TutorialInputRestriction.RestrictTo(names...)` disables every command menu entry whose label does not contain one of the names (case-insensitive substring). Allowed labels pulse between white and gold (1, 0.84, 0) at `PingPong(t*2)`. While any dialogue or popup is showing, every menu entry is disabled. `Unrestrict()` enables all entries.

**Movement restriction.** `RestrictMovementTo(tiles, message)` installs a destination validator on the movement controller. Choosing any other tile cancels the move with no action spent, re-highlights the allowed tiles and shows `message` as a popup. Allowed tiles flash between gold at alpha 0.2 and gold at alpha 0.65 (`PingPong(t*1.8)`). "Adjacent" in the scripts means the four orthogonal neighbours that are walkable, not water, and unoccupied.

**Waiting for an action.** `WaitForActionUsed` waits for the game state to leave idle and return, and only advances when the acting character's remaining actions went down. Cancelling an action does not advance the step.

**Forced dice.** `ScriptNextOutcome(character, degree, displayD20, damageDie)` queues a forced degree of success on the character's rule event bus (`DegreeAdjustmentContext`, final priority, source "Tutorial"). It also queues the d20 value and one damage die value in the dice roller so the combat log shows matching numbers. Extra dice (Sneak Attack, splash) are not queued and roll normally.

**Scripted enemy actions.** Enemy moves use `ForceMoveTo` with either `Stride` semantics (provokes reactions) or `Forced` semantics (does not). Enemy strikes use the creature's first melee strike through the normal strike resolver.

**End of encounter.** Encounters 1 to 3 call `TransitionToNextEncounter(backdrop, dialogue)`: mark the encounter complete in PlayerPrefs, set the game state to idle, fade the black backdrop in over 0.5 s, play the dialogue over black, show the loading screen, reload `TutorialCombat`. The next encounter then fades the backdrop out over 1.5 s. The victory/results screen is skipped for the tutorial provider (`VictoryScreenUI`).

**Fade timings.** Narrative backdrop fade-out 1.5 s (unscaled). Transition fade-in 0.5 s.

### Encounter 1: "The 3-Action System"

Data: `Tutorial_Encounter1` ("A single sewer rat blocks the path. Learn to Stride, Strike, and use Reactive Strike."). One Sewer Rat, SpawnZone Front.

Script: `Scripts/Tutorial/Encounters/TutorialEncounter1.cs`. `desiredRatDistance` is 4 in code and 3 in the scene, so the build uses 3.

**Pre-combat flow.** Black backdrop on. Narrative intro. Scene 1. Fade out 1.5 s. Scene 2 over the map.

**Positions and setup.**

| Unit | Tile | Notes |
|---|---|---|
| The Player | (0, 0) | |
| The Friend | (-1, 0) | Auto-passes |
| Sewer Rat | (3, 0) | Max HP overridden to 18 |

Hazards cleared: x 0 to 4, y -1 to 1.

Initiative: Player, Friend, Rat.

HP arithmetic: Strike 1 deals 4 + 4 = 8, Reactive Strike deals 6 + 4 = 10. 18 HP is exactly two hits with the Player's +4 Strength.

**Steps.**

| # | When | Popup text (plain) | Gold words | Allowed inputs | Advance on | Forced roll |
|---|---|---|---|---|---|---|
| 1 | Player turn start | "Each turn you have 3 actions. Every action you take in combat (moving, striking, raising a shield) costs 1 or more actions. Spend them wisely." | 3 actions | none (dialogue) | dismiss | |
| 2 | | "To act in combat, first select an action from the command menu on the left, then select your target on the battlefield. The menu tells your character WHAT to do. The battlefield tells them WHERE or WHO." | command menu | none | dismiss | |
| 3 | | "The rat is out of reach. Select Move from the command menu. // The highlighted tiles show everywhere you can reach. Brighter tiles are within one Move action. Dimmer tiles would require a second action. // The gold tiles are tutorial indicators. Click one of them to close the distance." | Move; highlighted tiles; Brighter tiles; Dimmer tiles; gold tiles | none | dismiss | |
| 4 | After popup 3 | (gold tiles appear on the rat's free orthogonal neighbours) | | Move; destination limited to the gold tiles. Wrong tile shows "Click one of the gold tiles next to the Sewer Rat." | 1 action spent | |
| 5 | | "Your character follows the shortest path to the selected tile. Each tile costs 5 feet of your Speed to cross. // With 25 feet of Speed, you can cover up to 5 tiles in a single Move action. Tiles beyond that range require a second action." | 5 feet; 5 tiles | none | dismiss | |
| 6 | | "Now that you are adjacent, you can attack. Select Strike from the command menu, then click the Sewer Rat." | Strike | Strike | 1 action spent | Success, d20 shows 12, damage die 4 |
| 7 | | "A clean Hit! Every attack resolves as one of four outcomes: Critical Hit, Hit, Miss, or Critical Miss." | Hit | none | dismiss | |
| 8 | | "Each additional Strike in the same turn takes a stacking -5 penalty. This is the Multiple Attack Penalty (MAP). // Select Strike again to see it in action." | -5 penalty; Multiple Attack Penalty (MAP); Strike | Strike (still set from step 6) | 1 action spent | Failure, d20 shows 3 |
| 9 | | "Missed. The MAP made that second Strike much harder to land. Select End Turn to finish your turn." | Missed; End Turn | End Turn | Player turn ends | |
| 10 | Friend turn | (none) | | | Script ends the turn after 2 frames | |
| 11 | Rat turn start, before it moves | "The Sewer Rat is wounded and panicking. It will try to flee through your reach. // Your fighter has Reactive Strike: when an enemy moves out of your melee reach, you can spend your Reaction for a free Strike. // Accept the prompt when it appears." | Reactive Strike; Reaction; Accept the prompt | none | dismiss | Queues Success, d20 shows 15, damage die 6 for the Player |
| 12 | | (rat flees) | | Reaction prompt only | Rat turn ends | |

**Enemy scripting (rat flee).** There is no AI flee behaviour in this fight. The script computes `fleeDir = ratPos - playerPos` (right if zero) and a target one tile further in that direction. The rat sprite slides 40% of the way toward that tile over 0.35 s, then `ForceMoveTo(target, Stride)` runs from the original tile. Leaving the Player's reach triggers the Reactive Strike prompt. The forced hit kills the rat. The script waits for the rat's turn end (fires even if the rat dies), waits 1 s, restores party HP and transitions with Scene 3a.

**PDF version (designer intent).**
- Setup: about 6x6 grid, sewer flooring, flat, no cover or elevation. One "Large Rat" 3 to 4 tiles from the Player. Friend at the back, auto-passes, log line "The Friend holds back."
- Rolls: Strike 1 Hit (rat to about 50%), Strike 2 Miss after MAP, rat flees and triggers Reactive Strike, Reactive Strike Hit kills it. No crits.
- Step 1 visuals: camera frames the grid, rat pulses, action tracker with 3 pips, separate lit Reaction icon.
- Step 2 popup: "Stride moves your character up to their Speed in one action. Click the highlighted tile to close the distance." All other controls locked.
- Step 3 popup: "Strike is your basic attack. Hover an enemy to preview your chance to hit and what each outcome does." Target panel shows Name, HP bar without a number, AC ???, saves/resistances/weaknesses/abilities ???, and outcome bands with probabilities. Inline callout next to the ??? rows: "Some details are unknown. You will learn how to reveal them later." After the hit: "A clean Hit. Every attack resolves as Critical Hit, Hit, Miss, or Critical Miss. You will see more of those outcomes as the fight goes on." Then THE FRIEND: "You've struck it deep. Finish it!"
- Step 4 popup: "Each additional Strike on the same turn takes a stacking -5 penalty, up to a maximum of -10. This is the Multiple Attack Penalty, or MAP." Hover tooltip shows [-5 MAP]. After the miss: "Missed. Sometimes the second Strike is still worth the risk, but sometimes it is better to move, raise a shield, or hold back."
- Enemy turn popups, in order: "The rat is wounded and panicking. It is going to run for safety." / (animation pauses mid-move, Reaction icon pulses) "This is a Reaction. You get 1 Reaction every round, separate from your 3 actions. Reactions trigger off specific conditions. A Reaction interrupts the normal flow of gameplay to allow you to decide if it should be used." / "When an enemy uses a move action while still inside your reach, you can spend your Reaction for a free Strike called Reactive Strike. A fleeing enemy is rarely safe." / (prompt over the rat) "Spend your Reaction to Strike the rat." Reaction icon greys out after use. Victory flourish.

**Rules taught (checklist).**

| Rule | PDF goal | Built |
|---|---|---|
| 3 actions per turn | (1) | Yes, popup 1 |
| Command menu then target | | Yes, popup 2 (Unity only) |
| Stride moves, Strike attacks | (2) | Yes |
| Movement range bands, 5 ft per tile, 25 ft Speed | | Yes, popups 3 and 5 (Unity only) |
| Four degrees of success | (4) | Yes, popup 7 |
| MAP on later Strikes | (3) | Yes, popups 8 and 9 (Unity omits the -10 cap) |
| Reactions as a separate per-round resource; Reactive Strike | (5) | Partly. Reactive Strike is taught; the "1 Reaction per round" rule is not stated. |
| Hidden ??? info on enemies | (6) | No popup in Encounter 1 |

### Encounter 2: "Recall Knowledge"

Data: `Tutorial_Encounter2` ("Two sewer rats block the path. Learn to study your enemy and heal after battle."). Two Sewer Rats, SpawnZone Front.

Script: `TutorialEncounter2.cs`. `desiredRatDistance` 3 in the scene.

**Pre-combat flow.** Black backdrop on, fade out 1.5 s with no dialogue (Scene 3a already played at the end of Encounter 1). Scene 3b over the map.

**Positions and setup.**

| Unit | Tile | HP |
|---|---|---|
| The Player | (0, 0) | full |
| The Friend | (-1, 0) | full, auto-passes |
| Rat 1 | (3, 0) | 8 (stat block) |
| Rat 2 | (4, 1) | 8 (stat block) |

Hazards cleared: x -1 to 5, y -1 to 2. Initiative: Player, Friend, Rat 1, Rat 2.

**Steps.**

| # | When | Popup text (plain) | Gold words | Allowed inputs | Advance on | Forced roll |
|---|---|---|---|---|---|---|
| 1 | R1 Player turn start | "Some enemy information is hidden until revealed. Recall Knowledge costs 1 action. // Open Skills on the command menu, select Recall Knowledge, and target one of the Sewer Rats." | Recall Knowledge; Skills; Recall Knowledge | Skills, Recall Knowledge, Back | 1 action spent | Success, d20 shows 14 |
| 2 | | "Success! You learned the creature's name and its Armor Class. // The first successful Recall Knowledge against a new creature always reveals its name for free and unlocks its entry in the Creature Compendium. // Every success reveals one additional fact about the creature." | Armor Class; Creature Compendium | none | dismiss | |
| 3 | Gold tiles and movement lock are set before this popup | "The rat is out of reach. Select Move from the command menu, then click one of the gold tiles next to it to close the distance." | Move; gold tiles | Move; destination limited to Rat 1's free neighbours. Wrong tile: "Click one of the gold tiles next to the Sewer Rat." | 1 action spent | |
| 4 | | "Now that you are adjacent, you can attack. Select Strike from the command menu, then click the Sewer Rat." | Strike | Strike | 1 action spent | Success, d20 shows 16, damage die 8 (12 damage, kills Rat 1) |
| 5 | | "Click End Turn to finish your turn." | End Turn | End Turn | Player turn ends | |
| 6 | Friend turn | (none) | | | auto-pass after 2 frames | |
| 7 | Rat 2 turn | (none) | | | scripted, see below | Rat 2: Success, d20 shows 15, damage die 2 (3 damage) |
| 8 | After Rat 2's turn ends | "You took damage. Your Hit Points represent how much punishment you can endure. When they reach zero, you fall. // Keep an eye on your health bar and the health bars of your allies." | Hit Points | none | dismiss | |
| 9 | R2 Player turn start | "The rat is wounded and within reach. Select Strike, then click the rat to finish it off." | Strike | Strike | 1 action spent | Success, d20 shows 14, damage die 6 (10 damage, kills Rat 2) |
| 10 | | (none) | | Unrestricted | 2 s wait | |

Popup 9 calls Rat 2 "wounded", but nothing in the script damages Rat 2 before that Strike.

**Enemy scripting.** Rat 1 is dead before its turn. Rat 2 is moved with `Forced` semantics (no reaction) to the tile at Player + (1, 0), waits 1 s, then strikes the Player with its Jaws. The script ends its turn. After the fight the script restores party HP to full and transitions with Scene 4.

**What Recall Knowledge reveals in code.** `MonsterJournal.RevealFields` reveals Name for free on the first success, then picks the other facts at random (AC, MaxHP, Fort, Ref, Will, Speeds, Resistances, Weaknesses, Immunities, Strikes, Traits, abilities). A Success reveals 1 extra fact and a Critical Success 2. The forced degree does not choose which fact, so popup 2 ("name and its Armor Class") is only true when AC is the random pick.

**PDF version (designer intent).**
- Setup: small grid, sewer walkway, flat. Two Sewer Rats 3 to 4 tiles away. Friend auto-passes.
- Rolls: R1 RK Success reveals Name and unlocks the Compendium entry. R1 Strike Hit kills Rat 1. Surviving rat Strides and Strikes the Player, Hit, about a quarter of the Player's max HP. R2 RK Success reveals AC; the AC row flips from ??? to the number with a highlight flourish. R2 Strike Hit kills Rat 2. Post-combat Treat Wounds by THE FRIEND (trained in Medicine): Success, restores most of the Player's missing HP. No crits.
- The PDF notes "Specific steps of the tutorial have been removed for brevity. Available upon request." There are no PDF popup texts for this encounter.

**Rules taught (checklist).**

| Rule | PDF goal | Built |
|---|---|---|
| Recall Knowledge is a 1-action skill check | (1) | Yes, popup 1 |
| Success reveals one fact; Name first and free | (2) | Yes, popup 2 (claims AC, which is random) |
| Name unlocks the Creature Compendium entry | (3) | Yes, popup 2 |
| Target panel ??? rows update when revealed | (4) | Engine behaviour, no popup |
| Compendium persists across the expedition | (5) | No. The tutorial journal is recreated on every scene load. |
| Enemies Strike back; damage carries over | (6) | Enemy Strike yes (popup 8). Carry-over no (auto-heal and reload). |
| Treat Wounds between encounters | (7) | No |

### Encounter 3: "Fight Together"

Data: `Tutorial_Encounter3` ("Three sewer rats block the path. Learn flanking and teamwork."). Three Sewer Rats, SpawnZone Front.

Script: `TutorialEncounter3.cs`.

**Pre-combat flow.** Black backdrop on. Scene 5 over black. Fade out 1.5 s. The Player's turn starts.

**Positions and setup.**

```
y=1            R2
y=0   P        R1      R3
y=-1  F
     x=0  1  2  3  4  5
```

| Unit | Tile | HP |
|---|---|---|
| The Player | (0, 0) | full |
| The Friend | (0, -1) | full |
| Rat 1 | (3, 0) | 16 (override) |
| Rat 2 | (3, 1) | 10 (override) |
| Rat 3 | (5, 0) | 8 (stat block) |
| Player flank tile on Rat 1 | (2, 0) | |
| Friend flank tile on Rat 1 | (4, 0) | |

Hazards cleared: x -2 to 6, y -2 to 2. Initiative: Player, Friend, Rat 1, Rat 2, Rat 3.

HP arithmetic: Player hits for 8 then 6 (Rat 1 at 2 HP). Friend dagger 4 + Sneak Attack 1d6 kills Rat 1. Player crit on Rat 2 deals (6 + 4) x 2 = 20.

**Steps.**

| # | When | Popup text (plain) | Gold words | Allowed inputs | Advance on | Forced roll |
|---|---|---|---|---|---|---|
| 1 | R1 Player turn start | "The Friend has joined the fight. Each ally takes their own turn with their own 3 actions, and you control all of them." | 3 actions | none | dismiss | |
| 2 | Gold tile (2, 0) and movement lock set before popup | "The rat is out of reach. Select Move, then click the gold tile next to the front rat." | Move; gold tile | Move; only (2, 0). Wrong tile: "Click the gold tile next to the front rat." | 1 action spent | |
| 3 | | "You are adjacent. Select Strike, then click the rat." | Strike | Strike | 1 action spent | Success, d20 shows 14, damage die 4 |
| 4 | | "You have one action left. A Strike at -5 MAP is one option, but in tougher fights, consider using your last action to move to safety, learn about the enemy, or support an ally. // For now, select Strike again." | -5 MAP; move to safety; learn about the enemy; support an ally | Strike | 1 action spent | Success, d20 shows 12, damage die 2 |
| 5 | | (none) | | End Turn | Player turn ends | |
| 6 | R1 Friend turn start; gold tile (4, 0) and lock set before popup | "It is now the Friend's turn. Select Move, then click the gold tile on the opposite side of the rat from the Player. // This will set up a flanking line." | Move; gold tile; flanking line | Move; only (4, 0). Wrong tile: "Click the gold tile on the opposite side of the rat." | 1 action spent | |
| 7 | | "The rat is now flanked: your Player and Friend threaten it from opposite sides. // A flanked enemy becomes Off-Guard, which lowers its AC by 2. The Friend has Sneak Attack: extra damage whenever the target is Off-Guard. // Select Strike, then click the rat." | flanked; Off-Guard; Sneak Attack | Strike | 1 action spent | Friend: Success, d20 shows 15, damage die 4. Kills Rat 1. |
| 8 | Gold tiles = free neighbours of Rat 2 that flank it with the Player (script comment expects (4, 1)) | "There are more rats ahead. Use the Friend's last action to Move into a flanking position on the next rat. // Select Move, then click one of the gold tiles." | Move; gold tiles | Move; only the flank tiles. Wrong tile: "Click one of the gold tiles to set up a flanking line." | 1 action spent | |
| 9 | | (none) | | End Turn | Friend turn ends | |
| 10 | R1 rat turns | (none) | | | scripted, see below | Rat 2: Failure, d20 shows 5 |
| 11 | R2 Player turn start; gold tiles = free neighbours of Rat 2 that flank it with the Friend (comment expects (2, 1)) | "Set up another flanking line. Select Move, then click the gold tile." | Move; gold tile | Move; only the flank tiles. Wrong tile: "Click one of the gold tiles to set up a flanking line." | 1 action spent | |
| 12 | No popup before this step | (none) | | Strike | 1 action spent | Critical Success, d20 shows 18, damage die 6. Kills Rat 2. |
| 13 | | "Critical Hit! When your attack exceeds the enemy's AC by 10 or more, damage is doubled. // Check the combat log: modifiers that changed the outcome are highlighted. The Off-Guard penalty made the difference." | Critical Hit!; combat log; highlighted | none | dismiss | |
| 14 | | (none) | | Unrestricted | any 1 action spent | |
| 15 | | (none) | | End Turn | Player turn ends | |
| 16 | R2 Friend turn | (none) | | Unrestricted, all 3 actions free | Friend turn ends | |
| 17 | R2 rat turns | (none) | | | each living rat's turn is ended after 2 frames with no action | |

**Godot 2026-10-22.** The Godot build plays the PDF table (section 8), and round 3 is guided rather than scripted. See "Tutorial pacing pass (user, 2026-10-22)" in section 8.

**Enemy scripting.**
- Round 1: Rat 1 is dead and skipped. Rat 2 is diagonal to the Player ((3, 1) against (2, 0)) and strikes without moving; forced Miss. Rat 3 is moved with `Forced` semantics from (5, 0) to (4, 0), then waits 0.5 s.
- Round 2: living rats do nothing.
- After round 2 the script restores party HP, waits 1 s and transitions with Scene 6. It does this whether or not Rat 3 is dead.

**PDF version (designer intent).**
- Setup: about 10x10, open sewer chamber, flat. Two stone pillars mid-grid. Five Sewer Rats: Rats 1 and 2 forward (3 to 4 tiles), Rats 3 and 4 mid-chamber beside a pillar, Rat 5 at the back. Rat 4 has a hidden VICIOUS BITE (1d4 persistent bleed on Hit) that stays a "??? Ability" row; its icon pulses when it fires but never names itself. The Friend is active with Lesser Acid Flasks and a dagger, trained in Alchemy and simple weapons, and has Sneak Attack (1d6 precision vs Off-Guard). Initiative Player, Friend, rats.
- Scripted roll table:

| Round | Actor | Action | Outcome |
|---|---|---|---|
| 1 | Player | Strike Rat 1 (not flanked) | Hit. Rat 1 to about 50%. |
| 1 | Player | Strike Rat 1 at -5 MAP | Hit. Rat 1 to about 25%. |
| 1 | Friend | Acid Flask at Rat 3 | Hit. Direct + splash to Rat 3, splash only to adjacent Rat 4. |
| 1 | Rats 1, 2 | Stride + Strike the Player | Both Miss |
| 1 | Rats 3, 4 | Stride forward | |
| 1 | Rat 5 | Stride from the back | Still out of reach |
| 2 | Player | Strike Rat 1, flanked with the Friend | Critical Hit. Kills Rat 1. |
| 2 | Player | Strike Rat 2, not flanked, -5 MAP | Critical Miss |
| 2 | Player | Strike Rat 2, not flanked, -10 MAP | Hit. Rat 2 to low HP. |
| 2 | Friend | Dagger Strike Rat 2, flanked by the Player | Hit + Sneak Attack 1d6. Kills Rat 2. |
| 2 | Friend | Acid Flask at Rat 3, -5 MAP | Hit. Finishes Rat 3, splash pings Rat 4. |
| 2 | Rat 4 | Stride + Strike the Friend | Hit, minor damage. Hidden slot pulses. Friend gains 1d4 persistent bleed. |
| 2 | Rat 5 | Stride to mid-chamber | Out of reach |
| 3 | Player | Strike Rat 4 | Hit. Kills Rat 4. |
| 3 | Player | Stride toward Rat 5, Strike at -5 MAP | Hit. Rat 5 to low HP. |
| 3 | Friend | Dagger Strike Rat 5, flanked | Hit + Sneak Attack. Kills Rat 5. |
| 3 | Friend, end of turn | Bleed tick 1d4 | Rolls 2. Recovery flat check DC 15: Success, bleed ends. |

- The PDF notes "Specific steps of the tutorial have been removed for brevity." There are no PDF popup texts for this encounter.

**Rules taught (checklist).**

| Rule | PDF goal | Built |
|---|---|---|
| Each ally has own turn, 3 actions, 1 Reaction; player controls all | (1) | Yes, popup 1 (Reaction not mentioned) |
| Alchemical bomb as a 1-action ranged Strike | (2) | No (moved to Encounter 4) |
| Area attack shape (primary target + adjacent) | (3) | No (Encounter 4 popup 5 mentions splash) |
| Splash damage rules (flat, no crit, no MAP, none on Crit Miss) | (4) | No |
| Flanking makes the target Off-Guard (-2 AC) | (5) | Yes, popups 6 and 7 |
| Off-Guard targets are easier to hit and crit | (6) | Partly (popup 13) |
| Critical Hit doubles damage | (7) | Yes, popup 13 |
| Critical Miss | (8) | No |
| Conditions trigger features (Sneak Attack off Off-Guard, agile/finesse only) | (9) | Partly, popup 7 |
| Persistent damage at end of turn | (10) | No |
| Recovery flat check DC 15 | (11) | No |
| Hidden abilities stay hidden after firing | (12) | No |
| Outnumbered fights reward bombs and positioning | (13) | No |
| MAP alternatives (move, learn, support) | | Yes, popup 4 (Unity only) |
| Combat log highlights deciding modifiers | | Yes, popup 13 (Unity only) |

### Encounter 4: "The Capstone"

Data: `Tutorial_Encounter4` ("A grotesque mutant rat and its dire guardians. The final test of everything you have learned."). One Sewer Tyrant, SpawnZone Back. Two Dire Sewer Rats, SpawnZone Front.

Script: `TutorialEncounter4.cs`.

**Pre-combat flow.** Black backdrop on. Scene 7 over black. Fade out 1.5 s.

**Positions and setup.**

| Unit | Tile | Notes |
|---|---|---|
| The Player | (0, 0) | |
| The Friend | (-1, 0) | |
| Sewer Tyrant | placed by the deployment system in the Back zone | 35 HP |
| Dire Sewer Rat x2 | placed by the deployment system in the Front zone | 16 HP each |

Hazards cleared: x -3 to 8, y -3 to 3. This removes difficult terrain in that box, which overlaps the area where the popup 1 difficult terrain would be.

Initiative: Player, Friend, Tyrant, Dire Rats (the Tyrant is found by the name containing "Tyrant").

**Steps.**

| # | When | Popup text (plain) | Gold words | Allowed inputs | Advance on | Forced roll |
|---|---|---|---|---|---|---|
| 1 | R1 Player turn start | "Some tiles ahead are difficult terrain. Moving into them costs an extra 5 feet. Plan your path before you commit." | difficult terrain | none | dismiss | |
| 2 | | "That central beast looks dangerous. Open with Recall Knowledge to learn what you are dealing with. Open Skills, select Recall Knowledge, and target the large creature." | Recall Knowledge; Skills; Recall Knowledge | Skills, Recall Knowledge, Back | 1 action spent | Critical Success, d20 shows 19 |
| 3 | | "Critical Success! Recall Knowledge reveals two facts instead of one. You learned the creature's Name, AC, and its Weakness: Acid 3. // A creature with Weakness takes additional damage of that type equal to the Weakness value." | Critical Success!; two; Weakness: Acid 3 | none | dismiss | |
| 4 | | (none) | | Unrestricted, 2 actions | Player turn ends | |
| 5 | R1 Friend turn start | "The Friend carries Acid Flasks in their Abilities menu. Acid Flasks deal acid damage, which triggers the Tyrant's Weakness. // Select Abilities, then Throw Acid Flask, and target the Tyrant." | Acid Flasks; Abilities; Abilities; Throw Acid Flask | Abilities, Throw Acid Flask, Back | 1 action spent | Friend: Success, d20 shows 15, damage die 1 |
| 6 | | "The acid damages the target directly and splashes onto every adjacent creature. The Tyrant's Weakness added 3 extra damage on top. // The rest of this fight is yours. Use flanking, Sneak Attack, and the Tyrant's acid weakness." | splashes; Weakness; flanking; Sneak Attack; acid weakness | none | dismiss | |
| 7 | | (none) | | Unrestricted | | |

After step 6 the script releases the enemy AI: the Tyrant and both Dire Rats are set to AI-controlled and the enemy turn manager is enabled. From here dice and AI are live.

**HP-threshold triggers.** The script listens to the Tyrant's damage events. Thresholds use integer division of max HP: 50% is 17 or less, 25% is 8 or less. Each fires once. The dialogue runs in a separate coroutine and does not pause combat. One hit can fire both in order. Lines are in section 2.

**End.** The script waits for the Tyrant's death event or the encounter end event, waits 1 s, plays the victory lines and the closing narration, and stops. It does not call `CompleteEncounter`, does not reload, and does not return to the title screen.

**Fail state.** Not built. If the party is wiped, the encounter end event sets the same flag as the Tyrant's death, so the victory lines play after a defeat.

**PDF version (designer intent).**
- Setup: about 12x12. Vast chamber with the sigil on the far wall. Two stone pillars mid-chamber. A three-tile-wide band of brackish sludge across the middle as difficult terrain.
- Sewer Tyrant: mini boss, Weakness 7 to acid, one hidden "??? Ability" slot, HP about 4 to 5 times a Sewer Rat, AC and saves a step above the adds, dead-centre behind the sludge band in front of the sigil.
- Two Dire Sewer Rats: level 0, about 2 times Sewer Rat HP, standard bite. One in front of each pillar, guarding the flanking lanes.
- Party at full HP from the post-Encounter 3 rest. Friend carries two fresh Acid Flasks.
- Initiative Player, Friend, Tyrant, both Dire Rats.
- 50% trigger and lines as built. 25% trigger fires on the last Dire Rat falling or Tyrant at 25%, whichever is first.
- Fail state: "If the entire party is reduced to 0 HP, the tutorial reloads the encounter from its opening state. A short post-mortem popup points the player at the tools they may not have leaned on: Recall Knowledge for Weakness, splash halo positioning, flanking discipline, Reactive Strike on enemies that Stride out of reach." (No popup text is written.)

**Rules taught (checklist).**

| Rule | PDF goal | Built |
|---|---|---|
| Open with Recall Knowledge on the main threat | (1) | Yes, scripted Critical Success |
| Difficult terrain costs extra movement | (2) | Popup 1 only. The script clears difficult terrain near the party. |
| Weakness, routed through bomb splash | (3) | Yes, popups 3, 5, 6 |
| Critical Success on RK reveals two facts | | Yes, popup 3 |
| Bomb splash hits the target and adjacent creatures | | Yes, popup 6 |
| Managing MAP on a durable target | (4) | Live play, no popup |
| Flanking lines for Sneak Attack | (5) | Live play, mentioned in popup 6 |
| Kill the adds to open flanking lanes | (6) | Live play, no popup |
| Read the hidden ability slot | (7) | No. The Tyrant has no creature features in data. |

---

## 4. Party (pregens)

Files: `Resources/Pregens/Pregen_TutorialPlayer.asset`, `Pregen_TutorialFriend.asset`. Both have `IsTutorialOnly = 1` and are level 1. The party is built by `RuntimeCharacterBuilder` from these pregens. Equipment is the class `DefaultWeapon`, `DefaultArmor`, `DefaultShield`.

Index decoding: `AbilityScore` enum is `0 Str, 1 Dex, 2 Con, 3 Int, 4 Wis, 5 Cha`. `Skill` enum is `0 Acrobatics, 1 Arcana, 2 Athletics, 3 Crafting, 4 Deception, 5 Diplomacy, 6 Intimidation, 7 Medicine, 8 Nature, 9 Occultism, 10 Performance, 11 Religion, 12 Society, 13 Stealth, 14 Survival, 15 Thievery`. Each boost adds 2 to a base 10; the class key ability gets one boost.

### The Player

| Field | Value |
|---|---|
| Display name | The Player |
| Description | A young fighter trained in the sewers. Confident, curious, shaped by his father's stories. |
| Portrait id | PlayerYoung (`Resources/Portraits/Human/PlayerYoung.png`) |
| Ancestry / heritage | Human (8 HP, Medium, 25 ft, Common) / Wintertouched Human (cold resistance half level, min 1) |
| Background | Guard (boost Str or Cha + free; trains Intimidation; Lore choice Legal or Warfare; grants Quick Coercion) |
| Class | Fighter (10 HP/level, key Str or Dex, default Str) |
| Ancestry boosts | Str, Cha |
| Background boosts | Str, Cha |
| Free boosts | Str, Con, Dex, Cha |
| Class key boost | Str |
| Ability scores | Str 18 (+4), Dex 12 (+1), Con 12 (+1), Int 10 (+0), Wis 10 (+0), Cha 16 (+3) |
| Max HP | 8 + 10 + 1 = 19 |
| Trained skills | Athletics (class), Intimidation (background), Warfare Lore (background choice), Medicine, Acrobatics, Survival (chosen) |
| Proficiencies (class) | Perception expert; Fort expert, Ref expert, Will trained; simple and martial weapons expert, advanced trained; unarmored, light, medium, heavy armor trained |
| Class features (L1) | Reactive Strike, Shield Block |
| Feats | Ancestry: General Training. Class: Sudden Charge. General (bonus): Intimidating Prowess. Background: Quick Coercion. |
| Weapon | Longsword: 1d8 slashing, versatile piercing, martial; trait Versatile |
| Armor | Scale Mail: +3 AC, Dex cap +2, check -2, speed -5, Str 2 |
| Shield | Steel Shield: +2 AC raised, Hardness 5, 20 HP |

Values derived from PF2e rules, not read from the running game: AC 17 (19 with shield raised), Longsword +9 to hit for 1d8+4, Fort +6, Ref +6, Will +3, Perception +5. Popup 5 in Encounter 1 states 25 ft Speed.

### The Friend

| Field | Value |
|---|---|
| Display name | The Friend |
| Description | A self-taught proto-alchemist. Cautious, witty, the brains of the duo. |
| Portrait id | FriendYoung (`Resources/Portraits/Human/FriendYoung.png`) |
| Ancestry / heritage | Human / Wintertouched Human |
| Background | Criminal (boost Dex or Int + free; trains Stealth; grants Underworld Lore and Experienced Smuggler) |
| Class | Alchemist (8 HP/level, key Int) |
| Ancestry boosts | Int, Dex |
| Background boosts | Dex, Int |
| Free boosts | Int, Dex, Wis, Con |
| Class key boost | Int |
| Ability scores | Str 10 (+0), Dex 16 (+3), Con 12 (+1), Int 18 (+4), Wis 12 (+1), Cha 10 (+0) |
| Max HP | 8 + 8 + 1 = 17 |
| Trained skills | Crafting (class), Stealth (background), Alchemy Lore (pregen lore choice), Medicine, Nature, Acrobatics, Arcana, Deception, Intimidation, Society (chosen, 3 + Int 4) |
| Proficiencies (class) | Perception trained; Fort expert, Ref expert, Will trained; unarmed and simple weapons trained; unarmored, light, medium armor trained; class DC trained |
| Feats | Ancestry: General Training. General (bonus): Incredible Initiative (+2 circumstance to initiative). Background: Experienced Smuggler. No class feat. |
| Bonus feature | Creature Sneak Attack 1d6: 1d6 extra precision damage to off-guard creatures |
| Primary action | Throw Acid Flask (1 action, 3 uses per encounter, splash 1) |
| Weapon | Dagger: 1d4 piercing, versatile slashing, simple; traits Agile, Finesse, Thrown, Versatile |
| Armor | Leather Armor: +1 AC, Dex cap +4, check -1 |
| Acid Flask item | "Acid Flask (Lesser)", level 1, 3 gp, 0 dice + 1 (flat 1 damage), range 20 ft. Description: "A flask of corrosive acid that deals acid damage and persistent acid damage on a hit, with acid splash damage to nearby creatures." Both the item `DamageType` and the action `SplashDamageType` are serialized as `6`, which is Fire in the `DamageType` enum. |

Data notes:
- Intimidating Prowess has level requirement 2 and needs expert Intimidation. The Player is level 1 and trained. The pregen grants it through `BonusGeneralFeat`.
- Criminal's granted lore is Underworld Lore. The pregen sets `BackgroundLoreChoice: Alchemy Lore`, which is not in Criminal's list.

Values derived from PF2e rules: AC 17, dagger +6 to hit for 1d4, Fort +6, Ref +8, Will +4, Perception +4.

`ThrowBombAction` behaviour: Critical Hit doubles direct damage, splash not doubled, splash on target and all within 5 ft. Hit: direct + splash to target and adjacent. Miss: splash to the target only. Critical Miss: nothing. Splash is flat and added to direct damage before resistance and weakness on the primary target. Persistent acid on hit is listed as not implemented in the code comments.

---

## 5. Enemy stat blocks

Files in `Resources/Bestiary/`. All three have trait Animal, faction Beast, action "Primary Strike", vision Low-Light, scent 30 ft, prefab `Prefabs/Enemies/Ironwolf Base.prefab`. Sizes use `CreatureSize` (`0 Tiny, 1 Small, 2 Medium`). Damage types use `DamageType` (`0 Bludgeoning, 1 Piercing, 2 Slashing, 3 Acid, 6 Fire, 11 Spirit, 18 Bleed`).

### Sewer Rat (`Sewer Rat.asset`, id `sewer_rat`)

Description: "A mangy rat the size of a small dog, thriving in the neglected tunnels beneath the city."

| Field | Value |
|---|---|
| Level | -1 |
| Size | Small |
| Speed | 30 ft, climb 10 ft |
| AC | 15 |
| Saves | Fort +6, Ref +7, Will +3 |
| HP | 8 (tutorial overrides: 18 in Encounter 1; 16 and 10 for Rats 1 and 2 in Encounter 3) |
| Attributes | Str +1, Dex +3, Con +2, Int -4, Wis +1, Cha -3 |
| Perception | +5 |
| Strike | Jaws +7, 1d6+1 piercing, agile, finesse |
| Skills | Acrobatics +5, Athletics +2, Stealth +5 |
| Weakness / resistance / immunity | none |
| Abilities | none |
| Portrait | `Art/Sprites/Enemies/Rat_v1/Rat_v1_Attack1_2.png` |
| Animator | `Animations/Enemies/Rats/RatV1.overrideController` |

### Dire Sewer Rat (`Dire Sewer Rat.asset`, id `dire_sewer_rat`)

Description: "A massive sewer rat, twice the size of its lesser kin. Its bite carries the filth of a century of neglect."

| Field | Value |
|---|---|
| Level | 0 |
| Size | Small |
| Speed | 30 ft, climb 10 ft |
| AC | 16 |
| Saves | Fort +5, Ref +5, Will +2 |
| HP | 16 |
| Attributes | Str +2, Dex +3, Con +2, Int -4, Wis +1, Cha -3 |
| Perception | +5 |
| Strike | Jaws +8, 1d8+2 piercing, finesse |
| Skills | Acrobatics +6, Stealth +6 |
| Weakness / resistance / immunity | none |
| Abilities | none |
| Portrait | none set |
| Animator | `Animations/Enemies/Rats/RatV3.overrideController` |

### Sewer Tyrant (`Sewer Tyrant.asset`, id `sewer_tyrant`)

Description: "A grotesquely mutated rat the size of a pony. Its hide splits and reforms as it moves, and it reeks of alchemical corruption."

| Field | Value |
|---|---|
| Level | 1 |
| Size | Medium (Large in the port, section 8) |
| Speed | 25 ft |
| AC | 17 |
| Saves | Fort +7, Ref +4, Will +3 |
| HP | 35 |
| Attributes | Str +3, Dex +1, Con +3, Int -4, Wis +1, Cha -2 |
| Perception | +6 |
| Strike | Jaws +9, 1d10+3 piercing, no traits |
| Skills | Athletics +7, Stealth +5 |
| Weakness | Value 3, type serialized as `0`, which is Bludgeoning in the `DamageType` enum. The popups, the script header and the PDF all say Acid 3. |
| Abilities | none (PDF wants one hidden "??? Ability" slot) |
| Portrait | `Art/Sprites/Enemies/Rat_v2/Rat_v2_Attack1_3.png` |
| Animator | `Animations/Enemies/Rats/RatV2.overrideController` |

### Vicious Bite (not used by any tutorial encounter)

The PDF gives Encounter 3's Rat 4 a hidden VICIOUS BITE (1d4 persistent bleed on Hit). In Unity it exists as:
- Feature `ScriptableObjects/Feats/Creature/Vicious Bite Bleed.asset`, display name "Vicious Bite", class `PersistentDamageStrikeRider`, strike index 0, 1d4, damage type `11` (Spirit in the current enum, not Bleed 18), empty description.
- Creature `Resources/Bestiary/Sewer Rat Vicious.asset` ("Vicious Sewer Rat", "A particularly aggressive sewer rat with a venomous bite that causes persistent bleeding."), the Sewer Rat block plus that feature, portrait `Art/Sprites/Enemies/Rat_v3/Rat_v3_Attack1_3.png`.

No tutorial script references it.

---

## 6. Systems the port needs

- Dialogue box with speaker name plate, portrait panel (hidden when no portrait), per-line portrait sprite, emotion tag, typewriter reveal (40 chars/s), click to skip reveal then advance.
- Narration lines: no speaker, no portrait, italic text.
- Narration over a full-screen black backdrop, with a 1.5 s fade-out to the map and a 0.5 s fade-in at encounter end.
- Tutorial popup: the same dialogue box with speaker "TUTORIAL", gold-highlighted words, a queue, and a blocking wait for dismissal.
- Command menu input restriction by label substring, with pulsing gold labels on allowed entries and all entries disabled while any dialogue shows.
- Movement restriction to a set of highlighted tiles, with a rejection popup and re-highlight on a wrong click. Flashing gold tile highlight.
- Action-spent detection that ignores cancelled actions.
- Forced degree of success for the next check by a given character, with matching d20 and damage die shown in the log.
- Scripted enemy moves (with and without provoking reactions) and scripted enemy Strikes.
- Fixed initiative order; enemy AI suppressed per creature and released mid-fight.
- Per-encounter HP overrides for creatures.
- Clearing hazards and difficult terrain from a box of tiles.
- Movement range display in two bands (one action, two actions).
- Hidden "???" creature fields on the target panel with reveal through Recall Knowledge: Name free on first success, then random facts (1 on Success, 2 on Critical Success), and a Creature Compendium entry.
- Recall Knowledge action under a Skills submenu.
- Treat Wounds between fights (PDF). The Unity build restores HP instead.
- Reaction system with a prompt: Reactive Strike when an enemy leaves reach, separate per-round Reaction.
- Multiple Attack Penalty display and stacking.
- Flanking and Off-Guard (-2 AC), and Sneak Attack (1d6 precision vs Off-Guard).
- Critical Hit doubling and a combat log that highlights the modifier that changed the outcome.
- Acid Flask: 1-action ranged bomb under an Abilities submenu, limited uses, splash to target and adjacent creatures with the miss and crit-miss rules above.
- Weakness and resistance by damage type.
- Persistent damage with end-of-turn tick and DC 15 recovery flat check (PDF Encounter 3).
- Difficult terrain (extra 5 ft per tile).
- HP-threshold mid-fight dialogue that does not pause combat, plus combat log narration lines.
- Fail-state reload of the encounter with a post-mortem popup (PDF).
- Encounter transition: save progress, fade to black, dialogue over black, reload the next encounter.
- Progress save per slot (highest completed encounter) and resume from the next encounter.
- Title screen "Prologue" slot: on press, find an empty save slot (else confirm "All save slots are full. Overwrite an existing save?" and pick a slot), create a slot of mode Tutorial named "Prologue", clear tutorial progress, show the loading screen "Starting tutorial...", load the tutorial scene. Loading an existing Prologue slot shows "Loading tutorial..." and resumes. Slot summary text is "Just started" or "Encounter N completed".
- Skip the results screen after tutorial fights.
- Script-only scenes 8 to 10 need: a map viewer, an Examine interaction on a wall symbol using the spectacles, a portal reveal, an exterior Meadows map, an NPC who fades out, and a cutscene camera hold.

---

## 7. Asset notes

**Dialogue portraits.** Each sheet is one PNG with named sub-sprites.

| Sheet | Sub-sprites used in tutorial dialogue | Sub-sprites not used |
|---|---|---|
| `Sprites/Portraits/PCs/Player/PlayerPlaceholder.png` | PlayerSmile, PlayerConcerned, PlayerGrin, PlayerBrave, PlayerDetermined | PlayerNeutral, PlayerSideye, PlayerPout, PlayerEyeroll, PlayerAngry, PlayerFurious, PlayerDoNotUse |
| `Sprites/Portraits/PCs/Friend/FriendPlaceholder.png` | FriendSmirk, FriendSmile, FriendAngry, FriendNervous | FriendLaugh, FriendCrying |

Character portraits for the party UI are separate: `Resources/Portraits/Human/PlayerYoung.png` and `FriendYoung.png`.

**Rat art.** Sprite folders `Art/Sprites/Enemies/Rat_v1`, `Rat_v2`, `Rat_v3` (76 frame PNGs each). Animator overrides and clips in `Animations/Enemies/Rats/`: `RatV1`, `RatV2`, `RatV3` each with Attack, Die, Hit, Idle, Walk. Mapping: Sewer Rat uses v1, Sewer Tyrant v2, Dire Sewer Rat v3.

**Sewer map art.** Theme `ScriptableObjects/Map Generation/SewerTheme.asset` uses PS1-style materials from `Materials/PS1Textures/`:

| Surface | Material |
|---|---|
| Grass (0) | RetroRock1, variants RetroRock2, RetroRock3, RetroRock4 |
| Dirt (1) | RetroDirt1, variant RetroDirt2 |
| Stone (2) | RetroRock1 |
| Wood (3) | RetroRocky1 top, RetroDirt2 wall |
| Water (4) | PSXOceanSurface top, RetroDirt2 wall |
| Mud (5) | RetroDirt7 |

Biome defaults: ground surface Stone, difficult surface Mud, cover Stone, wall Stone. Macro shapes, setpieces and debris patches are in `ScriptableObjects/Map Generation/MacroShapes`, `Setpieces`, `DebrisPatches`.

**Scripts referenced.**
- `Scripts/Tutorial/TutorialEncounterController.cs`, `TutorialCombatProvider.cs`, `TutorialInputRestriction.cs`, `TutorialProgressTracker.cs`, `TutorialEncounterActivator.cs`, `UI/TutorialPopupUI.cs`, `Encounters/TutorialEncounter1.cs` to `4.cs`
- `Scripts/GameFlow/TitleScreenUI.cs`, `GameFlowManager.cs` (`LoadTutorialCombat` loads scene "TutorialCombat"), `VictoryScreenUI.cs`, `CombatSceneCoordinator.cs`, `OutpostUI/DialogueBoxUI.cs`
- `Scripts/Integrations/PF2eActions/ThrowBombAction.cs`, `Scripts/Simulator/Bestiary/MonsterJournal.cs`, `Scripts/Persistence/SaveManager.cs`

## 8. Port decisions (Godot, 2026-10-18)

Target: new project `G:\Godot\Gamestorming\ungilded\`, Godot 4.6 C#, referencing `F:\dev\Pf2e.Core`, seeded from Delve's combat layer. First build stops after Encounter 4 and the Scene 7 victory lines. Scenes 8 to 10 are later work.

Where the Unity build and the PDF disagree, the PDF's encounter design wins and the Unity dialogue text wins:

- Encounter 2 plays the PDF version: two Recall Knowledge checks (Name, then AC), the rat's bite lands for about a quarter of the Player's HP, and Treat Wounds by the Friend happens between fights.
- Encounter 3 plays the PDF version: five Sewer Rats, three rounds, the Friend's Acid Flask with splash, the Critical Hit on a flanked rat, the Critical Miss at -5 MAP, Vicious Bite on Rat 4 as a hidden ability giving 1d4 persistent bleed, and the DC 15 recovery check.
- Encounter 4 keeps the live AI fight with the PDF's authored map: two pillars, a three-tile sludge band of difficult terrain, the Tyrant centred behind it, one Dire Sewer Rat before each pillar. The 25% lines fire when the Tyrant reaches 25% HP or the last Dire Rat falls. A party wipe reloads the encounter with the post-mortem popup.
- Maps are fixed layouts, not procedural, and each board comes with its halo (the walls, passages and channels around it). E1 (8x5) is a stretch of ribbed barrel tunnel: walkway, a channel sunk a quarter metre with a stone kerb, a ledge and wall beyond it, a pier every third tile with niches between, and the tunnel running on both ways. E2 (8x8) is a junction further along the same tunnel, with side passages north and south, a footbridge in the west tunnel and outfall pipes. E3 (10x10) is an octagonal junction cistern with two pillars, a passage in the middle of each side with drain grates at its mouth, and a drain sump that empties south under an arch. The skeleton lies in the narrow passage behind the party. E4 (12x12) is a long hall running east to west, with buttress piers and bays along both long walls, the sludge band leaving through arched culverts, a neck where the climbing entry passage comes in behind the party, and a stepped apse whose back wall carries the sigil. The camera cuts the walls on its side of the board down to a one-tile stub with darkness beyond. Pillars are 0.625 m tall and drop to a stub while a unit stands right behind one.
- Recall Knowledge reveals in a fixed order in the tutorial (Name, AC, then Weakness) by forcing the reveal, not by chance.
- The journal beat in Scene 6 plays as narration lines, as Unity does. A readable journal screen is later work.
- Tutorial popups were replaced by spotlight tips on 2026-10-20 (user). Each tip dims the screen, outlines the element it teaches (an action square, a command entry, a card row, tiles, units, the roll banner) and sits beside it with a pointer. A tip states why the step is needed and then the rule, with the numbers. Rule tips have a Continue button. Step tips ("Move next to the rat.") have none: they pass clicks only through the outlined area and close when the order is given. The wrong-tile hint is a step tip on the gold tiles that reads "Click a gold tile." Treat Wounds and the E4 post-mortem stay as centred boxes. The popup text in the section 3 tables is the Unity original, and the scripts in `ungilded/scripts/tutorial/encounters/` hold the current text.
- The narrative intro has 6 pages: "And yet... hope is a persistent weed." from line 4 is its own page (user, 2026-10-18). The words are unchanged.

Data fixes carried into the port:

- Sewer Tyrant weakness is Acid 7 (the PDF's 3 was raised to 10 on 2026-10-21, then lowered to 7 on 2026-10-22 because weakness applies to every persistent acid tick and 10 put the Tyrant near 25% HP in round 1). Acid Flask damage and splash are acid.
- Sewer Tyrant is Large (user, 2026-10-20): a 2x2 space with its low corner on tile (1, 5) of E4, which centres it on the board's rows. Jaws keeps 5 ft reach, as for a long creature. The Unity asset is Medium.
- Vicious Bite persistent damage is bleed.
- The Friend carries 2 Acid Flasks in Encounter 4 and 2 in Encounter 3.
- The Friend's lore is Alchemy Lore as authored, even though Criminal grants Underworld Lore.
- Intimidating Prowess has a level 2 prerequisite. If the engine rejects it at level 1, the Player takes a legal level 1 general feat instead and the substitution is reported.
- The dialogue box reads the Emotion field for the portrait. Where the Unity line's portrait sprite and Emotion disagree, Emotion wins.

### Tutorial pacing pass (user, 2026-10-22)

From a lens review (Flow 4/10, Feedback 5/10, Rules 5/10): the player made no free choice before Encounter 4, and several tips were wrong or carried two rules. Story findings are parked.

**Encounter 3 round 3 is guided, not scripted.**

- Both heroes' round 3 turns open with the full command menu, no target filter and no move lock. The flank tiles for the living rats show as gold hint tiles that do not lock movement (a hint mode beside the existing move restriction: gold tiles shown, every tile allowed, no wrong-tile tip).
- One step tip per hero at turn start, beside the command menu, no dim. Player, `e3_20_free`: "Two rats are still up. The gold tiles flank them." Friend, `e3_24_free`, shown only while a rat lives: "Finish the last rat. The gold tile flanks it."
- Forced rolls key to the committed order's target, not to the step. Every hero Strike in round 3 is forced to Hit. Damage dice: a Strike on Rat 4 rolls what kills it, a Player Strike on Rat 5 rolls 1 (leaves it low), a Friend Strike on Rat 5 rolls 2 and 3 (dagger plus Sneak Attack). The PDF table's outcome holds whatever order the player picks. `OnCommit` reads the order's target to choose the d20 and dice.
- A turn ends on End Turn or at 0 actions. Turns past round 3 run free, as today.
- Steps `e3_20` to `e3_26` are gone.

**End Turn is taught once.** `CombatScene.AutoEndTurn` is on from Encounter 2 on (off in Encounter 1, where `e1_07_end_turn` teaches it). A scripted turn that stops with actions left (the Friend's round 1 in Encounter 3, after flask and Stride) is ended by the script once the last action has played, with no tip. Removed: `e2_05`, `e3_05`, `e3_08`, `e3_14`, `e3_19`, `e3_23`, `e3_26`.

**Tip changes.** One rule per tip, PF2e terms, beside the element.

- `e3_07_flank` splits. Rule tip `e3_07_flanking` on the rat and both heroes: "Allies on opposite sides of an enemy flank it. A flanked enemy is off-guard to its flankers: -2 AC against their attacks." (gold: flank, off-guard). Then step tip `e3_07_flank` on the gold tile: "Stride to the gold tile to flank the rat."
- `e1_08_reaction`: "The Player has Reactive Strike: Strike an enemy that moves out of your reach. Use it on the fleeing rat." (gold: Reactive Strike). The reaction pip's hover reads "1 reaction per round. It comes back at the start of your turn."
- `e3_11_crit`: "Beating AC by 10 or more is a critical hit: double damage." The natural 20 or 1 sentence is cut.
- New `e3_12b_fumble` after the forced critical miss, on the roll banner: "A natural 1 drops the result one step: this miss is a critical miss." If the engine lands that fumble by margin rather than a natural 1, the text is "Missing AC by 10 or more is a critical miss."
- `e3_12_strike_map` step text: "The first rat is down. Strike the next one. The -5 MAP still applies."
- `e3_01_timeline` is cut. The timeline bar's hover reads "Turn order. Each hero takes their own turn with 3 actions."
- `e2_02_learned` is cut; the outlined row shows the reveal.
- `e3_06b_splash` keeps the numbers (what the flask hit and splashed) and drops the persistent damage sentence. Persistent damage is taught at `e3_15_bleed`. (Claude's call; the user asked for this tip on 2026-10-20.)
- `e4_05_unlocked` shows right after `e4_03_weak`, beside the command menu, text unchanged.

**Treat Wounds after Encounter 3.** The silent restore to full before Encounter 4 is gone. After Encounter 3's victory and before Scene 6, `TreatWoundsBeat` plays once per hero below full HP: the Friend treats the Player (`e3_27_treat_wounds`), then himself (`e3_28_treat_wounds`). `PrepareHeroes(4)` restores only a fallen or 0 HP hero.

**Checks.** `prologue_run`: step id lists updated; round 3 opens with the full menu; each forced round 3 Strike hits its committed target; no End Turn step tip shows after Encounter 1; the popup log has no `e3_01`, `e2_02` or removed end-turn ids; both heroes enter Encounter 4 at full or full-minus-1 HP through the beat, not through a restore.
