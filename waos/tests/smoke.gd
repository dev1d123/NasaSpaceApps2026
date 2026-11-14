extends Node
## Recorre todas las pantallas sin intervención: menú → diseño → misión → debriefing.
## Godot --headless --path . res://tests/smoke.tscn

func _ready() -> void:
	# Salvaguarda: si algo se cuelga, salir con error.
	get_tree().create_timer(300.0).timeout.connect(func():
		print("SMOKE TIMEOUT")
		get_tree().quit(1))
	var scn := OS.get_environment("WAOS_SCN")
	if scn == "":
		scn = "s1"
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null or not (packed.instantiate().get_script() as GDScript).can_instantiate():
		print("SMOKE FAIL: main no compila")
		get_tree().quit(1)
		return
	var main: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	print("menú ok: ", main.current.get_script().resource_path)
	main.current._set_players(2)
	main.current._accept(scn)
	await get_tree().process_frame
	await get_tree().process_frame
	var ds = main.current
	print("diseño ok: ", ds.get_script().resource_path, " · vuela habilitado=", not ds._fly.disabled)
	# Cambios de diseño por la interfaz de datos
	ds._change(func(): ds.d["ins"].append("mag"))
	await get_tree().process_frame
	ds.get_child(0).get_child(0)  # árbol de UI
	GameState.load_reference()
	ds.d = GameState.design
	ds._build_tabs()
	ds._refresh()
	await get_tree().process_frame
	print("referencia: todas ok=", ds.e["all_ok"], " · vuela habilitado=", not ds._fly.disabled)
	ds._freeze()
	await get_tree().process_frame
	await get_tree().process_frame
	var ms = main.current
	print("misión ok: ", ms.get_script().resource_path)
	ms._set_warp(-1.0)
	ms.view.toggle_focus()
	var frames := 0
	var events := 0
	while not ms.sim.finished and frames < 20000:
		await get_tree().process_frame
		frames += 1
		if not ms.sim.pending_event.is_empty() and ms._modal.get_child_count() > 0:
			events += 1
			ms.sim.resolve_event(MissionEvents.default_action(ms.sim, ms.sim.pending_event))
			ms._close_modal()
	print("vuelo terminado en %d frames · eventos %d · SP %.0f · día %.1f" % [frames, events, ms.sim.sp, ms.sim.t / 86400.0])
	await get_tree().process_frame
	await get_tree().process_frame
	ms.main.goto_debrief(ms.sim)
	await get_tree().process_frame
	await get_tree().process_frame
	print("debriefing ok: ", main.current.get_script().resource_path, " · puntaje ", GameState.last_result.get("total"))
	main.goto_design()
	await get_tree().process_frame
	print("rediseño ok · intento ", GameState.attempt)
	print("SMOKE OK")
	get_tree().quit()
