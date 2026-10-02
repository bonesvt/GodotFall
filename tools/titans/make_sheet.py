#!/usr/bin/env python3
"""Lays the showcase renders out as one reference sheet.

    python3 tools/titans/make_sheet.py SHOTS_DIR OUT.jpg
"""
import sys

from PIL import Image, ImageDraw, ImageFont

SHOTS, OUT = sys.argv[1], sys.argv[2]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BODY = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
TITANS = [
	("atlas", "ATLAS", "sky blue + orange, twin headlights, XO-16"),
	("ogre", "OGRE", "mustard + army green, bull bar, armour slabs, Tracker"),
	("stryder", "STRYDER", "white + red, raked nose, tail fins, jet, Splitter"),
	("scrap", "SCRAP", "rusty olive buggy: open tub, seat, odd panels"),
	("enemy", "ENEMY TITAN", "candy crimson + cream, blades, red eyes"),
	("wreck", "DAD'S TITAN (HUB)", "Atlas blue + orange stripe, wrecked"),
]
GUNS = [("xo16", "XO-16"), ("tracker", "TRACKER"), ("splitter", "SPLITTER"), ("scrap", "SCRAP RIFLE")]
BG = (24, 22, 26)
INK = (240, 232, 214)
DIM = (170, 160, 145)
ACCENT = (255, 140, 30)


def img(name, size):
	return Image.open(f"{SHOTS}/{name}.png").convert("RGB").resize(size, Image.LANCZOS)


def main():
	big, small, pad = 560, 280, 24
	card_w, card_h = big + small, big
	cols = 3
	W = cols * card_w + (cols + 1) * pad
	head = 120
	label = 70
	rows_h = 2 * (card_h + label + pad)
	gun = (W - 5 * pad) // 4
	H = head + rows_h + 60 + gun + label + pad
	sheet = Image.new("RGB", (W, H), BG)
	d = ImageDraw.Draw(sheet)
	title = ImageFont.truetype(FONT, 56)
	name = ImageFont.truetype(FONT, 30)
	note = ImageFont.truetype(BODY, 22)
	d.text((pad, 24), "TITANS / JAK GARAGE PASS", font=title, fill=INK)
	d.rectangle((pad, 94, pad + 520, 100), fill=ACCENT)
	d.text((pad + 980, 46), "glossy chipped paint, racing stripes, roll cages, tyre knees, exposed engines", font=note, fill=DIM)
	for i, (id, nm, desc) in enumerate(TITANS):
		x = pad + (i % cols) * (card_w + pad)
		y = head + (i // cols) * (card_h + label + pad)
		sheet.paste(img(f"{id}_front", (big, big)), (x, y))
		sheet.paste(img(f"{id}_back", (small, small)), (x + big, y))
		sheet.paste(img(f"{id}_side" if id == "wreck" else f"{id}_cockpit", (small, small)), (x + big, y + small))
		d.text((x, y + card_h + 8), nm, font=name, fill=ACCENT if id in ("enemy", "wreck") else INK)
		d.text((x, y + card_h + 42), desc, font=note, fill=DIM)
	y = head + rows_h + 10
	d.text((pad, y), "TITAN WEAPONS", font=name, fill=INK)
	y += 50
	for i, (id, nm) in enumerate(GUNS):
		x = pad + i * (gun + pad)
		sheet.paste(img(f"gun_{id}", (gun, gun)), (x, y))
		d.text((x, y + gun + 8), nm, font=name, fill=INK)
	sheet.save(OUT, quality=88)
	print("wrote", OUT, sheet.size)


main()
