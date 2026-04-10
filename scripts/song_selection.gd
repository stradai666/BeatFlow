extends Control

# Список песен
var songs = [
	{"name": "Tutorial", "music": "res://music/tutorial.mp3", "chart": "res://charts/tutorial.json"},
	{"name": "Level 1", "music": "res://music/level1.mp3", "chart": "res://charts/level1.json"}
]

@onready var container = $ScrollContainer/VBoxContainer
@onready var back_button = $BackButton # Ссылка на твою кнопку назад

func _ready():
	# Подключаем кнопку назад (через код)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Динамически создаем кнопки песен
	for song in songs:
		var btn = Button.new()
		btn.text = song["name"]
		btn.custom_minimum_size.y = 50
		# При нажатии вызываем функцию выбора с плавным переходом
		btn.pressed.connect(self._on_song_selected.bind(song))
		container.add_child(btn)

func _on_back_pressed():
	# Возвращаемся в главное меню через глобальный переход
	Transition.change_scene("res://scenes/menu.tscn")

func _on_song_selected(song_data):
	# Записываем данные в GameManager
	GameManager.selected_song_path = song_data["music"]
	GameManager.selected_chart_path = song_data["chart"]
	
	# Переходим в игру через глобальный переход
	Transition.change_scene("res://scenes/main.tscn")

# Если ты подключал сигнал через редактор (вкладка "Узлы"), 
# то можно использовать этот метод:
func _on_back_button_pressed() -> void:
	_on_back_pressed()
