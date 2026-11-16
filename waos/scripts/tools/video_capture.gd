extends Node
## Graba el recorrido del video de entrega con Movie Maker.
## WAOS_VIDEO_MARKS=<marks.json> Godot --path . --write-movie <dir>/f.png --fixed-fps 30 res://scenes/tools/video_capture.tscn
## Las marcas guardan el cuadro en que empieza cada toma, para cortarlas después.

var marks := {}
var frame := 0

func _process(_d: float) -> void:
	frame += 1

func mark(n: String) -> void:
	marks[n] = frame
	print("marca ", n, " = ", frame)

func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await wait(20)

	# 1 · Menú: contratos y equipo de cuatro roles
	mark("menu")
	await wait(45)
	main.current._set_players(4)
	await wait(120)

	# 2 · Mesa de diseño concurrente con el diseño de referencia de s2
	main.current._accept("s2")
	await wait(3)
	GameState.load_reference()
	var ds = main.current
	ds.d = GameState.design
	ds._build_tabs()
	ds._refresh()
	await wait(15)
	mark("design")
	await wait(70)
	ds._tabs.current_tab = 1
	await wait(55)
	ds._tabs.current_tab = 3
	await wait(55)
	ds._freeze()
	await wait(3)

	# 3 · Vuelo en LEO: Tierra, estaciones y nave con enlace
	var ms = main.current
	ms.sim.events_enabled = false
	ms._set_warp(600.0)
	await wait(40)
	mark("leo")
	await wait(120)
	ms.view.toggle_focus()
	await wait(40)
	mark("craft")
	await wait(120)

	# 4 · Evento que pide decisión
	MissionEvents._fire(ms.sim, "s2e3")
	await wait(8)
	mark("event")
	await wait(130)
	ms.sim.resolve_event(0)
	ms._close_modal()

	# 5 · Escenario lunar en NRHO 9:2
	main.goto_menu()
	await wait(3)
	main.current._accept("s3")
	await wait(3)
	GameState.load_reference()
	GameState.design["perfil"] = "nrho"
	main.goto_mission()
	await wait(3)
	ms = main.current
	ms.sim.events_enabled = false
	while ms.sim.phase == "crucero":
		ms.sim.advance(3600.0, 1e9)
	ms._set_warp(3600.0)
	await wait(90)
	mark("nrho")
	await wait(150)

	# 6 · Debriefing de una misión s2 volada completa con física y eventos
	GameState.set_players(1)
	GameState.start_contract("s2")
	GameState.load_reference()
	GameState.attempt = 1
	var sim := MissionSim.new()
	sim.setup(GameState.design, {"seed": 11, "events": true, "fast": true})
	var guard := 0
	while not sim.finished and guard < 100000:
		guard += 1
		sim.advance(86400.0 * 5, 1e9)
		if not sim.pending_event.is_empty():
			sim.resolve_event(0)
	main.goto_debrief(sim)
	await wait(15)
	mark("debrief")
	await wait(160)
	mark("end")

	var path := OS.get_environment("WAOS_VIDEO_MARKS")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(marks))
		f.close()
	get_tree().quit()
