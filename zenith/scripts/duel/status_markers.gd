class_name StatusMarkers
extends Node3D
## The live marks on a personality in play, rendered over its cached face only when one changes:
## the ladder's live layer and, on a duelist, its `DuelistTabs`. An Ally's Energy is also spelled
## out under its card.

const LIFT: float = 0.004                 # above the card quad, no z-fight
const FLASH_TIME: float = 0.55
## An Ally's Energy value and caption, in card units: under the card, or over it for the far seat
## with the value still above the caption on screen.
const NEAR_VALUE_Z: float = 0.57
const NEAR_CAPTION_Z: float = 0.77
const FAR_VALUE_Z: float = -0.7
const FAR_CAPTION_Z: float = -0.51

@export var reduced_motion: bool = false
@onready var viewport: SubViewport = $Viewport
@onready var ladder: MightLadder = $Viewport/Face/Ladder
@onready var tabs: DuelistTabs = $Viewport/Face/Tabs
@onready var overlay: MeshInstance3D = $Overlay
@onready var stat_value: Label3D = $StatValue
@onready var stat_caption: Label3D = $StatCaption
var _flash: Tween = null
var _shown: bool = false


func _ready() -> void:
	(overlay.material_override as StandardMaterial3D).albedo_texture = viewport.get_texture()
	ladder.changed.connect(_render)
	tabs.changed.connect(_render)


## `ladder_rect` is where the face lays out its ladder, in face pixels (`CardFaceCache.ladder_rect`).
func setup(ladder_rect: Rect2) -> void:
	if Rect2(ladder.position, ladder.size).is_equal_approx(ladder_rect):
		return
	ladder.position = ladder_rect.position
	ladder.size = ladder_rect.size
	_render()


func show_card(def: CardDef, aspect: int, backdrop: Color) -> void:
	ladder.show_card(def, aspect, backdrop)


## A duelist: the gauge at `energy` with its live `might`, the Surge rail to `reach` (-1 for
## none), its Fervor pips, and `control` naming the Ally in control ("" while it fights itself).
func set_duelist(energy: int, might: int, reach: int, fervor: int, need: int, control: String) -> void:
	_pulse_on_change(energy, fervor)
	ladder.show_live(energy, might, reach, ladder.preview_cost())
	tabs.show_tabs(fervor, need, control)
	stat_value.visible = false
	stat_caption.visible = false


## An Ally: the gauge only, and its Energy spelled out past the card's edge toward its owner.
func set_ally(energy: int, might: int, far: bool = false) -> void:
	_pulse_on_change(energy, -1)
	ladder.show_live(energy, might, -1, ladder.preview_cost())
	tabs.show_tabs(-1, 0, "")
	stat_value.visible = true
	stat_caption.visible = true
	stat_value.position.z = FAR_VALUE_Z if far else NEAR_VALUE_Z
	stat_caption.position.z = FAR_CAPTION_Z if far else NEAR_CAPTION_Z
	stat_value.text = str(energy)
	stat_value.modulate = ZenithTheme.WARN if energy <= 0 else ZenithTheme.ENERGY


## Preview only: the rung a projected cost would drop Energy to, outlined.
func preview_energy(cost: int = 0) -> void:
	ladder.set_preview(cost)


## The lit pill brightens for a moment when Energy or Fervor moves.
func _pulse_on_change(energy: int, fervor: int) -> void:
	var moved: bool = _shown and (energy != ladder.energy() or fervor != tabs.fervor())
	_shown = true
	if not moved or reduced_motion:
		return
	if _flash != null:
		_flash.kill()
	ladder.flash = 1.0
	_flash = create_tween()
	_flash.tween_property(ladder, "flash", 0.0, FLASH_TIME)


func _render() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
