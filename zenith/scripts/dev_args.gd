class_name DevArgs
extends RefCounted
## The command-line user arguments the client reads. A release build drops every `--dev-` flag, so a
## shipped exe cannot unlock content, rig a duel or reach the dev screens from the command line.


static func user_args() -> PackedStringArray:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if OS.is_debug_build():
		return args
	var out: PackedStringArray = PackedStringArray()
	for arg in args:
		if not arg.begins_with("--dev-"):
			out.append(arg)
	return out
