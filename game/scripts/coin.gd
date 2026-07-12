extends Area2D
## Collectible pickup: adds score and removes itself on player contact.

@export var score_value: int = 100


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		Game.add_score(score_value)
		queue_free()
