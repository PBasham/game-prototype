class_name LiquidWindow
extends HudWindow
## A Liquid Barrel's window (right click or E on one): how much it holds, as a gauge.
## Liquids aren't in the game yet, so it's always empty for now; Siphon Liquid will
## fill and empty it later.

const W := 150
const GAUGE_H := 12

## The open barrel's anchor tile, or World.NO_TILE.
var anchor := World.NO_TILE


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Liquid Barrel")


func _def() -> ObjectDef:
	return hud.world.object_at(anchor) if anchor != World.NO_TILE else null


func layout() -> void:
	size = Vector2(W, BODY_TOP + GAUGE_H + 34)


func title_right() -> String:
	return ""


func draw_body(font: Font) -> void:
	var def := _def()
	if def == null:
		return
	title = def.display_name
	var amount := 0  # no liquids yet
	var r := Rect2(Hud.PAD, BODY_TOP + 4, size.x - Hud.PAD * 2, GAUGE_H)
	UiSkin.slot(self, r, UiSkin.SlotLook.NORMAL)
	var k := float(amount) / maxf(def.liquid_capacity, 1.0)
	if k > 0.0:
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * k, r.size.y - 4)), Color(0.3, 0.55, 0.95))
	var text := "%s / %s buckets" % [_group(amount), _group(def.liquid_capacity)]
	draw_string(font, Vector2(r.position.x, r.end.y + 11), "Empty" if amount == 0 else "Water", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	draw_string(font, Vector2(r.end.x - tw, r.end.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.TEXT)
	draw_string(font, Vector2(r.position.x, r.end.y + 22), "No liquids yet.", HORIZONTAL_ALIGNMENT_LEFT, size.x - Hud.PAD * 2, 6, UiSkin.DIM)


static func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
