extends Node
## Entry point for the visual tour (see tour_driver.gd).


func _ready() -> void:
	var driver := Node.new()
	driver.name = "TourDriver"
	driver.set_script(load("res://tests/tour_driver.gd"))
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(driver)
	SceneManager.goto_scene("res://scenes/main/main_menu.tscn", 0.1)
