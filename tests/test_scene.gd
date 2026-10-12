extends SceneTree
## Exercise visuals and UI for five simulated minutes, including all production events.
const Game = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("run_scene")

func run_scene() -> void:
	var game = Game.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.native_smoke_test = true
	for i in 3000:
		game._process(0.1)
		if i == 500:
			for kind in ["wood", "truck", "mill"]:
				game.sim.money += 100
				game._upgrade(kind)
		if i % 100 == 0:
			await process_frame
	print("KIKORI_SCENE_EVENTS felled=%d sold=%d" % [game.sim.felled, game.sim.processed])
	var success = game.sim.felled > 10 and game.sim.processed > 10
	game.queue_free()
	await process_frame
	quit(0 if success else 1)
