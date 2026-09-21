class_name AdventureDev
extends RefCounted
## Dev-flag helpers shared by the adventure screens, so a screen opened straight from the command
## line can show any state. Everything here builds the run in memory only; the player's save is
## never read or written.

const DEV_SEED: int = 12345
const SHOT_DELAY: float = 0.5


static func args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


## The value after `prefix`, taking the last match, or "" when no argument carries it.
static func flag(prefix: String) -> String:
	var out: String = ""
	for arg in args():
		if arg.begins_with(prefix):
			out = arg.get_slice("=", 1)
	return out


static func reduced_motion() -> bool:
	return args().has("--reduced-motion")


## Puts an unsaved run for `starter_id` into Session. False when the starter or its ladder is
## missing, leaving Session as it was.
static func begin_run(starter_id: String) -> bool:
	var run: AdventureRun = AdventureRun.begin(starter_id, DEV_SEED)
	var ladder: AdventureLadder = AdventureLadder.load_for(starter_id)
	if run == null or ladder == null:
		return false
	Session.run = run
	Session.ladder = ladder
	return true


## `--dev-screenshot=<png>` saves the screen once it has settled, then quits.
static func screenshot(node: Node) -> void:
	var path: String = flag("--dev-screenshot=")
	if path == "":
		return
	await node.get_tree().create_timer(SHOT_DELAY).timeout
	await RenderingServer.frame_post_draw
	node.get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to %s" % path)
	node.get_tree().quit()
