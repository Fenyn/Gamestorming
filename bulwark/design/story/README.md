# Story scripts

One file per cutscene, and **each script is the single source for its scene** — beats, lines,
staging, and notes. The outline docs (`../intro.md`, `../tutorial.md`) carry full beats only for
scenes that are not yet scripted; once a scene's script lands here, the outline collapses to a
stub pointing at it, so every scene has exactly one place to edit. The JSON under
`data/dialogues/` is authored from these scripts and must match them — where script and JSON
differ, the script doc wins. Currently the intro JSONs are empty placeholders; they get
rewritten from these docs once the scripts are approved.

Voice authority is `../prose_style.md`. Read it before touching any line.

## Script format

Every construct maps 1:1 onto the dialogue JSON vocabulary
(`scripts/data/dialogues/DialogueData.cs`), so translation is mechanical:

| Script | JSON |
|---|---|
| `**Name** *(emotion)*: text` | `line` step — speaker id lowercase; emotion omitted → `neutral` |
| `[direction]` on its own line | staging step (fade, actor move, sfx, pause) — placeholder staging is marked as such |
| **Choice** block | `choice` step — the line directly above is the prompt; numbered options are player lines; indented lines under an option are its inline continuation; all options converge unless marked |
| `[set flag_name]` | `flag` effect step |
| `{player_name}` | runtime token, resolves to the chosen name |

Conventions:

- `###` headings restate the beats from the outline doc, in order, so script and outline stay
  checkable against each other.
- Emotion tags are portrait *hints* (weary, bright, dry, sharp...). The final portrait set is not
  decided; anything untagged is neutral.
- Flavor choices carry no effects and converge — say so in the choice block header.
- ASCII apostrophes only (`'tis`, never the curled autocorrect glyph).