class_name OrbitCamera
extends Camera3D
## Cámara orbital: arrastrar con botón izquierdo o derecho para girar, rueda para acercar.

var target := Vector3.ZERO
var yaw := 0.6
var pitch := 0.35
var distance := 25.0
var min_distance := 0.5
var max_distance := 3000.0
var auto_rotate := 0.0
var _drag := false
var _goal_distance := 25.0

func _ready() -> void:
	_goal_distance = distance
	near = 0.01
	far = 20000.0
	fov = 50.0

func set_distance(d: float, instant: bool = false) -> void:
	_goal_distance = clampf(d, min_distance, max_distance)
	if instant:
		distance = _goal_distance

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_goal_distance = clampf(_goal_distance * 0.88, min_distance, max_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_goal_distance = clampf(_goal_distance / 0.88, min_distance, max_distance)
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.006
		pitch = clampf(pitch + mm.relative.y * 0.006, -1.5, 1.5)

func _process(delta: float) -> void:
	yaw += auto_rotate * delta
	distance = lerpf(distance, _goal_distance, clampf(delta * 8.0, 0.0, 1.0))
	# Plano cercano proporcional a la distancia: con near fijo de 0.01 y far de 20 000
	# el buffer de profundidad no distingue piezas a milímetros y aparece z-fighting.
	near = clampf(distance * 0.02, 0.001, 50.0)
	var off := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
	global_position = target + off
	look_at(target, Vector3.UP)
