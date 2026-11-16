extends Node
## Enrutador de pantallas: Menú (CML 1) → Diseño (CML 2–3) → Misión (CML 4) → Debriefing.
## Integra transiciones cinemáticas, banda sonora aeroespacial y telemetría JPL.

const UISound = preload("res://scripts/ui/ui_sound.gd")
const MenuScreen := preload("res://scripts/screens/menu_screen.gd")
const DesignScreen := preload("res://scripts/screens/design_screen.gd")
const MissionScreen := preload("res://scripts/screens/mission_screen.gd")
const DebriefScreen := preload("res://scripts/screens/debrief_screen.gd")
const HUD_SHADER := preload("res://scripts/ui/hud_overlay.gdshader")

var current: Node
var _fx_layer: CanvasLayer
var _transition_rect: ColorRect
var _overlay_rect: ColorRect

func _ready() -> void:
	RenderingServer.set_default_clear_color(UIKit.BG)
	get_window().min_size = Vector2i(1280, 720)
	_setup_fx_layers()
	UISound.play_menu_music(1.5)
	goto_menu()

func _exit_tree() -> void:
	UIKit._theme = null  # liberar texturas del tema al cerrar

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			UISound.toggle_mute()

func _setup_fx_layers() -> void:
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 100
	_fx_layer.name = "FXLayer"
	add_child(_fx_layer)
	
	# Viñeta y líneas de telemetría tipo monitor JPL
	_overlay_rect = ColorRect.new()
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = HUD_SHADER
	sm.set_shader_parameter("scanline_density", 400.0)
	sm.set_shader_parameter("scanline_intensity", 0.025)
	sm.set_shader_parameter("vignette_intensity", 0.35)
	_overlay_rect.material = sm
	_fx_layer.add_child(_overlay_rect)
	
	# Cortinilla de transición suave
	_transition_rect = ColorRect.new()
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color(UIKit.BG, 0.0)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(_transition_rect)

func trigger_alarm(pulse_active: bool) -> void:
	if _overlay_rect and _overlay_rect.material is ShaderMaterial:
		var sm := _overlay_rect.material as ShaderMaterial
		if pulse_active:
			sm.set_shader_parameter("alarm_pulse", 0.75)
		else:
			sm.set_shader_parameter("alarm_pulse", 0.0)

func _swap(node: Node) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)
	
	# Transición cinemática rápida sin bloquear el bucle de procesamiento
	if _transition_rect != null and is_inside_tree():
		_transition_rect.color = Color(UIKit.BG, 0.6)
		var tw := create_tween()
		tw.tween_property(_transition_rect, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func goto_menu() -> void:
	UISound.play_menu_music(1.2)
	var s := MenuScreen.new()
	s.main = self
	_swap(s)

func goto_design() -> void:
	UISound.play_space_music(1.5)
	var s := DesignScreen.new()
	s.main = self
	_swap(s)

func goto_mission() -> void:
	UISound.play_space_music(1.5)
	var s := MissionScreen.new()
	s.main = self
	_swap(s)

func goto_debrief(sim: MissionSim) -> void:
	UISound.play_space_music(1.5)
	var s := DebriefScreen.new()
	s.main = self
	s.sim = sim
	_swap(s)
