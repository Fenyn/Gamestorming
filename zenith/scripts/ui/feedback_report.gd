class_name FeedbackReport
extends RefCounted
## One bug or feedback report as the player filed it, in the shapes it leaves the game in: the JSON
## the relay takes (tools/feedback_worker) and the plain text "Copy report" puts on the clipboard.
## Game details are plain "Name: value" lines and log tails, with every home folder and user name
## in a path replaced, so a report never carries the player's own paths.

const KINDS: Array[String] = ["bug", "feedback"]
const MAX_TITLE: int = 90
const MAX_DESCRIPTION: int = 6000
const MAX_DETAILS: int = 60000
const HOME: String = "<home>"
const PATH: String = "<path>"

var kind: String = "bug"
var title: String = ""
var description: String = ""
var details: String = ""


static func make(kind_name: String, title_text: String, description_text: String, details_text: String) -> FeedbackReport:
	var r: FeedbackReport = FeedbackReport.new()
	r.kind = kind_name if kind_name in KINDS else "bug"
	r.title = title_text.strip_edges().left(MAX_TITLE)
	r.description = description_text.strip_edges().left(MAX_DESCRIPTION)
	r.details = details_text.left(MAX_DETAILS)
	return r


## "Name: value" lines in `info`'s order.
static func detail_lines(info: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for key in info.keys():
		lines.append("%s: %s" % [str(key), str(info[key])])
	return "\n".join(lines)


## The last `count` non-empty lines of `text`.
static func tail(text: String, count: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges() != "":
			lines.append(line)
	return "\n".join(lines.slice(maxi(0, lines.size() - count)))


## `text` with each of `paths` (the user data folder, the game's folder) and any home folder
## replaced, on Windows, macOS and Linux spellings alike.
static func scrub(text: String, paths: PackedStringArray = PackedStringArray()) -> String:
	var out: String = text
	for p in paths:
		if p.length() > 3:
			out = out.replace(p, PATH).replace(p.replace("/", "\\"), PATH)
	# A user folder runs to the next separator; Windows names may hold spaces.
	var home: RegEx = RegEx.create_from_string("(?i)([a-z]:[\\\\/]+(users|documents and settings)[\\\\/]+[^\\\\/:\\n]+)|(/(Users|home)/[^/:\\n]+)")
	return home.sub(out, HOME, true)


## The relay's JSON body. `screenshot` is base64 JPEG, "" for none.
func payload(version: String, platform: String, screenshot: String = "") -> Dictionary:
	return {
		"kind": kind, "title": title, "description": description, "details": details,
		"version": version, "platform": platform, "screenshot": screenshot,
	}


## The report as text, for the clipboard when it cannot be sent.
func to_text() -> String:
	var head: String = "%s: %s" % ["Bug" if kind == "bug" else "Feedback", title if title != "" else "Untitled report"]
	var out: String = "%s\n\n%s" % [head, description]
	if details != "":
		out += "\n\n--- Game details ---\n" + details
	return out
