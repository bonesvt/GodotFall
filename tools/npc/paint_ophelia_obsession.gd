extends SceneTree
## Paints Ophelia's obsession outfits (obsession_look.gd, hub_npc.gd
## MISSION_OUTFITS) from her own textures, into assets/textures/npc/ophelia/:
##   upset     her tee as it is; her makeup run down her cheeks from crying
##             (body_upset.png, face_upset.png)
##   clingy    the hoodie re-dyed in Eco's colours, red with teal trim, and a
##             little teal spanner-heart pinned on the chest: Eco's, or made to
##             look it (body_clingy.png)
##   obsessed  the tee gone deep rose-black with a rose lace over it, the
##             striped sleeves black lace, the heart a hot rose; dark-rose
##             liner and shadow heavy round her eyes and dark rose lips
##             (body_obsessed.png, face_obsessed.png)
## Run headless, then import:
##   godot --headless --path . -s res://tools/npc/paint_ophelia_obsession.gd
##   godot --headless --path . --import

const DIR := "res://assets/textures/npc/ophelia/"
const ECO_RED := Color(0.62, 0.09, 0.12)
const TEAL := Color(0.2, 0.88, 0.92)
const ROSE := Color(0.95, 0.3, 0.55)
const ROSE_BLACK := Color(0.2, 0.03, 0.08)
## Her eyes and mouth on the face texture (1024 square).
const EYES := [Vector2(307, 540), Vector2(676, 540)]
const MOUTH := Vector2(512, 772)


func _initialize() -> void:
	var body := _load("body.png")
	var hoodie := _load("body_hoodie.png")
	var face := _load("face.png")
	_save(body.duplicate(), "body_upset.png")
	_save(_runny(face.duplicate()), "face_upset.png")
	_save(_clingy(hoodie), "body_clingy.png")
	_save(_obsessed(body), "body_obsessed.png")
	_save(_yandere_face(face.duplicate()), "face_obsessed.png")
	print("painted Ophelia's obsession outfits")
	quit()


func _load(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + name))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(DIR + name))


static func _lum(c: Color) -> float:
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b


## Purple-ish: her stripes, trims and streak colour.
static func _purple(c: Color) -> bool:
	return c.b > c.g + 0.12 and c.r > c.g + 0.05 and c.s > 0.3


## Skin: warm, light, low saturation.
static func _skin(c: Color) -> bool:
	return _lum(c) > 0.62 and c.r >= c.b


## The hoodie in Eco's red, its purple trims teal, a teal charm on the chest.
func _clingy(src: Image) -> Image:
	var img: Image = src.duplicate()
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			if _purple(c):
				img.set_pixel(x, y, TEAL * (0.6 + 0.6 * c.v))
			elif y < h * 0.5 and not _skin(c) and _lum(c) > 0.09 and _lum(c) < 0.45 and c.s < 0.25:
				# the hoodie's grey cloth (the top half of the sheet), keeping its shading
				var k := 0.55 + 1.6 * _lum(c)
				img.set_pixel(x, y, Color(ECO_RED.r * k, ECO_RED.g * k, ECO_RED.b * k))
	# a spanner through a heart, teal, pinned on her chest (left of the zip)
	var at := Vector2(w * 0.4, h * 0.27)
	_disc(img, at + Vector2(-26, 0), 30, TEAL)
	_disc(img, at + Vector2(26, 0), 30, TEAL)
	for i in 40:
		_disc(img, at + Vector2(0, 16 + i * 1.1), 42 - i, TEAL)
	_line(img, at + Vector2(-56, -56), at + Vector2(56, 72), 8, Color(0.85, 0.88, 0.9))
	_disc(img, at + Vector2(-56, -56), 16, Color(0.85, 0.88, 0.9))
	_disc(img, at + Vector2(-56, -56), 7, TEAL)
	return img


## The tee deep rose-black under a rose lace, the stripes black lace, the heart hot rose.
func _obsessed(src: Image) -> Image:
	var img: Image = src.duplicate()
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			if y >= h * 0.5:
				continue  # her trousers and boots stay black
			var lace: bool = (x % 10 <= 1 or y % 10 <= 1) and ((x / 10 + y / 10) % 2 == 0)
			if c.r > 0.6 and c.r > c.g + 0.25 and c.b > 0.3:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.45))  # the heart, hot rose
			elif _purple(c):
				# the striped sleeves: black lace, rose threads through it
				img.set_pixel(x, y, ROSE * 0.6 if lace else Color(0.05, 0.02, 0.04))
			elif not _skin(c) and _lum(c) < 0.3:
				var k := 0.6 + 2.0 * _lum(c)
				var base := Color(ROSE_BLACK.r * k, ROSE_BLACK.g * k, ROSE_BLACK.b * k)
				img.set_pixel(x, y, base.lerp(ROSE * 0.8, 0.8) if lace else base)
	return img


## Her makeup run down her cheeks: dark streaks from under each eye, smudged.
func _runny(img: Image) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for e in EYES:
		_smudge(img, e + Vector2(0, 14), Vector2(62, 22), Color(0.18, 0.14, 0.18), 0.45)
		for k in 3:
			var x: float = e.x - 30.0 + k * 28.0 + rng.randf_range(-6, 6)
			var y: float = e.y + 22.0
			var length := rng.randf_range(150, 260)
			var wob := rng.randf_range(0.0, 6.0)
			for t in int(length):
				var p := Vector2(x + sin((y + t) * 0.07 + wob) * 4.0, y + t)
				var fade := 1.0 - float(t) / length
				_disc_blend(img, p, 5.0 * (0.4 + 0.6 * fade), Color(0.12, 0.09, 0.12), 0.75 * fade)
	return img


## Heavy dark-rose liner and shadow round her eyes, dark rose lips.
func _yandere_face(img: Image) -> Image:
	for e in EYES:
		_smudge(img, e + Vector2(0, -6), Vector2(150, 64), Color(0.45, 0.06, 0.2), 0.6)
		_smudge(img, e + Vector2(0, 26), Vector2(80, 18), Color(0.3, 0.04, 0.14), 0.4)
	_smudge(img, MOUTH, Vector2(70, 20), Color(0.42, 0.04, 0.16), 0.85)
	return img


func _smudge(img: Image, c: Vector2, r: Vector2, col: Color, amt: float) -> void:
	for y in range(int(c.y - r.y), int(c.y + r.y) + 1):
		for x in range(int(c.x - r.x), int(c.x + r.x) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var q := Vector2((x - c.x) / r.x, (y - c.y) / r.y).length()
			if q > 1.0:
				continue
			var px := img.get_pixel(x, y)
			if px.get_luminance() > 0.93 and px.s < 0.05:
				continue  # the eye holes
			var k := smoothstep(1.0, 0.2, q) * amt
			img.set_pixel(x, y, px.lerp(Color(px.r * col.r, px.g * col.g, px.b * col.b).lerp(col, 0.5), k))


func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	_disc_blend(img, c, r, col, 1.0)


func _disc_blend(img: Image, c: Vector2, r: float, col: Color, amt: float) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x - c.x, y - c.y).length() <= r:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, amt))


func _line(img: Image, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	var n := int(a.distance_to(b))
	for i in n:
		_disc(img, a.lerp(b, float(i) / n), r, col)
