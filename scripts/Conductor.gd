extends Node

var song_position = 0.0

func _process(_delta):
	# Этот код ищет плеер КАЖДЫЙ кадр. Это не очень красиво, но зато НАДЕЖНО для теста.
	var player = get_tree().root.find_child("MusicPlayer", true, false)
	if player and player.playing:
		song_position = player.get_playback_position() + AudioServer.get_time_since_last_mix()
		# Выводим время в консоль, чтобы видеть, что всё работает
		# print("Время песни: ", song_position)
