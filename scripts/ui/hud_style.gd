extends RefCounted
## The in-game HUD's look, from the Strinova-style look test (2026-10-09,
## strinova-look/hud/hud_v2.html): dark plum cards with a coloured bar along
## the top and the bottom right corner cut off, Saira for words and Rajdhani
## for numbers (both SIL OFL, assets/fonts), and white type with a soft dark
## shadow instead of a black outline. The fight panel (hud.gd), the run HUD's
## cards, prompts and toasts (run_hud.gd), the radio box, Eco's whispers and
## the dialogue caption (npc_talk.gd) all draw with it. The menus keep
## ui_theme.gd.

const YELLOW := Color(1.0, 0.82, 0.25)
const CYAN := Color(0.37, 0.89, 1.0)
const PINK := Color(1.0, 0.61, 0.75)
const VIOLET := Color(0.78, 0.61, 1.0)
const AMBER := Color(1.0, 0.72, 0.29)
const RED := Color(1.0, 0.35, 0.31)
const CARD := Color(0.12, 0.086, 0.157, 0.78)
const INK := Color(1.0, 1.0, 1.0)
const DIM := Color(1.0, 1.0, 1.0, 0.62)
const SHADOW := Color(0.08, 0.04, 0.08, 0.55)
## The cut corner and the accent bar along the top.
const CUT := 12
const BAR := 3
## How far a bar or pip leans (a fraction of its height).
const LEAN := 0.25

static var _fonts := {}


## Saira at a weight (400 regular to 800 extra bold); `spacing` adds pixels
## between letters, for the small spaced-out captions.
static func saira(weight := 500, italic := false, spacing := 0) -> Font:
	var key := "saira%d%s%d" % [weight, "i" if italic else "", spacing]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = _file("Saira-Italic.ttf" if italic else "Saira.ttf")
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
		f.spacing_glyph = spacing
		_fonts[key] = f
	return _fonts[key]


## Rajdhani, for the big numbers (health, rounds, the run status).
static func numbers(bold := true, spacing := 0) -> Font:
	var key := "rajdhani%s%d" % ["b" if bold else "", spacing]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = _file("Rajdhani-Bold.ttf" if bold else "Rajdhani-SemiBold.ttf")
		f.spacing_glyph = spacing
		_fonts[key] = f
	return _fonts[key]


## The font file, or the engine's own font if it's missing (a stripped export).
static func _file(name: String) -> Font:
	var path := "res://assets/fonts/" + name
	return load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font


## A card: the plum glass, the accent bar on top, the bottom right corner cut.
static func card(accent: Color, pad := 14.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CARD
	s.border_color = accent
	s.border_width_top = BAR
	s.corner_radius_bottom_right = CUT
	s.corner_detail = 1  # one segment: a straight cut, not a round corner
	s.set_content_margin_all(pad)
	s.content_margin_left = pad + 2.0
	s.content_margin_right = pad + 2.0
	s.content_margin_top = pad + BAR
	return s


## A label in the HUD's type: font, size, colour and the soft shadow.
static func style(l: Label, size: int, color := INK, font: Font = null) -> Label:
	l.add_theme_font_override("font", font if font != null else saira(600))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	shadow(l)
	return l


static func shadow(l: Control) -> void:
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)


## Text drawn straight onto a canvas item, with the soft shadow under it.
static func text(ci: CanvasItem, font: Font, at: Vector2, s: String, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var sh := Color(SHADOW, SHADOW.a * color.a)
	ci.draw_string_outline(font, at + Vector2(0, 2), s, align, width, size, 4, Color(sh, sh.a * 0.6))
	ci.draw_string(font, at + Vector2(0, 2), s, align, width, size, sh)
	ci.draw_string(font, at, s, align, width, size, color)


static func width(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A leaning parallelogram: x0..x1 along its foot, `h` tall from `y`.
static func lean(x0: float, x1: float, y: float, h: float) -> PackedVector2Array:
	var k := h * LEAN
	return PackedVector2Array([Vector2(x0 + k, y), Vector2(x1 + k, y), Vector2(x1, y + h), Vector2(x0, y + h)])


## A leaning bar, `frac` full, cut into segments `seg` pixels long.
static func bar(ci: CanvasItem, r: Rect2, frac: float, color: Color, seg := 0.0) -> void:
	ci.draw_colored_polygon(lean(r.position.x, r.end.x, r.position.y, r.size.y), Color(1, 1, 1, 0.14))
	frac = clampf(frac, 0.0, 1.0)
	if frac > 0.0:
		ci.draw_colored_polygon(lean(r.position.x, r.position.x + r.size.x * frac, r.position.y, r.size.y), color)
	if seg > 0.0:
		var k := r.size.y * LEAN
		var x := r.position.x + seg
		while x < r.end.x - 2.0:
			ci.draw_line(Vector2(x + k, r.position.y), Vector2(x, r.end.y), CARD, 3.0)
			x += seg


## A key in a little box, like the [F] of a prompt; returns how wide it is.
static func key(ci: CanvasItem, at: Vector2, k: String, size: int) -> float:
	var font := saira(700)
	var w := maxf(width(font, k, size) + 12.0, size + 10.0)
	var h := size + 10.0
	var r := Rect2(at.x, at.y - h * 0.5, w, h)
	ci.draw_rect(r, Color(1, 1, 1, 0.14))
	ci.draw_rect(r, INK, false, 2.0)
	ci.draw_string(font, Vector2(r.position.x, r.position.y + h * 0.5 + size * 0.36), k, HORIZONTAL_ALIGNMENT_CENTER, w, size, INK)
	return w
