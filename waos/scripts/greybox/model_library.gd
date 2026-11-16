class_name ModelLibrary
extends RefCounted
## Modelos 3D hechos en Blender (ver docs/modelos/PROMPTS_ANTIGRAVITY.md).
## Lee assets/models/manifest.json; si un modelo falta, el juego usa el greybox.

const MANIFEST := "res://assets/models/manifest.json"
const SpaceMaterials = preload("res://scripts/greybox/space_materials.gd")
## Ponlo en false para comparar con el greybox original.
static var enabled := true
static var _manifest: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}

static func manifest() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(MANIFEST, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest

static func has(id: String) -> bool:
	if not enabled:
		return false
	var m := manifest()
	return m.has(id) and ResourceLoader.exists(str(m[id]["file"]))

static func instance(id: String) -> Node3D:
	if not has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(str(manifest()[id]["file"]))
	var ps: PackedScene = _cache[id]
	var inst: Node3D = ps.instantiate() as Node3D if ps != null else null
	if inst != null:
		SpaceMaterials.apply_to_node(inst)
	return inst

## Medidas del AABB en metros, convertidas a ejes de Godot (Blender Z → Godot Y).
static func size(id: String) -> Vector3:
	var b: Array = manifest().get(id, {}).get("bbox_m", [1, 1, 1])
	return Vector3(float(b[0]), float(b[2]), float(b[1]))

## Modelo de estación terrena para cada id del catálogo de estaciones.
static func ground_model(station_id: String) -> String:
	match station_id:
		"gds", "mad", "cbr":
			return "dsn70"
		"uni":
			return "yagi_uni"
	return "nsn11"
