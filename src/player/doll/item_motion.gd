class_name ItemMotion
extends Resource
## One arm animation for an item: how it's held, or one attack/use. Code-posed from
## curves, or played from hand-drawn frames when the art has them.
##
## Drawn frames: the doll looks for the tag "arms/<item id>/<name>", then
## "arms/<type id>/<name>", then "arms/<drawn_tag>", and plays the first it finds across
## the motion. Otherwise the curves below pose the arms.

enum ItemAngle {
	ARM,    ## item points along the holding arm, plus `item_angle`
	AIM,    ## item points at the cursor, plus `item_angle`
	FIXED,  ## item angle is `item_angle` (degrees: 0 = forward, -90 = up)
}

## Name used for drawn tags ("Slash", "Fire", "Hold").
@export var name := ""
## Seconds. Hold motions loop over this.
@export var duration := 0.35
## Arm angles are relative to the direction of the cursor, and the body faces it.
@export var aims := false
@export var front: ArmTrack
@export var back: ArmTrack
@export var item_angle_mode := ItemAngle.ARM
## Degrees, over the motion (see item_angle_mode).
@export var item_angle: Curve
## Upper body leans forward this many pixels over the motion (a lunge into a stab).
@export var lunge: Curve
## Generic drawn tag to fall back on ("Hold1H", "Hold2H", "Use").
@export var drawn_tag := ""


func item_angle_at(t: float) -> float:
	return item_angle.sample(t) if item_angle else 0.0


func lunge_at(t: float) -> float:
	return lunge.sample(t) if lunge else 0.0
