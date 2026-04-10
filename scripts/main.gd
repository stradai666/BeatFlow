extends Node2D

@onready var music_player = $MusicPlayer

# --- Основные переменные ---
var song_position = 0.0
var scroll_speed = 650.0
var health = 50.0
var chart = []
var target_y = 100.0

@onready var is_recording = GameManager.is_editor_mode

# --- Статистика и Комбо ---
var total_notes_processed = 0.0
var accuracy_sum = 0.0
var current_accuracy = 100.0
var combo = 0

# --- Окна точности (в секундах) ---
var window_perfect = 0.045 # 45мс
var window_good = 0.090 # 90мс
var window_bad = 0.135 # 135мс
var miss_window = 0.200 # 200мс

var recorded_chart = []
var targets = []
var current_presses = {0: null, 1: null, 2: null, 3: null}

func _ready():
	if GameManager.selected_song_path != "":
		_smart_load_audio(GameManager.selected_song_path)
	
	if not is_recording:
		var path = GameManager.selected_chart_path if GameManager.selected_chart_path != "" else "res://level.json"
		load_chart(path)
	
	music_player.play()
	setup_strum_line()
	setup_ui()

func _process(_delta):
	if music_player.playing:
		song_position = music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	
	if is_recording:
		_handle_recording_logic()
	else:
		spawn_logic()
		check_misses()
		_update_hp_bar_visual()
	
	_update_notes_position()
			
	for t in targets:
		t.modulate = t.modulate.lerp(Color(1, 1, 1, 0.2), 0.15)

func _update_notes_position():
	for note in get_tree().get_nodes_in_group("notes"):
		var time_diff = note.spawn_time - song_position
		note.position.y = target_y + (time_diff * scroll_speed)

func _handle_recording_logic():
	var lanes = ["note_left", "note_down", "note_up", "note_right"]
	for i in range(4):
		if Input.is_action_just_pressed(lanes[i]):
			targets[i].modulate = Color(1, 1, 1, 1)
			var new_note = spawn_note(song_position, i, 0.0)
			current_presses[i] = {"start": song_position, "node": new_note}
		
		if Input.is_action_pressed(lanes[i]) and current_presses[i] != null:
			var current_dur = song_position - current_presses[i]["start"]
			if current_dur > 0.1:
				if is_instance_valid(current_presses[i]["node"]):
					current_presses[i]["node"].length = current_dur
					if current_presses[i]["node"].has_method("update_tail"):
						current_presses[i]["node"].update_tail()
		
		if Input.is_action_just_released(lanes[i]) and current_presses[i] != null:
			var final_dur = song_position - current_presses[i]["start"]
			if final_dur < 0.15: final_dur = 0.0
			recorded_chart.append([float(current_presses[i]["start"]), int(i), float(final_dur)])
			current_presses[i] = null

func _input(event):
	if is_recording:
		if event.is_action_pressed("ui_accept"): save_recorded_chart()
		return
	
	var action_lanes = {"note_left": 0, "note_down": 1, "note_up": 2, "note_right": 3}
	for action in action_lanes:
		if event.is_action_pressed(action) and not event.is_echo():
			var lane = action_lanes[action]
			targets[lane].modulate = Color(1, 1, 1, 1)
			check_hit(lane)

func check_hit(lane):
	var notes = get_tree().get_nodes_in_group("notes")
	var closest_note = null
	var smallest_diff = window_bad

	for note in notes:
		if note.lane == lane:
			var diff = abs(note.spawn_time - song_position)
			if diff < smallest_diff:
				smallest_diff = diff
				closest_note = note

	if closest_note:
		total_notes_processed += 1
		combo += 1
		
		# Эффект вспышки на комбо 50
		if combo == 50:
			trigger_screen_flash()
		
		var rating_text = ""
		var rating_color = Color.WHITE
		var weight = 0.0

		if smallest_diff <= window_perfect:
			rating_text = "PERFECT!"
			rating_color = Color.CYAN
			weight = 1.0
			health += 4.0
		elif smallest_diff <= window_good:
			rating_text = "GOOD"
			rating_color = Color.SPRING_GREEN
			weight = 0.7
			health += 2.0
		else:
			rating_text = "BAD"
			rating_color = Color.ORANGE_RED
			weight = 0.3
			health -= 3.0

		accuracy_sum += weight
		_update_accuracy_label()
		show_rating_popup(rating_text, rating_color)
		
		health = clamp(health, 0, 100)
		closest_note.queue_free()

func check_misses():
	for note in get_tree().get_nodes_in_group("notes"):
		if song_position - note.spawn_time > miss_window:
			total_notes_processed += 1
			combo = 0
			_update_accuracy_label()
			
			show_rating_popup("MISS", Color.RED)
			health -= 8.0
			note.queue_free()

func _update_accuracy_label():
	if total_notes_processed > 0:
		current_accuracy = (accuracy_sum / total_notes_processed) * 100.0
	var acc_label = get_node_or_null("HUD/AccuracyLabel")
	if acc_label:
		acc_label.text = "Accuracy: %.2f%%" % current_accuracy

func show_rating_popup(text, color):
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.position = Vector2(700, 200)
	container.custom_minimum_size = Vector2(300, 150)
	add_child(container)
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = color
	label.add_theme_font_size_override("font_size", 42)
	container.add_child(label)
	
	if combo > 0:
		var combo_label = Label.new()
		combo_label.text = "x" + str(combo)
		combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combo_label.add_theme_font_size_override("font_size", 34)
		
		if combo >= 50: combo_label.modulate = Color.GOLD
		elif combo >= 10: combo_label.modulate = Color.WHITE
		else: combo_label.modulate = Color(0.7, 0.7, 0.7)
		
		container.add_child(combo_label)
	
	var tween = create_tween()
	tween.tween_property(container, "position:y", container.position.y - 70, 0.2)
	tween.parallel().tween_property(container, "modulate:a", 0, 0.2).set_delay(0.3)
	tween.tween_callback(container.queue_free)

func trigger_screen_flash():
	var overlay = get_node_or_null("HUD/FlashOverlay")
	if not overlay: return
	
	overlay.size = get_viewport_rect().size
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Вспыхиваем до 0.15 (15% видимости) за 0.05 сек
	tween.tween_property(overlay, "color:a", 0.15, 0.05)
	# Затухаем до нуля за 0.4 сек
	tween.tween_property(overlay, "color:a", 0.0, 0.4)

func spawn_note(time, lane, length = 0.0):
	if ResourceLoader.exists("res://scenes/note.tscn"):
		var n = preload("res://scenes/note.tscn").instantiate()
		n.spawn_time = time
		n.lane = lane
		n.length = length
		n.add_to_group("notes")
		add_child(n)
		n.position.x = targets[lane].position.x
		return n
	return null

func spawn_logic():
	if chart.size() > 0:
		if chart[0][0] <= song_position + 2.0:
			var d = chart[0]
			var l = d[2] if d.size() > 2 else 0.0
			spawn_note(d[0], d[1], l)
			chart.remove_at(0)

func load_chart(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary and data.has("notes"):
			chart = data["notes"]
		else:
			chart = data
		chart.sort_custom(func(a, b): return float(a[0]) < float(b[0]))

func save_recorded_chart():
	recorded_chart.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var path = "user://new_chart.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data = {"music_path": GameManager.selected_song_path, "notes": recorded_chart}
		file.store_string(JSON.stringify(data, "\t"))
		print("--- ЧАРТ СОХРАНЕН ---")

func setup_strum_line():
	targets.clear()
	for i in range(4):
		var target = Sprite2D.new()
		target.texture = preload("res://assets/romb.png")
		target.scale = Vector2(1, 1)
		target.modulate = Color(1, 1, 1, 0.2)
		target.position = Vector2(300 + (i * 120), target_y)
		add_child(target)
		targets.append(target)

func _smart_load_audio(path):
	if path.begins_with("user://"):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var bytes = file.get_buffer(file.get_length())
			var stream
			var ext = path.get_extension().to_lower()
			if ext == "mp3": stream = AudioStreamMP3.new()
			elif ext == "ogg": stream = AudioStreamOggVorbis.load_from_buffer(bytes)
			elif ext == "wav": stream = AudioStreamWAV.new()
			if stream:
				if ext != "ogg": stream.data = bytes
				music_player.stream = stream
	else:
		music_player.stream = load(path)

func setup_ui():
	var old_hud = get_node_or_null("HUD")
	if old_hud: old_hud.queue_free()
	
	var cl = CanvasLayer.new()
	cl.name = "HUD"
	add_child(cl)
	
	# Слой для вспышки
	var flash_overlay = ColorRect.new()
	flash_overlay.name = "FlashOverlay"
	flash_overlay.color = Color(1.0, 0.9, 0.5, 0.0) # Золотистый, прозрачный
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(flash_overlay)
	
	var pb = ProgressBar.new()
	pb.name = "HPBar"
	pb.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	pb.size = Vector2(15, 300)
	pb.position = Vector2(50, 150)
	pb.value = health
	cl.add_child(pb)
	
	var acc_label = Label.new()
	acc_label.name = "AccuracyLabel"
	acc_label.text = "Accuracy: 100.00%"
	acc_label.add_theme_font_size_override("font_size", 24)
	acc_label.position = Vector2(550, 650)
	cl.add_child(acc_label)

func _update_hp_bar_visual():
	var hp_bar = get_node_or_null("HUD/HPBar")
	if hp_bar:
		hp_bar.value = lerp(float(hp_bar.value), float(health), 0.1)
