# Gamestorming — repo-wide rules

Project-specific rules live in each project's own CLAUDE.md (`delve/CLAUDE.md`, `bulwark/`). This file governs everything in the repo, and above all how you write to me.

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
