# Duel server

Every online duel is refereed on the duel server. Run it from the editor binary with `--headless --path zenith -- --server --port=7777` or from the exported binary with `--headless -- --server --port=7777`. Both players connect out to it, one opens a room and gets a five-letter share code, the other joins with the code, and the server runs that room's duel with the only rules engine (`scenes/server.tscn`, `scripts/server/duel_server.gd`, rooms in `Net`). Clients hold no hidden information and pick only from the options the server sends, so a modified client gains nothing. Because players connect out to a fixed address, nobody forwards ports and no NAT punchthrough or relay is needed.

The client reads the address from the project setting `zenith/net/duel_server` (`project.godot`, `[zenith]` section); `--dev-server=host:port` overrides it for one run.

## Size

Measured with `tools/load_probe.gd`: about 365 KB and 6 ms of CPU per command per live duel, 3.5 to 4.7 KB on the wire per update. The headless process idles near 100 MB. A 512 MB, 1 vCore box carries dozens of duels at once. Around 1,000 concurrent players (500 duels, roughly 165 commands a second) it would take one full core and about 1 MB/s; delta updates instead of whole views (the view build is 90% of the cost) and a second core cover that.

## Presence

Each client tells the other what its player is doing right now (`scripts/net/presence_state.gd`): the pointer as a point on the table plane in shared table coordinates (`TableLayout.to_shared`), the uid of a public table card under it, the slot index of a hovered hand card, and which pile, public card or panel is open (a Discard, Out or Relic pile by seat, an inspected public card by uid, the log, or "choosing" for any tray). It never carries a card id, a title, or the uid of anything in a hand, a Reserve or a Life Deck; a tray, including a Life Deck search, is only "choosing". It goes out only when something changed, at most 20 times a second, on its own `unreliable_ordered` channel (`Net.PRESENCE_CHANNEL`), so commands and updates never wait on it. The server relays it only to the other seat of the sender's started room, and a LAN host takes it only from its seated joiner during a duel; both run `PresenceState.sanitise` first (allowed keys and types only, point clamped to the table, slots and uids range-checked, strings capped and matched to a fixed list) and drop more than 40 messages a second from one peer. Presence never reaches a `DuelHost` or the `Referee`. The receiving client sanitises again and drops any uid its own view cannot see. Hotseat, vs AI and adventure send and draw nothing.

## Export the server

Once, in the editor: Editor, Manage Export Templates, download for this version. Then from the repo root:

```
$godot = "G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe"
& $godot --headless --path zenith --export-release "Linux server" build/server/eidolarch_server.x86_64
```

Export with the GDScript-only editor, not the mono one: a mono export of this project starts on the box, prints the banner and then sits idle without ever opening the port (seen 2026-09-18).

The preset (`export_presets.cfg`, "Linux server") is a dedicated-server export with the pack embedded, one file of about 80 MB. `build/` is ignored by git.

## Install on the box

Any Linux VPS with a public IPv4 works. Google Cloud's free e2-micro (`us-central1`, Debian 12, 1 GB egress a month) or a RackNerd yearly plan (512 MB is enough) are the cheap options. Open UDP on the port (7777 by default): on Google Cloud a firewall rule for the instance's network tag with `udp:7777`; on a plain VPS the install script adds a ufw rule if ufw is present.

```
scp build/server/eidolarch_server.x86_64 tools/server/install.sh root@<ip>:
ssh root@<ip> bash install.sh 7777
```

The script puts the binary in `/opt/eidolarch`, runs it as a system user under systemd (`eidolarch.service`, restarts on crash and on boot), and prints the service status. Re-run it with a new binary to update.

- Logs: `journalctl -u eidolarch -f` shows rooms opening, duels starting with their seed, and results.
- Stop or start: `systemctl stop eidolarch`, `systemctl start eidolarch`.

Then put `<ip>:7777` into `zenith/net/duel_server` in `project.godot` and export the Windows client (`--export-release "Windows Desktop" build/windows/eidolarch.exe`, same GDScript-only editor) to send to a friend. The Windows preset embeds the pack and stamps the exe with `icon.ico` (rendered from `icon.svg` with `magick -background none -density 512 icon.svg -define icon:auto-resize=256,128,64,48,32,16 icon.ico`) and the version fields set in `export_presets.cfg`.

## Update in one step

```
powershell -File zenith\tools\server\deploy.ps1
```

exports the server with the GDScript-only editor, uploads it with `scp`, re-runs `install.sh` over `ssh` (which restarts the service) and prints the last journal lines. `-SkipExport` uploads the last export, `-Server root@host` and `-Port N` change the target. It needs key-based SSH to root, so it never asks for a password. Every duel in progress ends when the service restarts; there is no drain yet.

## Check from home

```
& $godot --path zenith -- --dev-host-code --dev-server=<ip>:7777 --dev-net-log --dev-pick=0,1 --dev-autoplay --dev-steps=20 --dev-screenshot=C:\path\a.png
```

prints `join code: XXXXX`; a second instance with `--dev-join=XXXXX --dev-server=<ip>:7777` and the same flags plays it out. The server log shows the room.

## Not yet

A match queue, identities for a ladder (a key pair per install, later Steam auth), turn timers, reconnects, and a results file. The room table is where those go.
