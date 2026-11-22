extends ColorRect
## Drifting pixel mist drawn over an area with the mist shader.
## `edge_only` keeps it to the borders (the village at dusk).

@export_range(0.0, 1.0) var density := 0.35:
	set(value):
		density = value
		_apply()
@export var edge_only := false
@export var tint := Color(0.72, 0.82, 0.88, 1.0)
@export var drift := Vector2(0.010, 0.003)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


func _apply() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("edge_only", 1.0 if edge_only else 0.0)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("drift", drift)


func fade_density(to: float, duration: float) -> Tween:
	var t := create_tween()
	t.tween_property(self, "density", to, duration)
	return t
