class_name ArmTrack
extends Resource
## What one arm does during an ItemMotion.
##
##   NATURAL  the arm follows the movement animation (swinging with the run)
##   POSE     code places the hand: `angle` (degrees: 0 = forward, -90 = up, 90 = down,
##            180 = behind) and `reach` (hand distance from the shoulder as a fraction
##            of the arm's length; 1 = straight, 0.5 = elbow well bent), both over the
##            motion (curve x = 0..1 through the motion)
##   GRIP     the hand holds the item's other grip (two-handed items), pulled back
##            along the item by `pull` pixels (drawing a bow)
##
## Curves are edited in the Inspector. One point = a constant.

enum Mode { NATURAL, POSE, GRIP }

@export var mode := Mode.NATURAL
## When the motion aims, this arm's angle is measured from the aim direction (it turns
## with the cursor). Off = measured from forward, so the arm stays put while the other
## one aims (the hand holding a spell book).
@export var follows_aim := true
@export var angle: Curve
@export var reach: Curve
@export var pull: Curve


func angle_at(t: float) -> float:
	return angle.sample(t) if angle else 0.0


func reach_at(t: float) -> float:
	return clampf(reach.sample(t), 0.05, 1.0) if reach else 1.0


func pull_at(t: float) -> float:
	return pull.sample(t) if pull else 0.0
