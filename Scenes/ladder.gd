extends Node2D

func _ready() -> void:
	$Area2D.body_entered.connect(_on_area_2d_body_entered)
	$Area2D.body_exited.connect(_on_area_2d_body_exited)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if "on_ladder" in body:
		body.on_ladder = true
		print("[Ladder] Player entered ladder area")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if "on_ladder" in body:
		body.on_ladder = false
		print("[Ladder] Player exited ladder area")
