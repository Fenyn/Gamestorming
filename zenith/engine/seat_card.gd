class_name SeatCard
extends RefCounted
## One card as one seat is allowed to see it. A hidden card keeps its uid and zone and nothing
## else, so the client can draw a back in the right place without learning what it is.

var uid: int = 0
var def_id: String = ""        # "" when hidden from this seat
var title: String = ""
var owner: int = 0
var controller: int = 0
var zone: StringName = &"none"
var aspect: int = 1
var energy: int = 0
var might: int = 0
var remain: int = 0
var attached_to: int = -1
var named_card: String = ""
var under: int = 0             # cards stacked beneath (Bond partners, overlays)
var bond_timer: int = 0
var variant: String = ""       # personalities: which printed line this Aspect was written for
var tags: Array[String] = []   # personalities: the keywords they carry right now, printed or lent
                               # by an attachment. Clients read this, never the card's own `tags`
## personalities: the Aspect stack's card ids, lowest first. `def_id` is always the card for the
## current Aspect, so a client looks that up in its library for the face and the art; the ladder
## is what the announced stack is, which is public from setup and what MPPV is read off.
var ladder: Array[String] = []


func hidden() -> bool:
	return def_id == ""


func to_dict() -> Dictionary:
	return {
		"uid": uid, "def": def_id, "title": title, "owner": owner, "controller": controller,
		"zone": String(zone), "aspect": aspect, "energy": energy, "might": might, "remain": remain,
		"attached_to": attached_to, "named": named_card, "under": under, "bond_timer": bond_timer,
		"variant": variant, "tags": tags, "ladder": ladder,
	}


static func from_dict(d: Dictionary) -> SeatCard:
	var c: SeatCard = SeatCard.new()
	c.uid = int(d.get("uid", 0))
	c.def_id = str(d.get("def", ""))
	c.title = str(d.get("title", ""))
	c.owner = int(d.get("owner", 0))
	c.controller = int(d.get("controller", 0))
	c.zone = StringName(str(d.get("zone", "none")))
	c.aspect = int(d.get("aspect", 1))
	c.energy = int(d.get("energy", 0))
	c.might = int(d.get("might", 0))
	c.remain = int(d.get("remain", 0))
	c.attached_to = int(d.get("attached_to", -1))
	c.named_card = str(d.get("named", ""))
	c.under = int(d.get("under", 0))
	c.bond_timer = int(d.get("bond_timer", 0))
	c.variant = str(d.get("variant", ""))
	c.tags.assign(d.get("tags", []))
	c.ladder.assign(d.get("ladder", []))
	return c


## What one seat may know about a card: everything on the table, own hand and Reserve, nothing
## about Life Decks or the other seat's hand and Reserve.
static func visible_to(c: CardInstance, seat: int) -> bool:
	match c.zone:
		&"life_deck":
			return false
		&"hand", &"reserve":
			return c.owner == seat
		_:
			return true


## `reveal` shows a card the seat could not otherwise see, for a card the seat is choosing among.
## `tags` is what a personality carries right now, which only the engine can work out, so the
## caller hands it in rather than the view reading the printed list.
static func of(c: CardInstance, seat: int, reveal: bool = false, tags: Array[String] = []) -> SeatCard:
	var v: SeatCard = SeatCard.new()
	v.uid = c.uid
	v.owner = c.owner
	v.controller = c.controller
	v.zone = c.zone
	v.under = c.cards_under.size()
	if not reveal and not visible_to(c, seat):
		return v
	v.def_id = c.def.id
	v.title = c.def.title
	v.aspect = c.aspect
	v.energy = c.energy
	v.might = c.might() if c.def.is_personality() else 0
	v.remain = c.remain
	v.attached_to = c.attached_to.uid if c.attached_to != null else -1
	v.named_card = c.named_card
	v.bond_timer = c.bond_timer
	v.variant = c.def.variant
	v.tags = tags
	v.ladder = c.ladder()
	return v
