extends CanvasLayer

@onready var anim = $AnimationPlayer
@onready var overlay = $Overlay

func change_scene(target_path: String):
	# 1. Выезжает справа
	overlay.position.x = get_viewport().size.x
	anim.play("fade")
	
	# Ждем, пока квадрат полностью закроет экран (середина анимации)
	await get_tree().create_timer(0.5).timeout
	
	# 2. Меняем сцену
	get_tree().change_scene_to_file(target_path)
	
	# Ждем окончания анимации (квадрат уезжает влево)
	await anim.animation_finished
	
	# Сбрасываем позицию для следующего раза
	overlay.position.x = get_viewport().size.x
