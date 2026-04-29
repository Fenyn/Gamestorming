extends PanelContainer

@onready var wizard_label: Label = %WizardLabel
@onready var activity_label: Label = %ActivityLabel

var _frame: int = 0
var _timer: float = 0.0
const FRAME_TIME := 0.5

var _animations: Dictionary = {}


func _ready() -> void:
	_build_animations()

	if HeartRateManager.source != "demo":
		visible = false
	EventBus.heart_rate_source_changed.connect(func(src: String):
		visible = src == "demo"
	)


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= FRAME_TIME:
		_timer -= FRAME_TIME
		_advance()


func _advance() -> void:
	var key := _phase_to_key(HeartRateManager.current_phase)
	var data: Dictionary = _animations.get(key, _animations["REST"])
	var frames: Array = data["frames"]

	_frame = (_frame + 1) % frames.size()
	wizard_label.text = frames[_frame]
	activity_label.text = data["activity"]

	var zone := _get_zone_color()
	wizard_label.add_theme_color_override("font_color", zone.lightened(0.15))


func _phase_to_key(phase: String) -> String:
	if phase == "":
		return "REST"
	phase = phase.to_upper()
	if "HEAVY" in phase:
		return "HEAVY"
	if "LIFTING" in phase or "SET" in phase:
		return "LIFTING"
	if "WARMUP" in phase:
		return "WARMUP"
	if "COOLDOWN" in phase:
		return "COOLDOWN"
	return "REST"


func _get_zone_color() -> Color:
	var age: float = GameState.settings.get("age", 30.0)
	var max_hr := GameFormulas.max_heart_rate(age)
	var pct := HeartRateManager.smoothed_bpm / max_hr if max_hr > 0.0 else 0.0
	if pct >= 0.85: return Color(0.9, 0.15, 0.15)
	if pct >= 0.70: return Color(0.9, 0.55, 0.1)
	if pct >= 0.55: return Color(0.7, 0.8, 0.2)
	if pct >= 0.40: return Color(0.3, 0.7, 0.4)
	return Color(0.4, 0.6, 0.8)


func _f(lines: Array) -> String:
	return "\n".join(lines)


func _build_animations() -> void:
	_animations["REST"] = {
		"activity": "Resting in the garden...",
		"frames": [
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | o  o |      |   ",
				"    |  <>  |      |   ",
				"    | ~~~~ |      |   ",
				"     \\ ~~ /       |   ",
				"      \\~~/        |   ",
				"      |  |       |   ",
				"     /|  |\\      |   ",
				"    / |  | \\     |   ",
				"   /  |  |  \\    *   ",
				"      |__|     ,|.   ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | o  o |      |   ",
				"    |  <>  |      |   ",
				"    | ~~~~ |      |   ",
				"     \\ ~~ /       |   ",
				"      \\~~/        |   ",
				"      |  |       |   ",
				"     /|  |\\      |   ",
				"    / |  | \\     |   ",
				"   /  |  |  \\    *   ",
				"      |__|    \\|/    ",
			]),
		],
	}

	_animations["WARMUP"] = {
		"activity": "Warming up with wand drills!",
		"frames": [
			_f([
				"       /\\         *  ",
				"      /  \\       /   ",
				"     / ** \\     /    ",
				"    /------\\   /     ",
				"    | o  o |  /      ",
				"    |  <>  | /       ",
				"    | ~~~~ |/        ",
				"     \\ ~~ /          ",
				"      \\~~/           ",
				"      |  |           ",
				"     /|  |\\          ",
				"    / |  | \\         ",
				"   /  |  |  \\        ",
				"      |__|           ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | o  o |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				"      |  |---*        ",
				"     /|  |\\           ",
				"    / |  | \\          ",
				"   /  |  |  \\         ",
				"      |__|            ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | o  o |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				"      |  |\\           ",
				"     /|  | \\          ",
				"    / |  |  *         ",
				"   /  |  |  \\         ",
				"      |__|            ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | o  o |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				" *---|  |             ",
				"     /|  |\\           ",
				"    / |  | \\          ",
				"   /  |  |  \\         ",
				"      |__|            ",
			]),
		],
	}

	_animations["LIFTING"] = {
		"activity": "Hoeing the enchanted soil!",
		"frames": [
			_f([
				"       /\\      |     ",
				"      /  \\     |     ",
				"     / ** \\    |     ",
				"    /------\\   |     ",
				"    | >  < |   |     ",
				"    |  <>  |   |     ",
				"    | ~~~~ |   |     ",
				"     \\ ~~ /   /      ",
				"      \\~~/   /       ",
				"      |  |-+         ",
				"     /|  |\\          ",
				"    / |  | \\         ",
				"   /  |  |  \\        ",
				"      |__|   .,      ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | >  < |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				"      |  |\\           ",
				"     /|  | +          ",
				"    / |  | |\\         ",
				"   /  |  | | \\        ",
				"      |__|  +.,      ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | ^  ^ |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				"      |  |\\           ",
				"     /|  | \\          ",
				"    / |  |  +         ",
				"   /  |  |  |\\        ",
				"      |__|  +.';.    ",
			]),
		],
	}

	_animations["HEAVY"] = {
		"activity": "Hauling the cauldron!",
		"frames": [
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | >  < |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /   {~~}   ",
				"      \\~~/    {  }   ",
				"      |  |--={  }    ",
				"     /|  |\\  {__}    ",
				"    / |  | \\         ",
				"   /  |  |  \\        ",
				"      |__|           ",
			]),
			_f([
				"       /\\      {~~}  ",
				"      /  \\     {  }  ",
				"     / ** \\    {  }  ",
				"    /------\\   {__}  ",
				"    | >  < |  /      ",
				"    |  <>  | /       ",
				"    | ~~~~ |/        ",
				"     \\ ~~ /          ",
				"      \\~~/           ",
				"      |  |           ",
				"     /|  |\\          ",
				"    / |  | \\         ",
				"   /  |  |  \\        ",
				"      |__|           ",
			]),
			_f([
				"    {~~}  /\\         ",
				"    {  } /  \\        ",
				"    {  }/ ** \\       ",
				"    {__/------\\      ",
				"      \\ >  < |      ",
				"       \\ <>  |      ",
				"        \\ ~~ |      ",
				"         \\~~/       ",
				"      \\~~/          ",
				"      |  |          ",
				"     /|  |\\         ",
				"    / |  | \\        ",
				"   /  |  |  \\       ",
				"      |__|          ",
			]),
			_f([
				"       /\\      {~~}  ",
				"      /  \\     {  }  ",
				"     / ** \\    {  }  ",
				"    /------\\   {__}  ",
				"    | >  < |  /      ",
				"    |  <>  | /       ",
				"    | ~~~~ |/        ",
				"     \\ ~~ /          ",
				"      \\~~/           ",
				"      |  |           ",
				"     /|  |\\          ",
				"    / |  | \\         ",
				"   /  |  |  \\        ",
				"      |__|           ",
			]),
		],
	}

	_animations["COOLDOWN"] = {
		"activity": "Watering the garden ~",
		"frames": [
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | -  - |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				"      |  |---,        ",
				"     /|  |\\   )       ",
				"    / |  | \\  |  ~    ",
				"   /  |  |  \\ | ~     ",
				"      |__|  ,|. |.   ",
			]),
			_f([
				"       /\\             ",
				"      /  \\            ",
				"     / ** \\           ",
				"    /------\\          ",
				"    | -  - |          ",
				"    |  <>  |          ",
				"    | ~~~~ |          ",
				"     \\ ~~ /           ",
				"      \\~~/            ",
				"      |  |---,        ",
				"     /|  |\\   )  ~    ",
				"    / |  | \\  | ~ ~   ",
				"   /  |  |  \\ |~ ~ ~  ",
				"      |__|  \\|/ \\|/  ",
			]),
		],
	}
