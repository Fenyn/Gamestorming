---
name: no-ai-tells
description: Check and rewrite user-facing text so it does not read as machine-written, using the patterns from Wikipedia's "Signs of AI writing" plus this repo's banned phrases. Use before writing or editing anything a player or reader sees (UI strings, tooltips, hovers, dialogue, narration, card text, tutorial lines, store pages, patch notes, READMEs, design docs for the user), when the user asks to "de-AI", humanise or clean up text, or when the AI-writing hook reports hits.
---

# No AI tells

Source: https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing (read 2026-10-18). The page
explains why the patterns appear. A model drifts toward the most common phrasing, so specific facts
get replaced with generic, important-sounding ones. The fix is almost always the same: say the
specific thing in the plainest words.

The repo CLAUDE.md rules ("A screen is not a narrator", "Messages to me") still apply. This
checklist adds to them and does not replace them.

## The hook

`.claude/hooks/ai_tells.py` runs after every Write and Edit (project `.claude/settings.json`). It
scans only the text just written: string literals in code and data files, prose in .md, .txt, .csv
and .html. Log and error calls, comments, `tests/`, `dev/`, `addons/`, `.claude/`, memory files and
CLAUDE.md are skipped. Hits come back as context naming the line and rule.

- Treat a hit as a prompt to look, not as a verdict. Rewrite it unless it is deliberate: a
  character's voice, a literal meaning ("steady the blade", "a robust shield" as an item stat), a
  rule or keyword name, or a dictionary gloss.
- The scanner catches words and shapes. It cannot catch the content problems in section 1, so read
  the text yourself as well.
- To check existing files: `python .claude/hooks/ai_tells.py <file> [<file>...]` (exit 1 on hits).

## 1. Content

- **Puffed-up significance.** Cut sentences that say a thing is important, pivotal, a testament, a
  turning point, part of a broader trend, or that it left a mark. State what it does instead.
- **Superficial analysis.** Cut the trailing "-ing" clause that comments on the sentence before it:
  ", highlighting its...", ", ensuring...", ", reflecting...", ", creating a...".
- **Advert voice.** No "vibrant", "rich", "nestled", "in the heart of", "boasts", "immersive",
  "unforgettable", "embark on", "whether you're a... or a...", "dive into". Store pages say what the
  player does in the game.
- **Vague sources.** No "experts say", "many believe", "it is widely considered".
- **Challenges formula.** No "Despite these challenges..." or "future outlook" endings.
- **Generic over specific.** If a line could describe any game, character or card, replace it with
  the detail only this one has.

## 2. Words

Overused by models, so avoid unless the literal meaning is meant: additionally (to open a sentence),
align with, bolster, crucial, delve, emphasise, enduring, enhance, foster, garner, highlight (as
"emphasise"), interplay, intricate, key (as an adjective), landscape (abstract), leverage,
meticulous, multifaceted, pivotal, quietly, resonate, robust, seamless, showcase, tapestry,
testament, underscore, universally, valuable, vibrant.

- Use "is", "are" and "has". Not "serves as", "stands as", "functions as", "features", "offers".
- Use the short word: wrote, used, tried, moved, died. Not authored, utilised, attempted,
  relocated, passed away.
- Plain qualifiers and superlatives are human: "very", "perhaps", "the only", "the first".

## 3. Sentence shapes

- **Negative parallelism.** No "not just X, but Y", "it's not X, it's Y", "isn't about X",
  "no X, no Y, just Z", "Y rather than X". Say Y.
- **Rule of three.** Do not list three adjectives or three phrases by reflex. Use the number of
  items there are.
- **Staccato.** Three or more short flat statements in a row read as the trope ("Game 2 starts in 18
  seconds. Bram opens it. Same decks."). Join related facts into one sentence or drop one. Shouted
  barks and questions in dialogue are speech and are fine.
- **Elegant variation.** Call a thing by the same name every time. Do not rotate synonyms.
- **Summaries.** No "In summary", "Overall," or a closing line that restates the paragraph.

## 4. Punctuation and format

- No em dashes. Use a comma, a full stop, "and", "but" or "because". A dialogue line cut off
  mid-word uses "..." in this repo.
- No emoji as decoration.
- In docs: sentence-case headings, bold only where a reader must not miss it, and prose instead of
  lists whose items each open with a bold label and a colon.

## 5. Chatbot residue

Never in shipped text: "I hope this helps", "let me know", "feel free to", "Certainly!",
"great question", "it's important to note", "worth noting", "based on available information",
placeholder brackets like `[character name]`.

## 6. House list (repo CLAUDE.md)

"load-bearing", "worth stating plainly", "worth naming", "worth flagging", "full stop", "carries the
argument", "the trap is", "the real question is", "the honest answer is", "to be clear", "let me be
direct", and "real" or "actual" used for emphasis.

## How to use it

1. Before writing, decide what the reader needs and does not already know. If nothing, write
   nothing (CLAUDE.md "A screen is not a narrator").
2. Write the plain version first.
3. Read it against sections 1 to 6. For dialogue, also follow the `ivalice` skill.
4. Fix anything the hook reports, or say in your message why a hit was kept.
