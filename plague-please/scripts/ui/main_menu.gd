extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	GameManager.start_new_run()
