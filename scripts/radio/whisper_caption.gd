extends Control
## Eco's whisper caption: a soft, slanted line under the crosshair that
## breathes in word by word and fades away. Deliberately unlike the radio box:
## no frame, no callsign, just her voice. eco_whispers.gd drives it.

const FONT_SIZE := 21
const WIDTH := 640.0
## Where the caption's baseline sits, as a fraction of screen height. Below
## the crosshair, above the radio box and the speed readout.
const HEIGHT_FRACTION := 0.64
const WORDS_PER_SEC := 5.0
const FADE_IN := 0.25
const FADE_OUT := 0.9

const TEXT := Color(0.95, 0.93, 1.0)
const SHADOW := Color(0.04, 0.0, 0.06, 0.85)
const BACK := Color(0.02, 0.0, 0.04, 0.42)
const TAG := Color(0.95, 0.6, 0.66, 0.9)

var text := ""
var words := PackedStringArray()
var shown := 0.0  # words revealed so far (fractional: the next one fades in)
var alpha := 0.0
var live := false
var font: Font
var band_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)  # italic slant
	font = variation
	band_style.set_corner_radius_all(16)
	band_style.shadow_size = 18  # feathers the band's edge


func show_line(line: String) -> void:
	text = line
	words = line.split(" ", false)
	shown = 0.0
	live = true


func end_line() -> void:
	live = false


func is_showing() -> bool:
	return alpha > 0.01


## The line on screen, for tests.
func current_text() -> String:
	return text if is_showing() or live else ""


func _process(delta: float) -> void:
	alpha = move_toward(alpha, 1.0 if live else 0.0, delta / (FADE_IN if live else FADE_OUT))
	if live:
		shown = minf(shown + delta * WORDS_PER_SEC, words.size())
	elif alpha <= 0.0:
		text = ""
		words = PackedStringArray()
	queue_redraw()


func _draw() -> void:
	if words.is_empty() or alpha <= 0.0:
		return
	var rows := _wrap()
	var y := size.y * HEIGHT_FRACTION
	var tag := "eco, whispering"
	var tag_w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	# A soft dark band so the words read on snow and sky alike.
	var widest := tag_w
	for row in rows:
		widest = maxf(widest, font.get_string_size(" ".join(row), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var band := Rect2(size.x * 0.5 - widest * 0.5 - 18.0, y - FONT_SIZE - 26.0, widest + 36.0, 34.0 + rows.size() * (FONT_SIZE + 6.0))
	band_style.bg_color = Color(BACK, BACK.a * alpha)
	band_style.shadow_color = Color(BACK, BACK.a * alpha * 0.8)
	draw_style_box(band_style, band)
	_draw_text(Vector2(size.x * 0.5 - tag_w * 0.5, y - FONT_SIZE - 6.0), tag, 13, Color(TAG, TAG.a * alpha))
	var word_i := 0
	for row in rows:
		var row_w := font.get_string_size(" ".join(row), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var x := size.x * 0.5 - row_w * 0.5
		for w in row:
			var a := clampf(shown - word_i, 0.0, 1.0) * alpha
			if a > 0.0:
				_draw_text(Vector2(x, y), w, FONT_SIZE, Color(TEXT, a))
			x += font.get_string_size(w + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			word_i += 1
		y += FONT_SIZE + 6.0


func _draw_text(at: Vector2, s: String, size_px: int, color: Color) -> void:
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(SHADOW, SHADOW.a * color.a))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _wrap() -> Array:
	var rows: Array = []
	var row := PackedStringArray()
	for w in words:
		var test := " ".join(row + PackedStringArray([w]))
		if not row.is_empty() and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > WIDTH:
			rows.append(row)
			row = PackedStringArray()
		row.append(w)
	if not row.is_empty():
		rows.append(row)
	return rows
