extends RefCounted
## Public standing effects shared by field ornaments and full inspection.

static func flags(p: SeatPlayer) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if p.must_pass:
		lines.append("Must pass")
	if p.skip_next_attack_phase:
		lines.append("Skips next attack")
	if p.energy_blocked:
		lines.append("Cannot gain Energy")
	if p.fervor_shield:
		lines.append("Fervor shielded")
	if p.aspect_shield:
		lines.append("Aspect shielded")
	if p.no_ascension_win:
		lines.append("Cannot win by Ascension")
	if p.fervor_needed != DuelEngine.FERVOR_TO_ASPECT:
		lines.append("Needs %d Fervor" % p.fervor_needed)
	if p.fervor_gain != 1:
		lines.append("Fervor gain x%d" % p.fervor_gain)
	if p.seal_victory_pending:
		lines.append("Seal victory pending")
	for restriction in p.restrictions:
		lines.append(CardText.restriction_name(restriction))
	return lines
