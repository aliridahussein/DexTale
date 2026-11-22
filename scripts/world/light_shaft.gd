extends Sprite2D
## Slowly breathing additive light beam (sunset rays, moonbeams, stained glass).

@export var base_alpha := 0.18
@export var pulse := 0.05
@export var speed := 0.35

var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_t += delta * speed
	modulate.a = base_alpha + sin(_t) * pulse + sin(_t * 2.7) * pulse * 0.4
