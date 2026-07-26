# Intro Scene 0 — "The Frontier" (script)

**Single source for Scene 0** — beats, lines, staging, and notes all live here (`../intro.md`
keeps only a stub and the cross-scene flow). Wins over the JSON
(`data/dialogues/intro/scene_0.json`, which is authored from this doc and currently lags it).
Format conventions: `README.md`. Voice authority: `../prose_style.md`.

- **Goal:** establish the decayed frontier through what the player sees; fold Elara in as the
  third member of the party — mutual benefit, not niceness.
- **Cast:** `player`, `fenwick`, `elara` (her knowledge boundaries: `../characters/elara.md` —
  first foray into human lands, everything at a foreigner's remove).
- **Staging:** Stardew-style top-down cutscene on `scenes/intro/road.tscn`. Every `[bracket]` line
  is a literal `CutsceneDirector` command, and nothing outside that vocabulary is authored: `fade`,
  `wait`, `move`, `face`, `enter`, `exit`, `camera`, `prop`, `sfx`. Parentheticals after a speaker
  name are **portrait emotion hints only** (one word), never physical action — the director cannot
  render hands, glances, or held objects. Business that is not a walk, a cardinal turn, a camera
  pan, or a held beat has to be spoken aloud or cut.
- **Markers:** existing in `road.tscn` — `MarkPlayerStop`, `MarkFenwickStop`, `MarkElaraEnter`,
  `MarkElaraLevel`, `MarkTrackBend`, `MarkTrackExit`, `MarkPilings`. **Needs placing:**
  `MarkFenwickBend` (beside `MarkTrackBend`, where Fenwick catches up) and `MarkTrackHead` (a few
  steps up the track, where Elara steps past the pair). `MarkElaraLevel` wants repositioning to the
  bend cluster rather than the river, since the conversation has moved off the road by the time she
  arrives.
- **Choices:** one, flavor only, converges, no effects — three options, all posture.
- **Flags:** sets `intro_scene_0` at the end.

---

## Beat — The dead bridge

[fade in 1.0]
[move `player` -> MarkPlayerStop @120]
[move `fenwick` -> MarkFenwickStop @120]
[camera -> MarkPilings 2.0]

**Fenwick**: Ah.

**Player**: Aye.

**Fenwick**: That would be our bridge.

**Player**: What is left of her.

[camera -> return]

**Fenwick**: Is there any getting across?

**Player**: Not here. The banks are cut too deep to wade, and I'd go straight to the bottom with
the mail on.

**Fenwick**: How long has she been lying there, do you reckon?

**Player**: Five years, near enough. There are saplings coming up through the roadbed thick as my
thumb. Nothing has crossed this way in a long while.

**Fenwick**: Five years, and nobody has come out to fix her?

**Player**: It is a crown bridge on a road nobody rides, Fen. Who was there out here to send word
of it?

**Fenwick**: You said as much about the milestone. And the waystation. And that chapel with the
tree coming up through the roof.

**Player**: And when we reach the post I'll write it up, and they'll hear about all four.

## Beat — The way round

[move `player` -> MarkTrackBend @70]

**Fenwick**: I'll not hold my breath awaiting their response. The way round is plain enough, at
least.

[move `fenwick` -> MarkFenwickBend @100]

**Player**: There is no telling how far it runs before it finds a crossing.

**Fenwick**: And it goes in under the trees.

**Player**: It does.

**Fenwick**: ...If something out there eats me, I'll want my funeral done properly. Cooked meats,
maidens weeping, and someone to read a poem over whatever is left.

**Player**: Would you settle for a hole and a hat on a stick?

**Fenwick** *(cheerful)*: I'll give up the maidens. The cooked meats are not negotiable, and I can
see I shall have to set the whole of it down in writing so there is no arguing over the spread on
the day. I'll begin drafting the moment we—

## Beat — Elara on the road

[enter `elara` -> MarkElaraEnter]

**Elara** *(calling)*: That track is the one you want. The bridge has been down six years.

[face `player` west]
[face `fenwick` west]

**Fenwick**: Six. You were a year light, {player_name}.

**Player**: I said mayhap more.

[move `elara` -> MarkElaraLevel @140]

**Elara**: The shallows are half a day up that track. You will want the light.

[move `elara` -> MarkTrackHead @90]

**Fenwick**: Madam. A moment.

## Beat — Introductions

[face `elara` west]

**Elara**: That is a great deal of iron for a pair of simple travelers.

**Fenwick**: We are crownguard, madam, not brigands. The iron came with the posting.

**Elara**: The last men who told me that took my purse.

**Player**: Then read this. Orders under the crown's seal.

[wait 1.0]

**Fenwick**: And walk it with us, if you like. We are for the same crossing, at least.

**Elara**: {player_name} and Fenwick. Headed to the old outpost?

## Beat — The destination named

**Fenwick**: If it still stands.

**Elara**: It stands, though I had taken it for abandoned.

**Player**: Surely there will be someone in it. They'd not send us to an empty post.

[wait 1.0]

**Elara**: I have passed that turn two years and never once seen smoke over the walls. That is all I
know of it.

**Fenwick**: I had hoped for a livelier account.

**Choice** *(posture; flavor only, converges, no effects — the prompt is Elara's line below)*

**Elara**: I have met nobody on that road going toward it, only folk coming away. Families, mostly,
with the whole house on a mule. One even had his front door lashed on top of it. What is out there for
the two of you?

1. **"It is my first post. I mean to make something of it."**
   - **Elara**: They send new men out here?
   - **Fenwick**: We have no house behind either of us, and the good postings go elsewhere.
2. **"A hot meal and a roof, if we are lucky."**
   - **Fenwick**: The meal is seen to, though I make no promises about the roof.
3. **"I have my orders. Is that not reason enough?"**
   - **Elara**: I meant no offense, good sir. I am but curious.

**Elara**: How many more are coming behind you?

**Player**: None. This is the relief.

[wait 1.5]

**Fenwick**: You are meant to say something encouraging now.

**Elara**: I know.

## Beat — Terms

**Elara**: The shallows are not easy to find if you have never seen them.

**Fenwick**: Is that an offer?

**Elara**: It is a warning. The offer is that I walk in front.

**Fenwick**: We'd take it and gladly. And a name, if you can spare one.

**Elara**: Elara. I will see you as far as the gate. I have wanted a look inside that place for two
years, and I would as soon not walk this road alone.

**Player**: Has something happened on it?

**Elara**: More brigands than there used to be. And the farms up that way are losing stock. Not
taken, though. Torn open in the pen and left lying.

**Player**: What hunts out that way? Bear, wildcat?

**Elara**: They named nothing. Only that it came at night, and the pen wall was pushed in rather
than jumped.

[wait 1.0]

**Fenwick** *(bright)*: All the more reason to keep together. Take heart, madam: whatever else this
road does to us, I'll see that we eat well.

## Beat — The track east

**Elara**: Then we should move. The light will not wait on us.

**Fenwick**: Supper on the far bank, then. What grows out here that is worth putting in a pot?

**Elara**: Come along and I will tell you.

[exit `elara` -> MarkTrackExit @110]
[exit `fenwick` -> MarkTrackExit @110]
[exit `player` -> MarkTrackExit @110]
[fade out 1.0]
[flag intro_scene_0]

---

## Open items

- **Markers to place in `road.tscn`:** `MarkFenwickBend` (beside `MarkTrackBend`, where Fenwick
  catches up) and `MarkTrackHead` (a few steps up the track, where Elara steps past the pair).
  `MarkElaraLevel` needs repositioning from the river to the bend cluster.
- Facings are placeholders pending final marker geometry — check every `face` step once the markers
  are placed.
- `crownguard` is introduced in this script and appears nowhere else in the repo. Propagate to
  `../characters/player.md` and `../world.md`.
- `data/dialogues/intro/scene_0.json` still holds the previous draft; regenerate from this doc once
  all three intro scripts are locked.
