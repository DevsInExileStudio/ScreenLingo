@tool
extends ColorRect

## ColorRect with shader that needs size in pixels (rect_size):
## roundings, crease thickness and shadows calculated in px, not UV fractions.
## Material made unique per node so cards don't share params.

func _ready() -> void:
	if material:
		material = material.duplicate()
	_sync()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync()


func _sync() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("rect_size", size)
