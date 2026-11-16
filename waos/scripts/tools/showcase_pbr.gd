extends Node
## Renderizador de vitrina de modelos PBR con iluminación de estudio espacial NASA.
## Captura planos generales y detalles en alta resolución (1600x900).

const SpaceMaterials = preload("res://scripts/greybox/space_materials.gd")
const ModelLibrary = preload("res://scripts/greybox/model_library.gd")
const SpacecraftModel = preload("res://scripts/greybox/spacecraft_model.gd")

var _cam: Camera3D
var _holder: Node3D
var _title_lbl: Label
var _desc_lbl: Label

func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(1))
	DirAccess.make_dir_absolute("res://art/screenshots_pbr")
	
	_build_scene()
	_run_captures()

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
	
	# Sol principal
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.52, 0.68, 0.25)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)
	
	# Reflejo terrestre (earthshine azul)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(0.55, -1.9, 0.0)
	fill.light_color = Color(0.35, 0.55, 0.85)
	fill.light_energy = 0.6
	add_child(fill)
	
	# Rim light trasero
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-1.1, -2.5, 0.0)
	rim.light_color = Color(0.85, 0.92, 1.0)
	rim.light_energy = 0.8
	add_child(rim)
	
	_cam = Camera3D.new()
	_cam.fov = 34.0
	add_child(_cam)
	
	_holder = Node3D.new()
	add_child(_holder)
	
	# HUD con datos de ingeniería del modelo
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	ui.add_child(box)
	
	var tag := Label.new()
	tag.text = "NASA SPACE APPS CHALLENGE 2026 · PBR SATELLITE CAD SHOWCASE"
	tag.modulate = Color("#38bdf8")
	box.add_child(tag)
	
	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.modulate = Color("#f8fafc")
	box.add_child(_title_lbl)
	
	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", 14)
	_desc_lbl.modulate = Color("#94a3b8")
	box.add_child(_desc_lbl)

func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var p := "res://art/screenshots_pbr/%s.png" % filename
		var abs_p := ProjectSettings.globalize_path(p)
		img.save_png(abs_p)
		print("Guardada captura: ", abs_p)

func _run_captures() -> void:
	var items: Array = [
		{
			"file": "showcase_01_leostar2_radar_full",
			"title": "LeoStar-2 · Observatorio SAR y Cargas Útiles Complejas",
			"desc": "Cuerpo recubierto en MLI Oro (Foil002), alas solares fotovoltaicas (SolarPanel002), plato Ka-band y radar SAR.",
			"type": "craft",
			"design": {
				"bus": "leostar2", "pan": "pan400", "com": "ka", "prop": "biprop",
				"ins": ["sar", "cam", "ir", "rad"], "perfil": "sso_500", "lv": "f9_rtls", "term": "pasivo", "aocs": "reac"
			},
			"dist": 4.8, "pitch": 0.28, "yaw": 0.65, "ty": 0.0
		},
		{
			"file": "showcase_02_espa_deepspace_nrho",
			"title": "Plataforma ESPA · Sonda Interplanetaria L1 / NRHO",
			"desc": "Aislamiento térmico MLI Plata (Foil003), propulsión eléctrica Hall con toberas de xenón y antena parabólica HGA.",
			"type": "craft",
			"design": {
				"bus": "espa", "pan": "pan1500", "com": "xhga", "prop": "hall",
				"ins": ["mag", "neut"], "perfil": "nrho", "lv": "f9_exp", "term": "calentador", "aocs": "reac"
			},
			"dist": 4.2, "pitch": 0.32, "yaw": 0.72, "ty": 0.0
		},
		{
			"file": "showcase_03_cube3u_nanosat",
			"title": "CubeSat 3U · Microsatélite de Observación Terrestre",
			"desc": "Celdas solares integradas, láminas de Kapton poliimida, rieles de aluminio 6061-T6 y cámara CubeCam con lente de sílice.",
			"type": "craft",
			"design": {
				"bus": "cube3u", "pan": "pan8", "com": "uhf", "prop": "none",
				"ins": ["cubecam", "mag"], "perfil": "leo_400", "lv": "electron", "term": "pasivo", "aocs": "barras"
			},
			"dist": 0.85, "pitch": 0.32, "yaw": 0.58, "ty": 0.0
		},
		{
			"file": "showcase_04_pan400_solar_cells",
			"title": "Arreglo Solar Desplegable 400 W (PAN400)",
			"desc": "Celdas fotovoltaicas de triple unión con busbars metálicos, marco de fibra de carbono y bisagras de aluminio.",
			"type": "model", "id": "pan400",
			"dist": 2.8, "pitch": 0.34, "yaw": 0.35, "ty": 0.65
		},
		{
			"file": "showcase_05_biprop_engine",
			"title": "Módulo de Propulsión Bipropelente Líquido",
			"desc": "Cuatro tanques esferoidales de titanio, toberas divergentes de alta expansión y soporte estructural anodizado.",
			"type": "model", "id": "biprop",
			"dist": 3.4, "pitch": 0.30, "yaw": 0.75, "ty": 0.45
		},
		{
			"file": "showcase_06_ka_dish_antenna",
			"title": "Antena Parabólica Orientable Banda Ka (1 m)",
			"desc": "Reflector parabólico de fibra compuesta metalizada, bocina alimentadora de cobre y articulación de guiado.",
			"type": "model", "id": "ka",
			"dist": 2.5, "pitch": 0.28, "yaw": 0.45, "ty": 0.95
		},
		{
			"file": "showcase_07_cam_optical_telescope",
			"title": "Cámara Óptica Multiespectral de Alta Resolución",
			"desc": "Lente frontal de cristal óptico con recubrimiento antirreflectante, tubo de fibra de carbono y montura de titanio.",
			"type": "model", "id": "cam",
			"dist": 1.4, "pitch": 0.22, "yaw": 0.55, "ty": 0.32
		},
		{
			"file": "showcase_08_dsn70_deep_space_network",
			"title": "Estación Terrena Deep Space Network 70 m (Goldstone / Madrid / Canberra)",
			"desc": "Plato reflector monumental de 70 metros, estructura de vigas de acero y pedestal cilíndrico de hormigón armado.",
			"type": "model", "id": "dsn70",
			"dist": 115.0, "pitch": 0.25, "yaw": 0.52, "ty": 28.0
		},
		{
			"file": "showcase_09_ref_s3_deepspace",
			"title": "Plataforma DeepSpace · Explorador NRHO Lunar",
			"desc": "Nave pesada con alas solares masivas de 4.5 kW, propulsión NEXT-C iónica y mástil magnetómetro de 3 metros.",
			"type": "craft",
			"design": {
				"bus": "deep", "pan": "pan4500", "com": "ka", "prop": "nextc",
				"ins": ["mag", "ir", "neut"], "perfil": "nrho", "lv": "sls", "term": "calentador", "aocs": "reac"
			},
			"dist": 5.5, "pitch": 0.28, "yaw": 0.65, "ty": 0.0
		}
	]
	
	for item in items:
		for c in _holder.get_children():
			_holder.remove_child(c)
			c.queue_free()
		
		_title_lbl.text = item["title"]
		_desc_lbl.text = item["desc"]
		
		var node: Node3D = null
		if item["type"] == "craft":
			var craft := SpacecraftModel.new()
			craft.build(item["design"])
			node = craft
		elif item["type"] == "model":
			node = ModelLibrary.instance(item["id"])
		
		if node != null:
			_holder.add_child(node)
		
		var dist: float = item["dist"]
		var pitch: float = item["pitch"]
		var yaw: float = item["yaw"]
		var ty: float = item.get("ty", 0.0)
		
		var cx := cos(pitch) * sin(yaw) * dist
		var cy := sin(pitch) * dist + ty
		var cz := cos(pitch) * cos(yaw) * dist
		
		_cam.position = Vector3(cx, cy, cz)
		_cam.look_at(Vector3(0, ty, 0), Vector3.UP)
		
		for f in 15:
			await get_tree().process_frame
			
		await _shot(item["file"])
	
	print("TODAS LAS CAPTURAS DE VITRINA PBR COMPLETADAS!")
	get_tree().quit(0)
