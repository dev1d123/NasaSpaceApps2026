extends Node
## Catálogos del GDD, cargados desde data/gdd_data.json (exportado del documento).

const DATA_PATH := "res://data/gdd_data.json"

var data: Dictionary = {}

## Mejoras de redundancia que algunos eventos piden (GDD, eventos s2e5 y s3e1).
const EXTRAS := {
	"rueda": {"nombre": "Cuarta rueda de reacción", "costo": 2.0, "masa": 3.0, "nota": "Permite conmutar en 6 h si falla una rueda (evento s2e5)."},
	"valvula": {"nombre": "Rama de propulsión redundante", "costo": 1.5, "masa": 1.0, "nota": "Evita la penalidad si se atasca una válvula (evento s3e1)."},
}

## Estaciones que se contratan, en orden, al subir los bloques de contacto en cada escenario.
const STATION_PLAN := {
	"s1": ["uni", "pun", "asf", "wal"],
	"s2": ["sval", "asf", "mcm", "wsc"],
	"s3": ["gds", "mad", "cbr", "gds"],
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not data.is_empty():
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("JSON inválido en " + DATA_PATH)

func list(key: String) -> Array:
	load_data()
	return data.get(key, [])

func by_id(key: String, id: String) -> Dictionary:
	for item in list(key):
		if item.get("id", "") == id:
			return item
	return {}

func scenario(id: String) -> Dictionary:
	return by_id("escenarios", id)

func profile(scn: Dictionary, id: String) -> Dictionary:
	for p in scn.get("perfiles", []):
		if p["id"] == id:
			return p
	return scn["perfiles"][0]

## Diseño de referencia de un escenario, en el formato que usa todo el juego.
func reference_design(scn_id: String) -> Dictionary:
	var sc := scenario(scn_id)
	var r: Dictionary = sc["referencia"]
	return {
		"scn": scn_id, "perfil": r["perfil"], "lv": r["lv"], "bus": r["bus"], "pan": r["pan"], "bat": r["bat"],
		"prop": r["prop"], "propKg": float(r["propKg"]), "com": r["com"], "ins": (r["ins"] as Array).duplicate(),
		"duty": float(r["duty"]), "bloques": int(r["bloques"]), "usuario": "l1", "extras": [], "uni_lat": 40.4, "uni_lon": -3.7,
	}

## ¿Cabe el componente en la clase de bus?
func fits(item: Dictionary, bus_clase: String) -> bool:
	return not item.has("cabe") or (item["cabe"] as Array).has(bus_clase)
