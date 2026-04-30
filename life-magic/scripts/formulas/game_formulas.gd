class_name GameFormulas


static func max_heart_rate(age: float) -> float:
	return 208.0 - 0.7 * age


static func resting_heart_rate(age: float) -> float:
	return clampf(62.0 + 0.2 * age, 60.0, 80.0)


static func hr_speed_factor(current_bpm: float, resting_bpm: float, max_hr: float, cap_pct: float) -> float:
	var cap_bpm := max_hr * cap_pct
	if cap_bpm <= resting_bpm:
		return 1.0
	var ratio := clampf((current_bpm - resting_bpm) / (cap_bpm - resting_bpm), 0.0, 1.0)
	return 1.0 + 2.0 * ratio


static func generator_cost(base_cost: float, cost_mult: float, owned: float) -> float:
	return base_cost * pow(cost_mult, owned)


static func generator_bulk_cost(base_cost: float, cost_mult: float, owned: float, count: int) -> float:
	if cost_mult == 1.0:
		return base_cost * count
	var total := 0.0
	for i in count:
		total += base_cost * pow(cost_mult, owned + i)
	return total


static func generator_max_affordable(base_cost: float, cost_mult: float, owned: float, budget: float) -> int:
	var count := 0
	var spent := 0.0
	while true:
		var next_cost := base_cost * pow(cost_mult, owned + count)
		if spent + next_cost > budget:
			break
		spent += next_cost
		count += 1
	return count


static func generator_production(count: float, base_prod: float, multiplier: float) -> float:
	return count * base_prod * multiplier


static func format_number(value: float) -> String:
	if value < 0.0:
		return "-" + format_number(-value)
	if value < 1000.0:
		if value == floorf(value) and value < 100.0:
			return str(int(value))
		return "%.1f" % value

	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc"]
	var tier := 0
	var display := value
	while display >= 1000.0 and tier < suffixes.size() - 1:
		display /= 1000.0
		tier += 1

	if tier == 0:
		return "%d" % int(value)

	if display >= 100.0:
		return "%d%s" % [int(display), suffixes[tier]]
	elif display >= 10.0:
		return "%.1f%s" % [display, suffixes[tier]]
	else:
		return "%.2f%s" % [display, suffixes[tier]]


static func plant_seed_cost(base_cost: float, cost_mult: float, planted_count: int) -> float:
	return base_cost * pow(cost_mult, planted_count)
