class_name HeldItemLook
extends Resource
## How an item looks and sits in the character's hands. Items (Phase 4) will each point
## at one of these; the paper doll reads it to pick the arm pose.
##
## Texture convention: draw the item pointing up and to the right (like an inventory
## icon), handle at the bottom left. `grip` is the pixel the front hand holds.

enum HoldStyle {
	ONE_HAND,  ## front hand holds it; back arm free
	TWO_HAND,  ## both hands (second hand at grip2)
	AIM,       ## arms point at the cursor while held (wands, spells, guns)
}
enum UseStyle {
	SWING,  ## clicking swings it overhead to forward (pickaxe, sword, axe)
	AIM,    ## clicking keeps aiming at the cursor (spells, wands)
	NONE,
}
enum StowStyle {
	BACK,    ## put away: across the back
	HIP,     ## put away: at the hip
	HIDDEN,  ## put away: not shown
}

@export var texture: Texture2D
@export var hold_style := HoldStyle.ONE_HAND
@export var use_style := UseStyle.SWING
@export var stow_style := StowStyle.BACK
## Pixel in the texture the front hand holds.
@export var grip := Vector2(3, 13)
## Pixel the back hand holds (TWO_HAND).
@export var grip2 := Vector2(7, 9)
## Angle the item points while just held, degrees (0 = forward, -90 = straight up).
@export var hold_angle := -60.0
## Seconds per swing.
@export var use_time := 0.35
## Swing arc: arm angle at the start and end, degrees (0 = forward, -90 = up).
@export var swing_from := -140.0
@export var swing_to := 30.0
## Faces the cursor while held (AIM always does). Use always faces the cursor.
@export var face_cursor := false
