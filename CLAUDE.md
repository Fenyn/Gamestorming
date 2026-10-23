# Gamestorming — repo-wide rules

Project-specific rules live in each project's own CLAUDE.md (`delve/CLAUDE.md`, `bulwark/`). This file governs everything in the repo, and above all how you write to me.

## A screen is not a narrator (mandatory, every project)

Before you write or change any text a player sees (a screen, a HUD, a menu, a tooltip):

1. Keep only labels, values, characters speaking, events, and button text.
2. Everything else is narration. Cut it if the player can already see it or will learn it by playing. If it is a rule they need but can't observe (a threshold, a multiplier, a hidden cause), move it to a hover on the thing it explains.
3. Write hovers as one or two sentences of plain fact. No wordplay, no "fewer X, more Y", no reassurance, no "you should".

This applies to new text and to any existing text you touch while editing a screen.

Before you write any text a player or reader sees (screens, dialogue, card text, store pages, docs for me), use the `no-ai-tells` skill. The hook `.claude/hooks/ai_tells.py` checks the result after every write.

## Pixel art is drawn by code (every project)

This applies when you draw a sprite from scratch, and when you write a prompt asking an agent to draw one.

1. Ask for code that draws the sprite, not for "an image". The code is either a palette-indexed array (one row of indices per pixel row) or explicit draw calls (Aseprite Lua, a PIL canvas).
2. State the grid size in the prompt, for example 32×32.
3. List every allowed colour in the prompt as a hex value. Index 0 is transparent. Nothing outside the list is allowed.
4. After drawing, check the output's colours against the list. A colour that is not on the list fails the sprite.

A model that picks its own colours drifts off-palette, and when it is asked for an image it produces pixels with no fixed grid. A locked grid and hex list give the same result every time.

Pack art still comes first. Crop an authored sprite from a pack before drawing one. This rule covers only art drawn from scratch.

### Aseprite

We use Aseprite, and it can be scripted to build sprites and to inspect the results.

- Executable: `E:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe`.
- Run a Lua script headless with `Aseprite.exe -b --script build.lua`. Pass values with `--script-param key=value` and read them from `app.params`.
- Export a scaled preview to look at: `Aseprite.exe -b sprite.aseprite --scale 8 --save-as preview.png`. Look at the preview at full size before calling a sprite done.
- For the palette check in step 4, a Lua script can walk `app.image` pixels and print every colour that is not in the hex list.
- Claude also has the `aseprite` MCP server (`.mcp.json`, source in `G:\aseprite-mcp`). `run_lua_script`, `get_color_stats`, `export_sprite` and `get_pixels_rect` cover the same steps.
- Existing Lua helpers and kit parts live in `F:\UnityNVME\Art\_Zenith\Kit\` and `F:\UnityNVME\Art\_Zenith\Tests\_scripts\`.

## Codex / Astra access

The `codex@openai-codex` Claude plugin is enabled for this repo. Codex uses
`gpt-6-astra` by default via `.codex/config.toml` and the existing Codex login.

- From Claude, use `/codex:rescue --model gpt-6-astra <request>` to ask Astra for help.
- Add `--resume` for a follow-up or `--fresh` for a separate task.
- Use `/codex:review` for review, `/codex:status` for job status, and `/codex:setup` to check readiness.
- Use `/codex:transfer` to transfer Claude conversation context to a resumable Codex thread.
- From PowerShell, `codex -m gpt-6-astra` opens Astra directly in the current directory.

When I ask you to consult Astra, use the Codex plugin with the explicit model
`gpt-6-astra`. Include relevant context and file paths because a rescue task does
not automatically share the entire Claude conversation. Request investigation
only unless I ask for changes. Avoid simultaneous edits to the same files.

## Messages to me

I am scanning your messages while doing something else. Long messages get skimmed, and the line that needed an answer gets missed. You are writing a status note, not marketing copy.

- Put the result in the first line.
- Keep only what I will act on. Cut the request I already made, the steps I watched you take, and any summary that repeats the first line.
- Be precise. Use the real file name, the real value, the real error text.
- Put questions last, each on its own line.
- Always keep risks, mistakes, and guesses you made. Those stay in even when everything else goes.
- Use plain sentences. One idea each. State the fact and stop.
- Stay polite. Short does not mean clipped. Suggest things instead of ordering me around, so "you can run npm install" rather than "run npm install". A please or a thanks costs one word.

Do not write for effect. If a sentence sounds quotable, rewrite it as a plain statement. Avoid:

- "load-bearing", "worth stating plainly", "worth naming", "worth flagging", "full stop", "carries the argument", "the trap is", "the real question is", "the honest answer is", "to be clear", "let me be direct"
- "real" or "actual" used for emphasis, like "a real tension" or "the actual problem"
- Any sentence that announces a point instead of making it. If a line can be deleted without losing information, delete it.
- "This is not X, it is Y" and "it isn't just X, it's Y"
- Sentence fragments used for emphasis, like "Not a bug. A design choice."
- Em dashes. Colons and semicolons used as a dramatic pause. Write "and", "but", or "because", or start a new sentence.
- Opening with agreement or praise, like "You're absolutely right" or "Great catch".
- Grading your own work: "successfully", "perfect", "now works flawlessly", "production ready".

Say what changed and what it means, in the words a coworker would use out loud. A good update reads like this:

> auth.ts: token refresh now runs only within 5 minutes of expiry. It used to run on every request. I also added logging for the 401s that were being dropped silently.
>
> Do you want the refresh window at 60 seconds instead of 5 minutes?
