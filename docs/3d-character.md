# Your 3D character (Blender to game)

How to model the Scholar (or any character) in Blender so the game can draw it as pixel
art. The 2D Scholar stays the default; the 3D body is a switch (console `body 3d`,
`body doll` to go back), so both can be kept and compared.

The game does the posing: it turns your character's bones to follow the same targets
the 2D doll uses (walking, swinging tools, casting, sitting, emotes), colors it with the
character's palette, shades it in hard bands and draws it at pixel resolution. You
model and rig it; you don't need to animate it.

## Quick start

1. In Blender, File > Import > glTF 2.0, and open `assets/body3d/mannequin.glb`. That's
   the placeholder: it shows the size, the way it faces, the bone names and the
   material names. Model over it, or start fresh.
2. Model, add an armature (rules below), bind the mesh to it (select the mesh, then the
   armature, Ctrl+P > With Automatic Weights), name the materials.
3. Save your `.blend` in `art/body3d/` (Blender source, not loaded by the game).
4. File > Export > glTF 2.0 to `assets/body3d/scholar.glb` (settings below).
5. In the game: `body 3d` (it uses `scholar.glb` when it's there, else the mannequin).
   Godot reimports the file whenever you export again; restart the game to see it.

## The rules

**Size and place.** Any height (about 1.8 m is natural); the game scales it to the
Scholar's height (63 art pixels, `Body3D.model_height`). Feet on the ground at the
origin, standing straight.

**Facing.** The character faces Blender's front view (Numpad 1 shows the face), which
is -Y. The game turns it to face the way you walk and a little toward the camera.

**Rest pose.** Standing, legs straight, arms down at the sides (a slight A is fine).

**Bones.** One armature. These names (Blender's Rigify names) are what the game looks
for; `.R` is the character's right side, which is the side toward the camera.

| Bone | From | To |
| --- | --- | --- |
| `hips` | between the hips (the root) | up into the spine |
| `spine` (and `spine.001`, `chest`... if you want more) | top of the hips | base of the neck |
| `neck` | base of the neck | base of the head |
| `head` | base of the head | top of the head |
| `upper_arm.R`, `upper_arm.L` | shoulder | elbow |
| `forearm.R`, `forearm.L` | elbow | wrist |
| `hand.R`, `hand.L` | wrist | fingertips |
| `thigh.R`, `thigh.L` | hip joint | knee |
| `shin.R`, `shin.L` | knee | ankle (or the point, like the Scholar's legs) |
| `foot.R`, `foot.L` (optional) | ankle | toes |

Children: spine on hips, neck on spine (the last spine bone), head on neck, upper arms
on the spine (or on a `shoulder` bone), forearm on upper arm, hand on forearm, thighs
on hips, shin on thigh, foot on shin. Other bones (fingers, hair, a cape) are fine;
they keep their rest pose for now. Common other names also work (`UpperLeg_R`,
`LowerArm_L`...).

The bone lengths and joint heights are measured from your model, so the doll's hands,
items and feet line up with your character's proportions.

**Materials.** Name each material after the color group it is:

| Material | What | Colored by |
| --- | --- | --- |
| `skin` | skin | the character's skin color |
| `hair` | hair | hair color |
| `tunic` | the tunic (gets the light trim line around it) | tunic color |
| `pants` | pants | pants color |
| `leather` | belt, boots, the leg points | leather color |
| `trim` | trim bands | trim color |

Their Base Color in Blender doesn't matter; the game uses the palette's shades
(`assets/sprites/scholar_palette.tres`), recolored by the character creator. Any other
material (a metal buckle, a gem) is shaded in the same bands from its own Base Color.
Textures aren't used yet.

**Detail.** Low poly reads best as pixels: a few hundred to a few thousand triangles.
Shapes and silhouette matter more than small details, which won't survive at 63
pixels tall. Smooth or flat shading in Blender both work (the bands do the shading).

## Export settings (File > Export > glTF 2.0)

- Format: glTF Binary (`.glb`).
- Include: the mesh and the armature (Limit to Selected or Visible Objects).
- Transform: +Y Up (on, the default).
- Mesh: Apply Modifiers (on).
- Animation: off (the game poses it; your animations aren't used yet).

## Looking at it in game

```
body 3d                  # your model (or the placeholder)
body doll                # the 2D Scholar
body detail 2            # pixels per art pixel: 1 (2D Scholar size) to 4
body bands 3             # shading bands: 2, 3 or 4
body turn 45             # how far it turns toward you when standing
body step 12 / smooth    # posed 12 times a second, or every frame
body colors srgb         # only if the colors look wrong (auto | as_is | srgb | linear)
body style model         # also: fit, blocky, soft, round (the code-made tests)
```

More tunables on the Player > Body3D node (Remote tree while the game runs): light
direction, trim line width (`trim_width`), hue shift, stance, turn speed.

## Not yet

- Your own animations from Blender (an idle, a run cycle, drawn key poses like sitting)
  instead of the code poses. Possible next: the game would play a Blender animation by
  name when it has one.
- Armor and hair overlays from the 2D doll aren't on the 3D body.
- Textures (colors come from the palette by material name).
