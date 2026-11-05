extends RefCounted
## Pixel-art pipeline, stage 2: maps are ASCII grids; this bakes them into one
## texture with deterministic per-tile detail (so every grass tile differs but
## the same map always looks identical). 16px art tiles, drawn at 2x.

const TILE := 16

const SOLID := "#~Whrdxbt"

const INFO := {
	".": "Grass", ",": "Path", "\"": "Flowers", ":": "Memory moss", "#": "Trees",
	"~": "Water", "=": "Bridge", "W": "Stone wall", "f": "Plaza", "h": "House",
	"r": "Roof", "d": "Door", "x": "Void", "b": "Shelves", "p": "Paper floor",
	"t": "Stump", "*": "Starfield",
}


static func is_solid(ch: String) -> bool:
	return SOLID.contains(ch)


static func _h(x: int, y: int, salt: int) -> int:
	var n := x * 374761393 + y * 668265263 + salt * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


static func bake(rows: Array, palette_shift: Color = Color.WHITE) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = max(w, (r as String).length())
	var img := Image.create(w * TILE, h * TILE, false, Image.FORMAT_RGBA8)
	for ty in h:
		var row: String = rows[ty]
		for tx in w:
			var ch := row[tx] if tx < row.length() else "#"
			_draw_tile(img, tx, ty, ch)
	if palette_shift != Color.WHITE:
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, img.get_pixel(x, y) * palette_shift)
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, ox: int, oy: int, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(ox + x, oy + y, w, h), c)


static func _dots(img: Image, ox: int, oy: int, tx: int, ty: int, count: int, c: Color, salt: int) -> void:
	for i in count:
		var hv := _h(tx, ty, salt + i)
		img.set_pixel(ox + hv % TILE, oy + (hv / TILE) % TILE, c)


static func _draw_tile(img: Image, tx: int, ty: int, ch: String) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	match ch:
		".", "\"", ":":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("2c5236"))
			_dots(img, ox, oy, tx, ty, 10, Color("3b6d45"), 1)
			_dots(img, ox, oy, tx, ty, 4, Color("244630"), 2)
			if ch == "\"":
				_dots(img, ox, oy, tx, ty, 3, Color("c0a0ff"), 3)
				_dots(img, ox, oy, tx, ty, 2, Color("fff6d6"), 4)
			elif ch == ":":
				_dots(img, ox, oy, tx, ty, 5, Color("6fd3ff"), 5)
				_dots(img, ox, oy, tx, ty, 2, Color("b9f3ff"), 6)
		",":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("6b5a3e"))
			_dots(img, ox, oy, tx, ty, 6, Color("7d6a4a"), 7)
			_dots(img, ox, oy, tx, ty, 3, Color("54462f"), 8)
		"#":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("1d3a25"))
			_rect(img, ox, oy, 1, 1, 14, 11, Color("1f4a2a"))
			_rect(img, ox, oy, 2, 2, 11, 6, Color("2a5e36"))
			_rect(img, ox, oy, 4, 3, 5, 3, Color("3a7a46"))
			_dots(img, ox, oy, tx, ty, 4, Color("16301e"), 9)
			_rect(img, ox, oy, 6, 12, 4, 4, Color("4a2e1a"))
			_rect(img, ox, oy, 7, 12, 1, 4, Color("6a4428"))
		"t":
			_draw_tile(img, tx, ty, ".")
			_rect(img, ox, oy, 4, 6, 8, 8, Color("4a2e1a"))
			_rect(img, ox, oy, 5, 6, 6, 2, Color("8a6a40"))
		"~":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("22385e"))
			for i in 3:
				var hv := _h(tx, ty, 20 + i)
				_rect(img, ox, oy, hv % 10, 3 + i * 5, 5, 1, Color("3a6aa0"))
		"=":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("22385e"))
			_rect(img, ox, oy, 0, 2, TILE, 12, Color("7a5a36"))
			for i in 4:
				_rect(img, ox, oy, i * 4, 2, 1, 12, Color("5a3e24"))
		"W":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("4a4560"))
			for row in 4:
				var off := 0 if row % 2 == 0 else 4
				_rect(img, ox, oy, 0, row * 4, TILE, 1, Color("322e44"))
				_rect(img, ox, oy, off, row * 4, 1, 4, Color("322e44"))
				_rect(img, ox, oy, off + 8, row * 4, 1, 4, Color("322e44"))
		"f":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("6a6480"))
			_rect(img, ox, oy, 0, 0, TILE, 1, Color("57516c"))
			_rect(img, ox, oy, 0, 0, 1, TILE, Color("57516c"))
			_dots(img, ox, oy, tx, ty, 3, Color("7a7492"), 11)
		"h":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("7a5434"))
			for i in 4:
				_rect(img, ox, oy, 0, i * 4 + 3, TILE, 1, Color("5a3a22"))
			if _h(tx, ty, 12) % 3 == 0:
				_rect(img, ox, oy, 4, 4, 8, 6, Color("2a1e30"))
				_rect(img, ox, oy, 5, 5, 6, 4, Color("ffe08a"))
				_rect(img, ox, oy, 7, 5, 1, 4, Color("2a1e30"))
		"r":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("6a3a5e"))
			for i in 4:
				_rect(img, ox, oy, 0, i * 4, TILE, 1, Color("4e2846"))
				_rect(img, ox, oy, (i * 5) % 12, i * 4, 1, 4, Color("4e2846"))
		"d":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("7a5434"))
			_rect(img, ox, oy, 3, 2, 10, 14, Color("3e2616"))
			_rect(img, ox, oy, 10, 9, 2, 2, Color("e0b040"))
		"x", "*":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("07040e"))
			_dots(img, ox, oy, tx, ty, 2, Color("8a7ac0"), 13)
			if _h(tx, ty, 14) % 5 == 0:
				_dots(img, ox, oy, tx, ty, 1, Color("fff6d6"), 15)
		"b":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("3a2416"))
			for shelf in 3:
				_rect(img, ox, oy, 0, shelf * 5 + 4, TILE, 1, Color("1e120a"))
				for book in 5:
					var hv := _h(tx * 7 + book, ty + shelf, 16)
					var colors := [Color("8a3a4a"), Color("3a5a8a"), Color("6a8a3a"), Color("c0a060"), Color("6a4a8a")]
					_rect(img, ox, oy, 1 + book * 3, shelf * 5, 2, 4, colors[hv % 5])
		"p":
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("cfc4a6"))
			_rect(img, ox, oy, 0, 15, TILE, 1, Color("a89c80"))
			_rect(img, ox, oy, 15, 0, 1, TILE, Color("a89c80"))
			for i in 2:
				var hv := _h(tx, ty, 17 + i)
				_rect(img, ox, oy, 2 + hv % 4, 4 + i * 5, 6 + hv % 5, 1, Color("8a7e66"))
		_:
			_rect(img, ox, oy, 0, 0, TILE, TILE, Color("ff00ff"))
