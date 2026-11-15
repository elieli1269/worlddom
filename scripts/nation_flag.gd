extends Control
class_name NationFlag

@export var nation_color := Color("#6682b7")
@export var seed_value := 1

func _ready() -> void:
	custom_minimum_size = Vector2(50, 32)
	queue_redraw()

func _draw() -> void:
	var c := nation_color
	draw_rect(Rect2(Vector2.ZERO, size), Color("#d8c99f"))
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), c.darkened(0.12))
	draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, (size.y - 4) * 0.27)), c.lightened(0.42))
	draw_rect(Rect2(Vector2(2, size.y * 0.70), Vector2(size.x - 4, size.y * 0.24)), c.darkened(0.25))
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var seal_color := Color("#d9bd72") if seed_value % 2 == 0 else Color("#f1e8d5")
	draw_circle(center, minf(size.y * 0.19, 6.0), seal_color)
	draw_circle(center, minf(size.y * 0.10, 3.2), c.darkened(0.32))
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color("#0c202b"), false, 1.0)
