class_name SpaceMaterials
extends RefCounted
## Biblioteca central de materiales PBR foto-reales de la NASA para modelos de naves y componentes.
## Mapea los 10 materiales estandarizados del manifiesto (MLI oro, MLI plata, celdas solares,
## aluminio mecanizado, kapton, marco compuesto, blanco térmico, cobre y óptica de carga útil).

const TEX_SOLAR_COLOR := preload("res://assets/textures/solar/color.png")
const TEX_SOLAR_ROUGH := preload("res://assets/textures/solar/roughness.png")
const TEX_SOLAR_METAL := preload("res://assets/textures/solar/metallic.png")
const TEX_SOLAR_NORM := preload("res://assets/textures/solar/normal.png")

const TEX_FOIL_GOLD_COLOR := preload("res://assets/textures/foil_gold/color.png")
const TEX_FOIL_GOLD_ROUGH := preload("res://assets/textures/foil_gold/roughness.png")
const TEX_FOIL_GOLD_METAL := preload("res://assets/textures/foil_gold/metallic.png")
const TEX_FOIL_GOLD_NORM := preload("res://assets/textures/foil_gold/normal.png")
const TEX_FOIL_GOLD_AO := preload("res://assets/textures/foil_gold/ao.png")

const TEX_FOIL_SILVER_COLOR := preload("res://assets/textures/foil_silver/color.png")
const TEX_FOIL_SILVER_ROUGH := preload("res://assets/textures/foil_silver/roughness.png")
const TEX_FOIL_SILVER_METAL := preload("res://assets/textures/foil_silver/metallic.png")
const TEX_FOIL_SILVER_NORM := preload("res://assets/textures/foil_silver/normal.png")
const TEX_FOIL_SILVER_AO := preload("res://assets/textures/foil_silver/ao.png")

const TEX_ALU_COLOR := preload("res://assets/textures/aluminum/color.png")
const TEX_ALU_ROUGH := preload("res://assets/textures/aluminum/roughness.png")
const TEX_ALU_METAL := preload("res://assets/textures/aluminum/metallic.png")
const TEX_ALU_NORM := preload("res://assets/textures/aluminum/normal.png")

const TEX_DARK_COLOR := preload("res://assets/textures/dark_metal/color.png")
const TEX_DARK_ROUGH := preload("res://assets/textures/dark_metal/roughness.png")
const TEX_DARK_METAL := preload("res://assets/textures/dark_metal/metallic.png")
const TEX_DARK_NORM := preload("res://assets/textures/dark_metal/normal.png")

const TEX_CARBON_COLOR := preload("res://assets/textures/carbon_frame/color.png")
const TEX_CARBON_ROUGH := preload("res://assets/textures/carbon_frame/roughness.png")
const TEX_CARBON_METAL := preload("res://assets/textures/carbon_frame/metallic.png")
const TEX_CARBON_NORM := preload("res://assets/textures/carbon_frame/normal.png")

const TEX_WHITE_COLOR := preload("res://assets/textures/white_panel/color.png")
const TEX_WHITE_ROUGH := preload("res://assets/textures/white_panel/roughness.png")
const TEX_WHITE_NORM := preload("res://assets/textures/white_panel/normal.png")

const TEX_COPPER_COLOR := preload("res://assets/textures/copper/color.png")
const TEX_COPPER_ROUGH := preload("res://assets/textures/copper/roughness.png")
const TEX_COPPER_METAL := preload("res://assets/textures/copper/metallic.png")
const TEX_COPPER_NORM := preload("res://assets/textures/copper/normal.png")

const TEX_CONCRETE_COLOR := preload("res://assets/textures/concrete/color.png")
const TEX_CONCRETE_ROUGH := preload("res://assets/textures/concrete/roughness.png")
const TEX_CONCRETE_NORM := preload("res://assets/textures/concrete/normal.png")

const TEX_IMPERF_NORM := preload("res://assets/textures/imperfections/normal.png")

static var _materials: Dictionary = {}
static var _initialized := false

static func init_materials() -> void:
	if _initialized:
		return
	_initialized = true

	# 1. Celdas Solares Fotovoltaicas de Triple Unión (GaAs/InGaP)
	var mat_celdas := StandardMaterial3D.new()
	mat_celdas.resource_name = "mat_celdas"
	mat_celdas.albedo_color = Color("#557ca3")
	mat_celdas.albedo_texture = TEX_SOLAR_COLOR
	mat_celdas.metallic = 0.85
	mat_celdas.metallic_texture = TEX_SOLAR_METAL
	mat_celdas.roughness = 0.22
	mat_celdas.roughness_texture = TEX_SOLAR_ROUGH
	mat_celdas.normal_enabled = true
	mat_celdas.normal_texture = TEX_SOLAR_NORM
	mat_celdas.normal_scale = 1.2
	mat_celdas.uv1_triplanar = true
	mat_celdas.uv1_scale = Vector3(5.0, 5.0, 5.0)
	mat_celdas.uv1_triplanar_sharpness = 8.0
	_materials["mat_celdas"] = mat_celdas

	# 2. Marco y Estructura de Sustrato Compuesto / Fibra de Carbono
	var mat_marco := StandardMaterial3D.new()
	mat_marco.resource_name = "mat_celdas_marco"
	mat_marco.albedo_color = Color("#22242a")
	mat_marco.albedo_texture = TEX_CARBON_COLOR
	mat_marco.metallic = 0.25
	mat_marco.metallic_texture = TEX_CARBON_METAL
	mat_marco.roughness = 0.65
	mat_marco.roughness_texture = TEX_CARBON_ROUGH
	mat_marco.normal_enabled = true
	mat_marco.normal_texture = TEX_CARBON_NORM
	mat_marco.uv1_triplanar = true
	mat_marco.uv1_scale = Vector3(8.0, 8.0, 8.0)
	mat_marco.uv1_triplanar_sharpness = 4.0
	_materials["mat_celdas_marco"] = mat_marco

	# 3. Aislamiento Multicapa Oro (MLI Gold - Apollo / JWST / Europa Clipper)
	var mat_mli_oro := StandardMaterial3D.new()
	mat_mli_oro.resource_name = "mat_mli_oro"
	mat_mli_oro.albedo_color = Color("#f4cb6c")
	mat_mli_oro.albedo_texture = TEX_FOIL_GOLD_COLOR
	mat_mli_oro.metallic = 0.95
	mat_mli_oro.metallic_texture = TEX_FOIL_GOLD_METAL
	mat_mli_oro.roughness = 0.28
	mat_mli_oro.roughness_texture = TEX_FOIL_GOLD_ROUGH
	mat_mli_oro.normal_enabled = true
	mat_mli_oro.normal_texture = TEX_FOIL_GOLD_NORM
	mat_mli_oro.normal_scale = 1.3
	mat_mli_oro.ao_enabled = true
	mat_mli_oro.ao_texture = TEX_FOIL_GOLD_AO
	mat_mli_oro.uv1_triplanar = true
	mat_mli_oro.uv1_scale = Vector3(3.5, 3.5, 3.5)
	mat_mli_oro.uv1_triplanar_sharpness = 5.0
	_materials["mat_mli_oro"] = mat_mli_oro

	# 4. Película Térmica Kapton (Poliimida Ámbar Intenso)
	var mat_kapton := StandardMaterial3D.new()
	mat_kapton.resource_name = "mat_kapton"
	mat_kapton.albedo_color = Color("#e58f2d")
	mat_kapton.albedo_texture = TEX_FOIL_GOLD_COLOR
	mat_kapton.metallic = 0.70
	mat_kapton.metallic_texture = TEX_FOIL_GOLD_METAL
	mat_kapton.roughness = 0.24
	mat_kapton.roughness_texture = TEX_FOIL_GOLD_ROUGH
	mat_kapton.normal_enabled = true
	mat_kapton.normal_texture = TEX_FOIL_GOLD_NORM
	mat_kapton.normal_scale = 1.1
	mat_kapton.uv1_triplanar = true
	mat_kapton.uv1_scale = Vector3(4.5, 4.5, 4.5)
	mat_kapton.uv1_triplanar_sharpness = 5.0
	_materials["mat_kapton"] = mat_kapton

	# 5. Aislamiento Multicapa Plata (MLI Silver / Aluminized Mylar)
	var mat_mli_plata := StandardMaterial3D.new()
	mat_mli_plata.resource_name = "mat_mli_plata"
	mat_mli_plata.albedo_color = Color("#eaeef4")
	mat_mli_plata.albedo_texture = TEX_FOIL_SILVER_COLOR
	mat_mli_plata.metallic = 0.96
	mat_mli_plata.metallic_texture = TEX_FOIL_SILVER_METAL
	mat_mli_plata.roughness = 0.25
	mat_mli_plata.roughness_texture = TEX_FOIL_SILVER_ROUGH
	mat_mli_plata.normal_enabled = true
	mat_mli_plata.normal_texture = TEX_FOIL_SILVER_NORM
	mat_mli_plata.normal_scale = 1.2
	mat_mli_plata.ao_enabled = true
	mat_mli_plata.ao_texture = TEX_FOIL_SILVER_AO
	mat_mli_plata.uv1_triplanar = true
	mat_mli_plata.uv1_scale = Vector3(3.5, 3.5, 3.5)
	mat_mli_plata.uv1_triplanar_sharpness = 5.0
	_materials["mat_mli_plata"] = mat_mli_plata

	# 6. Aluminio Mecanizado Aeroespacial (6061-T6 Anodizado Claro)
	var mat_aluminio := StandardMaterial3D.new()
	mat_aluminio.resource_name = "mat_aluminio"
	mat_aluminio.albedo_color = Color("#c8d0da")
	mat_aluminio.albedo_texture = TEX_ALU_COLOR
	mat_aluminio.metallic = 0.90
	mat_aluminio.metallic_texture = TEX_ALU_METAL
	mat_aluminio.roughness = 0.35
	mat_aluminio.roughness_texture = TEX_ALU_ROUGH
	mat_aluminio.normal_enabled = true
	mat_aluminio.normal_texture = TEX_ALU_NORM
	mat_aluminio.normal_scale = 0.8
	mat_aluminio.uv1_triplanar = true
	mat_aluminio.uv1_scale = Vector3(6.0, 6.0, 6.0)
	mat_aluminio.uv1_triplanar_sharpness = 4.0
	_materials["mat_aluminio"] = mat_aluminio

	# 7. Metal Negro Antirreflejo / Toberas / Star Trackers
	var mat_negro := StandardMaterial3D.new()
	mat_negro.resource_name = "mat_negro"
	mat_negro.albedo_color = Color("#1a1c22")
	mat_negro.albedo_texture = TEX_DARK_COLOR
	mat_negro.metallic = 0.45
	mat_negro.metallic_texture = TEX_DARK_METAL
	mat_negro.roughness = 0.65
	mat_negro.roughness_texture = TEX_DARK_ROUGH
	mat_negro.normal_enabled = true
	mat_negro.normal_texture = TEX_DARK_NORM
	mat_negro.uv1_triplanar = true
	mat_negro.uv1_scale = Vector3(8.0, 8.0, 8.0)
	mat_negro.uv1_triplanar_sharpness = 4.0
	_materials["mat_negro"] = mat_negro

	# 8. Radiador Térmico Blanco / Betacloth Cleanroom
	var mat_blanco := StandardMaterial3D.new()
	mat_blanco.resource_name = "mat_blanco"
	mat_blanco.albedo_color = Color("#f0f3f8")
	mat_blanco.albedo_texture = TEX_WHITE_COLOR
	mat_blanco.metallic = 0.05
	mat_blanco.roughness = 0.40
	mat_blanco.roughness_texture = TEX_WHITE_ROUGH
	mat_blanco.normal_enabled = true
	mat_blanco.normal_texture = TEX_WHITE_NORM
	mat_blanco.normal_scale = 0.6
	mat_blanco.uv1_triplanar = true
	mat_blanco.uv1_scale = Vector3(5.0, 5.0, 5.0)
	mat_blanco.uv1_triplanar_sharpness = 4.0
	_materials["mat_blanco"] = mat_blanco

	# 9. Cobre Puro / Magnetómetros / Bobinas / Guías de Onda
	var mat_cobre := StandardMaterial3D.new()
	mat_cobre.resource_name = "mat_cobre"
	mat_cobre.albedo_color = Color("#e88656")
	mat_cobre.albedo_texture = TEX_COPPER_COLOR
	mat_cobre.metallic = 0.95
	mat_cobre.metallic_texture = TEX_COPPER_METAL
	mat_cobre.roughness = 0.30
	mat_cobre.roughness_texture = TEX_COPPER_ROUGH
	mat_cobre.normal_enabled = true
	mat_cobre.normal_texture = TEX_COPPER_NORM
	mat_cobre.normal_scale = 1.0
	mat_cobre.uv1_triplanar = true
	mat_cobre.uv1_scale = Vector3(6.0, 6.0, 6.0)
	mat_cobre.uv1_triplanar_sharpness = 4.0
	_materials["mat_cobre"] = mat_cobre

	# 10. Óptica de Cargas Útiles (Lentes de Sílice Fundida con Revestimiento Antirreflejo)
	var mat_lente := StandardMaterial3D.new()
	mat_lente.resource_name = "mat_lente"
	mat_lente.albedo_color = Color(0.10, 0.16, 0.32, 0.88)
	mat_lente.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_lente.metallic = 0.85
	mat_lente.roughness = 0.05
	mat_lente.normal_enabled = true
	mat_lente.normal_texture = TEX_IMPERF_NORM
	mat_lente.normal_scale = 0.3
	mat_lente.clearcoat_enabled = true
	mat_lente.clearcoat = 1.0
	mat_lente.clearcoat_roughness = 0.05
	_materials["mat_lente"] = mat_lente

	# 11. Concreto Aeroespacial (Pedestales y Fundaciones DSN / NSN)
	var mat_concreto := StandardMaterial3D.new()
	mat_concreto.resource_name = "mat_concreto"
	mat_concreto.albedo_color = Color("#b8bcc4")
	mat_concreto.albedo_texture = TEX_CONCRETE_COLOR
	mat_concreto.metallic = 0.0
	mat_concreto.roughness = 0.85
	mat_concreto.roughness_texture = TEX_CONCRETE_ROUGH
	mat_concreto.normal_enabled = true
	mat_concreto.normal_texture = TEX_CONCRETE_NORM
	mat_concreto.uv1_triplanar = true
	mat_concreto.uv1_scale = Vector3(2.0, 2.0, 2.0)
	mat_concreto.uv1_triplanar_sharpness = 3.0
	_materials["mat_concreto"] = mat_concreto

static func get_material(mat_name: String) -> StandardMaterial3D:
	init_materials()
	if _materials.has(mat_name):
		return _materials[mat_name]
	# Búsqueda por palabras clave si el nombre no es exacto
	var lower := mat_name.to_lower()
	if "celda" in lower or "solar" in lower:
		return _materials["mat_celdas"]
	elif "oro" in lower or "gold" in lower:
		return _materials["mat_mli_oro"]
	elif "plata" in lower or "silver" in lower:
		return _materials["mat_mli_plata"]
	elif "kapton" in lower:
		return _materials["mat_kapton"]
	elif "alu" in lower or "metal" in lower:
		return _materials["mat_aluminio"]
	elif "negro" in lower or "dark" in lower or "chasis" in lower:
		return _materials["mat_negro"]
	elif "blanco" in lower or "white" in lower or "rad" in lower:
		return _materials["mat_blanco"]
	elif "cobre" in lower or "copper" in lower:
		return _materials["mat_cobre"]
	elif "lente" in lower or "glass" in lower or "opt" in lower:
		return _materials["mat_lente"]
	elif "concreto" in lower or "base" in lower:
		return _materials["mat_concreto"]
	return _materials["mat_aluminio"]

## Aplica recursivamente los materiales PBR a cada MeshInstance3D de un nodo o modelo
static func apply_to_node(node: Node) -> void:
	init_materials()
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var sc := mi.mesh.get_surface_count()
			for s in sc:
				var m := mi.mesh.surface_get_material(s)
				var mat_name := m.resource_name if m != null else ""
				if mat_name == "":
					mat_name = _guess_material_name(mi.name)
				var pbr := get_material(mat_name)
				if pbr != null:
					mi.set_surface_override_material(s, pbr)
	for child in node.get_children():
		apply_to_node(child)

static func _guess_material_name(node_name: String) -> String:
	var lower := node_name.to_lower()
	if "celda" in lower or "panel" in lower:
		return "mat_celdas"
	elif "marco" in lower or "hoja" in lower or "bisagra" in lower:
		return "mat_celdas_marco"
	elif "body" in lower:
		return "mat_mli_oro"
	elif "louver" in lower or "radiador" in lower or "rad_" in lower:
		return "mat_blanco"
	elif "kapton" in lower or "pcb_yp" in lower:
		return "mat_kapton"
	elif "chasis" in lower or "noz" in lower or "barrel" in lower:
		return "mat_negro"
	elif "boom" in lower or "coil" in lower or "mag" in lower:
		return "mat_cobre"
	elif "lente" in lower or "optic" in lower or "cam" in lower:
		return "mat_lente"
	elif "pedestal" in lower or "foundation" in lower or "pad" in lower:
		return "mat_concreto"
	return "mat_aluminio"
