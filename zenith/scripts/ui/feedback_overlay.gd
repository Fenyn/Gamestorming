extends CanvasLayer
## The bug and feedback form, an autoload (`Feedback`) so it opens over any screen: the
## `feedback_report` action (F8) or `Feedback.open()` from a menu. The screenshot and the game
## details are taken as it opens, before the form covers the screen. Every report is saved under
## user://feedback/ and posted to the relay (tools/feedback_worker), which opens a thread for it in
## the team's Discord forum. "Copy report" is the way out when it cannot be sent.

const SAVE_DIR: String = "user://feedback"
const ENGINE_LOG: String = "user://logs/godot.log"
const ENGINE_LOG_LINES: int = 80
const TABLE_LOG_LINES: int = 40
const SHOT_WIDTH: int = 1600
const SHOT_QUALITY: float = 0.8
const THUMB_WIDTH: int = 192
const CLOSE_DELAY: float = 1.4
const DEV_OPEN_DELAY: float = 1.0      # `--dev-feedback` opens the form this long after start
const SENDING: String = "Sending…"
const SENT: String = "Sent. Thank you for the report."
const NO_ADDRESS: String = "This build cannot send reports. Copy the report to share it another way."
const UNSENT: String = "The report could not be sent (%s). It is saved on this computer, and Copy report puts it on your clipboard."
const COPIED: String = "The report is on your clipboard."
const EMPTY: String = "Please write a title or a description first."

@onready var root: Control = $Root
@onready var bug_button: Button = %Bug
@onready var feedback_button: Button = %Feedback
@onready var summary: LineEdit = %Summary
@onready var description: TextEdit = %Description
@onready var include: CheckBox = %Include
@onready var thumb: TextureRect = %Shot
@onready var status: Label = %Status
@onready var cancel_button: Button = %Cancel
@onready var copy_button: Button = %Copy
@onready var send_button: Button = %Send
@onready var request: HTTPRequest = $Request

var _shot: Image = null
var _details: String = ""
var _sending: bool = false


func _ready() -> void:
	root.theme = SanctumUI.theme()
	visible = false
	cancel_button.pressed.connect(close)
	copy_button.pressed.connect(_copy)
	send_button.pressed.connect(_send)
	request.request_completed.connect(_on_sent)
	include.toggled.connect(func(on: bool) -> void: thumb.modulate.a = 1.0 if on else 0.3)
	for arg in DevArgs.user_args():
		if arg == "--dev-feedback" or arg.begins_with("--dev-feedback="):
			_dev_open(arg.get_slice("=", 1) if arg.contains("=") else "")


## `--dev-feedback` opens the form a moment after start; `--dev-feedback=<png>` also saves it
## filled in with a sample report, and quits.
func _dev_open(shot_path: String) -> void:
	await get_tree().create_timer(DEV_OPEN_DELAY).timeout
	open()
	if shot_path == "":
		return
	summary.text = "Sample: the Energy bar did not move"
	description.text = "I paid 2 Energy for an Art and the bar stayed where it was."
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("feedback screenshot saved to %s" % shot_path)
	print(_details.left(1500))
	if "--dev-feedback-send" in DevArgs.user_args():
		summary.text = "Test report from the dev build"
		description.text = "Sent by --dev-feedback-send to check the relay. Safe to delete."
		_send()
		if _sending:
			await request.request_completed
		print("feedback send: %s" % status.text)
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("feedback_report") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()
	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Shows the form over the current screen, `kind` "bug" or "feedback" picked.
func open(kind: String = "bug") -> void:
	if visible:
		return
	# The last frame drawn, which the form is not in yet.
	_shot = get_viewport().get_texture().get_image()
	if _shot != null and _shot.get_width() > SHOT_WIDTH:
		_shot.resize(SHOT_WIDTH, int(_shot.get_height() * float(SHOT_WIDTH) / _shot.get_width()), Image.INTERPOLATE_LANCZOS)
	_details = _gather_details()
	if _shot != null:
		var small: Image = _shot.duplicate()
		small.resize(THUMB_WIDTH, int(small.get_height() * float(THUMB_WIDTH) / small.get_width()), Image.INTERPOLATE_BILINEAR)
		thumb.texture = ImageTexture.create_from_image(small)
	thumb.visible = _shot != null
	(feedback_button if kind == "feedback" else bug_button).button_pressed = true
	summary.text = ""
	description.text = ""
	include.button_pressed = true
	thumb.modulate.a = 1.0
	status.text = ""
	_set_sending(false)
	visible = true
	summary.grab_focus()


func close() -> void:
	if _sending:
		request.cancel_request()
		_set_sending(false)
	visible = false
	_shot = null


func _report() -> FeedbackReport:
	var kind: String = "feedback" if feedback_button.button_pressed else "bug"
	return FeedbackReport.make(kind, summary.text, description.text, _details if include.button_pressed else "")


func _send() -> void:
	var report: FeedbackReport = _report()
	if report.title == "" and report.description == "":
		status.text = EMPTY
		return
	var shot: PackedByteArray = _shot.save_jpg_to_buffer(SHOT_QUALITY) if _shot != null and include.button_pressed else PackedByteArray()
	_save(report, shot)
	var endpoint: String = str(ProjectSettings.get_setting("zenith/feedback/endpoint", ""))
	if endpoint == "":
		status.text = NO_ADDRESS
		return
	var body: String = JSON.stringify(report.payload(_version(), _platform(), Marshalls.raw_to_base64(shot)))
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"X-Zenith-Key: %s" % str(ProjectSettings.get_setting("zenith/feedback/key", "")),
	])
	var err: Error = request.request(endpoint, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		status.text = UNSENT % error_string(err)
		return
	_set_sending(true)
	status.text = SENDING


func _on_sent(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_sending(false)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		status.text = SENT
		await get_tree().create_timer(CLOSE_DELAY).timeout
		if status.text == SENT:
			close()
		return
	var reason: String = "no answer from the report server" if result != HTTPRequest.RESULT_SUCCESS else "error %d" % code
	var answer: Variant = JSON.parse_string(body.get_string_from_utf8())
	if answer is Dictionary and str((answer as Dictionary).get("message", "")) != "":
		reason = str((answer as Dictionary).get("message", ""))
	status.text = UNSENT % reason


func _copy() -> void:
	DisplayServer.clipboard_set(_report().to_text())
	status.text = COPIED


func _set_sending(on: bool) -> void:
	_sending = on
	send_button.disabled = on
	copy_button.disabled = on


## A copy on disk whatever happens to the send: the JSON, and the screenshot beside it.
func _save(report: FeedbackReport, shot: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var f: FileAccess = FileAccess.open("%s/report_%s.json" % [SAVE_DIR, stamp], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report.payload(_version(), _platform()), "\t"))
	if not shot.is_empty():
		var s: FileAccess = FileAccess.open("%s/report_%s.jpg" % [SAVE_DIR, stamp], FileAccess.WRITE)
		if s != null:
			s.store_buffer(shot)


## What the report says about the game: build, system, screen, the current scene's own context
## (a duel names its mode, decks and step, and gives its table log), and the engine log's tail.
func _gather_details() -> String:
	var size: Vector2i = DisplayServer.window_get_size()
	var info: Dictionary = {
		"Version": _version(),
		"Platform": _platform(),
		"Renderer": "%s, %s" % [str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")), RenderingServer.get_video_adapter_name()],
		"Window": "%d x %d" % [size.x, size.y],
		"Time": Time.get_datetime_string_from_system(true) + " UTC",
	}
	var scene: Node = get_tree().current_scene
	var table_log: String = ""
	if scene != null:
		info["Scene"] = scene.scene_file_path
		if scene.has_method("feedback_context"):
			var context: Dictionary = scene.call("feedback_context")
			table_log = str(context.get("log", ""))
			context.erase("log")
			info.merge(context)
	var out: String = FeedbackReport.detail_lines(info)
	if table_log != "":
		out += "\n\n--- Table log ---\n" + FeedbackReport.tail(table_log, TABLE_LOG_LINES)
	if FileAccess.file_exists(ENGINE_LOG):
		out += "\n\n--- Engine log ---\n" + FeedbackReport.tail(FileAccess.get_file_as_string(ENGINE_LOG), ENGINE_LOG_LINES)
	var paths: PackedStringArray = PackedStringArray([OS.get_user_data_dir(), OS.get_executable_path().get_base_dir()])
	return FeedbackReport.scrub(out, paths)


func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


func _platform() -> String:
	return "%s (web)" % OS.get_name() if OS.has_feature("web") else OS.get_name()
