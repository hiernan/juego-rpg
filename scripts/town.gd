extends Control

func _on_button_tablon_pressed():
	if GameData.locations.is_empty():
		print("[Town] locations vacío → load_all()")
		GameData.load_all()
	GameData.current_location_id = "crypt"
	get_tree().change_scene_to_file("res://Mission.tscn")

func _on_button_recargar_datos_pressed() -> void:
	GameData.load_all()
	print("Cargados: %d enemigos, %d armas, %d armaduras, %d locaciones, %d loot tables, %d textos" % [
		GameData.enemies.size(),
		GameData.weapons.size(),
		GameData.armors.size(),
		GameData.locations.size(),
		GameData.loot_tables.size(),
		GameData.texts.size()
	])
