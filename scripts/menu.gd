extends Control

# --- НАСТРОЙКИ ПУТЕЙ ---
@export var play_selection_scene_path: String = "res://scenes/song_selection.tscn"
@export var editor_scene_path: String = "res://scenes/editor_menu.tscn"

func _ready():
	# Фокусируемся на кнопке для управления с клавиатуры
	var play_btn = get_node_or_null("CenterContainer/VBoxContainer/PlayButton")
	if play_btn:
		play_btn.grab_focus()

# --- ОБРАБОТКА НАЖАТИЙ ---

func _on_play_button_pressed():
	# Сбрасываем режим редактора
	GameManager.is_editor_mode = false
	# ИСПОЛЬЗУЕМ ГЛОБАЛЬНЫЙ ПЕРЕХОД
	Transition.change_scene(play_selection_scene_path)

func _on_editor_button_pressed():
	# Включаем режим редактора
	GameManager.is_editor_mode = true
	# ИСПОЛЬЗУЕМ ГЛОБАЛЬНЫЙ ПЕРЕХОД
	Transition.change_scene(editor_scene_path)

func _on_exit_button_pressed():
	# Для выхода переход обычно не нужен, просто закрываем
	get_tree().quit()
