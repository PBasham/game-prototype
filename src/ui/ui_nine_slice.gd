class_name UiNineSlice
extends StyleBox
## A nine-slice box whose art has `detail` art pixels per UI pixel (Phase 91: the UI art
## is drawn at 3x for crisp detail). Like StyleBoxTexture, but the corners and edges are
## drawn at 1/detail scale, so a 3x picture fits the same space as the old 1x one.

var texture: Texture2D
## The border, in art pixels (the corners keep their size, the rest stretches).
var margin := 8
var detail := 3


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var ts := texture.get_size()
	var m := float(margin)
	var d := m / float(detail)
	# Small boxes: shrink the border so the corners don't overlap.
	d = minf(d, minf(rect.size.x, rect.size.y) * 0.5)
	var sx := [0.0, m, ts.x - m, ts.x]
	var sy := [0.0, m, ts.y - m, ts.y]
	var dx := [rect.position.x, rect.position.x + d, rect.end.x - d, rect.end.x]
	var dy := [rect.position.y, rect.position.y + d, rect.end.y - d, rect.end.y]
	var rid := texture.get_rid()
	for j in 3:
		for i in 3:
			var dst := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			if dst.size.x <= 0.0 or dst.size.y <= 0.0:
				continue
			var src := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, dst, rid, src)
