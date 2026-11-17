class_name DevHeldItems
extends Node
## Debug builds only: placeholder items to test holding, using, aiming and putting away
## until real items arrive in Phase 4. Keys 1 to 5 pick one; H puts it away.
##
##   1  empty hands
##   2  one-handed tool (swings, stows on the back)
##   3  two-handed tool (swings, both hands, stows on the back)
##   4  wand (aims at the cursor, disappears when put away)
##   5  small one-handed item (stows at the hip)
##
## Textures are drawn in code: gray placeholder shapes, not content.

var player: Player
var items: Array[HeldItemLook] = []


func _ready() -> void:
	items = make_items()


func _process(_delta: float) -> void:
	# Polled (not _unhandled_input) so scripted runs (DevCli --tap) work too.
	for i in 5:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			player.hold(items[i - 1] if i > 0 else null)


## The test items (index 0 = tool, 1 = two-hander, 2 = wand, 3 = small item).
static func make_items() -> Array[HeldItemLook]:
	var tool := HeldItemLook.new()
	tool.texture = _draw_tool(16, Color("8a6a44"), Color("9aa0a8"), 5)
	tool.grip = Vector2(3, 12)
	tool.hold_angle = -65.0

	var big := HeldItemLook.new()
	big.texture = _draw_tool(22, Color("7a5a38"), Color("8a9098"), 8)
	big.hold_style = HeldItemLook.HoldStyle.TWO_HAND
	big.grip = Vector2(6, 15)
	big.grip2 = Vector2(3, 18)
	big.hold_angle = -55.0
	big.use_time = 0.5

	var wand := HeldItemLook.new()
	wand.texture = _draw_wand()
	wand.hold_style = HeldItemLook.HoldStyle.AIM
	wand.use_style = HeldItemLook.UseStyle.AIM
	wand.stow_style = HeldItemLook.StowStyle.HIDDEN
	wand.grip = Vector2(2, 9)

	var small := HeldItemLook.new()
	small.texture = _draw_tool(10, Color("6a4a30"), Color("b0b6be"), 0)
	small.stow_style = HeldItemLook.StowStyle.HIP
	small.grip = Vector2(2, 7)
	small.hold_angle = -30.0
	small.use_time = 0.25
	return [tool, big, wand, small]


## A handle along the up-right diagonal with an optional crossbar head at the top.
static func _draw_tool(size: int, handle: Color, head: Color, head_len: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for i in range(1, size - 1):
		img.set_pixel(i, size - 1 - i, handle)
		if i + 1 < size - 1:
			img.set_pixel(i + 1, size - 1 - i, handle.darkened(0.3))
	if head_len > 0:
		var tip := size - 3
		for k in range(-head_len / 2, head_len / 2 + 1):
			var x := tip + k
			var y := 2 + k
			if x >= 0 and x < size and y >= 0 and y < size:
				img.set_pixel(x, y, head)
				if y + 1 < size:
					img.set_pixel(x, y + 1, head.darkened(0.35))
	else:
		for i in range(size / 2, size - 1):
			img.set_pixel(i, size - 1 - i, head)
	return ImageTexture.create_from_image(img)


static func _draw_wand() -> ImageTexture:
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	for i in range(1, 9):
		img.set_pixel(i, 11 - i, Color("5a3a28"))
	for p: Vector2i in [Vector2i(9, 1), Vector2i(10, 1), Vector2i(9, 2), Vector2i(10, 2), Vector2i(8, 2), Vector2i(10, 0)]:
		img.set_pixel(p.x, p.y, Color("7fd4ff"))
	return ImageTexture.create_from_image(img)
