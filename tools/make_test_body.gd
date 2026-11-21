extends SceneTree
## Makes the placeholder 3D character: a rigged mannequin with the bone names and
## material names the game expects (docs/3d-character.md), exported as glTF binary.
## Open it in Blender to see the setup; Patrick's own model replaces it.
##
##   godot --headless --path . --script res://tools/make_test_body.gd
##   (-- --out=res://assets/body3d/mannequin.glb to write elsewhere; kept unless --force)
##
## Built like a Blender export: meters, Y up, facing +Z (Blender's -Y "front"), the
## character's right side toward -X, bones pointing along their own +Y.

const PX := 1.8 / 63.0  # meters per art pixel (63 art pixels tall = 1.8 m)

## Bones: name -> [parent, head (art px, x = character's left), tail]. Rigify names.
const BONES := {
	"hips": ["", Vector3(0, 31, 0), Vector3(0, 34, 0)],
	"spine": ["hips", Vector3(0, 34, 0), Vector3(0, 50.5, 0)],
	"neck": ["spine", Vector3(0, 50.5, 0), Vector3(0, 53.5, 0)],
	"head": ["neck", Vector3(0, 53.5, 0), Vector3(0, 63, 0)],
	"upper_arm.R": ["spine", Vector3(-5.2, 50.5, 0), Vector3(-5.8, 40, 0)],
	"forearm.R": ["upper_arm.R", Vector3(-5.8, 40, 0), Vector3(-6.0, 30.5, 0)],
	"hand.R": ["forearm.R", Vector3(-6.0, 30.5, 0), Vector3(-6.0, 26.5, 0)],
	"upper_arm.L": ["spine", Vector3(5.2, 50.5, 0), Vector3(5.8, 40, 0)],
	"forearm.L": ["upper_arm.L", Vector3(5.8, 40, 0), Vector3(6.0, 30.5, 0)],
	"hand.L": ["forearm.L", Vector3(6.0, 30.5, 0), Vector3(6.0, 26.5, 0)],
	"thigh.R": ["hips", Vector3(-2.6, 31, 0), Vector3(-2.6, 18, 0)],
	"shin.R": ["thigh.R", Vector3(-2.6, 18, 0), Vector3(-2.6, 0, 0)],
	"thigh.L": ["hips", Vector3(2.6, 31, 0), Vector3(2.6, 18, 0)],
	"shin.L": ["thigh.L", Vector3(2.6, 18, 0), Vector3(2.6, 0, 0)],
}

## Shapes: [bone, profile (Body3D.FIT key), material, from, to (art px), depth scale].
const SHAPES := [
	["spine", &"torso", "tunic", Vector3(0, 30, 0), Vector3(0, 51, 0), 0.62],
	["spine", &"belt", "leather", Vector3(0, 33.2, 0), Vector3(0, 34.8, 0), 0.64],
	["neck", &"neck", "skin", Vector3(0, 49.5, 0), Vector3(0, 54, 0), 0.95],
	["head", &"head", "skin", Vector3(0, 53.4, 0), Vector3(0, 62, 0), 0.95],
	["head", &"hair", "hair", Vector3(0, 59.5, -0.3), Vector3(0, 63, -0.3), 1.0],
	["head", &"hair_back", "hair", Vector3(0, 55, -2.3), Vector3(0, 61, -2.3), 0.36],
	["thigh.R", &"skirt", "tunic", Vector3(-2.0, 20, 0), Vector3(-2.0, 32.5, 0), 0.68],
	["thigh.L", &"skirt", "tunic", Vector3(2.0, 20, 0), Vector3(2.0, 32.5, 0), 0.68],
	["thigh.R", &"hem", "trim", Vector3(-2.0, 19.6, 0), Vector3(-2.0, 20.8, 0), 0.68],
	["thigh.L", &"hem", "trim", Vector3(2.0, 19.6, 0), Vector3(2.0, 20.8, 0), 0.68],
	["thigh.R", &"thigh", "pants", Vector3(-2.6, 31, 0), Vector3(-2.6, 18, 0), 1.0],
	["thigh.L", &"thigh", "pants", Vector3(2.6, 31, 0), Vector3(2.6, 18, 0), 1.0],
	["shin.R", &"shin", "pants", Vector3(-2.6, 18, 0), Vector3(-2.6, 4, 0), 1.0],
	["shin.L", &"shin", "pants", Vector3(2.6, 18, 0), Vector3(2.6, 4, 0), 1.0],
	["shin.R", &"tip", "leather", Vector3(-2.6, 4, 0), Vector3(-2.6, 0, 0), 1.0],
	["shin.L", &"tip", "leather", Vector3(2.6, 4, 0), Vector3(2.6, 0, 0), 1.0],
	["upper_arm.R", &"upper_arm", "skin", Vector3(-5.2, 50.5, 0), Vector3(-5.8, 40, 0), 1.0],
	["upper_arm.L", &"upper_arm", "skin", Vector3(5.2, 50.5, 0), Vector3(5.8, 40, 0), 1.0],
	["forearm.R", &"forearm", "skin", Vector3(-5.8, 40, 0), Vector3(-6.0, 30.5, 0), 1.0],
	["forearm.L", &"forearm", "skin", Vector3(5.8, 40, 0), Vector3(6.0, 30.5, 0), 1.0],
	["hand.R", &"hand", "skin", Vector3(-6.0, 30.5, 0), Vector3(-6.0, 26.5, 0), 0.6],
	["hand.L", &"hand", "skin", Vector3(6.0, 30.5, 0), Vector3(6.0, 26.5, 0), 0.6],
]


func _init() -> void:
	var out := "res://assets/body3d/mannequin.glb"
	var force := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--force":
			force = true
	if FileAccess.file_exists(out) and not force:
		print("Kept %s (use --force to replace it)" % out)
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))

	var root := Node3D.new()
	root.name = "Mannequin"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	root.add_child(skel)
	skel.owner = root
	var globals := {}
	for bone: String in BONES:
		var b: Array = BONES[bone]
		var head: Vector3 = (b[1] as Vector3) * PX
		var tail: Vector3 = (b[2] as Vector3) * PX
		var g := Transform3D(_basis_along(tail - head), head)
		globals[bone] = g
		var idx := skel.add_bone(bone)
		var parent := -1
		var local := g
		if b[0] != "":
			parent = skel.find_bone(b[0])
			local = (globals[b[0]] as Transform3D).affine_inverse() * g
		skel.set_bone_parent(idx, parent)
		skel.set_bone_rest(idx, local)
		skel.set_bone_pose(idx, local)

	# One surface per material, every vertex on one bone (rigid parts).
	var tools := {}
	for sh: Array in SHAPES:
		var mat: String = sh[2]
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
		_add_shape(tools[mat], skel.find_bone(sh[0]), Body3D.FIT[sh[1]], (sh[3] as Vector3) * PX, (sh[4] as Vector3) * PX, sh[5])
	var mesh := ArrayMesh.new()
	for mat: String in tools:
		var st: SurfaceTool = tools[mat]
		st.commit(mesh)
		var m := StandardMaterial3D.new()
		m.resource_name = mat
		m.albedo_color = _preview_color(mat)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		mesh.surface_set_name(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	skel.add_child(mi)
	mi.owner = root
	mi.skeleton = NodePath("..")
	mi.skin = skel.create_skin_from_rest_transforms()

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(out))
	print("Wrote %s" % out if err == OK else "Failed to write %s: %s" % [out, error_string(err)])
	root.free()
	quit()


## A basis whose +Y runs along `dir` (bones point along their own +Y, like Blender's).
static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3(1, 0, 0) if absf(y.x) < 0.9 else Vector3(0, 0, 1)
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)


## A lathe shape (Body3D profile, art px radii) from a to b, on one bone.
static func _add_shape(st: SurfaceTool, bone: int, profile: Array, a: Vector3, b: Vector3, depth: float) -> void:
	var lm := Body3D.lathe(profile, 16)
	var arr := lm.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var axis := b - a
	var y := axis.normalized()
	var z := Vector3(0, 0, 1) if absf(y.z) < 0.9 else Vector3(1, 0, 0)  # depth toward the front
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	# Lathe: x and z are radius (art px), y is 0..1 along the axis.
	var basis := Basis(x * PX, axis, z * PX * depth)
	var nbasis := basis.inverse().transposed()
	for i in verts.size():
		st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.set_normal((nbasis * norms[i]).normalized())
		st.add_vertex(a + basis * verts[i])


static func _preview_color(mat: String) -> Color:
	return {"skin": Color(0.9, 0.72, 0.56), "hair": Color(0.36, 0.23, 0.13), "tunic": Color(0.2, 0.4, 0.8),
		"pants": Color(0.3, 0.53, 0.94), "leather": Color(0.3, 0.22, 0.2), "trim": Color(0.73, 0.83, 0.97)}.get(mat, Color.GRAY)
