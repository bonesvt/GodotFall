extends Control
## A top-down map of a generated zone (level_plan.gd), drawn like a field map:
## shaded ground, the lanes in their colours (loud red, quiet blue, high
## orange), section names down the side, and, once the zone is built (`info`
## from zone_generator.gd), the grunts, their patrol routes, the caches, the
## loot, the beacon, the walls made to wallrun (blue) and the grapple hooks
## (orange diamonds). North (-Z, the way you go) is up.

const LANE_COLORS := {"loud": Color(1.0, 0.3, 0.22), "quiet": Color(0.3, 0.75, 1.0), "high": Color(1.0, 0.72, 0.18)}
const GROUND := {
	"forest": [Color(0.36, 0.5, 0.3), Color(0.62, 0.7, 0.5)],
	"marsh": [Color(0.24, 0.32, 0.26), Color(0.6, 0.62, 0.42)],
	"boneyard": [Color(0.4, 0.38, 0.38), Color(0.7, 0.66, 0.6)],
}
const SIDEBAR := 120.0
const HEADER := 64.0

var plan: RefCounted
var info := {}
## Pixels per metre.
var scale_px := 2.5
var _ground_tex: ImageTexture
var _x0 := 0.0
var _x1 := 0.0


func setup(p: RefCounted, built := {}, px_per_m := 2.5) -> void:
	plan = p
	info = built
	scale_px = px_per_m
	var w: float = plan.half_width(0.0) + 30.0
	_x0 = -w - 12.0
	_x1 = w + 12.0
	_ground_tex = ImageTexture.create_from_image(_ground_image())
	custom_minimum_size = Vector2(SIDEBAR + (_x1 - _x0) * scale_px, HEADER + (plan.z_top - plan.z_bottom) * scale_px)
	size = custom_minimum_size
	queue_redraw()


func to_map(x: float, z: float) -> Vector2:
	return Vector2(SIDEBAR + (x - _x0) * scale_px, HEADER + (z - plan.z_bottom) * scale_px)


## The ground at 1 m a pixel, shaded by height with light from the north-west.
func _ground_image() -> Image:
	var w := int(_x1 - _x0)
	var h := int(plan.z_top - plan.z_bottom)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var cols: Array = GROUND[plan.biome]
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	for iz in h:
		for ix in w:
			heights[iz * w + ix] = plan.ground(_x0 + ix + 0.5, plan.z_bottom + iz + 0.5)
	for iz in h:
		for ix in w:
			var y := heights[iz * w + ix]
			var gx := heights[iz * w + mini(ix + 1, w - 1)] - heights[iz * w + maxi(ix - 1, 0)]
			var gz := heights[mini(iz + 1, h - 1) * w + ix] - heights[maxi(iz - 1, 0) * w + ix]
			var shade := clampf(0.5 + 0.08 * y - 0.35 * (gx + gz), 0.0, 1.0)
			var c: Color = (cols[0] as Color).lerp(cols[1], shade)
			if y < plan.kill_y:
				c = Color(0.08, 0.1, 0.14).lerp(Color(0.16, 0.3, 0.36), clampf((y - plan.floor_y) / 6.0, 0.0, 1.0))
			elif plan.biome == "marsh" and y < -0.15:
				c = c.lerp(Color(0.14, 0.2, 0.18), 0.6)
			img.set_pixel(ix, iz, c)
	return img


func _draw() -> void:
	if plan == null:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1))
	var origin := to_map(_x0, plan.z_bottom)
	draw_texture_rect(_ground_tex, Rect2(origin, Vector2(_x1 - _x0, plan.z_top - plan.z_bottom) * scale_px), false)
	# Sections: a rule across at each boundary and the name in the sidebar.
	for s in plan.sections:
		var y: float = to_map(0, s["z1"]).y
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.25), 1.0)
		var label: String = s["kind"].to_upper()
		if s.has("cache"):
			label += "\n cache: " + s["cache"]
		_text(font, Vector2(6, to_map(0, s["mid"]).y), label, 13, Color(0.95, 0.92, 0.8))
	# Lanes.
	for i in plan.lanes.size():
		var lane: Dictionary = plan.lanes[i]
		var pts := PackedVector2Array()
		var z: float = plan.spawn_z
		while z >= plan.end_z:
			pts.append(to_map(plan.lane_x(i, z), z))
			z -= 2.0
		var col: Color = LANE_COLORS[lane["kind"]]
		col.a = 0.55
		draw_polyline(pts, col, 3.0 if lane["kind"] == "loud" else 2.0)
	if not info.is_empty():
		_draw_built(font)
	# Header: the zone, and the lanes left to right.
	draw_rect(Rect2(0, 0, size.x, HEADER - 4), Color(0.08, 0.08, 0.08, 0.92))
	_text(font, Vector2(8, 22), "%s   seed %d   %s" % [plan.zone_name, plan.seed_value, plan.biome], 18, Color(1, 0.95, 0.85))
	var x := 8.0
	for lane in plan.lanes:
		var t: String = lane["name"]
		draw_rect(Rect2(x, 36, 12, 12), LANE_COLORS[lane["kind"]])
		_text(font, Vector2(x + 16, 47), t, 12, Color(0.9, 0.9, 0.9))
		x += 22.0 + font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x


func _draw_built(font: Font) -> void:
	# Routes as built (rooftops, catwalks and crossings included).
	for route in info.get("routes", []):
		var pts := PackedVector2Array()
		for p in route["points"]:
			pts.append(to_map(p.x, p.z))
		draw_polyline(pts, LANE_COLORS[route["kind"]], 3.0)
	for poly in info.get("structures", []):
		var r: Rect2 = poly
		var a := to_map(r.position.x, r.position.y)
		var b := to_map(r.end.x, r.end.y)
		draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()), Color(0.15, 0.13, 0.12, 0.85))
	# Walls to run along (blue) and grapple hooks (orange diamonds).
	for w in info.get("wallruns", []):
		var a := to_map(w["from"].x, w["from"].z)
		var b := to_map(w["to"].x, w["to"].z)
		draw_line(a, b, Color(0.05, 0.1, 0.2), 6.0)
		draw_line(a, b, Color(0.35, 0.6, 1.0), 3.5)
	for h in info.get("grapple_spots", []):
		var p := to_map(h.x, h.z)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), Color(0.1, 0.05, 0.0))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), Color(1.0, 0.6, 0.15))
	for patrol in info.get("patrols", []):
		var pts := PackedVector2Array()
		for p in patrol:
			pts.append(to_map(p.x, p.z))
		pts.append(pts[0])
		for k in pts.size() - 1:
			draw_dashed_line(pts[k], pts[k + 1], Color(1, 0.55, 0.5), 2.0, 6.0)
	for node in info.get("loot", []):
		if not is_instance_valid(node):
			continue
		var p := to_map(node.position.x, node.position.z)
		if node.get_script() != null and String(node.get_script().resource_path).ends_with("resource_node.gd"):
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), Color(0.45, 0.95, 1.0))
		else:
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(0.85, 0.7, 0.45))
	for g in info.get("grunts", []):
		if not is_instance_valid(g):
			continue
		var p := to_map(g.position.x, g.position.z)
		draw_circle(p, 5.0, Color(0.1, 0.0, 0.0))
		draw_circle(p, 3.6, Color(1.0, 0.15, 0.1))
	for cache in info.get("caches", []):
		var p := to_map(cache.position.x, cache.position.z)
		draw_circle(p, 8.0, Color(0.1, 0.08, 0.0))
		draw_circle(p, 6.0, Color(1.0, 0.5, 0.1) if cache.locked else Color(1.0, 0.9, 0.2))
	for p in info.get("checkpoints", []):
		draw_circle(to_map(p.x, p.z), 2.5, Color(1, 1, 1, 0.8))
	var spawn: Vector3 = info["spawn"]
	_marker(font, to_map(spawn.x, spawn.z), "START", Color(1, 1, 1))
	if info.get("beacon") != null:
		var b: Vector3 = info["beacon"].position
		_marker(font, to_map(b.x, b.z), "EXTRACT", Color(0.4, 1.0, 0.6))


func _marker(font: Font, at: Vector2, text: String, col: Color) -> void:
	draw_circle(at, 7.0, Color(0, 0, 0))
	draw_circle(at, 5.0, col)
	_text(font, at + Vector2(10, 5), text, 13, col)


func _text(font: Font, at: Vector2, text: String, font_size: int, col: Color) -> void:
	var lines := text.split("\n")
	for k in lines.size():
		var p := at + Vector2(0, k * (font_size + 2))
		draw_string_outline(font, p, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.85))
		draw_string(font, p, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
