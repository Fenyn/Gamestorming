class_name NetTransport
extends Node
## How a process reaches the other side. A transport opens the `MultiplayerPeer` that `Net`
## hands to the MultiplayerAPI; everything above that (rooms, lobby, commands, updates) is the
## same whichever transport made the connection. `LanTransport` is a direct ENet connection to
## an address (the duel server, or a hosting client on a LAN); a Steam transport would slot in
## here the same way, reaching the duel server or a friend through Valve's relays.

## What the host shares for the other player to type in: an address, a code, or a Steam id.
var join_code: String = ""


## Open as the host. Returns "" or a message for the player. May be a coroutine.
func host() -> String:
	return "This transport cannot host."


## Connect to a host by what it shared. Returns "" or a message for the player. May be a
## coroutine; `Net` still learns the outcome through the MultiplayerAPI signals.
func join(_code: String) -> String:
	return "This transport cannot join."


## Drop anything the transport holds besides the peer, which `Net` closes itself.
func close() -> void:
	join_code = ""


## One line for the title or lobby while hosting.
func hosting_text() -> String:
	return "Waiting for the other player."
