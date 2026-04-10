extends Node2D

@onready var music_player = $MusicPlayer
@onready var music_picker = $MusicPicker
@onready var status_label = $CanvasLayer/Control/StatusLabel
@onready var chart_list = $CanvasLayer/Control/ChartList
@onready var context_menu = $CanvasLayer/Control/ChartContextMenu

# Узлы окна сохранения
@onready var save_window = $CanvasLayer/Control/SaveWindow
@onready var chart_name_input = $CanvasLayer/Control/SaveWindow/VBoxContainer/ChartNameInput
@onready var confirm_save_btn = $CanvasLayer/Control/SaveWindow/VBoxContainer/HBoxContainer/ConfirmSave
@onready var cancel_save_btn = $CanvasLayer/Control/SaveWindow/VBoxContainer/HBoxContainer/CancelSave

# Кнопки управления (прямые пути)
@onready var create_button = $CanvasLayer/Control/CreateButton
@onready var save_main_btn = $CanvasLayer/Control/SaveButton
@onready var pause_button  = $CanvasLayer/Control/PauseButton
@onready var exit_button   = $CanvasLayer/Control/ExitButton

var song_position = 0.0
var recorded_chart = [] 
var targets = []
var is_paused = false 
var current_selected_index = -1 

func _ready():
	_ensure_folders_exist()
	setup_strum_line()
	refresh_chart_list()
	
	save_window.visible = false
	
	# Настройка FileDialog
	music_picker.access = FileDialog.ACCESS_FILESYSTEM
	music_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	music_picker.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
	music_picker.filters = PackedStringArray(["*.mp3 ; MP3 Audio", "*.ogg ; OGG Audio", "*.wav ; WAV Audio"])
	
	# Настройка контекстного меню
	context_menu.clear()
	context_menu.add_item("Запустить (Играть)", 0)
	context_menu.add_item("Изменить (Редактировать)", 1)
	context_menu.add_separator()
	context_menu.add_item("Удалить", 2)
	
	# Сигналы
	create_button.pressed.connect(func(): music_picker.popup_centered(Vector2(800, 600)))
	save_main_btn.pressed.connect(_open_save_dialog)
	pause_button.pressed.connect(_toggle_pause)
	exit_button.pressed.connect(_exit_to_menu) # Тут теперь переход
	
	music_picker.file_selected.connect(_on_music_selected)
	confirm_save_btn.pressed.connect(_on_confirm_save_pressed)
	cancel_save_btn.pressed.connect(func(): save_window.visible = false)
	chart_list.item_clicked.connect(_on_chart_item_clicked)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _ensure_folders_exist():
	var paths = ["user://charts/", "user://music/"]
	for p in paths:
		if not DirAccess.dir_exists_absolute(p):
			DirAccess.make_dir_absolute(p)

# --- КОНТЕКСТНОЕ МЕНЮ И СПИСОК ---

func _on_chart_item_clicked(index, _at_position, mouse_button_index):
	current_selected_index = index
	chart_list.select(index)
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		context_menu.position = get_global_mouse_position()
		context_menu.popup()
	elif mouse_button_index == MOUSE_BUTTON_LEFT:
		_on_chart_item_selected(index)

func _on_context_menu_id_pressed(id):
	match id:
		0: _play_chart(current_selected_index) # Переход в игру
		1: _on_chart_item_selected(current_selected_index)
		2: _delete_chart(current_selected_index)

func _play_chart(index):
	var chart_name = chart_list.get_item_text(index)
	var data = _load_json("user://charts/" + chart_name)
	if data:
		GameManager.selected_song_path = data.get("music_path", "")
		GameManager.selected_chart_path = "user://charts/" + chart_name
		GameManager.is_editor_mode = false
		# ПЛАВНЫЙ ПЕРЕХОД В ИГРУ
		Transition.change_scene("res://scenes/main.tscn")

func _delete_chart(index):
	var chart_name = chart_list.get_item_text(index)
	DirAccess.remove_absolute("user://charts/" + chart_name)
	refresh_chart_list()
	status_label.text = "Удалено: " + chart_name

# --- РАБОТА С АУДИО ---

func _on_music_selected(path: String):
	var internal_path = _copy_to_internal_storage(path)
	if internal_path != "":
		GameManager.selected_song_path = internal_path
		_load_audio_file(internal_path)
		recorded_chart.clear()
		is_paused = false
		chart_name_input.text = path.get_file().get_basename()
		status_label.text = "Загружено: " + path.get_file()

func _copy_to_internal_storage(source_path: String) -> String:
	var file_name = source_path.get_file()
	var dest_path = "user://music/" + file_name
	if FileAccess.file_exists(dest_path): return dest_path
	var err = DirAccess.copy_absolute(source_path, dest_path)
	return dest_path if err == OK else ""

func _load_audio_file(path: String):
	if not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	var bytes = file.get_buffer(file.get_length())
	var stream
	var ext = path.get_extension().to_lower()
	match ext:
		"mp3":
			stream = AudioStreamMP3.new()
			stream.data = bytes
		"ogg": stream = AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			stream = AudioStreamWAV.new()
			stream.data = bytes
	if stream:
		music_player.stop()
		music_player.stream = stream
		music_player.play()
		is_paused = false

# --- СОХРАНЕНИЕ / ЗАГРУЗКА ---

func save_chart():
	var custom_name = chart_name_input.text.strip_edges().validate_filename()
	if custom_name == "": custom_name = "unnamed"
	var data = {
		"chart_name": custom_name,
		"music_path": GameManager.selected_song_path,
		"notes": recorded_chart
	}
	var file = FileAccess.open("user://charts/" + custom_name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	refresh_chart_list()
	status_label.text = "Сохранено!"

func refresh_chart_list():
	chart_list.clear()
	var dir = DirAccess.open("user://charts/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"): chart_list.add_item(file_name)
			file_name = dir.get_next()

func _on_chart_item_selected(index):
	var chart_name = chart_list.get_item_text(index)
	var data = _load_json("user://charts/" + chart_name)
	if data:
		recorded_chart = data.get("notes", [])
		GameManager.selected_song_path = data.get("music_path", "")
		chart_name_input.text = chart_name.get_basename()
		if GameManager.selected_song_path != "":
			_load_audio_file(GameManager.selected_song_path)
			status_label.text = "Редактирование: " + chart_name

func _load_json(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK: return json.data
	return null

# --- УПРАВЛЕНИЕ И ПЕРЕХОДЫ ---

func _toggle_pause():
	if music_player.stream == null: return
	is_paused = !is_paused
	music_player.stream_paused = is_paused
	pause_button.text = "ПРОДОЛЖИТЬ" if is_paused else "ПАУЗА"

func _exit_to_menu():
	# ПЛАВНЫЙ ПЕРЕХОД В МЕНЮ
	Transition.change_scene("res://scenes/menu.tscn")

func _open_save_dialog():
	if recorded_chart.is_empty(): return
	if !is_paused: _toggle_pause()
	save_window.visible = true
	chart_name_input.grab_focus()

func _on_confirm_save_pressed():
	save_chart()
	save_window.visible = false

# --- ПРОЦЕСС ---

func _process(_delta):
	if music_player.playing and !is_paused:
		song_position = music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	for t in targets:
		t.modulate = t.modulate.lerp(Color(1, 1, 1, 0.2), 0.15)

func _input(event):
	if !music_player.playing or is_paused or save_window.visible: return 
	var lanes = {"note_left": 0, "note_down": 1, "note_up": 2, "note_right": 3}
	for action in lanes:
		if event.is_action_pressed(action):
			var lane = lanes[action]
			targets[lane].modulate = Color(1, 1, 1, 1)
			recorded_chart.append([song_position, lane])
			spawn_note_preview(song_position, lane)

func setup_strum_line():
	for t in targets: t.queue_free()
	targets.clear()
	for i in range(4):
		var target = Sprite2D.new()
		target.texture = preload("res://assets/romb.png") 
		target.scale = Vector2(0.4, 0.4)
		target.modulate = Color(1, 1, 1, 0.2)
		target.position = Vector2(300 + (i * 120), 150)
		add_child(target)
		targets.append(target)

func spawn_note_preview(time, lane):
	if ResourceLoader.exists("res://scenes/note.tscn"):
		var n = preload("res://scenes/note.tscn").instantiate()
		n.spawn_time = time
		n.lane = lane
		n.position.x = targets[lane].position.x
		add_child(n)
