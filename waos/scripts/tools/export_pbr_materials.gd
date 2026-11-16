@tool
extends SceneTree

const SpaceMaterials = preload("res://scripts/greybox/space_materials.gd")

func _init() -> void:
	DirAccess.make_dir_absolute("res://assets/materials")
	SpaceMaterials.init_materials()
	for mat_name in SpaceMaterials._materials.keys():
		var mat: StandardMaterial3D = SpaceMaterials._materials[mat_name]
		var path := "res://assets/materials/%s.tres" % mat_name
		var err := ResourceSaver.save(mat, path)
		print("Saved material ", path, " -> ", err == OK)
	quit()
