extends DirectionalLight3D

## Moves the sun across the day: cool morning light during prep, bright midday,
## orange golden hour as the day timer runs out. Also tints the sky and ambient light.

@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")

# Each key: day progress, sun elevation (deg), sun yaw (deg), light colour, energy,
# sky horizon colour, ambient colour.
const KEYS := [
	[0.0, 18.0, 70.0, Color(1.0, 0.88, 0.76), 0.9, Color(0.86, 0.8, 0.78), Color(0.82, 0.84, 0.9)],
	[0.45, 55.0, 15.0, Color(1.0, 0.97, 0.92), 1.2, Color(0.72, 0.82, 0.9), Color(0.9, 0.88, 0.84)],
	[0.8, 32.0, -40.0, Color(1.0, 0.86, 0.68), 1.1, Color(0.9, 0.78, 0.62), Color(0.95, 0.85, 0.75)],
	[1.0, 12.0, -70.0, Color(1.0, 0.62, 0.38), 0.9, Color(1.0, 0.62, 0.42), Color(0.95, 0.75, 0.62)],
]

var _environment: Environment = null
var _sky_material: ProceduralSkyMaterial = null
var _last_progress := -1.0

func _ready() -> void:
	var world_env := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_env:
		_environment = world_env.environment
		if _environment and _environment.sky:
			_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
	_apply(_day_progress())

func _process(_delta: float) -> void:
	# Changing the sky or sun rebuilds the sky lighting, so only update on real change.
	var progress := _day_progress()
	if absf(progress - _last_progress) >= 0.002:
		_apply(progress)

func _day_progress() -> float:
	if GameManager.prep_active:
		return 0.0
	if not GameManager.day_active:
		return 1.0
	return clampf(1.0 - GameManager.day_timer / GameManager.DAY_LENGTH, 0.0, 1.0)

func _apply(progress: float) -> void:
	_last_progress = progress
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i in range(KEYS.size() - 1):
		var k0: Array = KEYS[i]
		var k1: Array = KEYS[i + 1]
		if progress >= float(k0[0]) and progress <= float(k1[0]):
			a = k0
			b = k1
			break
	var span: float = float(b[0]) - float(a[0])
	var t: float = 0.0 if span <= 0.0 else (progress - float(a[0])) / span
	t = smoothstep(0.0, 1.0, t)

	var elevation: float = lerpf(float(a[1]), float(b[1]), t)
	var yaw: float = lerpf(float(a[2]), float(b[2]), t)
	rotation_degrees = Vector3(-elevation, yaw, 0.0)
	light_color = (a[3] as Color).lerp(b[3] as Color, t)
	light_energy = lerpf(float(a[4]), float(b[4]), t)

	var horizon: Color = (a[5] as Color).lerp(b[5] as Color, t)
	if _sky_material:
		_sky_material.sky_horizon_color = horizon
		_sky_material.ground_horizon_color = horizon
	if _environment:
		_environment.ambient_light_color = (a[6] as Color).lerp(b[6] as Color, t)
