# Eidolarch card pool by school

Every card a deck can build from, one section per school, with batches 2 and 3 and the new Masteries folded in (marked `new`, not built yet, no id until it is). Rebuilt by `tools/gen_card_pool.py`. Ids are generic (`pyre_strike_07`) and never follow a title. Rules text of shipped cards is the engine's own wording (`tools/dump_cards.gd`); new cards use the review sheet's summary.

Counts leave out Masteries and signature cards and include gated cards. Rows are grouped by their first subtheme. Subthemes were tagged by a script reading the rules text and then checked by eye, so a tag can be a near miss.

## At a glance

| School | Cards | New | Strike | Art | Combat | Non-Combat | Drill |
|---|---|---|---|---|---|---|---|
| Pyre | 50 | 0 | 28 | 11 | 3 | 0 | 8 |
| Steel | 50 | 0 | 28 | 14 | 2 | 2 | 4 |
| Tide | 50 | 0 | 21 | 15 | 4 | 3 | 7 |
| Storm | 50 | 7 | 14 | 24 | 2 | 2 | 8 |
| Shade | 50 | 0 | 23 | 13 | 5 | 2 | 7 |
| Root | 50 | 0 | 19 | 12 | 8 | 5 | 6 |
| Freestyle | 63 | 0 | 7 | 11 | 20 | 18 | 7 |

Not listed below: 7 Grounds, 62 Personality, 4 Relic, 28 Seal.

## Pyre (fire): 50 cards

Subthemes: Fervor as a number 4, Drills 9, Ash 4, Burning the board 5, Pyre Arts 9, Art answers 6, Climbing blocks 5, Fervor attacks 15.

Masteries:

- **Pyre Crucible Mastery** (`pyre_mastery_01`): When you perform an attack, if the attack is Pyre and the attack is not Focused, you may take a wound. If you do, this attack is Focused. After you stop an attack with a Pyre card that does not remove itself from the game, place it on the bottom of your Life Deck. Limit 1 per deck.
- **Pyre Ember Mastery** (`pyre_mastery_02`): Use in Combat: Remove the top card of your discard pile from the game. If it is a Pyre card, raise your Fervor 2. Otherwise, raise your Fervor 1. Once per Combat. Limit 1 per deck.
- **Pyre Tinder Mastery** (`pyre_mastery_03`): When entering Combat, if your discard pile has a card, you may remove the top card of your discard pile from the game. If it is a Pyre card, for the remainder of Combat, your Strikes do +3 Energy. Otherwise, for the remainder of Combat, your Strikes do +1 Energy. Limit 1 per deck.
- **Pyre Cinder Mastery** (`pyre_mastery_04`): When you perform an attack, if the attack is an Art, lower your opponent's Fervor 1. When your opponent stops your attack, if the attack is an Art and the attack is Pyre, your opponent takes 2 wounds. Limit 1 per deck.

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Pyre Blazing Hide | Strike | Endurance X. X = your Fervor. Strike doing +3 Energy. For the remainder of Combat, any Hit effect of yours that raises your Fervor or lowers your opponent's Fervor is a secondary effect, and happens whether or not the attack succeeds. | Fervor as a number |  | `pyre_strike_22` |
| Pyre Choking Smoke | Strike | Endurance X. X = your Fervor. Stops an Art. Lower your opponent's Fervor 1. If your opponent's Fervor is 1 or lower, remove the bottom 10 cards of your opponent's discard pile from the game. | Fervor as a number, Ash, Art answers |  | `pyre_strike_23` |
| Pyre Drawing Flue | Art | Endurance 4. Art dealing a wound, plus wounds equal to your Fervor. Hit: Shuffle this card into your Life Deck. | Fervor as a number |  | `pyre_art_04` |
| Pyre Rising Heat Drill | Drill | Your attacks do +X Energy, X = your Fervor. Limit 1 per deck. | Fervor as a number |  | `pyre_drill_01` |
| Pyre Bonfire | Strike | Strike. Empower 4. Search your Life Deck for up to 5 Pyre Drills and put them into play. Raise your Fervor 1. Remove from the game after use. | Drills |  | `pyre_strike_24` |
| Pyre Laying Fire | Strike | Endurance 2. Strike doing +3 Energy. Hit: Search your Life Deck for a Pyre Drill and put it into play. | Drills |  | `pyre_strike_25` |
| Pyre Banked Coals Drill | Drill | Your Fervor cannot be lowered. | Drills |  | `pyre_drill_02` |
| Pyre Burnt Offering Drill | Drill | Use this card only if you have a card in hand. Stops a Strike or an Art. Discard your whole hand. | Drills |  | `pyre_drill_03` |
| Pyre Cinder Sift Drill | Drill | After a successful attack, if the attack is a Strike and your discard pile has a card, you may choose a card from your discard pile and shuffle it into your Life Deck. Once per Combat. | Drills |  | `pyre_drill_04` |
| Pyre Flame Screen Drill | Drill | Defense Shield: stops the first unstopped Art each Combat. | Drills, Art answers |  | `pyre_drill_05` |
| Pyre Hearthstone Drill | Drill | When your duelist advances an Aspect, your other Drills are not discarded. If your opponent's Fervor is 0, this Drill is not discarded either. | Drills |  | `pyre_drill_06` |
| Pyre Kiln Drill | Drill | Your Arts do +2 wounds. | Drills, Pyre Arts |  | `pyre_drill_07` |
| Pyre Smoldering Drill | Drill | At the start of your turn, remove the bottom 3 cards of your opponent's discard pile from the game. Your attacks do +2 Energy. This Drill does not count towards or against the one school of Drills you may have in play. | Drills, Ash |  | `pyre_drill_08` |
| Pyre Ashen Veil | Strike | Stops a Strike. Remove the top 10 cards of your opponent's discard pile from the game. Raise your Fervor 1. | Ash, Climbing blocks |  | `pyre_strike_15` |
| Pyre Cremation | Strike | Strike. Hit: Remove all of your opponent's discard pile from the game. | Ash |  | `pyre_strike_26` |
| Pyre Firestorm | Strike | Strike. Hit, instead of dealing damage, you may choose one: your opponent discards all Allies in play or your opponent discards all Drills in play. Raise your Fervor 1. | Burning the board |  | `pyre_strike_06` |
| Pyre Scouring Flame | Strike | Strike. Hit: Remove a Non-Combat card in play from the game. Raise your Fervor 1. | Burning the board |  | `pyre_strike_05` |
| Pyre Ashfall | Art | Art dealing 3 wounds. Empower 3. Your opponent removes a Drill or Ally in play of your choice from the game. Lower your opponent's Fervor 2. | Burning the board, Pyre Arts |  | `pyre_art_02` |
| Pyre Immolation | Art | Art. Your opponent removes a Drill or Ally in play of your choice from the game. Raise your Fervor 1. | Burning the board |  | `pyre_art_01` |
| Pyre Conflagration | Combat | Your duelist pays 5 Energy to use this card. All Non-Combat cards and Allies in play are discarded. Set your duelist's Energy to 0. Raise your Fervor 1. Limit 1 per deck. | Burning the board |  | `pyre_combat_02` |
| Pyre Flare Volley | Art | Endurance 2. Art dealing 2 wounds. You may discard a card from your hand as you perform it to add 3 wounds. Remain 2. Remove from the game after use. | Pyre Arts |  | `pyre_art_06` |
| Pyre Phoenix Flame | Art | Art dealing 5 wounds. Hit: Choose 5 Pyre cards from your discard pile and shuffle them into your Life Deck. Remove from the game after use. | Pyre Arts |  | `pyre_art_07` |
| Pyre Struck Spark | Art | Art dealing 3 wounds. Costs 1 Energy to perform. Raise your Fervor 1. | Pyre Arts |  | `pyre_art_08` |
| Pyre Sudden Flare | Art | Focused Art dealing 3 wounds. Hit: Raise your Fervor 2. | Pyre Arts |  | `pyre_art_09` |
| Pyre Unmaking Blaze | Art | Art dealing 6 wounds. Hit, instead of dealing damage, you may have your opponent lose one Aspect. Remove from the game after use. | Pyre Arts |  | `pyre_art_10` |
| Pyre White Flame | Art | Endurance 2. Art dealing 6 wounds. Wounds from it are removed from the game instead of discarded. Draw the bottom card of your Life Deck. Remove from the game after use. | Pyre Arts |  | `pyre_art_11` |
| Pyre Stoked Blaze | Combat | For the remainder of Combat, your Arts cost 1 less Energy to perform, to a minimum of 1. For the remainder of Combat, your Arts do +2 wounds. Lower your opponent's Fervor 1. | Pyre Arts |  | `pyre_combat_03` |
| Pyre Backdraft | Strike | Strike doing +3 Energy. Stops all Arts, yours as well as your opponent's, for the remainder of Combat. Lower your opponent's Fervor 1. | Art answers |  | `pyre_strike_03` |
| Pyre Ember Ward | Strike | Endurance 2. Stops an Art. Raise your Fervor 1. | Art answers |  | `pyre_strike_20` |
| Pyre Heat Haze | Strike | Stops an Art. If your Fervor is 1 or higher, stops all Arts performed against you for the remainder of Combat. Remove from the game after use. Limit 1 per deck. | Art answers |  | `pyre_strike_27` |
| Pyre Hearthguard | Art | Stops an Art. Raise any one personality's Energy to full. Remove from the game after use. | Art answers |  | `pyre_art_03` |
| Pyre Backfire | Strike | Stops a Strike. Your opponent takes 3 wounds. Remove from the game after use. | Climbing blocks |  | `pyre_strike_28` |
| Pyre Bellows Guard | Strike | Stops a Strike. Gain 5 Energy. Raise your Fervor 1. | Climbing blocks |  | `pyre_strike_14` |
| Pyre Cinder Guard | Strike | Stops a Strike. Raise your Fervor 2. Gain 2 Energy. | Climbing blocks |  | `pyre_strike_01` |
| Pyre Searing Guard | Strike | Endurance 1. Stops a Strike. Your opponent takes a wound. Raise your Fervor 1. Gain 5 Energy. | Climbing blocks |  | `pyre_strike_02` |
| Pyre Blazing Charge | Strike | Strike doing +3 Energy. Cannot be stopped or prevented by Strike cards. Raise your Fervor 1. Remove from the game after use. | Fervor attacks |  | `pyre_strike_07` |
| Pyre Burning Sword Cleave | Strike | Endurance 2. Strike doing +4 Energy. For the remainder of Combat, the Pyre attacks you perform from your hand count as having "Sword" in the title. Raise your Fervor 1. Lower your opponent's Fervor 1. | Fervor attacks |  | `pyre_strike_21` |
| Pyre Comet Fall | Strike | Strike doing +4 Energy. Remain 1. Remove from the game after use. | Fervor attacks |  | `pyre_strike_04` |
| Pyre Ember Strike | Strike | Strike doing +3 Energy. Raise your Fervor 1. | Fervor attacks |  | `pyre_strike_18` |
| Pyre Flame Lash | Strike | Endurance 2. Strike doing +4 Energy. Raise your Fervor 1. Empower 2. If stopped, look at the bottom 5 cards of your Life Deck. You may put a Strike card from among them into your hand. Put the rest on the top of your Life Deck in any order. | Fervor attacks |  | `pyre_strike_11` |
| Pyre Flashover | Strike | Strike doing +3 Energy. If your opponent used a Combat card this Combat, Remain 2. Remove from the game after use. | Fervor attacks |  | `pyre_strike_10` |
| Pyre Flashpoint | Strike | Strike doing +3 Energy. Costs 4 Energy to perform. Raise your Fervor 2. | Fervor attacks |  | `pyre_strike_16` |
| Pyre Furnace Breath | Strike | Strike doing +4 Energy. Raise your Fervor 2. Remove from the game after use. | Fervor attacks |  | `pyre_strike_08` |
| Pyre Kindling | Strike | Strike doing +3 wounds. Raise your Fervor 1. For the remainder of Combat, your other Pyre attacks are Focused. | Fervor attacks |  | `pyre_strike_12` |
| Pyre Rekindling | Strike | Strike doing +6 Energy. Raise your Fervor 1. Choose a Pyre attack card other than "Pyre Rekindling" from your discard pile and put it into your hand. Remove from the game after use. | Fervor attacks |  | `pyre_strike_13` |
| Pyre Scorching Blow | Strike | Strike doing +4 Energy. Raise your Fervor 1. | Fervor attacks |  | `pyre_strike_19` |
| Pyre Snuffing | Strike | Strike doing +3 Energy. If your opponent's Fervor is 0, damage cannot be prevented and raise your Fervor 1. Your opponent may not use Powers for the remainder of Combat. | Fervor attacks |  | `pyre_strike_09` |
| Pyre Updraft | Strike | Strike doing +3 Energy. Raise your Fervor 1. | Fervor attacks |  | `pyre_strike_17` |
| Pyre Burned Through | Art | Art dealing 5 wounds. For the remainder of Combat, your opponent cannot use Endurance against your Pyre attacks. Hit: Raise your Fervor 2. | Fervor attacks |  | `pyre_art_05` |
| Pyre Twin Flames | Combat | Strike. Raise your Fervor 1. Remain 1. | Fervor attacks |  | `pyre_combat_01` |

## Steel (Draconic manifestation; needs a Draconic Duelist): 50 cards

Subthemes: Might comparison 9, Endurance armour 9, Energy squeeze 8, Empower 10, Raw Strikes 18.

Masteries:

- **Steel Hoard Mastery** (`steel_mastery_01`): Draconic duelists only. When entering Combat, discard the top card of your Life Deck. If it is a Steel card, draw 2 cards. Otherwise, draw a card. Limit 1 per deck.
- **Steel Dragonfear Mastery** (`steel_mastery_02`): Draconic duelists only. When entering Combat, draw a card. If it is a Steel card, you may show it to your opponent. If you do, your opponent loses 4 Energy. Limit 1 per deck.
- **Steel Scale Mastery** (`steel_mastery_03`): Draconic duelists only. When entering Combat, draw a card. If it is a Steel card, you may show it to your opponent. If you do, prevent 4 Energy and 4 wounds of damage from the first attack performed against you this Combat. If you do not, prevent 4 Energy of damage from the first attack performed against you this Combat. Otherwise, prevent 4 Energy of damage from the first attack performed against you this Combat. Limit 1 per deck.
- **Steel Bloodrage Mastery** (`steel_mastery_04`): Draconic duelists only. You cannot win by Ascension. Your Steel attacks gain "Raise your Fervor 1. Gain 3 Energy." In the Recover step, if the card you put back into your Life Deck is a Steel card, raise your Fervor 2. Gain 4 Energy. Limit 1 per deck.

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Steel Dragonblood Charge | Strike | Strike dealing 7 Energy. If your duelist's Might is higher, your opponent may not use a Mastery this turn and your opponent may not use a Relic this turn. | Might comparison |  | `steel_strike_12` |
| Steel Dragonweight Blow | Strike | Strike doing +3 Energy. If your duelist's Might is higher, your opponent discards a Non-Combat card in play of your choice. | Might comparison |  | `steel_strike_15` |
| Steel Towering Charge | Strike | Strike doing +4 Energy. If your duelist's Might is higher, your opponent discards up to 2 Allies in play of your choice. | Might comparison |  | `steel_strike_28` |
| Steel Towering Frame | Strike | Strike doing +3 Energy. If the personality performing this has a higher Might than the one defending, double the Strike Table result. | Might comparison |  | `steel_strike_24` |
| Steel Unyielding Scales | Strike | If your duelist's Might is higher than your opponent's duelist's, stops a Strike. Stays on the table to be used any number of times this Combat. Remove from the game after use. Limit 1 per deck. | Might comparison |  | `steel_strike_02` |
| Steel Boiling Blood | Art | Art dealing 6 wounds. If your duelist's Might is higher than your opponent's duelist's, focused. For the remainder of Combat, whenever you use Endurance, your duelist gains 1 Energy. | Might comparison, Endurance armour |  | `steel_art_07` |
| Steel Dragonfire Breath | Art | Art. If your duelist's Might is higher, raise your Fervor 1 and for the remainder of Combat, your other attacks do +2 wounds. | Might comparison |  | `steel_art_09` |
| Steel Drawn Breath | Combat | Use when performing an attack. Raise your duelist's Energy to full. Your next attack does +X Energy, X = the Energy this gained you, to a maximum of +5. Remove from the game after use. | Might comparison |  | `steel_combat_02` |
| Steel Blood Memory | Non-Combat | Use in Combat: Raise your Fervor 2. Place the bottom 2 cards of your discard pile at the bottom of your Life Deck. If your duelist's Might is higher than your opponent's duelist's, draw a card. Remove from the game after use. | Might comparison |  | `steel_noncombat_01` |
| Steel Hoarding Claw | Strike | Endurance 2. Strike doing +3 Energy. Lower your opponent's Fervor 1. Hit: Search your Life Deck for a Seal and put it into play. Remove from the game after use. | Endurance armour |  | `steel_strike_05` |
| Steel Scalebound Blow | Strike | Endurance 4. Strike doing +3 Energy and +2 wounds. | Endurance armour |  | `steel_strike_14` |
| Steel Taloned Fist | Strike | Endurance 3. Strike doing +4 Energy. | Endurance armour |  | `steel_strike_13` |
| Steel Thrashing Tail | Strike | Endurance 2. Strike. If stopped, remove a Drill in play from the game. Remove from the game after use. | Endurance armour |  | `steel_strike_23` |
| Steel Cornered Blood | Art | Endurance 4. Art dealing 5 wounds. For the remainder of Combat, your Steel attacks that have Empower are Focused. Raise your Fervor 1. | Endurance armour, Empower |  | `steel_art_13` |
| Steel Shed Skin | Art | Endurance 2. Strike doing +4 Energy. Choose 3 Steel cards from your discard pile and shuffle them into your Life Deck. Remove from the game after use. | Endurance armour |  | `steel_art_03` |
| Steel Hardscale Drill | Drill | Defense Shield: stops the first unstopped Strike each Combat. | Endurance armour |  | `steel_drill_04` |
| Steel Constricting Grip | Strike | Focused Strike doing +3 Energy. Search your Life Deck for a Steel Drill and put it into play. Hit: Until the end of their next turn, your opponent's duelist's Surge Rate is 0 and cannot be changed by other effects. | Energy squeeze |  | `steel_strike_27` |
| Steel Fanged Snap | Strike | Strike doing +3 Energy. Hit: Your opponent pays 2 more Energy for their next attack this Combat. | Energy squeeze |  | `steel_strike_09` |
| Steel Pinning Claw | Strike | Strike doing +3 Energy. Empower 2. Until the end of your next turn, your opponent's duelist and Allies cannot gain Energy. Remove from the game after use. | Energy squeeze, Empower |  | `steel_strike_08` |
| Steel Scaled Forearm | Strike | Stops a Strike. Your opponent's duelist loses 3 Energy. | Energy squeeze |  | `steel_strike_04` |
| Steel Serpentine Twist | Strike | Stops a Strike. Your opponent loses 4 Energy. | Energy squeeze |  | `steel_strike_19` |
| Steel Swallowed Flame | Art | Stops an Art. If the bottom card of your discard pile is Steel, your opponent's duelist loses 4 Energy. | Energy squeeze |  | `steel_art_05` |
| Steel Baleful Gaze Drill | Drill | Your opponent's attacks cost 1 more Energy to perform. If your opponent's deck is Root, your opponent's attacks cost 2 more Energy to perform instead. | Energy squeeze |  | `steel_drill_02` |
| Steel Stifling Presence Drill | Drill | Your attacks do +2 Energy. Your opponent's personalities gain 1 less Energy when they power up in the Power Up step, to a minimum of 0. This Drill does not count towards or against the one school of Drills you may have in play. | Energy squeeze |  | `steel_drill_03` |
| Steel Blood Unbound | Strike | (When you perform a Strike, you may discard this card from your hand to have that attack do +4 Energy and raise your Fervor 1.) Strike doing +3 Energy. Empower 2. For the remainder of Combat, when you use Empower you still use all of the card's text after Empower. | Empower |  | `steel_strike_26` |
| Steel Shedding Scales | Strike | Endurance 1. Strike doing +3 Energy. Raise your Fervor 1. Empower 2. For the remainder of Combat, your Strikes do +X Energy, X = the times you have used Endurance since this card was played. | Empower, Endurance armour |  | `steel_strike_25` |
| Steel Awakened Blood | Art | Art dealing 5 wounds. Empower 2. Search your Life Deck for a Steel Drill that adds damage to your attacks and put it into play. Lower your opponent's Fervor 2. | Empower |  | `steel_art_14` |
| Steel Deafening Roar | Art | Draconic only. Art. Empower 3. Your opponent may not use a Mastery or use Drills for the remainder of Combat. Remove from the game after use. | Empower |  | `steel_art_02` |
| Steel Reclaimed Hoard | Art | Draconic only. Art dealing 3 wounds. Empower 4. Choose 2 Steel cards other than "Steel Reclaimed Hoard" from your discard pile and place them on top of your Life Deck. Remove from the game after use. | Empower |  | `steel_art_10` |
| Steel Routing Roar | Art | Draconic only. Art. Empower 3. Your opponent discards up to 3 Allies in play of your choice. Remove from the game after use. | Empower |  | `steel_art_12` |
| Steel Scorching Breath | Art | Art. Raise your Fervor 1. Empower 4. For the remainder of Combat, wounds from your attacks are removed from the game. For the remainder of Combat, damage from your attacks cannot be prevented. | Empower |  | `steel_art_08` |
| Steel Tail Sweep | Art | Draconic only. Art dealing 3 wounds. Empower 4. Your opponent discards up to 3 Drills in play of your choice. Remove from the game after use. | Empower |  | `steel_art_11` |
| Steel Clawed Heel | Strike | Strike doing +4 Energy. You may discard the top card of your Life Deck to add 3 wounds. | Raw Strikes |  | `steel_strike_20` |
| Steel Clawed Pounce | Strike | Strike doing +3 Energy. You may discard the top card of your Life Deck to add 3 Energy of damage. | Raw Strikes |  | `steel_strike_22` |
| Steel Horn Gore | Strike | Strike. Hit: Your opponent discards up to 2 Non-Combat cards and Allies in play of your choice. | Raw Strikes |  | `steel_strike_11` |
| Steel Horned Charge | Strike | Strike doing +8 Energy. Raise your Fervor 1. | Raw Strikes |  | `steel_strike_06` |
| Steel Ironscale Hide | Strike | Stops a Strike or an Art. Gain 7 Energy. | Raw Strikes |  | `steel_strike_03` |
| Steel Lashing Tail | Strike | Strike doing +4 wounds. Hit: Raise your Fervor 1. | Raw Strikes |  | `steel_strike_21` |
| Steel Locking Jaws | Strike | Reserve only. Strike doing +3 wounds. Damage cannot be prevented. Draw a card. Raise your Fervor 1. | Raw Strikes |  | `steel_strike_01` |
| Steel Raking Talons | Strike | Draconic only. Strike doing +5 Energy. | Raw Strikes |  | `steel_strike_17` |
| Steel Recoiling Lunge | Strike | Focused Strike doing +5 Energy. For the remainder of Combat, Steel attacks you use go to the bottom of your Life Deck instead. | Raw Strikes |  | `steel_strike_10` |
| Steel Rending Talon | Strike | Draconic only. Strike doing +5 Energy. Hit: Your opponent takes 2 wounds. | Raw Strikes |  | `steel_strike_18` |
| Steel Talon Cleave | Strike | Strike dealing 10 Energy. Remove from the game after use. | Raw Strikes |  | `steel_strike_16` |
| Steel Twin Claws | Strike | Strike doing +3 Energy. Remain 1. Remove from the game after use. | Raw Strikes |  | `steel_strike_07` |
| Steel Dragonscale Mantle | Art | Draconic only. Stops an Art. Stops all Arts performed against you for the remainder of Combat. | Raw Strikes |  | `steel_art_06` |
| Steel Raised Scales | Art | Stops a Strike or an Art. Raise your Fervor 1. Search your Life Deck for a "Steel Kindred Standoff" card and put it into your hand. Remove from the game after use. | Raw Strikes |  | `steel_art_01` |
| Steel Searing Breath | Art | Focused Art dealing 3 wounds. Hit: Draw a card. | Raw Strikes |  | `steel_art_04` |
| Steel Kindred Standoff | Combat | End Combat. The turn ends. Remove from the game after use. | Raw Strikes |  | `steel_combat_01` |
| Steel Bared Fangs | Non-Combat | Use in Combat: Lose 4 Energy. For the remainder of Combat, your attacks do +3 wounds. | Raw Strikes |  | `steel_noncombat_02` |
| Steel Clawed Hands Drill | Drill | Your Strikes do +2 Energy. | Raw Strikes |  | `steel_drill_01` |

## Tide (water): 50 cards

Subthemes: Drowning 7, Allies 10, Guard 13, Digging 8, Board strip 4, Tide attacks 14.

Fervor denial is a trait here, not a subtheme: 18 cards carry it as a rider. It stops a climb; Drowning is what turns low Fervor into a win.

Masteries:

- **Tide Undertow Mastery** (`tide_mastery_01`): After a successful attack, if the attack is Tide, lower your opponent's Fervor 1. Your opponent needs 6 Fervor to rise an aspect. Limit 1 per deck.
- **Tide Fathom Mastery** (`tide_mastery_02`): Your Tide Strikes do +2 wounds. Instead of defending, you may remove any number of Tide cards in your discard pile from the game. Prevent 2 wounds from the attack for each one removed. Limit 1 per deck.
- **Tide Eddy Mastery** (`tide_mastery_03`): Discard a card from your hand to stop a Strike or an Art. If the top card of your discard pile is Tide, lower your opponent's Fervor 2. Once per Combat. Limit 1 per deck.
- **Tide Floodtide Mastery** (`tide_mastery_04`): Your Arts do +1 wound. Your Tide Arts gain "Hit: Raise your Fervor 1." Limit 1 per deck.

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Tide Dead Calm | Strike | Strike doing +2 Energy. Costs 2 Energy to perform. Hit: Your opponent takes X wounds, X = 5 minus their Fervor. | Drowning |  | `tide_strike_18` |
| Tide Frozen Over | Strike | Strike doing +2 Energy. Set your opponent's Fervor to 0. Your opponent cannot gain Fervor until the beginning of their next turn. | Drowning |  | `tide_strike_15` |
| Tide Pounding Surf | Strike | Endurance 3. Strike doing +3 Energy. Raise your Fervor 1. Hit: For the remainder of Combat, your Strikes that use the Strike Table have a Base Damage of X. X = 4 minus your opponent's Fervor. | Drowning |  | `tide_strike_20` |
| Tide Sinking Blow | Strike | Strike dealing a wound. Hit: If the top card of your opponent's discard pile is not a Strike card, your opponent takes 5 wounds. | Drowning |  | `tide_strike_21` |
| Tide Leeching Brine | Art | Art. Hit: Attach this card to your opponent's duelist. At the start of your opponent's turn, your opponent takes 2 wounds. Discard this card when the personality it is attached to is at full Energy. | Drowning |  | `tide_art_15` |
| Tide Riptide | Non-Combat | Use in Combat: Set your opponent's Fervor to 0. Your opponent loses one Aspect. Remove from the game after use. | Drowning |  | `tide_noncombat_03` |
| Tide Salt Burn Drill | Drill | Your attacks do +2 Energy. When you lower your opponent's Fervor while it is 0, they discard the top card of their Life Deck for each point lowered. This Drill does not count towards or against the one school of Drills you may have in play. | Drowning |  | `tide_drill_03` |
| Tide Drowning | Strike | Strike. Your opponent removes a Non-Combat card or Ally in play of your choice from the game. | Allies, Board strip |  | `tide_strike_03` |
| Tide Pull Under | Strike | Strike. Hit: Discard a Non-Combat card or Ally in play. If Moth Seal 3 or Moth Seal 4 is in play, Remain X, where X is your duelist's Aspect. Remove from the game after use. | Allies |  | `tide_strike_04` |
| Tide Confluence | Art | Art dealing 5 wounds. Empower 3. If performed by an Ally, focused. If you have an Ally in play, your opponent discards a Drill in play of your choice. | Allies, Board strip |  | `tide_art_08` |
| Tide Springwater | Art | Art. You may search your discard pile for an aspect 1 Ally and put it into play at Energy 3. Hit: Raise its Energy to full. Remove from the game after use. | Allies, Digging |  | `tide_art_05` |
| Tide Twin Breaker | Art | Art dealing 5 wounds. If Sir Edric Rooke is in play, +4 wounds and Focused. Lower your opponent's Fervor 2. Raise your Fervor 1. If this card is discarded from your Life Deck, at the start of the next fight-back phase this turn, you may search your Life Deck for an Ally and put it into play. | Allies |  | `tide_art_09` |
| Tide Washout | Combat | Endurance 1. Remove a Drill in play from the game. Your duelist and each of your Allies gain 2 Energy. Raise your Fervor 1. Remove from the game after use. | Allies |  | `tide_combat_02` |
| Tide Answering Current | Non-Combat | Use in Combat: Search your Life Deck for an Ally and put it into play at Energy 3. Choose an Ally from your discard pile and put it into play at Energy 3. Remove from the game after use. | Allies, Digging |  | `tide_noncombat_02` |
| Tide Following Current Drill | Drill | If performed by an Ally, your attacks do +2 Energy. | Allies |  | `tide_drill_04` |
| Tide Mooring Drill | Drill | Your Allies in play cannot be discarded. Limit 1 per deck. | Allies |  | `tide_drill_02` |
| Tide Shoal Drill | Drill | After a successful attack, if the attack is a Strike, search your Life Deck for an aspect 1 Ally and put it into your hand. | Allies |  | `tide_drill_01` |
| Tide Deep Guard | Strike | Stops an Art. Lower your opponent's Fervor 2. | Guard |  | `tide_strike_11` |
| Tide Ebb | Strike | Stops a Strike. Your duelist loses any amount of Energy. For each Energy lost, lower your opponent's Fervor 1. | Guard |  | `tide_strike_01` |
| Tide Flotsam | Strike | Endurance 3. Stops an Art. Raise your Fervor 1. Choose 2 Non-Combat cards and Drills from your discard pile and place them on top of your Life Deck. Remove from the game after use. | Guard, Digging |  | `tide_strike_19` |
| Tide Sounding | Strike | Stops a Strike. Show the top 3 cards of your Life Deck to both players. Your opponent chooses 1 of them and it goes into your hand. Put the others back on top in any order. If your duelist is aspect 3 or higher, you choose instead. | Guard |  | `tide_strike_17` |
| Tide Sweep Aside | Strike | Stops a Strike. Lower your opponent's Fervor 1. | Guard |  | `tide_strike_13` |
| Tide Undersweep | Strike | Strike doing +2 Energy. The next Strike performed against you during your opponent's next attack phase is stopped. Lower your opponent's Fervor 1. | Guard |  | `tide_strike_12` |
| Tide Waterlogged | Strike | Strike. Hit: Stops all Strikes performed against you for the remainder of Combat. Lower your opponent's Fervor 1. Remove from the game after use. | Guard |  | `tide_strike_08` |
| Tide Wide Sweep | Strike | Strike doing +5 Energy. Stops an Art. Lower your opponent's Fervor 1. | Guard |  | `tide_strike_02` |
| Tide Backwash | Art | Focused Art dealing 5 wounds. Stops an Art. Choose a card for each point of your Fervor from your discard pile and shuffle them into your Life Deck. If every card taken is a Non-Combat card or Drill, gain 3 Energy. Remove from the game after use. | Guard, Digging |  | `tide_art_13` |
| Tide Breakwater | Art | Stops an Art. For the remainder of Combat, Arts against you deal no wounds. Remove from the game after use. Limit 1 per deck. | Guard |  | `tide_art_01` |
| Tide Surge | Art | Art dealing 5 wounds. Stops a Strike. | Guard |  | `tide_art_02` |
| Tide Parting Waters | Combat | Endurance X. X = your Fervor. Stops a Strike or an Art. Remove from the game after use. If your duelist is aspect 3 or higher, discard it after use instead. | Guard |  | `tide_combat_04` |
| Tide Seawall Drill | Drill | Defense Shield: stops the first unstopped Strike each Combat. | Guard |  | `tide_drill_05` |
| Tide Dredge | Strike | Endurance 2. Strike doing +5 Energy. Look at the top 5 cards of your Life Deck. You may put a Non-Combat card or Drill from among them into play. Put the rest on the bottom of your Life Deck in any order. | Digging |  | `tide_strike_07` |
| Tide Depths | Art | Art dealing 3 wounds. Search your Life Deck for a card and put it into your hand. Remove from the game after use. | Digging |  | `tide_art_06` |
| Tide High Water | Art | Art dealing 5 wounds. Raise your Fervor 1. Hit: Search your Life Deck for a Grounds card and put it into play. | Digging |  | `tide_art_07` |
| Tide Returning Tide | Combat | Lower your opponent's Fervor 2. Place the top 3 cards of your discard pile at the bottom of your Life Deck. | Digging |  | `tide_combat_03` |
| Tide Erosion | Non-Combat | Use in Combat: Your opponent discards a Drill in play of your choice. | Board strip |  | `tide_noncombat_04` |
| Tide Narrow Channel Drill | Drill | Your opponent may place only 1 Non-Combat card in play during their turn. | Board strip |  | `tide_drill_06` |
| Tide Breaking Sea | Strike | Strike doing +6 Energy. Lower your opponent's Fervor 4. | Tide attacks |  | `tide_strike_16` |
| Tide Deep Anchor | Strike | Strike doing +1 Energy. Your opponent may not use cards that lower an Aspect for the remainder of Combat. You may not use cards that lower your own Aspect for the remainder of Combat. Remain 1. | Tide attacks |  | `tide_strike_06` |
| Tide Deep Sweep | Strike | Strike doing +4 Energy. Lower your opponent's Fervor 1. | Tide attacks |  | `tide_strike_14` |
| Tide Heavy Swell | Strike | Strike doing +3 Energy. Lower your opponent's Fervor 2. | Tide attacks |  | `tide_strike_09` |
| Tide Pressure Wave | Strike | Strike doing +4 Energy. Lower your opponent's Fervor 2. | Tide attacks |  | `tide_strike_10` |
| Tide Welling Deep | Strike | Strike doing +5 Energy. Raise your duelist's Energy to full. Place at the bottom of your Life Deck after use. | Tide attacks |  | `tide_strike_05` |
| Tide Black Water | Art | Art. Lower your opponent's Fervor 3. | Tide attacks |  | `tide_art_11` |
| Tide Cresting Wave | Art | Art dealing 5 wounds. Raise your Fervor 1. Lower your opponent's Fervor 2. | Tide attacks |  | `tide_art_12` |
| Tide Crushing Depth | Art | Art dealing 6 wounds. Hit: Discard every card attached to your duelist. Remove from the game after use. | Tide attacks |  | `tide_art_10` |
| Tide Spring Tide | Art | Art dealing 5 wounds. Raise your Fervor 2. Lower your opponent's Fervor 1. | Tide attacks |  | `tide_art_14` |
| Tide Torrent | Art | Art. Costs 0 Energy to perform. You may pay any amount of Energy; each 2 paid adds a wound. | Tide attacks |  | `tide_art_04` |
| Tide Twin Swell | Art | Art dealing 3 wounds, plus wounds equal to your Surge Rate. Remain 1. | Tide attacks |  | `tide_art_03` |
| Tide Held Under | Combat | Lower your opponent's Fervor 2. Your opponent loses 2 Energy. | Tide attacks |  | `tide_combat_01` |
| Tide Heavy Water Drill | Drill | Your Strikes do +1 Energy. | Tide attacks |  | `tide_drill_07` |

## Storm (lightning and wind): 50 cards

Subthemes: Art cost engine 5, Art boosts 4, Table defense 3, Drills 11, Endurance 12, Energy refill 4, Strike answers 6, Art answers 4, Storm Arts 14.

Masteries:

- **Storm Brewing Mastery** (`storm_mastery_01`): Your Arts do +1 wound. Your Arts cost 1 less Energy, to a minimum of 1. Limit 1 per deck.
- **Storm Squall Mastery** (`storm_mastery_02`): Hit: If the attack is Storm and the attack is an Art, your opponent may not use Strike cards during their next attack phase. Your Arts do +1 wound. Limit 1 per deck.
- **Storm Gale Mastery** (new): Your Strikes do +2 Energy. After a Storm Strike lands, your other Strikes do +1 wound this Combat
- **Storm Conductor Mastery** (new): Once per Combat, discard one of your Storm Drills to put 2 different Drills from your deck into play. In the Recover step you may put the top Drill of your discard pile under your deck

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Storm Idle Spark | Art | Art dealing 3 wounds. Costs 0 Energy to perform. | Art cost engine |  | `storm_art_14` |
| Storm Narrow Arc | Art | Art dealing 5 Energy. Costs 1 Energy to perform. | Art cost engine |  | `storm_art_20` |
| Storm Pent Discharge | Art | Endurance 2. Art. Costs 3 Energy to perform. Hit: Your opponent discards a card from hand. | Art cost engine, Endurance |  | `storm_art_15` |
| Storm Free Current | Combat | Use when entering Combat. Show your hand to your opponent. If 3 or more cards in your hand are Storm cards, attach this card to your duelist. While attached to your duelist: Your attacks cost no Energy to perform. Discard this card at the end of Combat. | Art cost engine |  | `storm_combat_02` |
| Storm Conduit Drill | Drill | Your Arts cost 1 less Energy to perform, to a minimum of 1. | Art cost engine, Drills |  | `storm_drill_04` |
| Storm Opened Channel | Strike | Focused Strike doing +2 Energy. Hit: For the remainder of Combat, your Arts do +2 wounds. | Art boosts |  | `storm_strike_09` |
| Storm Rolling Peal | Art | Art. Empower 3. For the remainder of Combat, your other Arts do +1 wound. Lower your opponent's Fervor 2. | Art boosts |  | `storm_art_13` |
| Storm Seeking Spark Drill | Drill | Once a Combat, after your Art lands, search their deck for a card and discard it | Art boosts, Drills | new |  |
| Storm Tight Coil Drill | Drill | Your Arts do +2 wounds. | Art boosts, Drills |  | `storm_drill_03` |
| Storm Dispersal Drill | Drill | Defense Shield: stops the first unstopped Art each Combat. | Table defense, Drills |  | `storm_drill_02` |
| Storm Mantle Drill | Drill | Defense Shield: stops the first unstopped Strike each Combat. | Table defense, Drills |  | `storm_drill_01` |
| Storm Stormwall Drill | Drill | Your Surge +1. Your Defense Shields can stop Focused attacks | Table defense, Drills | new |  |
| Storm Gathering Front | Strike | +3 Energy. Empower 2. Look at your top 4 and put a Drill from them into play; the rest back in any order | Drills | new |  |
| Storm Lightning Rod | Strike | Strike. At the end of this Combat, put a Storm Drill from your deck into play | Drills | new |  |
| Storm Steady Current | Art | Endurance 1. 6 wounds. This Combat your Drills survive an Aspect change | Drills, Storm Arts | new |  |
| Storm Backflash Drill | Drill | When a Strike damages you, draw the bottom card of your discard pile | Drills | new |  |
| Storm Grounding Drill | Drill | When you stop an attack, you may remove this Drill to stop every attack of that kind this Combat. Limit 2 | Drills, Strike answers, Art answers | new |  |
| Storm Levelling Wind | Strike | Endurance 2. Focused Strike doing +3 Energy. Hit: Your opponent discards up to 4 Allies in play of your choice. Lower your opponent's Fervor 2. | Endurance |  | `storm_strike_11` |
| Storm Maelstrom | Strike | Endurance 2. Strike doing +4 Energy. Empower 2. For the remainder of Combat, damage from your attacks cannot be prevented. Hit: All Freestyle Drills in play are removed from the game. | Endurance |  | `storm_strike_01` |
| Storm Recharge | Strike | Endurance 2. Strike doing +2 Energy. Raise your duelist's Energy to full. | Endurance, Energy refill |  | `storm_strike_03` |
| Storm Tailwind | Strike | Endurance 3. Strike doing +4 Energy. For the remainder of Combat, your other attacks do +1 Energy. Lower your opponent's Fervor 2. | Endurance |  | `storm_strike_12` |
| Storm Wringing Squall | Strike | Endurance 3. Strike. Hit: Look at your opponent's hand and choose a Strike card. They discard it. | Endurance |  | `storm_strike_08` |
| Storm Assailing Arc | Art | Endurance 2. Focused Art dealing 6 wounds. If your opponent's personality in control has more Energy than the one performing this attack, lower it to match. | Endurance |  | `storm_art_18` |
| Storm Charged Ward | Art | Endurance 3. Stops an Art. For the remainder of Combat, your attacks do +2 Energy. Raise your Fervor 1. | Endurance, Art answers |  | `storm_art_01` |
| Storm Ricochet Bolt | Art | Endurance 3. Art dealing 5 wounds. For the remainder of Combat, your attacks gain "Hit: your duelist gains 2 Energy." Lower your opponent's Fervor 2. | Endurance |  | `storm_art_19` |
| Storm Thunderhead | Art | Art. Empower 3. Your opponent discards up to 3 Drills in play of your choice. For the remainder of Combat, your next Endurance prevents all remaining damage. | Endurance |  | `storm_art_05` |
| Storm Scattering Gale | Combat | Endurance 3. Place up to 2 of your opponent's Seals in play at the bottom of their Life Deck. | Endurance |  | `storm_combat_01` |
| Storm Mustering Peal | Non-Combat | Use this card only if you have taken 5 or more wounds from a single attack this Combat. Endurance 2. Use in Combat: Search your discard pile for up to 3 Allies and put them into play at full Energy. | Endurance |  | `storm_noncombat_02` |
| Storm Feeding Arc | Strike | Strike. Gain 3 Energy. Remove the top card of your opponent's discard pile from the game. | Energy refill |  | `storm_strike_06` |
| Storm Return Stroke | Strike | Strike doing +3 Energy. Hit: Raise your duelist's Energy to full. Raise your Fervor 1. | Energy refill |  | `storm_strike_07` |
| Storm Drawn Charge | Art | Stops an Art. Gain 4 Energy. Lower your opponent's Fervor 1. | Energy refill, Art answers |  | `storm_art_12` |
| Storm Rising Gust | Strike | Stops a Strike. Raise your Fervor 1. | Strike answers |  | `storm_strike_04` |
| Storm Twin Earthing | Strike | Stops a Strike. The next Strike performed against you during your opponent's next attack phase is stopped. | Strike answers |  | `storm_strike_05` |
| Storm Damping Guard | Art | Stops a Strike. Lower your opponent's Fervor 1. | Strike answers |  | `storm_art_11` |
| Storm Static Field | Art | Art. Stops a Strike. Remove from the game after use. | Strike answers |  | `storm_art_02` |
| Storm Returning Front | Non-Combat | Stops a Strike. Place at the bottom of your Life Deck after use. | Strike answers |  | `storm_noncombat_01` |
| Storm Earthing Rod | Art | Stops an Art. Raise your Fervor 1. | Art answers |  | `storm_art_09` |
| Storm Felling Gust | Strike | Strike doing +4 Energy. Hit: Your opponent discards an Ally in play of your choice. | Storm Arts |  | `storm_strike_10` |
| Storm Overcharge | Strike | Strike doing +4 Energy. If your duelist has 2 or more Energy, you may lose 2 Energy. If you do, search your Life Deck for an Art card and put it into your hand. Remove from the game after use. | Storm Arts |  | `storm_strike_02` |
| Storm Arc Bolt | Art | Art dealing 5 wounds. Raise your Fervor 2. | Storm Arts |  | `storm_art_06` |
| Storm Chain Lightning | Art | Art dealing 5 wounds. Remain 1. Remove from the game after use. | Storm Arts |  | `storm_art_03` |
| Storm Cold Front | Art | Art. Lower your opponent's Fervor 2. | Storm Arts |  | `storm_art_22` |
| Storm Focused Bolt | Art | Focused Art dealing 5 wounds. Hit: Prevent all damage from Strikes during your opponent's next attack phase. | Storm Arts |  | `storm_art_17` |
| Storm Jolt | Art | Art dealing 5 wounds. Raise your Fervor 1. | Storm Arts |  | `storm_art_08` |
| Storm Lash | Art | Art dealing 5 wounds. Raise your Fervor 1. | Storm Arts |  | `storm_art_07` |
| Storm Residual Shock | Art | Art dealing 6 wounds. If stopped, your opponent takes 2 wounds. | Storm Arts |  | `storm_art_21` |
| Storm Silencing Static | Art | Art dealing 5 wounds. Name a card that can perform a Strike. Search your opponent's Life Deck for every copy of it and discard them. Shuffle their Life Deck. | Storm Arts |  | `storm_art_23` |
| Storm Smiting Bolt | Art | Art. Your opponent removes a Non-Combat card or Ally in play of your choice from the game. | Storm Arts |  | `storm_art_04` |
| Storm Stunning Bolt | Art | Art. Hit: Your opponent skips their next attack phase. Remove from the game after use. | Storm Arts |  | `storm_art_10` |
| Storm Ungrounded Flash | Art | Art dealing 6 wounds. Cannot be stopped by Art cards. | Storm Arts |  | `storm_art_16` |

## Shade (shadow and hexes): 50 cards

Subthemes: Whisper 13, Life Deck attack 6, Hexes 3, Hand attack 16, Paying Energy 6, Answers 11, Shade attacks 11.

Masteries:

- **Shade Nightfall Mastery** (`shade_mastery_01`): Your attacks do +1 Energy and +1 wound. Your Shade attacks do +2 Energy and +2 wounds instead. Limit 1 per deck.
- **Shade Tithe Mastery** (`shade_mastery_02`): Use this card only if you have a card in hand. Use in Combat: Discard a card from your hand. If you do, if the top card of your discard pile is Shade, your opponent discards a card from hand at random. if the top card of your discard pile is not Shade, your opponent discards a card from hand. Once per Combat. Limit 1 per deck.
- **Shade Blight Mastery** (`shade_mastery_03`): Your attacks gain "Hit: Discard a Drill in play." Your Shade attacks gain "Hit: You may discard a Non-Combat card in play." instead. Limit 1 per deck.
- **Shade Eclipse Mastery** (`shade_mastery_04`): Use this card only if 1 or more cards in your hand are Shade cards. Use in Combat: Discard a Shade card from your hand. If you do, raise your Fervor 1. gain 6 Energy. Your Shade cards that are not Drills and can stop attacks can also stop Focused attacks. Limit 1 per deck.

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Shade Emptying Whisper | Strike | Focused Strike doing +3 Energy. Hit: Your opponent discards until they have 2 or fewer cards in hand. | Whisper, Hand attack |  | `shade_strike_11` |
| Shade Feeding Whisper | Strike | Stops a Strike. Raise your Fervor 2. | Whisper |  | `shade_strike_18` |
| Shade Insistent Whisper | Strike | Endurance 1. Strike doing +2 Energy. Empower 3. Your opponent discards a card from hand. Remove from the game after use. | Whisper, Hand attack |  | `shade_strike_05` |
| Shade Lingering Whisper | Strike | Strike doing +4 Energy. The next Art performed against you during your opponent's next attack phase is stopped. Place 2 cards from the bottom of your discard pile at the bottom of your Life Deck. | Whisper |  | `shade_strike_08` |
| Shade Opening Whisper | Strike | Strike doing +10 Energy. Must be the first card you use this Combat. Hit: Your opponent may not perform Strikes for the remainder of Combat. If stopped, take 5 wounds. | Whisper |  | `shade_strike_20` |
| Shade Prying Whisper | Strike | Reserve only. Strike doing +3 Energy. Your opponent discards a Non-Combat card or Ally in play of your choice. Your opponent may discard a card from hand. If they do not, your opponent removes a Non-Combat card or Ally in play of your choice from the game. | Whisper, Hand attack |  | `shade_strike_01` |
| Shade Returning Whisper | Strike | Strike doing +4 Energy. Lower your opponent's Fervor 1. Hit: Choose 3 Whisper cards from your discard pile and place them on top of your Life Deck and remove this card from the game. | Whisper |  | `shade_strike_09` |
| Shade Sifting Whisper | Strike | Strike doing +4 Energy. Empower 2. Hit: Look at your opponent's hand and discard every Non-Combat card in it. | Whisper, Hand attack |  | `shade_strike_12` |
| Shade Silenced Whisper | Strike | Strike doing +3 Energy. Your opponent removes a card in hand that is not a Seal from the game, of their choice. If they hold only Seals, they show you their hand. | Whisper, Hand attack |  | `shade_strike_10` |
| Shade Stilling Whisper | Strike | Strike doing +3 Energy. Hit: Attach this card to one of your opponent's Non-Combat cards in play. While attached to one of your opponent's Non-Combat cards: That card cannot be used. | Whisper, Hexes |  | `shade_strike_16` |
| Shade Answering Whisper | Art | Art dealing 5 wounds. Stops a Strike. Raise your Fervor 1. | Whisper, Answers |  | `shade_art_01` |
| Shade Swelling Whisper | Art | Art dealing 6 wounds. Costs 5 Energy to perform. Raise your Fervor 1. | Whisper, Paying Energy |  | `shade_art_09` |
| Shade Turned Whisper | Art | Stops an Art. Raise your Fervor 1. | Whisper, Answers |  | `shade_art_08` |
| Shade Named Doom | Strike | Strike doing +3 Energy. Name a card that is not a Seal. Search your opponent's Life Deck for 1 copy of it and discard it. Shuffle their Life Deck. | Life Deck attack |  | `shade_strike_21` |
| Shade Slipping Thought | Strike | Strike doing +4 Energy. Choose a card at random from your opponent's hand and shuffle it into their Life Deck. Your opponent draws a card. | Life Deck attack, Hand attack |  | `shade_strike_04` |
| Shade Creeping Dark | Combat | Your opponent takes X wounds, X = your duelist's Surge Rate. | Life Deck attack |  | `shade_combat_03` |
| Shade Erased Name | Combat | Name a Strike, Art or Combat card. Your opponent searches their Life Deck for every copy of it and must remove them from the game. Remove from the game after use. | Life Deck attack |  | `shade_combat_02` |
| Shade Mockery Hex | Combat | Your opponent takes 2 wounds for each point of their Fervor. You may have your opponent shuffle their hand into their Life Deck; they then draw that many cards. Remove from the game after use. | Life Deck attack |  | `shade_combat_05` |
| Shade Pilfering Shadow | Non-Combat | Use in Combat: Search your opponent's Life Deck for up to 2 cards and remove them from the game. Remove from the game after use. | Life Deck attack |  | `shade_noncombat_01` |
| Shade Wasting Mark | Strike | Strike doing +3 Energy. Attach this card to your opponent's duelist. While attached to your opponent's duelist: Attacks that personality performs do -2 Energy. Discard this card when the personality it is attached to is at full Energy. | Hexes |  | `shade_strike_17` |
| Shade Fixed Gaze | Art | Endurance 1. Art. Empower 3. Attach this card to your opponent's duelist. While attached to your opponent's duelist: Damage from your attacks cannot be prevented while that personality is in control of Combat. | Hexes |  | `shade_art_10` |
| Shade Dread Grip | Strike | Strike doing +4 Energy. Stops a Strike. Your opponent discards a card from hand at random. Remove from the game after use. | Hand attack, Answers |  | `shade_strike_03` |
| Shade Hex Recall | Strike | Stops a Strike or an Art. Search your discard pile for a card that makes your opponent discard from hand and put it into your hand. Remove from the game after use. | Hand attack, Answers |  | `shade_strike_02` |
| Shade Picking Shadow | Strike | Focused Strike doing +2 Energy. Hit: Look at your opponent's hand and choose a card. They discard it. | Hand attack |  | `shade_strike_15` |
| Shade Dilemma Hex | Art | Art. Costs 3 Energy to perform. Hit: You may discard a card from your hand. If you do, your opponent may discard a card from hand at random. If they do not, your opponent loses 4 Energy. | Hand attack, Paying Energy |  | `shade_art_13` |
| Shade Mind Rot | Art | Art. Costs 3 Energy to perform. Hit: Your opponent discards 2 cards from hand. | Hand attack, Paying Energy |  | `shade_art_02` |
| Shade Rebounding Hex | Art | Stops an Art. You may discard a card from your hand. If you do, your opponent discards a card from hand at random. | Hand attack, Answers |  | `shade_art_11` |
| Shade Stolen Secret | Combat | Endurance 2. Look at your opponent's hand. Your opponent skips their next attack phase. Your next attack does +2 wounds. | Hand attack |  | `shade_combat_04` |
| Shade Clouded Mind Drill | Drill | After a successful attack, choose a card at random from your opponent's hand and shuffle it into their Life Deck and your opponent draws a card. | Hand attack |  | `shade_drill_04` |
| Shade Forgetting Drill | Drill | At the beginning of each Discard step, if your duelist has 1 or more Energy, you may lose 1 Energy. If you do, your opponent discards their whole hand. | Hand attack |  | `shade_drill_03` |
| Shade Hoarded Secrets Drill | Drill | You may now keep up to 2 cards in your hand at the end of each turn. | Hand attack |  | `shade_drill_02` |
| Shade Gathering Dark | Strike | Strike. You may pay any amount of your duelist's Energy; each 1 paid adds 1 Energy of damage. | Paying Energy |  | `shade_strike_07` |
| Shade Hungering Gloom | Art | Art dealing 4 Energy. Costs 2 Energy to perform. Hit: Gain 4 Energy. | Paying Energy |  | `shade_art_07` |
| Shade Veil | Combat | Stops a Strike or an Art. Costs 1 Energy to use. | Paying Energy, Answers |  | `shade_combat_01` |
| Shade Gathered Hexes | Strike | Stops an Art. Choose 3 Shade cards from your discard pile and shuffle them into your Life Deck. Remove from the game after use. | Answers |  | `shade_strike_19` |
| Shade Sapping Shadow | Strike | Stops a Strike. Your opponent's duelist loses 1 Energy. Lower your opponent's Fervor 1. | Answers |  | `shade_strike_22` |
| Shade Severing Shadow | Art | Art dealing 4 wounds. Stops an Art. | Answers |  | `shade_art_04` |
| Shade Reclaimed Hex Drill | Drill | Whenever you stop an attack, you may place the bottom card of your discard pile at the bottom of your Life Deck. | Answers |  | `shade_drill_07` |
| Shade Umbra Drill | Drill | Defense Shield: stops the first unstopped Art each Combat. | Answers |  | `shade_drill_05` |
| Shade Binding Murk | Strike | Strike dealing 3 wounds. Hit: Your opponent may not perform Strikes for the remainder of Combat. | Shade attacks |  | `shade_strike_06` |
| Shade Bitter Trade | Strike | Marked only. Strike doing +5 Energy. You may discard one of your Non-Combat cards in play. If you do, your opponent discards 2 Non-Combat cards in play of your choice. | Shade attacks |  | `shade_strike_14` |
| Shade Ransoming Hand | Strike | Reserve only. Strike doing +3 Energy. For the remainder of Combat, during your attack phase you may remove 2 cards from your Reserve from the game to remove one of your opponent's Drills in play. Remove from the game after use. | Shade attacks |  | `shade_strike_13` |
| Shade Reaching Shadow | Strike | Strike doing +3 Energy. Hit: Gain 3 Energy. | Shade attacks |  | `shade_strike_23` |
| Shade Culling Hex | Art | Endurance 2. Art. Hit: Your opponent discards an Ally in play of your choice. | Shade attacks |  | `shade_art_12` |
| Shade Dusk Bolt | Art | Focused Art. Hit: Raise your Fervor 1. | Shade attacks |  | `shade_art_06` |
| Shade Night Rend | Art | Art dealing 6 wounds. Your opponent loses 3 Energy. | Shade attacks |  | `shade_art_03` |
| Shade Shadow Snare | Art | Art dealing 6 wounds. Hit: Your opponent may not perform Arts for the remainder of Combat. | Shade attacks |  | `shade_art_05` |
| Shade Shadow Respite | Non-Combat | Use in Combat: Raise any one personality's Energy to full. You may end Combat. | Shade attacks |  | `shade_noncombat_02` |
| Shade Effacing Drill | Drill | After a successful attack, if the attack is an Art, your opponent removes a Non-Combat card in play of your choice from the game. Limit 1 per deck. | Shade attacks |  | `shade_drill_06` |
| Shade Gleaning Drill | Drill | After a successful attack, you may draw a card. Once per Combat. | Shade attacks |  | `shade_drill_01` |

## Root (thorn, sap, stone and frost; needs a Verdant Duelist): 50 cards

Subthemes: Recursion 13, Seals 3, Table defense 9, Fervor denial 8, Board strip 5, Costly Arts 5, Root attacks 14.

Masteries:

- **Root Regrowth Mastery** (`root_mastery_01`): Verdant duelists only. When entering Combat, you may draw the bottom card of your discard pile. If that card is a Root card, raise your duelist's Energy to full. Limit 1 per deck.
- **Root Compost Mastery** (`root_mastery_02`): Verdant duelists only. When entering Combat, shuffle the top card of your discard pile into your Life Deck. If it is a Root card, draw a card. Limit 1 per deck.
- **Root Deeproot Mastery** (`root_mastery_03`): Verdant duelists only. When entering Combat, draw the bottom card of your Life Deck. If it is a Root card, you may show it to your opponent. If you do, draw the bottom card of your Life Deck. Limit 1 per deck.
- **Root Sacred Grove Mastery** (`root_mastery_04`): Verdant duelists only. When one of your cards that is not a Root would go to your discard pile, remove it from the game instead. Your Root attacks gain "Hit: Place the bottom 2 cards of your discard pile at the bottom of your Life Deck and gain 3 Energy." Limit 1 per deck.

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Root Bindweed | Strike | Endurance 2. Strike doing +3 Energy. Shuffle the top 2 cards of your discard pile into your Life Deck. Remove from the game after use. | Recursion |  | `root_strike_14` |
| Root Boar Rush | Strike | Strike doing +5 Energy. Raise your duelist's Energy to full. Shuffle the top 4 cards of your discard pile into your Life Deck. Remove from the game after use. | Recursion |  | `root_strike_01` |
| Root Creeping Vine | Strike | Endurance 4. Strike doing +2 Energy. Hit: Choose a card from your discard pile and shuffle it into your Life Deck. | Recursion, Table defense |  | `root_strike_17` |
| Root Rising Sap | Strike | Strike. Place 2 cards from the bottom of your discard pile at the bottom of your Life Deck. | Recursion |  | `root_strike_06` |
| Root Barkskin Deflection | Art | Verdant only. Stops an Art. Shuffle the top and bottom cards of your discard pile into your Life Deck. | Recursion |  | `root_art_01` |
| Root Hurled Thorns | Art | Art dealing 5 wounds. Costs 1 Energy to perform. Hit: Shuffle the top card of your discard pile into your Life Deck. | Recursion, Costly Arts |  | `root_art_12` |
| Root Scattered Seed | Art | Art dealing 6 wounds. Hit: Place 3 cards from the bottom of your discard pile at the bottom of your Life Deck. If stopped, remove the bottom 2 cards of your discard pile from the game. | Recursion |  | `root_art_08` |
| Root Seed Burst | Art | Focused Art dealing 5 wounds. Hit: Choose up to 4 cards in your discard pile. Remove 2 of them from the game and shuffle the rest into your Life Deck. Remove this card from the game. | Recursion |  | `root_art_11` |
| Root Wyrmwood Blast | Art | Verdant only. Art, plus 1 wound for each Marble Seal in play. Choose X cards from your discard pile and place them on the bottom of your Life Deck. X = the number of Marble Seals in play. | Recursion, Seals |  | `root_art_04` |
| Root Closing Bark | Combat | Endurance 10. Shuffle the top card of your discard pile into your Life Deck. Remove from the game after use. | Recursion, Table defense |  | `root_combat_04` |
| Root Grove Focus | Combat | Draw the bottom card of your discard pile. If that card is a Root card, search your Life Deck for an Art card and put it into your hand. Remove from the game after use. | Recursion |  | `root_combat_02` |
| Root New Shoots | Combat | Verdant only. Choose one: shuffle the top 3 cards of your discard pile into your Life Deck or shuffle 3 cards from the bottom of your discard pile into your Life Deck. | Recursion |  | `root_combat_08` |
| Root Deep Draught | Non-Combat | Use in Combat: Raise your duelist's Energy to full. Draw a card and show it to your opponent. If it is a Root card, choose 2 cards from your discard pile and place them on the bottom of your Life Deck. Remove from the game after use. | Recursion |  | `root_noncombat_01` |
| Root Carver's Reach | Strike | Strike. Hit: Capture a Seal. Lower your opponent's Fervor 2. Remove from the game after use. | Seals, Fervor denial |  | `root_strike_03` |
| Root Swallowing Earth | Combat | For the remainder of Combat, your Strikes do +2 Energy. Place a Seal in play at the bottom of its owner's Life Deck. | Seals |  | `root_combat_07` |
| Root Oakheart Guard | Strike | Verdant only. Endurance 3. Strike. Stops a Strike. | Table defense |  | `root_strike_19` |
| Root Trail Cut | Combat | Endurance 4. Look at the top 4 cards of your opponent's Life Deck and remove 1 of them that is not a Seal from the game. Put the rest back on the top in any order. | Table defense |  | `root_combat_05` |
| Root Canopy Drill | Drill | Defense Shield: stops the first unstopped Art each Combat. | Table defense |  | `root_drill_03` |
| Root Frost Watch Drill | Drill | Discard a card that can perform an Art from your hand to stop an Art. Your duelist's Surge Rate is +2 while this is in play. | Table defense |  | `root_drill_06` |
| Root Sightline Drill | Drill | When entering Combat, look at the top 2 cards of your Life Deck and put them all on top or all on the bottom, in any order. | Table defense |  | `root_drill_04` |
| Root Tracker's Drill | Drill | When entering Combat as the defender, look at the top 5 cards of your Life Deck and put them back in any order. | Table defense |  | `root_drill_01` |
| Root Windbreak Drill | Drill | Defense Shield: stops the first unstopped Strike each Combat. | Table defense |  | `root_drill_02` |
| Root Oaken Stance | Strike | Stops a Strike. Lower your opponent's Fervor 1. | Fervor denial |  | `root_strike_02` |
| Root Pruning Cut | Strike | Strike doing +2 wounds. Hit: Draw the top card of your discard pile. Lower your opponent's Fervor 2. Remove from the game after use. | Fervor denial |  | `root_strike_07` |
| Root Splitting Wedge | Strike | Endurance 3. Strike. Empower 4. Your opponent discards a Non-Combat card, Ally, or Grounds in play of your choice. Lower your opponent's Fervor 2. | Fervor denial, Board strip |  | `root_strike_12` |
| Root Taproot Brace | Strike | Stops a Strike. Raise your duelist's Energy to full. Lower your opponent's Fervor 1. | Fervor denial |  | `root_strike_16` |
| Root Auger Splinter | Art | Focused Art dealing 5 wounds. Lower your opponent's Fervor 2. | Fervor denial |  | `root_art_06` |
| Root Culling Frost | Art | Endurance 2. Art. Hit: Your opponent discards an Ally in play of your choice. Lower your opponent's Fervor 1. | Fervor denial, Board strip |  | `root_art_10` |
| Root First Frost | Art | Art. Lower your opponent's Fervor 1. | Fervor denial |  | `root_art_05` |
| Root Stone Cleaver | Strike | Endurance 4. Focused Strike doing +3 Energy. Empower 3. For the remainder of Combat, your opponent cannot use Defense Shields. Your opponent discards up to 3 Allies in play of your choice. | Board strip |  | `root_strike_18` |
| Root Kin Clearing | Combat | You must have an Ally in play to use this card. Your opponent discards all Non-Combat cards in play. Remove from the game after use. Limit 1 per deck. | Board strip |  | `root_combat_06` |
| Root Strangling Vine | Non-Combat | Osric Thornwald only. Use in Combat: Choose one of your opponent's Drills in play. Your opponent cannot use its power for the rest of the game. Remove from the game after use. Limit 8 per deck. | Board strip |  | `root_noncombat_05` |
| Root Millstone | Strike | Strike dealing 6 wounds. Costs 3 Energy to perform. | Costly Arts |  | `root_strike_05` |
| Root Old Growth | Art | Art dealing 10 wounds. Costs 4 Energy to perform. Hit: Remove the top 3 cards of your Life Deck from the game. If stopped, discard your whole hand. Remove from the game after use. | Costly Arts |  | `root_art_09` |
| Root Uprooting Blast | Art | Art dealing 7 wounds. Costs 4 Energy to perform. | Costly Arts |  | `root_art_03` |
| Root Sap Flow Drill | Drill | Your attacks do +2 Energy. Your attacks cost 1 less Energy to perform, to a minimum of 1. The Energy costs of cards you use are 1 less, to a minimum of 1. This Drill does not count towards or against the one school of Drills you may have in play. | Costly Arts |  | `root_drill_05` |
| Root Briar Tangle | Strike | Strike dealing 3 Energy. Remain 2. Remove from the game after use. | Root attacks |  | `root_strike_09` |
| Root Deadfall | Strike | Focused Strike doing +3 Energy. Hit: Remove any cards in your discard pile from the game. | Root attacks |  | `root_strike_08` |
| Root Grove Fury | Strike | Strike dealing 6 Energy. Raise your Fervor 1. Remove from the game after use. | Root attacks |  | `root_strike_13` |
| Root Quickening | Strike | Strike doing +5 Energy. If the attack is against a Marked personality, focused. Gain 4 Energy. | Root attacks |  | `root_strike_10` |
| Root Sapwood Guard | Strike | Stops a Strike. Gain 3 Energy. | Root attacks |  | `root_strike_15` |
| Root Snare | Strike | Strike doing +3 Energy. Hit: Remove a Non-Combat card in play from the game. | Root attacks |  | `root_strike_11` |
| Root Timber Blow | Strike | Strike doing +3 Energy. | Root attacks |  | `root_strike_04` |
| Root Drinking Leaves | Art | Stops an Art. Gain 3 Energy. | Root attacks |  | `root_art_02` |
| Root Flung Stone | Art | Art dealing 5 wounds. Hit: Discard a Non-Combat card in play. Remove from the game after use. | Root attacks |  | `root_art_07` |
| Root Bramble Wall | Combat | The next attack performed against you this Combat is stopped. Remove from the game after use. | Root attacks |  | `root_combat_03` |
| Root Thorn Volley | Combat | Osric Thornwald only. Art. Search your Life Deck for an Art card and put it into your hand. | Root attacks |  | `root_combat_01` |
| Root Fallen Oak | Non-Combat | Osric Thornwald only. You must have an Ally in play to use this card. Use in Combat: Remove one of your Allies in play from the game. If you do, raise your Fervor 2. Remove from the game after use. | Root attacks |  | `root_noncombat_03` |
| Root Grove Kin | Non-Combat | Use in Combat: Raise every one of your Allies' Energy to full. For the remainder of Combat, your Allies may take control of Combat and use their Powers at any Energy. Take a wound for each Ally you have in play. | Root attacks |  | `root_noncombat_04` |
| Root Thorn Hedge | Non-Combat | Use immediately after you take damage from an attack. Your opponent takes 3 wounds. | Root attacks |  | `root_noncombat_02` |

## Freestyle (shared, mundane): 63 cards

Legal in every deck. Grouped by what the card is for rather than by subtheme.

Mastery: **Freestyle Discipline Mastery** (`freestyle_mastery_01`): When entering Combat, if you have a card in hand, you may discard a Signature card from your hand. If you do, search your Life Deck for a Signature card and put it into your hand. Your Drills cannot be discarded for any reason, an aspect change included. Limit 1 per deck.

| Title | Type | What it does | Subthemes | New | id |
|---|---|---|---|---|---|
| Old Habit | Strike | Strike. Draw the bottom card of your discard pile. Remove from the game after use. | Search, Recursion, Other |  | `freestyle_strike_01` |
| Lobbed Bolt | Art | Endurance 1. Art. Discard up to 1 of your Non-Combat cards in play. Search your Life Deck for a Non-Combat card and put it into play. Remove from the game after use. | Search, Board removal, Other |  | `freestyle_art_03` |
| Marked Lightning | Art | Marked only. Use this card immediately after a Strike you perform succeeds. Your opponent discards up to 3 Non-Combat cards in play of your choice. Draw a card. | Search, Board removal, Other |  | `freestyle_art_10` |
| Closing Ranks | Combat | Draconic only. Use when performing an attack. That attack does +2 wounds for each Draconic personality you have in play. Draw a card. Remove from the game after use. | Search, Board removal, Other |  | `freestyle_combat_11` |
| Hired Blades | Combat | Search your Life Deck or discard pile for an Ally and put it into play at Energy 10. | Search, Recursion, Allies, Other |  | `freestyle_combat_13` |
| Keen Eye | Combat | Draw a card. If it is a Signature card, draw a card. Remove from the game after use. | Search, Other |  | `freestyle_combat_16` |
| Rallying Call | Combat | Raise your duelist's and every Ally's Energy to full. Search your Life Deck or discard pile for an Ally and put it into play at Energy 3. Remove from the game after use. | Search, Recursion, Allies, Other |  | `freestyle_combat_12` |
| Respite | Combat | Draw the top 2 cards of your discard pile. Your opponent's duelist gains 5 Energy. Limit 1 per deck. | Search, Recursion, Other |  | `freestyle_combat_05` |
| Warding Call | Combat | Search your Life Deck or discard pile for an Ally and put it into play at Energy 3. Your opponent discards all Seals in play. Limit 1 per deck. | Search, Board removal, Recursion, Seals, Allies, Other |  | `freestyle_combat_08` |
| Clear Mind | Non-Combat | Use in Combat: Search your Life Deck for a Combat card and put it into your hand. | Search, Other |  | `freestyle_noncombat_03` |
| Lucky Find | Non-Combat | Use in Combat: Search your Life Deck for a Non-Combat card and put it into play. Limit 1 per deck. | Search, Other |  | `freestyle_noncombat_06` |
| Recalled Lesson | Non-Combat | Use in Combat: Search your Life Deck or discard pile for a Strike or Art card and put it into your hand. Limit 1 per deck. | Search, Recursion, Other |  | `freestyle_noncombat_02` |
| Warden's Measure | Non-Combat | Use in Combat: Search your Life Deck for a Seal and put it into play. Remove from the game after use. Limit 1 per deck. | Search, Seals, Other |  | `freestyle_noncombat_14` |
| Revision Drill | Drill | Use in Combat: Discard a card from your hand. Draw 2 cards. Once per Combat. Limit 1 per deck. | Search, Other |  | `freestyle_drill_02` |
| Clean Sweep | Strike | Strike doing +6 Energy. Costs 6 Energy to perform. Hit: Your opponent discards up to 6 Non-Combat cards in play of your choice. Remove from the game after use. | Board removal, Other |  | `freestyle_strike_02` |
| Headlong Plunge | Strike | Endurance 2. Focused Strike doing +3 Energy. Empower 3. Raise your Fervor 1. Lower your opponent's Fervor 1. Your opponent discards an Ally in play of your choice. Gain 3 Energy. Place at the bottom of your Life Deck after use. | Board removal, Allies, Fervor, Other |  | `freestyle_strike_03` |
| Knife Volley | Art | Endurance 2. Art, plus 2 wounds for each Ally you have in play. Raise your Fervor 1. Remain 1. Remove from the game after use. | Board removal, Allies, Fervor, Other |  | `freestyle_art_05` |
| Marked Demise | Art | Marked only. Art. You may reduce the wounds this attack deals by any amount, to a minimum of 0, and remove one of your opponent's Drills in play for every wound given up. Empower 2. Limit 2 per deck. | Board removal, Other |  | `freestyle_art_11` |
| Riftcry | Art | Discard the Grounds in play. If Bram Ashmark is your duelist, raise your Fervor 1. | Board removal, Fervor, Other |  | `freestyle_art_09` |
| Dismissal | Combat | All Allies in play are removed from the game. Remove from the game after use. Limit 2 per deck. | Board removal, Allies, Other |  | `freestyle_combat_17` |
| Spent to the Last | Combat | Your duelist must have 5 Energy to use this. Discard all Non-Combat cards and Allies in play. Set your duelist's Energy to 0. Raise your Fervor 1. Limit 1 per deck. | Board removal, Allies, Fervor, Other |  | `freestyle_combat_20` |
| An Open Challenge | Non-Combat | Use during your opponent's Declare step: Discard a card from your hand. Your opponent must declare Combat this turn. Begins the game in play. Remove from the game after use. Limit 1 per deck. | Board removal, Other |  | `freestyle_noncombat_09` |
| Defacement | Non-Combat | Use in Combat: Your opponent removes a Seal in play of your choice from the game. Remove from the game after use. Limit 1 per deck. | Board removal, Seals, Other |  | `freestyle_noncombat_10` |
| Kin's Rescue | Non-Combat | Use in Combat: For the remainder of Combat, all damage from attacks against you is prevented. If Marble Seal 7 is in play, discard this card after use instead. Remove from the game after use. Limit 1 per deck. | Board removal, Seals, Other |  | `freestyle_noncombat_16` |
| Rites Unmade | Non-Combat | Use in Combat: Your opponent discards all Drills in play. Remove from the game after use. Limit 1 per deck. | Board removal, Other |  | `freestyle_noncombat_01` |
| Spoiled Rite | Non-Combat | Use in Combat: Your opponent removes all Non-Combat cards in play from the game. Remove from the game after use. Limit 1 per deck. | Board removal, Other |  | `freestyle_noncombat_12` |
| The Breaker's Yard | Non-Combat | Use in Combat: Remove an Ally in play from the game. If your duelist is Scorn or Marrow, remove an Ally in play from the game. | Board removal, Allies, Other |  | `freestyle_noncombat_11` |
| The Watch Goes Dark | Non-Combat | Use in Combat: Remove all Seals in play and in both Life Decks from the game. | Board removal, Seals, Other |  | `freestyle_noncombat_18` |
| Bravado Drill | Drill | When entering Combat, lower your opponent's Fervor 2 and gain 2 Energy. Begins the game in play. Limit 1 per deck. | Board removal, Fervor, Other |  | `freestyle_drill_01` |
| Counterplay Drill | Drill | When placed, name a card. Neither player may play or use it while this is in play. Limit 2 per deck. | Board removal, Other |  | `freestyle_drill_04` |
| Lone Blade Drill | Drill | Your Strikes do +5 Energy. Discard this Drill if you have any other Non-Combat card in play. | Board removal, Other |  | `freestyle_drill_03` |
| Second Wind | Strike | Stops a Strike. Raise your duelist's Energy to full. Shuffle 3 cards from the bottom of your discard pile into your Life Deck. | Recursion, Stops, Other |  | `freestyle_strike_06` |
| Last Gasp | Combat | Set your duelist's Energy to 0. Remove all of your discard pile from the game. Your opponent takes 5 wounds. Remove from the game after use. Limit 1 per deck. | Recursion, Other |  | `freestyle_combat_09` |
| Parley | Combat | End Combat. Place the bottom card of your discard pile at the bottom of your Life Deck. Remove from the game after use. | Recursion, Other |  | `freestyle_combat_18` |
| Foresight | Non-Combat | When entering Combat, search your discard pile for a Strike, Art, or Combat card and put it into your hand. | Recursion, Other |  | `freestyle_noncombat_04` |
| Provocation | Non-Combat | Raise your Fervor 2. Choose up to 2 cards from your discard pile and place them on the bottom of your Life Deck. Remove from the game after use. | Recursion, Fervor, Other |  | `freestyle_noncombat_07` |
| The Gate's Boon | Non-Combat | Use in Combat: End Combat. Choose up to 3 cards from your discard pile and shuffle them into your Life Deck. Remove from the game after use. Limit 1 per deck. | Recursion, Other |  | `freestyle_noncombat_13` |
| Seal Seizure | Combat | Capture a Seal. | Seals, Other |  | `freestyle_combat_19` |
| Eyes Beyond the Gate | Non-Combat | After a successful attack, if the attack is an Art, you may search your Life Deck for a Seal and put it into play. If you do, capture a Seal. Limit 1 per deck. | Seals, Other |  | `freestyle_noncombat_17` |
| Sleight | Non-Combat | Use in Combat: Capture a Seal. Remove from the game after use. | Seals, Other |  | `freestyle_noncombat_15` |
| Warding Drill | Drill | Neither player may place Seals. Limit 1 per deck. | Seals, Other |  | `freestyle_drill_06` |
| Bonding Rite | Non-Combat | Use in Combat: Bond the two named Allies: they leave play under their Bond card, which fights as one Ally at full Energy. | Allies, Other |  | `freestyle_noncombat_08` |
| Sword Lunge | Strike | Focused Strike doing +3 Energy. Hit: Lower your opponent's Fervor 3. Remove from the game after use. | Fervor, Other |  | `freestyle_strike_04` |
| Captain's Barrage | Art | Art. Costs 3 Energy to perform. Raise your Fervor 2. Remove from the game after use. | Fervor, Other |  | `freestyle_art_06` |
| Sharp Rebuke | Art | Art dealing 8 wounds. Lower your opponent's Fervor 3. Remove from the game after use. Limit 1 per deck. | Fervor, Other |  | `freestyle_art_07` |
| Braced Guard | Combat | Stops a Strike or an Art. Lower your opponent's Fervor 1. Remove from the game after use. | Fervor, Stops, Other |  | `freestyle_combat_02` |
| Raised Stakes | Combat | Raise your Fervor 6. Raise your opponent's Fervor 6. You cannot win by Ascension for the rest of the game. | Fervor, Other |  | `freestyle_combat_14` |
| Reckless Ascent | Combat | You cannot win by Ascension for the rest of the game. Move your duelist to the aspect equal to your Fervor. | Fervor, Other |  | `freestyle_combat_15` |
| Last Ward | Strike | Stops a Strike or an Art. You may discard a card from your hand to stop a Focused attack. | Stops, Other |  | `freestyle_strike_05` |
| Dead Air | Art | Stops an Art. Stops all Arts performed against you for the remainder of Combat. You may not perform Arts for the remainder of Combat. | Stops, Other |  | `freestyle_art_01` |
| Stillness | Combat | Stops a Strike or an Art. Stops all attacks performed against you for the remainder of Combat. Limit 1 per deck. | Stops, Other |  | `freestyle_combat_01` |
| Marked Strength | Strike | Marked only. Strike doing +2 Energy. Hit: Your opponent's duelist loses 4 Energy and your opponent may not use Combat cards for the remainder of Combat. | Other |  | `freestyle_strike_07` |
| Blinding Flare | Art | Art. Hit: Your opponent may not use Strike cards for the remainder of Combat. | Other |  | `freestyle_art_08` |
| Overreach | Art | Focused Art. If your duelist is aspect 2 or higher, you may lose one Aspect. If you do, your next attack does +7 wounds. Remove from the game after use. | Other |  | `freestyle_art_04` |
| Unerring Bolt | Art | Art. Cannot be stopped. Damage cannot be prevented. Remove from the game after use. | Other |  | `freestyle_art_02` |
| Kept at Bay | Combat | Your opponent may not perform Strikes for the remainder of Combat. | Other |  | `freestyle_combat_07` |
| Old Trick | Combat | Search your Reserve for an attack card and put it into your hand. Remove from the game after use. | Other |  | `freestyle_combat_10` |
| Sever the Leyline | Combat | Set your opponent's duelist to aspect 1. Remove from the game after use. Limit 1 per deck. | Other |  | `freestyle_combat_04` |
| Terms of the Pact | Combat | Choose Strikes or Arts: all attacks of that kind are stopped for the remainder of Combat, yours included. Remove from the game after use. Limit 1 per deck. | Other |  | `freestyle_combat_03` |
| Watchful Eye | Combat | Look at your opponent's hand and shuffle a card of your choice into their Life Deck. | Other |  | `freestyle_combat_06` |
| The Long Year | Non-Combat | Use in Combat: For the rest of the game, your attacks do +1 Energy. Remove from the game after use. | Other |  | `freestyle_noncombat_05` |
| Assembly Drill | Drill | Your attacks do +1 wound. If the attack is performed by a Construct personality, your attacks do +2 wounds instead. | Other |  | `freestyle_drill_07` |
| No Retreat Drill | Drill | Neither player may use cards that end Combat. | Other |  | `freestyle_drill_05` |

## Signature: 70 cards

Tied to a named character, schoolless unless noted. Listed by character, largest kit first.

| Character | Title | Type | What it does | id |
|---|---|---|---|---|
| Caedan Vale | Caedan's Pommel Bash | Strike | Endurance 2. Strike doing +4 Energy. If Caedan Vale is your duelist and you stopped an attack in their last attack phase, your opponent skips their next attack phase. Raise your Fervor 1. | `signature_strike_15` |
| Caedan Vale | Caedan's Quickstep | Strike | Strike doing +4 Energy. Empower 2. Lower your opponent's Fervor 2. If Caedan Vale is your duelist, search your discard pile for a Signature card and put it into your hand. Remove from the game after use. | `signature_strike_14` |
| Caedan Vale | Caedan's Riposte | Strike | Stops a Strike. In your next attack phase you may repeat the attack it stopped. | `signature_strike_21` |
| Caedan Vale | Caedan's Sword Draw | Strike | Strike doing +4 Energy. Raise your Fervor 1. Hit: Search your Life Deck for a "Sword" card other than "Caedan's Sword Draw" and put it into your hand. | `signature_strike_13` |
| Caedan Vale | Caedan's Declaration | Art | Art. Raise your Fervor 2. Lower your opponent's Fervor 2. Remove from the game after use. Limit 1 per deck. | `signature_art_09` |
| Caedan Vale | Caedan Cuts It Short | Combat | Use when needed. Stops the effects of any Combat card. | `signature_combat_03` |
| Caedan Vale | Caedan's Quiet Study | Combat | Draw a card. If it is one of your duelist's Signature cards, draw a card. | `signature_combat_08` |
| Caedan Vale | Caedan's Heirloom Blade | Non-Combat | Use in Combat: Attach this card to your duelist. While attached to your duelist: Your "Sword" attacks do +3 wounds. Wounds from those attacks are removed from the game. | `signature_noncombat_06` |
| Caedan Vale | Caedan's Insight | Non-Combat | Use in Combat: Search your Life Deck for up to 2 Signature cards and put them into your hand. Remove from the game after use. | `signature_noncombat_03` |
| Caedan Vale | Caedan's Guardian Drill | Drill | Use in Combat: Place a Non-Combat card, Drill, or Seal from your hand into play. Once per Combat. | `signature_drill_06` |
| Bram Ashmark | Ashmark Scatters the Ashes | Strike | Endurance 1. Strike doing +4 Energy. Remove the top 5 cards of your opponent's discard pile from the game. Gain 3 Energy. | `signature_strike_19` |
| Bram Ashmark | Ashmark's Choke Hold | Strike | Strike doing +4 Energy. Empower 2. For the remainder of Combat, your opponent's duelist loses 1 Energy at the beginning of each of their attack phases. Hit: Search your Life Deck for a "Sweep" card and put it into your hand. | `signature_strike_30` |
| Bram Ashmark | Ashmark's Relentless Fury | Strike | Strike doing +4 Energy. Empower 2. Neither player may do anything but attack or pass in their attack phase for the remainder of Combat. Raise your Fervor 1. | `signature_strike_02` |
| Bram Ashmark | Ashmark's Unmaking Whisper | Strike | Strike doing +5 Energy. Hit: Lower your opponent's Fervor 2. Hit: If your opponent's Fervor is 0, your opponent loses one Aspect. | `signature_strike_31` |
| Bram Ashmark | Ashmark's Wall of Flame | Strike | Marked only. Stops a Strike or an Art. Can stop a Focused attack. Remove from the game after use. | `signature_strike_08` |
| Bram Ashmark | Ashmark Leaves Nothing | Art | Focused Art. Empower 2. Hit: Remove all of your opponent's discard pile from the game. Raise your Fervor 1. | `signature_art_02` |
| Bram Ashmark | Ashmark's Ember Spray | Art | Marked only. Art dealing 5 wounds. Raise your Fervor 2. Hit: Search your discard pile for a Marked Art card and put it into your hand. Remove from the game after use. | `signature_art_14` |
| Bram Ashmark | Ashmark Will Not Break | Combat | Bram Ashmark only. Stops a Strike or an Art. For the remainder of Combat, all damage from attacks against you is prevented. Limit 1 per deck. | `signature_combat_02` |
| Bram Ashmark | Ashmark Stokes the Coals | Non-Combat | Bram Ashmark only. Use in Combat: Raise your duelist's Energy to full. Shuffle the top 5 cards of your discard pile into your Life Deck. Raise your Fervor 1. | `signature_noncombat_04` |
| Emrys Rooke | Emrys Gives No Quarter | Strike | Strike doing +3 Energy. Neither player may use cards that end Combat or use cards that stop all attacks for the remainder of Combat. | `signature_strike_01` |
| Emrys Rooke | Emrys Risks It All | Strike | Focused Strike doing +4 Energy. Cannot be stopped by Strike cards. Raise your Fervor 1. Remove from the game after use. | `signature_strike_09` |
| Emrys Rooke | Emrys' Hilt Guard | Strike | Stops a Strike. Search your discard pile for an Emrys Rooke Signature card and put it into your hand. Remove from the game after use. | `signature_strike_22` |
| Emrys Rooke | Emrys' Rising Blow | Strike | Strike doing +3 Energy. Raise your Fervor 1. If performed against a Pact duelist, Remain 1. Remove from the game after use. | `signature_strike_29` |
| Emrys Rooke | Emrys' Sword Flourish | Strike | Focused Strike. Hit: Search your Life Deck for a "Swordplay" card and put it into play. Remove from the game after use. | `signature_strike_10` |
| Emrys Rooke | Emrys' Sword Sweep | Strike | Strike doing +2 Energy. Hit: Your opponent discards up to 4 Allies in play of your choice. | `signature_strike_11` |
| Emrys Rooke | Emrys' Sword Thrust | Strike | Strike doing +2 Energy. Hit: Your opponent discards 2 Non-Combat cards in play of your choice. | `signature_strike_12` |
| Emrys Rooke | Emrys Spots the Fraud Drill | Drill | Your opponent may not place Allies. Limit 1 per deck. | `signature_drill_04` |
| Emrys Rooke | Emrys' Swordplay Drill | Drill | Your "Sword" attacks do +2 Energy. "If successful" lines on your "Sword" attacks resolve as secondary effects. | `signature_drill_01` |
| Sir Edric Rooke | Edric Gives Ground | Strike | Stops a Strike or an Art. Raise your or your opponent's Fervor 1. The next attack performed against you this Combat is stopped. If Sir Edric Rooke is in control, place this card at the bottom of your Life Deck after use. | `signature_strike_23` |
| Sir Edric Rooke | Edric's Opening Strike | Strike | Strike. Hit: Draw the bottom card of your discard pile. If Sir Edric Rooke is your duelist, Remain 1. Remove from the game after use. Limit 2 per deck. | `signature_strike_05` |
| Sir Edric Rooke | Edric's Training | Strike | Strike doing +2 Energy. Hit: Draw the bottom card of your discard pile. Remove from the game after use. | `signature_strike_06` |
| Sir Edric Rooke | Edric's Committed Cut | Art | Endurance 3. Strike doing +4 Energy. If your duelist is aspect 2 or higher, +4 wounds and Focused. Hit: Search your Life Deck for a Drill and put it into play. | `signature_art_04` |
| Sir Edric Rooke | Edric's Truce | Combat | Use this card after an attack against you succeeds. Stops a Strike or an Art. | `signature_combat_01` |
| Sir Edric Rooke | Edric's Vow | Combat | Sir Edric Rooke only. Attach this card to your Dame Alder Rooke. While attached, when entering Combat, you may draw the bottom card of your discard pile. Dame Alder Rooke may have only 1 "Edric's Vow" attached. | `signature_combat_06` |
| Sir Edric Rooke | Edric Carves First | Non-Combat | Use in Combat: Search your Life Deck for a Seal and put it into play. | `signature_noncombat_07` |
| Sir Edric Rooke | Edric Waits for Low Water | Non-Combat | Use in Combat: Look at the top 7 cards of your Life Deck and put every Non-Combat card among them into play. Shuffle the rest back. | `signature_noncombat_10` |
| Sir Edric Rooke | Edric's Retaining Drill | Drill | Your Seals cannot be captured. | `signature_drill_05` |
| Gideon Mourne | Mourne's Frantic Rush | Strike | Strike doing +1 Energy. Hit: Raise your Fervor 1. Remain 1. Remove from the game after use. | `signature_strike_20` |
| Gideon Mourne | Mourne's Stance | Strike | Stops a Strike. Stops all Strikes performed against you for the remainder of Combat. Remove from the game after use. | `signature_strike_03` |
| Gideon Mourne | Mourne's Jolting Arc | Art | Art. Your opponent may not perform Strikes for the remainder of Combat. Lower your opponent's Fervor 2. Remove from the game after use. | `signature_art_07` |
| Gideon Mourne | Mourne Takes the Measure | Non-Combat | Use this card when your opponent would win by Ascension. Your opponent loses one Aspect. Remove from the game after use. Limit 1 per deck. | `signature_noncombat_05` |
| Gideon Mourne | Mourne's Plans | Non-Combat | Use in Combat: Search your Life Deck for a Seal and put it into play. Remove from the game after use. | `signature_noncombat_08` |
| Gideon Mourne | Mourne's Smirk | Non-Combat | Use in Combat: Search your Life Deck for a Seal and put it into play. | `signature_noncombat_09` |
| Gideon Mourne | Mourne's Quickness Drill | Drill | When entering Combat, draw the bottom card of your discard pile. | `signature_drill_03` |
| Corin Thrace | Corin's Practiced Guard | Strike | Stops a Strike. Raise your Fervor 1. Search your discard pile for a Drill and put it into play. | `signature_strike_26` |
| Corin Thrace | Corin Throws Smoke | Art | Art. Hit: End Combat. | `signature_art_13` |
| Corin Thrace | Corin's Suppressing Shot | Art | Art. Hit: Your opponent may not perform Arts for the remainder of Combat. | `signature_art_12` |
| Corin Thrace | Corin's Threefold Bolt | Art | Art dealing 2 wounds. Remain 2. Remove from the game after use. | `signature_art_08` |
| Corin Thrace | Corin's Conditioning | Non-Combat | When entering Combat, raise your Fervor 1, raise your duelist's Energy to full, and draw the bottom card of your discard pile. Remove from the game after use. | `signature_noncombat_02` |
| Halden Quarr | Quarr Shrugs It Off (Steel) | Strike | Halden Quarr only. Stops a Strike or an Art. Remain 1. If used only once this Combat, shuffle it into your Life Deck at the end of Combat. Remove from the game after use. Limit 2 per deck. | `signature_strike_25` |
| Halden Quarr | Quarr's Crushing Blow (Steel) | Strike | Endurance X. X = 6 if Halden Quarr is your duelist, otherwise 3. Strike doing +2 wounds. If Halden Quarr is in control, +3 Energy and your opponent discards a Non-Combat card in play of your choice. | `signature_strike_28` |
| Halden Quarr | Quarr's Roar (Steel) | Strike | Art dealing 6 wounds. If Halden Quarr is in control, your opponent may not use Combat cards for the remainder of Combat. Remove from the game after use. | `signature_strike_27` |
| Sable Draik | Sable's Black Hands | Art | Sable Draik only. Art dealing 6 wounds. For the remainder of Combat, damage from your attacks cannot be prevented. If you have 2 or more Allies in play, Remain 1. Remove from the game after use. | `signature_art_06` |
| Sable Draik | Sable's Lingering Curse | Art | Art dealing 5 wounds. Hit: Attach this card to the personality in control. While attached to the personality in control: Your Arts do +2 wounds. | `signature_art_10` |
| Sable Draik | Sable's Reckoning | Art | Focused Art dealing 5 wounds. Set your Fervor to 2. Set your opponent's Fervor to 2. Hit: You may shuffle your removed Allies into your Life Deck. Remove from the game after use. | `signature_art_05` |
| Marrow | Marrow's Appraisal | Combat | Look at your opponent's hand and choose a card. They discard it. | `signature_combat_04` |
| Marrow | Marrow's Retinue | Combat | Marrow only. Search your Life Deck for up to 2 Allies and put them into play at full Energy. | `signature_combat_09` |
| Siphon | Siphon's Sidestep | Strike | Siphon only. Stops a Strike. Search your Life Deck for a Storm card and put it into your hand. Remove from the game after use. | `signature_strike_24` |
| Siphon | Siphon's Drain | Art | Art. Your opponent removes a Drill in play of your choice from the game. | `signature_art_03` |
| The Fortress | The Fortress' Iron Bulwark | Strike | Stops a Strike. Stops all Strikes performed against you for the remainder of Combat. Remove from the game after use. | `signature_strike_04` |
| The Fortress | The Fortress' Arcane Aegis | Art | Stops an Art. Stops all Arts performed against you for the remainder of Combat. Remove from the game after use. | `signature_art_01` |
| Brann Draik | Brann's Shakedown | Strike | Strike doing +4 Energy. If Brann Draik is in control, your opponent discards a Non-Combat card in play of your choice and capture a Seal. Hit: Search your Life Deck for an Ally and put it into play at Energy 4. | `signature_strike_16` |
| Cull | Cull's Absorbing Drill | Drill | Stops an Art. Costs 2 life cards to use. | `signature_drill_02` |
| Dame Alder Rooke | Alder's Deluge | Combat | Dame Alder Rooke only. Your opponent discards all Non-Combat cards in play. Remove from the game after use. | `signature_combat_05` |
| Halvard Draik | Halvard's Twin Cut | Strike | Focused Strike doing +4 Energy. If Halvard Draik is in control, your opponent discards a card from hand. If Halvard Draik is in control, stops a Strike. Hit: Search your Life Deck for an Ally and put it into play at Energy 4. | `signature_strike_17` |
| Mercy | Mercy Smiles | Non-Combat | Stops a Strike. If a Construct personality is in control, search your discard pile for a Construct card and put it into your hand. Remove from the game after use. | `signature_noncombat_01` |
| Scorn | Scorn Smirks | Combat | Your opponent removes all Drills in play from the game. Remove from the game after use. Limit 1 per deck. | `signature_combat_07` |
| Sledge | Sledge's Set Stance | Art | Art. If your duelist is a Construct personality, search your Life Deck for a Construct card other than "Sledge's Set Stance" and put it into your hand. Remove from the game after use. | `signature_art_11` |
| Torvan Hask | Hask's Flying Kick | Strike | Strike doing triple the Base Damage. | `signature_strike_07` |
| Vesna Draik | Vesna's Ambush | Strike | Focused Strike doing +4 Energy. If Vesna Draik is in control, for the remainder of Combat, your opponent's Allies cannot take control or take damage. Hit: Search your Life Deck for an Ally and put it into play at Energy 4. | `signature_strike_18` |
