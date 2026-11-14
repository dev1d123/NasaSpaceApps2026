extends Node
## Estado de la partida: contrato, diseño, jugadores, colaboración y resultados.

signal design_changed

const ROLES := [
	{"id": "launch", "nombre": "Director de lanzamiento", "segmento": "Launch", "color": Color("#e8743b")},
	{"id": "space", "nombre": "Ingeniero de sistemas", "segmento": "Space", "color": Color("#4f9be8")},
	{"id": "ground", "nombre": "Oficial de comunicaciones", "segmento": "Ground", "color": Color("#46b37a")},
	{"id": "user", "nombre": "Investigador principal", "segmento": "User", "color": Color("#c9a227")},
]

var players: int = 1
## Nombre del jugador que controla cada rol (índice de rol → número de jugador 1..4).
var role_owner: Array = [1, 1, 1, 1]
var scn_id: String = "s1"
var design: Dictionary = {}
var attempt: int = 0
## Decisiones mayores (compras > 10 % del presupuesto) y cuántas tuvieron visto bueno de 2 roles.
var major_decisions: int = 0
var approved_decisions: int = 0
var last_result: Dictionary = {}
var history: Array = []

func set_players(n: int) -> void:
	players = clampi(n, 1, 4)
	for i in 4:
		role_owner[i] = (i % players) + 1

func start_contract(id: String) -> void:
	scn_id = id
	design = GameData.reference_design(id)
	design["ins"] = []
	attempt = 0
	major_decisions = 0
	approved_decisions = 0
	history.clear()
	last_result = {}

func load_reference() -> void:
	design = GameData.reference_design(scn_id)
	design_changed.emit()

func role_label(role_id: String) -> String:
	for i in ROLES.size():
		if ROLES[i]["id"] == role_id:
			if players > 1:
				return "%s · J%d" % [ROLES[i]["nombre"], role_owner[i]]
			return ROLES[i]["nombre"]
	return role_id

func role_color(role_id: String) -> Color:
	for r in ROLES:
		if r["id"] == role_id:
			return r["color"]
	return Color.WHITE
