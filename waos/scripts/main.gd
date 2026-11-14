extends Node
## Enrutador de pantallas: Menú (CML 1) → Diseño (CML 2–3) → Misión (CML 4) → Debriefing.

const MenuScreen := preload("res://scripts/screens/menu_screen.gd")
const DesignScreen := preload("res://scripts/screens/design_screen.gd")
const MissionScreen := preload("res://scripts/screens/mission_screen.gd")
const DebriefScreen := preload("res://scripts/screens/debrief_screen.gd")

var current: Node

func _ready() -> void:
	RenderingServer.set_default_clear_color(UIKit.BG)
	get_window().min_size = Vector2i(1280, 720)
	goto_menu()

func _exit_tree() -> void:
	UIKit._theme = null  # liberar texturas del tema al cerrar

func _swap(node: Node) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)

func goto_menu() -> void:
	var s := MenuScreen.new()
	s.main = self
	_swap(s)

func goto_design() -> void:
	var s := DesignScreen.new()
	s.main = self
	_swap(s)

func goto_mission() -> void:
	var s := MissionScreen.new()
	s.main = self
	_swap(s)

func goto_debrief(sim: MissionSim) -> void:
	var s := DebriefScreen.new()
	s.main = self
	s.sim = sim
	_swap(s)
