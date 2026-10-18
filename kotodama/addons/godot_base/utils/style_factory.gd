class_name StyleFactory


static func flat(
	bg: Color = Color(0.1, 0.1, 0.16),
	border_color: Color = Color(0.2, 0.25, 0.3),
	border_width: int = 1,
	corner_radius: int = 2,
	content_margin: int = 4,
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(content_margin)
	return style


static func flat_no_border(
	bg: Color = Color(0.1, 0.1, 0.16),
	corner_radius: int = 2,
	content_margin: int = 4,
) -> StyleBoxFlat:
	return flat(bg, Color.TRANSPARENT, 0, corner_radius, content_margin)


static func panel(
	bg: Color = Color(0.12, 0.12, 0.18),
	border_color: Color = Color(0.25, 0.28, 0.35),
	border_width: int = 2,
	corner_radius: int = 4,
	content_margin: int = 8,
) -> StyleBoxFlat:
	return flat(bg, border_color, border_width, corner_radius, content_margin)


static func pill(
	bg_color: Color = Color(0.2, 0.2, 0.3),
	margin_h: int = 10,
	margin_v: int = 3,
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(12)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style
