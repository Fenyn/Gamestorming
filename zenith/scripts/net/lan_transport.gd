class_name LanTransport
extends NetTransport
## A direct ENet connection: the host listens on a port, the joiner types the host's address.
## Works on a LAN or with port forwarding, and is what the dev flags and the two-instance check
## use. The join code is the host's first private address plus the port.

const DEFAULT_PORT: int = 7777

var port: int = DEFAULT_PORT
var max_peers: int = 1   # a hosting client takes one joiner; a dedicated server takes two
## DTLS on the ENet host: the server's own key and certificate on the duel server, the pinned
## certificate on a client of it. Null for plain ENet, which a hosting client and its joiner keep.
var tls: TLSOptions = null


func host() -> String:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_peers)
	if err != OK:
		return "Could not open port %d (%s)." % [port, error_string(err)]
	if tls != null:
		err = peer.host.dtls_server_setup(tls)
		if err != OK:
			peer.close()
			return "Could not turn on DTLS on port %d (%s)." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	join_code = "%s:%d" % [local_address(), port]
	return ""


## `code` may carry a port as host:port; an empty code means this machine.
func join(code: String) -> String:
	var where: Array = split_address(code)
	var target: String = where[0]
	var target_port: int = where[1]
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target, target_port)
	if err != OK:
		return "Could not connect to %s:%d (%s)." % [target, target_port, error_string(err)]
	if tls != null:
		err = peer.host.dtls_client_setup(target, tls)
		if err != OK:
			peer.close()
			return "Could not start DTLS to %s:%d (%s)." % [target, target_port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	return ""


func hosting_text() -> String:
	return "Hosting at %s. Waiting for the other player." % join_code


## `code` as [host, port]: the port after a colon, DEFAULT_PORT without one, this machine for an
## empty host.
static func split_address(code: String) -> Array:
	var target: String = code.strip_edges()
	var target_port: int = DEFAULT_PORT
	if target.contains(":") and not target.begins_with("["):
		target_port = int(target.get_slice(":", 1))
		target = target.get_slice(":", 0)
	if target == "":
		target = "127.0.0.1"
	return [target, target_port]


## Whether the joiner typed an address rather than a share code.
static func looks_like_address(code: String) -> bool:
	var c: String = code.strip_edges()
	return c == "" or c.contains(".") or c.contains(":") or c == "localhost"


## The first private IPv4 address this machine has, or 127.0.0.1.
static func local_address() -> String:
	for address in IP.get_local_addresses():
		var a: String = str(address)
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"
