class_name CustomerProfile
extends RefCounted

## A generated customer: who they are, how they look and how they behave.
## Archetypes follow the Phase 2 plan in CLAUDE.md (regulars are patient,
## commuters are impatient, complex orderers add modifiers).

enum Archetype { REGULAR, COMMUTER, STUDENT, COMPLEX }

const NAMES := [
	"Alex", "Sam", "Maya", "Jordan", "Priya", "Leo", "Hana", "Omar", "Zoe", "Mateo",
	"Aiko", "Ben", "Chloe", "Dev", "Ines", "Kai", "Lena", "Marco", "Nia", "Owen",
	"Rosa", "Theo", "Uma", "Victor", "Wren", "Yuki", "Ada", "Felix", "Grace", "Hugo",
	"Iris", "Jonah", "Kofi", "Luz", "Mina", "Noah", "Pia", "Quinn", "Ravi", "Sora",
]

const ACCESSORY_COLORS := [
	Color(0.85, 0.25, 0.2), Color(0.2, 0.45, 0.8), Color(0.95, 0.75, 0.2), Color(0.25, 0.6, 0.35),
	Color(0.55, 0.3, 0.6), Color(0.15, 0.15, 0.18), Color(0.9, 0.9, 0.88), Color(0.95, 0.5, 0.2),
]

const GREETINGS := ["Hi!", "Hey there!", "Morning!", "Hello!", "Hiya!"]
const IMPATIENT := ["Come on...", "Any time now...", "Hello?", "*sigh*", "Running late..."]
const WAITING := ["...", "Smells good!", "*checks phone*", "Nice place.", "Hmm..."]
const ANGRY := ["Forget it.", "Too slow!", "Ugh.", "I'm out."]
const HAPPY := ["Perfect!", "Amazing!", "Best coffee ever!", "Wow!"]
const OKAY := ["Thanks!", "Cheers!", "Thank you!"]
const MEH := ["Hmm. Thanks.", "...okay.", "Not great."]

var archetype: Archetype = Archetype.REGULAR
var display_name := ""
var skin_index := 0
var height_scale := 1.0
var walk_speed := 2.0
var patience_mult := 1.0
var modifier_chance_mult := 1.0
var hat := ""          # "", "beanie", "cap"
var glasses := false
var headphones := false
var backpack := false
var uses_phone := false
var accessory_color := Color.WHITE
var accessory_color_2 := Color.WHITE

static func generate(rng: RandomNumberGenerator = null) -> CustomerProfile:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var p := CustomerProfile.new()
	var roll := rng.randf()
	if roll < 0.3:
		p.archetype = Archetype.REGULAR
	elif roll < 0.6:
		p.archetype = Archetype.COMMUTER
	elif roll < 0.85:
		p.archetype = Archetype.STUDENT
	else:
		p.archetype = Archetype.COMPLEX

	p.display_name = NAMES[rng.randi() % NAMES.size()]
	p.skin_index = rng.randi() % 10
	p.height_scale = rng.randf_range(0.92, 1.06)
	p.accessory_color = ACCESSORY_COLORS[rng.randi() % ACCESSORY_COLORS.size()]
	p.accessory_color_2 = ACCESSORY_COLORS[rng.randi() % ACCESSORY_COLORS.size()]

	match p.archetype:
		Archetype.REGULAR:
			p.walk_speed = rng.randf_range(1.6, 1.9)
			p.patience_mult = 1.3
			p.hat = "beanie" if rng.randf() < 0.4 else ""
			p.glasses = rng.randf() < 0.5
		Archetype.COMMUTER:
			p.walk_speed = rng.randf_range(2.2, 2.6)
			p.patience_mult = 0.7
			p.headphones = rng.randf() < 0.5
			p.backpack = rng.randf() < 0.3
			p.uses_phone = true
		Archetype.STUDENT:
			p.walk_speed = rng.randf_range(1.8, 2.2)
			p.patience_mult = 1.0
			p.backpack = rng.randf() < 0.8
			p.headphones = rng.randf() < 0.4
			p.hat = "cap" if rng.randf() < 0.35 else ""
			p.uses_phone = rng.randf() < 0.7
		Archetype.COMPLEX:
			p.walk_speed = rng.randf_range(1.7, 2.0)
			p.patience_mult = 1.0
			p.modifier_chance_mult = 2.5
			p.glasses = rng.randf() < 0.6
			p.hat = "cap" if rng.randf() < 0.3 else ""
	return p

func archetype_name() -> String:
	match archetype:
		Archetype.REGULAR: return "Regular"
		Archetype.COMMUTER: return "Commuter"
		Archetype.STUDENT: return "Student"
		Archetype.COMPLEX: return "Picky"
	return ""

static func pick(lines: Array) -> String:
	return lines[randi() % lines.size()]

func review_line(stars: float) -> String:
	if stars >= 4.5:
		return pick(HAPPY)
	if stars >= 3.0:
		return pick(OKAY)
	return pick(MEH)
