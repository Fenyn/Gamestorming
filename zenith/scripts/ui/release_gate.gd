class_name ReleaseGate
extends RefCounted
## Which unfinished features the player can open in this build, from the project settings
## `zenith/release/tutorial` and `zenith/release/deck_builder` (off when missing). A closed one keeps
## its button, greyed, with its sentence as the tooltip; the dev flags still open it.

const TUTORIAL_LATER: String = "The tutorial arrives in a later build."
const BUILDER_LATER: String = "The deck builder arrives in a later build."


static func tutorial() -> bool:
	return bool(ProjectSettings.get_setting("zenith/release/tutorial", false))


static func deck_builder() -> bool:
	return bool(ProjectSettings.get_setting("zenith/release/deck_builder", false))


## "Alpha build 0.1.0. Expect bugs and missing pieces.", from `application/config/version`.
static func alpha_text() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return "Alpha build %s. Expect bugs and missing pieces." % version if version != "" else "Alpha build. Expect bugs and missing pieces."
