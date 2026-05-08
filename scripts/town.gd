extends Control

@onready var DoorOpenInn: Sprite2D = $DoorOpenInn
@onready var HotspotDoorInn: Button = $HotspotDoorInn
@onready var BoardGlow: Sprite2D = $BoardGlow
@onready var HotspotBoard: Button = $HotspotBoard

func _ready() -> void:
	# Ocultar la puerta abierta por defecto
	DoorOpenInn.visible = false

	# Asegurar botón invisible que capta el mouse
	HotspotDoorInn.flat = true
	HotspotDoorInn.text = ""
	HotspotDoorInn.focus_mode = Control.FOCUS_NONE
	HotspotDoorInn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Conexiones (idempotentes)
	if not HotspotDoorInn.is_connected("mouse_entered", Callable(self, "_on_hotspot_inn_mouse_entered")):
		HotspotDoorInn.connect("mouse_entered", Callable(self, "_on_hotspot_inn_mouse_entered"))
	if not HotspotDoorInn.is_connected("mouse_exited", Callable(self, "_on_hotspot_inn_mouse_exited")):
		HotspotDoorInn.connect("mouse_exited", Callable(self, "_on_hotspot_inn_mouse_exited"))
	if not HotspotDoorInn.is_connected("pressed", Callable(self, "_on_hotspot_inn_pressed")):
		HotspotDoorInn.connect("pressed", Callable(self, "_on_hotspot_inn_pressed"))
	
		# Cartel: estado inicial
	BoardGlow.visible = false

	# Hotspot invisible que capta el mouse
	HotspotBoard.flat = true
	HotspotBoard.text = ""
	HotspotBoard.focus_mode = Control.FOCUS_NONE
	HotspotBoard.mouse_filter = Control.MOUSE_FILTER_STOP

	# Conexiones (idempotentes)
	if not HotspotBoard.is_connected("mouse_entered", Callable(self, "_on_hotspot_board_mouse_entered")):
		HotspotBoard.connect("mouse_entered", Callable(self, "_on_hotspot_board_mouse_entered"))
	if not HotspotBoard.is_connected("mouse_exited", Callable(self, "_on_hotspot_board_mouse_exited")):
		HotspotBoard.connect("mouse_exited", Callable(self, "_on_hotspot_board_mouse_exited"))
	if not HotspotBoard.is_connected("pressed", Callable(self, "_on_hotspot_board_pressed")):
		HotspotBoard.connect("pressed", Callable(self, "_on_hotspot_board_pressed"))

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

func _on_hotspot_inn_mouse_entered() -> void:
	DoorOpenInn.visible = true

func _on_hotspot_inn_mouse_exited() -> void:
	DoorOpenInn.visible = false

func _on_hotspot_inn_pressed() -> void:
	get_tree().change_scene_to_file("res://Inn.tscn")

func _on_hotspot_board_mouse_entered() -> void:
	BoardGlow.visible = true

func _on_hotspot_board_mouse_exited() -> void:
	BoardGlow.visible = false

func _on_hotspot_board_pressed() -> void:
	get_tree().change_scene_to_file("res://mission.tscn")
