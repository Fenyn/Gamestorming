# Kotodama (言霊)

A kanji sanctuary. Each kanji is a small spirit you invite into the yard by writing its form on a talisman. Words are flowers you plant and water by naming them. The yard starts as a clearing at a torii gate and grows into a shrine village as you learn. One session is one day at the sanctuary, 10 to 20 minutes. No timers, no currency, nothing dies. Every click is a retrieval.

**Engine:** Godot 4.6, GDScript, godot-base junction (save, screens, sfx)
**Genre:** Cozy daily collection sim, spaced repetition underneath
**Learner:** Knows hiragana and katakana. Starts at JLPT N5 kanji.
**Inspirations:** WaniKani (order, ladder), Animal Crossing (real days, the day ends, seasons), Stardew (watering, a place that fills in), Neko Atsume (nothing dies)

Decisions settled 2026-10-10: spirit sanctuary over smithy, calligrapher and sand garden. Blob body look. Kanji and words both reviewed. Zones by radical family. 5 new kanji a day. JLPT order with components first inside a level. Readings typed in romaji. Stroke drawing in the first slice, mouse only. Cozy progressive buildup, no economy, zones and decorations appear at learning milestones. Words are flowers. Spirits are invited, not hatched. Shrines for settled spirits, visitors, seasons planned in. Learning loop first, building loop second.

---

## Tone

- No timers, streaks, failure counts or currency. Nothing to lose.
- A miss shows the answer and the parts. The spirit "was shy today". Stage drops are silent.
- The day ends when the invitations and the chores are done. The yard says it is evening. An optional practice bell offers more drills on weak items, never required.
- Seasons and weather follow the real calendar and change only the look.

## Things in the yard

| Thing | What it is | Reviewed? |
|---|---|---|
| Spirit | One kanji. Ink glyph on a blob tinted by its zone, eyes above the glyph. Idles at its yorishiro (a stone, tree or post) in its zone. | Yes: call it, what it is, its form |
| Flower | One word. Planted in a bed in the zone of its first kanji. Blooms bigger as its stage rises, droops when overdue. Kana tail on the stem for okurigana (食べる). | Yes: water it, what it is |
| Shrine | A burned spirit's yorishiro becomes a small hokora. The spirit settles there and only answers rare calls after. | Rare |
| Part | A component that is not a kanji on its own (氵, 亻, 宀). A body piece in lessons. | No |
| Visitor | A pilgrim at the gate asking for a word. Slice 2. | No |

Spirit growth by stage: new is small and translucent, guru is full size, master is big, burned is big with a halo and a shrine.

## Inviting a spirit (dawn)

Shinto frame: kanjō, inviting a kami to dwell. New spirits are nameless lights beyond the torii.

1. Its parts, shown as pieces of spirits you already know. Pick them from a rack of six.
2. The stroke order plays.
3. The keyword and its main readings.
4. Write its form on an ofuda with a faint guide. The light settles into the talisman.
5. Carry the ofuda to a free yorishiro in its zone. The spirit takes shape there.
6. Plant its first words: reading and meaning shown, type each reading once, a seed goes in the bed.

Up to 5 kanji and 15 word seeds a day. Words whose spirits are all present are planted the same way.

## A day

1. **Dawn.** Invitations, see above.
2. **Day.** Spirits with a bubble want calling. Drooping flowers want water. One drill per click. Pass: a glow, stage up. Miss: the answer and the parts shown, stage drops two, it asks again before dusk.
3. **Wanderers.** Overdue spirits stand dim at the woods' edge. Overdue flowers droop. Both are served first.
4. **Dusk.** Tally: called, watered, invited. The yard at evening. Milestone pieces appear overnight.

Review cap 60 a day. Overflow waits with no extra penalty.

## Drills

| Drill | On | Input | Pass rule |
|---|---|---|---|
| Call it / water it | spirit, flower | Type romaji, kana shows as you type | Kana matches a listed reading. Spirit: any main reading. Flower: the word's reading. Katakana words accept hiragana. |
| What it is | spirit, flower | Pick 1 of 4 meanings | Distractors are same-zone or shared-part items |
| Its form | spirit | Draw strokes on a canvas, no guide | Stroke check below |

Rotation per item: call → what → (spirit only) form → call. A miss on any drops the stage. Shrines only come back as rare call drills.

## Stroke check (mouse)

- Canvas 256×256. Expected strokes come from KanjiVG, resampled to polylines in a 109×109 box.
- One stroke is mouse down to mouse up. Stroke count must match.
- Each stroke in order: start within 22% of the box diagonal of the expected start, end within 22% of the expected end, direction within 50°, length at least 40% of expected.
- A wrong stroke flashes and shows that stroke's guide. One retry per stroke. A stroke wrong twice is drawn for you and counts as a wrong stroke. One wrong stroke per three strokes is allowed, so a kanji of up to three strokes fails on one, longer kanji on two.
- Invitations show a faint full guide. Stage 1 and 2 form drills show the first stroke's start. Guru and up show nothing.
- All tolerances are exported on the canvas scene.

## Review ladder

| Stage | Due after | Look |
|---|---|---|
| 0 new | same day | small, translucent |
| 1 | 1 day | small |
| 2 | 3 days | small |
| 3 guru | 7 days | full |
| 4 | 14 days | full |
| 5 master | 30 days | big |
| 6 | 90 days | big |
| 7 burned | never | big, halo, shrine |

Miss: drop 2 stages, floor 1, re-ask today. Days roll at 4 am local.

## Zones

A spirit lives in the zone of its Kangxi radical (KANJIDIC2 `rad_value`). The zone sets the blob tint. A flower lives in the zone of its first kanji. The full 214-radical map lives in `data/zones.json`; anything unlisted goes to the meadow.

| Zone | Main radicals | Tint |
|---|---|---|
| Pond | 水 氵 冫 魚 舟 | blue |
| Sky field | 日 月 雨 气 夕 風 | gold |
| Hearth | 火 灬 食 | red |
| Grove | 木 艹 竹 禾 米 麦 | green |
| Path | 人 亻 彳 辶 足 走 止 | sand |
| Hill | 山 土 石 阝 田 | brown |
| Hall | 言 口 心 忄 音 見 示 | purple |
| Forge | 金 刀 刂 弓 矢 戈 車 斤 | steel |
| House | 宀 門 女 子 广 戸 穴 | rose |
| Body | 手 扌 目 耳 肉 身 自 頁 首 面 | peach |
| Beasts | 犬 犭 馬 鳥 虫 牛 羊 豕 鹿 | moss |
| Loom | 糸 衣 衤 巾 皮 革 | teal |
| Meadow | everything else (一 二 十 大 小 王 白 立 貝 生 ...) | grey-green |

## Growth by milestones

Day one is the torii, the hearth and the woods. The woods are the kanji you have not met. Pieces appear overnight, nothing is bought or placed. Numbers are placeholders to tune.

| Milestone | What appears |
|---|---|
| First spirit of a zone | The zone is cleared from the woods, tier 1 (a puddle, a sapling, a cairn) |
| 10 spirits in a zone | Tier 2 (reeds and a dock, a grove path, a stone stair) |
| 5 shrines in a zone | Tier 3 (a bridge and lanterns, a sacred tree with shimenawa) |
| 50 flowers in bloom | Flower beds get borders and a watering stone |
| All N5 kanji invited | The torii is repainted vermilion, stone lanterns line the main path |
| All N4 kanji invited | A bell tower, the practice bell moves there |
| Each later level | One landmark per level, to be picked |
| First visitor served | A bench at the gate |

## Seasons and weather (slice 2)

By real date. Spring: sakura petals over the paths. Summer: deep green, cicadas. Autumn: momiji in the grove. Winter: snow on the shrines. Rain on some days, snow in winter. Weather changes the look only, never the schedule.

## Visitors (slice 2)

A pilgrim at the gate asks for a word, given in English or kana. You find its flower and name it. Only words at guru or above are asked for. One visitor a day at most. A served visitor leaves a small gift in the yard: a paper crane, a stone, a lantern.

## Order

- Levels: JLPT N5, N4, N3, N2, N1 from OpenJLPT.
- Inside a level a kanji comes after every component kanji it contains. Non-kanji parts arrive with the first kanji that uses them. Ties by stroke count, then KANJIDIC2 frequency.
- A word becomes plantable once all its kanji are invited. Words are taught by level then frequency, at most 3 per new kanji per day, 15 a day.

## Typing

Romaji to kana converter in GDScript (wāpuro rules: shi/si, chi/ti, tsu/tu, fu/hu, ji/zi, doubled consonant → っ, n/nn/n' → ん, kya kyu kyo, "-" → ー). The kana string is shown live under the input. No IME.

## Data

`tools/build_data.py` downloads and writes everything the game reads. Nothing is parsed at runtime.

| Source | Gives | Licence |
|---|---|---|
| OpenJLPT | JLPT level per kanji and word, word readings and meanings | CC BY-SA 4.0 (levels from Jonathan Waller's lists, CC BY) |
| KANJIDIC2 | kanji meanings, readings, Kangxi radical, stroke count, frequency | EDRDG, CC BY-SA |
| KRADFILE | visible components per kanji | EDRDG, CC BY-SA |
| KanjiVG | stroke order paths | CC BY-SA 3.0 |
| Noto Sans JP | glyphs | OFL |

Outputs: `data/kanji.json`, `data/words.json`, `data/parts.json`, `data/zones.json`, `data/strokes/<hex>.json` (polylines), `assets/glyphs/<hex>.png` (32 px thresholded ink glyph, one per kanji and part). Spirit = zone blob sprite + glyph sprite + eyes, composed in the scene. `CREDITS.md` carries the attributions.

## Art

- Yard tiles: Mana Seed Gentle Forest 32×32 (pond, waterfall, trees) and Iconic Homestead (hall, hearth flames). Owned packs, kept out of the repo like zenith's, so the web build goes through `web-prebuilt/`.
- Shrine props are not in any owned pack: torii, hokora, ofuda, stone lantern, shimenawa, bell. About six sprites, drawn by code under the repo's palette-locked pixel rule, Mana Seed palette.
- Spirits: procedural, see Data. Pixel look comes from thresholding Noto at 22 px.
- Flowers: one sprite per bloom stage, four stages, tinted by zone.
- Text: Noto Sans JP for kanji and kana. UI chrome from the Kenney borders already in the library.
- No avatar. The cursor is the keeper.

## Slices

**Slice 1, the learning loop.**
1. Data pipeline and CREDITS.
2. Yard scene: zones at tier 1 that open on their first spirit, spirits idling at yorishiro, flower beds, bubbles and droops, click to drill.
3. Invitation: part pick, stroke animation, keyword, guided ofuda, placing, seeds.
4. Three drills, romaji converter, stroke canvas.
5. Ladder, save through godot-base, day roll, dusk tally.

**Slice 2, the building loop.** Zone tiers and milestone pieces, shrines, seasons and weather, visitors, the practice bell.

**Later.** Lookalike check (two talismans, one wrong), mnemonic stories (tone approval first), sound, tablet stroke mode, landmarks per level.

## Risks

- Pacing is untested. Five invitations plus 40 drills is guessed at 12 minutes.
- Mouse strokes need the tolerances tuned against your hand. Too strict frustrates, too loose teaches nothing.
- The blob look may feel flat next to the glyph-with-eyes look. The sprite is layered, so it is cheap to revisit.
- Six shrine props drawn from scratch is the only art not from a pack.
- No official JLPT lists exist. OpenJLPT uses community lists.
- KRADFILE parts are visual, not etymological. Fine for mnemonics, wrong as linguistics.
- Mana Seed is a European forest glade. The shrine props carry the whole Japanese feel.
