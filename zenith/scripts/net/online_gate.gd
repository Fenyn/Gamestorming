class_name OnlineGate
extends RefCounted
## Whether this build can play online. A browser allows neither ENet nor plain UDP, so the web build
## has every online option greyed out with UNAVAILABLE_TEXT and `Net` refuses to connect.
## `is_web()` also drops the decoration that is slow to compile in a browser (`ArcaneBackdrop`'s 3D
## hall, `CourtyardSet`'s leaves). `--dev-web` makes a desktop debug build behave as the web build.

const UNAVAILABLE_TEXT: String = "Online play is only available in the desktop version."

## Tests set this: 1 acts as the web build, 0 as the desktop, -1 asks the platform.
static var forced_web: int = -1


static func is_web() -> bool:
	if forced_web != -1:
		return forced_web == 1
	return OS.has_feature("web") or DevArgs.user_args().has("--dev-web")


static func available() -> bool:
	return not is_web()
