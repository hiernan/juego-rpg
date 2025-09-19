extends Node

func _ready():
	# Cuando arranca el juego, cargamos la escena del pueblo
	var town_scene = load("res://Town.tscn")
	var town_instance = town_scene.instantiate()
	add_child(town_instance)
