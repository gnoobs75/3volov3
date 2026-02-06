extends Control
## Screen-space overlay for effects: low health pulse, sensory popup, death recap.
## The parent cell_stage_manager sets draw data, then calls queue_redraw().

# Draw callback — cell_stage_manager provides a callable
var draw_callback: Callable = Callable()

func _draw() -> void:
	if draw_callback.is_valid():
		draw_callback.call(self)
