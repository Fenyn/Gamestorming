class_name GameFormulas


static func purchase_cost(base_cost: float, cost_multiplier: float, owned: int) -> float:
	return base_cost * pow(cost_multiplier, owned)


static func calculate_tickets(total_gold: float) -> int:
	return int(floor(sqrt(total_gold / 100.0)))


static func format_gold(amount: float) -> String:
	if amount >= 1_000_000.0:
		return "%.1fM" % (amount / 1_000_000.0)
	if amount >= 1_000.0:
		return "%.1fK" % (amount / 1_000.0)
	return "%d" % int(amount)
