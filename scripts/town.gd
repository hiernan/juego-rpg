extends Control

@onready var DoorOpenInn: Sprite2D = $DoorOpenInn
@onready var HotspotDoorInn: Button = $HotspotDoorInn
@onready var BoardGlow: Sprite2D = $BoardGlow
@onready var HotspotBoard: Button = $HotspotBoard
@onready var HotspotHealer: Button = $HotspotHealer
@onready var HealerGlow: Sprite2D = $HealerGlow
@onready var BlacksmithGlow: Sprite2D = $BlacksmithGlow
@onready var HotspotBlacksmith: Button = $HotspotBlacksmith

func _ready() -> void:
	# Ocultar la puerta abierta por defecto
	DoorOpenInn.visible = false

	# Ocultar el glow del boticario
	HealerGlow.visible = false
	
	# Ocultar el glow del herrero
	BlacksmithGlow.visible = false
	
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

	# Conexiones Healer
	if not HotspotHealer.is_connected("mouse_entered", Callable(self, "_on_hotspot_healer_mouse_entered")):
		HotspotHealer.connect("mouse_entered", Callable(self, "_on_hotspot_healer_mouse_entered"))
	if not HotspotHealer.is_connected("mouse_exited", Callable(self, "_on_hotspot_healer_mouse_exited")):
		HotspotHealer.connect("mouse_exited", Callable(self, "_on_hotspot_healer_mouse_exited"))
	if not HotspotHealer.is_connected("pressed", Callable(self, "_on_hotspot_healer_pressed")):
		HotspotHealer.connect("pressed", Callable(self, "_on_hotspot_healer_pressed"))

	# Conexiones Herrero
	if not HotspotBlacksmith.is_connected("mouse_entered", Callable(self, "_on_hotspot_blacksmith_mouse_entered")):
		HotspotBlacksmith.connect("mouse_entered", Callable(self, "_on_hotspot_blacksmith_mouse_entered"))
	if not HotspotBlacksmith.is_connected("mouse_exited", Callable(self, "_on_hotspot_blacksmith_mouse_exited")):
		HotspotBlacksmith.connect("mouse_exited", Callable(self, "_on_hotspot_blacksmith_mouse_exited"))
	if not HotspotBlacksmith.is_connected("pressed", Callable(self, "_on_hotspot_blacksmith_pressed")):
		HotspotBlacksmith.connect("pressed", Callable(self, "_on_hotspot_blacksmith_pressed"))

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

func _on_hotspot_healer_mouse_entered() -> void:
	HealerGlow.visible = true

func _on_hotspot_healer_mouse_exited() -> void:
	HealerGlow.visible = false

func _on_hotspot_healer_pressed() -> void:
	get_tree().change_scene_to_file("res://scripts/healer.tscn")

func _on_hotspot_blacksmith_mouse_entered() -> void:
	BlacksmithGlow.visible = true

func _on_hotspot_blacksmith_mouse_exited() -> void:
	BlacksmithGlow.visible = false

func _on_hotspot_blacksmith_pressed() -> void:
	get_tree().change_scene_to_file("res://scripts/blacksmith.tscn")
