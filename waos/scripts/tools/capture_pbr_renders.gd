extends Node

const SpaceMaterials = preload("res://scripts/greybox/space_materials.gd")
const ModelLibrary = preload("res://scripts/greybox/model_library.gd")
const SpacecraftModel = preload("res://scripts/greybox/spacecraft_model.gd")

func _ready() -> void:
	print("Starting PBR Render Capture with full engine...")
	DirAccess.make_dir_absolute("res://art/screenshots_pbr")
	
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	
	# Iluminación de estudio aeroespacial
	var world := Node3D.new()
	vp.add_child(world)
	
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#070a12")
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#4a5875")
	sm.sky_horizon_color = Color("#717a90")
	sm.ground_bottom_color = Color("#181d2a")
	sm.ground_horizon_color = Color("#444b5c")
	sky.sky_material = sm
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#323d54")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	
	# Luz solar directa
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.48, 0.72, 0.2)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	world.add_child(sun)
	
	# Luz de relleno de albedo terrestre (earthshine)
	var earth_fill := DirectionalLight3D.new()
	earth_fill.rotation = Vector3(0.65, -1.8, 0.0)
	earth_fill.light_color = Color(0.35, 0.55, 0.85)
	earth_fill.light_energy = 0.55
	world.add_child(earth_fill)
	
	# Luz de borde trasera para siluetas nítidas (rim light)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-1.2, -2.6, 0.0)
	rim.light_color = Color(0.85, 0.92, 1.0)
	rim.light_energy = 0.75
	world.add_child(rim)
	
	var cam := Camera3D.new()
	cam.fov = 36.0
	world.add_child(cam)
	
	var holder := Node3D.new()
	world.add_child(holder)
	
	_render_sequence(vp, cam, holder)

func _render_sequence(vp: SubViewport, cam: Camera3D, holder: Node3D) -> void:
	var renders: Array = [
		{
			"name": "01_satellite_leostar2_full",
			"type": "craft",
			"design": {
				"bus": "leostar2",
				"pan": "pan400",
				"com": "ka",
				"prop": "biprop",
				"ins": ["cam", "ir", "mag", "rad"],
				"perfil": "sso_500", "lv": "f9_rtls", "term": "pasivo", "aocs": "reac"
			},
			"cam_dist": 4.5, "cam_pitch": 0.28, "cam_yaw": 0.55, "target_y": 0.0
		},
		{
			"name": "02_satellite_espa_deep_space",
			"type": "craft",
			"design": {
				"bus": "espa",
				"pan": "pan1500",
				"com": "xhga",
				"prop": "hall",
				"ins": ["sar", "mag", "neut"],
				"perfil": "nrho", "lv": "f9_exp", "term": "calentador", "aocs": "reac"
			},
			"cam_dist": 3.8, "cam_pitch": 0.32, "cam_yaw": 0.70, "target_y": 0.0
		},
		{
			"name": "03_satellite_cube3u_nanosat",
			"type": "craft",
			"design": {
				"bus": "cube3u",
				"pan": "pan8",
				"com": "uhf",
				"prop": "none",
				"ins": ["cubecam", "mag"],
				"perfil": "leo_400", "lv": "electron", "term": "pasivo", "aocs": "barras"
			},
			"cam_dist": 0.95, "cam_pitch": 0.35, "cam_yaw": 0.65, "target_y": 0.0
		},
		{
			"name": "04_solar_panel_pan400_closeup",
			"type": "model",
			"id": "pan400",
			"cam_dist": 2.4, "cam_pitch": 0.40, "cam_yaw": 0.35, "target_y": 0.0
		},
		{
			"name": "05_propulsion_biprop_closeup",
			"type": "model",
			"id": "biprop",
			"cam_dist": 1.6, "cam_pitch": 0.25, "cam_yaw": 0.75, "target_y": 0.0
		},
		{
			"name": "06_antenna_ka_dish_closeup",
			"type": "model",
			"id": "ka",
			"cam_dist": 1.5, "cam_pitch": 0.30, "cam_yaw": 0.45, "target_y": 0.2
		},
		{
			"name": "07_payload_camera_closeup",
			"type": "model",
			"id": "cam",
			"cam_dist": 1.1, "cam_pitch": 0.22, "cam_yaw": 0.60, "target_y": 0.0
		},
		{
			"name": "08_ground_dsn70_antenna",
			"type": "model",
			"id": "dsn70",
			"cam_dist": 3.6, "cam_pitch": 0.26, "cam_yaw": 0.50, "target_y": 0.8
		}
	]
	
	for item in renders:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		
		var node: Node3D = null
		if item["type"] == "craft":
			var craft := SpacecraftModel.new()
			craft.build(item["design"])
			node = craft
		elif item["type"] == "model":
			node = ModelLibrary.instance(item["id"])
		
		if node != null:
			holder.add_child(node)
			
		var dist: float = item["cam_dist"]
		var pitch: float = item["cam_pitch"]
		var yaw: float = item["cam_yaw"]
		var target_y: float = item.get("target_y", 0.0)
		
		var cx := cos(pitch) * sin(yaw) * dist
		var cy := sin(pitch) * dist + target_y
		var cz := cos(pitch) * cos(yaw) * dist
		
		cam.position = Vector3(cx, cy, cz)
		cam.look_at(Vector3(0, target_y, 0), Vector3.UP)
		
		for f in 4:
			await get_tree().process_frame
			
		var img := vp.get_texture().get_image()
		if img != null:
			var path := "res://art/screenshots_pbr/%s.png" % item["name"]
			var abs_path := ProjectSettings.globalize_path(path)
			var err := img.save_png(abs_path)
			print("Rendered ", item["name"], " -> ", abs_path, " (err=", err, ")")
			
	print("ALL PBR RENDERS COMPLETED SUCCESSFULLY!")
	get_tree().quit(0)
