extends Node
## Renderiza miniaturas 512x512 de cada modelo con texturas PBR directamente en Godot
## y actualiza assets/previews/ para que la UI muestre los acabados reales.

const SpaceMaterials = preload("res://scripts/greybox/space_materials.gd")
const ModelLibrary = preload("res://scripts/greybox/model_library.gd")

var _cam: Camera3D
var _holder: Node3D

func _ready() -> void:
	get_window().size = Vector2i(512, 512)
	get_tree().create_timer(180.0).timeout.connect(func(): get_tree().quit(1))
	DirAccess.make_dir_absolute("res://assets/previews")
	
	_build_scene()
	_render_all()

func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#070a12")
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#45526e")
	sm.sky_horizon_color = Color("#6b768c")
	sm.ground_bottom_color = Color("#141824")
	sm.ground_horizon_color = Color("#3d4554")
	sky.sky_material = sm
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#2a3346")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.52, 0.68, 0.25)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)
	
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(0.55, -1.9, 0.0)
	fill.light_color = Color(0.35, 0.55, 0.85)
	fill.light_energy = 0.6
	add_child(fill)
	
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-1.1, -2.5, 0.0)
	rim.light_color = Color(0.85, 0.92, 1.0)
	rim.light_energy = 0.8
	add_child(rim)
	
	_cam = Camera3D.new()
	_cam.fov = 32.0
	add_child(_cam)
	
	_holder = Node3D.new()
	add_child(_holder)

func _compute_aabb(node: Node3D) -> AABB:
	var total := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var curr := stack.pop_back() as Node
		if curr is MeshInstance3D:
			var mi := curr as MeshInstance3D
			if mi.mesh:
				var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
				var ab := xf * mi.mesh.get_aabb()
				if first:
					total = ab
					first = false
				else:
					total = total.merge(ab)
		for c in curr.get_children():
			stack.push_back(c)
	return total

func _render_all() -> void:
	var manifest: Dictionary = ModelLibrary.manifest()
	var count := 0
	
	for id in manifest.keys():
		for c in _holder.get_children():
			_holder.remove_child(c)
			c.queue_free()
		
		var inst := ModelLibrary.instance(id)
		if inst == null:
			continue
		
		_holder.add_child(inst)
		
		# Esperar 2 frames para que el grafo de escena propague matrices globales
		for f in 2:
			await get_tree().process_frame
		
		var aabb := _compute_aabb(inst)
		var center := aabb.get_center()
		var radius := maxf(aabb.size.length() * 0.5, 0.1)
		
		# Posicionar cámara a distancia óptima con ángulo isométrico aeroespacial
		var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
		var pitch := 0.28
		var yaw := 0.62
		
		var cx := cos(pitch) * sin(yaw) * dist + center.x
		var cy := sin(pitch) * dist + center.y
		var cz := cos(pitch) * cos(yaw) * dist + center.z
		
		_cam.position = Vector3(cx, cy, cz)
		_cam.look_at(center, Vector3.UP)
		
		for f in 8:
			await get_tree().process_frame
		
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var path := "res://assets/previews/%s.png" % id
			var abs_path := ProjectSettings.globalize_path(path)
			img.save_png(abs_path)
			count += 1
			print("[%d/%d] Miniatura PBR actualizada: %s" % [count, manifest.size(), id])
	
	print("TODAS LAS MINIATURAS PBR ACTUALIZADAS (%d)!" % count)
	get_tree().quit(0)
