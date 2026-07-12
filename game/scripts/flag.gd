extends Area2D
## Level-end goal: clears the level when the player reaches it.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		Game.clear_level()
