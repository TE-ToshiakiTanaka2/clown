extends Area2D
## Fall-death boundary below the level: kills the player on contact
## without a score penalty.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.die()
