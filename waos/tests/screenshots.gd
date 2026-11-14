extends Node
## Capturas de cada pantalla para revisión visual (requiere ventana, no headless).
## WAOS_SHOTS=<carpeta> Godot --path . res://tests/screenshots.tscn

var out := ""

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("captura ", name)

func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	out = OS.get_environment("WAOS_SHOTS")
	get_tree().create_timer(240.0).timeout.connect(func(): get_tree().quit(1))
	get_window().size = Vector2i(1600, 900)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await wait(30)
	await shot("1_menu")
	main.current._accept("s2")
	await wait(5)
	GameState.load_reference()
	var ds = main.current
	ds.d = GameState.design
	ds._build_tabs()
	ds._refresh()
	await wait(40)
	await shot("2_diseno_sistemas")
	ds._tabs.current_tab = 3
	await wait(5)
	await shot("3_diseno_ciencia")
	ds._tabs.current_tab = 2
	await wait(5)
	await shot("3b_diseno_comunicaciones")
	ds._freeze()
	await wait(5)
	var ms = main.current
	ms._set_warp(600.0)
	await wait(90)
	await shot("4_mision_leo")
	ms.view.toggle_focus()
	await wait(60)
	await shot("5_mision_nave")
	# Evento forzado para ver el modal
	MissionEvents._fire(ms.sim, "s2e3")
	await wait(10)
	await shot("6_evento")
	ms.sim.resolve_event(1)
	ms._close_modal()
	# Lunar
	main.goto_menu()
	await wait(3)
	main.current._accept("s3")
	await wait(3)
	GameState.load_reference()
	GameState.design["perfil"] = "nrho"
	GameState.design["propKg"] = 30.0
	main.goto_mission()
	await wait(3)
	ms = main.current
	ms._set_warp(-1.0)
	while ms.sim.phase == "crucero":
		await get_tree().process_frame
		if not ms.sim.pending_event.is_empty():
			ms.sim.resolve_event(0)
			ms._close_modal()
	ms._set_warp(3600.0)
	await wait(120)
	if not ms.sim.pending_event.is_empty():
		ms.sim.resolve_event(0)
		ms._close_modal()
	await wait(30)
	await shot("7_mision_nrho")
	main.goto_debrief(ms.sim)
	await wait(10)
	await shot("8_debriefing")
	get_tree().quit()
