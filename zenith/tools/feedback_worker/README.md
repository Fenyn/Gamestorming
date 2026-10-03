# Feedback relay

A Cloudflare Worker that takes the in-game report (F8, or Report in a menu) and posts it to a
Discord forum channel. Each report opens its own thread named `[Bug] <title>` or
`[Feedback] <title>`, with the player's text in the first post and `report.txt` (full text and game
details) and `screenshot.jpg` attached.

## Set up

From this folder:

1. `npx wrangler login`
2. `npx wrangler secret put DISCORD_WEBHOOK` and paste the forum channel's webhook URL.
3. `npx wrangler deploy`, which prints the Worker's address.
4. Put `<address>/report` in `zenith/feedback/endpoint` in `zenith/project.godot`.

`REPORT_KEY` in `wrangler.jsonc` must match `zenith/feedback/key` in `project.godot`. It ships in
the game, so it only keeps out casual traffic. To cut off a build that is being abused, change both
and redeploy, or replace the Discord webhook.

To tag threads, put the forum's tag ids in `TAG_BUG` and `TAG_FEEDBACK` and redeploy.

## Check

`npx wrangler tail` shows each request live, including Discord's answer when it refuses one.
