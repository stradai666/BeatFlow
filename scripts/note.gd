extends Node2D

var spawn_time = 0.0
var lane = 0
var length = 0.0 

@onready var tail_visual = $TailVisual # Твой ColorRect

func update_tail():
	if length > 0.1 and tail_visual:
		tail_visual.visible = true
		var parent = get_parent()
		var speed = parent.scroll_speed if "scroll_speed" in parent else 650.0
		# Растягиваем прямоугольник вниз
		tail_visual.size.y = length * speed
	elif tail_visual:
		tail_visual.visible = false

func _process(_delta):
	var parent = get_parent()
	if "scroll_speed" in parent and "song_position" in parent:
		# Движение ноты (цель на Y=100)
		position.y = 100 + (spawn_time - parent.song_position) * parent.scroll_speed
